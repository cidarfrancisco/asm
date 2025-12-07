; qr_extract.asm
; Extracción de datos en patrón zigzag
; Objetivo: Extraer los bits de datos del QR siguiendo el zigzag
; Inputs:
;   Matriz de 625 bytes (25x25)
; Outputs:
;   Secuencia de bits extraídos

%include "io.mac"

.DATA
    msg_extracting  db "Extrayendo datos...", 0

.UDATA
    ; Buffer para almacenar bits extraídos
    global extracted_bits
    extracted_bits  resb 200      ; buffer para 1600 bits
    bits_count      resd 1        ; contador de bits extraídos
    
    ; Variables de trabajo
    current_col     resd 1        ; columna actual
    current_row     resd 1        ; fila actual
    going_up        resd 1        ; 1 = subiendo, 0 = bajando

.CODE

; Importar funciones de otros módulos
extern get_module
extern matriz_ptr
extern matriz_size
extern get_pixel

; Verifica si una posición es un área reservada (patterns, etc)
; Inputs: EAX = x (columna) / EBX = y (fila)
; Output: EAX = 1 si es área reservada, 0 si es área de datos
is_reserved_area:
    push ebp
    mov ebp, esp
    
    ; Finder patterns (7x7 en 3 esquinas)
    ; Superior izquierdo (0-6, 0-6)
    cmp eax, 7                   ; compara la columna con 7 
    jge .check_top_right         ; si es mayor o igual no es area reservada              
    cmp ebx, 7                   ; compara la fila con 7 
    jge .check_top_right         ; si es mayor o igual no es area reservada
    mov eax, 1                   ; de lo contrario es área reservada
    jmp .end                     ; salta al final 
    
.check_top_right:
    ; Superior derecho (18-24, 0-6)
    cmp eax, 18                  ; compara la columna con 18
    jl .check_bottom_left        ; si es menor no es area reservada
    cmp ebx, 7                   ; compara la fila con 7 
    jge .check_bottom_left       ; si es mayor o igual no es area reservada
    mov eax, 1                   ; de lo contrario es área reservada
    jmp .end                     ; salta al final
    
.check_bottom_left:
    ; Inferior izquierdo (0-6, 18-24)
    cmp eax, 7                   ; compara la columna con 7 
    jge .check_timing            ; si es mayor o igual no es area reservada
    cmp ebx, 18                  ; compara la fila con 7 
    jl .check_timing             ; si es menor no es area reservada
    mov eax, 1                   ; de lo contrario es área reservada
    jmp .end                     ; salta al final 
    
.check_timing:
    ; Timing patterns (fila 6 y columna 6)
    cmp eax, 6                   ; comparamos  la columan con 6
    je .is_reserved              ; si es igual es area reservada
    cmp ebx, 6                   ; comparamos  la fila con 6
    je .is_reserved              ; si es igual es area reservada
    
    ; Alignment pattern, reservar un área 5x5 en 18,18
    mov ecx, eax                 ; ecx = columna 
    sub ecx, 18                  ; ecx = x - 18 (distancia horizontal al centro)
    cmp ecx, -2                  ; comparar si (x - 18) < -2
    jl .not_reserved             ; si x < 16, está fuera del alignment
    cmp ecx, 2                   ; comparar si (x - 18) > 2
    jg .not_reserved             ; si x > 20, está fuera del alignment
    
    mov ecx, ebx                 ; coordenada fila 
    sub ecx, 18                  ; ecx = y - 18 (distancia vertical al centro)
    cmp ecx, -2                  ; comparar si (y - 18) < -2  
    jl .not_reserved             ; si y < 16, está fuera del alignment
    cmp ecx, 2                   ; comparar si (y - 18) > 2
    jg .not_reserved             ; si y > 20, está fuera del alignment
    
.is_reserved:
    mov eax, 1                   ; si se retorno 1 esta reservado
    jmp .end
    
.not_reserved:
    xor eax, eax                 ; 0 si no es reservado

.end:
    pop ebp
    ret

; Extrae los datos del QR en patrón zigzag
; Inputs: [matriz_ptr] = puntero a matriz
; Outputs: [extracted_bits] = bits extraídos y EAX = número de bits extraídos

global extract_data_zigzag

