; a clean direct-threaded Forth implementation

bits 32

global main
extern atoi, printf, read

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

%define latest_tok 0  ; tail of dictionary linked list

%macro dictentry 1
       align 16, db 0
nt_%1  dd latest_tok
%define latest_tok nt_%1
%defstr name %1
       db name
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

DUP:    push ebx
        NEXT

STAR:   pop eax
        imul ebx
        mov ebx, eax
        NEXT


dictentry BYE
        mov eax, 1         ; eax = syscall 1 (exit)
        int 0x80           ; ebx = exit code (conveniently also TOS)

TONUM:
        push ebx
        call atoi
        add esp, 4
        mov ebx, eax
        NEXT

_WORD:
        push esi
        push edi

restart:
        mov esi, [TIB]
        mov edi, PAD

nextchar:
        lodsb
        cmp al, bl
        jz gotspace
        or al, al
        jz gotzero

        stosb
        jmp nextchar

gotzero:               ; end of string:
        cmp edi, PAD   ; if no characters stored yet
        jz getline     ; get line of input from user

gotspace:
        cmp edi, PAD   ; if leading spaces
        jz nextchar    ; just continue
        mov al, 0
        stosb          ; store terminating NUL

        mov [TIB], esi

        mov ebx, PAD   ; returned word always at start of PAD

        pop edi
        pop esi
        NEXT

getline:
        push 128
        push TIB
        push 0   ; stdin
        call read
        add esp, 12
        mov ebx, eax
        jmp restart

FIND:   ; ( str -- str|xt 0|1|-1 )
        push esi
        push edi

        mov edi, ebx      ; given string pointer
        mov ecx, 128
        mov al, 0
        repnz scasb       ;
        mov eax, edi
        sub eax, ebx      ; put strlen in eax

        mov edx, [LATEST]

nextword:
        lea esi, [edx+4]  ; dict name
        mov edi, ebx      ; esi = str
        mov ecx, eax      ; eax = strlen(str)
        repz cmpsb
        jz found
        mov edx, [edx]
        or edx, edx       ;  link != 0 (more dictionary entries)
        jnz nextword

notfound:
        pop edi
        pop esi

        push ebx
        xor ebx, ebx
        NEXT
found:
        pop edi
        pop esi

        add edx, 16       ; get xt from nt
        push edx
        mov ebx, 1
        NEXT

dictentry SQUARED
        call ENTER
        dd DUP, STAR, EXIT

INTERPRET: call ENTER
    dd DOLITERAL, 32, _WORD, FIND, QBRANCH, 12
    dd EXECUTE, BRANCH, 4, TONUM, EXIT

START   dd INTERPRET, BRANCH, -12

TIBUF   db "10 SQUARED BYE", 0

section .data
TIB     dd TIBUF
PAD     times 128 db 0
LATEST  dd latest_tok
