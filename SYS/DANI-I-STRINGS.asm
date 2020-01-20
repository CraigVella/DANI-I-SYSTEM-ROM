;-------------------------------------------------
;-------------DANI-I-STRINGS----------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
V_CCHARBUFFER:    .SET $300           ; Common System 255 Byte Character Buffer
;-------------EO-EQUATES--------------------------

;-------------MACROS------------------------------
M_STR_TOUPPER:   .MACRO srcPtr, dstPtr     ; String to uppercase
    M_PTR_STORE srcPtr, V_SYSVAR1
    M_PTR_STORE dstPtr, V_SYSVAR2
    JSR SYS_STR_TOUPPER
    .ENDM

M_STR_COPY:      .MACRO srcPtr, dstPtr     ; Copy String
    M_PTR_STORE srcPtr, V_SYSVAR1
    M_PTR_STORE dstPtr, V_SYSVAR2
    JSR SYS_STR_COPY
    .ENDM

M_STR_CONCAT:    .MACRO str1, str2, dst    ; Concatenate two strings and store in dst
    M_PTR_STORE str1, V_SYSVAR1
    M_PTR_STORE str2, V_SYSVAR2
    M_PTR_STORE dst,  V_SYSVAR3
    JSR SYS_STR_CONCAT
    .ENDM

M_STR_PATTERNMATCH: .MACRO string, pattern ; See if String Pattern Matches
    M_STR_COPY  pattern, V_CCHARBUFFER
    M_PTR_COPY  string, V_SYSVAR1
    JSR SYS_STR_PATTERN
    .ENDM
    
M_STR_FROMBYTE: .MACRO bytePtr             ; Create String from Byte
    M_PTR_STORE bytePtr, V_SYSVAR1
    JSR SYS_STR_FROMBYTE
    .ENDM

M_SYS_FILLMEMORY: .MACRO dst, size, val
    M_PTR_STORE dst, V_SYSVAR1
    LDA #size
    STA V_SYSVAR2
    LDA #val
    STA V_SYSVAR3
    JSR SYS_FILLMEMORY
    .ENDM

M_SYS_STR_LEN: .MACRO str
    M_PTR_STORE str, V_SYSVAR1
    JSR SYS_STR_LEN
    .ENDM

M_SYS_STR_APPEND: .MACRO str, addition
    M_PTR_STORE str, V_SYSVAR1
    M_PTR_STORE addition, V_SYSVAR2
    JSR SYS_STR_APPEND
    .ENDM
;-------------EO-MACROS---------------------------

;----------SUB-ROUTINES--------------------------------------------------------------------------------------------

;-----------String Legnth----------------------------
;-- Returns the Legnth of a given String
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB -> GSB = String
;-- Return: V_SYSVAR2 String Length
;----------------------------------------------------
SYS_STR_LEN:
    PHA
    PHY
    LDY #$00                  ; String Counter Set to 0
.continue
    LDA (V_SYSVAR1),Y         ; Load the index of String
    CMP #$00                  ; Check to see if it's Null
    BEQ .doneCount
    INY                       ; Increase Y Count
    CPY #$FF                  ; Check to see if were at max str len
    BNE .continue             ; If were not at max continue our count
.doneCount
    STY V_SYSVAR2             ; Store Y in 12 that's the string len
    PLY
    PLA
    RTS

;-----------String To Upper--------------------------
;-- Takes String pointed to at ZP10 and Stores it at Location Pointed to ZP12
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB -> GSB = String To Upper
;-- Parameters - V_SYSVAR2 - 2Bytes - LSB -> GSB = Address To Put Upper String
;----------------------------------------------------
SYS_STR_TOUPPER:
    PHA
    PHY
    PHX
    LDY #$00      ; Set Y to 0 - Counter
