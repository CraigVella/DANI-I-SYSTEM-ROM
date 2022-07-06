;-------------------------------------------------
;-------------DANI-I-BASIC-BOOTSTRAPPER-----------
;-------------------------------------------------

	.INCLUDE ".\BASIC\EH-BASIC.asm"    ; Include ehBasic
	
STR_FILENAME: .DB "Enter Filename: ", $00
STR_BUFFER:   .SET $0400                   ; This is COMMANDER BUFFER but not in use

DANI_BASIC_BOOT:
	LDY #DANI_LAB_endvec-DANI_LAB_vec ; set index
.loop
	LDA DANI_LAB_vec-1,Y  ; get Byte from vectors
	STA VEC_IN-1,Y        ; save to RAM
	DEY                   ;
	BNE .loop             ; loop if more to do
	CLD                   ; Clear Decimal Mode
	LDX #$FF              ; Initialize the Stack Pointer
    	TXS                   ; Transfer X to Stack 
	JMP LAB_COLD          ; Boot ehBASIC - COLD

DANI_LAB_IN:
	JSR SYS_BLINK_CURSOR  ; Run the Blink Cursor Routine
	LDA INPUT_CBUF        ; Grab whats in Input Buffer
	BEQ .emptyInput	      ; Is it nothing?
	PHA                   ; Push input onto stack Perserve A
	LDA #$00              ; Clear Input
	STA INPUT_CBUF        ; CBUF = 0
	PLA                   ; Put Char into A
	CMP #$1B              ; Check to see if we have an ESC
	BEQ .makeCC           ; Make this a CTRL-C
	JMP .noAlter
.makeCC
	LDA #$03              ; Transform this into a Ctrl-C
.noAlter
	SEC	              ; Set Carry to let Basic know we have a char
	JMP .done
.emptyInput
	CLC                   ; Clear Carry telling basic nothing is here
.done	
	RTS
	
DANI_LAB_OUT:
	CMP #$0D
	BEQ .doCR
	CMP #$0A
	BEQ .ignore
	CMP #$08
	BEQ .doBackspace
	JMP DVGA_PUT_CHAR
.doCR
	PHA 
	LDA #$00                  ; Turn off the Blink
    
	STA (CURSOR_LOC)
	JSR DVGA_CUR_CR
	PLA
	JMP .ignore
.doBackspace
	JMP DANI_LAB_BACKSPACE
.ignore 
	RTS

DANI_LAB_SLGETFILE:
	M_DRTC_GET_DIR STR_BUFFER
	BCS .err
	M_PRINT_STR STR_FILENAME
	JSR SYS_GETSTR
	M_PTR_STORE V_INPUTBUFFER, V_DRTCVAR1
	M_PTR_COPY Smeml, V_DRTCVAR2
	RTS
.err
	PLA
	PLA
	RTS

DANI_LAB_LOAD:
	JSR DANI_LAB_SLGETFILE
	JSR DRTC_LOAD_FILE
	BCS .err
	M_PTR_COPY V_DRTCVAR1, Svarl
	JMP LAB_1319
.err
	RTS
	
DANI_LAB_SAVE:
	JSR DANI_LAB_SLGETFILE
	SEC
	LDA Svarl
	SBC Smeml
	STA V_DRTCVAR3
	LDA Svarh
	SBC Smemh
	STA V_DRTCVAR3+1
	JSR DRTC_SAVE_FILE
	RTS

DANI_LAB_BACKSPACE:
	PHA		     ; Perseve A
	LDA #$00             ; Turn off the Blink
    	STA (CURSOR_LOC)     ; 
    	JSR DVGA_DEC_CUR     ; Dec Cursor
    	JSR DVGA_PUT_CHAR    ; Put a Blank on Screen clearing out last Character
    	JSR DVGA_DEC_CUR     ; Decrease the Character once more
    	PLA                  ; Pull A and set NZ
    	RTS

DANI_LAB_vec
	.WORD DANI_LAB_IN
	.WORD DANI_LAB_OUT
	.WORD DANI_LAB_LOAD
	.WORD DANI_LAB_SAVE 
DANI_LAB_endvec
    	
; ------ DANI BASIC EXTENDED ROUTINES ---------
DANI_BASIC_VAR1: .SET $E2
DANI_BASIC_VAR2: .SET $E4
DANI_BASIC_VAR3: .SET $E6
DANI_BASIC_BUFF: .SET $400  ; 256 Byte Buffer

DANI_BASIC_SET_CURSOR:
	JSR LAB_SCGB	      ; Scan for "," and get byte
	CPX #40               ; Compare to see if larger than 39
	BCS_L LAB_FCER        ; Branch on Carry Set LONG to Function Error
	STX DANI_BASIC_VAR1+1 ; Store X in Var 1 LSB
	JSR LAB_SCGB          ; Scan for "," again
	CPX #30               ; Compare to see if larger than 29
	BCS_L LAB_FCER        ; Branch on Carry Set LONG to Function Error
	STX DANI_BASIC_VAR1   ; Store Y in Var 1 GSB
	; Variables are stored from basic in DBV1Low and DBV1Hi
	; Multiply Width by 40 and add height
	LDA #40               ; 40
	STA V_MATHVAR1        ; into var 1
	LDA DANI_BASIC_VAR1   ; X
	STA V_MATHVAR2        ; into var 2
	JSR SYS_MULT_16BIT    ; Multiply them (16bit)
	M_PTR_COPY V_MATHVAR2, CURSOR_LOC ; Store result in Cursor Locaiton
	LDA DANI_BASIC_VAR1+1 ; Load our Y
	STA V_MATHVAR1        ; Store in Mathvar 1
	M_PTR_STORE CURSOR_LOC, V_MATHVAR2 ; Store pointer of 16 bit number in Mathvar 2
	JSR SYS_ADD_16BIT     ; Safely add the 8 bit number into 16 bit number
	LDA CURSOR_LOC+1      ; Load Hi byte into A
	CLC                   ; Clear Carry
	ADC #$80              ; Add $80 to GSB
	STA CURSOR_LOC+1      ; Store it back - Cursor_loc now has new cursor Loc
	RTS
	
DANI_BASIC_PUT:
	JSR LAB_SCGB	          ; Scan for "," and get byte
	TXA                       ; Move X To A
    	STA (CURSOR_LOC)          ; Store this character into Cursor Location
    	RTS