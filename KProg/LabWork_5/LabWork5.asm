.model small
.stack 100h
.data
    bufferForCmd db 100, ?, 100 dup(?)
    inputFileName db 100 dup(?)
    outputFileName db 100 dup(?)
    wordToFind db 50, ?, 50 dup(?)
    inputHandler dw ?
    outputHandler dw ?
    newLine db 0dh, 0ah, "$"
    openFileError db "Can't open file!"
    usageError db 'Usage: program.exe <input file> <output file> <word>', 0dh, 0ah, '$'
    noArgProvided db 'Not all arguments provided', 0dh, 0ah, '$'
    fileNotFoundError db 'Error: Input file not found!', 0dh, 0ah, '$'
    wordToFindErrorMsg db 'Error: Word is incorrect!', 0dh, 0ah, '$'
    
.code

main PROC
    mov ax, @data
    mov es, ax
    
readFromCmd:
    xor cx, cx
    mov cl, ds:[80h]
    lea si, ds:[81h]
    lea di, bufferForCmd + 2
    
    rep movsb
    
    mov ds, ax
    mov byte ptr [di], 0dh
    
    call ParseArguments
    cmp cl, 3
    jne ShowUsage
    
    lea dx, inputFileName
    mov ah, 3Dh             ;Open file
    mov al, 0               ;Read-only mode
    int 21h
    jc FileNotFound
    
    mov inputHandler, ax              ;Store the file handle of input file
    
;    lea dx, outputFileName         ;Use this code in emu8086 because 5Bh interrupt doesn't work in emu
;    mov ah, 3Dh
;    mov al, 2
;    int 21h

    lea dx, outputfilename
    mov ah, 5Bh                     ;this interrupt works in dosbox and doesn't work in emu8086
    mov al, 7
    int 21h
    
    mov outputHandler, ax              ;Store the file handle of output file
    
    ;Process input file line by line
    call ProcessFile
    
    jmp Exit
    
ShowUsage:
    lea dx, usageError
    mov ah, 09h
    int 21h
    jmp Exit    
    
NoArgError:
    lea dx, noArgProvided
    mov ah, 09h
    int 21h
    
    lea dx, usageError
    mov ah, 09h
    int 21h
    jmp Exit
    
FileNotFound:
    lea dx, fileNotFoundError
    mov ah, 09h
    int 21h
    jmp Exit
    
WordToFindError:
    lea dx, wordToFindErrorMsg
    mov ah, 09h
    int 21h
    jmp ShowUsage
    
    ;Exit program
Exit:

    mov ah, 3Eh
    mov bx, inputHandler
    int 21h
    
    mov ah, 3Eh
    mov bx, outputHandler
    int 21h

    mov ah, 4Ch
    int 21h
    
main ENDP

;--------------- Functions block -------------------

ParseArguments PROC
    xor cx, cx              ; Clear CX to start counting arguments
    lea si, bufferForCmd + 2
    lea di, inputFileName
    call GetNextArg         ; Read the first argument
    cmp al, 0
    je NoArgError
    
    inc cx                  ; Increment argument count if parsed successfully
    lea di, outputFileName
    call GetNextArg         ; Read the second argument
    cmp al, 0
    je NoArgError
    
    inc cx                  ; Increment argument count if parsed successfully
    lea di, wordToFind
    call GetNextArg         ; Read the third argument
    
    lea si, wordToFind
    call checkWordToFind
    cmp al, 0
    je WordToFindError
    
    mov byte ptr [di], "$"
    cmp al, 0
    je NoArgError
    
    inc cx                  ; Increment argument count if parsed successfully
    ret
    
ParseArguments ENDP

GetNextArg PROC
    ; Input: SI = address in bufferForCmd, DI = destination buffer
    ; Output: Word stored in destination buffer, SI updated
    push di
    xor al, al              ; Clear AL to indicate failure initially

CheckFirstSpace:
    cmp byte ptr [si], ' '
    jne ShowUsage
    
    inc si
    
