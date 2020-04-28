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
extern strtol, snprintf

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

; internal words, use like: dictentry STAR, "*"
%macro dictentry 2
%strlen namelen %2
nt_%1  dd latest_tok
%define latest_tok nt_%1
       db 0          ; not immediate
       db namelen
name_%1 db %2
%1:
%endmacro

; internal IMMEDIATE words, use like: dictentry SEMI, ";", 1
%macro dictentry 3
%strlen namelen %2
nt_%1  dd latest_tok
%define latest_tok nt_%1
       db 0x80       ; immediate (macro arg doesn't matter)
       db namelen
       db %2
%1:
%endmacro

main:
        sub esp, 0x40     ; esp = data stack, grows down
        lea ebp, [esp+4]  ; ebp = return stack, grows up
        mov [RP0], ebp
        mov [SP0], esp
        mov esi, pABORT   ; esi = Forth PC
        mov edi, available ; edi = HERE
        NEXT

; start of dictionary

ENTER:  RPUSH esi
        pop esi           ; get parameter field address from 'call ENTER'
        NEXT

EXIT:   RPOP esi
        NEXT

dictentry DOLITERAL, "DOLIT" ; ( -- v )
        lodsd
        push ebx
        mov ebx, eax
        NEXT

dictentry EXECUTE, "EXECUTE" ; ( ?? xt -- ?? )
        pop eax
        xchg eax, ebx
        jmp eax

dictentry QDUP, "?DUP"    ; ( 0|a -- 0|a a )
        or ebx, ebx
        jz qdupdone
        push ebx
qdupdone: NEXT

dictentry GTZERO, "0>"    ; ( v -- v>0 )
        cmp ebx, 0
        jle false
        mov ebx, 1
        NEXT
false:  mov ebx, 0
        NEXT

dictentry EQZERO, "0="    ; ( v -- v>0 )
        or ebx, ebx
        jnz false2
        mov ebx, 1
        NEXT
false2:  mov ebx, 0
        NEXT

dictentry BRANCH, "BRANCH"    ; ( -- )
        lodsd
        add esi, eax
        NEXT

dictentry QBRANCH, "?BRANCH"  ; ( b -- )
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

dictentry INCR, "1+"  ; ( a -- a+1 )
        inc ebx
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
        inc ebx
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

        mov esi, pQUIT     ; QUIT after 'calling' TYPE
        jmp TYPE

dictentry TYPE, "TYPE" ; ( ptr n -- )
        mov edx, ebx   ; count
        pop ecx        ; ptr to buf
        mov ebx, 1     ; stdout
        mov eax, 0x04  ; sys_write
        int 0x80

        pop ebx
        NEXT

dictentry SPRINTF, "SPRINTF"  ; ( ?args? nargs fmtstr -- PAD n )
        pop ecx        ; ecx := nargs
        RPUSH ecx      ; save nargs on return stack

        push ebx       ; fmtstr
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

dictentry FETCH, "@"   ; ( ptr -- v )
        mov ebx, [ebx]
        NEXT

dictentry STORE, "!"   ; ( v ptr -- )
        pop eax
        mov [ebx], eax
        pop ebx
        NEXT

dictentry ADDSTORE, "+!"   ; ( n ptr -- )
        pop eax
        add [ebx], eax
        pop ebx
        NEXT

dictentry COMMA, ","   ; ( v -- )
        mov eax, ebx
        stosd
        pop ebx
        NEXT

dictentry HERE, "HERE"  ; ( -- ptr )
        push ebx
        mov ebx, edi
        NEXT

dictentry ALLOT, "ALLOT" ; ( n -- )
        add edi, ebx
        pop ebx
        NEXT


dictentry IMMEDIATE, "IMMEDIATE"   ; ( -- )
        mov eax, [LATEST]
        or byte [eax+4], 0x80
        NEXT

dictentry CREATE, "CREATE"   ; ( "<token>" -- )
        mov eax, edi
        xchg eax, [LATEST]
        stosd       ; link pointer
        mov al, 0
        stosb       ; flags (!immediate)
        push ebx
        mov ebx, 32    ; until next space
        mov eax, _WORD
        call ASMEXEC
        movzx eax, byte [edi]  ; count
        lea edi, [edi+eax+1]

        ; set up 'call ENTER'
        mov al, 0xe8           ; rel32 call
        stosb
        mov eax, ENTER
        sub eax, edi
        sub eax, 4             ; [(edi-1)+5+eax] := ENTER
        stosd
        NEXT

dictentry RBRACKET, "]"   ; ( "<token>" -- )
        mov dword [_STATE], 1  ; compilation state
        NEXT

dictentry LBRACKET, "["   ; ( "<token>" -- )
        mov dword [_STATE], 0  ; interpret state
        NEXT

dictentry COLON, ":"   ; ( "<token>" -- )
        call ENTER
        dd CREATE, RBRACKET, EXIT

dictentry SEMICOLON, ";", 1   ; ( "<token>" -- )
        call ENTER
        dd DOLITERAL, EXIT, COMMA, LBRACKET, EXIT

dictentry BLANK, "BL"
        call ENTER
        dd DOLITERAL, 32, EXIT

dictentry COMPILETICK, "[']", 1  ; ( "<token>" -- ) runtime: ( -- xt )
        call ENTER
        dd BLANK, _WORD, FIND, EQZERO, QABORT, LITERAL, EXIT

dictentry LITERAL, "LITERAL"
        call ENTER
        dd DOLITERAL, DOLITERAL, COMMA, COMMA, EXIT

%include "interpret.asm"

INTERPRET_WORD: call ENTER
        dd BLANK, _WORD
        dd FIND, QBRANCH, 12
        dd EXECUTE, BRANCH, 4, TONUM, EXIT

COMPILE_WORD: call ENTER
        dd BLANK, _WORD
        dd FIND
        dd QDUP, QBRANCH, 36, GTZERO
        dd QBRANCH, 12, EXECUTE, BRANCH, 4, COMMA
        dd BRANCH, 8
        dd TONUM, LITERAL
        dd EXIT

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
        dd STATE, FETCH, QBRANCH, 12, COMPILE_WORD, BRANCH, 4, INTERPRET_WORD
        dd BRANCH, -40

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

dictentry STATE, "STATE"
        push ebx
        mov ebx, _STATE
        NEXT

dictentry ABORT, "ABORT"
        call ENTER
        dd SP_CLEAR
pQUIT   dd QUIT

dictentry QABORT, "?ABORT"
        call ENTER
        dd QBRANCH, 4, ABORT, EXIT

pABORT  dd ABORT

section .data
TIBUF   times 132 db 0
TIB     dd 0
PAD     times 128 db 0
LATEST  dd latest_tok
SP0     dd 0
RP0     dd 0
_STATE  dd 0

available times 16384 db 0  ; rest of dictionary
