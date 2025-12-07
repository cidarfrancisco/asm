// encoder_main.c
// Programa para codificar texto en un código QR versión 2
// Genera un archivo PBM con el código QR

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declaraciones de funciones en ensamblador

// De qr_encode_data.asm
extern int encode_text_to_bits(const char* text);
extern void place_bits_zigzag(void);
extern void* encoded_bits;
extern unsigned int encoded_bit_len;
extern void* encode_matrix_ptr;

// De qr_pbm.asm
extern unsigned char matriz[625];
extern void qr_generate_matrix_only(void);
extern int qr_write_pbm(const char* filename);

void print_banner(void) {
    printf("\n");
    printf("====================================================\n");
    printf("  CODIFICADOR DE CÓDIGOS QR - Versión 2 (25x25)\n");
    printf("====================================================\n");
    printf("  Proyecto 2 - Arquitectura de Computadoras\n");
    printf("  Instituto Tecnológico de Costa Rica\n");
    printf("====================================================\n");
    printf("\n");
}

void print_usage(const char* program_name) {
    printf("Uso:\n");
    printf("  %s <texto> [archivo_salida.pbm]\n\n", program_name);
    printf("Parámetros:\n");
    printf("  texto           - Texto a codificar (máximo 32 caracteres)\n");
    printf("  archivo_salida  - Nombre del archivo PBM (opcional, default: qr_output.pbm)\n\n");
    printf("Ejemplo:\n");
    printf("  %s \"Hola Mundo\"\n", program_name);
    printf("  %s \"TEC 2025\" mi_qr.pbm\n\n", program_name);
}

int main(int argc, char* argv[]) {
    const char* text;
    const char* output_file;
    int result;

    print_banner();

    // Verificar argumentos
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    text = argv[1];
    output_file = (argc >= 3) ? argv[2] : "qr_output.pbm";

    // Verificar longitud del texto
    size_t text_len = strlen(text);
    if (text_len > 32) {
        printf("✗ Error: El texto es demasiado largo (%zu caracteres)\n", text_len);
        printf("  Máximo permitido: 32 caracteres\n\n");
        return 1;
    }

    printf("[1/4] Codificando texto...\n");
    printf("      Texto: \"%s\" (%zu caracteres)\n", text, text_len);

    // Codificar texto a bits
    result = encode_text_to_bits(text);
    if (result != 0) {
        printf("\n✗ Error al codificar el texto\n\n");
        return 1;
    }

    printf("      ✓ Texto codificado exitosamente\n");
    printf("      Bits generados: %u\n", encoded_bit_len);

    // Generar matriz QR con patrones base
    printf("\n[2/4] Generando matriz QR...\n");
    qr_generate_matrix_only();
    printf("      ✓ Patrones base generados\n");

    // Colocar bits codificados en la matriz
    printf("\n[3/4] Colocando datos en matriz...\n");
    encode_matrix_ptr = matriz;  // Establecer puntero a la matriz
    place_bits_zigzag();
    printf("      ✓ Datos colocados en patrón zigzag\n");

    // Guardar archivo PBM
    printf("\n[4/4] Guardando archivo PBM...\n");
    printf("      Archivo: %s\n", output_file);

    result = qr_write_pbm(output_file);
    if (result != 0) {
        printf("\n✗ Error al guardar el archivo\n\n");
        return 1;
    }

    printf("      ✓ Archivo guardado correctamente\n");

    printf("\n");
    printf("====================================================\n");
    printf("  ✓ CÓDIGO QR GENERADO EXITOSAMENTE\n");
    printf("====================================================\n");
    printf("\n");
    printf("Para visualizar el QR:\n");
    printf("  - Linux/Mac: display %s  (ImageMagick)\n", output_file);
    printf("  - Convertir a PNG: convert %s qr.png\n", output_file);
    printf("\n");
    printf("Para decodificar:\n");
    printf("  ./qr_decoder %s\n", output_file);
    printf("\n");

    return 0;
}