ReadLoop:
    lodsb                    ; Load byte from buffer into AL
    cmp al, ' '              ; Check if it’s a space
    je CheckIfLastArg
    cmp al, 0dh                
    je EndArg                ; If end of string, exit
    stosb                    ; Store the character in the destination buffer
    jmp ReadLoop           ; Continue until space or end of string
    
CheckIfLastArg:
    cmp cx, 2
    jne EndArg
    
    stosb
    
ReadToEnd:
    lodsb
    cmp al, 0dh
    je EndArg
    stosb
    jmp ReadToEnd

EndArg:
    mov ax, di
    pop di
    cmp di, ax
    je NoArg                 ; If no argument (di didn't move), no valid argument

    mov di, ax
    mov al, 1                ; Set AL to 1 to indicate success
    dec si
    ret

NoArg:
    xor al, al               ; Set AL to 0 to indicate failure
    dec si
    ret
GetNextArg ENDP

ProcessFile PROC
    
    mov bufferForCmd[2], ' '
    lea dx, bufferForCmd + 3       ;Buffer for line
    mov bx, inputHandler
readChar:
    
    mov ah, 3Fh
    mov cx, 1
    int 21h
    
    cmp al, 0
    je EndOfFile
    
    mov si, dx                  ;Get a read char
    mov al, [si]
    cmp al, 0ah
    je doneReading
    inc dx
    inc bufferForCmd[1]
    jmp readChar
    
doneReading:
    
    call SearchWord
    
    cmp al, 0
    je ProcessNextLine
    
    mov ah, 40h
    mov bx, outputHandler
    xor cx, cx
    mov cl, bufferForCmd[1]
    lea dx, bufferForCmd + 3
    int 21h
    
ProcessNextLine:
    call ClearBufferForCmd

    jmp ProcessFile
    
EndOfFile:
    ret    
    
ProcessFile ENDP

SearchWord PROC
    xor al, al                ; Clear AL to 0 (not found)
    lea si, bufferForCmd + 2  ; Line buffer
    lea di, wordToFind        ; Word to search for
    xor cx, cx
    

SearchLoop:
    lodsb                     ; Load next character from line into AL
    cmp al, 0ah               ; End of line?
    je NotFound               ; If end of line, not found

    cmp al, byte ptr [di]     ; Compare with current character of word
    jne ResetWordPointer      ; If not equal, continue searching

    inc di                    ; Move to next character in word
    inc cx                    ; Count size of wordToFind
    cmp byte ptr [di], "$"    ; End of word?
    je Found                  ; If word is fully matched, found

    jmp SearchLoop            ; Continue searching
    
NotFound:
    xor al, al
    ret
    
ResetWordPointer:
    lea di, wordToFind
    xor cx, cx
    jmp SearchLoop

Found:    
    cmp byte ptr [si], ' '
    je checkSpaceBefore
    cmp byte ptr [si], 0dh
    je checkSpaceBefore
    
    jmp WordNotBounded
    
checkSpaceBefore:
    sub si, cx
    dec si
    cmp byte ptr [si], ' '
    je WordBounded
    lea di, bufferForCmd[2]
    cmp [si], di
    je WordBounded
    
    add si, cx
    inc si
    
WordNotBounded:
    
    jmp ResetWordPointer
    
WordBounded:
    mov al, 1
    ret
    
SearchWord ENDP


ClearBufferForCmd PROC
    lea di, bufferForCmd + 1
    mov cx, 101
    xor al, al
    rep stosb
    ret
ClearBufferForCmd ENDP


checkWordToFind PROC
    
check_loop:
    lodsb
    cmp al, 0           
    je valid
    cmp al, 20h        
    je reject           
    cmp al, 09h        
    je reject           
    jmp check_loop      

valid:
    mov ax, 1           
    ret

reject:
    mov ax, 0           
    ret 
checkWordToFind ENDP

end