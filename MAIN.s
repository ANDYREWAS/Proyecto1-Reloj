; Dispositivo:	PIC16F887
; Autor:	Andres Najera
; Compilador:	pic-as (v2.35), MPLABX V6.00    
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
    
WDIVL	MACRO divisor  
						    
	MOVWF	temp+0   
	CLRF	temp+1 
	INCF	temp+1	    ; ¿Cuantas veces  ha restado?
	
	MOVLW	divisor  
	SUBWF	temp, f	
	BTFSC   STATUS,0    ; ¿Carry?  
	GOTO	$-4   
	
	MOVLW	divisor	    
	ADDWF	temp, W	    
	MOVWF	residuo	    
	DECF	temp+1,W   
	MOVWF	cociente   
	
	ENDM
    
PSECT udata_shr			; Memoria compartida
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
    
    temp:		DS 2	;Variables Macro restas
    cociente:		DS 1
    residuo:		DS 1
    
    
    dia:		DS 1	;Variables fecha
    mes:		DS 1
    u_dia:	    	DS 1
    d_dia:	    	DS 1
    u_mes:	    	DS 1
    d_mes:	    	DS 1
    temp_d:		DS 1
    
    
    minutosT:		DS 1	;Variables temporizador
    segundosT:		DS 1
    tempEnable:		DS 1
    
    u_minT:		DS 1
    d_minT:		DS 1
    u_segT:		DS 1
    d_segT:		DS 1
    
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
    
    ;FUNCIONAMIENTO RELOJ
    CALL    TEMP_CONFIG
    
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
    RETURN
    INCF    dia
    CLRF    horasR
    
    MOVF    mes,0
    CALL    TABLA_FECHA
    SUBWF   dia,0
    BTFSS   STATUS,2
    RETURN
    INCF    mes
    MOVLW   1
    MOVWF   dia
    
    MOVLW   13
    SUBWF   mes,0
    BTFSS   STATUS,2
    RETURN
    MOVLW   1
    MOVWF   mes
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
    
    
    BCF	    PORTE,1	    ;siempre que presionemos cualquier botón apaga el buzzer del timer
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
    CALL    CLEARVARS
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    CLRF    PORTA
    BANKSEL PORTD	    ; Cambio a banco 00
    BSF	    PORTD,0	    ; Predeterminado a encender el display 0 primero
    

    
    ;Precarga de valores a variables
    MOVLW   2		    
    MOVWF   LED
    
    MOVLW   60		    ;precarga segundos
    MOVWF   segundosR
    
    MOVLW   1
    MOVWF   horasR
    
    MOVLW   1
    MOVWF   minutosR
    
    MOVLW   28
    MOVWF   dia
    
    MOVLW   2
    MOVWF   mes
    
    MOVLW   15
    MOVWF   segundosT
    
    MOVLW   0
    MOVWF   minutosT

    
LOOP:
   
    CALL    DIRECCIONAMIENTO	;Código que se va a estar ejecutando mientras no hayan interrupciones
    CALL    MULTIPLEXADO
    GOTO    LOOP	
   
CLEARVARS:			;Subrutina que limpia las variables para evitar ambiguedades
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
    CLRF dia		
    CLRF mes	
    
    CLRF temp		
    CLRF cociente		
    CLRF residuo		
    
    CLRF dia		
    CLRF mes		
    CLRF u_dia	
    CLRF d_dia	    	
    CLRF u_mes	    	
    CLRF d_mes	    
    CLRF temp_d		
    
    CLRF minutosT		
    CLRF segundosT		
    CLRF tempEnable	
    
    CLRF u_minT		
    CLRF d_minT		
    CLRF u_segT	
    CLRF d_segT
    
RETURN     
    
DIRECCIONAMIENTO:
    CLRF    PCLATH			; Limpiamos registro PCLATH		
    BSF	    PCLATH, 0			; Posicionamos el PC en dirección 04xxh
    MOVF    modo,0			; Movemos el valor de la bandera modo a W 
    ANDLW   0x03			; no saltar más del tamaño de la tabla
    ADDWF   PCL
    GOTO    RELOJ
    GOTO    FECHA
    GOTO    TEMPORIZADOR    
    GOTO    ALARMA

