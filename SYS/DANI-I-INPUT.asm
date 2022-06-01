;-------------------------------------------------
;-------------DANI-I-INPUT------------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
CURSOR_LOC:       .SET $18            ; Cursor Location ZP: $18 - 2bytes - Offset of $8000 always - Ranges from $8000 to $84AF
CURSOR_BLI:       .SET $1A            ; Cursor Blink On or Off
CURSOR_BLI_S:     .SET $1B            ; Current Blink Status
INPUT_CBUF:       .SET $1C            ; Input Buffer
V_INPUTBUFFER:    .SET $200           ; 200-2FF (255 char input buffer)
V_INPUTBUFFER_S:  .SET $1D            ; Input Buffer Current Size
; --- ALL OF ZP $10 -> $1F IS USED BY CRITICAL SYSTEM ---
;-------------EO-EQUATES--------------------------

;-------------MACROS------------------------------
M_CUR_BLINK_ON: .MACRO 
    LDA #$FF 
    STA CURSOR_BLI
    .ENDM

M_CUR_BLINK_OFF: .MACRO
    LDA #$00
    STA CURSOR_BLI
    .ENDM
    
M_SET_CURSOR:    .MACRO row, column        ; Place Cursor on Row and Column
.local = {row * 40} + column + $8000
    M_PTR_STORE .local, CURSOR_LOC
    .ENDM
;-------------EO-MACROS---------------------------

;----------SUB-ROUTINES--------------------------------------------------------------------------------------------

;---------- SYS-GETSTR ---------------------------
;-- Parameters - VOID
;-- Get String from Input
;-- Continually get Characters until an Enter
;-------------------------------------------------
SYS_GETSTR:
    PHA
    PHX
    M_SYS_FILLMEMORY V_INPUTBUFFER, $FF, $00
    LDA #$00
    STA V_INPUTBUFFER_S  ; Set the Input Buffer Size to 0
.getNextChar   
    LDA #$00
    STA INPUT_CBUF       ; Clear the Input Char Buffer
.waitOnInput
    JSR SYS_BLINK_CURSOR ; Blink The Cursor Routine
    LDA INPUT_CBUF       ; Get Input Buffer
    CMP #0
    BEQ .waitOnInput     ; If input is still 00 Go back and Try again
    ; Control Character Branching
    CMP #$0D             ; do we have an enter key?
    BEQ .inputComplete   ; We have a enter input complete
    CMP #$08             ; do we have a backspace?
    BEQ .backspace
    ; This was normal input continue
    JSR DVGA_PUT_CHAR    ; Put the Character on Screen
    LDX V_INPUTBUFFER_S  ; Load Buffer size into X
    STA V_INPUTBUFFER, X ; Store Char in CharBuffer at Size Location
    INX                  ; Increase one in input Buffer size
    STX V_INPUTBUFFER_S  ; Store the New string size
    CPX #$FE             ; Max String Size 254 Chars (Need to leave 1 byte for Null Trunc)
    BEQ .inputComplete   ; If over 254, it's an overflow
    JMP .getNextChar
.inputComplete
    LDA #$00
    STA INPUT_CBUF       ; Clear the Input Char Buffer
    STA (CURSOR_LOC)     ; Turn off the blink
    JSR DVGA_CUR_CR      ; CR
    JMP .done
.backspace
    LDX V_INPUTBUFFER_S  ; Put the Size of the current string in X
    CPX #$00             ; Check to See if the String is Empty (Nothing to Backspace)
    BEQ .getNextChar     ; If it is ignore it and just get the next character
    LDA #$00             ; Turn off the Blink
    STA (CURSOR_LOC)
    DEX                  ; Reduce String Size By One
    LDA #$00             ; Load Null into Accum
    STA V_INPUTBUFFER, X ; Null out last Spot in string
    STX V_INPUTBUFFER_S  ; Store the New String Size
    JSR DVGA_DEC_CUR     ; Decrease The Character
    JSR DVGA_PUT_CHAR    ; Put a Blank on Screen clearing out last Character
    JSR DVGA_DEC_CUR     ; Decrease the Character once more
    JMP .getNextChar
.done
    PLX
    PLA
    RTS

;---------- SYS-BLINK_CURSOR ---------------------
;-- Parameters - VOID
;-- Blink The Cursor
;-------------------------------------------------
SYS_BLINK_CURSOR:
    PHA
    LDA #$FF       ; Check to see
    CMP CURSOR_BLI ; If Blink Cursor is on
    BNE .done      ; If it's not on done blink the cursor
    ; It's On lets blink the cursor
    LDA TIMER_COUNT
    CMP #$0F         ; Blink Speed
    BCS .blinkAction ; its greater than or equal to 64
    JMP .done        ; it's not finish up here
.blinkAction
    LDA CURSOR_BLI_S
    CMP #$01         ; Check to see if the last blink was on
    BEQ .shutOffBlink; Shut off the blink
    LDA #$8C         ; Turn on the blink
    STA (CURSOR_LOC)
    LDA #$01
    STA CURSOR_BLI_S ; Save the Blink Status
    JMP .blinkDone
.shutOffBlink
    LDA #$00         ; Turn off the Blink
    STA (CURSOR_LOC)
    STA CURSOR_BLI_S ; Save the Blink Status
.blinkDone
    LDA #$00
    STA TIMER_COUNT  ; Reset Timer Counter
.done
    PLA
    RTS