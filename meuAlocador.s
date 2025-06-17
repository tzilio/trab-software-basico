.section .data
  topoInicialHeap:  .quad 0       # Endereço inicial da heap
  topoAtual:        .quad 0       # Topo atual da heap
  listaOcupado:     .quad 0       # Lista encadeada de blocos ocupados
  listaLivre:       .quad 0       # Lista encadeada de blocos livres

  info:             .byte '#'     # Cabeçalho dos blocos
  ocupado:          .byte '+'     # Byte para blocos ocupados
  livre:            .byte '-'     # Byte para blocos livres
  nova_linha:       .byte '\n'    # Nova linha

  string:           .string "<vazio>\n"  # String quando heap está vazia

  .equ METADATA_SIZE, 24          # Tamanho do cabeçalho de cada bloco

.section .text
  .globl iniciaAlocador
  .globl finalizaAlocador
  .globl liberaMem
  .globl alocaMem
  .globl imprimeMapa

################################################################################
#                               iniciaAlocador                                #
# Inicializa a heap usando syscall brk e define topo inicial e atual          #
################################################################################
iniciaAlocador:
  pushq %rbp
  movq  %rsp, %rbp

  movq  $12, %rax      # syscall brk
  movq  $0,  %rdi
  syscall

  movq  %rax, topoInicialHeap
  movq  %rax, topoAtual

  popq  %rbp
  ret

################################################################################
#                              finalizaAlocador                               #
# Libera toda a heap voltando para o estado inicial                           #
################################################################################
finalizaAlocador:
  pushq %rbp
  movq  %rsp, %rbp

  movq  $12, %rax
  movq  topoInicialHeap, %rdi
  syscall

  movq $0, listaLivre
  movq $0, listaOcupado

  popq  %rbp
  ret

################################################################################
#                                 alocaMem                                    #
# Aloca memória de tamanho `rdi`, procurando bloco livre ou expandindo heap   #
################################################################################
alocaMem:
  pushq %rbp
  movq %rsp, %rbp

  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq listaLivre, %r12   # bloco_atual
  movq $0, %r13           # bloco_anterior

.encontrar_bloco_livre:
  cmpq $0, %r12
  je .alocar_novo_bloco

  movq 8(%r12), %r14
  movq 16(%r12), %r15

  cmpq %rdi, %r14
  jl .iterar

  cmpq $0, %r13
  jne .ajustar_livre
  movq %r15, listaLivre
  jmp .usar_bloco

.ajustar_livre:
  movq %r15, 16(%r13)

.iterar:
  movq %r12, %r13
  movq %r15, %r12
  jmp .encontrar_bloco_livre

.usar_bloco:
  movq $1, (%r12)
  movq listaOcupado, %rcx
  movq %rcx, 16(%r12)
  movq %r12, listaOcupado
  movq %r12, %rax
  addq $24, %rax

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret

.alocar_novo_bloco:
  movq topoAtual, %rbx
  movq topoAtual, %r10
  movq %rdi, %r9
  addq %rdi, %r10
  addq $24, %r10

  movq $12, %rax
  movq %r10, %rdi
  syscall

  movq %rax, topoAtual

  movq $1, (%rbx)
  movq %r9, 8(%rbx)
  movq listaOcupado, %rcx
  movq %rcx, 16(%rbx)
  movq %rbx, listaOcupado
  movq %rbx, %rax
  addq $24, %rax

  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret

################################################################################
#                                 liberaMem                                   #
# Libera um bloco previamente alocado e faz fusão com vizinhos, se possível   #
################################################################################
liberaMem:
  pushq %rbp
  movq %rsp, %rbp

  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  cmpq $0, %rdi
  je .erro

  movq %rdi, %r12
  subq $24, %r12          # ptr := bloco - METADATA

  movq listaOcupado, %r13
  movq $0, %r14

