; ============================================================
; ecc_parity2d.asm
; Corrección de errores usando Paridad 2D
; Organiza 32 bytes en matriz 8×4, calcula paridad por fila/columna
; Puede corregir 1 error por bloque
; ============================================================

%include "io.mac"

.DATA
    ROWS    equ 8       ; 8 filas
    COLS    equ 4       ; 4 columnas

.UDATA
    ; Datos recibidos: 32 bytes + 8 paridades de fila + 4 de columna = 44 total
    global ecc_received_data
    ecc_received_data   resb 32     ; datos originales

    global ecc_row_parity
    ecc_row_parity      resb 8      ; paridad de cada fila

    global ecc_col_parity
    ecc_col_parity      resb 4      ; paridad de cada columna

    global ecc_corrected_data
    ecc_corrected_data  resb 32     ; datos corregidos

    ; Variables de trabajo
    error_row           resd 1      ; fila con error (-1 si ninguna)
    error_col           resd 1      ; columna con error (-1 si ninguna)

.CODE

; ============================================================
; FUNCIÓN: ecc_encode
; Genera paridades de fila y columna para 32 bytes
; ============================================================
; Inputs:
;   ESI = puntero a datos de entrada (32 bytes)
; Output:
;   ecc_row_parity[] = 8 bytes de paridad de fila
;   ecc_col_parity[] = 4 bytes de paridad de columna
;   EAX = 0 si éxito
; ============================================================
global ecc_encode
ecc_encode:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Copiar datos a buffer interno
    mov edi, ecc_received_data
    mov ecx, 32
    rep movsb

    ; Calcular paridades de fila
    xor ebx, ebx                    ; ebx = índice de fila (0-7)

.row_loop:
    cmp ebx, ROWS
    jge .calc_col_parity

    xor al, al                      ; acumulador de paridad
    xor ecx, ecx                    ; ecx = índice de columna (0-3)

.row_parity_loop:
    cmp ecx, COLS
    jge .save_row_parity

    ; Calcular offset: fila * COLS + columna
    mov edx, ebx
    shl edx, 2                      ; edx = fila * 4
    add edx, ecx                    ; edx = fila * 4 + col

    xor al, [ecc_received_data + edx]   ; XOR con dato

    inc ecx
    jmp .row_parity_loop

.save_row_parity:
    mov [ecc_row_parity + ebx], al
    inc ebx
    jmp .row_loop

.calc_col_parity:
    ; Calcular paridades de columna
    xor ecx, ecx                    ; ecx = índice de columna (0-3)

.col_loop:
    cmp ecx, COLS
    jge .done

    xor al, al                      ; acumulador de paridad
    xor ebx, ebx                    ; ebx = índice de fila (0-7)

.col_parity_loop:
    cmp ebx, ROWS
    jge .save_col_parity

    ; Calcular offset: fila * COLS + columna
    mov edx, ebx
    shl edx, 2                      ; edx = fila * 4
    add edx, ecx                    ; edx = fila * 4 + col

    xor al, [ecc_received_data + edx]   ; XOR con dato

    inc ebx
    jmp .col_parity_loop

.save_col_parity:
    mov [ecc_col_parity + ecx], al
    inc ecx
    jmp .col_loop

.done:
    xor eax, eax                    ; éxito

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: ecc_decode
; Detecta y corrige errores usando paridades 2D
; ============================================================
; Inputs:
;   ESI = puntero a datos recibidos (44 bytes: 32 datos + 8 + 4 paridad)
; Output:
;   ecc_corrected_data[] = datos corregidos
;   EAX = número de errores corregidos (0, 1), -1 si no se puede corregir
; ============================================================
global ecc_decode
ecc_decode:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Copiar datos recibidos (32 bytes)
    mov edi, ecc_received_data
    mov ecx, 32
    rep movsb

    ; Copiar paridades de fila recibidas (8 bytes)
    mov edi, ecc_row_parity
    mov ecx, 8
    rep movsb

    ; Copiar paridades de columna recibidas (4 bytes)
    mov edi, ecc_col_parity
    mov ecx, 4
    rep movsb

    ; Inicializar: sin error detectado
    mov dword [error_row], -1
    mov dword [error_col], -1

    ; Verificar paridades de fila
    xor ebx, ebx                    ; ebx = índice de fila

