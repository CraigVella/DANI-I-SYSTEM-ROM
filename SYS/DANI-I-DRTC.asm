;-------------------------------------------------
;-------------DANI-I-RTC-DRIVE--------------------
;-------------------------------------------------

;-------------EQUATES-----------------------------
V_DRTCVAR1:	          .SET       $28
V_DRTCVAR2:	          .SET       $2A
V_DRTCVAR3:	          .SET       $2C
V_DRTC_ARGLEN:	          .SET       $2E

DRTC_DATAPORT:            .SET       $9001     ; PA1

DRTC_CMD_RTC_ASCII:       .SET       @10000000 ; RTC Command (bit 7) Command 0 (bit 6-3) ArgsLen (bits 2-0)
DRTC_CMD_RTC_GETCLK:      .SET       @10001000 ; 
DRTC_CMD_RTC_SETCLK:      .SET       @11000001 ; SET CLOCK w/1 ARGUMENT OF BUFFER SIZE

DRTC_CMD_DRV_GET_DIR:     .SET       @00000000 ; GET DIR
DRTC_CMD_DRV_LOAD_FILE:   .SET       @01000001 ; Load File w/1 Argument - File Name
DRTC_CMD_DRV_SAVE_FILE:   .SET       @00100011 ; Save File w/3 Arguments - File Size(2b), File Name(1b)

DRV_NO_DISK               .DB        "No Disk Present", $00
DRV_NO_FILE               .DB        "No File Found By Name", $00
DRV_LOADING               .DB        "Loading...", $00
DRV_SAVING                .DB        "Saving...", $00
DRV_DONE                  .DB        "DONE", $00

DEBUG_SENDDATA_WAIT       .DB        "SENDDATA-WAIT ", $00
DEBUG_SENDDATA_ACK        .DB        "SENDDATA-ACK ", $00
;DEBUG_RECIEVE_WAIT        .DB        "RECIEVE-WAIT ", $00
;DEBUG_RECIEVE_ACK         .DB        "RECIEVE-ACK ", $00

;-------------MACROS------------------------------

;-------------Commands----------------------------
M_DRTC_GET_ASCII_CLOCK: .MACRO dst
    M_PTR_STORE dst, V_DRTCVAR1
    JSR DRTC_GET_ASCII_CLOCK
    .ENDM
    
M_DRTC_GET_CLK: .MACRO dst
    M_PTR_STORE dst, V_DRTCVAR1
    JSR DRTC_GET_CLK
    .ENDM

M_DRTC_GET_DIR: .MACRO dst
    M_PTR_STORE dst, V_DRTCVAR1
    JSR DRTC_GET_DIR
    .ENDM

M_DRTC_LOAD_FILE: .MACRO fileString, memStart
    M_PTR_STORE fileString, V_DRTCVAR1
    M_PTR_COPY  memStart, V_DRTCVAR2
    JSR DRTC_LOAD_FILE
    .ENDM

M_DRTC_SAVE_FILE: .MACRO fileString, memStart, len
    M_PTR_STORE fileString, V_DRTCVAR1
    M_PTR_COPY  memStart, V_DRTCVAR2
    M_PTR_COPY  len, V_DRTCVAR3
    JSR DRTC_SAVE_FILE
    .ENDM
    
;-------------Helpers-----------------------------
M_DRTC_SET_OUT:   .MACRO  ; Set the Drive to OUTPUT MODE
    LDA #$FF
    STA VIA+$03
    .ENDM

M_DRTC_SET_RECV:  .MACRO  ; Set the Drive to RECV Mode
    LDA #$00
    STA VIA+$03
    .ENDM

M_DRTC_CLEAR_CA1:       .MACRO
    LDA #@00000010          ; Clear IFR CA1
    STA VIA+$0D             ;
    .ENDM

M_DRTC_WAIT_FOR_DATA:   .MACRO
 .IF DEBUG == 0
    LDA #@00000010
