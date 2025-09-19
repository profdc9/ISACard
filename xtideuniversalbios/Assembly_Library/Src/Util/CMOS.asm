; Project name	:	Assembly Library
; Description	:	Functions for accessing CMOS.

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2018 by XTIDE Universal BIOS Team.
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


;--------------------------------------------------------------------
; CMOS_WriteALtoIndexInDL
;	Parameters:
;		AL:		Byte to write
;		DL:		CMOS address to write to
;	Returns:
;		Interrupts enabled and NMI disabled
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
CMOS_WriteALtoIndexInDL:
	push	ax
	call	SetDLtoIndexRegister
	pop		ax
	out		CMOS_DATA_REGISTER, al
	sti
	ret


;--------------------------------------------------------------------
; CMOS_ReadFromIndexInDLtoAL
;	Parameters:
;		DL:		CMOS address to read from
;	Returns:
;		AL:		Byte read from CMOS
;		Interrupts enabled and NMI disabled
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
CMOS_ReadFromIndexInDLtoAL:
	call	SetDLtoIndexRegister
	in		al, CMOS_DATA_REGISTER
	sti
	ret


;--------------------------------------------------------------------
; SetDLtoIndexRegister
;	Parameters:
;		DL:		CMOS address to select
;	Returns:
;		Interrupts disabled and NMI disabled
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
SetDLtoIndexRegister:
	mov		al, dl
	or		al, FLG_CMOS_INDEX_NMI_DISABLE	; Disable NMI
	cli
	out		CMOS_INDEX_REGISTER, al
	ret		; Return works as I/O delay


;--------------------------------------------------------------------
; CMOS_Verify10hTo2Dh
;	Parameters:
;		Nothing
;	Returns:
;		ZF:		Set if valid checksum
;		Interrupts disabled and NMI disabled
;	Corrupts registers:
;		AX, CX, DX
;--------------------------------------------------------------------
CMOS_Verify10hTo2Dh:
	; Get checksum WORD from CMOS
	mov		dl, CHECKSUM_OF_BYTES_10hTo2Dh_HIGH
	call	CMOS_ReadFromIndexInDLtoAL
	xchg	ah, al
	inc		dx			; CHECKSUM_OF_BYTES_10hTo2Dh_LOW
	call	CMOS_ReadFromIndexInDLtoAL
	push	ax			; Store checksum word

	; Verify checksum
	call	GetSumOfBytes10hto2DhtoCX
	pop		ax
	cmp		ax, cx		; ZF set if checksum verified
	ret


;--------------------------------------------------------------------
; CMOS_StoreNewChecksumFor10hto2Dh
;	Parameters:
;		Nothing
;	Returns:
;		Interrupts disabled and NMI disabled
;	Corrupts registers:
;		AX, CX, DX
;--------------------------------------------------------------------
CMOS_StoreNewChecksumFor10hto2Dh:
	call	GetSumOfBytes10hto2DhtoCX

	; Write it to CMOS
	xchg	ax, cx
	mov		dl, CHECKSUM_OF_BYTES_10hTo2Dh_LOW
	call	CMOS_WriteALtoIndexInDL
	xchg	al, ah
	dec		dx			; CHECKSUM_OF_BYTES_10hTo2Dh_HIGH
	jmp		SHORT CMOS_WriteALtoIndexInDL


;--------------------------------------------------------------------
; GetSumOfBytes10hto2DhtoCX
;	Parameters:
;		Nothing
;	Returns:
;		CX:		Sum of CMOS bytes 10h to 2Dh
;		Interrupts disabled and NMI disabled
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
GetSumOfBytes10hto2DhtoCX:
	xor		cx, cx			; Sum
	mov		dl, 10h			; First index
	xor		ah, ah

.AddNextByte:
	call	CMOS_ReadFromIndexInDLtoAL
	add		cx, ax
	inc		dx
	cmp		dl, 2Dh			; Last index
	jbe		SHORT .AddNextByte
	ret
