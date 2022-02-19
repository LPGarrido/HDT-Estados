PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  
BMODO	EQU 0
BACCION	EQU 1
  
/*; -------------- MACROS --------------- 
  ; Macro para reiniciar el valor del TMR0
  ; **Recibe el valor a configurar en TMR_VAR**
  RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM 
*/
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
PSECT udata_bank0
    VALOR:		DS 1
    BANDERAS:		DS 1
    NIBBLES:		DS 2
    DISPLAY:		DS 2
    CUENTA:		DS 1

PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	    ; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h			    ; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:
    BTFSC   T0IF	    ; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0	    ; Si -> Subrutina o macro con codigo a ejecutar
			    ;	cuando se active interrupción de TMR0
    
    BTFSC   RBIF	    ; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB	    ; Si -> Subrutina o macro con codigo a ejecutar
			    ;	cuando se active interrupción de PORTB
    
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
    RETFIE		    ; Regresamos a ciclo principal
    
    
PSECT code, delta=2, abs
ORG 100h		    ; posición 100h para el codigo
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO	    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    ; Configuración de TMR0
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    BANKSEL PORTD	    ; Cambio a banco 00
    
LOOP:
    ; Código que se va a estar ejecutando mientras no hayan interrupciones
    MOVF    PORTA,W
    MOVWF   VALOR
    CALL    OBTENER_NIBBLE
    CALL    SET_DISPLAY
    GOTO    LOOP	    
    
;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4	    ; IRCF<2:0> -> 110 4MHz
    RETURN
    
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG	    ; cambiamos de banco
    BCF	    T0CS	    ; TMR0 como temporizador
    BCF	    PSA		    ; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0		    ; PS<2:0> -> 111 prescaler 1 : 256
    
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   61
    MOVWF   TMR0	    ; 50ms retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    RETURN 

; Cada vez que se cumple el tiempo del TMR0 es necesario reiniciarlo.
; ** Comentado porque lo cambiamos de subrutina a macro **
RESET_TMR0:
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   61
    MOVWF   TMR0	    ; 50ms retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    return
    
 CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    BANKSEL TRISC
    CLRF    TRISC	    ; PORTD como salida
    BCF	    TRISD,0
    BCF	    TRISD,1
    BCF	    TRISD,2
    BCF	    TRISD,3
    BSF	    TRISB,BMODO
    BSF	    TRISB,BACCION
    CLRF    TRISA
    BANKSEL PORTC
    CLRF    PORTC	    ; Apagamos PORTD
    BCF	    PORTD,0
    BCF	    PORTD,1
    BCF	    PORTD,2
    BCF	    PORTD,3
    CLRF    PORTA
    RETURN
    
CONFIG_INT:
    BANKSEL IOCB
    BSF	    IOCB0
    BSF	    IOCB1
    
    BANKSEL INTCON
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    BSF	    RBIE
    BCF	    RBIF
    RETURN

OBTENER_NIBBLE:		    ;VALOR = 0110 1101
    MOVLW   0x0F
    ANDWF   VALOR,W
    MOVWF   NIBBLES
    
    MOVLW   0xF0
    ANDWF   VALOR,W
    MOVWF   NIBBLES+1
    SWAPF   NIBBLES+1
    RETURN
    
SET_DISPLAY:
    MOVF    NIBBLES,W
    CALL    TABLA_7SEG
    MOVWF   DISPLAY
    
    MOVF    NIBBLES+1,W
    CALL    TABLA_7SEG
    MOVWF   DISPLAY+1
    
    RETURN
    
MOSTRAR_VALORES:
    BCF	    PORTD,0
    BCF	    PORTD,1
    BTFSC   BANDERAS,0
    GOTO    DISPLAY_1
    ;GOTO    DISPLAY_0
    
    DISPLAY_0:
	MOVF    DISPLAY,W
	MOVWF   PORTC
	BSF	    PORTD,1
	BSF	    BANDERAS,0
	RETURN

    DISPLAY_1:
	MOVF    DISPLAY+1,W
	MOVWF   PORTC
	BSF	    PORTD,0
	BCF	    BANDERAS,0
	RETURN

INT_TMR0:
    CALL    RESET_TMR0	    ; Reiniciamos TMR0 para 50ms
    CALL    MOSTRAR_VALORES
    INCF    CUENTA
    MOVF    CUENTA,W	    ;W=CUENTA
    SUBLW   20		    ;W-20
    BTFSS   STATUS,2	    ;Si Z=0, RETURN; si Z=1, funcion
    RETURN
    
    CLRF    CUENTA
    BTFSS   PORTD,3
    RETURN
    BTFSS   PORTD,2
    GOTO    $+2
    GOTO    $+3
    INCF    PORTA
    RETURN
    DECF    PORTA
    RETURN
    
INT_PORTB:
    BTFSC   PORTD,3	; 
    GOTO    $+4
    BTFSC   PORTD,2	;RD1=0; RD0=0 ESTADO_0; RD0=1 ESTADO_1
    GOTO    ESTADO_1	
    GOTO    ESTADO_0
    BTFSC   PORTD,2	;RD1=1; RD0=0 ESTADO_2; RD0=1 ESTADO_3
    GOTO    ESTADO_3
    GOTO    ESTADO_2
    
    ESTADO_0:
	BTFSC	PORTB, BMODO
	GOTO	$+3
	BCF	PORTD,3
	BSF	PORTD,2
	BTFSS	PORTB, BACCION
	INCF	PORTA
	BCF	RBIF
	RETURN
	
    ESTADO_1:
	BTFSC	PORTB, BMODO
	GOTO	$+3
	BSF	PORTD,3
	BCF	PORTD,2
	BTFSS	PORTB, BACCION
	DECF	PORTA
	BCF	RBIF
	RETURN

    ESTADO_2:
	BTFSC	PORTB, BMODO
	GOTO	$+3
	BSF	PORTD,3
	BSF	PORTD,2
	BCF	RBIF
	RETURN
	
    ESTADO_3:
	BTFSC	PORTB, BMODO
	GOTO	$+3
	BCF	PORTD,3
	BCF	PORTD,2
	BCF	RBIF
	RETURN
	
	 
ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02h
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END


