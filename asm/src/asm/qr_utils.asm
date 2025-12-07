; qr_utils.asm
; Funciones auxiliares para procesamiento de QR
; Objetivo: Proveer funciones reutilizables para manipular la matriz

%include "io.mac"

.DATA
    ; (Vacía por ahora)

.UDATA
    ; Variables compartidas (se inicializan desde qr_decode.asm)
    global matriz_ptr
    global matriz_size
    
    matriz_ptr      resd 1      ; puntero a la matriz
    matriz_size     resd 1      ; tamaño de la matriz 

.CODE
; Obtiene el valor de un módulo en la matriz
; Inputs: EAX = x (columna, 0-24) / EBX = y (fila, 0-24)
; Output: AL = valor del módulo (0 o 1)
global get_module

get_module:
    ; meter los registros a la pila
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    
    push ebx                    ; preservar ebx
    push edx                    ; preservar edx
    
    ; Verificar que x e y estén dentro de [0, 24]
    cmp eax, 0                  ; comparar x con 0
    jl .error                   ; si x < 0, ir a error
    cmp eax, 25                 ; comparar x con 25
    jge .error                  ; si x >= 25, ir a error
    cmp ebx, 0                  ; comparar y con 0
    jl .error                   ; si y < 0, ir a error
    cmp ebx, 25                 ; comparar y con 25
    jge .error                  ; si y >= 25, ir a error
    
    ; Calcular indice lineal en la matriz 
    push eax                    ; guardar x en la pila
    mov eax, ebx                ; eax = y
    mov ecx, 25                 ; ecx = 25 (ancho de la matriz)
    mul ecx                     ; eax = y * 25
    mov ecx, eax                ; ecx = y * 25
    pop eax                     ; recuperar x
    add ecx, eax                ; ecx = y * 25 + x (índice final)
    
    ; leer el valor
    mov esi, [matriz_ptr]       ; esi = puntero base de la matriz
    
    movzx eax, byte [esi + ecx] ; eax = matriz[y*25 + x] (extender a 32 bits)
    and al, 1                   ; asegurar que solo sea 0 o 1 (aplicar máscara)
    
    test al, al                 ; establecer flag zero: ZF = 1 si al = 0
    
    jmp .end                    ; saltar al final

.error:
    xor eax, eax                ; retornar 0 en caso de error

.end:
    ; restaurar registros 
    pop edx                     ; restaurar edx
    pop ebx                     ; restaurar ebx
    
    pop ebp                     ; restaurar frame pointer
    ret                         ; retornar

; Verifica si una secuencia de 7 módulos sigue el patrón 1:1:3:1:1
; Patrón: NEGRO-BLANCO-NEGRO NEGRO NEGRO-BLANCO-NEGRO
;         1     1      3              1      1
; Inputs:
;   EAX = x inicial (columna de inicio)
;   EBX = y inicial (fila de inicio) 
;   CL  = dirección (0 = horizontal, 1 = vertical)
; Output:
;   EAX = 1 si el patrón coincide, 0 si no coincide
global check_pattern_1_1_3_1_1

check_pattern_1_1_3_1_1:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame

    ; Guardar registros que vamos a modificar
    push esi                    ; preservar esi
    push edi                    ; preservar edi
    
    mov esi, eax                ; esi = x inicial (guardar coordenada x)
    mov edi, ebx                ; edi = y inicial (guardar coordenada y)
    
    ; Verificar 7 módulos según el patrón 1:1:3:1:1
    ; Posiciones esperadas: NEGRO BLANCO NEGRO-NEGRO-NEGRO BLANCO NEGRO
    ; Índices:              0     1      2     3     4      5      6

    ; MÓDULO 0: debe ser NEGRO (1)
    mov eax, esi                ; eax = x actual
    mov ebx, edi                ; ebx = y actual
    call get_module             ; leer modulo
    cmp al, 1                   ; ver si es negro
    jne .no_match               ; si no es negro, no coincide el patrón
    
    ; Incrementar posición según la dirección
    cmp cl, 0                   ; ver si la direccion es horizontal
    je .inc_x_1                 ; si sí, incrementar x
    inc edi                     ; si no, dirección vertical: y++
    jmp .check_1                ; continuar con módulo 1
.inc_x_1:
    inc esi                     ; dirección horizontal: x++
    
.check_1:
    ; MÓDULO 1: debe ser BLANCO (0)
    mov eax, esi                ; eax = x actual
    mov ebx, edi                ; ebx = y actual
    call get_module             ; leer modulo
    cmp al, 0                   ; ver si es blanco
    jne .no_match               ; si no es blanco, no coincide
    
    ; Incrementar posición
    cmp cl, 0                   ; ver si es horizontal
    je .inc_x_2                 ; si sí, incrementar x
    inc edi                     ; si no, vertical: y++
    jmp .check_2                ; continuar
.inc_x_2:
    inc esi                     ; horizontal: x++
    
.check_2:
    ; MÓDULOS 2, 3, 4: deben ser NEGRO NEGRO NEGRO (3 negros consecutivos)
    ; Este es el cuadro central del patrón 1:1:3:1:1
    mov edx, 3                  ; edx = contador (3 módulos negros)
.check_center:
    mov eax, esi                ; eax = x actual
    mov ebx, edi                ; ebx = y actual
    call get_module             ; leer módulo
    cmp al, 1                   ; ver si es negro
    jne .no_match               ; si no es negro, no coincide
    
    ; Incrementar posición
    cmp cl, 0                   ; ver si es horizontal
    je .inc_x_center            ; si sí, incrementar x
    inc edi                     ; si no, vertical: y++
    jmp .next_center            ; continuar
.inc_x_center:
    inc esi                     ; horizontal: x++