.loop
    BIT VIA+$0D
    BEQ .loop
 .ENDIF
    .ENDM
    
M_DRTC_SENDDATA:        .MACRO data
    LDA #data
    JSR DRTC_SENDDATA
    .ENDM

M_DRTC_CLEARARGLEN:     .MACRO
    LDA #$00
    STA V_DRTC_ARGLEN
    STA V_DRTC_ARGLEN+1
    .ENDM
    
;---------- DRTC_SAVE_FILE ----------------------
;-- Parameters - 
;-- V_DRTCVAR1 = Pointer to null Terminated File String
;-- V_DRTCVAR2 = Pointer to Memory Starting Location
;-- V_DRTCVAR3 = 16bit Len
;-- Save file by name, starting at memory location for 16bit len
;-------------------------------------------------
DRTC_SAVE_FILE:
    M_DRTC_SENDDATA DRTC_CMD_DRV_SAVE_FILE      ; Send Save File Command,3 Args (SizeToWrite-2B, FileNameSize-1B)
    M_DRTC_CLEARARGLEN				; Clear Arg Len
    LDA V_DRTCVAR3                              ; LB Len
    JSR DRTC_SENDDATA                           ; LB Sent
    LDA V_DRTCVAR3+1                            ; HB Len
    JSR DRTC_SENDDATA                           ; HB Sent
    M_PTR_COPY V_DRTCVAR1, V_SYSVAR1        	; Cpy Pointer for Str len Command
    JSR SYS_STR_LEN				; String Len in V_SYSVAR2
    INC V_SYSVAR2                               ; Increase by 1 for NUL Terminator
    LDA V_SYSVAR2                               ; Right Size for String Len
    JSR DRTC_SENDDATA				; Send String Len as Argument
    M_PRINT_STR DRV_SAVING                      ; Saving...
    ; Now Send Filename String
    LDA V_SYSVAR2				; Load Up Str Len				; 
    STA V_DRTC_ARGLEN                           ; ARGLEN
    JSR DRTC_BUFFER_TO_STREAM                   ; Send Buffer To Stream (File Name, Len of Buffer = StrLen In ArgLen)
    M_PTR_COPY V_DRTCVAR2, V_DRTCVAR1           ; Set Pointer to read to Memory of what to save
    M_PTR_COPY V_DRTCVAR3, V_DRTC_ARGLEN        ; Set Len into Arg Len
    JSR DRTC_BUFFER_TO_STREAM                   ; Send Memory To Stream
    M_PRINT_STR DRV_DONE         		; Done
    JSR DVGA_CUR_CR
    RTS

;---------- DRTC_LOAD_FILE ----------------------
;-- Parameters - 
;-- V_DRTCVAR1 = Pointer to null Terminated File String
;-- V_DRTCVAR2 = Pointer to Memory Starting Location
;-- Load File into Memory Starting Location
;-------------------------------------------------
DRTC_LOAD_FILE:
    M_DRTC_SENDDATA DRTC_CMD_DRV_LOAD_FILE 	; Load File
    M_DRTC_CLEARARGLEN				; Clear Arg Len
    M_PTR_COPY V_DRTCVAR1, V_SYSVAR1        	; Cpy Pointer for Str len Command
    JSR SYS_STR_LEN				; String Len in V_SYSVAR2
    INC V_SYSVAR2                               ; Increase by 1 for NUL Terminator
    LDA V_SYSVAR2                               ; Send
    JSR DRTC_SENDDATA				; Send String Len as Argument
    LDA V_SYSVAR2				; 
    STA V_DRTC_ARGLEN                           ; ARGLEN
    JSR DRTC_BUFFER_TO_STREAM                   ; Send Buffer To Stream (File Name, Len of Buffer = StrLen In ArgLen)
    JSR DRTC_RECVPACKETLEN              	; Recieve Packet Len - AKA File Size
    LDA V_DRTC_ARGLEN                    	; Check if Zero
    BNE .getData
    LDA V_DRTC_ARGLEN+1
    BNE .getData
    M_PRINT_STR DRV_NO_FILE			; No File Found
    JSR DVGA_CUR_CR				; CR
    JMP .finished
