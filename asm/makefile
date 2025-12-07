# Makefile para Codificador y Decodificador de QR
# Proyecto 2 - Arquitectura de Computadoras

# Compiladores
CC = gcc
NASM = nasm

# Flags
CFLAGS = -Wall -Wextra -g -m32
NASMFLAGS = -f elf32 -I.
LDFLAGS = -m32

# Directorios
SRC_DIR = src
ASM_DIR = $(SRC_DIR)/asm

# Archivos fuente - DECODER
C_SOURCES_DECODER = $(SRC_DIR)/main.c $(SRC_DIR)/file_utils.c
ASM_SOURCES_DECODER = $(ASM_DIR)/qr_decode.asm \
                      $(ASM_DIR)/qr_detect.asm \
                      $(ASM_DIR)/qr_utils.asm \
                      $(ASM_DIR)/qr_extract.asm \
                      $(ASM_DIR)/qr_decode_data.asm \
                      $(ASM_DIR)/ecc_parity2d.asm

# Archivos fuente - ENCODER
C_SOURCES_ENCODER = $(SRC_DIR)/encoder_main.c
ASM_SOURCES_ENCODER = $(ASM_DIR)/qr_encode_data.asm \
                      $(ASM_DIR)/qr_pbm.asm \
                      $(ASM_DIR)/ecc_parity2d.asm

# Archivos objeto
C_OBJECTS_DECODER = $(C_SOURCES_DECODER:.c=.o)
ASM_OBJECTS_DECODER = $(ASM_SOURCES_DECODER:.asm=.o)

C_OBJECTS_ENCODER = $(C_SOURCES_ENCODER:.c=.o)
ASM_OBJECTS_ENCODER = $(ASM_SOURCES_ENCODER:.asm=.o)

IO_OBJECT = io.o

# Ejecutables
TARGET_DECODER = qr_decoder
TARGET_ENCODER = qr_encoder

# ----------------------------------------------------------
# Reglas principales
# ----------------------------------------------------------

.PHONY: all clean rebuild help

all: $(TARGET_DECODER) $(TARGET_ENCODER)
	@echo ""
	@echo "======================================================"
	@echo "  ✓ Compilación exitosa"
	@echo "======================================================"
	@echo ""
	@echo "Codificador:"
	@echo "  ./$(TARGET_ENCODER) \"texto\" [salida.pbm]"
	@echo ""
	@echo "Decodificador:"
	@echo "  ./$(TARGET_DECODER) archivo.pbm"
	@echo ""
	@echo "Ejemplo completo:"
	@echo "  ./$(TARGET_ENCODER) \"Hola TEC\""
	@echo "  ./$(TARGET_DECODER) qr_output.pbm"
	@echo ""

# Enlazar decodificador
$(TARGET_DECODER): $(C_OBJECTS_DECODER) $(ASM_OBJECTS_DECODER) $(IO_OBJECT)
	@echo "Enlazando decodificador..."
	$(CC) $(LDFLAGS) -o $@ $^
	@echo "✓ Decodificador compilado"

# Enlazar codificador
$(TARGET_ENCODER): $(C_OBJECTS_ENCODER) $(ASM_OBJECTS_ENCODER) $(IO_OBJECT)
	@echo "Enlazando codificador..."
	$(CC) $(LDFLAGS) -o $@ $^
	@echo "✓ Codificador compilado"

# Compilar archivos C
%.o: %.c
	@echo "Compilando $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Ensamblar archivos NASM
%.o: %.asm
	@echo "Ensamblando $<..."
	$(NASM) $(NASMFLAGS) $< -o $@

# Limpiar archivos generados
clean:
	@echo "Limpiando archivos generados..."
	@rm -f $(C_OBJECTS_DECODER) $(ASM_OBJECTS_DECODER) $(TARGET_DECODER)
	@rm -f $(C_OBJECTS_ENCODER) $(ASM_OBJECTS_ENCODER) $(TARGET_ENCODER)
	@rm -f $(SRC_DIR)/*.o $(ASM_DIR)/*.o
	@rm -f temp*.pbm qr_output.pbm test*.pbm
	@echo "✓ Limpieza completada"

# Limpiar y recompilar
rebuild: clean all

# Ayuda
help:
	@echo "======================================================"
	@echo "  Makefile - Sistema QR"
	@echo "======================================================"
	@echo ""
	@echo "Objetivos disponibles:"
	@echo "  make         - Compilar ambos programas"
	@echo "  make clean   - Eliminar archivos generados"
	@echo "  make rebuild - Limpiar y recompilar"
	@echo "  make help    - Mostrar esta ayuda"
	@echo ""
	@echo "Ejecutables generados:"
	@echo "  qr_encoder  - Codificador (texto → QR)"
	@echo "  qr_decoder  - Decodificador (QR → texto)"
	@echo ""
