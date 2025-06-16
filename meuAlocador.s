.equ OFF_STATUS, 0              # deslocamento do campo status no cabeçalho
.equ OFF_SIZE,   8              # deslocamento do campo tamanho no cabeçalho
.equ OFF_NEXT,  16              # deslocamento do ponteiro next no cabeçalho
.equ OFF_PREV,  24              # deslocamento do ponteiro prev no cabeçalho
.equ HEADER_SZ, 32              # tamanho total do cabeçalho de cada bloco
.equ PAGE_SZ,   4096            # tamanho de página, usado para expansão

.section .data                  # seção de dados para variáveis globais
topoInicialHeap: .quad 0        # armazena endereço inicial da heap
ponteiroHeap:    .quad 0        # armazena o valor atual de brk
livreHead:       .quad 0        # cabeça da lista de blocos livres
ocupadoHead:     .quad 0        # cabeça da lista de blocos ocupados

Gerencial:  .string "################"  # padrão visual para mapa inicial
LivreChr:   .string "-"                # caractere para byte livre
OcupChr:    .string "*"                # caractere para byte ocupado
EOL:        .string "\n"               # fim de linha no output

.section .text                  # seção de código executável
.globl iniciaAlocador, finalizaAlocador, alocaMem, liberaMem, imprimeMapa  # expõe entradas públicas

insert_head:                    # insere bloco no início de uma lista
    movq   (%rsi), %rdx         # carrega cabeça atual da lista
    movq   %rdx, OFF_NEXT(%rdi) # aponta next do novo bloco para antiga cabeça
    movq   $0, OFF_PREV(%rdi)   # define prev do novo bloco como NULL
    testq  %rdx, %rdx           # verifica se lista estava vazia
    je     1f                   # pula se não havia bloco
    movq   %rdi, OFF_PREV(%rdx) # atualiza prev da antiga cabeça
1:  movq   %rdi, (%rsi)         # ajusta cabeça da lista para novo bloco
    ret                         # retorna ao chamador

remove_node:                    # retira bloco de sua lista atual
    movq   OFF_NEXT(%rdi), %rdx # carrega ponteiro next do bloco
    movq   OFF_PREV(%rdi), %rcx # carrega ponteiro prev do bloco
    testq  %rcx, %rcx           # verifica se bloco não é cabeça
    je     2f                   # se for cabeça, trata abaixo
    movq   %rdx, OFF_NEXT(%rcx) # liga prev.next ao next do bloco
    jmp    3f                   # pula para ajustar next.prev
2:  movq   %rdx, (%rsi)         # atualiza cabeça da lista
3:  testq  %rdx, %rdx           # verifica se existe bloco seguinte
    je     4f                   # se não, não ajusta prev
    movq   %rcx, OFF_PREV(%rdx) # liga next.prev ao prev do bloco
4:  ret                         # retorna ao chamador

iniciaAlocador:                # prepara estruturas e obtém base da heap
    movq   $12, %rax           # código de syscall brk
    xorq   %rdi, %rdi          # rdi = 0 para consultar brk(0)
    syscall                    # chama brk(0) para obter ponteiro
    movq   %rax, topoInicialHeap(%rip)  # salva endereço inicial
    movq   %rax, ponteiroHeap(%rip)     # define ponteiro atual de brk
    movq   $0, livreHead(%rip)         # lista de livres vazia
    movq   $0, ocupadoHead(%rip)       # lista de ocupados vazia
    ret                         # retorna ao programa

finalizaAlocador:              # retorna heap ao estado inicial
    movq   topoInicialHeap(%rip), %rdi  # rdi = endereço base salvo
    movq   $12, %rax           # código de syscall brk
    syscall                    # chama brk(base) para liberar
    ret                         # encerra a rotina

alocaMem:                      # aloca um bloco com pelo menos rdi bytes
    movq   %rdi, %r14          # copia tamanho pedido
    leaq   15(%r14), %r15      # prepara para alinhamento
    andq   $-16, %r15          # ajusta para múltiplo de 16

    movq   livreHead(%rip), %r12  # inicia busca na lista de livres
.busca:
    testq  %r12, %r12          # testa se atingiu fim da lista
    jz     .precisa_crescer    # se vazio, expande heap
    movq   OFF_SIZE(%r12), %r8 # lê tamanho do bloco disponível
    cmpq   %r14, %r8           # compara com tamanho solicitado
    jb     .prox_livre         # pula se for menor
    movq   %r12, %rdi          # prepara argumento para remove_node
    leaq   livreHead(%rip), %rsi
    call   remove_node         # retira bloco da lista de livres
    movq   $1, OFF_STATUS(%r12) # marca bloco como ocupado
    movq   %r12, %rdi          # prepara argumento para insert_head
    leaq   ocupadoHead(%rip), %rsi
    call   insert_head         # adiciona à lista de ocupados
    leaq   HEADER_SZ(%r12), %rax # calcula endereço do payload
    ret                        # retorna ponteiro de payload

.prox_livre:
    movq   OFF_NEXT(%r12), %r12 # avança para próximo bloco livre
    jmp    .busca              # continua busca

