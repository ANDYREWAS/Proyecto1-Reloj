; Dispositivo:	PIC16F887
; Autor:	Andres Najera
; Compilador:	pic-as (v2.35), MPLABX V6.00
;              
; Creado:	21 feb 2022
; Última modificación: 21 feb 2022
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  MODO	    EQU 1
  UP	    EQU 0
  DOWN	    EQU 2
  EDIT	    EQU 3
  
  
  
RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
RESET_TMR1 MACRO TMR1_H, TMR1_L
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM    
    
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1

PSECT udata_bank0
    LED:		DS 1
    modo:		DS 1
    ;Variables para la Hora
    display:		DS 1	;variables de los displays
    display1:		DS 1
    display2:		DS 1
    display3:		DS 1
    segundosR:		DS 1	;Variables de la hora
    minutosR:		DS 1
    horasR:		DS 1
    dia:		DS 1	;Variables fecha
    mes:		DS 1
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	; Cambio de pagina
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
    CALL    INT_TMR0
    BTFSC   TMR1IF	    ; Interrupcion de TMR1?
    CALL    INT_TMR1
    BTFSC   TMR2IF	    ; Interrupcion de TMR2?
    CALL    INT_TMR2
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB		; Si -> Subrutina de interrupción de PORTB
 
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
RETFIE			    ; Regresamos a ciclo principal

;_______________________INTERRUPCIONES_________________________________________    
INT_TMR0:
    RESET_TMR0 225	    ; Reiniciamos TMR0 para 1ms
;    CALL    MOSTRAR_VOLOR   ; Mostramos valor en hexadecimal en los displays
RETURN
    
INT_TMR1:
    RESET_TMR1 0xE0, 0xC0   ; Reiniciamos TMR1 para 1000ms
RETURN

INT_TMR2:
    BCF	    TMR2IF	    ; Limpiamos bandera de interrupcion de TMR1
    BSF	    PORTE,2
    DECFSZ  LED
    return
    CALL    REINICIOLED    
RETURN   
    
REINICIOLED:
    BCF	    PORTE,2
    MOVLW   2
    MOVWF   LED
RETURN

INT_PORTB:
    BTFSS   PORTB, MODO	    ; Si se presionó botón de cambio de modo    
    INCF    modo
    ;comprobar
    MOVF    modo,0	    ; Movemos el valor de la bandera modo a W
    BCF	    RBIF	    ; Limpiamos bandera de interrupción  
RETURN
    
    
;______________________________________________________________________________
ORG 100h    
MAIN:
    CALL    CONFIG_IO	    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    ; Configuración de TMR0
    CALL    CONFIG_TMR1	    ; Configuración de TMR1
    CALL    CONFIG_TMR2	    ; Configuración de TMR2
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    CLRF    PORTB
    BANKSEL PORTD	    ; Cambio a banco 00
    BSF	    PORTD,0	    ; Predeterminado a encender el display 0 primero
    
			    ;Precarga de los dos leds parapadeantes 1/2seg

    MOVLW   2		    
    MOVWF   LED
    
    MOVLW   60
    MOVWF   segundosR
    
LOOP:
    ;______________DIRECCIONAMIENTO________________________
    ORG 500h
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 0		
    BSF	    PCLATH, 3		; Posicionamos el PC en dirección 05xxh
    ANDLW   0111B		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    GOTO    RELOJ
    GOTO    FECHA
    GOTO    TEMPORIZADOR    
				 ;Código que se va a estar ejecutando mientras no hayan interrupciones
;   CALL    SET_DISPLAY		
    GOTO    LOOP	
    RETURN
 
RELOJ:
    BSF	PORTA,0
RETURN
    
    
FECHA:
    BSF	PORTA,1
RETURN
    
TEMPORIZADOR:
    BSF	PORTA,2
RETURN
    
    
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 01
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BCF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4	    ; IRCF<2:0> -> 010 250KHz
    RETURN

