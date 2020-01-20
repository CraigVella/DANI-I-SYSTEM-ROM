;-------------------------------------------------
;-------------DANI-I-COMMANDER--------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
V_DANIVAR1:       .SET $30            ; DANI-CMD Variable 1
V_DANIVAR2:       .SET $32            ; DANI-CMD Variable 2
V_DANIVAR3:       .SET $34            ; DANI-CMD Variable 3
V_DANIVAR4:       .SET $36            ; DANI-CMD Variable 4
V_DANICHARBUFFER: .SET $500           ; Common Dani OS 255 Byte Character Buffer
V_DANICMDBUFFER:  .SET $400           ; DANICMD Buffer
;-------------EO-EQUATES--------------------------

;--------------------------------------------------
;---------Static STRINGS---------------------------
;--------------------------------------------------

S_DANI_OS       .DB "DANI-OS 32k RAM - Ver 1.1a", $00
S_Ready         .DB "System Ready.", $00
S_CMDS          .DB ">", $00
S_CMDS_OK       .DB "OK", $00

S_COLON         .DB ":", $00
S_COMMA         .DB ",", $00
S_PIPE          .DB "|", $00
S_DOT           .DB ".", $00
S_SPACE         .DB " ", $00

S_DEBUG         .DB "DUMP $0270",$00

;------------- CMD STRING PATTERNS ---------------

S_CMDP_PEEK     .DB "PEEK $????",$00
S_CMDP_POKE     .DB "POKE $????:$??", $00
S_CMDP_JMPR     .DB "JMPR $????",$00
S_CMDP_DUMP     .DB "DUMP $????",$00

;------------- CMD STRING OUTPUTS ----------------

S_CMDS_BADC     .DB "Bad Command", $00
S_CMDS_BADM     .DB "Bad Memory Address", $00
S_CMDS_VALE     .DB "Value -> $", $00

;-------------MACROS------------------------------
M_DANI_PROC_CMD: .MACRO cmd                ; Command To Process
    M_PTR_STORE cmd, V_DANIVAR1
    JSR DANI_PROC_CMD    
    .ENDM
;-----------EO-MACROS-----------------------------

;----------DANI-CMD-PROGRAM---------------------------------------------------------------------------------------

;----------DANI-CMD-MAIN--------------------------
;-- Parameters - VOID
;-------------------------------------------------
DANI_CMD_MAIN:
    ; -- Main Dani Commander - Maybe we port Basic over eventually
    M_SET_CURSOR 4, 0                            ; Set Cursor to Row 4
    M_PRINT_STR S_DANI_OS                        ; Print String
    M_SET_CURSOR 5, 0                            ; Set Cursor to Row 5
    M_PRINT_STR S_Ready                          ; Print out Ready String
    M_SET_CURSOR 7, 0                            ; Set Cursor to Row 7
    M_CUR_BLINK_ON                               ; Turn Cursor Blinker On
.loop
    ; Input String routine here
    M_PRINT_STR S_CMDS                           ; Print out Command Line String
    JSR SYS_GETSTR                               ; Get String - String in V_INPUTBUFFER
    ;M_STR_COPY S_DEBUG, V_INPUTBUFFER           ; DEBUG
    M_STR_TOUPPER V_INPUTBUFFER, V_DANICMDBUFFER ; Turn Input Buffer to Caps and Place in DANICMDBUFFER
    M_DANI_PROC_CMD V_DANICMDBUFFER              ; Process the Command
    JMP .loop
    JMP HALT

;----------DANI-PROC_CMD--------------------------
;-- Process Commands
;-- Parameters - V_DANIVAR1 2Bytes - String Loc of CMD
;-------------------------------------------------
DANI_PROC_CMD:
    PHA
    ; Here we will check for each command - If we dont find a command we will print out Error
    M_STR_PATTERNMATCH V_DANIVAR1, S_CMDP_PEEK
    BCS .peek             ; Found a Peek Command in Buffer
    M_STR_PATTERNMATCH V_DANIVAR1, S_CMDP_POKE
    BCS .poke             ; Found a Poke Command in Buffer
    M_STR_PATTERNMATCH V_DANIVAR1, S_CMDP_JMPR
    BCS .jmpr             ; Found a Poke Command in Buffer
    M_STR_PATTERNMATCH V_DANIVAR1, S_CMDP_DUMP
    BCS .dump             ; Found a Dump Command in Buffer
    JMP .badc             ; Didn't match any commands, must be a bad one
