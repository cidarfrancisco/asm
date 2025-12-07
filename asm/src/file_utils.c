// file_utils.c
// Implementación de utilidades de archivos


#include "file_utils.h"
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

// 
int file_exists(const char* filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

// Lee un archivo PBM y lo carga en una matriz
int load_pbm_file(const char* filename, unsigned char* matrix, int* size) {
    FILE* file;
    char header[10];
    int width, height;
    int i, value;
    
    // Validar parámetros
    if (filename == NULL || matrix == NULL || size == NULL) {
        fprintf(stderr, "Error: Parámetros inválidos\n");
        return -1;
    }
    
    // Verificar que el archivo existe
    if (!file_exists(filename)) {
        fprintf(stderr, "Error: El archivo '%s' no existe\n", filename);
        return -1;
    }
    
    // Abrir archivo
    file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "Error: No se pudo abrir '%s'\n", filename);
        return -1;
    }
    
    // Leer header (debe ser "P1")
    if (fscanf(file, "%s", header) != 1) {
        fprintf(stderr, "Error: No se pudo leer el header\n");
        fclose(file);
        return -1;
    }
    
    if (strcmp(header, "P1") != 0) {
        fprintf(stderr, "Error: Formato incorrecto (esperado P1, recibido %s)\n", header);
        fclose(file);
        return -1;
    }
    
    // Leer dimensiones
    if (fscanf(file, "%d %d", &width, &height) != 2) {
        fprintf(stderr, "Error: No se pudieron leer las dimensiones\n");
        fclose(file);
        return -1;
    }
    
    // Verificar que sea 25x25 (versión 2 del QR)
    if (width != 25 || height != 25) {
        fprintf(stderr, "Error: El QR debe ser 25x25 (versión 2)\n");
        fprintf(stderr, "       El archivo es %dx%d\n", width, height);
        fclose(file);
        return -1;
    }
    
    // Leer los 625 valores (25 * 25)
    for (i = 0; i < 625; i++) {
        if (fscanf(file, "%d", &value) != 1) {
            fprintf(stderr, "Error: Lectura incompleta (posición %d)\n", i);
            fclose(file);
            return -1;
        }
        
        // Validar que sea 0 o 1
        if (value != 0 && value != 1) {
            fprintf(stderr, "Error: Valor inválido %d en posición %d\n", value, i);
            fclose(file);
            return -1;
        }
        
        matrix[i] = (unsigned char)value;
    }
    
    fclose(file);
    *size = 25;
    
    return 0;
}


// Guarda una matriz en formato PBM
int save_pbm_file(const char* filename, unsigned char* matrix, int size) {
    FILE* file;
    int i, j;
    
    // Validar parámetros
    if (filename == NULL || matrix == NULL || size != 25) {
        fprintf(stderr, "Error: Parámetros inválidos para guardar PBM\n");
        return -1;
    }
    
    // Abrir archivo para escritura
    file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Error: No se pudo crear '%s'\n", filename);
        return -1;
    }
    
    // Escribir header
    fprintf(file, "P1\n");
    fprintf(file, "%d %d\n", size, size);
    
    // Escribir matriz
    for (i = 0; i < size; i++) {
        for (j = 0; j < size; j++) {
            fprintf(file, "%d", matrix[i * size + j]);
            if (j < size - 1) {
                fprintf(file, " ");
            }
        }
        fprintf(file, "\n");
    }
    
    fclose(file);
    return 0;
}
