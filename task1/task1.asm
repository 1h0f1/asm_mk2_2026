.386

stack_segment segment para stack use16
    db 65500 dup(?)
stack_segment ends

data_segment segment para public use16

crc16_table dw 0000h,1021h,2042h,3063h,4084h,50A5h,60C6h,70E7h
            dw 8108h,9129h,0A14Ah,0B16Bh,0C18Ch,0D1ADh,0E1CEh,0F1EFh
            dw 1231h,0210h,3273h,2252h,52B5h,4294h,72F7h,62D6h
            dw 9339h,8318h,0B37Bh,0A35Ah,0D3BDh,0C39Ch,0F3FFh,0E3DEh
            dw 2462h,3443h,0420h,1401h,64E6h,74C7h,44A4h,5485h
            dw 0A56Ah,0B54Bh,8528h,9509h,0E5EEh,0F5CFh,0C5ACh,0D58Dh
            dw 3653h,2672h,1611h,0630h,76D7h,66F6h,5695h,46B4h
            dw 0B75Bh,0A77Ah,9719h,8738h,0F7DFh,0E7FEh,0D79Dh,0C7BCh
            dw 48C4h,58E5h,6886h,78A7h,0840h,1861h,2802h,3823h
            dw 0C9CCh,0D9EDh,0E98Eh,0F9AFh,8948h,9969h,0A90Ah,0B92Bh
            dw 5AF5h,4AD4h,7AB7h,6A96h,1A71h,0A50h,3A33h,2A12h
            dw 0DBFDh,0CBDCh,0FBBFh,0EB9Eh,9B79h,8B58h,0BB3Bh,0AB1Ah
            dw 6CA6h,7C87h,4CE4h,5CC5h,2C22h,3C03h,0C60h,1C41h
            dw 0EDAEh,0FD8Fh,0CDECh,0DDCDh,0AD2Ah,0BD0Bh,8D68h,9D49h
            dw 7E97h,6EB6h,5ED5h,4EF4h,3E13h,2E32h,1E51h,0E70h
            dw 0FF9Fh,0EFBEh,0DFDDh,0CFFCh,0BF1Bh,0AF3Ah,9F59h,8F78h
            dw 9188h,81A9h,0B1CAh,0A1EBh,0D10Ch,0C12Dh,0F14Eh,0E16Fh
            dw 1080h,00A1h,30C2h,20E3h,5004h,4025h,7046h,6067h
            dw 83B9h,9398h,0A3FBh,0B3DAh,0C33Dh,0D31Ch,0E37Fh,0F35Eh
            dw 02B1h,1290h,22F3h,32D2h,4235h,5214h,6277h,7256h
            dw 0B5EAh,0A5CBh,95A8h,8589h,0F56Eh,0E54Fh,0D52Ch,0C50Dh
            dw 34E2h,24C3h,14A0h,0481h,7466h,6447h,5424h,4405h
            dw 0A7DBh,0B7FAh,8799h,97B8h,0E75Fh,0F77Eh,0C71Dh,0D73Ch
            dw 26D3h,36F2h,0691h,16B0h,6657h,7676h,4615h,5634h
            dw 0D94Ch,0C96Dh,0F90Eh,0E92Fh,99C8h,89E9h,0B98Ah,0A9ABh
            dw 5844h,4865h,7806h,6827h,18C0h,08E1h,3882h,28A3h
            dw 0CB7Dh,0DB5Ch,0EB3Fh,0FB1Eh,8BF9h,9BD8h,0ABBBh,0BB9Ah
            dw 4A75h,5A54h,6A37h,7A16h,0AF1h,1AD0h,2AB3h,3A92h
            dw 0FD2Eh,0ED0Fh,0DD6Ch,0CD4Dh,0BDAAh,0AD8Bh,9DE8h,8DC9h
            dw 7C26h,6C07h,5C64h,4C45h,3CA2h,2C83h,1CE0h,0CC1h
            dw 0EF1Fh,0FF3Eh,0CF5Dh,0DF7Ch,0AF9Bh,0BFBAh,8FD9h,9FF8h
            dw 6E17h,7E36h,4E55h,5E74h,2E93h,3EB2h,0ED1h,1EF0h

inputMaxLength db 254
inputLength    db ?
inputData      db 256 dup(?)

hex_buffer     db 5 dup(?)

newline        db 13,10,'$'

data_segment ends

code_segment segment para use16
assume cs:code_segment, ds:data_segment, ss:stack_segment

PrintString PROC
    push ax
    mov  ah, 09h
    int  21h
    pop  ax
    ret
PrintString ENDP

ReadInput PROC
    push ax
    push dx
    
    mov  ah, 0Ah
    int  21h
    
    mov  bx, dx
    inc  bx
    xor  cx, cx
    mov  cl, byte ptr [bx]
    
    pop  dx
    pop  ax
    ret
ReadInput ENDP

CalcCRC16 PROC
    push si
    push di
    push cx
    push ax
    push bx

    mov  dx, 0FFFFh
    
    cmp  cx, 0
    je   crc_done

crc_loop:
    mov  al, byte ptr [si]
    inc  si

    mov  bx, dx
    shr  bx, 8
    xor  bl, al
    xor  bh, bh

    shl  dx, 8

    shl  bx, 1
    
    mov  di, offset crc16_table
    add  di, bx
    mov  ax, word ptr [di]

    xor  dx, ax

    loop crc_loop

crc_done:
    pop  bx
    pop  ax
    pop  cx
    pop  di
    pop  si
    ret
CalcCRC16 ENDP

WordToHexStr PROC
    push ax
    push bx
    push cx
    push dx

    mov  bx, dx
    mov  cx, 4
    mov  di, offset hex_buffer

convert_loop:
    rol  bx, 4
    
    mov  al, bl
    and  al, 0Fh
    
    cmp  al, 9
    jbe  is_digit
    add  al, 7

is_digit:
    add  al, '0'
    mov  byte ptr [di], al
    inc  di
    
    loop convert_loop

    mov  byte ptr [di], '$'

    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
WordToHexStr ENDP

start:
    mov ax, data_segment
    mov ds, ax
    mov es, ax
    mov ax, stack_segment
    mov ss, ax

    lea dx, inputMaxLength
    call ReadInput
    
    lea si, inputData
    
    lea dx, newline
    call PrintString

    call CalcCRC16

    call WordToHexStr

    lea dx, hex_buffer
    call PrintString

    mov ax, 4C00h
    int 21h

code_segment ends
end start