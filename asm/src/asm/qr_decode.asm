; qr_decode.asm                                             
; Decodificación completa de código QR                     
; Objetivo: Decodificar un código QR versión 2 (25x25) a texto 
;
; Inputs:                                                  
;   Puntero a matriz de 625 bytes (25x25)                 
;   Tamaño de la matriz (25)                              
;   Puntero a buffer de salida (texto)                    
;
; Outputs: Buffer de salida lleno con el texto decodificado 
; EAX: 0 si éxito, -1 si error                            
;

%include "io.mac"                                        

extern detect_all_finders                                  ; Función externa que detecta los 3 finder patterns
extern matriz_ptr                                          ; Variable global externa para guardar puntero a matriz
extern matriz_size                                         ; Variable global externa para guardar tamaño de matriz
extern extract_data_zigzag                                ; Función externa que extrae bits de datos en zigzag
extern extracted_bits                                      ; Buffer externo donde se guardan los bits extraídos
extern decode_bits_to_text                                 ; Función externa que convierte bits en texto

.DATA
    ; Mensaje placeholder (temporal, hasta implementar decodificación real)
    msg_placeholder     db "[Decodificacion pendiente - implementar fase por fase]", 0 ; Mensaje por defecto

    ; Mensajes de debug (opcional)
    msg_inicio          db "Iniciando decodificacion...", 0       ; Texto para indicar inicio del proceso
    msg_validando       db "Validando matriz...", 0               ; Texto para indicar validación de tamaño/datos
    msg_exito           db "Decodificacion exitosa", 0            ; Mensaje de éxito
    msg_error_size      db "Error: Tamano incorrecto", 0          ; Mensaje de error de tamaño
    msg_error_finders   db "Error: No se encontraron los 3 finder patterns", 0 ; Error si no hay 3 patrones

.UDATA                                                      ; Sección de datos no inicializados (reservas)

    global param_matriz                                     ; Exporta param_matriz para que otros módulos lo usen
    global param_size                                       ; Exporta param_size
    global param_output   
    global get_pixel
                                      ; Exporta param_output   

    ; Variables para almacenar parámetros
    param_matriz        resd 1      ; puntero a la matriz    ; Guarda el puntero a la matriz 25x25
    param_size          resd 1      ; tamaño de la matriz    ; Guarda el tamaño (se espera 25)
    param_output        resd 1      ; puntero al buffer de salida ; Dirección del buffer donde se escribe el texto
    
    finder_top_left     resd 2      ; posición (x,y) del finder superior izquierdo  
    finder_top_right    resd 2      ; posición (x,y) del finder superior derecho    
    finder_bottom_left  resd 2      ; posición (x,y) del finder inferior izquierdo  
    
    temp_byte           resb 1      ; byte temporal          ; Variable temporal genérica
    temp_counter        resd 1      ; contador temporal      ; Contador auxiliar si se ocupa

    ; Buffer para los datos extraídos (Fase 1, tamaño fijo)
    datos_buffer     resb 128     ; hasta 128 bytes de “datos” ; Donde se empaquetan los bytes extraídos
    datos_num_bytes  resd 1       ; cuántos bytes se llenaron  ; Número de bytes válidos en datos_buffer
    

.CODE                                                         ; Sección de código (instrucciones)

; Punto de entrada principal (llamada desde C)
; Parámetros (convención cdecl):
;   [ebp+8]  = puntero a matriz (625 bytes)
;   [ebp+12] = tamaño (debe ser 25)
;   [ebp+16] = puntero a buffer de salida
; Retorna:
;   EAX = 0 si éxito, -1 si error
global qr_decode_matrix                                      ; Exporta qr_decode_matrix para que C pueda llamarla

qr_decode_matrix:
    push ebp                        ; guardar frame pointer anterior     
    mov ebp, esp                    ; establecer nuevo frame pointer      
    
    ; Guardar registros que vamos a modificar
    push ebx                        ; Guarda EBX en la pila
    push esi                        ; Guarda ESI
    push edi                        ; Guarda EDI
    
    ; --------------------------------------------------------
    ; Obtener y validar parámetros
    ; --------------------------------------------------------
    mov esi, [ebp+8]                ; ESI = puntero a matriz              
    mov ebx, [ebp+12]               ; EBX = tamaño                        
    mov edi, [ebp+16]               ; EDI = puntero a buffer de salida    
    
    ; Guardar parámetros en variables globales (para usarlos en subfunciones)
    mov [param_matriz], esi         ; Guarda el puntero de matriz en variable global
    mov [param_size], ebx           ; Guarda el tamaño de la matriz
    mov [param_output], edi         ; Guarda el puntero al buffer de salida
    
    ; IMPORTANTE: También guardar para qr_utils.asm
    mov [matriz_ptr], esi           ; Copia puntero de matriz a variable global compartida
    mov [matriz_size], ebx          ; Copia tamaño de matriz a variable global compartida
    
    ; Validar que el tamaño sea 25
    cmp ebx, 25                     ; Compara size con 25
    jne .error_size                 ; si no es 25, ir a error           
    
    ; --------------------------------------------------------
    ; Detectar finder patterns (versión simple)
    ; --------------------------------------------------------
    call detect_all_finders         ; usar detect_all_finders (de qr_detect.asm) 
    
    ; Verificar que se encontraron los 3 finders
    cmp eax, 3                      ; debe retornar 3 (los 3 finders)      
    jl .error_finders               ;  si < 3, ir a error_finders          

    ; --------------------------------------------------------
    ; (Reservado) Leer información de formato
    ; --------------------------------------------------------
    ; Por ahora no hacemos nada aquí. Más adelante se puede  
    ; implementar leer_formato         

    ; --------------------------------------------------------
    ; Extraer datos de la matriz (Fase 1, versión simple)
    ; --------------------------------------------------------
    call extract_data_zigzag        ; Llama a la rutina que recorre el QR en zigzag y llena extracted_bits

    ; --------------------------------------------------------
    ; Decodificar datos a texto
    ; --------------------------------------------------------
    call decode_bits_to_text        ; Convierte los bits extraídos en caracteres de texto
    cmp eax, 0                      ; Verifica el código de retorno de decode_bits_to_text
    jne .error_decode               ; Si no fue 0, hubo algún error en la decodificación

    ; --------------------------------------------------------
    ; Si todo salió bien:
    ; --------------------------------------------------------
    xor eax, eax                   ; EAX = 0 (éxito)                     
    jmp .end                        ; Salta a la parte final común

.error_size:
    mov eax, -1                     ; EAX = -1 (error de tamaño)         
    jmp .end                        ; Salta al epílogo

.error_finders:
    mov eax, -2                     ; EAX = -2 (error: finders no encontrados) 
    jmp .end
.error_decode:
    mov eax, -3                     ; EAX = -3 (error al decodificar bits) 
    jmp .end

.end:
    ; Restaurar registros
    pop edi                         ; Restaura EDI
    pop esi                         ; Restaura ESI
    pop ebx                         ; Restaura EBX
    
    ; Epílogo de función
    pop ebp                         ; Restaura el frame pointer anterior
    ret                             ; retornar a C                       

; Copia el mensaje temporal al buffer de salida
; Inputs:   [param_output] = puntero al buffer de salida
; Outputs:  Buffer lleno con mensaje
; Modifica: EAX, ECX, ESI, EDI

copiar_mensaje_placeholder:
    push ebp
    mov ebp, esp                    ; Establece marco de pila local
    
    push esi                        ; Guarda ESI
    push edi                        ; Guarda EDI
    push ecx                        ; Guarda ECX (contador)
    
    ; Obtener punteros
    mov esi, msg_placeholder        ; ESI = fuente (mensaje)             
    mov edi, [param_output]         ; EDI = destino (buffer)           
    
    ; Copiar hasta encontrar el byte nulo
.loop_copiar:
    mov al, [esi]                   ; AL = byte actual del mensaje       
    mov [edi], al                   ; copiar al buffer de salida         
    
    cmp al, 0                       ; ¿es el terminador nulo?           
    je .fin_copiar                  ; sí → terminar                    
    
    inc esi                         ; siguiente byte fuente               
    inc edi                         ; siguiente byte destino            
    jmp .loop_copiar                ; Repite el bucle

.fin_copiar:
    pop ecx                         ; Restaura ECX
    pop edi                         ; Restaura EDI
    pop esi                         ; Restaura ESI
    
    pop ebp                         ; Restaura EBP
    ret                             ; Regresa a quien llamó la función

; ------------------------------------------------------------
; Detecta los 3 patrones finder (esquinas del QR)
; ------------------------------------------------------------
; Inputs:   [param_matriz] = puntero a matriz 25x25
; Outputs:  Posiciones guardadas en finder_top_left, etc.
; Retorna:  EAX = 0 si éxito, -1 si error
; ------------------------------------------------------------
detectar_finder_patterns:
    push ebp
    mov  ebp, esp                   ; Establece marco de pila local

    ; Llamar a detect_all_finders
    call detect_all_finders         ; EAX = número de finders           

    cmp eax, 3                      ; Compara cantidad de finders con 3
    jl  .error                      ; si hay menos de 3, error

    ; Éxito
    xor eax, eax                    ; EAX = 0                           
    jmp .end

.error:
    mov eax, -1                     ; código de error genérico          

.end:
    pop ebp                         ; Restaura EBP
    ret                             ; Regresa al llamador

; ------------------------------------------------------------
; TODO - Función: leer_formato
; Lee la información de formato del QR
; ------------------------------------------------------------
leer_formato:
    ; IMPLEMENTAR DESPUÉS                                                 ; Lugar reservado para fase futura
    xor eax, eax                    ; Retorna 0 por ahora                ; No hace nada todavía
    ret


; Extrae los bits de datos siguiendo el patrón zigzag
; (Implementación local, alternativa a extract_data_zigzag externa)


; ============================================================
; ZigZag REAL QR (versión 2 - 25x25)
; ============================================================

extraer_datos_zigzag:
    push ebp
    mov  ebp, esp

    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; ---------------------------------------
    ; Inicializar punteros
    ; ---------------------------------------
    xor edi, edi              ; índice de byte en datos_buffer
    xor ecx, ecx              ; bits llenados en el byte actual
    xor edx, edx              ; acumulador de bits (DL)

    mov ebx, 24               ; columna inicial (derecha)
    
.col_loop:
    cmp ebx, 0
    jl .fin_zigzag            ; terminar si ya no hay columnas

    ; Saltar timing pattern (columna 6)
    cmp ebx, 6
    je .skip_col

    ; Recorrer 2 columnas: ebx (derecha) y ebx-1 (izquierda)
    mov eax, ebx              ; x derecha
    mov esi, ebx
    dec esi                   ; x izquierda

    ; Dirección alternante (bajar/subir)
    mov edi, ebx
    shr edi, 1
    test edi, 1
    jz .dir_abajo
    jmp .dir_arriba

; ------------------ BAJANDO -----------------------
.dir_abajo:
    mov edi, 24               ; y = 24 → 0
.y_down:
    cmp edi, -1
    je .end_pair

    ; Leer derecha
    push eax
    push edi
    call get_pixel
    pop edi
    pop eax
    call add_bit

    ; Leer izquierda
    push esi
    push edi
    call get_pixel
    pop edi
    pop esi
    call add_bit

    dec edi
    jmp .y_down

; ------------------ SUBIENDO -----------------------
.dir_arriba:
    mov edi, 0               ; y = 0 → 24
.y_up:
    cmp edi, 25
    je .end_pair

    ; derecha
    push eax
    push edi
    call get_pixel
    pop edi
    pop eax
    call add_bit

    ; izquierda
    push esi
    push edi
    call get_pixel
    pop edi
    pop esi
    call add_bit

    inc edi
    jmp .y_up

.end_pair:
    ; Siguiente par de columnas
    sub ebx, 2
    jmp .col_loop

.skip_col:
    sub ebx, 1
    jmp .col_loop

.fin_zigzag:
    ; Guardar bytes restantes
    cmp ecx, 0
    je .fin_ok

    mov esi, datos_buffer
    add esi, edi
    mov [esi], dl
    inc edi

.fin_ok:
    mov [datos_num_bytes], edi

    xor eax, eax

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ===========================================================
; add_bit: agrega AL al acumulador DL y escribe bytes completos
; ===========================================================
add_bit:
    shl dl, 1
    and al, 1
    or dl, al

    inc ecx
    cmp ecx, 8
    jne .done

    mov esi, datos_buffer
    add esi, edi
    mov [esi], dl

    inc edi
    xor ecx, ecx
    xor edx, edx

.done:
    ret

    
    
; ------------------------------------------------------------
; Función: decodificar_datos
; Convierte los bits extraídos en texto
; ------------------------------------------------------------
decodificar_datos:
    push ebp
    mov  ebp, esp             ; Establece marco de pila

    push eax
    push ebx
    push ecx
    push esi
    push edi

    ; EDI = destino (buffer de salida)
    mov edi, [param_output]   ; Carga el puntero al buffer donde va el texto

    ; ESI = origen (datos_buffer)
    mov esi, datos_buffer     ; Origen: bytes de datos extraídos

    ; ECX = número de bytes que llenamos
    mov ecx, [datos_num_bytes] ; Cantidad de bytes a copiar

    ; Si no hay datos, sólo ponemos terminador
    cmp ecx, 0
    je .poner_nulo            ; Si no hay bytes, solo escribimos '\0'

.copiar_loop:
    mov al, [esi]             ; Lee un byte de datos_buffer
    mov [edi], al             ; Lo copia al buffer de salida

    inc esi                   ; Avanza en origen
    inc edi                   ; Avanza en destino

    loop .copiar_loop         ; Decrementa ECX y repite mientras ECX != 0

.poner_nulo:
    mov byte [edi], 0         ; terminador de cadena C (fin de texto)

    ; Éxito
    xor eax, eax              ; EAX = 0

    pop edi                   ; Restaura registros
    pop esi
    pop ecx
    pop ebx
    pop eax

    pop ebp                   ; Restaura marco de pila
    ret                       ; Devuelve control

; ------------------------------------------------------------
; Obtiene el valor de un pixel en la matriz
; ------------------------------------------------------------
; Inputs:
;   EAX = x (columna, 0-24)
;   EBX = y (fila, 0-24)
;   [param_matriz] = puntero a matriz
;
; Output:
;   AL = valor del pixel (0 o 1)
; Modifica: EAX, EBX, ECX
; ------------------------------------------------------------
get_pixel:
    push ebp
    mov ebp, esp              ; Marco de pila local
    
    push edx
    push esi
    
    ; Validar rangos
    cmp eax, 25
    jge .error                ; Si x >= 25, error
    cmp ebx, 25
    jge .error                ; Si y >= 25, error
    cmp eax, 0
    jl .error                 ; Si x < 0, error
    cmp ebx, 0
    jl .error                 ; Si y < 0, error
    
    ; Calcular índice: índice = y * 25 + x
    imul ebx, 25              ; EBX = y * 25
    add ebx, eax              ; EBX = y * 25 + x
    
    ; Obtener puntero a matriz
    mov esi, [param_matriz]   ; ESI = puntero a matriz
    
    ; Leer el byte en la posición calculada
    mov al, [esi + ebx]       ; AL = matriz[y*25 + x]
    
    and al, 1                 ; asegurar que es 0 o 1 (normalizar)

    jmp .end                  ; Salta al final

.error:
    mov al, 0                 ; retornar 0 en caso de error de índice

.end:
    pop esi                   ; Restaura ESI
    pop edx                   ; Restaura EDX
    
    pop ebp                   ; Restaura marco de pila
    ret                       ; Regresa al llamador

; ------------------------------------------------------------
; Establece el valor de un pixel en la matriz
; ------------------------------------------------------------
; Inputs:
;   EAX = x (columna, 0-24)
;   EBX = y (fila, 0-24)
;   CL = valor a establecer (0 o 1)
;   [param_matriz] = puntero a matriz
;
; Modifica: EAX, EBX, EDX, ESI
; ------------------------------------------------------------
set_pixel:
    push ebp
    mov ebp, esp              ; Marco de pila
    
    push edx
    push esi
    
    ; Validar rangos
    cmp eax, 25
    jge .end                  ; Si x fuera de rango, salir sin hacer nada
    cmp ebx, 25
    jge .end                  ; Si y fuera de rango, salir
    cmp eax, 0
    jl .end                   ; x < 0 → nada
    cmp ebx, 0
    jl .end                   ; y < 0 → nada
    
    ; Calcular índice: índice = y * 25 + x
    imul ebx, 25              ; EBX = y * 25
    add ebx, eax              ; EBX = y * 25 + x
    
    ; Obtener puntero a matriz
    mov esi, [param_matriz]   ; ESI = puntero a matriz
    
    ; Guardar el valor (asegurar que es 0 o 1)
    and cl, 1                 ; CL = CL & 1 → normaliza a 0/1
    mov [esi + ebx], cl       ; matriz[y*25 + x] = CL

.end:
    pop esi                   ; Restaura ESI
    pop edx                   ; Restaura EDX
    
    pop ebp                   ; Restaura EBP
    ret                       ; Vuelve al llamador

