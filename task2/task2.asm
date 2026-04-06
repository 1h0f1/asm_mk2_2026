.386

LIMIT_POSITIVE equ 32767
LIMIT_NEGATIVE equ 32768

ERR_OK equ 0
ERR_ZERO_DIV equ 1
ERR_RANGE equ 2
ERR_SYNTAX equ 3
ERR_BAD_OP equ 4
ERR_EMPTY equ 5

param1 equ 4
param2 equ 6
param3 equ 8
param4 equ 10

stk segment para stack
    db 65530 dup(?)
stk ends

dat segment para public
    input_buffer db 256 dup(?)
    buffer_max db 254
    buffer_len db ?
    is_multiply db 0
    
    output_dec db 16 dup(?)
    output_hex db 9 dup(?)
    
    first_str db 10 dup(?)
    first_len db ?
    second_str db 10 dup(?)
    second_len db ?
    
    prompt_expr db "Enter expression (dec: 5 - 3 or hex: 0xA + 0x1F): ", "$"
    prompt_res db "Answer: ", "$"
    hex_start db " (hex: $"
    hex_end db ")$"
    error_syntax db "ERROR: Invalid format$"
    error_zero db "ERROR: Cannot divide by zero$"
    error_range db "ERROR: Number out of range$"
    error_op db "ERROR: Unknown operator$"
    error_empty db "ERROR: Empty input$"
    
    operand1 dw ?
    operand2 dw ?
    op_sign db ?
    
    mul_result dd ?
    other_result dw ?
    
    work_buffer db 10 dup(?)
dat ends

cod segment para public use16
assume cs:cod, ds:dat, ss:stk

print_newline proc near
    push bp
    mov bp, sp
    push dx
    push ax
    
    mov dl, 13
    mov ah, 02h
    int 21h
    
    mov dl, 10
    mov ah, 02h
    int 21h
    
    pop ax
    pop dx
    mov sp, bp
    pop bp
    ret
print_newline endp

terminate proc near
    push bp
    mov bp, sp
    mov ah, 4ch
    mov al, 0
    int 21h
    mov sp, bp
    pop bp
    ret
terminate endp

show_zero_error proc near
    push bp
    mov bp, sp
    push dx
    lea dx, error_zero
    mov ah, 09h
    int 21h
    mov al, ERR_ZERO_DIV
    mov ah, 4ch
    int 21h
    pop dx
    mov sp, bp
    pop bp
    ret
show_zero_error endp

show_range_error proc near
    push bp
    mov bp, sp
    push dx
    lea dx, error_range
    mov ah, 09h
    int 21h
    mov al, ERR_RANGE
    mov ah, 4ch
    int 21h
    pop dx
    mov sp, bp
    pop bp
    ret
show_range_error endp

show_syntax_error proc near
    push bp
    mov bp, sp
    push dx
    lea dx, error_syntax
    mov ah, 09h
    int 21h
    mov al, ERR_SYNTAX
    mov ah, 4ch
    int 21h
    pop dx
    mov sp, bp
    pop bp
    ret
show_syntax_error endp

show_op_error proc near
    push bp
    mov bp, sp
    push dx
    lea dx, error_op
    mov ah, 09h
    int 21h
    mov al, ERR_BAD_OP
    mov ah, 4ch
    int 21h
    pop dx
    mov sp, bp
    pop bp
    ret
show_op_error endp

show_empty_error proc near
    push bp
    mov bp, sp
    push dx
    lea dx, error_empty
    mov ah, 09h
    int 21h
    mov al, ERR_EMPTY
    mov ah, 4ch
    int 21h
    pop dx
    mov sp, bp
    pop bp
    ret
show_empty_error endp

exit_clean proc near
    push bp
    mov bp, sp
    call terminate
    mov sp, bp
    pop bp
    ret
exit_clean endp