.badc
    M_PRINT_STR S_CMDS_BADC
    JSR DVGA_CUR_CR
    JMP .done
.peek
    JSR DANI_PEEK_CMD     ; V_INPUTBUFFER should contain command, run it
    JMP .done
.poke
    JSR DANI_POKE_CMD
    JMP .done
.jmpr
    JSR DANI_JMPR_CMD
    JMP .done
.dump
    JSR DANI_DUMP_CMD
    JMP .done
.done
    PLA
    RTS

;----------DANI-DUMP_CMD--------------------------
;-- Executes the DUMP Command
;-- Parameters - V_DANIVAR1 - 2Bytes - String Loc of CMD
;-------------------------------------------------
DANI_DUMP_CMD:
    PHA
    PHX
    PHY
    LDX #$06               ; 6 Bytes passed beginning of DUMP $
    LDY #$01               ; Store LSB first
.strt
    ; Grab First Byte
    M_PTR_COPY V_DANIVAR1, V_SYSVAR1  ; Copy the Pointer of CMD to SYSVAR1
    TXA                    ; Xfer how much we need to move ahead to A
    CLC
    ADC V_SYSVAR1          ; Add that amount to starting point of string
    STA V_SYSVAR1          ; Save the new position
    LDA #V_DANIVAR2        ; Load our Byte Holder Pointer
    STA V_DANIVAR3         ; Store it in Var3
    TYA                    ; Transfer what position we are in Data Hold Ptr to A
    CLC
    ADC V_DANIVAR3         ; Add that to our Pointer Holder
    STA V_SYSVAR2          ; Store that into Sys Var2 for Byte_FROMSTR call
    LDA #$00               ; It's a ZP address
    STA V_SYSVAR2+1        ; Save that to the GSB of Var2
    JSR SYS_BYTE_FROMSTR   ; Call it and store it
    BCS .err               ; If Carry flag set it's an error
    CPY #$00               ; Lets check if Y=0 and that means we got all the bytes
    BEQ .output            ; We got all the bytes, branch to output
    DEY                    ; Decrease Y by one and get next Byte
    INX
    INX                    ; Move string index forward by two characters
    JMP .strt              ; Grab Next Byte
.err
    M_PRINT_STR S_CMDS_BADM; error decoding what the mem address was
    JSR DVGA_CUR_CR        ; Skip Line
    JMP .done
.output
    ; DANIVAR2 has the Memory Location we would like to Dump From
    M_PTR_COPY V_DANIVAR2, V_DANIVAR1
    LDX #$00
.outAgain
    M_PTR_TOSTACK V_DANIVAR1     ; Store this on the stack so we dont loose it      
    JSR DANI_GENDUMPSTR          ; Dump String will be in V_DANICHARBUFFER
    M_PRINT_STR V_DANICHARBUFFER ; Print to String
    M_PTR_FROMSTACK V_DANIVAR1   ; Get the Pointer off Stack
    M_SYS_ADD_16BIT 8,V_DANIVAR1 ; Add 8 to pointer data location  
    INX                          ; Increase X
    CPX #$10                     ; Are we at 16 yet?
    BNE .outAgain
    JMP .done
.done
    PLY
    PLX
    PLA
    RTS

;----------DANI_GENDUMPSTR--------------------------
;-- Generates a Dump Str of 40 characters
;-- Parameters - V_DANIVAR1 - 2Bytes - Pointer of start of data
;-- Out - V_DANICHARBUFFER holds dump string
;-------------------------------------------------
DANI_GENDUMPSTR:
    PHA
    PHY
    M_SYS_FILLMEMORY V_DANICHARBUFFER, 41, $00       ; Blank out the first 41 of the string Buffer and start building
    ; First lay down the GSB Memory address
    M_STR_FROMBYTE V_DANIVAR1+1
    M_STR_COPY V_CCHARBUFFER, V_DANICHARBUFFER       ; Copy that into our character Buffer
    ; Lay down the LSB Memory Address
    M_STR_FROMBYTE V_DANIVAR1                        ; Get LSB String
    M_SYS_STR_APPEND V_DANICHARBUFFER, V_CCHARBUFFER ; Append it
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_COLON       ; Add Colon
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_SPACE       ; Add Space
    LDY #$00                                         ; Set Y to 0
