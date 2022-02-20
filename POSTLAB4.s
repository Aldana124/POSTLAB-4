; Archivo: PSOTLAB4.s
; Dispositivo: PIC16F887
; Autor: Diego Aldana

; Programa: CONTADOR CON DECIMAS 
; Hardware: 7 SEGMENTOS 

; Creado: 14/02/2022
; Ult. modificaciíon: 19/02/2022


    PROCESSOR 16F887
    #include <xc.inc>

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

    ; Definición de valores constantes (Correspondiente a los botones del puerto B)
	INCR	    EQU 0	; Valor constante equivalente
	DECR	    EQU 1	
	
    ; Status de las interrupciones
    PSECT udata_shr		; Memoria compartida
	WT:		DS 1	; 1 byte
	ST:		DS 1	
    
    ; Variables globales
	PSECT udata_bank0		; common memory
	CONT:		DS 1		; Variable del Contador con botones
	CONT1:		DS 1		; Variable del Contador de segundos (DISPLAY1)
	CONT2:		DS 1		; Variable del Contador de decenas (DISPLAY2)
      
    ;------------- VECTOR RESET -------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h			; Posición 0000h para el reset
    resetVec:
        PAGESEL MAIN		
        GOTO    MAIN

    PSECT intVect, class=CODE, abs, delta=2
    ORG 04h	; posición 0004h para interrupciones

    ;-------------------- SUBRUTINAS DE INTERRUPCION ---------------------------
    PUSH:			
	MOVWF   WT		; Guardamos en W el valor de  WT
	SWAPF   STATUS, W	
	MOVWF   ST		; Almacenamos W en ST
	
    ISR:			; Verificación de banderas de las interrupciones
	BTFSC   RBIF		; Vericamos si hay interrupción de cambio en el puerto B
	CALL    INT_IOCB		; Subrutina INT_B
	
	BTFSC	T0IF		; Verificamos si hay interrupción del TIMER0
	CALL	INT_TMR0	; Subrutina INT_TMR0
	
    POP:				
	SWAPF   ST, W  
	MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
	SWAPF   WT, F	    
	SWAPF   WT, W	    ; Recuperamos valor de W
	RETFIE		    ; Regresamos a ciclo principal
    
    ;-------- RUTINAS  -----------------
    PSECT code, delta=2, abs
    ORG 100h	; posición 100h para el codigo
    
    MAIN:
	CALL	CONFIG_IO	    ; Comfiguración de los puertos	
	CALL	CONFIG_CLK	    ; Configuración del TMR0
	CALL	CONIFG_INT	    ; Configuracion de INTERRUPCIONES
	CALL	CONFIG_IOCRB	    ; Configuración de 
	CALL	CONFIG_TMR0
	CLRF	CONT1		    ; limpieza de variable
	CLRF	CONT2		
	BANKSEL PORTB
	
    LOOP:			; Rutina que se estará ejecutando indefinidamente 
	MOVF    CONT1, W	; Valor de contador 1 a W para buscarlo en la tabla hexadecimal
	CALL    TABLA		; Buscamos caracter de CONT1 en la tabla hexadecimal
	MOVWF   PORTC		; Guardamos caracter de CONT1 en PORTC
	
	MOVF    CONT2, W	; Mismo proceso para el CONT2
	CALL    TABLA		
	MOVWF   PORTD		; Guardamos caracter de CONT2 en PORTD
	
	CALL	X10    ; rutina para cada 10 pulsos de contador
	CALL	X60    ; tutina para minutos
	
	GOTO	LOOP		; Volvemos a comenzar con el loop
	
    ;--------------- SUBRUTINAS --------------------
    INT_IOCB:
	BANKSEL PORTB
	BTFSS   PORTB, INCR	; Verificar si el bit 0 del puerto B está presionado
	INCF    PORTA		; Incrementar contador 
	BTFSS   PORTB, DECR	; Verificar si el bit 1 del puerto B no está presionado
	DECF    PORTA		; Decrementar contador
	BCF	RBIF		; Limpiar la bandera de cambio del PORTB
	return  
	
    INT_TMR0:
	CALL	RESET_TMR0
	INCF	CONT		; Incrementamos al contador cada vez que se eleve la bandera (20ms)
    	MOVF	CONT, W	; Colocamos el valor del CONT0 en la variable W
	SUBLW   50		
	BTFSS   ZERO		; Verificación de la bandera del ZERO
	return			
	INCF	CONT1		; Incrementar el CONT1
	CLRF	CONT		; limpieza
	return

    CONFIG_TMR0:
	BANKSEL OPTION_REG	; Redireccionamos de banco
	BCF	T0CS		; Configuramos al timer0 como temporizador
	BCF	PSA		; Configurar el Prescaler para el timer0 (No para el Wathcdog timer)
	BSF	PS2
	BSF	PS1
	BCF	PS0		; PS<2:0> -> 110 (Prescaler 1:128)
	CALL	RESET_TMR0	; Reiniciamos la bandera interrupción
	return
    
    CONFIG_CLK:			
	BANKSEL OSCCON	    
	BSF	OSCCON, 0
	BCF	OSCCON, 4
	BSF	OSCCON, 5
	BSF	OSCCON, 6	; Oscilador con reloj de 4 MHz
	return

    CONFIG_IOCRB:
	BANKSEL TRISB
	BSF	IOCB, INCR	; Habilitar el registro IOCB para el primer bit
	BSF	IOCB, DECR	; Habilitar el registro IOCB para el segundo bit
	
	BANKSEL PORTB
	MOVF    PORTB, W	; Mover el valor del puerto B al registro W
	BCF	RBIF		; Limpieza de la bandera de interrupción por cambio RBIF
	return

    CONIFG_INT:
	BANKSEL INTCON
	BSF	GIE		; Habilitamos a todas las interrupciones
	BSF	RBIE		; Habilitamos las interrupciones por cambio de estado del PORTB
	BCF	RBIF		; Limpieza de la bandera de la interrupción de cambio
	BSF	T0IE		; Habilitamos la interrupción del TMR0
	BCF	T0IF		; Limpieza de la bandera de TMR0
	return
	
    CONFIG_IO:
	BANKSEL ANSEL		; Direccionamos de banco
	CLRF    ANSEL
	CLRF    ANSELH		; Configurar como digitales
	
	BANKSEL TRISA		; Direccionamos de banco
	BSF	TRISB, 0	; Habilitamos como entrada al bit 0 de PORTB
	BSF	TRISB, 1	; Habilitamos como entrada al bit 1 de PORTB 
	BCF	TRISB, 2	; se habilitaron las entradas manuealmente porque tiraba un error raro ;-;
	BCF	TRISB, 3
	BCF	TRISB, 4
	BCF	TRISB, 5
	BCF	TRISB, 6
	BCF	TRISB, 7
	BCF	TRISA, 0	
	BCF	TRISA, 1
	BCF	TRISA, 2
	BCF	TRISA, 3
	BCF	TRISC, 0	
	BCF	TRISC, 1
	BCF	TRISC, 2
	BCF	TRISC, 3
	BCF	TRISC, 4
	BCF	TRISC, 5
	BCF	TRISC, 6
	BCF	TRISD, 0	
	BCF	TRISD, 1
	BCF	TRISD, 2
	BCF	TRISD, 3
	BCF	TRISD, 4
	BCF	TRISD, 5
	BCF	TRISD, 6
	BCF	OPTION_REG, 7   ; Habilitar las resistencias pull-up (RPBU)
	BSF	WPUB, INCR	; Habilita el registro de pull-up en RB0 
	BSF	WPUB, DECR	; Habilita el registro de pull-up en RB1
	BANKSEL PORTA		; Direccionar de banco
	CLRF    PORTA		; Limpieza de PORTA
	CLRF    PORTB		; Limpieza de PORTB
	CLRF	PORTC
	CLRF	PORTD
	return	
	
    RESET_TMR0:
	BANKSEL TMR0		
	MOVLW   100		; Valor de N 
	MOVWF   TMR0		; 20 ms
	BCF	T0IF		; Limpieza de bandera
	return

    X60:
	MOVF	CONT2, W    ; Colocar el valor del contador de segundos en W
	SUBLW	6	    ; Restar 6 al valor del contador de decenas
	BTFSS	ZERO	    ; Verificación de la bandera del ZERO
	return
	CLRF	CONT1	    ; limpieza
	CLRF	CONT2	    ; 
	return
	
    X10:
	MOVF	CONT1, W    ; Colocar el valor del contador de segundos en W
	SUBLW	10	    
	BTFSS   ZERO	    ; Verificación de la bandera del ZERO
	return
	INCF	CONT2
	CLRF	CONT1
	return
		

	
    ;---------------- TABLA  HEXADECIMAL ------------------
    ORG 200h
    TABLA:
	CLRF    PCLATH		; Limpiamos registro PCLATH
	BSF	PCLATH, 1	; Posicionamos el PC en dirección 02xxh
	ANDLW   0x0F		; no saltar más del tamaño de la tabla
	ADDWF   PCL		; Apuntamos el PC a caracter en ASCII de CONT
	RETLW   00111111B	; 0
	RETLW   00000110B	; ASCII char 1
	RETLW   01011011B	; ASCII char 2
	RETLW   01001111B	; ASCII char 3
	RETLW   01100110B	; ASCII char 4
	RETLW   01101101B	; ASCII char 5
	RETLW   01111101B	; ASCII char 6	
	RETLW   00000111B	; ASCII char 7
	RETLW   01111111B	; ASCII char 8
	RETLW   01101111B	; ASCII char 9
	RETLW   01110111B	; ASCII char 10
	RETLW   01111100B	; ASCII char 11
	RETLW   00111001B	; ASCII char 12
	RETLW   01011110B	; ASCII char 13
	RETLW   01111001B	; ASCII char 14
	RETLW   01110001B	; ASCII char 15
	END