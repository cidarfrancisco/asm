; qr_encode_data.asm
; Version que USA qr_pbm.asm externo

%include "io.mac"

extern ecc_encode
extern ecc_get_row_parity
extern ecc_get_col_parity

; Funciones de qr_pbm.asm
extern qr_generate_matrix_only
extern matriz
extern qr_write_pbm

.DATA
    msg_too_long    db "Error: texto demasiado largo", 0

    global encoded_bits
    encoded_bits     times 352 db 0

    global encode_matrix_ptr
    encode_matrix_ptr    dd 0

.UDATA
    enc_bit_position     resd 1
    enc_char_count       resd 1
    global encoded_bit_len
    encoded_bit_len      resd 1
    data_bytes           resb 32

.CODE

; [Mantén write_bits igual que antes]
write_bits:
    push ebx
    push edx
    push esi

    mov ebx, ecx
    mov esi, encoded_bits
    mov edx, [enc_bit_position]
    add esi, edx

.wb_loop:
    cmp ebx, 0
    je .wb_done

    mov edx, eax
    mov ecx, ebx
    dec ecx
    shr edx, cl
    and dl, 1

    mov [esi], dl
    inc esi

    mov ecx, [enc_bit_position]
    inc ecx
    mov [enc_bit_position], ecx

    dec ebx
    jmp .wb_loop

.wb_done:
    pop esi
    pop edx
    pop ebx
    ret

; [Mantén encode_text_to_bits igual - hasta .encode_end]
global encode_text_to_bits

encode_text_to_bits:
    push ebp
    mov  ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, [ebp+8]
    xor ecx, ecx

.count_loop:
    mov al, [esi]
    cmp al, 0
    je  .len_done
    inc ecx
    inc esi
    jmp .count_loop

.len_done:
    mov [enc_char_count], ecx
   
    cmp ecx, 32
    jle .len_ok
    mov eax, -1
    jmp .encode_end

.len_ok:
    xor eax, eax
    mov [enc_bit_position], eax

    mov edi, encoded_bits
    mov ecx, 352
    xor al, al
    rep stosb
    
    mov eax, 4
    mov ecx, 4
    call write_bits

    mov eax, [enc_char_count]
    mov ecx, 8
    call write_bits

    mov esi, [ebp+8]
    mov ebx, [enc_char_count]

.data_loop:
    cmp ebx, 0
    je  .after_data

    movzx eax, byte [esi]
    mov ecx, 8
    call write_bits

    inc esi
    dec ebx
    jmp .data_loop

.after_data:
    xor eax, eax
    mov ecx, 4
    call write_bits

    mov eax, [enc_bit_position]
    xor edx, edx
    mov ecx, 8
    div ecx

    cmp edx, 0
    je .no_pad_bits

    mov ecx, 8
    sub ecx, edx
    xor eax, eax
    call write_bits

.no_pad_bits:
    mov esi, encoded_bits
    add esi, 12
    mov edi, data_bytes
    xor ebx, ebx

.bits_to_bytes_loop:
    cmp ebx, 32
    jge .ecc_generate

    xor eax, eax
    mov ecx, 8

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
    mov esi, data_bytes
    call ecc_encode

    call ecc_get_row_parity
    mov esi, eax
    mov ecx, 8

.add_row_parity:
    movzx eax, byte [esi]
    push ecx
    mov ecx, 8
    call write_bits
    pop ecx
    inc esi
    loop .add_row_parity

    call ecc_get_col_parity
    mov esi, eax
    mov ecx, 4

.add_col_parity:
    movzx eax, byte [esi]
    push ecx
    mov ecx, 8
    call write_bits
    pop ecx
    inc esi
    loop .add_col_parity

    mov eax, [enc_bit_position]
    mov [encoded_bit_len], eax
    xor eax, eax

.encode_end:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; ============================================
; CORREGIDO: is_reserved_encode
; ============================================
is_reserved_encode:
    push ebp
    mov ebp, esp
    push ecx
    push edx

    ; Finders + separadores (8x8)
    cmp eax, 8
    jge .check_tr
    cmp ebx, 8
    jge .check_tr
    mov eax, 1
    jmp .end_res

