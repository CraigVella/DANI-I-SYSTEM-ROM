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

DRV_NO_DISK               .DB        "No Disk Present",00

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
    LDA #@00000010
.loop
    BIT VIA+$0D
    BEQ .loop
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
    M_DRTC_WAIT_FOR_DATA ; Wait for the data to hit 
    LDA DRTC_DATAPORT    ; Load it in, and clear the flag
    STA V_DRTC_ARGLEN    ; It's In
    M_DRTC_WAIT_FOR_DATA ; Wait for data again to hit the port
    LDA DRTC_DATAPORT    ; Same
    STA V_DRTC_ARGLEN+1  ; Hibyte save
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
   M_DRTC_CLEAR_CA1     ; Clear CA1 Just in Case - Shouldn't have to if everyone is nice
   PLA                  ; Pulls Data to send off stack
   STA DRTC_DATAPORT    ; Send it on PA1
   M_DRTC_WAIT_FOR_DATA ; Wait for Confirmatiom
   M_DRTC_CLEAR_CA1     ; Clear CA1 - They Recieved It!
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
   DEC V_DRTC_ARGLEN    ; Decrement the buffer len
   BNE .keepGoing
   LDA V_DRTC_ARGLEN+1  ; LB is Zero Check HB
   BEQ .finished        ; LB and HB are Zero .finished
   DEC V_DRTC_ARGLEN+1  ; Decrement the High Buffer Byte
.keepGoing
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
   DEC V_DRTC_ARGLEN    ; Decrement the buffer len
   BNE .keepGoing
   LDA V_DRTC_ARGLEN+1  ; LB is Zero Check HB
   BEQ .finished        ; LB and HB are Zero .finished
   DEC V_DRTC_ARGLEN+1  ; Decrement the High Buffer Byte
.keepGoing
   JMP .sendData        ; Go get the next piece of data
.finished
   M_DRTC_CLEAR_CA1
   RTS