.check_row_loop:
    cmp ebx, ROWS
    jge .check_columns

    xor al, al                      ; recalcular paridad
    xor ecx, ecx                    ; columna

.calc_row_parity:
    cmp ecx, COLS
    jge .compare_row_parity

    mov edx, ebx
    shl edx, 2
    add edx, ecx
    xor al, [ecc_received_data + edx]

    inc ecx
    jmp .calc_row_parity

.compare_row_parity:
    cmp al, [ecc_row_parity + ebx]
    je .next_row                    ; paridad correcta

    ; Paridad incorrecta: marcar fila con error
    mov [error_row], ebx

.next_row:
    inc ebx
    jmp .check_row_loop

.check_columns:
    ; Verificar paridades de columna
    xor ecx, ecx                    ; ecx = índice de columna

.check_col_loop:
    cmp ecx, COLS
    jge .apply_correction

    xor al, al                      ; recalcular paridad
    xor ebx, ebx                    ; fila

.calc_col_parity:
    cmp ebx, ROWS
    jge .compare_col_parity

    mov edx, ebx
    shl edx, 2
    add edx, ecx
    xor al, [ecc_received_data + edx]

    inc ebx
    jmp .calc_col_parity

.compare_col_parity:
    cmp al, [ecc_col_parity + ecx]
    je .next_col                    ; paridad correcta

    ; Paridad incorrecta: marcar columna con error
    mov [error_col], ecx

.next_col:
    inc ecx
    jmp .check_col_loop

.apply_correction:
    ; Copiar datos a buffer de salida
    mov esi, ecc_received_data
    mov edi, ecc_corrected_data
    mov ecx, 32
    rep movsb

    ; Verificar si hay error
    mov eax, [error_row]
    cmp eax, -1
    je .no_error                    ; sin error en filas

    mov ebx, [error_col]
    cmp ebx, -1
    je .uncorrectable               ; error solo en fila (múltiples errores)

    ; Corregir el error en posición [error_row][error_col]
    mov edx, eax                    ; edx = error_row
    shl edx, 2                      ; edx = error_row * 4
    add edx, ebx                    ; edx = error_row * 4 + error_col

    ; Recalcular el byte correcto usando paridades
    xor al, al
    xor ecx, ecx

.recalc_byte:
    cmp ecx, COLS
    jge .save_corrected

    cmp ecx, ebx                    ; saltar la columna con error
    je .skip_col

    mov esi, [error_row]
    shl esi, 2
    add esi, ecx
    xor al, [ecc_received_data + esi]

.skip_col:
    inc ecx
    jmp .recalc_byte

.save_corrected:
    xor al, [ecc_row_parity + edx]  ; XOR con paridad esperada
    mov [ecc_corrected_data + edx], al

    mov eax, 1                      ; 1 error corregido
    jmp .end

.no_error:
    xor eax, eax                    ; 0 errores
    jmp .end

.uncorrectable:
    mov eax, -1                     ; error no corregible

.end:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: ecc_get_corrected_data
; Retorna puntero a datos corregidos
; ============================================================
global ecc_get_corrected_data
ecc_get_corrected_data:
    mov eax, ecc_corrected_data
    ret

; ============================================================
; FUNCIÓN: ecc_get_row_parity
; Retorna puntero a paridades de fila
; ============================================================
global ecc_get_row_parity
ecc_get_row_parity:
    mov eax, ecc_row_parity
    ret

; ============================================================
; FUNCIÓN: ecc_get_col_parity
; Retorna puntero a paridades de columna
; ============================================================
global ecc_get_col_parity
ecc_get_col_parity:
    mov eax, ecc_col_parity
    ret
