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
  pushq %rbp                  # Salva base da pilha
  movq  %rsp, %rbp            # Cria novo frame da pilha

  movq  $12, %rax             # syscall number: brk
  movq  $0,  %rdi             # argumento: NULL -> retorna topo atual da heap
  syscall                     # executa brk(0)

  movq  %rax, topoInicialHeap # armazena início da heap retornado por brk
  movq  %rax, topoAtual       # inicializa topoAtual com mesmo valor

  popq  %rbp                  # Restaura base da pilha
  ret                         # Retorna da função

################################################################################
#                              finalizaAlocador                               #
# Libera toda a heap voltando para o estado inicial                           #
################################################################################
finalizaAlocador:
  pushq %rbp                  # Salva base da pilha
  movq  %rsp, %rbp            # Cria novo frame

  movq  $12, %rax             # syscall number: brk
  movq  topoInicialHeap, %rdi # argumento: endereço inicial salvo
  syscall                     # executa brk(topoInicialHeap)

  movq $0, listaLivre         # esvazia lista de blocos livres
  movq $0, listaOcupado       # esvazia lista de blocos ocupados

  popq  %rbp                  # Restaura base da pilha
  ret                         # Retorna da função

################################################################################
#                                 alocaMem                                    #
# Aloca memória de tamanho `rdi`, procurando bloco livre ou expandindo heap   #
################################################################################
alocaMem:
  pushq %rbp                  # Salva base da pilha
  movq %rsp, %rbp             # Cria novo frame

  pushq %rbx                  # Salva registradores usados
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq listaLivre, %r12       # r12 := ponteiro para o primeiro bloco livre
  movq $0, %r13               # r13 := anterior do bloco livre (NULL inicialmente)

.encontrar_bloco_livre:
  cmpq $0, %r12               # Se não há blocos livres (r12 == NULL)
  je .alocar_novo_bloco       # -> vai direto alocar novo bloco

  movq 8(%r12), %r14          # r14 := tamanho do bloco livre atual
  movq 16(%r12), %r15         # r15 := próximo bloco livre na lista

  cmpq %rdi, %r14             # Se bloco é pequeno demais para a requisição
  jl .iterar                  # -> continua procurando

  cmpq $0, %r13               # Se é o primeiro bloco da lista
  jne .ajustar_livre          # Se não for o primeiro, remove r12 da lista
  movq %r15, listaLivre       # Senão, listaLivre := próximo bloco
  jmp .usar_bloco             # Usa esse bloco livre

.ajustar_livre:
  movq %r15, 16(%r13)         # r13->prox := r15 (remove r12 da lista encadeada)

.iterar:
  movq %r12, %r13             # anterior := atual
  movq %r15, %r12             # atual := próximo
  jmp .encontrar_bloco_livre  # volta para verificar novo bloco

.usar_bloco:
  movq $1, (%r12)             # marca o bloco como ocupado
  movq listaOcupado, %rcx     # obtém cabeça da lista de blocos ocupados
  movq %rcx, 16(%r12)         # próximo do novo ocupado := lista atual
  movq %r12, listaOcupado     # listaOcupado := bloco atual

  movq %r12, %rax             # rax := endereço do bloco (início da metadata)
  addq $24, %rax              # rax := endereço do payload (dados do usuário)

  popq %r15                   # Restaura registradores
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret                         # Retorna ponteiro para área alocada

.alocar_novo_bloco:
  movq topoAtual, %rbx        # rbx := início do novo bloco (aponta para topo atual)
  movq topoAtual, %r10        # r10 := também guarda topoAtual
  movq %rdi, %r9              # r9 := tamanho solicitado
  addq %rdi, %r10             # r10 := topoAtual + tamanho
  addq $24, %r10              # r10 := topoAtual + tamanho + metadata

  movq $12, %rax              # syscall brk
  movq %r10, %rdi             # solicita espaço até (topo + tamanho + metadata)
  syscall

  movq %rax, topoAtual        # atualiza topo da heap

  movq $1, (%rbx)             # status := ocupado
  movq %r9, 8(%rbx)           # tamanho := tamanho solicitado
  movq listaOcupado, %rcx     # próximo := listaOcupado
  movq %rcx, 16(%rbx)         # vincula bloco à lista
  movq %rbx, listaOcupado     # adiciona novo bloco como cabeça da lista

  movq %rbx, %rax             # rax := início do bloco (metadata)
  addq $24, %rax              # rax := endereço do payload

  popq %r15                   # Restaura registradores
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret                         # Retorna ponteiro para dados do usuário