TEMP_CONFIG:  
    /*
    ;verificacion de tamaño - OVERFLOW
    MOVLW   100		
    SUBWF   minutosT,0
    BTFSC   STATUS,2	;zero / overflow
    CLRF    minutosT
    
    MOVLW   60
    SUBWF   segundosT,0
    BTFSC   STATUS,2
    CLRF    segundosT
    
     heeyy esto es para el modo de configuracion del temporizador.
     */
    
    BTFSC   tempEnable,0
    DECFSZ  segundosT
    RETURN
    DECF    minutosT
    BTFSC   STATUS,0	    ;vemos si hubo Carry
    GOTO    $+4
    MOVLW   60
    MOVWF   segundosT
    RETURN
    BCF	    tempEnable,0
    CLRF    minutosT
    BSF	    PORTE,1
RETURN

    RELOJ:
    CLRF    PORTA
    BSF	    PORTA,0
    ;BTFSS   PORTB,EDIT
    ;GOTO    SET_RELOJ
  
	CALL	SPLIT_M_R
	;SET display0 - unidades de minuto
	MOVF	u_min,0
	CALL	TABLA_7SEG
	MOVWF	display
	
	;SET display1 - Decenas de minuto
	MOVF	d_min,0
	CALL	TABLA_7SEG
	MOVWF	display3
	
	
	CALL	SPLIT_H_R
	;SET display0 - unidades de hora
	MOVF	u_hora,0
	CALL	TABLA_7SEG
	MOVWF	display1
	
	;SET display1 - Decenas de hora
	MOVF	d_hora,0
	CALL	TABLA_7SEG
	MOVWF	display2

	SPLIT_M_R:			;Las subrutinas SPLIT son para la separacion de la variable en unidades y decenas
	    MOVF    minutosR, W 
   
	    WDIVL   60		    
	    MOVF    cociente, W
	    MOVWF   d_min	   
	    MOVF    residuo, W
	    MOVWF   u_min

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_min	     
	    MOVF    residuo, W
	    MOVWF   u_min
	RETURN
	    


	SPLIT_H_R:    
	    MOVF    horasR, W 
    
	    WDIVL   24		    
	    MOVF    cociente, W
	    MOVWF   d_hora	   
	    MOVF    residuo, W
	    MOVWF   u_hora

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_hora	     
	    MOVF    residuo, W
	    MOVWF   u_hora
	   	
	RETURN
	/* 		    Modo de config, comentado
	SET_RELOJ:
	    BTFSS   PORTB,UP
	    INCF    minutosR
	    BTFSS   PORTB,DOWN
	    DECF    minutosR
	    
	    BTFSS   PORTB,EDIT
	    GOTO    SET_RELOJ2
	    GOTO    $-6
	    
	    SET_RELOJ2:
		BTFSS   PORTB,UP
		INCF    horasR
		BTFSS   PORTB,DOWN
		DECF    horasR
		
		BTFSS   PORTB,EDIT
		GOTO    RELOJ
		GOTO    $-6
	    */
   
    FECHA:
    CLRF    PORTA
    BSF	    PORTA,1
    
    /*BTFSS   PORTB,EDIT
    GOTO    SET_FECHA
    */
	CALL	FORMATO
	
	CALL	SPLIT_m_F
	;SET display1 - unidades mes
	MOVF	u_mes,0	
	CALL	TABLA_7SEG
	MOVWF	display1
	
	;SET display2 - unidades mes
	MOVF	d_mes,0	
	CALL	TABLA_7SEG
	MOVWF	display2
	
	CALL	SPLIT_d_F
	;SET display0 - unidades dia
	MOVF	u_dia,0	
	CALL	TABLA_7SEG
	MOVWF	display
	
	;SET display3 - unidades mes
	MOVF	d_dia,0	
	CALL	TABLA_7SEG
	MOVWF	display3

	
	FORMATO:
	    MOVF    mes,w
	    CALL    TABLA_FECHA	    ;nos devuelve la cantidad de dias que tiene el mes en W
	    SUBWF   dia,w
	    BTFSC   STATUS,2	    ;verificamos que no se pongan mas dias de los que tiene el mes
	    CLRF    dia
	    
	
	    MOVF    mes,w
	    CALL    TABLA_FECHA	    ;nos devuelve la cantidad de dias que tiene el mes en W
	    SUBWF   dia,w
	    BTFSS   STATUS,0	    ;verificamos que no haya carry, si hay, que cargue la cantidad de días que tiene el mes
	    GOTO    $+3
	    MOVF    mes,w
	    MOVWF   dia
	RETURN
	
	SPLIT_d_F:    
	    
	    MOVF    mes,W
	    CALL    TABLA_FECHA
	    MOVWF   temp_d	;se guarda en temp la cantidad de dias que tiene el mes
   
	    MOVF    dia, W 
	    WDIVL   temp_d	 ;30,31,28   
	    MOVF    cociente, W
	    MOVWF   d_dia	   
	    MOVF    residuo, W
	    MOVWF   u_dia

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_dia	     
	    MOVF    residuo, W
	    MOVWF   u_dia
	RETURN
	    


	SPLIT_m_F:    
	    MOVF    mes, W 

	    WDIVL   13		    
	    MOVF    cociente, W
	    MOVWF   d_mes	   
	    MOVF    residuo, W
	    MOVWF   u_mes

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_mes	     
	    MOVF    residuo, W
	    MOVWF   u_mes
	   	
	RETURN
	/*			    Modo de config, comentado
	SET_FECHA:
	    BTFSS   PORTB,UP
	    INCF    dia
	    BTFSS   PORTB,DOWN
	    DECF    dia
	    
	    BTFSS   PORTB,EDIT
	    GOTO    SET_FECHA2
	    GOTO    $-6
	    
	    SET_FECHA2:
		BTFSS   PORTB,UP
		INCF    mes
		BTFSS   PORTB,DOWN
		DECF    mes
		
		BTFSS   PORTB,EDIT
		GOTO    FECHA
		GOTO    $-6
    */
    

    TEMPORIZADOR:
    
    CLRF    PORTA
    BSF	    PORTA,2
    
    BTFSS   PORTB,UP
    BSF	    tempEnable,0
    
    BTFSS   PORTB,DOWN
    BCF	    tempEnable,0