.continue
    LDA (V_SYSVAR1),Y   ; Load Index Y
    BEQ .done     ; If Null we are done
    ; Check to see if this is a character
    TAX           ; Save Original In X
    AND #@1011111 ; Convert Accum to Uppercase
    CMP #64       ; Make sure it's Larger than 64
    BCC .notChar  ; This is not a char, replace original and continue
    CMP #91       ; Make Sure it's Less than 91
    BCS .notChar  ; This is not a char again
    STA (V_SYSVAR2),Y   ; Store it and Move on
.nextChar 
    INY           ; Add 1 to Y
    JMP .continue ; Continue to Next
.notChar
    TXA           ; Transfer Orignal Back
    STA (V_SYSVAR2),Y   ; Store it on next
    JMP .nextChar
.done
    STA (V_SYSVAR2),Y   ; Store the end Null Character
    PLX
    PLY
    PLA
    RTS
    
;------------String Copy--------------------------------------
;-- Takes a Null Term String At ZP10 and Copies it to address at ZP12
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB->GSB = String to Copy
;-- Parameters - V_SYSVAR2 - 2Bytes - LSB->GSB = Memory Location to Copy to
;-------------------------------------------------------------
SYS_STR_COPY:
    PHA
    PHY
    LDY #$00      ; Set Y to 0 - Counter
.continue
    LDA (V_SYSVAR1), Y  ; Load Index of String
    BEQ .done     ; If it's NUL we are at end of String
    STA (V_SYSVAR2), Y  ; Copy and Store In Location
    INY           ; Increase Y
    JMP .continue
.done
    LDA #$00
    STA (V_SYSVAR2), Y  ; Store Nul Terminator
    PLA
    PLY
    RTS
    
;------------String Append------------------------------------
;-- Takes a Null Term String At V_SYSVAR1 and appends it to address at V_SYSVAR2
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB->GSB = Source String
;-- Parameters - V_SYSVAR2 - 2Bytes - LSB->GSB = String being appended
;-------------------------------------------------------------
SYS_STR_APPEND:
    PHA
    PHY
    PHX
    M_PTR_TOSTACK V_SYSVAR2      ; Push Var 2 to stack while we get Str Len
    JSR SYS_STR_LEN              ; Get Str Len of Var Source String
    LDY V_SYSVAR2                ; Save Str Len to Y
    M_PTR_FROMSTACK V_SYSVAR2    ; Pull Sys Var 2 back from stack
.copyStr
    LDA (V_SYSVAR2)              ; Load Character into A
    BEQ .done                    ; If it's a Null were done
    CPY #$FE                     ; We're done if next place is 254 no matter what
    BEQ .done
    STA (V_SYSVAR1), Y           ; Store It into String at Y
    INY
    INC V_SYSVAR2                ; Increase our Pointer
    BNE .copyStr                 ; We need to increase our GSB
    INC V_SYSVAR2+1              ; Increase our GSB
    JMP .copyStr                 ; Back to Top
.done
    ; Put Null on end and exit
    INY
    LDA #$00
    STA (V_SYSVAR1), Y           ; Save NULL to term String
    PLX
    PLY
    PLA
    RTS

