// file_utils.h
// Utilidades para manejo de archivos PBM
// Objetivo:
//   Proveer funciones para cargar archivos PBM en memoria
//

#ifndef FILE_UTILS_H
#define FILE_UTILS_H

/**
 * Carga un archivo PBM P1 (ASCII) en una matriz
 * 
 * @param filename: Ruta del archivo .pbm
 * @param matrix: Buffer donde guardar la matriz (debe tener 625 bytes)
 * @param size: Puntero donde guardar el tamaño (debe ser 25)
 * @return: 0 si éxito, -1 si error
 * 
 * Esta función solo lee el archivo y convierte a matriz.
 *    
 */
int load_pbm_file(const char* filename, unsigned char* matrix, int* size);

/**
 * Guarda una matriz en formato PBM P1 (ASCII)
 * 
 * @param filename: Ruta del archivo de salida
 * @param matrix: Matriz a guardar
 * @param size: Tamaño de la matriz (debe ser 25)
 * @return: 0 si éxito, -1 si error
 */
int save_pbm_file(const char* filename, unsigned char* matrix, int size);

/**
 * Verifica si un archivo existe
 * 
 * @param filename: Ruta del archivo
 * @return: 1 si existe, 0 si no
 */
int file_exists(const char* filename);

#endif // FILE_UTILS_H
