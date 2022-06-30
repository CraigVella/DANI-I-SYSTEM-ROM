;-------------------------------------------------
;-------------DANI-I-RTC-DRIVE--------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------


;-------------MACROS------------------------------
M_DRTC_SET_OUT:   .MACRO  ; Set the Drive to OUTPUT MODE
    LDA #$FF
    STA VIA+$03
    .ENDM

M_DRTC_SET_RECV:  .MACRO  ; Set the Drive to RECV Mode
    LDA #$00
    STA VIA+$03
    .ENDM

STR_DRTC_CALLED .DB "DRTC IRQ Called", 00
    
DRTC_IRQ:       ;  Drive Interrupt Called
	M_PRINT_STR STR_DRTC_CALLED
	LDA #@00000010 ; Clear IFR CA1
	STA VIA+$0D
	RTS