;-----------String Concatenate--------------------------------
;-- Takes a Null Term String At ZP10 and Concatenates it With String At ZP12 - Stores Result at ZP14
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB->GSB = String 1
;-- Parameters - V_SYSVAR2 - 2Bytes - LSB->GSB = String 2
;-- Parameters - V_SYSVAR3 - 2Bytes - LSB->GSB = Output String
;-- Output = New String Ptr at V_SYSVAR3 , V_SYSVAR4 will new string size
;-------------------------------------------------------------
SYS_STR_CONCAT:
    PHA
    PHY
    LDA #$00
    STA V_SYSVAR4            ; ZP16 Will Contain New String Size - Set it to 0
    ; First Mem Copy String 1 Into ZP14
    M_PTR_TOSTACK V_SYSVAR2  ; Push V_SYSVAR2 to stack (Contains 2nd String to Concat)
    M_PTR_TOSTACK V_SYSVAR3  ; Push V_SYSVAR3 to stack (Contains location of final string)
    M_PTR_COPY V_SYSVAR3, V_SYSVAR2 ; Copy Output String to Output for Str Copy          
    JSR SYS_STR_COPY   ; Copy String to New Location From V_SYSVAR1 -> V_SYSVAR3
    JSR SYS_STR_LEN    ; Get String Len of String in V_SYSVAR1, located in V_SYSVAR2
    LDA V_SYSVAR2      ; Save New String Len to 16
    STA V_SYSVAR4      ; Save string len in V_SYSVAR4 
    M_PTR_FROMSTACK V_SYSVAR2 ; Pull Output string Location off Stack and put in V_SYSVAR2           
    M_PTR_FROMSTACK V_SYSVAR1 ; Pull 2nd string to concat off stack and store in V_SYSVAR1
    DEC V_SYSVAR4      ; Deduct Current String Size By 1 (REMOVE NULL)
    LDA V_SYSVAR2      ; Get String Destination LSB
    ADC V_SYSVAR4      ; Add String Size Minus 1 to Accum
    BCS .addToGSB      ; If there was a Carry add one to GSB As Well
.cont
    STA V_SYSVAR2      ; Store New LSB
    JSR SYS_STR_COPY   ; Copy new string in
    JMP .done
.addToGSB
    INC V_SYSVAR2+1    ; Carry was set, increase the GSB
    JMP .cont
.done
    PLY
    PLA
    RTS

;------------String From Byte---------------------------------
;-- Takes a Memory Location @ ZP10 And Converts Byte To String in HEX @ V_CCHARBUFFER
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB->GSB = Memory Location
;-- Output V_CCHARBUFFER = Hex String
;-------------------------------------------------------------
SYS_STR_FROMBYTE:
    PHA
    PHY
    LDY #$01
    LDA (V_SYSVAR1)       ; Grab Byte from Memory Location
    AND #@00001111        ; Mask for LSNibble
.next
    ORA #@00110000        ; Or For ASCII
    CMP #$3A              ; Check to see if it's greater than ASCII 9
    BCS .greaterThan9
.cont
    STA V_CCHARBUFFER, Y  ; Store this in V_CCHARBUFFER
    CPY #$00              ; Check to see if were done
    BEQ .done
    LDA (V_SYSVAR1)
    AND #@11110000        ; Mask for GSNibble
    ROR                   ; Shift Right 4 times
    ROR
    ROR
    ROR
    DEY
    JMP .next
.greaterThan9
    DEA                   ; Increase Accum By One
    ORA #@01000000        ; Turn on Character Bit
    AND #@01000111        ; Only Care about Char Bit and Last 3 Bits
    JMP .cont
.done
    LDA #$00              ; Load NULL
    STA V_CCHARBUFFER+2   ; NULL Out String
    PLY
    PLA
    RTS

;------------Byte From String---------------------------------
;-- Takes a String from Location @ ZP10 And Converts To Byte @ ZP12
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB->GSB = String Location
;-- Parameters - V_SYSVAR2 - 2Bytes - LSB->GSB = Memory Location to Store Byte
;-- ON Error Carry Flag is Set
;-------------------------------------------------------------
SYS_BYTE_FROMSTR:
    PHA
    PHY
    LDY #$00           ; Start Y at Zero
.next
    LDA (V_SYSVAR1), Y       ; Load First Character of String
    BIT #@00110000     ; Check to see if it's a number
    BEQ .nan
    ; it could be a number check to see if it's less than ':'
    CMP #$3A           ; Check to see if it's less than ':'
    BCS .err           ; It's larger than a number but not A-F
.invalidCont
    AND #@00001111     ; Convert to Number
    CPY #$01           ; Check to see if were doing the LSB
    BEQ .finishLSB     ; finish up
    ROL
    ROL
    ROL
    ROL
    STA (V_SYSVAR2)    ; Store GSB in $12
    JMP .doLSB
