
dotessfmt db "<%d> ", 0
dictentry DOTESS, ".S"
        mov ecx, [SP0]
        sub ecx, esp
        sar ecx, 2
        dec ecx      ; ecx := number of elements on stack

        RPUSH ecx

        push ebx   ; push TOS under rest of args to SPRINTF

        push ecx
        push 1
        mov ebx, dotessfmt
        mov eax, SPRINTF
        call ASMEXEC
        mov eax, TYPE
        call ASMEXEC

        RPOP ecx

nextcell:
        or ecx, ecx
        jz done

        push ebx   ; push TOS on stack proper

        RPUSH ecx

        push dword [ecx*4+esp-4]
        push 1
        mov ebx, intfmt
        mov eax, SPRINTF
        call ASMEXEC
        mov eax, TYPE
        call ASMEXEC

        RPOP ecx
        loop nextcell

done:   NEXT

dictentry _WORD, "WORD"
        push esi
        push edi

        mov esi, [TIB]
        or esi, esi    ; if no source for input buffer
        jz getline

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

        dec esi        ; start next WORD at space/NUL
        mov [TIB], esi

        mov ebx, PAD   ; returned word always at start of PAD

        pop edi
        pop esi
        NEXT

; should become REFILL ( -- flag ) at some point
getline:
        pop edi
        pop esi

        mov eax, CR
        call ASMEXEC

        push 128
        push TIBUF
        push 0   ; stdin
        call read
        add esp, 12
        mov byte [eax+TIBUF-1], 0   ; replace \n with NUL
        mov dword [TIB], TIBUF
        jmp _WORD       ; restart

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
