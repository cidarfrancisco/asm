# Sistema de Corrección de Errores - Paridad 2D

## Descripción
Sistema simple y eficiente de detección y corrección de errores usando paridad bidimensional.

## Características
- **Capacidad de corrección:** 1 error por bloque de 32 bytes
- **Overhead:** 12 bytes (8 fila + 4 columna)
- **Total de bytes transmitidos:** 44 (32 datos + 12 paridad)
- **Complejidad:** Baja - ideal para proyecto educativo

## Cómo funciona

### Codificación (ecc_encode)
1. Organiza 32 bytes en matriz 8×4:
   ```
   Fila 0: [byte0] [byte1] [byte2] [byte3]
   Fila 1: [byte4] [byte5] [byte6] [byte7]
   ...
   Fila 7: [byte28][byte29][byte30][byte31]
   ```

2. Calcula paridad XOR por fila (8 bytes):
   ```
   parity_fila[i] = byte[i*4] ^ byte[i*4+1] ^ byte[i*4+2] ^ byte[i*4+3]
   ```

3. Calcula paridad XOR por columna (4 bytes):
   ```
   parity_col[j] = byte[j] ^ byte[4+j] ^ byte[8+j] ^ ... ^ byte[28+j]
   ```

### Decodificación (ecc_decode)
1. Recalcula paridades de fila y columna
2. Compara con paridades recibidas
3. Si hay diferencia:
   - Fila con error → indica fila
   - Columna con error → indica columna
   - Intersección → posición exacta del error
4. Corrige el byte usando: `byte_correcto = byte_erróneo ^ parity_fila ^ otros_bytes_fila`

## Ventajas vs Reed-Solomon
- ✅ **Mucho más simple:** ~250 líneas vs ~500+ líneas
- ✅ **Más eficiente:** 12 bytes overhead vs 22 bytes
- ✅ **Fácil de debuggear**
- ✅ **Apropiado para proyecto educativo**
- ⚠️ **Limitación:** Solo corrige 1 error (RS corrige hasta 11)

## Uso en el proyecto

### En codificación (qr_encode_data.asm):
```asm
extern ecc_encode
extern ecc_get_row_parity
extern ecc_get_col_parity

; Después de codificar los 32 bytes de datos
mov esi, datos_32_bytes
call ecc_encode

; Obtener paridades para agregar al QR
call ecc_get_row_parity    ; EAX = puntero a 8 bytes
call ecc_get_col_parity    ; EAX = puntero a 4 bytes
```

### En decodificación (qr_decode_data.asm):
```asm
extern ecc_decode
extern ecc_get_corrected_data

; Después de extraer 44 bytes del QR
mov esi, datos_44_bytes    ; 32 datos + 8 fila + 4 col
call ecc_decode            ; EAX = 0 (sin error), 1 (corregido), -1 (no corregible)

call ecc_get_corrected_data ; EAX = puntero a 32 bytes corregidos
```

## Archivos
- `src/asm/ecc_parity2d.asm` - Implementación completa
- `src/asm/qr_decode_data.asm` - Integración en decodificador (modificado)
- `makefile` - Actualizado para incluir ecc_parity2d.asm

## Comparación con alternativas

| Sistema           | Overhead | Corrección | Complejidad |
|-------------------|----------|------------|-------------|
| **Paridad 2D**    | 12 bytes | 1 error    | Baja        |
| Hamming (7,4)     | ~15 bytes| 1 bit      | Media       |
| Reed-Solomon      | 22 bytes | 11 errores | Alta        |
| Checksum/CRC      | 2-4 bytes| 0 (solo detecta) | Baja   |

## Notas
Este sistema es suficiente para QR de buena calidad. En casos reales con múltiples errores, se necesitaría Reed-Solomon completo o simplemente volver a escanear el QR.
