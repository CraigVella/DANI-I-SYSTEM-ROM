;-------------------------------------------------
;-------------DANI-I-BASIC-BOOTSTRAPPER-----------
;-------------------------------------------------

	.INCLUDE ".\BASIC\EH-BASIC.asm"    ; Include ehBasic

DANI_BASIC_BOOT:
	LDY #LAB_endvec-LAB_vec ; set index
LAB_stlp:
	LDA LAB_vec-1,Y       ; get Byte from vectors
	STA VEC_IN-1,Y        ; save to RAM
	DEY                   ;
	BNE LAB_stlp          ; loop if more to do
	CLD                   ; Clear Decimal Mode
	LDX #$FF              ; Initialize the Stack Pointer
    	TXS                   ; Transfer X to Stack 
	JMP LAB_COLD

DANI_LAB_IN:
	JSR SYS_BLINK_CURSOR  ; Run the Blink Cursor Routine
	LDA INPUT_CBUF        ; Grab whats in Input Buffer
	BEQ .emptyInput	      ; Is it nothing?
	STA $0A               ; Use 0A as an input bfufer
	LDA #$00              ; Clear Input
	STA INPUT_CBUF        ; CBUF = 0
	LDA $0A               ; Put Char into A
	SEC	              ; Set Carry to let Basic know we have a char
	JMP .done
.emptyInput
	CLC                   ; Clear Carry telling basic nothing is here
.done	
	RTS
DANI_LAB_OUT:
	CMP #$0A
	BEQ .ignoreLF
	CMP #$08
	BEQ .backspace
	JMP DVGA_PUT_CHAR
.ignoreLF
	RTS
.backspace
	LDA #$00             ; Turn off the Blink
    	STA (CURSOR_LOC)     ; 
    	JSR DVGA_DEC_CUR     ; Dec Cursor
    	JSR DVGA_PUT_CHAR    ; Put a Blank on Screen clearing out last Character
    	JSR DVGA_DEC_CUR     ; Decrease the Character once more
	RTS
DANI_LAB_LOAD:
DANI_LAB_SAVE:
	RTS
	
LAB_vec
	.WORD DANI_LAB_IN
	.WORD DANI_LAB_OUT
	.WORD DANI_LAB_LOAD
	.WORD DANI_LAB_SAVE 
LAB_endvec