; qr_decode_data.asm
; Decodificación de bits a texto


%include "io.mac"

; declaraciones externas
extern extracted_bits
extern param_output
extern param_matriz
extern ecc_decode
extern ecc_get_corrected_data


.DATA
    msg_decoding            db "Decodificando bits a texto...", 0
    msg_mode_not_supported  db "Modo de codificacion no soportado aun", 0
    msg_unknown_mode        db "Modo de codificacion desconocido", 0
    msg_ecc_failed          db "Error ECC: demasiados errores", 0
    msg_debug_mode          db "Modo leido (decimal): ", 0
    msg_newline             db 10, 0            ; salto de línea

.UDATA
    mode            resd 1          ; Guarda el modo de codificación (4 bits → valor entero)
    char_count      resd 1          ; Cantidad de caracteres que hay que leer/decodificar
    bit_position    resd 1          ; Índice del bit actual dentro de extracted_bits
    current_byte    resb 1          ; Byte temporal (no muy usado aquí)
    bits_in_byte    resd 1          ; Contador de bits dentro de un byte (no muy usado aquí)

    ; Buffer para datos antes de corrección (44 bytes: 32 datos + 8 fila + 4 col)
    raw_bytes       resb 44         ; Bytes sin corregir


.CODE

; ============================================================
; FUNCIÓN: bits_to_bytes
; Convierte los bits extraídos a bytes para Reed-Solomon
; ============================================================
bits_to_bytes:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, extracted_bits         ; Origen: bits extraídos
    mov edi, raw_bytes              ; Destino: buffer de bytes
    xor ebx, ebx                    ; Contador de bytes generados

.byte_loop:
    cmp ebx, 44                     ; ¿Ya convertimos 44 bytes?
    jge .done

    xor eax, eax                    ; Acumulador para el byte actual
    mov ecx, 8                      ; 8 bits por byte

.bit_loop:
    shl eax, 1                      ; Desplazar acumulador a la izquierda
    movzx edx, byte [esi]           ; Leer bit (cada posición contiene 0 o 1)
    or al, dl                       ; Agregar bit al acumulador
    inc esi                         ; Siguiente bit
    loop .bit_loop

    mov [edi], al                   ; Guardar byte completo
    inc edi                         ; Siguiente posición en destino
    inc ebx                         ; Incrementar contador
    jmp .byte_loop

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

read_bits:
    push ebp
    mov ebp, esp                    ; Crea marco de pila para la función
    
    push edi                        ; Guarda registros que podríamos tocar
    push edx
    
    xor eax, eax                    ; EAX = 0 → empezamos sin bits acumulados
    mov esi, extracted_bits         ; ESI = base del arreglo de bits
    add esi, [bit_position]         ; ESI apunta al bit/byte en posición bit_position
    
.read_loop:
    cmp ecx, 0                      ; Quedan bits por leer?
    je .done                        ; Si ECX == 0, terminamos
    
    shl eax, 1                      ; EAX <<= 1 → hacemos espacio para el nuevo bit
    
    movzx ebx, byte [esi]           ; EBX = byte actual (extendido a 32 bits)
    or al, bl                       ; OR con AL: mete el bit/byte leído en el LSB de EAX
    
    inc esi                         ; Avanzamos al siguiente byte/bit en extracted_bits
    inc dword [bit_position]        ; bit_position++ → avanzamos el índice global
    
    dec ecx                         ; Un bit menos por leer
    jmp .read_loop                  ; Repetimos hasta consumir todos los bits

.done:
    pop edx                         ; restauramos registros
    pop edi                          
    
    pop ebp                         ; restauramos marco
    ret                             ; nos devolvemos con el resutlado en EAX 

decode_byte_mode:
    push ebp
    mov ebp, esp                    ; Marco de pila
    
    push ebx
    push esi
    push edi
    
    mov edi, [param_output]         ; EDI = destino (buffer de salida)
    mov ebx, [char_count]           ; EBX = número de caracteres a decodificar
    
.decode_loop:
    cmp ebx, 0                      ; ¿Ya decodificamos todos los chars?
    je .done                        ; Si sí, pasamos a poner el terminador
    
    mov ecx, 8                      ; 8 bits por carácter
    call read_bits                  ; EAX = siguiente byte (carácter)
    
    mov [edi], al                   ; Guarda el carácter en el buffer
    inc edi                         ; Avanza en el buffer destino
    
    dec ebx                         ; Falta un carácter menos
    jmp .decode_loop                ; Sigue con el siguiente

.done:
    mov byte [edi], 0               ; Agrega '\0' al final del string
    
    pop edi
    pop esi
    pop ebx
    
    pop ebp
    ret                             ; Vuelve a la función llamadora

copy_string:
    push eax                       ; Guardamos EAX porque lo usamos como temporal
    
.loop:
    mov al, [esi]                   ; AL = byte actual de la cadena origen
    mov [edi], al                   ; Copia al destino
    
    cmp al, 0                       ; ¿Es fin de cadena?
    je .done                        ; Sí → terminamos
    
    inc esi                         ; Avanzamos origen
    inc edi                         ; Avanzamos destino
    jmp .loop                       ; Repetimos

.done:
    pop eax                         ; Restauramos EAX
    ret                             ; Finaliza la función

global decode_bits_to_text

