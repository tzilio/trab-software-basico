.section .data
  topoInicialHeap:  .quad 0
  topoAtual:        .quad 0
  listaOcupado:     .quad 0
  listaLivre:       .quad 0

  info:             .byte '#'
  ocupado:          .byte '+'
  livre:            .byte '-'
  nova_linha:       .byte '\n'

  string:           .string "<vazio>\n"

  .equ METADATA_SIZE, 24

.section .text
  .globl iniciaAlocador
  .globl finalizaAlocador
  .globl liberaMem
  .globl alocaMem
  .globl imprimeMapa

iniciaAlocador:
  pushq %rbp
  movq  %rsp, %rbp

  movq  $12, %rax  # rax := 12 -- syscall brk
  movq  $0,  %rdi  # rdi := 0  -- argumento
  syscall

  movq  %rax, topoInicialHeap  # Atualiza topo inicial da heap
  movq  %rax, topoAtual        # Atualiza topo atual da heap

  popq  %rbp
  ret

finalizaAlocador:
  pushq %rbp
  movq  %rsp, %rbp

  movq  $12, %rax             # rax := 12 -- syscall brk
  movq  topoInicialHeap, %rdi # rdi := topoInicialHeap
  syscall

  movq $0, listaLivre   # listaLivre := NULL
  movq $0, listaOcupado # ListaOcupado := NULL

  popq  %rbp
  ret

# rdi := Num_bytes
# r12 := bloco_atual
# r13 := bloco_anterior
# r14 := tamanho_do_bloco_atual
# r15 := proximo
# rbx := inicio_do_bloco
alocaMem:
  pushq %rbp
  movq %rsp, %rbp

  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq listaLivre, %r12 # bloco_atual := listaLivre
  movq $0, %r13         # bloco_anterior := NULL

encontrar_bloco_livre:

  cmpq $0, %r12  # if (bloco_atual == NULL)
  je alocar_novo_bloco

  movq 8(%r12), %r14 # tamanho_do_bloco_atual := *(bloco_atual + 8)
  movq 16(%r12), %r15 # proximo := *(bloco_atual + 16)

  cmpq %rdi, %r14 # if (tamanho_do_bloco_atual < num_bytes)
  jl iterar_para_proximo_bloco

  cmpq $0, %r13 # if (bloco_anterior != NULL)
  jne arrumar_ponteiros

  movq %r15, listaLivre # listaLivre := proximo
  jmp retornar_bloco

arrumar_ponteiros:

  movq %r15, 16(%r13) # *(bloco_anterior + 16) := proximo

iterar_para_proximo_bloco:

  movq %r12, %r13 # bloco_anterior := bloco_atual
  movq %r15, %r12 # bloco_atual := proximo
  jmp encontrar_bloco_livre

retornar_bloco:

  movq $1, (%r12) # *(bloco_atual) = 1 
  movq listaOcupado, %rcx
  movq %rcx, 16(%r12) # *(bloco_atual + 16) := listaOcupado
  movq %r12, listaOcupado     # listaOcupado := bloco_atual

  # return *(bloco_atual + 24)
  movq %r12, %rax
  addq $24, %rax

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx

  popq %rbp
  ret

alocar_novo_bloco:

  movq topoAtual, %rbx # inicio_do_bloco := topoAtual
  movq %rdi, %r9 # r9 := num_bytes

  movq topoAtual, %r10 
  addq %rdi, %r10
  addq $24, %r10 # r10 := topoAtual + num_bytes + 24

  movq $12, %rax # rax := 12 (syscall brk)
  movq %r10, %rdi
  syscall

  movq %rax, topoAtual

  # preenche metadados
  movq $1, (%rbx) # *(inicio_do_bloco) := 1
  movq %r9, 8(%rbx) # *(inicio_do_bloco + 8) := num_bytes
  movq listaOcupado, %rcx
  movq %rcx, 16(%rbx) # *(inicio_do_bloco + 16) := listaOcupado
  movq %rbx, listaOcupado # listaOcupado := inicio_do_bloco

  movq %rbx, %rax # return *(inicio_do_bloco + 24)
  addq $24, %rax

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx

  popq %rbp
  ret

# rdi := bloco
# r12 := ptr
# r13 := bloco_atual
# r14 := bloco_anterior
# r15 := proximo
liberaMem:
  pushq %rbp
  movq %rsp, %rbp

  pushq %r15
  pushq %r14
  pushq %r13
  pushq %r12

  cmpq $0, %rdi # if (bloco == NULL)
  je erro

  # ptr := bloco - 24
  movq %rdi, %r12
  subq $24, %r12 

  movq listaOcupado, %r13 # bloco_atual := ListaOcupado
  movq $0, %r14 # bloco_anterior := NULL

encontrar_bloco:
  cmpq $0, %r13 # if (bloco_atual == NULL)
  je nao_encontrou

  movq 16(%r13), %r15 # proximo := *(bloco_atual + 16)

  cmpq %r12, %r13 # if (bloco_atual != ptr)
  jne proximo_bloco

  cmpq $0, %r14 # if (bloco_anterior != NULL)
  jne ajustar_ponteiros

  movq %r15, listaOcupado # listaOcupado := proximo
  jmp liberar_bloco

ajustar_ponteiros:
  movq %r15, 16(%r14) # *(bloco_anterior + 16) := proximo

