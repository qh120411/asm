; ================= EMU8086 / MASM =================
; Menu: 1) Chao hoi  2) Tinh tong 2 so  0) Thoat
; Nhap so dung int 21h/AH=0Ah (buffered), ho tro so am
; In so 16-bit signed (co dau - neu am)

.model small
.stack 100h

.data
    ; --- Menu ---
    menu_str    db 13, 10, "---------- MENU ----------", 13, 10
                db "1. Nhap va in loi chao", 13, 10
                db "2. Tinh tong 2 so", 13, 10
                db "0. Thoat chuong trinh", 13, 10
                db "Chon chuc nang (0, 1, 2): $"

    ; --- Chuc nang 1 ---
    prompt1     db 13, 10, "Ho ten cua ban la: $"
    result1_pre db 13, 10, "Chao ban $"
    result1_suf db 13, 10, "$"

    input_name_buffer db 50       ; max length
                      db ?        ; actual length
                      db 50 dup (?) 

    ; --- Chuc nang 2 (Tinh tong) ---
    msg1 db 13, 10, 'Nhap so thu nhat: $'
    msg2 db 13, 10, 'Nhap so thu hai: $'
    msg3 db 13, 10, 'Tong hai so = $'   

    buf  db 6, ?, 6 dup(?)   ; buffered input for numbers
    sign db 0                ; 0=duong, 1=am

    num1        dw ?
    num2        dw ?
    result_num  dw ?

    newline     db 13, 10, '$'

.code
main proc
    ; Khoi tao DS
    mov ax, @data
    mov ds, ax

; --- Vong lap Menu chinh ---
menu_loop:
    lea dx, menu_str
    mov ah, 9
    int 21h

    ; Doc lua chon (1 ky tu)
    mov ah, 1
    int 21h
    mov bl, al

    ; Doc ky tu tiep (thuong la Enter) de don buffer
    mov ah, 1
    int 21h

    ; So sanh lua chon
    cmp bl, '1'
    je option_1
    cmp bl, '2'
    je option_2
    cmp bl, '0'
    je exit_prog
    jmp menu_loop

; --- Chuc nang 1: Chao hoi ---
option_1:
    lea dx, prompt1
    mov ah, 9
    int 21h

    ; Doc ten (AH=0Ah)
    lea dx, input_name_buffer
    mov ah, 0Ah
    int 21h

    ; Doi sang CHU HOA
    lea si, [input_name_buffer + 1] ; SI -> byte do dai
    mov cl, [si]                    ; CL = do dai
    mov ch, 0
    lea si, [input_name_buffer + 2] ; SI -> ky tu dau
convert_loop:
    mov al, [si]
    cmp al, 'a'
    jb  next_char1
    cmp al, 'z'
    ja  next_char1
    sub al, 32
    mov [si], al
next_char1:
    inc si
    loop convert_loop

    ; Chen '$' cuoi chuoi de in AH=9
    lea si, [input_name_buffer + 1]
    mov cl, [si]
    mov ch, 0
    lea di, [input_name_buffer + 2]
    add di, cx
    mov byte ptr [di], '$'

    ; In "Chao ban " + TEN + xuong dong
    lea dx, result1_pre
    mov ah, 9
    int 21h

    lea dx, input_name_buffer + 2
    mov ah, 9
    int 21h

    lea dx, result1_suf
    mov ah, 9
    int 21h

    jmp menu_loop

; --- Chuc nang 2: Tinh tong ---
option_2:
    ; Nhap so 1
    lea dx, msg1
    mov ah, 9
    int 21h
    call nhap_so
    mov [num1], ax

    ; Nhap so 2
    lea dx, msg2
    mov ah, 9
    int 21h
    call nhap_so
    mov [num2], ax

    ; TINH TONG: AX = num1 + num2
    mov ax, [num1]
    add ax, [num2]
    mov [result_num], ax

    ; In ket qua
    lea dx, msg3
    mov ah, 9
    int 21h
    mov ax, [result_num]
    call in_so

    ; Xuong dong
    lea dx, newline
    mov ah, 9
    int 21h

    jmp menu_loop

; --- Thoat ---
exit_prog:
    mov ah, 4Ch
    int 21h
endp tranquanghuy_qh120411 ;ket thuc chuong trinh

; ==============================================
; NHAP_SO: ASCII -> signed 16-bit (AX)
; Ho tro so am. Dung buffered input AH=0Ah vao 'buf'.
; ==============================================
nhap_so proc
    mov byte ptr [buf], 5      ; max 5 ky tu (VD: -1234)

    lea dx, buf
    mov ah, 0Ah
    int 21h

    mov cl, [buf+1]            ; do dai thuc te
    cmp cl, 0
    je  ns_zero

    lea si, buf+2
    mov [sign], 0

    ; Dau am ?
    mov al, [si]
    cmp al, '-'
    jne ns_pos
    mov [sign], 1
    inc si
    dec cl

ns_pos:
    xor ax, ax                 ; AX = 0
    mov bx, 10                 ; BX = 10 (he thap phan)

ns_next:
    cmp cl, 0
    je  ns_done
    ; AX = AX * 10
    mul bx                     ; DX:AX = AX * BX
    ; them chu so moi
    xor dx, dx
    mov dl, [si]
    sub dl, '0'
    add ax, dx

    inc si
    dec cl
    jmp ns_next

ns_done:
    cmp byte ptr [sign], 0
    je  ns_exit
    neg ax
ns_exit:
    ret

ns_zero:
    xor ax, ax
    ret
nhap_so endp

; ==============================================
; IN_SO: In so 16-bit signed trong AX
; In dau '-' neu am, va in '0' neu so = 0.
; ==============================================
in_so proc
    push ax
    push bx
    push cx
    push dx
    push di

    mov bx, ax                 ; BX = so can in

    ; 0 ?
    cmp bx, 0
    jne is_not_zero
    mov ah, 2
    mov dl, '0'
    int 21h
    jmp is_restore

is_not_zero:
    ; Am ?
    cmp bx, 0
    jge is_positive
    mov ah, 2
    mov dl, '-'
    int 21h
    neg bx

is_positive:
    mov cx, 0                  ; dem chu so
    mov di, 10                 ; so chia 10

is_repeat:
    xor dx, dx                 ; DX:AX / 10
    mov ax, bx
    div di                     ; AX = thuong, DX = du
    push dx                    ; luu du (chu so)
    inc cx
    mov bx, ax                 ; BX = thuong
    cmp bx, 0
    jne is_repeat

; In nguoc tu stack
print_loop:
    pop dx            ;Lay chu so tu stack
    add dl, '0'       ;Chuyen so -> ASCII
    mov ah, 2         ;In ky tu
    int 21h
    loop print_loop     ;Lap lai CX lan

is_restore:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret         ;Tro ve
in_so endp
                
; Ket thuc chuong trinh
endp tranquanghuy_qh120411