/*
    BTFSS   PORTB,EDIT
    GOTO    SET_TEMP
*/
	CALL	SPLIT_M_T
	;SET display0 - unidades de segundo temp
	MOVF	u_segT,0
	CALL	TABLA_7SEG
	MOVWF	display
	
	;SET display1 - Decenas de segundo  temp
	MOVF	d_segT,0
	CALL	TABLA_7SEG
	MOVWF	display3
	
	
	CALL	SPLIT_S_T
	;SET display0 - unidades de minuto  temp
	MOVF	u_minT,0
	CALL	TABLA_7SEG
	MOVWF	display1
	
	;SET display1 - Decenas de minuto   temp
	MOVF	d_minT,0
	CALL	TABLA_7SEG
	MOVWF	display2

	SPLIT_M_T:    
	    MOVF    minutosT, W 
   
	    WDIVL   60		    
	    MOVF    cociente, W
	    MOVWF   d_minT	   
	    MOVF    residuo, W
	    MOVWF   u_minT

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_minT	     
	    MOVF    residuo, W
	    MOVWF   u_minT
	RETURN
	    


	SPLIT_S_T:    
	    MOVF    segundosT, W 
    
	    WDIVL   60		    
	    MOVF    cociente, W
	    MOVWF   d_segT	   
	    MOVF    residuo, W
	    MOVWF   u_segT

	    WDIVL   10		     
	    MOVF    cociente, W
	    MOVWF   d_segT	     
	    MOVF    residuo, W
	    MOVWF   u_segT
	   	
	RETURN
  /*				    Modo de config, comentado
	SET_TEMP:
	    BTFSS   PORTB,UP
	    INCF    segundosT
	    BTFSS   PORTB,DOWN
	    DECF    segundosT
	    
	    BTFSS   PORTB,EDIT
	    GOTO    SET_TEMP2
	    GOTO    $-6
	    
	    SET_TEMP2:
		BTFSS   PORTB,UP
		INCF    minutosT
		BTFSS   PORTB,DOWN
		DECF    minutosT
		
		BTFSS   PORTB,EDIT
		GOTO    TEMPORIZADOR
		GOTO    $-6
*/	
    RETURN

    ALARMA:
    GOTO    RELOJ
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
    
    RESET_TMR1 0xE1, 0x7C   ; Reiniciamos TMR1 para 1000ms
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
    RETLW   32		;ENERO
    RETLW   29		;FEBRERO
    RETLW   32		;MARZO
    RETLW   31		;ABRIL
    RETLW   32		;MAYO
    RETLW   31		;JUNIO
    RETLW   32		;JULIO
    RETLW   32		;AGOSTO
    RETLW   31		;SEPTIEMBRE
    RETLW   32		;OCTUBRE
    RETLW   31		;NOVIEMBRE
    RETLW   32		;DICIEMBRE
    

