;-------------------------------------------------
;-------------DANI-I-VGA-SYSTEM-------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
VRAM:             .SET $8000
VRAM_CMD:         .SET VRAM + $F00
VRAM_CHARSLOC:    .SET VRAM + $F10
VRAM_CHARSBUF:    .SET VRAM + $F20
VRAM_ZPVAR1:      .SET $02
VRAM_ZPVAR2:      .SET $04
VRAM_ZPVAR3:      .SET $06
VRAM_ZPVAR4:      .SET $08
;-------------EO-EQUATES--------------------------

;--------------MACROS-----------------------------
M_PRINT_STR:     .MACRO string             ; Print a String to screen
    M_PTR_STORE string, V_SYSVAR1
    JSR DVGA_PUTS
    .ENDM
;-------------EO-MACROS---------------------------

;----------SUB-ROUTINES--------------------------------------------------------------------------------------------

;----------DVGA-Load-Default-Characters-----------
;-- Loads Default Characters into Character RAM
;-- Parameters - VOID ----------------------------
;-------------------------------------------------
DVGA_LOADDEFCHARACTERS:
    PHA
    PHX
    M_PTR_STORE {CHAR_ROM+$468-8}, V_SYSVAR3 ; Store starting location in V_SYSVAR3
    LDX #$8C                                 ; Set X counter to 140 (140 chars total)
.loop
    STX V_SYSVAR1                            ; Set Location of this character
    M_PTR_COPY V_SYSVAR3, V_SYSVAR2          ; Copy Start of Character from Var 3 -> 2
    JSR DVGA_STORECHAR                       ; Put Address of Character V_SYSVAR2 and Location you want it stored in V_SYSVAR1
    M_SYS_SUB_16BIT $08, V_SYSVAR3           ; Deduct 8bytes from V_SYSVAR3
    DEX                                      ; deduct 1 from the location
    CPX #$FF                                 ; Did we hit 0 and Roll to FF
    BNE .loop                                ; loop until we hit go through 0 to FF
    PLX
    PLA
    RTS

;----------DVGA Store Character ------------------
;-- Parameters - V_SYSVAR1 = Location that you want to store charater in
;-- Parameters - V_SYSVAR2 = Address of Character
;-------------------------------------------------
DVGA_STORECHAR:              ;-- ptr to Character in ZP 10, stored in LDA, Location is in ZP 20
    PHA			     ; Push A To Stack
    PHY			     ; Push Y To Stack
    LDY #$07                 ; Set up counter - put 7
.loop:                       ; Start of Loop
    LDA (V_SYSVAR2),Y        ; Get StoreChar Byte
    STA VRAM_CHARSBUF,Y      ; Store it in VRAM
    DEY                      ; Decrement Y
    BPL .loop                ; Continue to loop until it wraps
    LDA V_SYSVAR1            ; Load location value
    STA VRAM_CHARSLOC        ; Store it in Vram Char location
    LDA #$01                 ; Set Store Command
    STA VRAM_CMD             ; in the VGA command location
.chkcmd:
    LDA VRAM_CMD             ; Check to see if it was loaded in
    BNE .chkcmd              ; It was? Okay were good
    PLY			     ; Restore Y
    PLA  		     ; Restore A
    RTS                      ; Return from subroutine
 
;----------DVGA Draw Logo ------------------------
;-- Parameters - VOID
;-------------------------------------------------
DVGA_DRAWLOGO:
    PHA
    LDA #$80            ; Draw the DANI-I Logo
    STA VRAM
    LDA #$81            
    STA VRAM+1
    LDA #$82            
    STA VRAM+2
    LDA #$83            
    STA VRAM+3
    LDA #$84            
    STA VRAM+40
    LDA #$85            
    STA VRAM+41
    LDA #$86            
    STA VRAM+42
    LDA #$87            
    STA VRAM+43
    LDA #$88            
    STA VRAM+80
    LDA #$89            
    STA VRAM+81
    LDA #$8A            
    STA VRAM+82
    LDA #$8B            
    STA VRAM+83
    PLA
    RTS
    
;----------DVGA Blank Screen ---------------------
;-- Parameters - VOID
;-------------------------------------------------
DVGA_BLANKSCREEN:
    LDA #<VRAM               ; Load Low Byte of VRAM address
    STA V_SYSVAR1            ; Store it in Zero Page 40
    LDY #$B0                 ; Last page + 1 only partially filled
    LDA #$00                 ; Set Accu To 0 (fill byte)
    LDX #>VRAM+4             ; Init X to last VRAM page number
