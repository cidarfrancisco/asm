// main.c
// Programa principal 
// Objetivo: Interfaz simple para decodificar códigos QR versión 2
//
// Responsabilidades de C:
//   Capturar nombre de archivo
//   Cargar del archivo PBM a memoria, mostrar resultados al usuario
//
// Responsabilidades de ensamblador
//   el procesamiento del QR
//   Detección de patrones
//   Extracción de datos
//   Decodificación

#include <stdio.h>                                       // printf, puts, etc.
#include <stdlib.h>                                      // exit, funciones generales
#include <string.h>                                      // Manejo de cadenas si se ocupa
#include "file_utils.h"                                  // Prototipo de load_pbm_file y funciones de archivo

// Declaración de funciones NASM


/**
 * Decodifica un código QR a partir de una matriz de píxeles
 * 
 * EEntrada : Matriz de 625 bytes (25x25) con valores 0 o 1
 *      size: Tamaño de la matriz (debe ser 25)
 * @param output_text: Buffer donde se guardará el texto (mín 512 bytes)
 * @return: 0 si éxito, -1 si error
 */
extern int qr_decode_matrix(unsigned char* matrix, int size, char* output_text);



// Muestra el banner del programa
void print_banner() {                                    // Encapsula el encabezado bonito del programa
    printf("\n");
    printf("====================================================\n");
    printf("  DECODIFICADOR DE CÓDIGOS QR - Versión 2 (25x25)\n");
    printf("====================================================\n");
    printf("  Proyecto 2 - Arquitectura de Computadoras\n");
    printf("  Instituto Tecnológico de Costa Rica\n");
    printf("====================================================\n");
    printf("\n");
}


// Muestra cómo usar el programa
void print_usage(const char* program_name) {                   // Explica al usuario cómo se ejecuta el programa
    printf("Uso:\n");
    printf("  %s <archivo.pbm>\n\n", program_name);
    printf("Formato soportado:\n");
    printf("  - PBM formato P1 (ASCII)\n");
    printf("  - Tamaño: 25x25 (QR versión 2)\n\n");
    printf("Ejemplo:\n");
    printf("  %s mi_codigo_qr.pbm\n\n", program_name);
    printf("Nota:\n");
    printf("  Si tienes un QR en PNG/JPG, conviértelo primero:\n");
    printf("  $ convert mi_qr.png -threshold 50%% mi_qr.pbm\n");
    printf("\n");
}


// Imprime la matriz en consola lo q es útil para depuración

void print_matrix_debug(unsigned char* matrix, int size) {   // Muestra la matriz 25x25 como texto
    int i, j;
    
    printf("\n[DEBUG] Matriz cargada:\n");
    for (i = 0; i < size; i++) {                             // Recorre filas
        for (j = 0; j < size; j++) {                         //recorre columnas
            printf("%c ", matrix[i * size + j] ? '#' : '.'); // Imprime '#' para 1 y '.' para 0
        }
        printf("\n");
    }
    printf("\n");
}

// Punto de entrada del programa
int main(int argc, char* argv[]) { 
    unsigned char matrix[625];  // Matriz 25x25 = 625 bytes
    char decoded_text[512];     // Buffer para el texto decodificado
    int size;                   //tamaño que se leyó(25 esperado))
    int result;                 //código de retorno de funciones 
    
    // Mostrar banner
    print_banner();
    
    // Verificar argumentos
  if (argc != 2) {                                     // Si no se pasa exactamente 1 argumento (el archivo)
        print_usage(argv[0]);                            // Muestra cómo se usa el programa
        return 1;                                        // Termina con código de error
    }
    
    // --------------------------------------------------------
    // Acá se carga el archivo PBM 
    // --------------------------------------------------------
    printf("[1/3] Cargando archivo PBM...\n");           // Mensaje de progreso
    printf("      Archivo: %s\n", argv[1]);              // Muestra el nombre del archivo que se va a leer
    
    result = load_pbm_file(argv[1], matrix, &size);      // Llama a la función que carga el PBM en la matriz
    
    if (result != 0) {                                   // Si hubo error al cargar
        printf("\n✗ Error al cargar el archivo\n\n");    // Mensaje de error
        return 1;                                        // Termina el programa
    }
    
    printf("      ✓ Archivo cargado correctamente\n");   // Confirma que el archivo se leyó bien
    printf("      Tamaño: %dx%d\n", size, size);         // Muestra el tamaño de la matriz cargada
    
    // Opcional: Mostrar matriz (solo para debug)
    // Descomentar si quieres ver la matriz en consola
    // print_matrix_debug(matrix, size);
    
    // --------------------------------------------------------
    // PASO 2: Decodificar QR (responsabilidad de NASM)
    // --------------------------------------------------------
    printf("\n[2/3] Decodificando código QR...\n");
    printf("      Llamando a función NASM...\n");
    
    // NOTA: Por ahora esta función no existe
    // La implementarás en los siguientes pasos
    // Por el momento, retornará un placeholder
    
    result = qr_decode_matrix(matrix, size, decoded_text);   // Llama a la función implementada en ASM
    
     if (result != 0) {                                   // Si la decodificación falla
        printf("\n✗ Error al decodificar el QR (código: %d)\n", result);      // Mensaje de error con código
        if (result == -1) {
            printf("  Error: Tamaño de matriz incorrecto\n");
        } else if (result == -2) {
            printf("  Error: No se encontraron los 3 finder patterns\n");
        } else if (result == -3) {
            printf("  Error: Fallo en decodificación de bits a texto\n");
        }
        printf("  Posibles causas:\n");                  // Explica posibles motivos
        printf("  - QR dañado o incompleto\n");          // El QR puede estar mal formado
        printf("  - Formato no soportado\n");            // No es versión 2 o tamaño incorrecto
        printf("  - Errores no corregibles\n\n");        // Demasiados errores para corregir con ECC
        return 1;                                        // Termina con error
    }
    
    printf("      ✓ Decodificación completada\n");
    
    printf("\n[3/3] Resultado:\n");                      // Encabezado de la sección final
    printf("---------------------------------------------------\n"); // Separador visual
    printf("\n");                                        // Línea en blanco
    printf("  Texto decodificado:\n");                   // Etiqueta
    printf("  \"%s\"\n", decoded_text);                  // Muestra el texto devuelto por qr_decode_matrix
    printf("\n");                                        // Línea en blanco
    printf("---------------------------------------------------\n\n"); // Cierre visual
    
    return 0;
}