is_hex_number proc near
    push bp
    mov bp, sp
    push si
    push bx
    push cx
    
    mov si, word ptr [bp + param1]
    xor bx, bx
    
    mov al, byte ptr [si]
    cmp al, '-'
    je skip_sign_hex
    cmp al, '+'
    jne check_zero_hex
    
skip_sign_hex:
    inc si
    
check_zero_hex:
    mov al, byte ptr [si]
    cmp al, '0'
    jne not_hex_format
    
    mov al, byte ptr [si + 1]
    cmp al, 'x'
    je found_hex_prefix
    cmp al, 'X'
    je found_hex_prefix
    jmp not_hex_format
    
found_hex_prefix:
    add si, 2
    mov bx, si
    
    mov al, byte ptr [si]
    cmp al, 0
    je hex_format_error
    cmp al, ' '
    je hex_format_error
    
validate_hex_loop:
    mov al, byte ptr [si]
    cmp al, 0
    je hex_valid
    cmp al, ' '
    je hex_valid
    
    cmp al, '0'
    jb hex_format_error
    cmp al, '9'
    jbe hex_char_ok
    
    and al, 0DFh
    cmp al, 'A'
    jb hex_format_error
    cmp al, 'F'
    ja hex_format_error
    
hex_char_ok:
    inc si
    jmp validate_hex_loop
    
not_hex_format:
    xor ax, ax
    clc
    jmp hex_check_done
    
hex_valid:
    mov ax, 1
    clc
    jmp hex_check_done
    
hex_format_error:
    xor ax, ax
    stc
    
hex_check_done:
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
is_hex_number endp

hex_to_int proc near
    push bp
    mov bp, sp
    push si
    push dx
    push bx
    
    mov si, word ptr [bp + param1]
    add si, 2
    xor ax, ax
    
hex_convert_loop:
    mov cl, byte ptr [si]
    cmp cl, 0
    je hex_convert_done
    cmp cl, ' '
    je hex_convert_done
    
    cmp ah, 0
    jne check_hex_overflow
    jmp hex_shift_value
    
check_hex_overflow:
    test ah, 0F0h
    jnz hex_overflow_error
    
hex_shift_value:
    shl ax, 4
    
    cmp cl, '9'
    jbe hex_digit_num
    
    and cl, 0DFh
    sub cl, 'A'
    add cl, 10
    jmp hex_accumulate
    
hex_digit_num:
    sub cl, '0'
    
hex_accumulate:
    or al, cl
    inc si
    jmp hex_convert_loop
    
hex_overflow_error:
    mov ax, ERR_RANGE
    stc
    call show_range_error
    jmp hex_convert_exit
    
hex_convert_done:
    clc
    
hex_convert_exit:
    pop bx
    pop dx
    pop si
    mov sp, bp
    pop bp
    ret
hex_to_int endp

universal_atoi proc near
    push bp
    mov bp, sp
    push si
    push bx
    
    mov si, word ptr [bp + param1]
    mov bx, si
    
    mov al, byte ptr [bx]
    cmp al, '-'
    je skip_sign_universal
    cmp al, '+'
    jne check_universal_hex
    
skip_sign_universal:
    inc bx
    
check_universal_hex:
    mov al, byte ptr [bx]
    cmp al, '0'
    jne call_decimal_convert
    
    mov al, byte ptr [bx + 1]
    cmp al, 'x'
    je call_hex_convert
    cmp al, 'X'
    je call_hex_convert
    
call_decimal_convert:
    push si
    call decimal_to_int
    add sp, 2
    jmp universal_done
    
call_hex_convert:
    xor dx, dx
    mov al, byte ptr [si]
    cmp al, '-'
    jne hex_positive
    mov dx, 1
    
hex_positive:
    push bx
    call hex_to_int
    add sp, 2
    jc universal_done
    
    cmp dx, 0
    je universal_done
    
    cmp ax, 8000h
    je hex_min_value
    
    neg ax
    jo universal_overflow
    clc
    jmp universal_done
    