.check_tr:
    cmp eax, 17
    jl .check_bl
    cmp ebx, 8
    jge .check_bl
    mov eax, 1
    jmp .end_res

.check_bl:
    cmp eax, 8
    jge .check_timing
    cmp ebx, 17
    jl .check_timing
    mov eax, 1
    jmp .end_res

.check_timing:
    cmp eax, 6
    je .reserved
    cmp ebx, 6
    je .reserved

    ; CRÍTICO: Formato fila/columna 8
    cmp eax, 8
    je .reserved
    cmp ebx, 8
    je .reserved

    ; Alignment (distancia desde 18,18)
    mov ecx, eax
    sub ecx, 18
    push eax
    mov eax, ecx
    imul eax, eax
    cmp eax, 4
    pop eax
    jg .not_reserved

    mov edx, ebx
    sub edx, 18
    push eax
    mov eax, edx
    imul eax, eax
    cmp eax, 4
    pop eax
    jg .not_reserved

.reserved:
    mov eax, 1
    jmp .end_res

.not_reserved:
    xor eax, eax

.end_res:
    pop edx
    pop ecx
    pop ebp
    ret

; ============================================
; CORREGIDO: place_bits_zigzag
; ============================================
global place_bits_zigzag

place_bits_zigzag:
    push ebp
    mov  ebp, esp
    sub esp, 16
    push ebx
    push esi
    push edi

    mov esi, [encode_matrix_ptr]

    mov dword [ebp-4], 0        ; bit_index
    mov dword [ebp-8], 24       ; columna
    mov dword [ebp-12], 24      ; fila
    mov dword [ebp-16], 1       ; direction (1=up)

.col_loop:
    mov eax, [ebp-8]
    cmp eax, 0
    jl .done

    ; Saltar columna 6 (timing)
    cmp eax, 6
    jne .process_col
    dec dword [ebp-8]
    jmp .col_loop

.process_col:
    ; Resetear fila según dirección
    mov eax, [ebp-16]
    cmp eax, 1
    je .start_up

    mov dword [ebp-12], 0       ; Empezar arriba
    jmp .row_loop

.start_up:
    mov dword [ebp-12], 24      ; Empezar abajo

.row_loop:
    ; Verificar límites
    mov edx, [ebp-12]
    cmp dword [ebp-16], 1
    je .check_up_bound
    cmp edx, 25
    jge .next_col
    jmp .place_bits

.check_up_bound:
    cmp edx, -1
    jle .next_col

.place_bits:
    ; Módulo derecho (columna actual)
    mov eax, [ebp-8]
    mov ebx, [ebp-12]
    
    call is_reserved_encode
    cmp eax, 1
    je .skip_right

    mov edx, [ebp-4]
    cmp edx, [encoded_bit_len]
    jge .skip_right

    movzx eax, byte [encoded_bits + edx]
    and al, 1

    mov ebx, [ebp-12]
    imul ebx, 25
    add ebx, [ebp-8]

    mov [esi + ebx], al
    inc dword [ebp-4]

.skip_right:
    ; Módulo izquierdo (columna - 1)
    mov eax, [ebp-8]
    dec eax
    mov ebx, [ebp-12]
    
    push eax
    call is_reserved_encode
    mov ecx, eax
    pop eax
    
    cmp ecx, 1
    je .skip_left

    mov edx, [ebp-4]
    cmp edx, [encoded_bit_len]
    jge .skip_left

    movzx edx, byte [encoded_bits + edx]
    and dl, 1

    mov ebx, [ebp-12]
    imul ebx, 25
    add ebx, eax

    mov [esi + ebx], dl
    inc dword [ebp-4]

.skip_left:
    ; Mover a siguiente fila
    cmp dword [ebp-16], 1
    je .move_up
    inc dword [ebp-12]
    jmp .row_loop

.move_up:
    dec dword [ebp-12]
    jmp .row_loop

.next_col:
    ; Cambiar dirección y columna
    xor dword [ebp-16], 1
    sub dword [ebp-8], 2
    jmp .col_loop

.done:
    pop edi
    pop esi
    pop ebx
    add esp, 16
    pop ebp
    ret