.continueBytes
    LDA (V_DANIVAR1)                                 ; Load the Byte
    STA V_DANIVAR2                                   ; Store it in Var2
    M_STR_FROMBYTE V_DANIVAR2                        ; Create String From Byte
    M_SYS_STR_APPEND V_DANICHARBUFFER, V_CCHARBUFFER ; Append it
    M_SYS_ADD_16BIT 1, V_DANIVAR1                    ; Add one to mem location
    INY
    CPY #$08                                         ; Check if we have been through 8
    BEQ .doneWithBytes
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_COMMA       ; Add a Comma
    JMP .continueBytes
.doneWithBytes
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_SPACE       ; Add Space
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_PIPE        ; Add a Pipe
    M_SYS_SUB_16BIT 8, V_DANIVAR1                    ; Back it up 8 Bytes
    LDY #$00                                         ; Set Y to 0
.contWithChars
    LDA (V_DANIVAR1)
    BEQ .turnIntoPeriod                              ; The byte is 00, we need to turn this into a period
.backToChar
    STA V_DANIVAR3                                   ; Temp Storage for new Character                                    
    LDA #$00
    STA V_DANIVAR3+1                                 ; Make it a string Null Term
    M_SYS_STR_APPEND V_DANICHARBUFFER, V_DANIVAR3    ; Append it to String
    M_SYS_ADD_16BIT 1, V_DANIVAR1                    ; Add one to mem location
    INY
    CPY #$08
    BNE .contWithChars                               ; Are we at 8 bytes yet? if not cont again
    M_SYS_STR_APPEND V_DANICHARBUFFER, S_PIPE        ; Add a Pipe
    JMP .eoDaniDumpStr                               ; Jump to End of Method
.turnIntoPeriod
    LDA S_DOT                                        ; Replace the 00 with a '.'
    JMP .backToChar                                  ; Go back to Char
.eoDaniDumpStr
    PLY
    PLA
    RTS
    
    
;----------DANI-JMPR_CMD--------------------------
;-- Executes the Jump and Return Command
;-- Parameters - V_DANIVAR1 - 2Bytes - String Loc of CMD
;-------------------------------------------------
DANI_JMPR_CMD:
    PHA
    PHX
    PHY
    LDX #$06               ; 6 Bytes passed beginning of JUMP $
    LDY #$01               ; Store LSB first
.strt
    ; Grab First Memory Byte
    M_PTR_COPY V_DANIVAR1, V_SYSVAR1
    TXA                    ; Xfer Move ahead to A
    CLC
    ADC V_SYSVAR1          ; Add Move ahead in string amount
    STA V_SYSVAR1          ; Set the Increased Index 
    LDA #V_DANIVAR2        ; Set our Variable of V_DANIVAR2 to hold Byte
    STA V_DANIVAR3         ; Store our Increased +$50
    TYA                    ; XFer our increase amount to A
    CLC 
    ADC V_DANIVAR3         ; Incrase our Save Point By what was in Y
    STA V_SYSVAR2          ; Store that in our Mem location should start as $51 then go to $50
    LDA #$00               ; Set this to ZP
    STA V_SYSVAR2+1                
    JSR SYS_BYTE_FROMSTR   ; Store Value in $51 LSB
    BCS .err               ; Do we have an error in Mem Address?
    CPY #$00               ; Did we hit Y = 0 meaning we got the full mem location?
    BEQ .output            ; If so go get the value and output it
    DEY                    ; Decrase Y so we now store the LSB
    INX                    ; Move index for string ahead by 2
    INX
    JMP .strt              ; go back to start and get next byte
.err
    M_PRINT_STR S_CMDS_BADM; error decoding what the mem address was
    JSR DVGA_CUR_CR        ; Skip Line
    JMP .done
.output
    ; The Memory location should be at V_DANIVAR2 of what we need to jump
    LDA #>[.done - 1]
    PHA
    LDA #<[.done - 1]
    PHA
    JMP (V_DANIVAR2)
.done
    PLY
    PLX
    PLA
    RTS

;----------DANI-POKE_CMD--------------------------
;-- Executes the Poke Command
;-- Parameters - V_DANIVAR1 - 2Bytes - String Loc of CMD
;-------------------------------------------------
DANI_POKE_CMD:
    PHA
    PHX
    PHY
    LDX #$06               ; 6 Bytes passed beginning of POKE
    LDY #$02               ; We will store LSB in V_DANIVAR3 + Y
