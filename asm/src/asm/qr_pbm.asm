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
    push ecx					; guarda ecx
    
    ; Calcula el indice lineal dentro de la matriz
    imul ebx, 25               	; ebx = y * 25
    add  ebx, eax              	; ebx = y*25 + x
    
    mov  al, [tmp_val]        	; carga el valor guardado anteiormente en la varibale temporal
    mov  [matriz + ebx], al    	; escribe el valor en la matriz
    pop ecx						; restaura le valor de ecx
    ret							; vuelve a la funcion que llamo a set_pixel

;dibuja el finder, es decir el cuadrito grande en las esquinas de un qr
dibujar_finder:
	; Guardamos en la pila los registros que vamos a usar
    push eax
    push ebx
    push ecx
    push edx
	
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
    mov eax, ecx               	; eax = fila
    imul eax, 7                	; eax = fila * 7
    add eax, edx               	; eax = fila*7 + col

    ; leer valor 0/1 del patrón y guardarlo en tmp_val
    mov al, [finder_pattern + eax] 	; AL = 0 o 1
    and al, 1                  		; asegurartnos que es solo 0 o 1
    mov [tmp_val], al          		; guardar en variable temporal

    ; calcular coordenadas x,y
    mov eax, esi				; eax = x0
    add eax, edx               	; eax = x0 + col
    mov ebx, edi				; ebx = y0
    add ebx, ecx               	; ebx = y0 + fila

    ; colocar pixel en la matriz
    call set_pixel

    inc edx                     ; sigueinte columna
    jmp col_finder				; salta a col_finder

sig_fila_finder:
    inc ecx                     ; siguiente fila
    jmp fila_finder				; salta a fila_finder

fin_finder:
	; Restauramos los registros como estaban antes de entrar
    pop edx
    pop ecx
    pop ebx
    pop eax
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
    mov esi, eax                 	; x0
    mov edi, ebx                 	; y0

    ; Fila blanca arriba del finder
    mov edx, esi                 	; edx = x0
    dec edx                      	; empezamos una columna antes del inicio de finder
    mov ecx, esi					; ecx = x0
    add ecx, 7                   	; avanzamos hasta una columna despues de la ultima columna del finder
    mov ebx, edi                 	; ebx = y0
    dec ebx                      	; empezamos una fila arriba del inicio del finder

sep_top_loop:
    cmp edx, ecx					; compara el valor de la columna actual con el maximo de columnas donde se deben escribir los 0 
    jg sep_top_done              	; si el numero actual es mayor que 7 terminamos esa fila

    mov eax, edx                 	; eax = posicion en la fila actual

    ; Comprobar que (x,y) estan dentro de la matriz 
    cmp eax, 0
    jl  sep_top_next				; si x < 0 saltamos sin dibujar
    cmp eax, 25
    jge sep_top_next				; si x >= 25 tampoco se dibuja
    cmp ebx, 0
    jl  sep_top_next				; si y < 0 saltamos sin dibujar
    cmp ebx, 25
    jge sep_top_next				; si y >= 25 tampoco se dibuja
	; si llega a esta parte es porque tanto el x como el y es valido y se debe poner un 0 
    mov byte [tmp_val], 0        	; escribir 0
    call set_pixel					; escribe el 0 en la matriz

sep_top_next:
    inc edx                      	;pasamos a la siguiente columna
    jmp sep_top_loop
sep_top_done:

    ; Fila abajo del finder
    mov edx, esi                 	; edx = x0
    dec edx                      	; empezamos una columna antes del inicio de finder
    mov ecx, esi					; ecx = x0
    add ecx, 7                   	; avanzamos hasta una columna despues de la ultima columna del finder
    mov ebx, edi					; ebx = y0
    add ebx, 7                   	; bajamos hasta una fila despues del finder

sep_bottom_loop:
    cmp edx, ecx					; compara el valor de la columna actual con el maximo de columnas
    jg sep_bottom_done				; si el valor actual es mayor que el maximo salta a sep_bottom_done

    mov eax, edx                 	; eax = fila actual
    
	; Otra vez comprobamos que (x,y) estan dentro de la matriz 
    cmp eax, 0
    jl  sep_bottom_next
    cmp eax, 25
    jge sep_bottom_next
    cmp ebx, 0
    jl  sep_bottom_next
    cmp ebx, 25
    jge sep_bottom_next

    mov byte [tmp_val], 0
    call set_pixel

sep_bottom_next:
    inc edx							; pasamos a la siguiente columna
    jmp sep_bottom_loop				; salta al loop 
    
sep_bottom_done:

    ; Columna blanca a la izquierda del finder
    mov eax, esi
    dec eax                      	; empezamos una columna antes del inicio de finder
    mov edx, edi
    dec edx                      	; empezamos una fila antes del inicio de finder
    mov ecx, edi
    add ecx, 7                   	; bajamos hasta una fila despues del finder

sep_left_loop:
    cmp edx, ecx					; compara el valor de la fila actual con el maximo de filas del seprador
    jg sep_left_done				; si es mayor salta a sep_left_done

	; Otra vez comprobamos que (x,y) estan dentro de la matriz 
    cmp eax, 0
    jl  sep_left_next
    cmp eax, 25
    jge sep_left_next
    cmp ebx, 0
    jl  sep_left_next
    cmp ebx, 25
    jge sep_left_next

    mov byte [tmp_val], 0

	mov ebx, edx                 	; ebx = y actual
    mov eax, eax 					; eax = x actual

    call set_pixel

sep_left_next:
    inc edx                      	; pasamos a la sigueinte fila
    jmp sep_left_loop
