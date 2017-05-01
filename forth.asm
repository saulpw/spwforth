; a clean direct-threaded Forth implementation

bits 32

global _start

%macro NEXT 0
        lodsd       ; fetch next xt from PC
        jmp eax     ; direct threading
%endmacro

%macro RPOP 1
        xchg ebp, esp
        pop %1
        xchg ebp, esp
%endmacro

%macro RPUSH 1
        xchg ebp, esp
        push %1
        xchg ebp, esp
%endmacro

_start:
        sub esp, 0x40     ; esp = data stack, grows down
        mov ebp, esp      ; ebp = return stack, grows up
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

DUP:    push ebx
        NEXT

STAR:   pop eax
        imul ebx
        mov ebx, eax
        NEXT

BYE:    mov eax, 1         ; eax = syscall 1 (exit)
        int 0x80           ; ebx = exit code (conveniently also TOS)

SQUARED: call ENTER
         dd DUP, STAR, EXIT

; a simple test: echo $? should be 25
START    dd DOLITERAL, 5, SQUARED, BYE

