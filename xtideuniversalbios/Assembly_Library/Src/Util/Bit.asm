; Project name	:	Assembly Library
; Description	:	Functions for bit handling.

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

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Bit_GetSetCountToCXfromDXAX
;	Parameters
;		DX:AX:	Source DWORD
;	Returns:
;		CX:		Number of bits set in DX:AX
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Bit_GetSetCountToCXfromDXAX:
	push	bx

	call	Bit_GetSetCountToCXfromAX
	mov		bx, cx
	xchg	ax, dx
	call	Bit_GetSetCountToCXfromAX
	xchg	ax, dx
	add		cx, bx

	pop		bx
	ret


;--------------------------------------------------------------------
; Bit_GetSetCountToCXfromAX
;	Parameters
;		AX:		Source WORD
;	Returns:
;		CX:		Number of bits set in AX
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Bit_GetSetCountToCXfromAX:
	push	ax

	mov		cx, -1
ALIGN JUMP_ALIGN
.IncrementCX:
	inc		cx
.ShiftLoop:
	shr		ax, 1
	jc		SHORT .IncrementCX
	jnz		SHORT .ShiftLoop

	pop		ax
	ret


;--------------------------------------------------------------------
; Bit_SetToDXAXfromIndexInCL
;	Parameters:
;		CL:		Index of bit to set (0...31)
;		DX:AX:	Destination DWORD with flag to be set
;	Returns:
;		DX:AX:	DWORD with wanted bit set
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Bit_SetToDXAXfromIndexInCL:
	cmp		cl, 16
	jb		SHORT Bit_SetToAXfromIndexInCL

%ifdef USE_NEC_V
	eSET1	dx, cl				; SET1 ignores bits 7...4 in CL
%else
	sub		cl, 16
	xchg	ax, dx
	call	Bit_SetToAXfromIndexInCL
	xchg	dx, ax
	add		cl, 16
%endif
	ret


;--------------------------------------------------------------------
; Bit_SetToAXfromIndexInCL
;	Parameters:
;		CL:		Index of bit to set (0...15)
;		AX:		Destination WORD with flag to be set
;	Returns:
;		AX:		WORD with wanted bit set
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Bit_SetToAXfromIndexInCL:
%ifdef USE_NEC_V
	eSET1	ax, cl
%else
	push	dx

	mov		dx, 1
	shl		dx, cl
	or		ax, dx

	pop		dx
%endif
	ret

