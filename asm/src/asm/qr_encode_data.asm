; qr_encode_data.asm
; Codificacion de texto a bits en modo BYTE para QR version 2
; Los bits se guardan como bytes 0/1 en encoded_bits, en el orden más significativo primero

%include "io.mac"

; Funciones externas de ECC
extern ecc_encode
extern ecc_get_row_parity
extern ecc_get_col_parity

; PARTE DE DATOS
.DATA
    msg_too_long    db "Error: texto demasiado largo para este encoder", 0		; mensaje para debug

    ; Buffer de bits codificados (expandido para incluir paridad)
    global encoded_bits
    encoded_bits     times 352 db 0		; 44 bytes * 8 bits = 352 bits (32 datos + 8 fila + 4 col)

	; Buffer final que termina escrito en la matriz (25x25)
    global encode_matrix_ptr
    encode_matrix_ptr    dd 0

; PARTE DE DATOS NO INICIALIZADOS
.UDATA
    enc_bit_position     resd 1				; indice en encoded_bits
    enc_char_count       resd 1				; cantidad de caracteres del texto de entrada
    global encoded_bit_len
    encoded_bit_len      resd 1				; numero total de bits validos en encoded_bits

    ; Buffers para datos en bytes (antes de convertir a bits)
    data_bytes           resb 32            ; 32 bytes de datos

; PARTE DE CODIGO
.CODE

; Escribe 'ecx' bits del valor 'eax' en encoded_bits, desde el bit más significativo hacia el menos significativo.
; INPUT
;   EAX = valor cuyo campo de bits queremos escribir
;   ECX = cantidad de bits a escribir
; OUTPUT
;   enc_bit_position actualizado

write_bits:
	; Guardamos los registros que vamos a usar
    push ebx
    push edx
    push esi

    mov ebx, ecx				; ebx = numero de bits que faltan por escribir

    ; esi = puntero base = encoded_bits + enc_bit_position
    mov esi, encoded_bits
    mov edx, [enc_bit_position]
    add esi, edx

.wb_loop:
    cmp ebx, 0					; comparar numero de bits con 0 
    je .wb_done              	; si ya no quedan bits terminamos

    ; queremos el bit numero (ebx-1)
    mov edx, eax             	; edx = valor original
    mov ecx, ebx
    dec ecx                  	; bit_index = ebx - 1
    shr edx, cl              	; desplaza para dejar ese bit en el bit 0
    and dl, 1                	; dl = 0 o 1

    ; guardar bit como byte 0/1
    mov [esi], dl            
    inc esi

    ; incrementamos enc_bit_position
    mov ecx, [enc_bit_position]
    inc ecx
    mov [enc_bit_position], ecx

    dec ebx                  	; un bit menos por escribir
    jmp .wb_loop				; salta para seguir en el loop

.wb_done:
	; restauramos los registros
    pop esi
    pop edx
    pop ebx
    ret

; para codificar el texto a bits 
global encode_text_to_bits

encode_text_to_bits:
	; guardamos los registros que vamos a usar
    push ebp
    mov  ebp, esp

    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Calcular longitud de la cadena (enc_char_count)
    mov esi, [ebp+8]         	; esi = puntero al texto
    xor ecx, ecx             	; ecx = contador de caracteres

.count_loop:
    mov al, [esi]            	; lee un byte del texto
    cmp al, 0
    je  .len_done            	; si es 0  terminamos

    inc ecx                  	; aumenta contador
    inc esi                  	; siguiente caracter
    jmp .count_loop				

.len_done:
    mov [enc_char_count], ecx
   
    cmp ecx, 32					; limite de caracteres para evitar desbordes, en este caso son 32 pero puede variar
    jle .len_ok					; si es menor a 32 continua

    mov eax, -1					; si es muy largo
    jmp .encode_end				; salta a que termino

.len_ok:

    ; Inicializar posicion de bit y limpiar encoded_bits
    xor eax, eax
    mov [enc_bit_position], eax

    ; limpiar el buffer por si acaso
    mov edi, encoded_bits
    mov ecx, 256
    mov al, 0
    rep stosb
    
    ; Escribir modo 
    mov eax, 4               ; modo BYTE
    mov ecx, 4               ; 4 bits
    call write_bits

    ; Escribir longitud (8 bits) porque para version 2 en modo BYTE, el contador usa 8 bits
    mov eax, [enc_char_count]
    mov ecx, 8
    call write_bits

    ; Escribir los datos: 8 bits por caracter
    mov esi, [ebp+8]         ; esi = puntero de nuevo al texto
    mov ebx, [enc_char_count]

.data_loop:
    cmp ebx, 0
    je  .after_data

    movzx eax, byte [esi]    ; EAX = carácter actual (0..255)
    mov ecx, 8               ; 8 bits por carácter
    call write_bits

    inc esi
    dec ebx
    jmp .data_loop