################################################################################
#                                 liberaMem                                   #
# Libera um bloco previamente alocado e faz fusão com vizinhos, se possível   #
################################################################################
liberaMem:
  pushq %rbp                   # Salva base da pilha
  movq %rsp, %rbp              # Cria novo frame de pilha

  pushq %r12                   # Salva registradores usados
  pushq %r13
  pushq %r14
  pushq %r15

  cmpq $0, %rdi                # Verifica se ponteiro é nulo
  je .erro                     # Se sim, não faz nada

  movq %rdi, %r12              # r12 := ptr recebido
  subq $24, %r12               # r12 := início do bloco (metadata)

  movq listaOcupado, %r13      # r13 := ponteiro para início da lista de blocos ocupados
  movq $0, %r14                # r14 := bloco anterior (NULL)

.buscar:
  cmpq $0, %r13                # Se fim da lista ocupada
  je .nao_encontrou            # Se bloco não está na lista → erro

  movq 16(%r13), %r15          # r15 := próximo bloco da lista
  cmpq %r12, %r13              # Se encontrou o bloco a ser liberado
  jne .proximo                 # Se não for, continua buscando

  cmpq $0, %r14
  jne .ajusta_ocupado          # Se há anterior, atualiza ponteiro dele
  movq %r15, listaOcupado      # Se é o primeiro, atualiza cabeça da lista
  jmp .liberar                 # Vai liberar

.ajusta_ocupado:
  movq %r15, 16(%r14)          # anterior->prox := atual->prox (remove da lista)

.liberar:
  movq $0, (%r12)              # Marca o bloco como livre (status := 0)

  movq 8(%r12), %r10           # r10 := tamanho do bloco atual
  lea 24(%r12,%r10), %r11      # r11 := endereço do próximo bloco na memória (r12 + 24 + tamanho)

  movq topoAtual, %r9
  cmpq %r9, %r11               # Se o endereço ultrapassa o topo
  jge .verifica_esquerda       # → não há vizinho à direita

  cmpq $0, (%r11)              # Se bloco à direita está livre
  jne .verifica_esquerda

  # Fusão com bloco à direita
  movq 8(%r11), %r10           # r10 := tamanho do bloco à direita
  addq %r10, 8(%r12)           # soma tamanhos (payloads)
  addq $24, 8(%r12)            # soma metadata à fusão

  movq $0, (%r11)              # Zera status do bloco absorvido
  movq $0, 8(%r11)             # Zera tamanho do bloco absorvido

  # Remove r11 da listaLivre
  movq listaLivre, %r8         # r8 := atual
  movq $0, %r9                 # r9 := anterior

.encontra_dir:
  cmpq $0, %r8
  je .verifica_esquerda        # não encontrou na lista
  cmpq %r11, %r8
  je .ajusta_dir               # achou na lista livre
  movq %r8, %r9                # avança: r9 := anterior
  movq 16(%r8), %r8            # r8 := próximo
  jmp .encontra_dir

.ajusta_dir:
  cmpq $0, %r9
  jne 1f
  movq 16(%r11), %r10          # Se é o primeiro da lista
  movq %r10, listaLivre        # atualiza cabeça da lista
  jmp .verifica_esquerda
1:
  movq 16(%r11), %r15
  movq %r15, 16(%r9)           # r9->prox := r11->prox

.verifica_esquerda:
  movq listaLivre, %r8         # r8 := bloco livre atual