hex_min_value:
    mov ax, 8000h
    clc
    jmp universal_done
    
universal_overflow:
    mov ax, ERR_RANGE
    call show_range_error
    stc
    
universal_done:
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
universal_atoi endp

decimal_to_int proc near
    push bp
    mov bp, sp
    push si
    push bx
    push cx
    
    mov si, word ptr [bp + param1]
    xor ax, ax
    xor bx, bx
    
skip_leading_spaces:
    mov cl, byte ptr [si]
    cmp cl, ' '
    jne check_sign_decimal
    inc si
    jmp skip_leading_spaces
    
check_sign_decimal:
    cmp cl, '-'
    jne check_plus_decimal
    mov bx, 1
    inc si
    jmp decimal_main_loop
    
check_plus_decimal:
    cmp cl, '+'
    jne decimal_main_loop
    inc si
    
decimal_main_loop:
    mov cl, byte ptr [si]
    cmp cl, '0'
    jb decimal_finish
    cmp cl, '9'
    ja decimal_finish
    
    sub cl, '0'
    
    cmp ax, 3276
    jg decimal_overflow
    
    push dx
    mov dx, 10
    imul dx
    pop dx
    jo decimal_overflow
    
    xor ch, ch
    add ax, cx
    jo decimal_overflow
    
    inc si
    jmp decimal_main_loop
    
decimal_finish:
    cmp bx, 0
    je check_positive_result
    
    cmp ax, 8000h
    je decimal_min_int
    
    neg ax
    jo decimal_overflow
    clc
    jmp decimal_exit
    
check_positive_result:
    cmp ax, 0
    jge decimal_ok
    jmp decimal_overflow
    
decimal_ok:
    clc
    jmp decimal_exit
    
decimal_min_int:
    mov ax, 8000h
    clc
    jmp decimal_exit
    
decimal_overflow:
    mov ax, ERR_RANGE
    call show_range_error
    stc
    
decimal_exit:
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
decimal_to_int endp

int_to_decimal proc near
    push bp
    mov bp, sp
    push di
    push ax
    push bx
    push cx
    push dx

    mov di, word ptr [bp + param1]
    mov ax, word ptr [bp + param2]

    cmp ax, 0
    jns itd_positive

    mov byte ptr [di], '-'
    inc di
    neg ax

itd_positive:
    cmp ax, 0
    jne itd_nonzero

    mov byte ptr [di], '0'
    inc di
    mov byte ptr [di], 0
    jmp itd_done

itd_nonzero:
    xor cx, cx
    mov bx, 10

itd_divide_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne itd_divide_loop

itd_write_loop:
    pop dx
    add dl, '0'
    mov byte ptr [di], dl
    inc di
    loop itd_write_loop

    mov byte ptr [di], 0

itd_done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    mov sp, bp
    pop bp
    ret
int_to_decimal endp

int_to_hex proc near
    push bp
    mov bp, sp
    push di
    push ax
    push bx
    push cx
    
    mov di, word ptr [bp + param1]
    mov ax, word ptr [bp + param2]
    
    mov bx, ax
    mov al, bh
    call convert_byte_hex
    
    mov al, bl
    call convert_byte_hex
    
    mov byte ptr [di], 0
    
    pop cx
    pop bx
    pop ax
    pop di
    mov sp, bp
    pop bp
    ret
int_to_hex endp

convert_byte_hex proc near
    push cx
    mov cl, al
    shr al, 4
    call convert_nibble
    mov al, cl
    and al, 0Fh
    call convert_nibble
    pop cx
    ret
convert_byte_hex endp

convert_nibble proc near
    cmp al, 9
    jbe nibble_is_digit
    add al, 7
nibble_is_digit:
    add al, '0'
    mov byte ptr [di], al
    inc di
    ret
convert_nibble endp

