; Dispositivo:	PIC16F887
; Autor:	Andres Najera
; Compilador:	pic-as (v2.35), MPLABX V6.00    
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
    u_min:		DS 1
    d_min:		DS 1
    u_hora:		DS 1
    d_hora:		DS 1
    
    temp:		DS 1
    cociente:		DS 1
    residuo:		DS 1
    
    
    dia:		DS 1	;Variables fecha
    mes:		DS 1
    config_select:	DS 1
    
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
    BTFSC   RBIF	    ; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB	    ; Si -> Subrutina de interrupción de PORTB
 
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
RETFIE			    ; Regresamos a ciclo principal

;_______________________INTERRUPCIONES_________________________________________    
INT_TMR0:
    RESET_TMR0 225	    ; Reiniciamos TMR0 para 1ms

RETURN
    
INT_TMR1:
    RESET_TMR1 0xE0, 0xC0   ; Reiniciamos TMR1 para 1000ms
    DECFSZ  segundosR
    RETURN
    MOVLW   60
    MOVWF   segundosR
    
    INCF    minutosR
    MOVLW   60
    SUBWF   minutosR, 0	    ;guardamos el resultado en W
    BTFSS   STATUS, 2	    ;no regresamos si el resultado fue 0
    RETURN
    
    INCF    horasR	    
    CLRF    minutosR
    
    MOVLW   24
    SUBWF   horasR,0
    BTFSS   STATUS,2
    GOTO    $+3
    INCF    dia
    CLRF    horasR
    
    
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
    BTFSC   PORTB, MODO	    ; Si se presionó botón de cambio de modo    
    Goto    $+6
    INCF    modo
    ;comprobar
    MOVLW   4
    SUBWF   modo,0
    BTFSC   STATUS,2
    CLRF    modo
    ;movemos modo a W para luego sumarselo a PCLAT
    
    BCF	    RBIF	    ; Limpiamos bandera de interrupción  
RETURN
    
    
;______________________________________________________________________________
PSECT code, delta = 2, abs
ORG 100h    
MAIN:
    CALL    CONFIG_IO	    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    ; Configuración de TMR0
    CALL    CONFIG_TMR1	    ; Configuración de TMR1
    CALL    CONFIG_TMR2	    ; Configuración de TMR2
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    ;CALL    CLEARVARS
    CLRF    PORTA
    BANKSEL PORTD	    ; Cambio a banco 00
    BSF	    PORTD,0	    ; Predeterminado a encender el display 0 primero
    
			    ;Precarga de los dos leds parapadeantes 1/2seg
    MOVLW   2		    
    MOVWF   LED
    
    MOVLW   60		    ;precarga segundos
    MOVWF   segundosR
    
    MOVLW   6
    MOVWF   horasR
    
    MOVLW   9
    MOVWF   minutosR
    
    MOVLW   1
    MOVWF   dia
    
    MOVLW   1
    MOVWF   mes
/*    
CLEARVARS:
    CLRF LED		
    CLRF modo		
    CLRF display		
    CLRF display1		
    CLRF display2		
    CLRF display3		
    CLRF segundosR		
    CLRF minutosR		
    CLRF horasR	
    CLRF u_min		
    CLRF d_min		
    CLRF u_hora		
    CLRF d_hora		   
    CLRF temp1		
    CLRF temp2		
    CLRF dia		
    CLRF mes		
RETURN 
  */  
LOOP:
    MOVF    modo,0
    MOVWF   PORTA
    
    CALL    DIRECCIONAMIENTO					;Código que se va a estar ejecutando mientras no hayan interrupciones
    CALL    MULTIPLEXADO
    GOTO    LOOP	

 
    
    
   