.buscar_esq:
  cmpq $0, %r8
  je .insere_livre             # Se chegou ao fim -> insere como novo livre

  movq 8(%r8), %r10            # r10 := tamanho do bloco r8
  lea 24(%r8,%r10), %r11       # r11 := fim físico do bloco r8
  cmpq %r11, %r12              # Se r8 termina exatamente onde começa r12
  je .funde                    # -> são adjacentes -> pode fundir

  movq 16(%r8), %r8            # avança para próximo bloco livre
  jmp .buscar_esq

.funde:
  movq 8(%r12), %r10           # r10 := tamanho do bloco a ser fundido
  addq %r10, 8(%r8)            # aumenta tamanho do r8
  addq $24, 8(%r8)             # soma o metadata de r12

  movq $0, (%r12)              # limpa metadata de r12 (absorvido)
  movq $0, 8(%r12)
  jmp .fim_libera              # termina fusão

.insere_livre:
  movq listaLivre, %r15
  movq %r15, 16(%r12)          # novo->prox := listaLivre
  movq %r12, listaLivre        # listaLivre := novo

.fim_libera:
  movq $1, %rax                # sucesso
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbp
  ret

.proximo:
  movq %r13, %r14              # anterior := atual
  movq %r15, %r13              # atual := próximo
  jmp .buscar                  # continua busca

.nao_encontrou:
.erro:
  movq $0, %rax                # erro: ponteiro inválido ou não encontrado
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
  pushq %rbp                    # Salva base da pilha
  movq %rsp, %rbp               # Cria novo frame de pilha

  pushq %rbx                    # Salva registradores usados
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15

  movq topoInicialHeap, %r8     # r8 := ponteiro para início da heap
  cmpq topoAtual, %r8           # Se topoInicial == topoAtual -> heap está vazia
  je .vazio                     # -> imprime "<vazio>"

.loop:
  cmpq topoAtual, %r8           # Enquanto r8 < topoAtual
  jge .fim_imprime              # → fim do mapa

  movq (%r8), %r12              # r12 := status do bloco (0 = livre, 1 = ocupado)
  movq 8(%r8), %r13             # r13 := tamanho do bloco
  testq %r13, %r13              # Se tamanho == 0
  jz .proximo_bloco             # -> bloco vazio, pula

  movq $0, %r14                 # r14 := contador de bytes para imprimir '#'
.print_info:
  cmpq $24, %r14                # METADATA_SIZE (tamanho do cabeçalho)
  jge .print_payload            # Depois de imprimir 24 '#', vai pro payload
  movq $1, %rax                 # syscall: write
  movq $1, %rdi                 # fd: stdout
  leaq info, %rsi               # buffer: caractere '#'
  movq $1, %rdx                 # length: 1 byte
  syscall
  incq %r14                     # i++
  jmp .print_info

.print_payload:
  movq $0, %r14                 # reseta contador
  cmpq $1, %r12                 # Se status == 1 (ocupado)
  je .print_ocupado             # → imprime '+'

.print_livre:
  cmpq %r13, %r14               # Enquanto i < tamanho
  jge .proximo_bloco
  movq $1, %rax                 # syscall: write
  movq $1, %rdi                 # stdout
  leaq livre, %rsi              # caractere '-'
  movq $1, %rdx
  syscall
  incq %r14
  jmp .print_livre

.print_ocupado:
  cmpq %r13, %r14               # Enquanto i < tamanho
  jge .proximo_bloco
  movq $1, %rax                 # syscall: write
  movq $1, %rdi
  leaq ocupado, %rsi            # caractere '+'
  movq $1, %rdx
  syscall
  incq %r14
  jmp .print_ocupado

.proximo_bloco:
  addq %r13, %r8                # Avança ptr pelo tamanho do payload
  addq $24, %r8                 # Avança também o cabeçalho
  jmp .loop

.fim_imprime:
  movq $1, %rax                 # syscall: write
  movq $1, %rdi
  leaq nova_linha, %rsi         # caractere '\n'
  movq $1, %rdx
  syscall
  jmp .sair

.vazio:
  movq $1, %rax                 # syscall: write
  movq $1, %rdi
  leaq string, %rsi             # imprime "<vazio>\n"
  movq $8, %rdx                 # 8 bytes
  syscall

.sair:
  popq %r15                     # Restaura registradores
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  popq %rbp
  ret