liberar_bloco:
  # --- FUSÃO (coalescing) COM BLOCO À DIREITA ---------------------------------
  movq 8(%r12), %r10           # r10 = tamanho deste bloco
  lea 24(%r12,%r10), %r11      # r11 = endereço do próximo bloco na memória
  movq topoAtual, %r9
  cmpq %r9, %r11               # se além do topo → não há bloco à direita
  jge  .verifica_esquerda
  cmpq $0, (%r11)              # status do bloco à direita == livre ?
  jne .verifica_esquerda
  # soma tamanho_do_vizinho + 24 aos metadados deste bloco
  movq 8(%r11), %r10
  addq %r10, 8(%r12)
  addq $24, 8(%r12)
  # zera cabeçalho do bloco absorvido (r11) para não aparecer no mapa
  movq $0,   (%r11)   # zera status: cabeçalho não será impresso
  movq $0,  8(%r11)
  # retira bloco à direita da listaLivre
  # busca ptr_prev->next == r11
  movq listaLivre, %r8
  movq $0, %r9
.encontra_prev_dir:
  cmpq $0, %r8
  je   .verifica_esquerda
  cmpq %r11, %r8
  je   .ajusta_link_dir
  movq %r8, %r9        # r9 = prev (corrigido)
  movq 16(%r8), %r8    # r8 = next (avança)
  jmp  .encontra_prev_dir
.ajusta_link_dir:
  cmpq $0, %r9
  jne  1f
  movq 16(%r11), %r10   # usa temporário para evitar mem->mem
  movq %r10, listaLivre
  jmp  .verifica_esquerda
1: movq 16(%r11), %r15
  movq %r15, 16(%r9)

  # --- FUSÃO COM BLOCO À ESQUERDA --------------------------------------------
.verifica_esquerda:
  movq listaLivre, %r8
.busca_esq:
  cmpq $0, %r8
  je   .insere_final
  movq 8(%r8), %r10
  lea 24(%r8,%r10), %r11       # fim físico do bloco verificado
  cmpq %r11, %r12              # r11 == ptr ? blocos são adjacentes
  je   .funde_esq
  movq 16(%r8), %r8            # avança na lista
  jmp  .busca_esq
.funde_esq:
  # soma tamanho_atual + 24 ao bloco da esquerda
  movq 8(%r12), %r10
  addq %r10, 8(%r8)
  addq $24, 8(%r8)

  movq $0,  (%r12)       # zera status: não deve mais aparecer no mapa
  movq $0,  8(%r12)      # zera tamanho: cabeçalho fantasma
  jmp  .done_fusao

.insere_final:
  # insere ptr (r12) na cabeça da listaLivre
  movq listaLivre, %r15
  movq %r15, 16(%r12)
  movq %r12, listaLivre
.done_fusao:
  movq $1, %rax
  popq %r15
  popq %r14
  popq %r13
  popq %r12

  popq %rbp
  ret

proximo_bloco:
  movq %r13, %r14 # bloco_anterior := bloco_atual
  movq %r15, %r13 # bloco_atual := proximo
  jmp encontrar_bloco

nao_encontrou:
  movq $0, %rax
  popq %r15
  popq %r14
  popq %r13
  popq %r12

  popq %rbp
  ret

erro:
  movq $0, %rax

  popq %r15
  popq %r14
  popq %r13
  popq %r12

  popq %rbp
  ret

# r11 := ptr
# r12 := ocupado
# r13 := tamanho
# r14 := i
imprimeMapa:
  pushq %rbp
  movq %rsp, %rbp
 
  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq topoInicialHeap, %r8 # ptr := topoInicialHeap
  cmpq topoAtual, %r8 # corrigido de %rax para %r8
  je vazio

percorrer_blocos:
  cmpq topoAtual, %r8 
  jge fim_heap

  movq (%r8), %r12 # ocupado := *(ptr)
  movq 8(%r8), %r13 # tamanho := *(ptr + 8)
  testq %r13, %r13         # tamanho == 0 ?
  jz  imprimir_proximo_bloco

  movq $0, %r14
for_imprime_info:
  cmpq $24, %r14 # if (i >= 24)
  jge fora_for_imprime_info

  movq $1, %rax # rax := 1 (syscall write)
  movq $1, %rdi # rdi := 1 (stdout)
  leaq info, %rsi # endereço do caractere
  movq $1, %rdx # tamanho
  syscall

  addq $1, %r14 # i += 1
  jmp for_imprime_info

fora_for_imprime_info:
  cmpq $1, %r12 # if ocupado == 1
  je imprimir_ocupado

  movq $0, %r14 
for_imprime_livre:
  cmpq %r13, %r14 # if (i >= tamanho)
  jge imprimir_proximo_bloco

  movq $1, %rax
  movq $1, %rdi
  leaq livre, %rsi
  movq $1, %rdx
  syscall

  addq $1, %r14 # i += 1
  jmp for_imprime_livre

imprimir_ocupado:
  movq $0, %r14 

for_imprime_ocupado:
  cmpq %r13, %r14 # if (i >= tamanho)
  jge imprimir_proximo_bloco

  movq $1, %rax
  movq $1, %rdi
  leaq ocupado, %rsi
  movq $1, %rdx
  syscall

  addq $1, %r14 # i += 1
  jmp for_imprime_ocupado

imprimir_proximo_bloco:
  addq %r13, %r8          # pula área de dados
  addq $24,  %r8           # pula metadados
  jmp percorrer_blocos

fim_heap:
  movq $1, %rax
  movq $1, %rdi
  leaq nova_linha, %rsi
  movq $1, %rdx
  syscall

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx

  movq %rbp, %rsp
  popq %rbp
  ret

vazio:
  movq $1, %rax
  movq $1, %rdi
  leaq string, %rsi
  movq $8, %rdx
  syscall

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx

  movq %rbp, %rsp
  popq %rbp
  ret