.after_data:
    ; para terminar 4 bits de 0 (0000)
    xor eax, eax             ; valor 0
    mov ecx, 4               ; 4 bits
    call write_bits

    ; Relleno con 0 para llegar a multiplo de 8 bits 
    mov eax, [enc_bit_position]
    xor edx, edx
    mov ecx, 8
    div ecx                  ; para ver si es multiplo de 8

    cmp edx, 0
    je .no_pad_bits          ; ya es multiplo de 8

    mov ecx, 8
    sub ecx, edx             ; cuantos bits faltan para el siguiente byte
    xor eax, eax             ; valor 0
    call write_bits

.no_pad_bits:
    ; --------------------------------------------------------
    ; Convertir bits a bytes para ECC
    ; --------------------------------------------------------
    ; Los primeros bits son: modo(4) + longitud(8) + datos(N*8) + terminator(4) + padding
    ; Necesitamos extraer exactamente 32 bytes de datos

    ; Calcular cuántos bits de datos tenemos
    mov eax, [enc_char_count]
    shl eax, 3                  ; eax = char_count * 8 (bits de datos puros)
    add eax, 12                 ; + 4 bits modo + 8 bits longitud = 12

    ; Convertir bits a bytes (32 bytes)
    mov esi, encoded_bits       ; origen: bits
    add esi, 12                 ; saltar modo(4) + longitud(8) = 12 bits
    mov edi, data_bytes         ; destino: bytes
    xor ebx, ebx                ; contador de bytes generados

.bits_to_bytes_loop:
    cmp ebx, 32
    jge .ecc_generate

    xor eax, eax                ; acumulador
    mov ecx, 8                  ; 8 bits por byte

.gather_byte:
    shl eax, 1
    movzx edx, byte [esi]
    or al, dl
    inc esi
    loop .gather_byte

    mov [data_bytes + ebx], al
    inc ebx
    jmp .bits_to_bytes_loop

.ecc_generate:
    ; --------------------------------------------------------
    ; Generar paridades ECC
    ; --------------------------------------------------------
    mov esi, data_bytes
    call ecc_encode             ; Genera paridades en ecc_row_parity y ecc_col_parity

    ; --------------------------------------------------------
    ; Agregar paridades al final de encoded_bits
    ; --------------------------------------------------------
    ; Resetear posición de bits al final de los datos
    mov eax, [enc_bit_position]
    mov [enc_bit_position], eax

    ; Agregar 8 bytes de paridad de fila
    call ecc_get_row_parity     ; EAX = puntero a 8 bytes
    mov esi, eax
    mov ecx, 8

.add_row_parity:
    movzx eax, byte [esi]
    push ecx
    mov ecx, 8                  ; 8 bits por byte
    call write_bits
    pop ecx
    inc esi
    loop .add_row_parity

    ; Agregar 4 bytes de paridad de columna
    call ecc_get_col_parity     ; EAX = puntero a 4 bytes
    mov esi, eax
    mov ecx, 4

.add_col_parity:
    movzx eax, byte [esi]
    push ecx
    mov ecx, 8                  ; 8 bits por byte
    call write_bits
    pop ecx
    inc esi
    loop .add_col_parity

    ; Guardar longitud final de bits (ahora con ECC incluido)
    mov eax, [enc_bit_position]
    mov [encoded_bit_len], eax
    xor eax, eax

.encode_end:
	; restauramos los registros
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx

    pop ebp
    ret

; Esta funcion toma encoded_bits y los coloca en la matriz usando el recorrido zigzag estándar de QR:
;   • de derecha a izquierda
;   • en columnas de 2 módulos
;   • subiendo y bajando alternadamente
;   • sin sobreescribir los patrones fijos 

global place_bits_zigzag

; Funcion para verificar si una posicion es area reservada
is_reserved_encode:
    push ebp
    mov ebp, esp

    ; Finder patterns (7x7 en 3 esquinas)
    ; Superior izquierdo (0-6, 0-6)
    cmp eax, 7
    jge .check_top_right_e
    cmp ebx, 7
    jge .check_top_right_e
    mov eax, 1
    jmp .end_e

.check_top_right_e:
    ; Superior derecho (18-24, 0-6)
    cmp eax, 18
    jl .check_bottom_left_e
    cmp ebx, 7
    jge .check_bottom_left_e
    mov eax, 1
    jmp .end_e

.check_bottom_left_e:
    ; Inferior izquierdo (0-6, 18-24)
    cmp eax, 7
    jge .check_timing_e
    cmp ebx, 18
    jl .check_timing_e
    mov eax, 1
    jmp .end_e

.check_timing_e:
    ; Timing patterns (fila 6 y columna 6)
    cmp eax, 6
    je .is_reserved_e
    cmp ebx, 6
    je .is_reserved_e

    ; Alignment pattern (centro aproximado)
    mov ecx, eax
    sub ecx, 18
    cmp ecx, -2
    jl .not_reserved_e
    cmp ecx, 2
    jg .not_reserved_e

    mov ecx, ebx
    sub ecx, 18
    cmp ecx, -2
    jl .not_reserved_e
    cmp ecx, 2
    jg .not_reserved_e

.is_reserved_e:
    mov eax, 1
    jmp .end_e

.not_reserved_e:
    xor eax, eax