validate_first_operand proc near
    push bp
    mov bp, sp
    push si
    push bx
    push cx
    
    lea si, first_str
    xor bx, bx

    push si
    call is_hex_number
    add sp, 2
    jnc check_hex_result1
    
check_hex_result1:
    cmp ax, 1
    je valid_first_hex

    mov al, byte ptr [si]
    cmp al, '-'
    je skip_first_sign
    cmp al, '+'
    je skip_first_sign
    jmp start_first_digits
    
skip_first_sign:
    inc bx
    
start_first_digits:
    mov al, byte ptr [si + bx]
    cmp al, 0
    je first_format_error
    cmp al, 13
    je first_format_error
    
check_first_digit_loop:
    mov al, byte ptr [si + bx]
    cmp al, 0
    je first_format_ok
    cmp al, 13
    je first_format_ok
    cmp al, ' '
    je first_format_ok

    cmp al, '0'
    jb first_format_error
    cmp al, '9'
    ja first_format_error
    
    inc bx
    jmp check_first_digit_loop
    
first_format_ok:
    cmp bx, 0
    je first_format_error
    cmp bx, 1
    jne first_valid_done

    mov al, byte ptr [si]
    cmp al, '-'
    je first_format_error
    cmp al, '+'
    je first_format_error
    
first_valid_done:
    mov ax, 1
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
    
valid_first_hex:
    mov ax, 1
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
    
first_format_error:
    call show_syntax_error
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
validate_first_operand endp

validate_second_operand proc near
    push bp
    mov bp, sp
    push si
    push bx
    push cx
    
    lea si, second_str
    xor bx, bx

    push si
    call is_hex_number
    add sp, 2
    jnc check_hex_result2
    
check_hex_result2:
    cmp ax, 1
    je valid_second_hex

    mov al, byte ptr [si]
    cmp al, '-'
    je skip_second_sign
    cmp al, '+'
    je skip_second_sign
    jmp start_second_digits
    
skip_second_sign:
    inc bx
    
start_second_digits:
    mov al, byte ptr [si + bx]
    cmp al, 0
    je second_format_error
    cmp al, 13
    je second_format_error
    
check_second_digit_loop:
    mov al, byte ptr [si + bx]
    cmp al, 0
    je second_format_ok
    cmp al, 13
    je second_format_ok
    cmp al, ' '
    je second_format_ok

    cmp al, '0'
    jb second_format_error
    cmp al, '9'
    ja second_format_error
    
    inc bx
    jmp check_second_digit_loop
    
second_format_ok:
    cmp bx, 0
    je second_format_error
    cmp bx, 1
    jne second_valid_done

    mov al, byte ptr [si]
    cmp al, '-'
    je second_format_error
    cmp al, '+'
    je second_format_error
    
second_valid_done:
    mov ax, 1
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
    
valid_second_hex:
    mov ax, 1
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
    
second_format_error:
    call show_syntax_error
    pop cx
    pop bx
    pop si
    mov sp, bp
    pop bp
    ret
validate_second_operand endp

dword_to_decimal proc near
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov di, word ptr [bp + param1]
    mov ax, word ptr [bp + param2]
    mov dx, word ptr [bp + param3]

    cmp dx, 0
    jne d2d_nonzero
    cmp ax, 0
    jne d2d_nonzero

    mov byte ptr [di], '0'
    inc di
    mov byte ptr [di], 0
    jmp d2d_done

d2d_nonzero:
    cmp dx, 0
    jge d2d_positive

    not ax
    not dx
    add ax, 1
    adc dx, 0

    mov byte ptr [di], '-'
    inc di

d2d_positive:
    xor cx, cx
    mov bx, 10

d2d_convert_loop:
    mov si, ax
    mov ax, dx
    xor dx, dx
    div bx

    xchg ax, si
    div bx

    push dx
    inc cx

    mov dx, si
    cmp ax, 0
    jne d2d_convert_loop
    cmp dx, 0
    jne d2d_convert_loop

