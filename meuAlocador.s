.section .data
    topoInicialHeap: .quad 0
    fimHeap: .quad 0
    ponteiroHeap: .quad 0

    Gerencial: .string "################"
    Desocupado: .string "-"
    Ocupado: .string "+"
    QuebraLinha: .string "\n"

.section .text
.globl iniciaAlocador
.globl finalizaAlocador
.globl alocaMem
.globl liberaMem
.globl imprimeMapa

iniciaAlocador:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax                # syscall brk
    movq $0, %rdi                 # brk(0) -> devolve endereco atual da heap
    syscall                       # syscall

    movq %rax, topoInicialHeap    # endereco da heap em TopoInicialHeap
    movq %rax, ponteiroHeap       # ponteiro da heap comeca na base
    movq %rax, fimHeap            # fimHeap tambem recebe o endereco da heap

    popq %rbp
    ret


finalizaAlocador:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax                              # syscall brk
    movq topoInicialHeap, %rdi                  # restaura a heap
    syscall                                     # fimHeap eh restaurada tambem

    popq %rbp
    ret

liberaMem:
    pushq %rbp
    movq %rsp, %rbp

    subq $16, %rdi          # Volta ao início do cabeçalho
    movq $0, (%rdi)         # Marca como livre

    movq 8(%rdi), %rsi      # tamanho do bloco atual
    lea 16(%rdi, %rsi), %r8 # endereço do próximo bloco
    cmpq ponteiroHeap, %r8
    jge fim                 # se já for o fim da heap, nada a fazer

    movq (%r8), %r9         # status do próximo bloco
    cmpq $0, %r9
    jne fim                 # se próximo estiver ocupado, não funde

    movq 8(%r8), %r10       # tamanho do próximo bloco
    addq $16, %r10          # soma cabeçalho
    addq %r10, %rsi         # novo tamanho do bloco fundido
    movq %rsi, 8(%rdi)      # atualiza tamanho

fim:
    popq %rbp
    ret

alocaMem:
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r14              # %r14 -> tamanho requisitado
    movq fimHeap, %r15           # %r15 = aponta para o topo da heap
    movq topoInicialHeap, %r12   # %r12 = aponta para o comeco da heap (base)
    movq ponteiroHeap, %r13      # %r13 = aponta para o ponteiro da heap atual

    movq $-1, %rax               # %rax = tamanho do menor bloco encontrado (-1 significa nenhum encontrado)
    addq $16, %r12

    # Itera por todos os blocos
    while_ainda_tem:
        cmpq %r13, %r12          # se %r12 >= ponteiro da heap, sai do loop
        jge nao_tem_mais        

        movq -16(%r12), %r8     # %r8 = ocupado?
        movq -8(%r12), %r9      # %rcx = tamanho do bloco atual

        cmpq $1, %r8            # se ocupado, vai para proxima iteracao
        je atualiza_iterador

        cmpq %r14, %r9          # se tamanho do bloco < tamanho requisitado, vai para proxima iteracao
        jl atualiza_iterador

        cmpq $-1, %rax
        je set_best             # o primeiro bloco possivel encontrado ja eh uma opcao

        cmpq %rbx, %r9
        jl set_best             # se bloco atual for menor que o melhor ate agora, define como melhor

        jmp atualiza_iterador

    set_best:
        movq %r9, %rbx          # %rbx = tamanho do melhor bloco
        movq %r12, %rax         # %rax = endereco do melhor bloco

    atualiza_iterador:
        addq %r9, %r12          # %r12 += tamanho do bloco atual
        addq $16, %r12          # %r12 += tamanho do cabecalho
        jmp while_ainda_tem

    nao_tem_mais:
        cmpq $-1, %rax
        je cria_novo_bloco       # se nenhum bloco foi encontrado, cria um novo bloco

        movq $1, -16(%rax)       # marca o bloco como ocupado
        jmp fim_alocacao

    cria_novo_bloco:
        addq %r14, %r12          # calcula o novo ponteiro da heap

        cmpq fimHeap, %r12
        jg alocacao              # se o ponteiro ultrapassar a memoria disponivel na heap, tera de alocar mais

        movq %r12, ponteiroHeap  # se nao, atualiza o ponteiro da heap e marca o bloco como ocupado
        subq %r14, %r12
        movq %r12, %rax

        movq $1, -16(%rax)       # marca como ocupado
        movq %r14, -8(%rax)      # define o tamanho do bloco
        jmp fim_alocacao

    alocacao:
        addq $16, %rdi       # tamanho do cabecalho + bloco requisitado
        movq %rdi, %r10
        addq $4095, %r10
        andq $-4096, %r10    # bitmask para arredondar o tamanho da pag para multiplo de 4096

        movq $12, %rax    # syscall brk
        addq %r15, %r10   # proximo limite da heap
        movq %r10, %rdi
        syscall           # brk(%r10)

        movq %rax, fimHeap  # atualiza o limite da heap (fimHeap)
        movq %r13, %rax     # %rax recebe o ponteiro antigo da heap

        addq $16, %r13      # atualiza ponteiro para novo bloco
        addq %r14, %r13
        movq %r13, ponteiroHeap

        movq $1, (%rax)     # marca o bloco como ocupado
        movq %r14, 8(%rax)  # define o tamanho do bloco
        addq $16, %rax      # retorna o endereco do bloco

    fim_alocacao:
        popq %rbp
        ret