decode_bits_to_text:
    push ebp
    mov ebp, esp                   ; marco de pila

    push ebx
    push esi
    push edi

    ; --------------------------------------------------------
    ; PASO 1: Convertir bits extraídos a bytes
    ; --------------------------------------------------------
    call bits_to_bytes

    ; --------------------------------------------------------
    ; PASO 2: Aplicar corrección de errores (Paridad 2D)
    ; --------------------------------------------------------
    mov esi, raw_bytes              ; ESI = puntero a datos sin corregir
    call ecc_decode                 ; Corregir errores

    ; Verificar si la corrección fue exitosa
    cmp eax, -1
    je .ecc_error                   ; Si retorna -1, demasiados errores

    ; --------------------------------------------------------
    ; PASO 3: Obtener datos corregidos
    ; --------------------------------------------------------
    call ecc_get_corrected_data     ; EAX = puntero a datos corregidos

    ; Copiar datos corregidos a extracted_bits para procesamiento normal
    mov esi, eax                    ; ESI = datos corregidos
    mov edi, extracted_bits
    mov ecx, 32                     ; Solo 32 bytes de datos

.copy_corrected:
    movzx eax, byte [esi]           ; Leer byte corregido en AL
    mov edx, 8                      ; 8 bits por byte
    push ecx
    mov ecx, 7                      ; Empezar del bit 7 (MSB)

.expand_byte:
    mov ebx, eax                    ; Copiar byte a EBX
    shr ebx, cl                     ; Desplazar para obtener bit en posición CL
    and ebx, 1                      ; Aislar el bit
    mov [edi], bl                   ; Guardar bit (0 o 1)
    inc edi
    test ecx, ecx                   ; Verificar si ECX es 0
    jz .done_byte                   ; Si es 0, terminar
    dec ecx
    jmp .expand_byte

.done_byte:

    pop ecx
    inc esi
    loop .copy_corrected

    ; --------------------------------------------------------
    ; PASO 4: Decodificar normalmente
    ; --------------------------------------------------------
    mov dword [bit_position], 0  ; Reinicia la posición de lectura de bits a 0

     ; Leer modo (4 bits)
    mov ecx, 4                      ; Vamos a leer 4 bits
    call read_bits                  ; EAX = modo de codificación
    mov [mode], eax                 ; Guarda el modo en la variable mode
    
    ; DEBUG: imprimir modo leído
    PutStr msg_debug_mode     ; imprime el texto
    mov eax, [mode]           ; EAX = valor que leímos para modo
    PutLInt  EAX                   ; imprime EAX en decimal
    PutStr msg_newline        ; salto de línea

    ; Verificar modo Byte (0100 = 4)
    cmp dword [mode], 4             ; mode == 4? (modo byte)
    jne .try_alphanumeric           ; Si no es 4, probar con alfanumérico
    
    ; Modo Byte: leer 8 bits para contador
    mov ecx, 8                      ; 8 bits para la cantidad de caracteres
    call read_bits                  ; EAX = cantidad de caracteres
    mov [char_count], eax           ; Guarda char_count
    
    call decode_byte_mode           ; Decodifica todos los chars en modo byte
    jmp .success                    ; Ir a camino feliz
    
.try_alphanumeric:
    cmp dword [mode], 2             ; ¿mode == 2? (modo alfanumérico)
    jne .try_numeric                ; Si no, probamos si es modo numérico
    
    mov ecx, 6                      ; En QR, el contador para alfanumérico suele ser de 9/11/13 bits, aquí usamos 6 (simplificado)
    call read_bits                  ; EAX = cantidad de caracteres (simplificado)
    mov [char_count], eax           ; Guarda char_count
    
    mov edi, [param_output]         ; Destino de texto
    mov esi, msg_mode_not_supported ; Mensaje de “no implementado”
    call copy_string                ; Copia el mensaje al buffer
    jmp .error                      ; Salimos con error lógico (no soportado)
    
.try_numeric:
    cmp dword [mode], 1             ; ¿mode == 1? (modo numérico)
    jne .unknown_mode               ; Si no, entonces es un modo desconocido
    
    mov ecx, 7                      ; Contador para modo numérico (simplificado)
    call read_bits                  ; EAX = cantidad de dígitos
    mov [char_count], eax           ; Guarda el contador
    
    mov edi, [param_output]         ; Destino de texto
    mov esi, msg_mode_not_supported ; Mismo mensaje de “aún no soportado”
    call copy_string                ; Copia el mensaje
    jmp .error                      ; Salimos con error
    
.unknown_mode:
    mov edi, [param_output]         ; Destino de texto
    mov esi, msg_unknown_mode       ; Mensaje de modo desconocido
    call copy_string                ; Copia el mensaje
    jmp .error                      ; Salimos por la ruta de error

.ecc_error:
    mov edi, [param_output]         ; Destino de texto
    mov esi, msg_ecc_failed         ; Mensaje de error ECC
    call copy_string                ; Copia el mensaje
    jmp .error                      ; Salimos por la ruta de error

.success:
    xor eax, eax                    ; EAX = 0 → éxito
    jmp .end                        ; Fin normal

.error:
    mov eax, -1                     ; EAX = -1 → error lógico en la decodificación

.end:
    pop edi                         ; Restauramos registros
    pop esi
    pop ebx

    pop ebp                         ; Restauramos marco
    ret                             ; Regresamos a qr_decode.asm / C