d2d_write_loop:
    pop dx
    add dl, '0'
    mov byte ptr [di], dl
    inc di
    loop d2d_write_loop

    mov byte ptr [di], 0

d2d_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret
dword_to_decimal endp

dword_to_hex proc near
    push bp
    mov bp, sp
    push di
    push ax
    push dx
    push bx
    push cx

    mov di, word ptr [bp + param1]
    mov ax, word ptr [bp + param2]
    mov dx, word ptr [bp + param3]

    mov bx, ax
    mov cx, dx

    mov ax, cx
    call write_hex_word

    mov ax, bx
    call write_hex_word
    
    mov byte ptr [di], 0

    pop cx
    pop bx
    pop dx
    pop ax
    pop di
    mov sp, bp
    pop bp
    ret
dword_to_hex endp

write_hex_word proc near
    push cx
    mov cx, 4
whw_loop:
    rol ax, 4
    mov dl, al
    and dl, 0Fh
    cmp dl, 9
    jbe whw_digit
    add dl, 7
whw_digit:
    add dl, '0'
    mov byte ptr [di], dl
    inc di
    loop whw_loop
    pop cx
    ret
write_hex_word endp

read_input proc near
    push bp
    mov bp, sp
    push si
    push di
    push bx
    push cx

    lea dx, prompt_expr
    mov ah, 09h
    int 21h

    lea dx, input_buffer
    mov byte ptr [input_buffer], 254
    mov ah, 0Ah
    int 21h
    
    call print_newline

    mov cl, byte ptr [input_buffer + 1]
    cmp cl, 0
    je input_empty_error

    xor si, si
    add si, 2

    lea di, first_str

read_first_num:
    mov al, byte ptr [input_buffer + si]
    cmp al, ' '
    je first_num_done
    cmp al, 13
    je input_format_error

    mov byte ptr [di], al
    inc di
    inc si
    jmp read_first_num

first_num_done:
    mov byte ptr [di], 0

skip_space_before_op:
    inc si
    mov al, byte ptr [input_buffer + si]
    cmp al, ' '
    je skip_space_before_op

    mov byte ptr [op_sign], al
    inc si

skip_space_after_op:
    mov al, byte ptr [input_buffer + si]
    cmp al, ' '
    jne read_second_start
    inc si
    jmp skip_space_after_op

read_second_start:
    lea di, second_str

read_second_num:
    mov al, byte ptr [input_buffer + si]
    cmp al, ' '
    je second_num_done
    cmp al, 13
    je second_num_done

    mov byte ptr [di], al
    inc di
    inc si
    jmp read_second_num

second_num_done:
    mov byte ptr [di], 0

    mov ax, 1
    jmp input_exit

input_empty_error:
    call show_empty_error
    jmp input_exit

input_format_error:
    call show_syntax_error

input_exit:
    pop cx
    pop bx
    pop di
    pop si
    mov sp, bp
    pop bp
    ret
read_input endp

perform_calculation proc near
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    
    clc
    
    call validate_first_operand
    
    lea ax, first_str
    push ax
    call universal_atoi
    add sp, 2
    jc calc_error_exit
    mov word ptr [operand1], ax
    
    call validate_second_operand
    
    lea ax, second_str
    push ax
    call universal_atoi
    add sp, 2
    jc calc_error_exit
    mov word ptr [operand2], ax

    mov ax, word ptr [operand1]
    mov bx, word ptr [operand2]

    mov cl, byte ptr [op_sign]
    
    cmp cl, '+'
    je do_addition
    
    cmp cl, '-'
    je do_subtraction
    
    cmp cl, '*'
    je do_multiplication
    
    cmp cl, '/'
    je do_division
    
    cmp cl, '%'
    je do_modulo

    jmp op_error_exit