.next_center:
    dec edx                     ; decrementar contador
    cmp edx, 0                  ; ver si hay modulos por verificar
    jg .check_center            ; si sí, continuar con el siguiente
    
    ; MÓDULO 5: debe ser BLANCO (0)
    mov eax, esi                ; eax = x actual
    mov ebx, edi                ; ebx = y actual
    call get_module             ; leer módulo
    cmp al, 0                   ; ver si es blanco
    jne .no_match               ; si no es blanco, no coincide
    
    ; Incrementar posición
    cmp cl, 0                   ; ver si es horizontal
    je .inc_x_5                 ; si sí, incrementar x
    inc edi                     ; si no, vertical: y++
    jmp .check_6                ; continuar
.inc_x_5:
    inc esi                     ; horizontal: x++
    
.check_6:
    ; MÓDULO 6: debe ser NEGRO (1)
    mov eax, esi                ; eax = x actual
    mov ebx, edi                ; ebx = y actual
    call get_module             ; leer módulo
    cmp al, 1                   ; ver si es negro
    jne .no_match               ; si no es negro, no coincide
    
    ; si el patron esta verificado
    mov eax, 1                  ; retornar 1 (patrón válido)
    jmp .end                    ; ir al final

.no_match:
    xor eax, eax                ; retornar 0 (patrón no coincide)

.end:
    ; Restaurar registros
    pop edi                     ; restaurar edi
    pop esi                     ; restaurar esi
    
    pop ebp                     ; restaurar frame pointer
    ret                         ; retornar

; FUNCIÓN: is_finder_pattern
; Verifica si hay un finder pattern en una posición
; Un finder pattern válido debe cumplir el patrón 1:1:3:1:1 tanto
; en todas sus filas clave (0, 3, 6) como en sus columnas clave (0, 3, 6)
; Inputs:
;   EAX = x (columna de la esquina superior izquierda del patrón)
;   EBX = y (fila de la esquina superior izquierda del patrón)
; Output:
;   EAX = 1 si es un finder pattern válido, 0 si no lo es
global is_finder_pattern

is_finder_pattern:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    
    sub esp, 8                  ; reservar espacio para variables locales
    ; [ebp-4] = x inicial (columna de inicio)
    ; [ebp-8] = y inicial (fila de inicio)
    
    mov [ebp-4], eax            ; guardar x inicial
    mov [ebp-8], ebx            ; guardar y inicial
    
    push esi                    ; preservar esi
    push edi                    ; preservar edi
    
    ; verificar que el patron cabe en la matriz
    mov eax, [ebp-4]            ; eax = x inicial
    add eax, 7                  ; eax = x + 7 (límite derecho)
    cmp eax, 25                 ; ¿x + 7 > 25?
    jg .not_finder              ; si se sale, no puede ser un finder
    
    mov ebx, [ebp-8]            ; ebx = y inicial
    add ebx, 7                  ; ebx = y + 7 (límite inferior)
    cmp ebx, 25                 ; ¿y + 7 > 25?
    jg .not_finder              ; si se sale, no puede ser un finder
    
    ; verificar patron horizontal 
    ; Las filas 0, 3 y 6 deben cumplir el patrón 1:1:3:1:1

    ; Fila 0 (superior): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial
    mov ebx, [ebp-8]            ; ebx = y inicial (fila 0)
    xor ecx, ecx                ; cl = 0 (dirección horizontal)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; preguntar si coincide con el patron
    je .not_finder              ; si no, no es un finder válido
    
    ; Fila 3 (centro): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial
    mov ebx, [ebp-8]            ; ebx = y inicial
    add ebx, 3                  ; ebx = fila 3 (fila central)
    xor ecx, ecx                ; cl = 0 (horizontal)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; ver si coincide
    je .not_finder              ; si no, no es válido

    ; Fila 6 (inferior): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial
    mov ebx, [ebp-8]            ; ebx = y inicial
    add ebx, 6                  ; ebx = fila 6 (última fila)
    xor ecx, ecx                ; cl = 0 (horizontal)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; ver si coincide
    je .not_finder              ; si no, no es válido
    
    ; verificar patron vertical
    ; Las columnas 0, 3 y 6 deben cumplir el patrón 1:1:3:1:1
    
    ; Columna 0 (izquierda): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial (columna 0)
    mov ebx, [ebp-8]            ; ebx = y inicial
    mov cl, 1                   ; cl = 1 (dirección vertical)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; ver si coincide
    je .not_finder              ; si no, no es válido
    
    ; Columna 3 (centro): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial
    add eax, 3                  ; eax = columna 3 
    mov ebx, [ebp-8]            ; ebx = y inicial
    mov cl, 1                   ; cl = 1 (vertical)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; ver si coincide
    je .not_finder              ; si no, no es válido
    
    ; Columna 6 (derecha): debe ser 1:1:3:1:1
    mov eax, [ebp-4]            ; eax = x inicial
    add eax, 6                  ; eax = columna 6 
    mov ebx, [ebp-8]            ; ebx = y inicial
    mov cl, 1                   ; cl = 1 (vertical)
    call check_pattern_1_1_3_1_1 ; verificar patrón
    cmp eax, 0                  ; ver si coincide
    je .not_finder              ; si no, no es válido
    
    ; si todas las verificaciones pasaron es un finder valido
    mov eax, 1                  ; retornar 1 para finder valido 
    jmp .end                    ; ir al final

.not_finder:
    xor eax, eax                ; retornar 0 si no es un finder valido

.end:
    ; Restaurar registros y stack
    pop edi                    
    pop esi                     
    
    add esp, 8                
    pop ebp                     ; restaurar frame pointer
    ret                        