sep_left_done:

    ; Columna blanca a la derecha del finder
    mov eax, esi
    add eax, 7                   	; empezamos una columna despues del final de finder
    mov edx, edi
    dec edx                      	; empezamos una fila antes del inicio de finder
    mov ecx, edi
    add ecx, 7                   	; bajamos hasta una fila despues del finder

sep_right_loop:
    cmp edx, ecx					; compara el valor de la fila actual con el maximo de filas del separador
    jg sep_right_done

    mov ebx, edx                 	; ebx = y actual
	
	; Otra vez comprobamos que (x,y) estan dentro de la matriz 
    cmp eax, 0
    jl  sep_right_next
    cmp eax, 25
    jge sep_right_next
    cmp ebx, 0
    jl  sep_right_next
    cmp ebx, 25
    jge sep_right_next

    mov byte [tmp_val], 0
    call set_pixel

sep_right_next:
    inc edx                      	; incrementa la fila
    jmp sep_right_loop				; despues de incrementar salta al loop 
sep_right_done:

    ; Restaurar registros
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

    mov eax, edx			; copiamos el valor de la fila en eax 
    sub eax, 8				; le restamos 8 al valor de eax
    and eax, 1            	; para imprimir 1 o 0
    xor eax, 1            	; ir alternando 1,0,1,0,...
    mov [tmp_val], al		; guardamos el 1 o 0 en la variable temporal para que luego se escriba con set_pixel

    mov eax, edx         	; volvemos a poner el valor de la fila en eax
    push ebx              	; guardamos ebx en la pila para evitar perderlo
    call set_pixel			; llamamos a set_pixel
    pop ebx               	; restauramos ebx

    inc edx					; incrementamos el valor de la fima
    jmp tim_h_loop			; volvemos a empezar el loop
tim_h_done:


    ; Patrón vertical
    mov eax, 6            	; inicia en la fila 6
    mov ebx, 8            	; inicia en la columna 6
    
tim_v_loop:
    cmp ebx, 17           	; compara si ya llego a la columna 17 para no escribir sobre el finder que empieza en 18
    jge tim_v_done			; si ya llego salta para terminar

    mov edx, ebx			; copiamos el valor de la columna en edx
    sub edx, 8				; le restamos 8 al valor de edx
    and edx, 1				; para imprimir 1 o 0
    xor edx, 1            	; ir alternando
    mov [tmp_val], dl
    
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

    mov eax, ecx		; copia el valor de la fila en eax
    imul eax, 5			; multiplica la fila por 5 porque el patron es 5x5
    add eax, edx		; suma la columna edx

    mov al, [alignment_pattern + eax]		; lee el valor de la varibale alignment_pattern
    mov [tmp_val], al						; guarda le valor en la variable temporal

    ; sacar la coordenada de la fila real
    mov eax, esi
    add eax, edx

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

    call set_pixel			;

align_skip:
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
    mov eax, ecx			; pasamos el valor de la columna actuala eax
	mov ebx, 8				; para evitar segmentation fault
    mov byte [tmp_val], 0	; se escribe en la varibale temporal el valor 0 
    call set_pixel			; llamamos para escribir el pixel
    inc ecx					; incrementamos la columna
    jmp rf1					; repetimos 
rf1b:
    mov ecx, 7				; ahora empezamos en la columna 7
rf2:
    cmp ecx, 9				; compara la columna con 9 
    jge rf_vert				; si es mayor o igual salta 
    mov eax, ecx			; movemos el valor de la columna a eax
	mov ebx, 8				; para evitar segmentation fault
    mov byte [tmp_val], 0	; se escribe en la varibale temporal el valor 0 
    call set_pixel			; llamamos esta funcion para escirbir el pixel de la varibale temporal
    inc ecx					; incrmentamos la columna
    jmp rf2					; salta pra iniciar este loop 

rf_vert:
    mov eax, 8				; empieza en la columna 8
    mov ecx, 0				; empieza en la fila 0
rf3:
	; mismo proceso que en los anteriores 
    cmp ecx, 6
    jge rf3b
    mov ebx, ecx
    mov byte [tmp_val], 0
    call set_pixel
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
    mov ecx, 625            ; numero de bytes 
    mov edi, matriz         ; direccion de inicio 
    xor eax, eax            ; valor 0
    rep stosb               ; llena matriz con 0

    ; Dibujar los 3 finder patterns
    ; Superior izquierdo (0,0)
    mov eax, 0
    mov ebx, 0
    call dibujar_finder

    ; Superior derecho (25 - 7 = 18, 0)
    mov eax, 18
    mov ebx, 0
    call dibujar_finder

    ; Inferior izquierdo (0, 25 - 7 = 18)
    mov eax, 0
    mov ebx, 18
    call dibujar_finder

	; Dibujar separadores alrededor de los finders
    ; Separador del finder superior izquierdo
    mov eax, 0
    mov ebx, 0
    call dibujar_separador

    ; Separador del finder superior derecho
    mov eax, 18
    mov ebx, 0
    call dibujar_separador

    ; Separador del finder inferior izquierdo
    mov eax, 0
    mov ebx, 18
    call dibujar_separador

	; volver a llamar finders izqueirdos para corregir bug 
    ; Superior izquierdo (0,0)
    mov eax, 0
    mov ebx, 0
    call dibujar_finder

    ; Inferior izquierdo (0,18)
    mov eax, 0
    mov ebx, 18
    call dibujar_finder
    
    ; Dibujar timing patterns
    call dibujar_timing_patterns

	; Alignment pattern (posición 18,18)
	mov eax, 18
	mov ebx, 18
	call dibujar_alignment

	; Parte del format information
	call reservar_format_info

	; Restauramos los registros
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

    
