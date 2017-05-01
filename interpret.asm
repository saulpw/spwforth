
dictentry _WORD, "WORD"
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

dictentry FIND, "FIND"  ; ( str -- str|xt 0|1|-1 )
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
