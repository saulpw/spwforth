; a clean direct-threaded Forth implementation

; register allocation
; ebx = value of TOS
; esp = address of data stack, grows down
; ebp = address of return stack, grows up
; esi = address of Forth PC
; edi = HERE (end of dictionary, start of free space)
; eax, ecx, edx are all remaining for use

bits 32

global main
extern strtol, read, snprintf

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
        mov esi, pABORT   ; esi = Forth PC
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
        jnz QB1         ; if TOS == 0, PC += eax
        add esi, eax
QB1:    NEXT

dictentry DUP, "DUP"    ; ( a -- a a )
        push ebx
        NEXT

dictentry SWAP, "SWAP"  ; ( a b -- b a )
        xchg ebx, [esp]
        NEXT

dictentry DROP, "DROP"  ; ( a -- )
        pop ebx
        NEXT

dictentry OVER, "OVER"  ; ( a b -- a b a )
        push ebx
        mov ebx, [esp+4]
        NEXT

dictentry STAR, "*"  ; ( a b -- a*b )
        pop eax
        imul ebx
        mov ebx, eax
        NEXT

dictentry PLUS, "+"  ; ( a b -- a+b )
        pop eax
        add ebx, eax
        NEXT

dictentry MINUS, "-"  ; ( a b -- a-b )
        pop eax
        sub eax, ebx
        mov ebx, eax
        NEXT

dictentry SLASH, "/"  ; ( a b -- a/b )
        xor edx, edx
        pop eax
        idiv ebx
        mov ebx, eax
        NEXT

dictentry MOD, "MOD"  ; ( a b -- a%b )
        xor edx, edx
        pop eax
        idiv ebx
        mov ebx, edx
        NEXT

dictentry ROT, "ROT"   ; ( a b c -- b c a )
        pop ecx
        pop edx
        push ecx
        push ebx
        mov ebx, edx
        NEXT

dictentry NIP, "NIP"   ; ( a b -- b )
        add esp, 4
        NEXT

dictentry TUCK, "TUCK"   ; ( a b -- b a b )
        pop eax
        push ebx
        push eax
        NEXT

dictentry TWODUP, "2DUP"  ; ( a b -- a b a b )
;        call ENTER
;        dd OVER, OVER, EXIT
        push ebx
        push dword [esp+8]
        NEXT

dictentry TWOSWAP, "2SWAP"  ; ( a b c d -- c d a b )
;        call ENTER
;        dd DOLITERAL, 3, ROLL, DOLITERAL, 3, ROLL, EXIT
        xchg ebx, [esp+8]
        mov eax, [esp+12]
        xchg eax, [esp+4]
        mov [esp+12], eax
        NEXT

dictentry TWOOVER, "2OVER"  ; ( a b c d -- a b c d a b )
;        call ENTER
;        dd DOLITERAL, 3, PICK, DOLITERAL, 3, PICK, EXIT
        push ebx
        push dword [esp+16]
        mov ebx, [esp+16]
        NEXT

dictentry PICK, "PICK"   ; ( ... n -- ... [n] )
        mov ebx, [esp+ebx*4]
        NEXT

dictentry ROLL, "ROLL"   ; ( [n] ... n -- ... [n] )
        mov [ebp+4], esi
        mov [ebp+8], edi

        mov ecx, ebx
        lea esi, [esp+ebx*4-4]
        lea edi, [esp+ebx*4]
        mov ebx, [edi]   ; TOS := nth element
        std
        rep movsd
        cld

        mov esi, [ebp+4]
        mov edi, [ebp+8]
        add esp, 4
        NEXT

dictentry BYE, "BYE"
        mov eax, 1         ; eax = syscall 1 (exit)
        int 0x80           ; ebx = exit code (conveniently also TOS)

dictentry TONUM, ">NUMBER"
        push 0     ; base == 0 for 0x support (but beware octal with leading 0 otherwise)
        push ebp   ; above return stack is an okay place to put a local return value
        push ebx
        call strtol
        pop ebx
        add esp, 8
        mov edx, [ebp]     ; edx := *endptr
        cmp byte [edx], 0  ; "if **endptr is '\0' on return, the entire string is valid"
        jnz wordnotfound
        mov ebx, eax       ; ebx := return value
        NEXT

nffmt   db "word not found: %s", 13, 10, 0
wordnotfound:
        push ebx
        push 1
        mov ebx, nffmt
        mov eax, SPRINTF
        call ASMEXEC

        mov esi, pQUIT  ; QUIT after 'calling' TYPE
        jmp TYPE

dictentry TYPE, "TYPE"
        mov edx, ebx   ; count
        pop ecx        ; ptr to buf
        mov ebx, 1     ; stdout
        mov eax, 0x04  ; sys_write
        int 0x80

        pop ebx
        NEXT

dictentry SPRINTF, "SPRINTF"  ; ( ?args? nargs fmtstr -- PAD n )
        pop ecx
        RPUSH ecx
        push ebx
        push 128
        push PAD
        call snprintf
        add esp, 12
        RPOP ecx
        shl ecx, 2
        add esp, ecx   ; remove args to snprintf
        push PAD
        mov ebx, eax
        NEXT

intfmt  db "%d ", 0
dictentry PRINTNUM, "."
        push ebx
        push 1
        mov ebx, intfmt
        mov eax, SPRINTF
        call ASMEXEC
        jmp TYPE

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
        push 0x0          ; bogus value under stack
        NEXT

dictentry TIB_CLEAR, "TIB_CLEAR"
        mov dword [TIB], 0
        NEXT

dictentry QUIT, "QUIT"
        call ENTER
        dd RP_CLEAR
        dd TIB_CLEAR
        dd INTERPRET, BRANCH, -12

dictentry EMIT, "EMIT"
        push ebx
        mov eax, 0x04  ; sys_write
        mov ebx, 1     ; stdout
        lea ecx, [ESP] ; pointer to the char at TOS
        mov edx, 1     ; count
        int 0x80
        add esp, 4     ; ditch old TOS
        pop ebx        ; new TOS
        NEXT

; eax = xt of forth word, then 'call ASMEXEC'.  note that esi, edi, ebx, etc must be valid in the forth context
ASMEXEC:
    pop edx   ; ret address from call
    RPUSH esi ; inline ENTER
    mov esi, ASMEXEC_CONT
    RPUSH edx ; save on ret stack
    jmp eax

ASMEXEC_CONT dd asm_RET_TO_ASM
asm_RET_TO_ASM:
    RPOP eax
    RPOP esi  ; inline EXIT
    jmp eax

dictentry CR, "CR"
        call ENTER
        dd DOLITERAL, 13, EMIT, DOLITERAL, 10, EMIT, EXIT

dictentry ABORT, "ABORT"
        call ENTER
        dd SP_CLEAR
pQUIT   dd QUIT

pABORT  dd ABORT

section .data
TIBUF   times 128 db 0
TIB     dd 0
PAD     times 128 db 0
LATEST  dd latest_tok
SP0     dd 0
RP0     dd 0