.precisa_crescer:
    movq   ponteiroHeap(%rip), %rbx # endereço onde brk será ajustado
    movq   %r15, %r10          # r10 = tamanho alinhado
    addq   $HEADER_SZ, %r10    # inclui espaço para cabeçalho
    leaq   (%rbx,%r10), %rdi   # calcula novo brk desejado
    movq   $12, %rax           # syscall brk
    syscall                    # expande heap
    movq   %rdi, ponteiroHeap(%rip) # atualiza ponteiro de brk

    movq   $1, OFF_STATUS(%rbx)  # marca novo bloco ocupado
    movq   %r15, OFF_SIZE(%rbx)  # armazena tamanho original
    movq   $0, OFF_NEXT(%rbx)    # limpa
    movq   $0, OFF_PREV(%rbx)    # limpa prev
    movq   %rbx, %rdi            # prepara insert_head
    leaq   ocupadoHead(%rip), %rsi
    call   insert_head         # insere bloco na lista de ocupados
    leaq   HEADER_SZ(%rbx), %rax # retorna ptr do payload
    ret                        # conclusão da alocação

/* =========================== liberaMem =========================
 * rdi = ponteiro do payload a liberar
 */
liberaMem:
    subq  $HEADER_SZ, %rdi            # rdi -> cabeçalho do bloco

    /* --- retira da lista de ocupados --- */
    leaq  ocupadoHead(%rip), %rsi
    call  remove_node

    movq  $0, OFF_STATUS(%rdi)        # marca como livre

    /* ---------- MERGE COM O BLOCO SEGUINTE ---------- */
    movq  OFF_SIZE(%rdi), %rax        # rax = size_cur
    lea   15(%rax), %rcx
    andq  $-16, %rcx                  # rcx = align16(size_cur)
    leaq  HEADER_SZ(%rcx), %rcx       # deslocamento até o próximo header
    leaq  (%rdi,%rcx), %r8            # r8  = ptr próximo bloco

    cmpq  ponteiroHeap(%rip), %r8     # passa do fim da heap?
    jge   .skip_next
    cmpq  $0, OFF_STATUS(%r8)         # status == LIVRE ?
    jne   .skip_next

    /*      →  absorve próximo bloco livre */
    leaq  livreHead(%rip), %rsi
    movq  %r8, %r9
    call  remove_node                 # tira ‘next’ da lista livre

    movq  OFF_SIZE(%r8), %r9
    addq  $HEADER_SZ, %r9             # inclui header do ‘next’
    addq  %r9, OFF_SIZE(%rdi)         # size_cur += header + size_next
.skip_next:

    /* ---------- MERGE COM O BLOCO ANTERIOR ---------- */
    movq  livreHead(%rip), %r8        # percorre lista de livres
.scan_prev:
    testq %r8, %r8
    jz    .insert_free                # não achou vizinho → sai
    movq  OFF_SIZE(%r8), %rax
    lea   15(%rax), %rcx
    andq  $-16, %rcx
    leaq  HEADER_SZ(%rcx), %rcx
    leaq  (%r8,%rcx), %r9             # r9 = fim de blk + header
    cmpq  %r9, %rdi
    jne   .next_in_list

    /*  → r8 é o bloco imediatamente ANTERIOR e já está livre  */
    leaq  livreHead(%rip), %rsi
    movq  %r8, %r9
    call  remove_node                 # retira ‘prev’ da lista livre

    movq  OFF_SIZE(%rdi), %rax
    addq  $HEADER_SZ, %rax
    addq  %rax, OFF_SIZE(%r8)         # prev->size += header + size_cur
    movq  %r8, %rdi                   # rdi passa a ser o bloco fundido
    jmp   .insert_free
.next_in_list:
    movq  OFF_NEXT(%r8), %r8
    jmp   .scan_prev

.insert_free:
    /* ---------- coloca bloco (já possivelmente maior) na lista livre --- */
    leaq  livreHead(%rip), %rsi
    call  insert_head
    ret


imprimeMapa:                  # exibe visualização da heap atual
    movq   topoInicialHeap(%rip), %rbx # rbx = início da heap
.print_loop:
    cmpq   ponteiroHeap(%rip), %rbx # verifica se chegou ao final
    jge    .newline            # se sim, imprime nova linha

    movq   $1, %rax            # syscall write
    movq   $1, %rdi            # fd = stdout
    leaq   Gerencial(%rip), %rsi # padrão de '#' para delimitar
    movq   $16, %rdx           # 16 caracteres por vez
    syscall                    # escreve delimitador

    movq   OFF_STATUS(%rbx), %r10 # lê status do bloco
    movq   OFF_SIZE(%rbx),   %r11 # lê tamanho original do bloco
    xorq   %r12, %r12          # inicializa contador de bytes
.byte_loop:
    cmpq   %r11, %r12          # se processou todos os bytes
    jge    .passo              # passa ao próximo bloco
    movq   $1,  %rax           # syscall write
    movq   $1,  %rdi           # fd = stdout
    movq   $1,  %rdx           # escrever um byte
    cmpq   $0,  %r10           # verifica se está livre
    je     .livre             # se livre, escolhe caractere '-'
    leaq   OcupChr(%rip), %rsi # caso contrário, '+' para ocupado
    jmp    .write
.livre:
    leaq   LivreChr(%rip), %rsi # caractere para byte livre
.write:
    syscall                    # escreve byte representativo
    incq   %r12                # incrementa contador
    jmp    .byte_loop          # repete até completar bloco

.passo:
    movq   OFF_SIZE(%rbx), %r13 # lê tamanho original
    leaq   15(%r13), %r14       # prepara alinhamento
    andq   $-16, %r14           # ajusta para múltiplo de 16
    leaq   HEADER_SZ(%r14), %r14 # total a avançar
    addq   %r14, %rbx           # aponta para próximo cabeçalho
    jmp    .print_loop          # continua loop de impressão

.newline:
    movq   $1, %rax            # syscall write
    movq   $1, %rdi            # fd = stdout
    leaq   EOL(%rip), %rsi     # caractere de nova linha
    movq   $1, %rdx            # um byte apenas
    syscall                    # escreve newline
    ret                        # retorna ao chamador
