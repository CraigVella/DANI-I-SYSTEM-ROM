;-------------------------------------------------
;-------------DANI-I-MATH-------------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
V_MATHVAR1:       .SET $20            ; Math Variable 1
V_MATHVAR2:       .SET $22            ; Math Variable 2
V_MATHVAR3:       .SET $24            ; Math Variable 3
V_MATHVAR4:       .SET $26            ; Math Variable 4
;-------------------------------------------------

;-------------MACROS------------------------------
M_SYS_SUB_16BIT: .MACRO amt, val
     LDA #amt
     STA V_MATHVAR1
     M_PTR_STORE val, V_MATHVAR2
     JSR SYS_SUB_16BIT
    .ENDM
    
M_SYS_ADD_16BIT: .MACRO amt, val
     LDA #amt
     STA V_MATHVAR1
     M_PTR_STORE val, V_MATHVAR2
     JSR SYS_ADD_16BIT
    .ENDM
;-------------EO-MACROS---------------------------

;--------------------MATH-SUBROUTINES------------------------------------

;----------Safe 16 Bit Addition -----------------
;-- Adds amount from a two byte number pointed to V_MATHVAR2 Safely
;-- Parameters - V_MATHVAR1 = Amount to add by (8 bit)
;-- Parameters - V_MATHVAR2 = Ptr to 2 byte to add
;-------------------------------------------------
SYS_ADD_16BIT:
    PHA
    LDA (V_MATHVAR2)      ; Load amount to Add
    CLC                   ; Clear Carry
    ADC V_MATHVAR1        ; Add Amount
    STA (V_MATHVAR2)      ; Save Back
    BCC .done             ; No Carry where done here
    INC V_MATHVAR2        ; Increase Pointer to Hi Byte
    BNE .noHiInc          ; Did it wrap?
    INC V_MATHVAR2+1      ; Inc Hi
.noHiInc
    LDA (V_MATHVAR2)      ; Load Hi For Carry
    INA
    STA (V_MATHVAR2)      ; Store New Hi Byte
.done     
    PLA
    RTS


;----------Safe 16 Bit Subtraction -----------------
;-- Deducts amount from a two byte number pointed to V_MATHVAR2 Safely
;-- Parameters - V_MATHVAR1 = Amount to Dec V_MATHVAR2 by (8 bit)
;-- Parameters - V_MATHVAR2 = Ptr to 2 byte to val Deduct
;-------------------------------------------------
SYS_SUB_16BIT:
    PHA
    LDA (V_MATHVAR2)      ; Load amount to Deduct
    SEC                   ; Set Carry
    SBC V_MATHVAR1        ; Deduct at V_SYSVAR2
    STA (V_MATHVAR2)      ; Save back value to V_SYSVAR2
    BCC .deductGSB        ; Jump to deduct hibyte if set
    JMP .done
.deductGSB
    INC V_MATHVAR2
    BNE .skipHiInc        ; Did the Pointer Lowbyte just Wrap?
    INC V_MATHVAR2+1      ; it wrapped inc hi byte
.skipHiInc
    LDA (V_MATHVAR2)
    DEA      
    STA (V_MATHVAR2)
.done
    PLA
    RTS
    
;------------SYS Divide 16bit by 8bit--------------------------------------
;-- Parameters - V_MATHVAR1 16-bit Numerator   (ZP25 High Order, ZP24 Low Order)
;-- Parameters - V_MATHVAR2 8-bit  Denominator
;-- Return     - V_MATHVAR1 8-bit  Quotient
;-- Return     - V_MATHVAR2 8-bit  Remainder  
;--------------------------------------------------------------------------
SYS_DIV_16BIT:
    PHA
    PHX
    LDA V_MATHVAR1+1
    LDX #8
    ASL V_MATHVAR1
.l1 
    ROL
    BCS .l2
    CMP V_MATHVAR2
    BCC .l3
.l2  
    SBC V_MATHVAR2
    SEC
.l3  
    ROL V_MATHVAR1
    DEX
    BNE .l1
    STA V_MATHVAR2
    PLX
    PLA
    RTS
    
;------------SYS Divide 8bit by 8bit--------------------------------------
;-- Parameters - V_MATHVAR1 8-bit  Numerator  
;-- Parameters - V_MATHVAR2 8-bit  Denominator
;-- Return     - V_MATHVAR1 8-bit  Quotient
;-- Return     - V_MATHVAR2 8-bit  Remainder  
;--------------------------------------------------------------------------
SYS_DIV_8BIT:
   PHA
   PHX
   LDA #0
   LDX #8
   ASL V_MATHVAR1
.l1 
   ROL
   CMP V_MATHVAR2
   BCC .l2
   SBC V_MATHVAR2
.l2 
   ROL V_MATHVAR1
   DEX
   BNE .l1
   STA V_MATHVAR2
   PLX
   PLA
   RTS
 
;------------SYS Multiply 8bit by 8bit-------------------------------------
;-- Parameters - V_MATHVAR1 8-bit  Integer  
;-- Parameters - V_MATHVAR2 8-bit  Integer
;-- Return     - V_MATHVAR2 8-bit  Product  
;--------------------------------------------------------------------------
SYS_MULT_8BIT:
   PHA
   PHX
   LDX #8
.l1
   ASL
   ASL V_MATHVAR1
   BCC .l1
   CLC
   ADC V_MATHVAR2
.l2
   DEX
   BNE .l2
   STA V_MATHVAR2
   PLX
   PLA
   RTS
   
;------------SYS Multiply 8bit by 8bit - 16bit Product --------------------
;-- Parameters - V_MATHVAR1 8-bit  Integer  
;-- Parameters - V_MATHVAR2 8-bit  Integer
;-- Return     - V_MATHVAR2 16bit Product
;--------------------------------------------------------------------------
SYS_MULT_16BIT:
   PHA
   PHX
   LDA #0
   LDX #8
   LSR V_MATHVAR2
.l1
   BCC .l2
   CLC
   ADC V_MATHVAR1
.l2
   ROR
   ROR V_MATHVAR2
   DEX
   BNE .l1
   STA V_MATHVAR2+1
   PLX
   PLA
   RTS
