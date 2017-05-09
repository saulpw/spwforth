
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

        mov ecx, edi   ; ecx := saved HERE
        inc edi        ; reserve one char for length

        mov esi, [TIB]
        or esi, esi    ; if no source for input buffer
        jz getline

nextchar:
        lodsb
        cmp al, bl
        jz gotspace
        or al, al
        jz gotzero

        stosb
        jmp nextchar

gotzero:               ; end of string:
        lea eax, [edi-1] ; minus length byte
        cmp eax, ecx   ; if no characters stored yet
        jz getline     ; get line of input from user

gotspace:
        lea eax, [edi-1] ; minus length byte
        cmp eax, ecx   ; if leading spaces only
        jz nextchar    ; just continue
        mov al, 0
        stosb          ; store terminating NUL

        dec esi        ; start next WORD at space/NUL
        mov [TIB], esi

        mov edx, edi
        sub edx, ecx
        sub edx, 2     ; edx := char count (remove len and NUL term bytes)

        mov edi, ecx   ; restore saved HERE
        pop esi

        mov ebx, edi   ; returned word starts at current HERE
        mov [ebx], dl  ; backfill strlen (count of chars)
        NEXT

; should become REFILL ( -- flag ) at some point
getline:
        mov edi, ecx   ; restore saved HERE
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

dictentry FIND, "FIND"  ; ( tok -- tok|xt 0|1|-1 )
        push esi
        push edi

        mov edx, [LATEST]

checkword:
        movzx ecx, byte [ebx]  ; ecx := strlen(tok)
        mov edi, ebx      ; edi := tok
        inc edi

        lea esi, [edx+5]  ; esi := ptr to dict namelen
        xor eax, eax
        lodsb             ; eax := namelen, esi := nameptr
        cmp eax, ecx
        jnz nextword      ; skip if lengths are different

        repz cmpsb
        jz found

nextword:
        mov edx, [edx]
        or edx, edx       ;  link != 0 (more dictionary entries)
        jnz checkword

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
notimmed:
        lea edx, [edx+eax+6]     ; get xt from header (6=link+namelen+NUL+flags)

        push edx
        NEXT