do_addition:
    add ax, bx
    jo overflow_exit
    mov word ptr [other_result], ax
    cmp word ptr [other_result], 32767
    jg overflow_exit
    jmp calc_done

do_subtraction:
    sub ax, bx
    jo overflow_exit
    mov word ptr [other_result], ax
    cmp word ptr [other_result], 32767
    jg overflow_exit
    jmp calc_done

do_multiplication:
    mov byte ptr [is_multiply], 1
    imul bx
    mov word ptr [mul_result], ax
    mov word ptr [mul_result + 2], dx
    jmp calc_done

do_division:
    cmp bx, 0
    je zero_div_exit
    cwd
    idiv bx
    mov word ptr [other_result], ax
    cmp word ptr [other_result], 32767
    jg overflow_exit
    jmp calc_done

do_modulo:
    cmp bx, 0
    je zero_div_exit
    cwd
    idiv bx
    mov word ptr [other_result], dx
    cmp word ptr [other_result], 32767
    jg overflow_exit
    jmp calc_done

zero_div_exit:
    call show_zero_error
    jmp calc_done

overflow_exit:
    call show_range_error
    jmp calc_done

calc_error_exit:
    call show_syntax_error
    jmp calc_done

op_error_exit:
    call show_op_error
    
calc_done:
    pop dx
    pop cx
    pop bx
    mov sp, bp
    pop bp
    ret
perform_calculation endp

display_result proc near
    push bp
    mov bp, sp
    push ax
    push dx
    push cx
    push di

    cmp byte ptr [is_multiply], 0
    je display_word_result

display_dword_result:
    mov ax, word ptr [mul_result]
    mov dx, word ptr [mul_result + 2]

    push dx
    push ax
    lea ax, output_dec
    push ax
    call dword_to_decimal
    add sp, 6

    mov ax, word ptr [mul_result]
    mov dx, word ptr [mul_result + 2]
    
    push dx
    push ax
    lea ax, output_hex
    push ax
    call dword_to_hex
    add sp, 6

    jmp print_output

display_word_result:
    mov ax, word ptr [other_result]

    lea di, output_hex
    mov cx, 9
clear_hex_buf:
    mov byte ptr [di], 0
    inc di
    loop clear_hex_buf

    mov ax, word ptr [other_result]
    push ax
    lea ax, output_dec
    push ax
    call int_to_decimal
    add sp, 4
 
    mov ax, word ptr [other_result]
    push ax
    lea ax, output_hex
    push ax
    call int_to_hex
    add sp, 4

print_output:
    lea dx, prompt_res
    mov ah, 09h
    int 21h

    lea ax, output_dec
    push ax
    call print_string
    add sp, 2

    lea dx, hex_start
    mov ah, 09h
    int 21h

    lea ax, output_hex
    push ax
    call print_string
    add sp, 2

    lea dx, hex_end
    mov ah, 09h
    int 21h

    call print_newline

    pop di
    pop cx
    pop dx
    pop ax
    mov sp, bp
    pop bp
    ret
display_result endp

print_string proc near
    push bp
    mov bp, sp
    push si
    push ax
    push dx
    
    mov si, word ptr [bp + param1]
    
ps_loop:
    lodsb
    cmp al, 0
    je ps_done
    mov dl, al
    mov ah, 02h
    int 21h
    jmp ps_loop
    
ps_done:
    pop dx
    pop ax
    pop si
    mov sp, bp
    pop bp
    ret
print_string endp

print_char proc near
    push bp
    mov bp, sp
    push ax
    push dx
    
    mov dl, byte ptr [bp + param1]
    mov ah, 02h
    int 21h
    
    pop dx
    pop ax
    mov sp, bp
    pop bp
    ret
print_char endp

main proc near
    mov ax, dat
    mov ds, ax
    mov ax, stk
    mov ss, ax
    
    call read_input

    call perform_calculation
    
    call display_result

    call exit_clean
main endp

cod ends

end main