# Makefile para compilar Assembly + C
# Alvo principal: alocar

# Nomes dos arquivos
ASM_SRC = meuAlocador.s
ASM_OBJ = meuAlocador.o
C_SRC   = avalia.c
C_OBJ   = avalia.o
EXEC    = alocar

# Compiladores
AS      = as
CC      = gcc

# Flags
ASFLAGS = -g -o

# Alvo padrão
all: $(EXEC)

# Compila o arquivo .s para .o
$(ASM_OBJ): $(ASM_SRC)
	$(AS) $(ASFLAGS) $@ $<

# Compila o C para .o
$(C_OBJ): $(C_SRC)
	$(CC) -c -o $@ $<

# Linka os objetos
$(EXEC): $(ASM_OBJ) $(C_OBJ)
	$(CC) -no-pie -o $@ $^

# Limpeza
clean:
	rm -f *.o $(EXEC)

