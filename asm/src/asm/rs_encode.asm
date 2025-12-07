; ============================================================
; rs_encode.asm
; Codificador Reed-Solomon para QR Versión 2
; Genera 22 bytes de corrección de errores (ECC)
; ============================================================

%include "io.mac"

; Importar funciones de GF(256)
extern gf_mul
extern gf_exp

; ============================================================
; SECCIÓN DE DATOS
; ============================================================
.DATA
    ; ============================================================
    ; Polinomio generador para 22 bytes ECC
    ; g(x) = (x - α^0)(x - α^1)(x - α^2)...(x - α^21)
    ; Precalculado para QR Versión 2, nivel M
    ; ============================================================
    generator_poly:
        db 0x01, 0x0f, 0x36, 0x78, 0x40, 0x1b, 0x9d, 0xf3
        db 0xd5, 0x3d, 0xd6, 0xd8, 0x91, 0xed, 0x2b, 0x08
        db 0x86, 0x36, 0xf5, 0x45, 0xc0, 0x5e, 0x24

; ============================================================
; SECCIÓN DE DATOS NO INICIALIZADOS
; ============================================================
.UDATA
    ; Buffer para mensaje + ECC (32 datos + 22 ECC = 54 total)
    global message_poly
    message_poly    resb 54         ; polinomio del mensaje
    
    ; Buffer de salida: 22 bytes de corrección
    global ecc_bytes
    ecc_bytes       resb 22         ; bytes ECC generados

; ============================================================
; SECCIÓN DE CÓDIGO
; ============================================================
.CODE

; ============================================================
; FUNCIÓN: rs_encode
; Genera los 22 bytes de corrección Reed-Solomon
; Algoritmo: División polinomial sintética
; ============================================================
; Inputs:
;   ESI = puntero a datos de entrada (32 bytes)
; Output:
;   ecc_bytes[] contiene los 22 bytes ECC generados
;   EAX = 0 si éxito
; ============================================================
global rs_encode
rs_encode:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    push eax                    ; preservar registros
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; ============================================================
    ; PASO 1: Copiar mensaje a message_poly
    ; ============================================================
    mov edi, message_poly       ; edi = destino
    mov ecx, 32                 ; ecx = 32 bytes de datos
    rep movsb                   ; copiar esi → edi
    
    ; ============================================================
    ; PASO 2: Limpiar área de ECC (inicializar en 0)
    ; ============================================================
    mov ecx, 22                 ; ecx = 22 bytes ECC
    xor eax, eax                ; eax = 0
    rep stosb                   ; llenar con ceros
    
    ; ============================================================
    ; PASO 3: División polinomial sintética
    ; Procesar cada uno de los 32 bytes de datos
    ; ============================================================
    mov ecx, 32                 ; ecx = contador de bytes a procesar
    xor esi, esi                ; esi = índice en message_poly
    
.divide_loop:
    ; --------------------------------------------------------
    ; Obtener coeficiente líder (el byte actual)
    ; --------------------------------------------------------
    movzx eax, byte [message_poly + esi] ; eax = coeficiente líder
    
    test al, al                 ; ¿es cero?
    jz .skip_iteration          ; si es 0, no hacer nada (optimización)
    
    ; --------------------------------------------------------
    ; Multiplicar generador por coeficiente y hacer XOR
    ; --------------------------------------------------------
    xor edx, edx                ; edx = índice en generator_poly
    
.multiply_loop:
    cmp edx, 23                 ; ¿procesamos los 23 coeficientes?
    jge .skip_iteration         ; si sí, terminar iteración
    
    ; Multiplicar generator_poly[edx] por el coeficiente líder
    push eax                    ; guardar coeficiente
    mov al, byte [generator_poly + edx] ; al = gen[edx]
    pop ebx                     ; ebx = coeficiente líder
    push ebx                    ; volver a guardar
    mov bl, al                  ; bl = gen[edx]
    pop eax                     ; eax = coeficiente líder
    
    ; Llamar a multiplicación en GF(256)
    ; al = coeficiente, bl = gen[edx]
    call gf_mul                 ; al = resultado
    
    ; XOR con message_poly[esi + edx]
    push edx                    ; guardar índice
    add edx, esi                ; edx = esi + offset
    xor byte [message_poly + edx], al ; XOR resultado
    pop edx                     ; restaurar índice
    
    inc edx                     ; siguiente coeficiente del generador
    jmp .multiply_loop          ; continuar loop
    
.skip_iteration:
    inc esi                     ; siguiente byte del mensaje
    loop .divide_loop           ; continuar con siguiente byte
    
    ; ============================================================
    ; PASO 4: Copiar resultado a ecc_bytes
    ; Los últimos 22 bytes de message_poly son los ECC
    ; ============================================================
    mov esi, message_poly       ; esi = inicio del mensaje
    add esi, 32                 ; esi = apuntar a bytes ECC (después de datos)
    mov edi, ecc_bytes          ; edi = buffer de salida
    mov ecx, 22                 ; ecx = 22 bytes ECC
    rep movsb                   ; copiar ECC a buffer de salida
    
    ; ============================================================
    ; RETORNAR ÉXITO
    ; ============================================================
    xor eax, eax                ; eax = 0 (éxito)
    
    pop edi                     ; restaurar registros
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ============================================================
; FUNCIÓN: rs_get_ecc_bytes
; Obtiene un puntero a los bytes ECC generados
; ============================================================
; Inputs: ninguno
; Output:
;   EAX = puntero a ecc_bytes (22 bytes)
; ============================================================
global rs_get_ecc_bytes
rs_get_ecc_bytes:
    mov eax, ecc_bytes          ; eax = puntero a buffer ECC
    ret

; ============================================================
; FUNCIÓN: rs_test_simple
; Función de prueba: codifica "ABC" y retorna los ECC
; ============================================================
; Inputs: ninguno
; Output:
;   ecc_bytes[] contiene ECC para "ABC"
;   EAX = 0 si éxito
; ============================================================
global rs_test_simple
rs_test_simple:
    push ebp
    mov ebp, esp
    push esi
    
    ; Preparar datos de prueba: "ABC"
    mov esi, message_poly       ; esi = buffer de mensaje
    mov byte [esi], 'A'         ; mensaje[0] = 'A'
    mov byte [esi+1], 'B'       ; mensaje[1] = 'B'
    mov byte [esi+2], 'C'       ; mensaje[2] = 'C'
    
    ; Llenar resto con ceros
    add esi, 3                  ; esi apunta después de "ABC"
    mov ecx, 29                 ; 32 - 3 = 29 bytes restantes
    xor eax, eax
.clear_loop:
    mov byte [esi], al
    inc esi
    loop .clear_loop
    
    ; Codificar
    mov esi, message_poly       ; esi = datos a codificar
    call rs_encode              ; generar ECC
    
    pop esi
    pop ebp
    ret