; Configuramos el TMR0 para obtener un retardo de 1ms
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BCF	    PS2
    BCF	    PS1
    BCF	    PS0			; PS<2:0> -> 000 prescaler 1 : 2
    RESET_TMR0 225		; Reiniciamos TMR0 para 1ms
    RETURN 
    
CONFIG_TMR1:
    BANKSEL T1CON	    ; Cambiamos a banco 00
    BCF	    TMR1GE	    ; TMR1 siempre cuenta
    BSF	    T1CKPS1	    ; prescaler 1:8
    BSF	    T1CKPS0
    BCF	    T1OSCEN	    ; LP deshabilitado
    BCF	    TMR1CS	    ; Reloj interno
    BSF	    TMR1ON	    ; Prendemos TMR1
    
    RESET_TMR1 0xE0, 0xC0   ; Reiniciamos TMR1 para 1000ms
    RETURN

CONFIG_TMR2:
    BANKSEL PR2		    ; Cambiamos a banco 01
    MOVLW   122		    ; Valor para interrupciones cada 500ms
    MOVWF   PR2		    ; Cargamos litaral a PR2
    
    
    BANKSEL T2CON	    ; Cambiamos a banco 00
    BSF	    T2CKPS1	    ; prescaler 1:16
    BSF	    T2CKPS0
    BSF	    TOUTPS3	    ; postscaler 1:16
    BSF	    TOUTPS2
    BSF	    TOUTPS1
    BSF	    TOUTPS0
    BSF	    TMR2ON	    ; prendemos TMR2
    RETURN
        

CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    BANKSEL TRISD
    CLRF    TRISA	    ; PORTA como salida
    CLRF    TRISE	    ; PORTB como salida
    BANKSEL PORTD
    CLRF    PORTA	    ; Apagamos PORTA
    
    ;Multiplexado
    BANKSEL TRISC
    BCF     OPTION_REG	,7	;Habilita las resistencias pullups
    BSF	    WPUB	,0
    BSF	    WPUB	,1
    CLRF    TRISC		; PORTC como salida
   
    
    ;PORTD
    BCF	    TRISD, 0		; RD0 como salida / display nibble alto
    BCF	    TRISD, 1		; RD1 como salida / display nibble bajo
    BCF	    TRISD, 2		
    BCF	    TRISD, 3		
    BCF	    TRISD, 4
    
    ;PORTB 
    BSF	    TRISB, MODO		; RB3 como entrada
    BSF	    TRISB, UP		; RB0 como entrada
    BSF	    TRISB, DOWN		; RB1 como entrada
    BSF	    TRISB, EDIT		; RB4 como entrada
    
    BANKSEL PORTC
    CLRF    PORTC		; Apagamos PORTC
    BCF	    PORTD, 0		; Apagamos RD0
    BCF	    PORTD, 1		; Apagamos RD1
    BCF	    PORTD, 2		; Apagamos RD3
    BCF	    PORTD, 3		; Apagamos RD3

    CLRF    PORTA		; Apagamos PORTA
RETURN
    
CONFIG_INT:
    BANKSEL IOCB		
    BSF	    IOCB0	    ; Habilitamos int. por cambio de estado en RB0
    BSF	    IOCB1	    ; Habilitamos int. por cambio de estado en RB1
    BANKSEL PIE1	    ; Cambiamos a banco 01
    BSF	    TMR1IE	    ; Habilitamos interrupciones de TMR1
    BSF	    TMR2IE	    ; Habilitamos interrupciones de TMR2
    BANKSEL INTCON	    ; Cambiamos a banco 00
    BSF	    PEIE	    ; Habilitamos interrupciones de perifericos
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de int. de TMR0
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF	    TMR2IF	    ; Limpiamos bandera de TMR2
    BCF	    RBIF	    ; Limpiamos bandera de int. de PORTB
    
RETURN    
    
    
ORG 300h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
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




