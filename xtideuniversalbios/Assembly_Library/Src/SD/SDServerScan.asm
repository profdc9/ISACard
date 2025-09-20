; Project name	:	Assembly Library
; Description	:	Serial Server Support, Scan for Server

;
; This functionality is broken out from SerialServer as it may only be needed during
; initialization to find a server, and then could be discarded, (for example the case
; of a TSR).

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2013 by XTIDE Universal BIOS Team.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
;


%include "SD.inc"

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; SDServerScan_ScanForServer:
;	Parameters:
;		DX:		Port Number to Scan
;				0: Scan a known set of ports and bauds
;		ES:SI:	Ptr to buffer for return
;	Returns:
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX, DI
;--------------------------------------------------------------------
SDServerScan_ScanForServer:
	mov		cx, 1			; one sector, not scanning (default)

	test	dx, dx
	jnz		SHORT SDServerScan_CheckForServer_PortInDX

	mov		di, .scanPortAddresses-1
	mov		ch, 1			;  tell server that we are scanning

.nextPort:
	inc		di				; load next port address
	mov		dh, 40h			; Clear DH and make sure CF is set if error
	mov		dl, [cs:di]
	eSHL_IM	dx, 2			; shift from one byte to two
	jz		SHORT .error

	call	SDServer_CheckPort  ; check for the microcontroller
	jc		SHORT .nextPort

	call	SDServerScan_CheckForServer_PortInDX
	jc		SHORT .nextPort

.error:
	ret

.scanPortAddresses:
	db	PORT_8255_ADR1/4
	db	PORT_8255_ADR2/4
	db	PORT_8255_ADR3/4
	db	PORT_8255_ADR4/4
	db	0

;--------------------------------------------------------------------
; SDServer_CheckForServer_PortAndBaudInDX:
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Select Register
;				0xAx: Scan for drive, low nibble indicates drive
;				0x0:  Scan for Server, independent of drives
;		DX:		Baud and Port
;		CH:		1: We are doing a scan for the SD server
;				0: We are working off a specific port given by the user
;		CL:		1, for one sector to read
;		ES:SI:	Ptr to buffer for return
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX
;--------------------------------------------------------------------
SDServerScan_CheckForServer_PortInDX:
	push	bp				; setup fake SDServer_Command
	push	dx				; send port baud and rate, returned in inquire packet
							; (and possibly returned in the drive identification string)
	push	cx				; send number of sectors, and if it is on a scan or not
	mov		bl, SDServer_Command_Inquire		; protocol command onto stack with bh
	push	bx

	mov		bp, sp
	call	SDServer_SendReceive

	pop		bx
	pop		cx
	pop		dx
	pop		bp

	ret

;-------------------------------------------------------------------
; Port output timeout
; Outputs a byte to the 8255
;	Parameters
;		DX:		Port Number Base
;		AL:		Byte to output
;	Returns
;		CF:		Cleared if outputted, set if timed out
;	Corrupts registers
;		AL
SDOutTimeout:
	push	dx
	push	cx
	xor		cx,cx
	add		dl,SD_8255_Port_A
	out		dx,al
	add		dl,(SD_8255_Port_C-SD_8255_Port_A)
.SDOutTimeout1:
	in		al,dx
	test	al,080h
	jnz		SHORT .SDOutTimeoutRecv
	loop	.SDOutTimeout1
	stc
.SDOutTimeout2:
	pop		cx
	pop		dx
	ret
.SDOutTimeoutRecv:
	clc
	jnc		SHORT .SDOutTimeout2

;-------------------------------------------------------------------
; Port input timeout
; Outputs a byte to the 8255
;	Parameters
;		DX:		Port Number Base
;	Returns
;		CF:		Cleared if byte received, set if timed out
;		AL:		Byte input (if one is received)
SDInTimeout:
	push	dx
	push	cx
	xor		cx,cx
	add		dl,SD_8255_Port_C
.SDInTimeout1:
	in		al,dx
	test	al,020h
	jnz		SHORT .SDInTimeoutRecv
	loop	.SDInTimeout1
	stc
	jc		SHORT SDOutTimeout.SDOutTimeout2
.SDInTimeoutRecv:
	sub		dl,(SD_8255_Port_C-SD_8255_Port_A)
	in		al,dx
	clc
	jnc		SHORT SDOutTimeout.SDOutTimeout2

;-------------------------------------------------------------------
; SDServer_CheckPort
; Checks for a 8255 and responding microcontroller on port DX
;	Parameters:
;		DX:		Port Number Base   
;		ES:SI:	Ptr for buffer to return
;	Returns:
;		CF:		Cleared if success, set if error
;	Corrupts registers:
;		AX
SDServer_CheckPort:
	add		dl,SD_8255_Control_Port
	mov		al,0FAh
	out		dx,al		; initialize 8255 mode 2
	sub		dl,SD_8255_Control_Port

	push	cx
	mov		cx,4			; Try ring up byte four times
.SDServer_CheckPort1:
	mov		al,0eeh
	call	SDOutTimeout		; Output a byte
	jnc		SHORT .SDServer_NextIter
	call	SDInTimeout			; Input the response
	jnc		SHORT .SDServer_NextIter
	cmp		al,047h				; Return this byte on success
	jnz		SHORT .SDServer_NextIter

	mov		al,0edh
	call	SDOutTimeout		; Output a byte
	jnc		SHORT .SDServer_NextIter
	call	SDInTimeout			; Input the response
	jnc		SHORT .SDServer_NextIter
	cmp		al,09Ch				; Return this byte on success
	jz		SHORT .SDServer_CheckPort2

.SDServer_NextIter:
	loop	.SDServer_CheckPort1
	pop		cx					; Did not get a response
	stc
	ret
.SDServer_CheckPort2:
	clc
	ret