imprimeMapa:
    pushq %rbp
    movq %rsp, %rbp

    # subq $8, %rsp

    movq ponteiroHeap, %rbx                    # %rbx = fimHeap
    movq %rbx, %r14                            # %r14 = fimHeap

    movq topoInicialHeap, %rbx                 # %rbx = topoInicialHeap -> base da heap

    while_ainda_tem_print:
        cmpq %r14, %rbx                     # enquanto iterador nao chegou no fim da heap
        jge fim_while_bloco                     # se for maior ou igual, significa que os blocos acabaram
        movq $1, %rax                           # syscall write 
        movq $1, %rdi                           # 1 argumento do write -> escrever no stdout
        movq $Gerencial, %rsi                   # 2 argumento do write -> ponteiro para a mensagem a ser escrita
        movq $16, %rdx                          # 3 argumento do write -> tamanho do que sera escrito
        syscall                                 # chamando o write

        movq (%rbx), %r10                       # %r10 = ocupado?
        movq 8(%rbx), %r12                      # %r12 = tamanho do bloco
        movq $0, %r13                           # %r13 (iterador) = 0

        while_nao_acabou_bloco:
            cmpq %r12, %r13                     # enquanto iterador nao chegou ao fim do bloco
            jge fim_while_bytes
            movq $1, %rax                       # codigo de chamada de sistema para write 
            movq $1, %rdi
            movq $1, %rdx                       # tamanho da string 1 -> "+": ocupado, "-": desocupado

            cmpq $0, %r10                       # comparacao para ver se o bit esta ocupado (para saber o que escrever)
            jne imprime_ocupado        
            movq $Desocupado, %rsi              # imprime "-"
            jmp fim_impressao   

        imprime_ocupado: 
            movq $Ocupado, %rsi                 # imprime "+"

        fim_impressao:
            syscall
            addq $1, %r13                       # iterador += 1
            jmp while_nao_acabou_bloco          # continua o loop para o resto do bloco

        fim_while_bytes:
            addq $16, %rbx
            addq %r12, %rbx                     # %rbx + 16 + tamanho -> pula para o proximo bloco
            jmp while_ainda_tem_print           # volta para o laco para verificar se rbx (endereco iterador) ja eh maior que fimHeap

    fim_while_bloco:
    movq $QuebraLinha, %rsi                     # rsi = "\n"

    movq $1, %rax                               # codigo de chamada de sistema para write 
    movq $1, %rdi
    movq $1, %rdx                               # tamanho da string = 1 (caractere "\n")
    syscall

    # addq $8, %rsp
    popq %rbp
    ret