.loop_outer:
    STX V_SYSVAR1+1    	     ; Store it in Zero Page 41
.loop_inner:
    DEY             	     ; (filling high to low is more efficient)
    STA (V_SYSVAR1),Y  	     ; Store the fill byte
    BNE .loop_inner 	     ; ... down to the bottom of the page
    DEX               	     ; Prepare to fill next-lower page
    CPX #>VRAM       	     ; Is X < VRAM_H?
    BCS .loop_outer 	     ; No: fill the next page
    M_SET_CURSOR 0,0         ; Set Cursor to 0,0
    RTS			     ; Return from Subroutine

;---------DVGA-Put-String--------------------------
;-- Parameters - V_SYSVAR1 - Ptr to String to Put on Scr
;-- Desc: Puts String on Screen at Cursor Location
;--------------------------------------------------
DVGA_PUTS:
    PHA
    PHY                       ; Push Y on stack
    LDY #$00                  ; Set Y To Zero
.loop
    LDA (V_SYSVAR1),Y         ; Load Byte of String
    BEQ .stringDone           ; If this is a NULL character We are done with string
    JSR DVGA_PUT_CHAR         ; Put this Character On Screen
    CLV                       ; Clear Overflow Flag
    INY                       ; Increase Y
    BVS .stringDone           ; Y Overflowed to 00 - String is over 256 Characers, Exit
    JMP .loop
.stringDone
    PLY                       ; Grab Y from Stack
    PLA
    RTS
    
;---------DVGA-Put-Char----------------------------
;-- Parameters - Accum - Char To Print
;-- Desc: Puts Char on Screen at Cursor Location and Increases Cursor Location
;--------------------------------------------------
DVGA_PUT_CHAR:
    STA (CURSOR_LOC)          ; Store this character into Cursor Location
    JSR DVGA_INC_CUR          ; Increase Cursor Location
    RTS

;---------DVGA-Carriage-Return---------------------
;-- Parameters - VOID 
;-- Desc: Increases Character to Next Line
;--------------------------------------------------
DVGA_CUR_CR:
    PHA
    LDA CURSOR_LOC       ; Load Low Byte of Cursor Loc
    STA V_MATHVAR1       ; Store it for Division Low End of 16bit
    LDA CURSOR_LOC+1     ; Load High Byte of Cursor Loc
    SEC                  ; Set Carry For Deduction
    SBC #$80             ; remove 80 from high byte
    STA V_MATHVAR1+1      ; Store it for Division High End of 16bit
    LDA #40              ; 40 Column Row
    STA V_MATHVAR2       ; Store it For Denominator
    JSR SYS_DIV_16BIT    ; ZP24 will now contain the quotient
    INC V_MATHVAR1       ; Up the column by 1
    LDA V_MATHVAR1       ; Load it into A for a compare
    CMP #30              ; Does it equal 30 Rows? If so we are at end of screen
    BEQ .scrollScreen
.setCursorLocation
    ; Multiply Column by 40 to get new cursor location
    LDA #40
    STA V_MATHVAR2
    JSR SYS_MULT_16BIT
    LDA V_MATHVAR2
    STA CURSOR_LOC
    LDA V_MATHVAR2+1
    CLC
    ADC #$80
    STA CURSOR_LOC+1
    JMP .done
.scrollScreen
    JSR DVGA_SCROLL_DOWN  ; Scroll the Screen Down
    DEC V_MATHVAR1        ; Set the Location back by one
    JMP .setCursorLocation
.done
    PLA
    RTS

;---------DVGA-Inc-Cur-----------------------------
;-- Parameters - VOID 
;-- Desc: Increases the Screen Cursor By One
;--------------------------------------------------
DVGA_INC_CUR:
    PHA                       ; Save Accu
    INC CURSOR_LOC            ; Increase Cursor Location
    BEQ .increaseCursorH      ; it wrapped? Incrase our High Byte
.continue
    LDA CURSOR_LOC            ; Load our Cursor Location Low Byte
    CMP #$B0                  ; Is it B0?
    BEQ .checkCursor          ; Check to see if we are at 1200
    JMP .return               ; ok were done