.getData
    M_PRINT_STR DRV_LOADING                     ; Loading...
    M_PTR_COPY V_DRTCVAR2, V_DRTCVAR1
    JSR DRTC_STREAM_TO_BUFFER
    M_PRINT_STR DRV_DONE
    JSR DVGA_CUR_CR
.finished
    RTS

;---------- DRTC_GET_DIR ------------------------
;-- Parameters - 
;-- V_DRTCVAR1 = Pointer to Buffer to hold String
;-- Get Directory Listing
;------------------------------------------------- 
DRTC_GET_DIR:
    M_DRTC_SENDDATA DRTC_CMD_DRV_GET_DIR ; Get the directory
    M_PTR_COPY V_DRTCVAR1,V_DRTCVAR2     ; Save Buffer Start Location
    JSR DRTC_RECVPACKETLEN               ; Recieve Packet Len - Packet Len for Directories is the amount of Null Terminated Strings will be transferred
    LDA V_DRTC_ARGLEN                    ; Check if Zero
    BNE .getData                         
    LDA V_DRTC_ARGLEN+1
    BNE .getData
    M_PRINT_STR DRV_NO_DISK              ; No Disk In Drive
    JSR DVGA_CUR_CR
    JMP .finished
.getData
    M_PTR_COPY V_DRTCVAR2,V_DRTCVAR1     ; Set Buffer Start Location
    JSR DRTC_RECV_STRING                 ; Recieve String into Buffer
    M_PRINT_STR_I V_DRTCVAR2             ; Print the String - Indirectly accessed
    JSR DVGA_CUR_CR                      ; Move Cursor to next line
    DEC V_DRTC_ARGLEN                    ; Decrement the buffer len
    BNE .keepGoing
    LDA V_DRTC_ARGLEN+1                  ; LB is Zero Check HB
    BEQ .finished                        ; LB and HB are Zero .finished
    DEC V_DRTC_ARGLEN+1                  ; Decrement the High Buffer Byte
.keepGoing
    JMP .getData                         ; Go get the next piece of data
.finished
    RTS

;---------- DRTC_GET_ASCII_CLOCK -----------------
;-- Parameters - 
;-- V_DRTCVAR1 = Pointer to Buffer to hold String
;-- Get ASCII Clock from RTC and put it in a Buffer
;-------------------------------------------------    
DRTC_GET_ASCII_CLOCK:    
    M_DRTC_SENDDATA DRTC_CMD_RTC_ASCII  ; Ascii Clock Command
    JSR DRTC_RECVPACKETLEN              ; Recieve Packet Len
    JSR DRTC_STREAM_TO_BUFFER           ; Put it all into Buffer
    RTS

;---------- DRTC_GET_CLK--------------------------
;-- Parameters - 
;-- V_DRTCVAR1 = Pointer to Buffer to hold Clock Data
;-- Get Bytes of Clock in format of YEAR(2B) MONTH(1B) DAY(1B) DOW(1B) HOUR(1B) MIN(1B) SEC(1B)
;-------------------------------------------------
DRTC_GET_CLK:
    M_DRTC_SENDDATA DRTC_CMD_RTC_GETCLK ; Get CLK Command
    JSR DRTC_RECVPACKETLEN              ; Recieve Packet Len
    JSR DRTC_STREAM_TO_BUFFER           ; Put it all into Buffer
    RTS