.nan
    BIT #@01000000     ; Check to see if it's in right Letter Range
    BEQ .err           ; Not a correct Letter
    AND #@00000111     ; Mask all but final three
    INA                ; INC A by 1
    BIT #@00001000     ; Ensure this is within realm by seeing if increase went over F
    BNE .err           ; This is greater than F
    ORA #@00001000     ; Turn on Bit 4 for Hex
    JMP .invalidCont   ; Continue on with set GSB
.doLSB
    INY
    JMP .next
.finishLSB
    ORA (V_SYSVAR2)    ; Or Memory in 12 with new number
    STA (V_SYSVAR2)    ; Store
    CLC                ; Clear the Carry Flag, no Error
    JMP .done
.err
    SEC
.done
    PLY
    PLA
    RTS
    
;-----------SYS-String Pattern Match--------------------------
;-- Takes String pointed to at ZP10 and Pattern In Common Char Buffer, if they match Carry is Set
;-- All Patterns can use ? for single character, and * for wildcard
;-- Parameters - V_SYSVAR1 - 2Bytes - LSB -> GSB = String to Search
;-- Parameters - V_CCHARBUFFER -> Pattern
;----------------------------------------------------
SYS_STR_PATTERN:
    PHA
    PHX
    PHY
    LDX #$00              ; X is an index in the pattern
    LDY #$FF              ; Y is an index in the string
.next
    LDA V_CCHARBUFFER,X   ; Look at next pattern character
    CMP #'*'              ; Is it a star?
    BEQ .star             ; Yes, do the complicated stuff
    INY                   ; No, let's look at the string
    CMP #'?'              ; Is the pattern caracter a ques?
    BNE .reg              ; No, it's a regular character
    LDA (V_SYSVAR1),Y           ; Yes, so it will match anything
    BEQ .fail             ; except the end of string
.reg
    CMP (V_SYSVAR1),Y           ; Are both characters the same?
    BNE .fail             ; No, so no match
    INX                   ; Yes, keep checking
    CMP #0                ; Are we at end of string?
    BNE .next             ; Not yet, loop
.found
    PLY
    PLX
    PLA
    RTS                   ; Success, return with C=1
.star
    INX                   ; Skip star in pattern
    CMP V_CCHARBUFFER,X   ; String of stars equals one star
    BEQ .star             ;  so skip them also
.stLoop
    TXA                   ; We first try to match with * = ""
    PHA                   ;  and grow it by 1 character every
    TYA                   ;  time we loop
    PHA                   ; Save X and Y on stack
    JSR .next             ; Recursive call
    PLA                   ; Restore X and Y
    TAY
    PLA
    TAX
    BCS .found            ; We found a match, return with C=1
    INY                   ; No match yet, try to grow * string
    LDA (V_SYSVAR1),Y           ; Are we at the end of string?
    BNE .stLoop           ; Not yet, add a character
.fail
    CLC                   ; Yes, no match found, return with C=0
    PLY
    PLX
    PLA
    RTS

;----------Fill Memory Up to 256 Bytes ------------
;-- Zeros Memory at Starting Point
;-- Parameters - V_SYSVAR1 = Memory Location to Zero (starting with LSB and then GSB in ZP11)
;-- Parameters - V_SYSVAR2 = amount to Zero out
;-- Parameters - V_SYSVAR3 = value to fill
;-------------------------------------------------
SYS_FILLMEMORY:
    PHA
    PHY
    LDY #$00            ; Set Y to Value at 21
    LDA V_SYSVAR3       ; Store Value in A
.cont
    STA (V_SYSVAR1),Y   ; Null Memory at $10+Y
    CPY V_SYSVAR2       ; Compare Y count to How Much it should blank
    BEQ .done           ; If Y and Amount are equal we are done
    INY                 ; Increase Y by 1
    JMP .cont           ; Contineu on
.done
    PLY
    PLA
    RTS