DIRECCIONAMIENTO:
    CLRF    PCLATH			; Limpiamos registro PCLATH		
    BSF	    PCLATH, 0			; Posicionamos el PC en dirección 04xxh
    MOVF    modo,0	    ; Movemos el valor de la bandera modo a W 
    ANDLW   0x03			; no saltar más del tamaño de la tabla
    ADDWF   PCL
    GOTO    RELOJ
    GOTO    FECHA
    GOTO    TEMPORIZADOR    
    GOTO    ALARMA

   

    RELOJ:
    
	CALL	DECENAS_M_R
	;SET display0 - unidades de minuto
	MOVF	u_min,0
	CALL	TABLA_7SEG
	MOVWF	display
	
	;SET display1 - Decenas de minuto
	MOVF	d_min,0
	CALL	TABLA_7SEG
	MOVWF	display3
	
	
	CALL	DECENAS_H_R
	;SET display0 - unidades de hora
	MOVF	u_hora,0
	CALL	TABLA_7SEG
	MOVWF	display1
	
	;SET display1 - Decenas de hora
	MOVF	d_hora,0
	CALL	TABLA_7SEG
	MOVWF	display2

	DECENAS_M_R:    
	    MOVF	minutosR,0		;movemos minutos a W
	    MOVWF	temp

	    MOVLW	10
	    SUBWF	temp,1			;Le restamos 10 a ver cuantas decenas de minutos hay
	    BTFSS	STATUS,0		;revisamos el Carry
	    GOTO	UNIDADES_M_R		;ERROR
	    INCF	d_min
	    GOTO	$-5


	UNIDADES_M_R:
	    MOVLW	10
	    ADDWF	temp
	    MOVF	temp,0
	    MOVWF	u_min	
	RETURN

	DECENAS_H_R:    
	    MOVF	horasR,0		;movemos minutos a W
	    MOVWF	temp

	    MOVLW	10
	    SUBWF	temp,1			;Le restamos 10 a ver cuantas decenas de minutos hay
	    BTFSS	STATUS,0		;revisamos el Carry
	    GOTO    UNIDADES_H_R
	    INCF	d_hora
	    GOTO	$-5


	UNIDADES_H_R:
	    MOVLW	10
	    ADDWF	temp
	    MOVF	temp,0
	    MOVWF	u_hora	
	RETURN
    
    FECHA:

	;SET display0 - unidades mes
	MOVF	mes,0	
	CALL	TABLA_7SEG
	MOVWF	display1
	
	;SET display0 - unidades dia
	MOVF	dia,0	
	CALL	TABLA_7SEG
	MOVWF	display

    RETURN

    TEMPORIZADOR:
	
    RETURN

    ALARMA:

    RETURN

    	
MULTIPLEXADO:
    MOSTRAR_VALOR:			;Multiplexado
	BTFSC    PORTD,0
	GOTO	 DISPLAY_0

	BTFSC    PORTD,1
	GOTO	 DISPLAY_1

	BTFSC    PORTD,2
	GOTO	 DISPLAY_2

	BTFSC    PORTD,3
	GOTO	 DISPLAY_3

    
    
	DISPLAY_0:
	    CLRF    PORTD
	    MOVF    display, W		; Movemos display a W
	    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	    BSF	    PORTD, 1		; Encendemos display de nibble bajo

	    RETURN

	DISPLAY_1:
	    CLRF    PORTD
	    MOVF    display1, W		; Movemos display+1 a W
	    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	    BSF	    PORTD, 2		; Encendemos display de nibble alto

	    RETURN
	DISPLAY_2:
	    CLRF    PORTD
	    MOVF    display2, W		; Movemos display+1 a W
	    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	    BSF	    PORTD, 3		; Encendemos display de nibble alto

	    RETURN
	DISPLAY_3:
	    CLRF    PORTD
	    MOVF    display3, W		; Movemos display+1 a W
	    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	    BSF	    PORTD, 0		; Encendemos display de nibble alto

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
    BSF	    WPUB	,2
    BSF	    WPUB	,3
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
    BSF	    IOCB2	    ; Habilitamos int. por cambio de estado en RB2
    BSF	    IOCB3	    ; Habilitamos int. por cambio de estado en RB3
    
    BANKSEL PIE1	    ; Cambiamos a banco 01
    BSF	    TMR1IE	    ; Habilitamos interrupciones de TMR1
    BSF	    TMR2IE	    ; Habilitamos interrupciones de TMR2
    BANKSEL INTCON	    ; Cambiamos a banco 00
    BCF	    INTF    
    BSF	    PEIE	    ; Habilitamos interrupciones de perifericos
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de int. de TMR0
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF	    TMR2IF	    ; Limpiamos bandera de TMR2
    BSF	    RBIE
    BCF	    RBIF	    ; Limpiamos bandera de int. de PORTB
    
RETURN    
    
    
ORG 300h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 03xxh
    BSF	    PCLATH, 0		; Posicionamos el PC en dirección 03xxh
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


TABLA_FECHA:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 03xxh
    BSF	    PCLATH, 0		; Posicionamos el PC en dirección 03xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   0		;0
    RETLW   31		;ENERO
    RETLW   28		;FEBRERO
    RETLW   31		;MARZO
    RETLW   30		;ABRIL
    RETLW   31		;MAYO
    RETLW   30		;JUNIO
    RETLW   31		;JULIO
    RETLW   31		;AGOSTO
    RETLW   30		;SEPTIEMBRE
    RETLW   31		;OCTUBRE
    RETLW   30		;NOVIEMBRE
    RETLW   31		;DICIEMBRE
    

