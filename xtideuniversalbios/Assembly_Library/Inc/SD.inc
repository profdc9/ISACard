; Project name	:	AssemblyLibrary
; Description	:	Defines for display library.

%ifndef SD_INC
%define SD_INC


SD_8255_Port_A							EQU		0
SD_8255_Port_B							EQU		1
SD_8255_Port_C							EQU		2
SD_8255_Control_Port					EQU		3

;----------------------------------------------------------------------
;
; Addresses to look for 8255 at
;
;
PORT_8255_ADR1			EQU		330h
PORT_8255_ADR2			EQU		390h
PORT_8255_ADR3			EQU		2b0h
PORT_8255_ADR4			EQU		300h

%endif