extract_data_zigzag:
    ; Guardar registros que vamos a usar
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    
    mov dword [bits_count], 0    ; contador de bits extraídos = 0
    mov edi, extracted_bits      ; EDI apunta al buffer de bits
    
    ; Configurar posición inicial del recorrido zigzag
    mov dword [current_col], 24
    mov dword [current_row], 24
    mov dword [going_up], 1      ; empezamos subiendo
    
.zigzag_loop:
    mov eax, [current_col]       ; cargar columna actual          
    cmp eax, 0                   ; comparar con 0
    jl .extraction_done          ; si es menor terminamos 
    
    ; Saltar la columna 6 
    cmp eax, 6                   ; estamos en columna 6
    jne .not_timing_col          ; si no seguir normal
    dec dword [current_col]      ; si si decrementamos para saltar la columna 
    jmp .zigzag_loop             ; continuar con el loop
    
.not_timing_col:
    ; Leer 2 módulos en la columna actual porque el qr lee dos columnas a la vez
    mov eax, [current_col]       ; eax = columna
    mov ebx, [current_row]       ; ebx = fila
    
    ; Verificar si es área reservada
    call is_reserved_area       ; llamar a si es area reservada
    cmp eax, 1                  ; si se retorno 1 
    je .skip_module1            ; si es reservada, saltar
    
    ; Si no es reservada se lee normal 
    mov eax, [current_col]      ; eax = columna
    mov ebx, [current_row]      ; ebx = fila 
    call get_module             ; leer el valor
    
    ; Guardar bit
    mov [edi], al               ;  escribir bit en extracted_bits[bits_count]
    inc edi                     ; avanzar puntero del buffer
    inc dword [bits_count]      ; incrementar contador de bits extraídos
    
.skip_module1:
    ; Módulo 2: columna actual - 1
    mov eax, [current_col]      ; eax = columna actual 
    dec eax                     ; eax = columna - 1
    mov ebx, [current_row]      ; ebx = fila actual
    
    ; Verificar area reservada
    ; Guardamos eax y ebx porque is_reserved_area puede modificarlos
    push eax
    push ebx
    call is_reserved_area      ; llamamos a si es reservada
    ; restauramos 
    pop ebx
    pop eax
    
    cmp eax, 1                 ; comparamos con 1 a ver si esta reservada
    je .skip_module2           ; si esta reservada saltar
    
    mov eax, edx               ; eax = indice       
    call get_module            ; llamar a funcion que lee el modulo           
    mov [edi], al              ; guardar el bit en extracted_bits[bits_count]
    inc edi                    ; avanzar puntero del buffer a la siguiente posición
    inc dword [bits_count]     ; incrementar contador de bits extraídos

.skip_module2:
    ; Mover a la siguiente posición según dirección
    mov eax, [going_up]       ; cargar dirección actual
    cmp eax, 1                ; ver si estamos subiendo
    je .move_up               ; saltar a la logica de subir
    
.move_down:
    inc dword [current_row]   ; bajando: incrementar fila
    
    mov eax, [current_row]    ; cargar nueva fila
    cmp eax, 25               ; compara fila con 25
    jl .zigzag_loop           ; si es menor continuar
    
    ; Cambiar dirección: ahora subimos
    mov dword [going_up], 1     ; cambiar dirección a subiendo
    dec dword [current_row]     ; volver a fila válida
    sub dword [current_col], 2  ; pasar a siguiente par de columnas
    jmp .zigzag_loop
    
.move_up:
    dec dword [current_row]     ; subiendo: decrementar fila
    
    ; Llegamos al final subiendo
    mov eax, [current_row]      ; cargar nueva fila
    cmp eax, 0                  ; comparar fila con 0
    jge .zigzag_loop            ; si es amyor o igual seguimos
    
    ; Cambiar dirección: ahora bajamos
    mov dword [going_up], 0     ; cambiar dirección a bajando
    inc dword [current_row]     ; volver a fila válida
    sub dword [current_col], 2  ; pasar a siguiente par de columnas
    jmp .zigzag_loop

.extraction_done:
    mov eax, [bits_count]       ; retornar número de bits extraídos

    ; restaurar registros
    pop edi
    pop esi
    pop ebx
    
    pop ebp
    ret