.end_e:
    pop ebp
    ret

place_bits_zigzag:
	; guardamos los registros que vamos a usar
    push ebp
    mov  ebp, esp
    sub esp, 16                     ; espacio para variables locales
    push ebx
    push esi
    push edi

    mov esi, [encode_matrix_ptr]    ; esi = puntero a matriz destino

    mov dword [ebp-4], 0            ; bit_index = 0
    mov dword [ebp-8], 24           ; columna = 24 (derecha)
    mov dword [ebp-12], 24          ; fila = 24 (abajo)
    mov dword [ebp-16], 1           ; direction = up

.zigzag_loop:
    ; Verificar si terminamos
    mov eax, [ebp-8]                ; cargar columna actual en eax
    cmp eax, 0						; comparar columna con 0
    jl .done_zigzag					; si columna menor que 0 terminamos

    ; Saltar columna 6 (timing pattern)
    cmp eax, 6						; comparar si columna == 6
    jne .not_timing_col_e			; si no es 6, continuar normalmente
    dec dword [ebp-8]				; si es 6 decrementar la columna para saltarla
    jmp .zigzag_loop				; reiniciar el loop

.not_timing_col_e:
    mov eax, [ebp-8]                ; eax = columna
    mov ebx, [ebp-12]               ; ebx = fila
    
    call is_reserved_encode			; verificar si es area reservada
    cmp eax, 1						; si la funcion devolcio 1 si es area reservada
    je .skip_module1_e				; saltamos esa parte

    ; Verificar si aun tenemos bits por colocar
    mov edx, [ebp-4]                ; indice actual en encoded_bits
    cmp edx, [encoded_bit_len]		; comparar con total de bits codificados
    jge .done_zigzag				; si el indice de bits >= que el total terminamos

    ; Leer bit y colocar en matriz
    movzx eax, byte [encoded_bits + edx]	; cargar byte en encoded_bits
    and al, 1								; asegurar que sea 0 o 1

    ; Calcular offset = fila*25 + columna
    mov ebx, [ebp-12]               ; ebx = fila actual
    imul ebx, 25					; ebx = fila * 25
    add ebx, [ebp-8]                ; ebx = fila * 25 + columna

    mov [esi + ebx], al				; escribir el bit en la posicion calculada de la matriz

    inc dword [ebp-4]				; incrementar indice de bits 

.skip_module1_e:
    mov eax, [ebp-8]                ; eax = columna actual
    dec eax                         ; eax = columna - 1
    mov ebx, [ebp-12]               ; ebx = fila actual
    
    call is_reserved_encode			; verificar si es area reservada
    cmp eax, 1						; comparar si devolvio 1
    je .skip_module2_e				; si es reservada saltamos 

    ; Verificar si aun tenemos bits
    mov edx, [ebp-4]				; edx = bit_index
    cmp edx, [encoded_bit_len]		; comparar con total de bits
    jge .done_zigzag				; si cantidad de bits es mayor o igual al total terminamos 

    movzx eax, byte [encoded_bits + edx]	; cargar bit
    and al, 1								; asegurar que sea 0 o 1

    ; Calcular offset
    mov ebx, [ebp-12]				; ebx = fila
    imul ebx, 25					; ebx = fila * 25
    add ebx, [ebp-8]				; ebx = fila * 25 + columna
    dec ebx                         ; ; ebx = fila * 25 + columna - 1
    
    mov [esi + ebx], al				; escribir en matriz

    inc dword [ebp-4]				; incrementar indice de bits


.skip_module2_e:
	; El patron zigzag alterna entre: 0 bajando (incrementando filas) y 1 subiendo (decrementando filas)
    mov eax, [ebp-16]               ; cargar direction actual
    cmp eax, 1						; comparar si direccion == 1 
    je .move_up_e					; ir a la logica para subir

.move_down_e:
    inc dword [ebp-12]              ; bajar una fila
    mov eax, [ebp-12]				; cargar nueva fila en eax
    cmp eax, 25						; comparar si fila < 25
    jl .zigzag_loop					; si es menor continuar en esa columna

    ; Cambiar direccion si la fila es amyor a 25
    mov dword [ebp-16], 1           ; subir
    dec dword [ebp-12]              ; decrementrar fila para volver a la 24
    sub dword [ebp-8], 2            ; mover dos co;umnas a la izquierda
    jmp .zigzag_loop				; continuar zigzag

.move_up_e:
    dec dword [ebp-12]              ; subir una fila
    mov eax, [ebp-12]				; cargar nueva fila en eax
    cmp eax, 0						; comparar fila >= 0
    jge .zigzag_loop				; si es mayor o igual continuar

    ; Cambiar dirección
    mov dword [ebp-16], 0           ; bajar
    inc dword [ebp-12]              ; incrementar columna para volver a la 0
    sub dword [ebp-8], 2            ; mover dos culumnas a la derecha
    jmp .zigzag_loop				; seguir con zigzag

.done_zigzag:
	; restauramos los registros 
    pop edi
    pop esi
    pop ebx
    add esp, 16
    pop ebp
    ret
