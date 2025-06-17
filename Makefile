# Compilador e flags
CC = gcc
CFLAGS = -no-pie

# Arquivos-fonte
ASM_SRC = meuAlocador.s
ASM_OBJ = meuAlocador.o
EXEMPLO_SRC = exemplo.c
AVALIA_SRC = avalia.c

# Executáveis
EXEMPLO_BIN = ExemploAloca
AVALIA_BIN = AvaliaAloca

# Regra padrão: compila os dois binários
all: $(EXEMPLO_BIN) $(AVALIA_BIN)

# Compilação do alocador
$(ASM_OBJ): $(ASM_SRC)
	$(CC) $(CFLAGS) -c $(ASM_SRC) -o $(ASM_OBJ)

# Compilação do ExemploAloca
$(EXEMPLO_BIN): $(EXEMPLO_SRC) $(ASM_OBJ)
	$(CC) $(CFLAGS) $(EXEMPLO_SRC) $(ASM_OBJ) -o $(EXEMPLO_BIN)

# Compilação do AvaliaAloca
$(AVALIA_BIN): $(AVALIA_SRC) $(ASM_OBJ)
	$(CC) $(CFLAGS) $(AVALIA_SRC) $(ASM_OBJ) -o $(AVALIA_BIN)

# Limpeza
clean:
	rm -f *.o *.txt $(EXEMPLO_BIN) $(AVALIA_BIN)