.increaseCursorH
    INC CURSOR_LOC+1          ; increase the hi byte
    JMP .continue             ; go back 
.checkCursor
    LDA CURSOR_LOC+1          ; Load Hi Byte
    CMP #$84                  ; Is it $84 ? if so we are at 1200
    BNE .return               ; not at 1200, we are done here
    ; We are at 1200 - Scroll the screen
    JSR DVGA_SCROLL_DOWN      ; Scroll Screen Down By 1
    LDA #$84                  ; Reset Cursor to last line
    STA CURSOR_LOC+1          
    LDA #$88
    STA CURSOR_LOC
.return
    PLA                       ; Restore Accu
    RTS

;---------DVGA-Dec-Cur-----------------------------
;-- Parameters - VOID 
;-- Desc: Decreases the Screen Cursor By One
;--------------------------------------------------
DVGA_DEC_CUR:
    PHA                       ; Save Accu
    DEC CURSOR_LOC            ; Decrease Cursor Location
    LDA CURSOR_LOC            ; Grab Current Cursor Low Byte
    CMP #$FF                  ; Did It Wrap
    BEQ .decreaseCursorH      ; it wrapped? Decrease our High Byte
    JMP .return
.decreaseCursorH
    LDA CURSOR_LOC+1          ; Check to see if were at lowest possible $80
    CMP #$80                  ; Are we at 80 Already?
    BEQ .returnAndFix         ; we are done decreasing cursor because we are already at beginning of screen, but we have to set low byte to $00
    DEC CURSOR_LOC+1          ; decrease the hi byte
    JMP .return               ; we decreased, we are done 
.returnAndFix
    LDA #$00                  ; Load Zero
    STA CURSOR_LOC            ; Save it at current Cursor Loc - Beggining of Screen
.return
    PLA                       ; Restore Accu
    RTS
    
;---------DVGA-SCROLL-DOWN-------------------------
;-- Parameters - VOID 
;-- Desc: Blanks last row and scrolls screen contents down by 1 column
;--------------------------------------------------
DVGA_SCROLL_DOWN:
    PHA
    PHX
    PHY                ; AXY Stored
    M_PTR_STORE VRAM, VRAM_ZPVAR3
    M_PTR_STORE {VRAM+40}, VRAM_ZPVAR4
    ; Start the Loop of Moving Memory
    LDY #$00           ; Clear Y
    LDX #$00           ; Clear X
    ; Start of Loop for 1160 times (1200 minus 40)
.loop
    ; First see if we are at end of loop 1160?
    CPX #$88           ; X is $88 lets see if Y is $04
    BNE .loopXStart    ; X is not $88 Just continue in Loop
    CPY #$04           ; Check to see if Y is 4?
    BNE .loopXStart    ; Y is not 4? Continue in Loop
    JMP .endLoop       ; Jump to End of Loop 1160 has been reached
.loopXStart
    ; Do Stuff Here
    LDA (VRAM_ZPVAR4)    ; Get Row you will be moving
    STA (VRAM_ZPVAR3)    ; Put it into Row Moving to
    INC  VRAM_ZPVAR3     ; increase moving to row
    BEQ .inc17         ; did it roll over? increase moving to row high byte
.inc18
    INC VRAM_ZPVAR4      ; increase moving from low byte
    BEQ .inc19         ; did it roll over? increase moving from high byte
.doneWork
    ; Increase Our Loop
    INX
    BEQ .increaseY     ; Did X Roll Over to 00 ? If so Inc Y
    JMP .loop
.increaseY
    INY
    JMP .loop          ; Go Back to Loop
.inc17
    INC VRAM_ZPVAR3+1    ; increase moving to hi byte
    JMP .inc18         ; back to increase of memory
.inc19
    INC VRAM_ZPVAR4+1    ; incrase moving from hi byte
    JMP .doneWork      ; go back to done work
.endLoop
    ; Now we have to clear the last row of screen ZP $16 should hold the last row - just need to clear it with 40 blanks
    LDY #$00           ; clear Y
    LDA #$00           ; blank Char
.blankLineLoop
    STA (VRAM_ZPVAR3), Y ; Store Blank in 
    INY                ; Increase Y
    CPY #$28           ; Compare it with 40
    BNE .blankLineLoop ; If It's not 40 yet, loop
    PLY                ; Restore AXY and Return 
    PLX
    PLA
    RTS
