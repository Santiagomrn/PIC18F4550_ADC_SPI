 #include "C:\Program Files (x86)\Microchip\MPLABX\v5.25\mpasmx\p18f4550.inc"
  LIST p=18F4550	    ;Tipo de microprocesador
 
udata_acs
;Variables
data_to_send RES 1			    ; Reservamos un byte de memoria para enviar datos por SPI
save_data RES 1	;<----- no se que hace
;Variables del delay 1s
DCounter1 EQU 0X0C
DCounter2 EQU 0X0D
DCounter3 EQU 0X0E
    
Duty_On	    EQU	    0x20	;Vairalbes de ancho de pulso
Duty_Off    EQU	    0x21
    
  CODE 0x00
;---------FRECUENCIA DEL OSCILADOR------------------
;seleccion del oscilador interno como fuente de reloj del CPU
BSF OSCCON,SCS1,0 ;
BSF OSCCON,SCS0,0 ; 
;configuro el PLL para 8MHz de fosc al cpu 
BSF OSCCON, IRCF2,0
BSF OSCCON, IRCF1,0
BSF OSCCON, IRCF0,0
;--------DEFINO PUERTOS--------------
;CONFIGURO PUERTO B0 Y B1 COMO SALIDA
CLRF PORTB	    ;limpia puerto B
MOVLW B'00000000'   ;mueve 0 a w
MOVWF TRISB,ACCESS  ;mueve w a TRISB
MOVLW B'00000000'   ;mueve 0 a w
MOVWF LATB,ACCESS   ;mueve w a LATB
  
 ;configuro puerto D como salida
CLRF PORTD	    ;limpia el puerto D
MOVLW B'00000000'   ;mueve 0 a W
MOVWF TRISD,ACCESS  ;mueve W a TRISD 
MOVLW B'00000000'   ;mueve 0 a W
MOVWF LATD,ACCESS   ;mueve W a LATD
;Set CCP1 pin como salida puerto C2 como salida
CLRF TRISC
  ;----------configuracion de ADC----

MOVWF B'00000000'  ;CONFIGURO EL CANAL 0 AN0
MOVWF ADCON0
 
MOVLW B'00001110'  ;CONFIGURA EL VOTAJE DE REFERENCIA IGUAL AL DE LA ALIMENTACION PIC Y CONFIGURA EL PUERTO AN0 COMO ENTRADA ANALOGICA
MOVWF ADCON1 

MOVLW B'00111010'  ;ACTIVA JUSTIFICACION A LA IZQUIERDA -- TIMEPO DE ADQUISICION 20 TAD -- TAD=fOSC/32 =8MHZ/32
MOVWF ADCON2

MOVLW B'00000001'  ;ENCIENDE EL ADC
MOVWF ADCON0