.buscar:
  cmpq $0, %r13
  je .nao_encontrou

  movq 16(%r13), %r15
  cmpq %r12, %r13
  jne .proximo

  cmpq $0, %r14
  jne .ajusta_ocupado

  movq %r15, listaOcupado
  jmp .liberar

.ajusta_ocupado:
  movq %r15, 16(%r14)

.liberar:
  movq $0, (%r12)

  movq 8(%r12), %r10
  lea 24(%r12,%r10), %r11
  movq topoAtual, %r9
  cmpq %r9, %r11
  jge .verifica_esquerda

  cmpq $0, (%r11)
  jne .verifica_esquerda

  movq 8(%r11), %r10
  addq %r10, 8(%r12)
  addq $24, 8(%r12)

  movq $0, (%r11)
  movq $0, 8(%r11)

  movq listaLivre, %r8
  movq $0, %r9
.encontra_dir:
  cmpq $0, %r8
  je .verifica_esquerda
  cmpq %r11, %r8
  je .ajusta_dir
  movq %r8, %r9
  movq 16(%r8), %r8
  jmp .encontra_dir

.ajusta_dir:
  cmpq $0, %r9
  jne 1f
  movq 16(%r11), %r10
  movq %r10, listaLivre
  jmp .verifica_esquerda
1:
  movq 16(%r11), %r15
  movq %r15, 16(%r9)

.verifica_esquerda:
  movq listaLivre, %r8
.buscar_esq:
  cmpq $0, %r8
  je .insere_livre

  movq 8(%r8), %r10
  lea 24(%r8,%r10), %r11
  cmpq %r11, %r12
  je .funde

  movq 16(%r8), %r8
  jmp .buscar_esq

.funde:
  movq 8(%r12), %r10
  addq %r10, 8(%r8)
  addq $24, 8(%r8)

  movq $0, (%r12)
  movq $0, 8(%r12)
  jmp .fim_libera

.insere_livre:
  movq listaLivre, %r15
  movq %r15, 16(%r12)
  movq %r12, listaLivre

.fim_libera:
  movq $1, %rax
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbp
  ret

.proximo:
  movq %r13, %r14
  movq %r15, %r13
  jmp .buscar

.nao_encontrou:
.erro:
  movq $0, %rax
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbp
  ret

################################################################################
#                               imprimeMapa                                   #
# Imprime a estrutura da heap: headers, blocos livres e ocupados              #
################################################################################
imprimeMapa:
  pushq %rbp
  movq %rsp, %rbp

  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq topoInicialHeap, %r8
  cmpq topoAtual, %r8
  je .vazio

.loop:
  cmpq topoAtual, %r8
  jge .fim_imprime

  movq (%r8), %r12
  movq 8(%r8), %r13
  testq %r13, %r13
  jz .proximo_bloco

  movq $0, %r14
.print_info:
  cmpq $24, %r14
  jge .print_payload
  movq $1, %rax
  movq $1, %rdi
  leaq info, %rsi
  movq $1, %rdx
  syscall
  incq %r14
  jmp .print_info

.print_payload:
  movq $0, %r14
  cmpq $1, %r12
  je .print_ocupado

.print_livre:
  cmpq %r13, %r14
  jge .proximo_bloco
  movq $1, %rax
  movq $1, %rdi
  leaq livre, %rsi
  movq $1, %rdx
  syscall
  incq %r14
  jmp .print_livre

.print_ocupado:
  cmpq %r13, %r14
  jge .proximo_bloco
  movq $1, %rax
  movq $1, %rdi
  leaq ocupado, %rsi
  movq $1, %rdx
  syscall
  incq %r14
  jmp .print_ocupado

.proximo_bloco:
  addq %r13, %r8
  addq $24, %r8
  jmp .loop

.fim_imprime:
  movq $1, %rax
  movq $1, %rdi
  leaq nova_linha, %rsi
  movq $1, %rdx
  syscall
  jmp .sair

.vazio:
  movq $1, %rax
  movq $1, %rdi
  leaq string, %rsi
  movq $8, %rdx
  syscall

.sair:
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret
