; ============================================================
; qr_pbm.asm
; Crea un archivo PBM de 25x25 con todos los píxeles en 0
; A partir de esto se generara el qr
; ============================================================

%include "io.mac"

.DATA
filename    db "qr_output.pbm", 0      	; nombre del archivo de salida

pbm_header  db "P1", 0Ah               	; formato PBM (ASCII bitmap)
            db "25 25", 0Ah		      	; tamaño de la matriz (25 x 25), más 0 final

strlen_header equ ($ - pbm_header)		; longitud del header = dirección final − dirección inicial

digit_buf   db 0                       	; buffer de 1 byte para '0'/'1'
space_char  db ' '
newline_char db 0Ah

; patrón 7x7 del finder (1 = negro, 0 = blanco)
finder_pattern:
    db 1,1,1,1,1,1,1
    db 1,0,0,0,0,0,1
    db 1,0,1,1,1,0,1
    db 1,0,1,1,1,0,1
    db 1,0,1,1,1,0,1
    db 1,0,0,0,0,0,1
    db 1,1,1,1,1,1,1

; Patrón 5×5 del alignment pattern (1 = negro, 0 = blanco)
alignment_pattern:
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,0,1,0,1
    db 1,0,0,0,1
    db 1,1,1,1,1

.UDATA
global matriz                ; hacemos la matriz global para que otros modulos la usen
matriz  resb 625       		; 25 * 25 = 625 celdas 
fd      resd 1         		; almacena file descriptor del archivo PBM
i       resd 1         		; variable temporal para filas
j       resd 1         		; variable temporal para columnas
tmp_val resb 1                      ; valor temporal (0 o 1) 

.CODE
global qr_generate_pbm       ; funcion principal del modulo

; set_pixel(x, y), eax = x (columna, 0..24), ebx = y (fila, 0..24)
set_pixel:
    ; índice = y * 25 + x
    push eax
    push ebx
    push ecx    ; guarda ecx
    push edx
    
    ; Validar límites
    cmp eax, 0
    jl .skip
    cmp eax, 25
    jge .skip
    cmp ebx, 0
    jl .skip
    cmp ebx, 25
    jge .skip
    
    ; Calcula el indice lineal dentro de la matriz
    mov ecx, ebx                ; ecx = y
    imul ecx, 25                ; ecx = y * 25
    add ecx, eax                ; ecx = y * 25 + x
    
    ; Escribir valor
    mov dl, [tmp_val]           ; carga el valor guardado anteiormente en la variable temporal
    mov [matriz + ecx], dl      ; escribe el valor en la matriz

.skip:
    pop edx
    pop ecx                     ; restaura le valor de ecx
    pop ebx
    pop eax
    ret                         ; vuelve a la funcion que llamo a set_pixel

;dibuja el finder, es decir el cuadrito grande en las esquinas de un qr
dibujar_finder:
	; Guardamos en la pila los registros que vamos a usar
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
	
	; GUardamos donde va a iniciar el patron
    mov esi, eax               	; columna inicial
    mov edi, ebx               	; fila inicial

    xor ecx, ecx               	; fila = 0 (ecx es el contador de filas)

fila_finder:
    cmp ecx, 7					; compara ecx con 7
    jge fin_finder            	; si fila >= 7, terminó el patrón

    xor edx, edx               	; col = 0 (edx es el contador de columnas)

col_finder:
    cmp edx, 7					; compara edx con 7
    jge sig_fila_finder        	; si col >= 7, pasa a la siguiente fila

    ; indice dentro de finder_pattern
    push eax                    ; guardar eax
    mov eax, ecx               	; eax = fila
    imul eax, 7                	; eax = fila * 7
    add eax, edx               	; eax = fila*7 + col

    ; leer valor 0/1 del patrón y guardarlo en tmp_val
    movzx eax, byte [finder_pattern + eax] 	; AL = 0 o 1
    and al, 1                  		; asegurartnos que es solo 0 o 1
    mov [tmp_val], al          		; guardar en variable temporal
    pop eax                     ; restaurar eax

    ; calcular coordenadas x,y
    push eax                    ; guardar eax original
    mov eax, esi				; eax = x0
    add eax, edx               	; eax = x0 + col
    push ebx                    ; guardar ebx original
    mov ebx, edi				; ebx = y0
    add ebx, ecx               	; ebx = y0 + fila

    ; colocar pixel en la matriz
    call set_pixel

    pop ebx                     ; restaurar ebx
    pop eax                     ; restaurar eax

    inc edx                     ; sigueinte columna
    jmp col_finder				; salta a col_finder

sig_fila_finder:
    inc ecx                     ; siguiente fila
    jmp fila_finder				; salta a fila_finder

fin_finder:
	; Restauramos los registros como estaban antes de entrar
    pop edi
    pop ecx
    pop ebx
    pop eax
    pop edx
    pop esi
    ret

; Dibuja el separador (borde blanco) alrededor de un finder pattern
dibujar_separador:
    ; Guardamos en la pila los registros que vamos a usar
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Guardamos la posicion del finder superior izquierdo
    mov esi, eax                ; x0
    mov edi, ebx                ; y0
    
    ; Fila superior (y = y0-1, x = x0-1 hasta x0+7)
    mov ebx, edi
    dec ebx                     ; y = y0 - 1
    cmp ebx, 0
    jl .skip_top

    ; Fila blanca arriba del finder
    mov edx, esi                ; edx = x0
    dec edx                     ; empezamos una columna antes del inicio de finder

.top_loop:
    cmp edx, esi                ; compara el valor de la columna actual con el maximo de columnas donde se deben escribir los 0 
    jl .top_next
    mov ecx, esi
    add ecx, 8                  ; x final = x0 + 8
    cmp edx, ecx
    jge .skip_top
    
    mov eax, edx                ; eax = posicion en la fila actual
    cmp eax, 0
    jl .top_next                ; si x < 0 saltamos sin dibujar
    cmp eax, 25
    jge .top_next               ; si x >= 25 tampoco se dibuja
    
    mov byte [tmp_val], 0
    call set_pixel

.top_next:
    inc edx
    jmp .top_loop               

.skip_top:
    ; Fila inferior (y = y0+7, x = x0-1 hasta x0+7)
    mov ebx, edi
    add ebx, 7
    cmp ebx, 25
    jge .skip_bottom
    
    mov edx, esi
    dec edx

.bottom_loop:
    mov ecx, esi
    add ecx, 8
    cmp edx, ecx
    jge .skip_bottom
    
    mov eax, edx
    cmp eax, 0
    jl .bottom_next
    cmp eax, 25
    jge .bottom_next
    
    mov byte [tmp_val], 0
    call set_pixel

.bottom_next:
    inc edx
    jmp .bottom_loop

.skip_bottom:
    ; Columna izquierda (x = x0-1, y = y0 hasta y0+6)
    mov eax, esi
    dec eax
    cmp eax, 0
    jl .skip_left
    
    mov edx, edi

.left_loop:
    mov ecx, edi
    add ecx, 7
    cmp edx, ecx
    jg .skip_left
    
    mov ebx, edx
    cmp ebx, 0
    jl .left_next
    cmp ebx, 25
    jge .left_next
    
    mov byte [tmp_val], 0
    call set_pixel

.left_next:
    inc edx
    jmp .left_loop

.skip_left:
    ; Columna derecha (x = x0+7, y = y0 hasta y0+6)
    mov eax, esi
    add eax, 7
    cmp eax, 25
    jge .sep_done
    
    mov edx, edi

.right_loop:
    mov ecx, edi
    add ecx, 7
    cmp edx, ecx
    jg .sep_done
    
    mov ebx, edx
    cmp ebx, 0
    jl .right_next
    cmp ebx, 25
    jge .right_next
    
    mov byte [tmp_val], 0
    call set_pixel

.right_next:
    inc edx
    jmp .right_loop

.sep_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; dibujar_timing_patterns en fila 6 y columna 6 sin editar los finder 
dibujar_timing_patterns:
	; Guardamos en la pila los registros que vamos a usar
    push eax
    push ebx
    push ecx
    push edx

    ; Patrón horizontal
    mov ebx, 6            	; inicia en la columna 6
    mov edx, 8            	; inifia en la fila 8 

tim_h_loop:
    cmp edx, 17           	; compara si ya llego a la fila 17 para no escribir sobre el finder que empieza en 18
    jge tim_h_done			; si ya llego salta para terminar

    push eax                ; guardar eax
    mov eax, edx			; copiamos el valor de la fila en eax 
    sub eax, 8				; le restamos 8 al valor de eax
    and eax, 1            	; para imprimir 1 o 0
    xor eax, 1            	; ir alternando 1,0,1,0,...
    mov [tmp_val], al		; guardamos el 1 o 0 en la variable temporal para que luego se escriba con set_pixel
    pop eax                 ; restaurar eax

    push eax                ; guardar eax
    mov eax, edx         	; volvemos a poner el valor de la fila en eax
    push ebx              	; guardamos ebx en la pila para evitar perderlo
    call set_pixel			; llamamos a set_pixel
    pop ebx               	; restauramos ebx
    pop eax                 ; restaurar eax

    inc edx					; incrementamos el valor de la fima
    jmp tim_h_loop			; volvemos a empezar el loop
tim_h_done:


    ; Patrón vertical
    mov eax, 6            	; inicia en la fila 6
    mov ebx, 8            	; inicia en la columna 6
    
tim_v_loop:
    cmp ebx, 17           	; compara si ya llego a la columna 17 para no escribir sobre el finder que empieza en 18
    jge tim_v_done			; si ya llego salta para terminar

    push edx                ; guardar edx
    mov edx, ebx			; copiamos el valor de la columna en edx
    sub edx, 8				; le restamos 8 al valor de edx
    and edx, 1				; para imprimir 1 o 0
    xor edx, 1            	; ir alternando
    mov [tmp_val], dl
    pop edx                 ; restaurar edx
    
	; Guardamos en la pila los registros que vamos a usar
    push ebx              
    push eax              
    call set_pixel			; llamamos para escribir los pixeles
    
    ; Restauramos los registros
    pop eax
    pop ebx

    inc ebx					; incrementamos la columna		
    jmp tim_v_loop			; volvemos a iniciar el loop
tim_v_done:
	
	; Restauramos todos los registros
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; dibujar aligment pattern 
dibujar_alignment:
	; Guardamos los registros que vamos a usar 
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, eax     	; guardar x0
    mov edi, ebx     	; guardar y0
    xor ecx, ecx     	; fila = 0

align_row_loop:
    cmp ecx, 5			; comparamos la cantidad de filas con 5 
    jge align_end     	; si fila >= 5 terminamos

    xor edx, edx     	; columna = 0

align_col_loop:
    cmp edx, 5			; comparamos cantidad de columnas con 5
    jge align_next_row	; si columna >= 5 terminamos

    push eax            ; guardar eax
    mov eax, ecx		; copia el valor de la fila en eax
    imul eax, 5			; multiplica la fila por 5 porque el patron es 5x5
    add eax, edx		; suma la columna edx

    movzx eax, byte [alignment_pattern + eax]		; lee el valor de la varibale alignment_pattern
    mov [tmp_val], al						; guarda le valor en la variable temporal
    pop eax             ; restaurar eax

    ; sacar la coordenada de la fila real
    push eax            ; guardar eax
    mov eax, esi
    add eax, edx
    push ebx            ; guardar ebx

    ; sacar la coordenada de la columna real
    mov ebx, edi
    add ebx, ecx
	
	; se compara con 0 y 25 para evitar salirse d ela matriz
    cmp eax, 0
    jl  align_skip
    cmp eax, 25
    jge align_skip
    cmp ebx, 0
    jl  align_skip
    cmp ebx, 25
    jge align_skip

    call set_pixel

align_skip:
    pop ebx             ; restaurar ebx
    pop eax             ; restaurar eax
    inc edx					; incrementamos columna
    jmp align_col_loop		; saltamos al loop

align_next_row:
    inc ecx					; incrementamos fila
    jmp align_row_loop		; saltamos al loop

align_end:
	; restauramos los registros 
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Deja en 0 las zonas donde van los 15 bits del Format Info, evitando que otros patrones las sobrescriban
reservar_format_info:
	; guardamos en la pila lso registros que van a ser utilizados 
    push eax
    push ebx
    push ecx

    ; Parte junto al finder superior izquierdo 
    mov ebx, 8				; empezamos a dibujar en la fila 8
    mov ecx, 0				; empezamos a dibujar en la columna 0 
rf1:
    cmp ecx, 6				; compara la columna actual con 6
    jge rf1b				; si es mayor o igual salta 
    push eax                ; guardar eax
    mov eax, ecx			; pasamos el valor de la columna actuala eax
	mov ebx, 8				; para evitar segmentation fault
    mov byte [tmp_val], 0	; se escribe en la varibale temporal el valor 0 
    call set_pixel			; llamamos para escribir el pixel
    pop eax                 ; restaurar eax
    inc ecx					; incrementamos la columna
    jmp rf1					; repetimos 
rf1b:
    mov ecx, 7				; ahora empezamos en la columna 7
rf2:
    cmp ecx, 9				; compara la columna con 9 
    jge rf_vert				; si es mayor o igual salta 
    push eax                ; guardar eax
    mov eax, ecx			; movemos el valor de la columna a eax
	mov ebx, 8				; para evitar segmentation fault
    mov byte [tmp_val], 0	; se escribe en la varibale temporal el valor 0 
    call set_pixel			; llamamos esta funcion para escirbir el pixel de la varibale temporal
    pop eax                 ; restaurar eax
    inc ecx					; incrmentamos la columna
    jmp rf2					; salta pra iniciar este loop 

rf_vert:
    mov eax, 8				; empieza en la columna 8
    mov ecx, 0				; empieza en la fila 0
rf3:
	; mismo proceso que en los anteriores 
    cmp ecx, 6
    jge rf3b
    push ebx                ; guardar ebx
    mov ebx, ecx
    mov byte [tmp_val], 0
    call set_pixel
    pop ebx                 ; restaurar ebx
    inc ecx
    jmp rf3
rf3b:
	; restaurar los registros 
    pop ecx
    pop ebx
    pop eax
    ret

; Funcion que solo genera la matriz en memoria, NO escribe archivo
global qr_generate_matrix_only

qr_generate_matrix_only:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Inicializar matriz con ceros 
    mov ecx, 625
    mov edi, matriz
    xor eax, eax
    rep stosb

    ; Dibujar los 3 finder patterns
    mov eax, 0
    mov ebx, 0
    call dibujar_finder         ; Superior izquierdo

    mov eax, 18
    mov ebx, 0
    call dibujar_finder         ; Superior derecho

    mov eax, 0
    mov ebx, 18
    call dibujar_finder         ; Inferior izquierdo

    ; Dibujar separadores SOLO donde no tocan bordes
    mov eax, 0
    mov ebx, 0
    call dibujar_separador      ; Superior izquierdo

    mov eax, 18
    mov ebx, 0
    call dibujar_separador      ; Superior derecho

    ; *** NO llamar separador para inferior izquierdo (toca bordes) ***

    ; Re-dibujar finders para restaurar
    mov eax, 0
    mov ebx, 0
    call dibujar_finder

    mov eax, 18
    mov ebx, 0
    call dibujar_finder

    mov eax, 0
    mov ebx, 18
    call dibujar_finder

    ; Timing patterns
    call dibujar_timing_patterns

    ; Alignment
    mov eax, 16
    mov ebx, 16
    call dibujar_alignment

    ; Formato
    call reservar_format_info

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; Escribe la matriz al archivo qr_output.pbm
global qr_write_pbm

qr_write_pbm:
	; meter los registros a la pila
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Obtener parámetro: nombre de archivo (convención cdecl)
    mov ebx, [ebp+8]        ; ebx = puntero al nombre del archivo (primer parámetro)

    ; Crear/abrir archivo PBM
    mov eax, 5              ; sys_open
    ; ebx ya tiene el nombre del archivo desde el parámetro
    mov ecx, 0x041          ; O_WRONLY
    or  ecx, 0x200          ; O_TRUNC: borra contenido previo
    or  ecx, 0x0400         ; O_CREAT: crea si no existe
    mov edx, 0644o          ; permisos rw-r--r--
    int 0x80
    mov [fd], eax           ; guardar descriptor

    ; Escribir encabezado PBM al archivo 
    mov eax, 4              ; sys_write
    mov ebx, [fd]           ; descriptor
    mov ecx, pbm_header     ; puntero al header
    mov edx, strlen_header  ; longitud del header
    int 0x80				; llamada al sistema 

    ; Escribir matriz 25x25 
    mov dword [i], 0        ; i = 0 (fila)

fila_loop:
    mov eax, [i]            ; eax = i (fila)
    cmp eax, 25				; comparar el eax con 25
    jge end_write           ; si i >= 25, fin

    mov dword [j], 0        ; j = 0 (columna)

col_loop:
    mov eax, [j]			; eax = j (columna)
    cmp eax, 25				; comparar el eax con 25
    jge write_newline       ; si j >= 25, fin de línea

    ; índice = i*25 + j
    mov eax, [i]            ; eax = i
    imul eax, 25            ; eax = i * 25
    add eax, [j]            ; eax = i*25 + j

    ; cargar valor de la matriz (0 o 1)
    mov bl, [matriz + eax]  ; bl = valor
    add bl, '0'             ; convertir a ASCII '0'/'1'

    ; escribir el dígito
    mov [digit_buf], bl     ; guardar en buffer de 1 byte

    mov eax, 4              ; sys_write
    mov ebx, [fd]			; carga el descriptor en ebx
    mov ecx, digit_buf		; ecx apunta al byte que tiene 1 o 0
    mov edx, 1				; dice que se escribira un byte
    int 0x80				; llamada al sistema para ejecutar lo anterior

    ; escribir espacio
    mov eax, 4              ; sys_write
    mov ebx, [fd]			; carga el descriptor en ebx
    mov ecx, space_char		; direccion del espacio
    mov edx, 1				; dice que se escribira un byte
    int 0x80				; llamada al sistema para ejecutar lo anterior

 
    mov eax, [j]			; carga el valor actual del indice de  la columna 
    inc eax					; incrementa la columna
    mov [j], eax			; guarda el valor
    jmp col_loop			; salta a col_loop

write_newline:
    ; escribir salto de línea al final de la fila
    mov eax, 4              ; sys_write
    mov ebx, [fd]			; carga el descriptor en ebx
    mov ecx, newline_char	; direccion del salto de linea
    mov edx, 1				; dice que se escribira un byte
    int 0x80				; llamada al sistema para ejecutar lo anterior

    mov eax, [i]			; carga el valor actual del indice de la fila 
    inc eax					; incrementa la fila
    mov [i], eax			; guarda el valor
    jmp fila_loop			; salta a fila_loop

end_write:
    ; cerrar archivo
    mov eax, 6              ; sys_close
    mov ebx, [fd]
    int 0x80

	xor eax, eax
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; Funcion que llama a las dos anteriores genera la matriz y escribe el archivo 
qr_generate_pbm:
    push ebp
    mov ebp, esp

    call qr_generate_matrix_only
    call qr_write_pbm

    pop ebp
    ret