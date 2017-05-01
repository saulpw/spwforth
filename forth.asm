; a clean direct-threaded Forth implementation

bits 32

global main
extern atoi, printf, read

%define latest_tok 0  ; tail of dictionary linked list

%macro NEXT 0
        lodsd       ; fetch next xt from PC
        jmp eax     ; direct threading
%endmacro

%macro RPOP 1
        sub ebp, 4
        mov %1, [ebp]
%endmacro

%macro RPUSH 1
        mov [ebp], %1
        add ebp, 4
%endmacro

; dictentry STAR, "*"
%macro dictentry 2
       align 16, db 0
nt_%1  dd latest_tok
%define latest_tok nt_%1
       db %2
       align 16, db 0
%1:
%endmacro


main:
        sub esp, 0x40     ; esp = data stack, grows down
        lea ebp, [esp+4]  ; ebp = return stack, grows up
        mov esi, START    ; esi = Forth PC
        NEXT

ENTER:  RPUSH esi
        pop esi           ; get parameter field address from 'call ENTER'
        NEXT

EXIT:   RPOP esi
        NEXT

DOLITERAL:
        lodsd
        push ebx
        mov ebx, eax
        NEXT

EXECUTE:
        pop eax
        xchg eax, ebx
        jmp eax

BRANCH:
        lodsd
        add esi, eax
        NEXT

QBRANCH:
        lodsd
        cmp ebx, 0
        pop ebx
        jnz QB1       ; if TOS == 0, PC += eax
        add esi, eax
QB1:    NEXT

dictentry DUP, "DUP"
        push ebx
        NEXT

dictentry STAR, "*"
        pop eax
        imul ebx
        mov ebx, eax
        NEXT

dictentry BYE, "BYE"
        mov eax, 1         ; eax = syscall 1 (exit)
        int 0x80           ; ebx = exit code (conveniently also TOS)

dictentry TONUM, ">NUMBER"
        push ebx
        call atoi
        add esp, 4
        mov ebx, eax
        NEXT

%include "interpret.asm"

dictentry SQUARED, "SQUARED"
        call ENTER
        dd DUP, STAR, EXIT

INTERPRET: call ENTER
    dd DOLITERAL, 32, _WORD, FIND, QBRANCH, 12
    dd EXECUTE, BRANCH, 4, TONUM, EXIT

START   dd INTERPRET, BRANCH, -12

TIBUF   db ": SQUARED DUP * ; "
        db "10 SQUARED BYE", 0

section .data
TIB     dd TIBUF
PAD     times 128 db 0
LATEST  dd latest_tok