;---------- DRTC_SET_CLK-------------------------
;-- Parameters
;-- V_DRTCVAR1 = Pointer to Buffer of Clock Data To Set
;-- Get Bytes of Clock in format of YEAR(2B) MONTH(1B) DAY(1B) DOW(1B) HOUR(1B) MIN(1B) SEC(1B)
;-------------------------------------------------
DRTC_SET_CLK:
    M_DRTC_SENDDATA DRTC_CMD_RTC_SETCLK ; Send the CLK Set Command- it states we have 1 argument on the way (buffer size)
    M_DRTC_SENDDATA 8                   ; Buffer Size of 8
    LDA #$08                            ; Buffer LoByte for ARG LEN
    STA V_DRTC_ARGLEN                   ; 
    LDA #$00                            ; Buffer HiByte for Arg Len
    STA V_DRTC_ARGLEN+1                 ;
    JSR DRTC_BUFFER_TO_STREAM           ;
    RTS
    
;---------- DRTC_RECVPACKETLEN -----------------
;-- Parameters - Void
;-- Recives a 16bit Word of how many packets will be incoming
;-- Stores it into V_DRTC_ARGLEN - LByte + HByte
;-------------------------------------------------
DRTC_RECVPACKETLEN:
    PHA
    M_DRTC_CLEARARGLEN
    M_DRTC_SET_RECV      ; Set Recieve
    ;M_PRINT_STR DEBUG_RECIEVE_WAIT
    M_DRTC_WAIT_FOR_DATA ; Wait for the data to hit 
    LDA DRTC_DATAPORT    ; Load it in, and clear the flag
    STA V_DRTC_ARGLEN    ; It's In
    ;M_PRINT_STR DEBUG_RECIEVE_WAIT
    M_DRTC_WAIT_FOR_DATA ; Wait for data again to hit the port
    LDA DRTC_DATAPORT    ; Same
    STA V_DRTC_ARGLEN+1  ; Hibyte save
    ;M_PRINT_STR DEBUG_RECIEVE_ACK
    M_DRTC_WAIT_FOR_DATA ; Wait for Final ACK for Reset
    M_DRTC_CLEAR_CA1     ; Clear CA1 - Back to start
    PLA
    RTS
    
;---------- DRTC_SENDDATA ------------------------
;-- Parameters - Accum - Data you want sent
;-- Sends a 1 Byte Data Value
;-------------------------------------------------
DRTC_SENDDATA:
   PHA
   M_DRTC_SET_OUT       ; Set DRTC Direction
   PLA                  ; Pulls Data to send off stack
   STA DRTC_DATAPORT    ; Send it on PA1
   ;M_PRINT_STR DEBUG_SENDDATA_WAIT
   M_DRTC_WAIT_FOR_DATA ; Wait for Confirmatiom
   LDA #$00             ; Load NUL for Final ACK
   STA DRTC_DATAPORT    ; Send Final ACK
   ;M_PRINT_STR DEBUG_SENDDATA_ACK
   M_DRTC_WAIT_FOR_DATA ; Wait for Confirmatiom
   M_DRTC_CLEAR_CA1     ; Clear CA1 - Back to start
   RTS
   
;---------- DRTC_RECV_STRING-----------------------
;-- Parameters - 
;-- V_DRTCVAR1    = Pointer to Buffer to stream into
;-- Get Null TerminatedString from RTCDRV and put it in a Buffer
;--------------------------------------------------
DRTC_RECV_STRING:
   M_DRTC_SET_RECV      ; Enter Recieve Mode
.getData
   M_DRTC_WAIT_FOR_DATA ; Wait for data to be present
   LDA DRTC_DATAPORT    ; Load it in & Clear Flag
   STA (V_DRTCVAR1)     ; Store it in Buffer location
   BEQ .finished        ; This was a null Terminator - we are done
   INC V_DRTCVAR1       ; Increase the Low Byte Buffer Pointer
   BNE .skipHBB         ; Did it roll?
   INC V_DRTCVAR1+1     ; Increase the High Byte Buffer Pointer
.skipHBB
   JMP .getData         ; Go Get next Piece of Data
