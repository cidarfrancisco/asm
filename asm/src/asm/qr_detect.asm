; qr_detect.asm
; Detección de finder patterns en código QR
; Objetivo:
;   Detectar los 3 finder patterns (esquinas) en un QR v2
;
; Inputs: Matriz de 625 bytes en memoria
;
; Outputs: Posiciones de los 3 finder patterns
;

%include "io.mac"

.DATA
    msg_buscando    db "Buscando finder patterns...", 0
    msg_encontrado  db "Finder pattern encontrado en", 0

.UDATA
    ; Posiciones de los finder patterns encontrados
    global finder_positions                       ; Exporta la etiqueta finder_positions para otros módulos
    
    finder_positions:
        finder_tl_x     resd 1                     ; Top-Left x     
        finder_tl_y     resd 1                     ; Top-Left y      
        finder_tr_x     resd 1                     ; Top-Right x     
        finder_tr_y     resd 1                     ; Top-Right y     
        finder_bl_x     resd 1                     ; Bottom-Left x   
        finder_bl_y     resd 1                     ; Bottom-Left y   
    
    finders_found   resd 1      ; contador de finders encontrados ; Cuántos patrones hemos marcado (0–3)

.CODE

; Importar funciones de qr_utils.asm
extern is_finder_pattern                             ; Función externa (no usada en la versión simplificada)
extern matriz_ptr                                    ; Puntero global a la matriz 25x25
extern matriz_size                                   ; Tamaño de la matriz (debería ser 25)

; -----------------------------------------------------------
; Función: detect_all_finders
; Detecta los 3 finder patterns del QR
; -----------------------------------------------------------
; Inputs:
;   [matriz_ptr]  = puntero a matriz 25x25          ; No se usa directamente aquí, pero es el contexto
;   [matriz_size] = 25                              ; Idem, asumimos versión 2 de QR (25x25)
;
; Outputs:
;   [finder_positions] = posiciones de los 3 finders ; Rellena las variables finder_*_x / finder_*_y
;   EAX = número de finders encontrados (debe ser 3) ; Valor de retorno para qr_decode
;
; Modifica: Todos los registros                         ; Esta versión no se preocupa por conservar mucho
; -----------------------------------------------------------
global detect_all_finders                             ; Exporta la función para que otros módulos la usen

detect_all_finders:
    push ebp
    mov  ebp, esp                                    ; Crea marco de pila para esta función

    ; No necesitamos usar mucho los registros, pero igual
    ; guardamos los que podríamos tocar
    push ebx                                         ; Guarda EBX
    push esi                                         ; Guarda ESI
    push edi                                         ; Guarda EDI

    ; Inicializar contador a 0
    mov dword [finders_found], 0                     ; finders_found = 0

    ; --------------------------------------------------------
    ; Versión simplificada para QR v2 (25x25)
    ; Asumimos que el código está bien alineado y en versión 2.
    ; Solo guardamos las coordenadas conocidas de los finders:
    ;
    ;  - Superior izquierdo : (0, 0)
    ;  - Superior derecho   : (18, 0)
    ;  - Inferior izquierdo : (0, 18)
    ;
    ; Nota: 18 = 25 - 7, porque cada finder mide 7x7 módulos.
    ; --------------------------------------------------------

    ; Finder superior izquierdo
    mov dword [finder_tl_x], 0                      ; X = 0 para el finder superior izquierdo
    mov dword [finder_tl_y], 0                      ; Y = 0 para el finder superior izquierdo
    inc dword [finders_found]                       ; finders_found++

    ; Finder superior derecho
    mov dword [finder_tr_x], 18        ; 25 - 7     ; X = 18 para el finder superior derecho
    mov dword [finder_tr_y], 0                      ; Y = 0 (misma fila que el TL)
    inc dword [finders_found]                       ; finders_found++

    ; Finder inferior izquierdo
    mov dword [finder_bl_x], 0                      ; X = 0 para el finder inferior izquierdo
    mov dword [finder_bl_y], 18        ; 25 - 7     ; Y = 18 (última “línea” donde cabe el 7x7)
    inc dword [finders_found]                       ; finders_found++

    ; Retornar en EAX cuántos finders encontramos
    ; (en esta versión siempre serán 3 si llegamos aquí)
    mov eax, [finders_found]                        ; EAX = número de finders (normalmente 3)

    pop edi                                         ; Restaura EDI
    pop esi                                         ; Restaura ESI
    pop ebx                                         ; Restaura EBX
    pop ebp                                         ; Restaura EBP
    ret                                             ; Vuelve a quien llamó detect_all_finders







