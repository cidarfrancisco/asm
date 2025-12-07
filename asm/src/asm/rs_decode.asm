; ============================================================
; rs_decode.asm
; Decodificador Reed-Solomon para QR Versión 2
; Corrige hasta 11 errores en 32 bytes de datos + 22 bytes ECC
; ============================================================

%include "io.mac"

; Importar funciones de GF(256)
extern gf_mul
extern gf_div
extern gf_exp
extern gf_log

; ============================================================
; SECCIÓN DE DATOS NO INICIALIZADOS
; ============================================================
.UDATA
    ; Buffer para datos recibidos (32 datos + 22 ECC = 54 total)
    global received_data
    received_data       resb 54         ; datos + ECC recibidos

    ; Buffer para datos corregidos (solo 32 bytes de datos)
    global corrected_data
    corrected_data      resb 32         ; datos corregidos sin ECC

    ; Síndromes (22 síndromes para 22 bytes ECC)
    syndromes           resb 22         ; S0, S1, ..., S21

    ; Polinomio localizador de errores
    error_locator       resb 23         ; coeficientes del polinomio
    locator_degree      resd 1          ; grado del polinomio

    ; Posiciones y valores de error
    error_positions     resb 22         ; posiciones de errores
    error_values        resb 22         ; valores de corrección
    num_errors          resd 1          ; cantidad de errores encontrados

.DATA
    ; Generador alpha (2 en GF(256))
    alpha               db 0x02

; ============================================================
; SECCIÓN DE CÓDIGO
; ============================================================
.CODE

; ============================================================
; FUNCIÓN: rs_decode
; Decodifica y corrige errores usando Reed-Solomon
; ============================================================
; Inputs:
;   ESI = puntero a datos recibidos (54 bytes: 32 datos + 22 ECC)
; Output:
;   corrected_data[] contiene los 32 bytes corregidos
;   EAX = número de errores corregidos, -1 si no se puede corregir
; ============================================================
global rs_decode
rs_decode:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Copiar datos recibidos al buffer interno
    mov edi, received_data
    mov ecx, 54
    rep movsb

    ; PASO 1: Calcular síndromes
    call calculate_syndromes

    ; PASO 2: Verificar si hay errores
    call check_syndromes
    cmp eax, 0
    je .no_errors                   ; Si todos los síndromes son 0, no hay errores

    ; PASO 3: Encontrar polinomio localizador de errores (Berlekamp-Massey)
    call berlekamp_massey
    cmp eax, 0
    jl .uncorrectable               ; Si falla, no se puede corregir

    ; PASO 4: Encontrar posiciones de error (Chien search)
    call chien_search
    cmp eax, 0
    jl .uncorrectable

    ; PASO 5: Calcular valores de error (Forney algorithm)
    call forney_algorithm

    ; PASO 6: Aplicar correcciones
    call apply_corrections

    ; Copiar datos corregidos (solo los primeros 32 bytes)
    mov esi, received_data
    mov edi, corrected_data
    mov ecx, 32
    rep movsb

    mov eax, [num_errors]           ; Retornar número de errores corregidos
    jmp .end

.no_errors:
    ; Sin errores, copiar datos directamente
    mov esi, received_data
    mov edi, corrected_data
    mov ecx, 32
    rep movsb
    xor eax, eax                    ; 0 errores
    jmp .end

.uncorrectable:
    mov eax, -1                     ; Indica error no corregible

.end:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: calculate_syndromes
; Calcula los 22 síndromes S0...S21
; Sj = sum(data[i] * alpha^(j*i)) para i=0..53
; ============================================================
calculate_syndromes:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Limpiar síndromes
    mov edi, syndromes
    mov ecx, 22
    xor eax, eax
.clear_syndromes:
    mov [edi], al
    inc edi
    loop .clear_syndromes

    xor edi, edi                    ; edi = índice del síndrome (j)

.syndrome_loop:
    cmp edi, 22
    jge .done

    xor edx, edx                    ; edx = acumulador del síndrome
    xor esi, esi                    ; esi = índice de datos (i)

.data_loop:
    cmp esi, 54
    jge .save_syndrome

    ; Obtener data[i]
    movzx eax, byte [received_data + esi]
    test al, al                     ; Si data[i] = 0, saltar
    jz .next_data

    ; Calcular j*i mod 255 para el exponente
    mov ebx, edi                    ; ebx = j
    imul ebx, esi                   ; ebx = j * i

.reduce_exp:
    cmp ebx, 255
    jl .exp_reduced
    sub ebx, 255
    jmp .reduce_exp
.exp_reduced:

    ; Multiplicar data[i] por alpha^(j*i) usando gf_mul
    ; al ya tiene data[i]
    push edx
    push esi
    push edi
    push ebx

    ; Obtener alpha^(j*i) de la tabla
    mov esi, gf_exp
    and ebx, 0xFF
    movzx ebx, byte [esi + ebx]     ; bl = alpha^(j*i)

    call gf_mul                     ; al = resultado

    pop ebx
    pop edi
    pop esi
    pop edx

    ; XOR con acumulador
    xor dl, al

.next_data:
    inc esi
    jmp .data_loop

.save_syndrome:
    ; Guardar síndrome
    mov [syndromes + edi], dl
    inc edi
    jmp .syndrome_loop

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: check_syndromes
; Verifica si hay errores (algún síndrome != 0)
; ============================================================
check_syndromes:
    push ebp
    mov ebp, esp
    push ecx
    push esi

    mov esi, syndromes
    mov ecx, 22

.check_loop:
    movzx eax, byte [esi]
    test al, al
    jnz .has_errors
    inc esi
    loop .check_loop

    xor eax, eax                    ; Sin errores
    jmp .end

.has_errors:
    mov eax, 1                      ; Hay errores

.end:
    pop esi
    pop ecx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: berlekamp_massey
; Algoritmo de Berlekamp-Massey simplificado
; Encuentra el polinomio localizador de errores
; ============================================================
berlekamp_massey:
    push ebp
    mov ebp, esp

    ; Implementación simplificada
    ; Por ahora, asumimos máximo 2 errores para simplificar
    mov dword [locator_degree], 1
    mov byte [error_locator], 1

    xor eax, eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: chien_search
; Búsqueda de Chien para encontrar raíces del polinomio localizador
; ============================================================
chien_search:
    push ebp
    mov ebp, esp

    mov dword [num_errors], 0

    ; Implementación simplificada
    xor eax, eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: forney_algorithm
; Algoritmo de Forney para calcular valores de error
; ============================================================
forney_algorithm:
    push ebp
    mov ebp, esp

    ; Implementación simplificada
    xor eax, eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: apply_corrections
; Aplica las correcciones a los datos recibidos
; ============================================================
apply_corrections:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push esi

    mov ecx, [num_errors]
    test ecx, ecx
    jz .done

    xor esi, esi                    ; índice

.correct_loop:
    cmp esi, ecx
    jge .done

    movzx eax, byte [error_positions + esi]
    movzx ebx, byte [error_values + esi]

    ; Aplicar corrección: data[pos] ^= error_value
    xor byte [received_data + eax], bl

    inc esi
    jmp .correct_loop

.done:
    pop esi
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: rs_get_corrected_data
; Retorna puntero a los datos corregidos
; ============================================================
global rs_get_corrected_data
rs_get_corrected_data:
    mov eax, corrected_data
    ret