.finished
   M_DRTC_WAIT_FOR_DATA ; Wait for Final ACK for Reset
   M_DRTC_CLEAR_CA1     ; Clear CA1 - Back to start   
   RTS
 
;---------- DRTC_STREAM_TO_BUFFER -----------------
;-- Parameters - 
;-- V_DRTCVAR1    = Pointer to Buffer to stream into
;-- V_DRTC_ARGLEN = Legnth of buffer to stream
;-- Get Data from RTCDRV and put it in a Buffer
;--------------------------------------------------
DRTC_STREAM_TO_BUFFER:
   M_DRTC_SET_RECV      ; Enter Recieve Mode
.getData
   M_DRTC_WAIT_FOR_DATA ; Wait for data to be present
   LDA DRTC_DATAPORT    ; Load it in & Clear Flag
   STA (V_DRTCVAR1)     ; Store it in Buffer location
   INC V_DRTCVAR1       ; Increase the Low Byte Buffer Pointer
   BNE .skipHBB         ; Did it roll?
   INC V_DRTCVAR1+1     ; Increase the High Byte Buffer Pointer
.skipHBB
   LDA V_DRTC_ARGLEN
   BNE .dec
   LDA V_DRTC_ARGLEN+1
   BNE .dec
   JMP .finished
.dec
   DEC V_DRTC_ARGLEN    ; Decrement the buffer len
   BNE .keepGoing
   LDA V_DRTC_ARGLEN+1  ; LB is Zero Check HB
   BEQ .finished        ; LB and HB are Zero .finished
.keepGoing
   LDA #$FF             ; We need to see if LB rolled
   CMP V_DRTC_ARGLEN    ; 
   BNE .getData         ; We didn't roll go to next piece of data
   DEC V_DRTC_ARGLEN+1  ; Dec the HB
   JMP .getData         ; Go get the next piece of data
.finished
   M_DRTC_WAIT_FOR_DATA ; Wait for Final ACK for Reset
   M_DRTC_CLEAR_CA1     ; Clear CA1 - Back to start
   RTS  
   
;---------- DRTC_BUFFER_TO_STREAM------------------
;-- Parameters - 
;-- V_DRTCVAR1    = Pointer to Buffer to stream from
;-- V_DRTC_ARGLEN = Legnth of buffer to stream
;-- Send Data from Buffer to RTCDRV
;--------------------------------------------------
DRTC_BUFFER_TO_STREAM:
   M_DRTC_SET_OUT       ; Set Send Mode
.sendData
   LDA (V_DRTCVAR1)     ; Load Data from Buffer
   STA DRTC_DATAPORT    ; Send it
   M_DRTC_WAIT_FOR_DATA ; Wait for Confirmation
   INC V_DRTCVAR1       ; Increase the Low Byte Buffer Pointer
   BNE .skipHBB         ; Did it roll?
   INC V_DRTCVAR1+1     ; Increase the High Byte Buffer Pointer
.skipHBB
   LDA V_DRTC_ARGLEN
   BNE .dec
   LDA V_DRTC_ARGLEN+1
   BNE .dec
   JMP .finished
.dec
   DEC V_DRTC_ARGLEN    ; Decrement the buffer len
   BNE .keepGoing
   LDA V_DRTC_ARGLEN+1  ; LB is Zero Check HB
   BEQ .finished        ; LB and HB are Zero .finished
.keepGoing
   LDA #$FF             ; We need to see if LB rolled
   CMP V_DRTC_ARGLEN    ; 
   BNE .sendData        ; We didn't roll go to next piece of data
   DEC V_DRTC_ARGLEN+1  ; Dec the HB
   JMP .sendData        ; Go get the next piece of data
.finished
   LDA #$00             ; Load NUL for Final ACK
   STA DRTC_DATAPORT    ; Send Final ACK
   M_DRTC_WAIT_FOR_DATA ; Wait for Confirmatiom
   M_DRTC_CLEAR_CA1     ; Clear CA1 - Back to start
   RTS