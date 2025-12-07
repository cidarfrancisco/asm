; ============================================================
; rs_gf256.asm
; Operaciones aritméticas en GF(256) - Campo de Galois
; Usado para Reed-Solomon en códigos QR
; ============================================================

%include "io.mac"

; Importar tablas de rs_tables.asm
extern gf_exp
extern gf_log

.CODE

; ============================================================
; FUNCIÓN: gf_mul
; Multiplica dos elementos en GF(256)
; Fórmula: a * b = exp(log(a) + log(b) mod 255)
; ============================================================
; Inputs:
;   AL = primer operando (a)
;   BL = segundo operando (b)
; Output:
;   AL = resultado de a * b en GF(256)
; ============================================================
global gf_mul
gf_mul:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    push ecx                    ; preservar registros
    push edx
    push esi
    
    ; ============================================================
    ; CASO ESPECIAL: Multiplicación por cero
    ; En GF(256), 0 * x = 0 para todo x
    ; ============================================================
    test al, al                 ; ¿a == 0?
    jz .result_zero             ; si a = 0, resultado = 0
    test bl, bl                 ; ¿b == 0?
    jz .result_zero             ; si b = 0, resultado = 0
    
    ; ============================================================
    ; MULTIPLICACIÓN USANDO LOGARITMOS
    ; log(a*b) = log(a) + log(b) mod 255
    ; ============================================================
    movzx ecx, al               ; ecx = a (extender a 32 bits)
    movzx edx, bl               ; edx = b (extender a 32 bits)
    
    mov esi, gf_log             ; esi = puntero a tabla de logaritmos
    movzx ecx, byte [esi + ecx] ; ecx = log(a)
    movzx edx, byte [esi + edx] ; edx = log(b)
    
    add ecx, edx                ; ecx = log(a) + log(b)
    
    ; ============================================================
    ; REDUCCIÓN MÓDULO 255
    ; Si la suma >= 255, restar 255
    ; ============================================================
    cmp ecx, 255                ; ¿suma >= 255?
    jl .no_reduce               ; si no, continuar
    sub ecx, 255                ; sí → reducir módulo 255
.no_reduce:
    
    ; ============================================================
    ; ANTILOGARITMO: exp(log(a) + log(b))
    ; ============================================================
    mov esi, gf_exp             ; esi = puntero a tabla de exponentes
    movzx eax, byte [esi + ecx] ; eax = exp(log(a) + log(b))
    
    jmp .end                    ; ir al final

.result_zero:
    xor eax, eax                ; resultado = 0

.end:
    pop esi                     ; restaurar registros
    pop edx
    pop ecx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: gf_div
; Divide dos elementos en GF(256)
; Fórmula: a / b = exp(log(a) - log(b) mod 255)
; ============================================================
; Inputs:
;   AL = dividendo (a)
;   BL = divisor (b)
; Output:
;   AL = resultado de a / b en GF(256)
; Nota: División por cero no está definida
; ============================================================
global gf_div
gf_div:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    push ecx                    ; preservar registros
    push edx
    push esi
    
    ; ============================================================
    ; CASO ESPECIAL: Dividendo es cero
    ; 0 / b = 0 para todo b != 0
    ; ============================================================
    test al, al                 ; ¿a == 0?
    jz .result_zero             ; si a = 0, resultado = 0
    
    ; ============================================================
    ; DIVISIÓN USANDO LOGARITMOS
    ; log(a/b) = log(a) - log(b) mod 255
    ; ============================================================
    movzx ecx, al               ; ecx = a
    movzx edx, bl               ; edx = b
    
    mov esi, gf_log             ; esi = puntero a tabla de logaritmos
    movzx ecx, byte [esi + ecx] ; ecx = log(a)
    movzx edx, byte [esi + edx] ; edx = log(b)
    
    sub ecx, edx                ; ecx = log(a) - log(b)
    
    ; ============================================================
    ; REDUCCIÓN MÓDULO 255
    ; Si la resta < 0, sumar 255
    ; ============================================================
    test ecx, ecx               ; ¿resultado negativo?
    jge .no_add                 ; si no, continuar
    add ecx, 255                ; sí → sumar 255 para módulo positivo
.no_add:
    
    ; ============================================================
    ; ANTILOGARITMO: exp(log(a) - log(b))
    ; ============================================================
    mov esi, gf_exp             ; esi = puntero a tabla de exponentes
    movzx eax, byte [esi + ecx] ; eax = exp(log(a) - log(b))
    
    jmp .end                    ; ir al final

.result_zero:
    xor eax, eax                ; resultado = 0

.end:
    pop esi                     ; restaurar registros
    pop edx
    pop ecx
    pop ebp
    ret

; ============================================================
; FUNCIÓN: gf_pow
; Calcula a^n en GF(256)
; Fórmula: a^n = exp(n * log(a) mod 255)
; ============================================================
; Inputs:
;   AL = base (a)
;   BL = exponente (n)
; Output:
;   AL = resultado de a^n en GF(256)
; ============================================================
global gf_pow
gf_pow:
    push ebp                    ; guardar frame pointer
    mov ebp, esp                ; establecer nuevo frame
    push ecx                    ; preservar registros
    push edx
    push esi
    
    ; Caso especial: exponente 0
    test bl, bl                 ; ¿n == 0?
    jz .result_one              ; a^0 = 1
    
    ; Caso especial: base 0
    test al, al                 ; ¿a == 0?
    jz .result_zero             ; 0^n = 0 (para n > 0)
    
    ; Potencia: log(a^n) = n * log(a) mod 255
    movzx ecx, al               ; ecx = a
    movzx edx, bl               ; edx = n
    
    mov esi, gf_log             ; esi = tabla de logaritmos
    movzx ecx, byte [esi + ecx] ; ecx = log(a)
    
    imul ecx, edx               ; ecx = n * log(a)
    
    ; Reducir módulo 255
.reduce_loop:
    cmp ecx, 255                ; ¿ecx >= 255?
    jl .no_reduce_pow           ; si no, continuar
    sub ecx, 255                ; sí → reducir
    jmp .reduce_loop            ; repetir hasta que < 255
.no_reduce_pow:
    
    ; Antilogaritmo
    mov esi, gf_exp
    movzx eax, byte [esi + ecx]
    jmp .end

.result_one:
    mov eax, 1                  ; retornar 1
    jmp .end

.result_zero:
    xor eax, eax                ; retornar 0

.end:
    pop esi                     ; restaurar registros
    pop edx
    pop ecx
    pop ebp
    ret