.strt
    ; Grab the First Memory Byte
    M_PTR_COPY V_DANIVAR1, V_SYSVAR1
    TXA 
    CLC
    ADC V_SYSVAR1          ; Add X to StrPointer
    STA V_SYSVAR1          ; Store the new start of pointer
    LDA #V_DANIVAR2        ; Set our Variable to V_DANIVAR2 to hold Byte (Needs to hold 3 Total Bytes, Starting at V_DANIVAR2 + 3)
    STA V_DANIVAR4         ; Store our Variable pointer in V_DANIVAR4
    TYA
    CLC
    ADC V_DANIVAR4         ; Increase our Pointer in V_DANIVAR4 to the first spot
    STA V_SYSVAR2          ; Store that in our Mem Location To Extract String
    LDA #$00
    STA V_SYSVAR2+1
    JSR SYS_BYTE_FROMSTR   ; Store First Byte of Mem Location to V_SYSVAR2
    BCS .err
    CPY #$00               ; Did we just finish getting last mem Byte?
    BEQ .output            ; We Did Go Do Output
    DEY                    ; Move to Next Byte
.jump2
    INX                    ; Move X ahead two
    INX                    ; finished
    CPX #$0A               ; Are we at 10 Move it up by two Characters again
    BEQ .jump2
    JMP .strt
.err
    M_PRINT_STR S_CMDS_BADM; error decoding what the mem address was
    JSR DVGA_CUR_CR        ; Skip Line
    JMP .done
.output
    LDA V_DANIVAR2
    STA (V_DANIVAR2+1)     ; We basically use V_DANIVAR2 as 3 Bytes, thus why we cannot store anything inside V_DANIVAR3
    M_PRINT_STR S_CMDS_OK
    JSR DVGA_CUR_CR        ; Skip Line
.done
    PLA
    PLX
    PLY
    RTS

;----------DANI-PEEK_CMD--------------------------
;-- Executes the Peek Command
;-- Parameters - V_DANIVAR1 - 2Bytes - String Loc of CMD
;-------------------------------------------------
DANI_PEEK_CMD:
    PHA
    PHX
    PHY
    LDX #$06               ; 6 Bytes passed beginning of PEEK $
    LDY #$01               ; Store LSB first in $51
.strt
    ; Grab First Memory Byte
    M_PTR_COPY V_DANIVAR1, V_SYSVAR1
    TXA                    ; Xfer Move ahead to A
    CLC
    ADC V_SYSVAR1          ; Add Move ahead in string amount
    STA V_SYSVAR1          ; Set the Increased Index 
    LDA #V_DANIVAR2        ; Set our Variable of $50 to hold Byte
    STA V_DANIVAR3         ; Store our Increased +$50
    TYA                    ; XFer our increase amount to A
    CLC 
    ADC V_DANIVAR3         ; Incrase our Save Point By what was in Y
    STA V_SYSVAR2          ; Store that in our Mem location should start as $51 then go to $50
    LDA #$00               ; Set this to ZP
    STA V_SYSVAR2+1                
    JSR SYS_BYTE_FROMSTR   ; Store Value in $51 LSB
    BCS .err               ; Do we have an error in Mem Address?
    CPY #$00               ; Did we hit Y = 0 meaning we got the full mem location?
    BEQ .output            ; If so go get the value and output it
    DEY                    ; Decrase Y so we now store the LSB
    INX                    ; Move index for string ahead by 2
    INX
    JMP .strt              ; go back to start and get next byte
.err
    M_PRINT_STR S_CMDS_BADM
    JSR DVGA_CUR_CR        ; Skip Line
    JMP .done
.output
    ; The Memory location should be at $50 of what we need to output
    M_PTR_COPY V_DANIVAR2, V_SYSVAR1
    JSR SYS_STR_FROMBYTE
    M_STR_CONCAT S_CMDS_VALE, V_CCHARBUFFER, V_DANICHARBUFFER ; Create Output By Concatting
    M_PRINT_STR V_DANICHARBUFFER ; Put output out
    JSR DVGA_CUR_CR              ; Skip Line
.done
    PLY
    PLX
    PLA
    RTS
