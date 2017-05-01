; a clean direct-threaded Forth implementation

bits 32

global main
extern strtol, printf, read

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

; use like: dictentry STAR, "*"
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
        mov [RP0], ebp
        mov [SP0], esp
        mov esi, pQUIT    ; esi = Forth PC
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
        push 0     ; base == 0 for 0x support (but beware octal with leading 0 otherwise)
        push ebp   ; top of return stack is an okay place to put a local return value
        push ebx
        call strtol
        add esp, 12
        mov edx, [ebp]     ; edx := *endptr
        cmp byte [edx], 0  ; "if **endptr is '\0' on return, the entire string is valid"
        jnz wordnotfound
        mov ebx, eax       ; ebx := return value
        NEXT

nffmt   db "word not found: %s", 13, 10, 0
wordnotfound:
        push ebx
        push nffmt
        call printf

        mov esp, [SP0]
        mov esi, pQUIT
        jmp NEXT

intfmt  db "%d ", 13, 10
dictentry PRINTNUM, "."
        push ebx
        push intfmt
        call printf
        add esp, 8
        pop ebx
        NEXT

%include "interpret.asm"

dictentry SQUARED, "SQUARED"
        call ENTER
        dd DUP, STAR, EXIT

INTERPRET: call ENTER
        dd DOLITERAL, 32, _WORD, FIND, QBRANCH, 12
        dd EXECUTE, BRANCH, 4, TONUM, EXIT

dictentry RP_CLEAR, "RP_CLEAR"
        mov ebp, [RP0]
        NEXT

dictentry SP_CLEAR, "SP_CLEAR"
        mov esp, [SP0]
        NEXT

dictentry TIB_CLEAR, "TIB_CLEAR"
        mov dword [TIB], 0
        NEXT

dictentry QUIT, "QUIT"
        call ENTER
        dd RP_CLEAR
        dd TIB_CLEAR
        dd INTERPRET, BRANCH, -12

dictentry ABORT, "ABORT"
        call ENTER
        dd SP_CLEAR
pQUIT   dd QUIT

section .data
TIBUF   times 128 db 0
TIB     dd 0
PAD     times 128 db 0
LATEST  dd latest_tok
SP0     dd 0
RP0     dd 0
