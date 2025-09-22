; Project name	:	Assembly Library
; Description	:	SD Support

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


%include "SDServer.inc"

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; SDServer_SendReceive
;	Parameters:
;		DX:		I/O port
;		ES:SI:	Ptr to buffer (for data transfer commands)
;		SS:BP:	Ptr to SDServer_Command structure
;	Returns:
;		AH:		INT 13h Error Code
;		CX:		Number of 512-byte blocks transferred
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
SDServer_SendReceive:
	push	si
	push	di
	push	bp

;-----------------------------------------------------------------------
; Set up Port 2 mode on 8255 again if for some reason it got reset
	add		dl,SD_8255_Control_Port
	mov		al,0FAh
	out		dx,al		; initialize 8255 mode 2
	sub		dl,SD_8255_Control_Port

	mov		al, [bp+SDServer_Command.bSectorCount]
	mov		ah, [bp+SDServer_Command.bCommand]

;
; Command byte and sector count live at the top of the stack, pop/push are used to access
;
	push	ax							; save sector count for return value
	push	ax							; working copy on the top of the stack

%ifndef EXCLUDE_FROM_XUB				; DF already cleared in Int13h.asm
%ifdef CLD_NEEDED
	cld
%endif
%endif

;----------------------------------------------------------------------
;
; Send Command
;
; Sends first six bytes of IDEREGS_AND_INTPACK as the command
;
	push	es							; save off real buffer location
	push	si

	mov		si, bp						; point to IDEREGS for command dispatch;
	push	ss
	pop		es

	mov		cx, 6						; writing 6 bytes

	mov		bl,dl						; prepare BH for correct offsets
	add		bl,SD_8255_Port_C
	mov		bh,bl
	mov		bl,dl
	add		bl,SD_8255_Port_A

	call	SDServer_WriteBytes.SendAByte

	pop		di							; restore real buffer location (note change from SI to DI)
										; Buffer is primarily referenced through ES:DI throughout, since
										; we need to store (read sector) faster than we read (write sector)
	pop		es

	pop		ax							; load command byte (done before call to .nextSector on subsequent iterations)
	push	ax

%ifndef SDServer_NO_ZERO_SECTOR_COUNTS
	test	al, al						; if no sectors to be transferred, wait for the ACK checksum on the command
	jz		SHORT .zeroSectors
%endif

;
; Top of the read/write loop, one iteration per sector
;
.nextSector:
	mov		cx, 0200h					; reading/writing 512 bytes

	sahf								; command byte, are we doing a write?
	jnc		SHORT .readDataBlock

	xchg	si, di						; swap pointer and checksum, will be re-swap'ed in WriteBytes
	call	SDServer_WriteBytes.SendAByte
	jmp		SHORT .decSector

.readDataBlock:
.readDataBlock1:
	mov		dl,bh
.readDataBlock2:
	in		al,dx
	test	al,020h
	jz		SHORT .readDataBlock2
	mov		dl,bl
	in		al,dx
	stosb								; store in caller's data buffer
	loop	.readDataBlock1

.decSector:
	pop		ax							; sector count and command byte
	dec		al							; decrement sector count
	push	ax							; save
	jnz		SHORT .nextSector

.zeroSectors:
	mov		dl,bh						; read status byte
.waitReadStatus:
	in		al,dx
	test	al,020h
	jz		SHORT .waitReadStatus
	mov		dl,bl
	in		al,dx

;---------------------------------------------------------------------------
;
; Cleanup, error reporting, and exit
;

ALIGN JUMP_ALIGN
SDServer_OutputWithParameters_ReturnCodeInAL:
	mov		ah, al						; for success, AL will already be zero

	pop		bx							; recover "ax" (command and count) from stack
	pop		cx							; recover saved sector count
	xor		ch, ch
	sub		cl, bl						; subtract off the number of sectors that remained

	pop		bp
	pop		di
	pop		si

	sahf								; error return code to CF
	ret

;--------------------------------------------------------------------
; SDServer_WriteBytes
; 
; Parameters:
;
;	Parameters:
;		ES:SI:	Ptr to buffer
;		CX:		Bytes to write
;		DX:		I/O Port
;	Returns:
;		CX:		Zero
;		DL:		Port C address
;		ES:DI:	Ptr to buffer
;	Corrupts registers:
;		AX BX
;--------------------------------------------------------------------
SDServer_WriteBytes:
;	mov		bl,dl
;	add		bl,SD_8255_Port_C
;	mov		bh,bl
;	mov		bl,dl
;	add		bl,SD_8255_Port_A
.SendAByte:
	es lodsw
	mov		dl,bl
	out		dx,al
	mov		dl,bh
.WaitForReceive:
	in		al,dx
	test	al,080h
	jz		SHORT .WaitForReceive
	loop	.SendAByte
	xchg	si, di
	ret