;-------------------------------------Configuración del SPI al Inicio-------------------------------------
Start_SPI:
    ; Limpiamos puertos a utilizar
    CLRF PORTC				    ; Limpiamos puerto C
    CLRF PORTB				    ; Limpiasmo puerto B
    ;B1 SCK
    ;B0 (MOSI)
    ;C7 SDO (MISO)
    ;
    ;Configuración del B1 SCK como salida en el puerto y RB0 SDI(MOSI) como entrada en el puerto 0
    MOVLW 0x01				    ; Pasamos 0x01 al registro W, para poner a pi1 como salida y pin 0 como entrada
    MOVWF TRISB, ACCESS			    ; Movemos lo que está en el registro W a TRISB
    
    ;Configuración del SDO(MISO) como salida en el puerto C7
    CLRF TRISC			            ; Definimos el registro TRISC pin 7 como salida
    CLRF SSPCON1
    
    ;Configuración del Registro SSPCON1
    MOVF SSPCON1,W,ACCESS		    ; Movemos SSPCON1 al registro W
    IORLW b'10100000'			    ; Configuración de control del SPI con registro SSPBUF
    MOVWF SSPCON1,ACCESS		    ; Pasamos lo que está en el registro W a SSPCON1
    
    MOVF SSPCON1, W, ACCESS		    ; Movemos SSPCON1 al registro W
    IORLW b'00000010'			    ; Iniciamos con una frecuencia base 
    MOVWF SSPCON1, ACCESS		    ; Pasamos lo que está en el registro W a SSPCON1
    
    ;Configuración polaridad del reloj
    BCF SSPCON1,4,ACCESS		    ; El estado inactivo para el reloj es un nivel bajo
      
    ;Configuración del Registro SSPSTAT, realizar muestreo al final del tiempo de salida de datos por flanco de bajada
    BSF SSPSTAT,7,ACCESS		    ; Habilitamos muestreo por tiempo de salida de datos
    BSF SSPSTAT,6,ACCESS		    ; Habilitamos flanco de bajada
   
    ;Configuración interrupción SPI en el registro PIE
    BCF PIE1,3,ACCESS			    ; Ponemos el Registro PIE1 la deshabilitación de la interrupción de MSSP
      
    ;Prioridad de interrupción 
    CLRF IPR1				    ; Ponemos el Registro IPR1 como baja prioridad
   
    ;Definir configuración del SPI
    BCF PIR1,3,ACCESS			    ; Ponemos el Registro PIR1 en espera para transmitir o recibir
   
    ;Habilitar Configuración SPI en el pin 5
    BSF SSPCON1,5,ACCESS		    ; Habilita el puerto serie y configura SCK, SDO, SDI y SS
   
   ; RETURN				    ; Retornamos 
;--------------PROGRAMA PRINCIPAL----------------------
MAIN:
   ;----INICIA ADC-------
   MOVLW B'00000011'; ENCIENDE EL ADC Y COLOCA EL BIT DE CONVERSION EN PROGRESO
   MOVWF ADCON0
LOOP1:
   MOVLW B'00000010'
   ANDWF ADCON0,0,ACCESS; ESPERA A QUE TERMINE LA CONVERSION
   BNZ LOOP1
   ;----TERMINA ADC------
   ;------INICIA SPI-------
    MOVF    ADRESH,W 
    MOVWF data_to_send; MUEVE LA PARTE ALTA DEL ADC A W
    CALL SPI_transfer
    
    MOVF    ADRESL,W ;MUEVE LA PARTE BAJA DEL ADC  A W
    MOVWF data_to_send
    CALL SPI_transfer
    
   GOTO MAIN
   

SPI_transfer:
    ;MOVLW B'00000001'
    ;MOVWF data_to_send; 
    ;Configuraci?n de la tranferencia de datos
    MOVFF data_to_send,SSPBUF		    ; Pasamos los datos a tranferiar al Registro SSPBUF
    
Wait_transfer:
    ;Verificar si se acompleto la transferencia
    MOVLW 0x08				    ; Movemos 0x08 al registro W
    CPFSEQ PIR1,0			    ; Comparamos PIR1 = 1, entonces salta
    ;BRA Wait_transfer			    ; Repetir hasta que la transferencia se complete
    
    ;Limpiamos bandera de la interrupci?n del SPI
    BCF PIR1,3,ACCESS			    ; Ponemos el Registro PIR1 y bajamos bandera
   
    ;Obtenemos los datos del registro y lo guardamos
    MOVFF SSPBUF,save_data		    ; Pasamos los datos del Registro SSPBUF a la direcci?n de memoria save_data
   
    DELAY:
    MOVLW 0X5c
    MOVWF DCounter1
    MOVLW 0X26
    MOVWF DCounter2
    MOVLW 0X0b
    MOVWF DCounter3
LOOP:
    DECFSZ DCounter1, 1 ;decrementa 1 y salta si es cero
    GOTO LOOP
    DECFSZ DCounter2, 1
    GOTO LOOP
    DECFSZ DCounter3, 1
    GOTO LOOP

    RETURN
    ;GOTO SPI_transfer

  END