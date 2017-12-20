;-------------------------------------------------
;-------------DANI-I-SYSTEM-----------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
V_SYSVAR1:        .SET $10            ; System Variable 1
V_SYSVAR2:        .SET $12            ; System Variable 2
V_SYSVAR3:        .SET $14            ; System Variable 3
V_SYSVAR4:        .SET $16            ; System Variable 4
;-------------EO-EQUATES--------------------------

;-------COMMON-MACROS-----------------------------
M_PTR_STORE:     .MACRO var, loc           ; Store a 16bit Pointer
    LDA #<var
    STA loc
    LDA #>var
    STA loc+1
    .ENDM

M_PTR_COPY:      .MACRO src, dst           ; Copy a 16bit Pointer to New Location
    LDA src
    STA dst
    LDA src+1
    STA dst+1
    .ENDM

M_PTR_TOSTACK:   .MACRO src                ; Push a 16bit Pointer to stack
    LDA src
    PHA
    LDA src+1
    PHA
    .ENDM

M_PTR_FROMSTACK: .MACRO dst                ; Pull a 16bit Pointer from stack
    PLA
    STA dst+1
    PLA
    STA dst
    .ENDM
;----EO-COMMON-MACROS-----------------------------

    .INCLUDE ".\SYS\DANI-I-STRINGS.asm"     ; Include the String Subroutines
    .INCLUDE ".\SYS\DANI-I-INPUT.asm"       ; Include the Input System
    .INCLUDE ".\SYS\DANI-I-VGA.asm"         ; Include the Video System
    .INCLUDE ".\SYS\DANI-I-VGA-DEFCHAR.asm" ; Include the Default Character Set