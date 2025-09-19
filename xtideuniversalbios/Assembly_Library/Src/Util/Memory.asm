; Project name	:	Assembly Library
; Description	:	Functions for memory access.

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
; OPTIMIZE_STRING_OPERATION
;	Parameters
;		%1:		String instruction without size (only MOVS and STOS is supported)
;		CX:		Number of BYTEs to operate
;		DS:SI:	Ptr to source data (for MOVS)
;		ES:DI:	Ptr to destination
;	Returns:
;		CF:		Cleared
;		CX:		Zero
;		SI, DI:	Updated by number of bytes operated
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro OPTIMIZE_STRING_OPERATION 1
	shr		cx, 1
	rep		%1w
	eRCL_IM	cx, 1
	rep		%1b
%endmacro


;--------------------------------------------------------------------
; Memory_CopyCXbytesFromDSSItoESDI
;	Parameters
;		CX:		Number of bytes to copy
;		DS:SI:	Ptr to source data
;		ES:DI:	Ptr to destination buffer
;	Returns:
;		CF:		Cleared
;		SI, DI:	Updated by number of bytes copied
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB
ALIGN JUMP_ALIGN
Memory_CopyCXbytesFromDSSItoESDI:
	push	cx
	OPTIMIZE_STRING_OPERATION movs
	pop		cx
	ret
%endif


;--------------------------------------------------------------------
; Memory_ZeroSSBPwithSizeInCX
;	Parameters
;		CX:		Number of bytes to zero
;		SS:BP:	Ptr to buffer to zero
;	Returns:
;		Nothing
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
%ifdef INCLUDE_MENU_LIBRARY
ALIGN JUMP_ALIGN
Memory_ZeroSSBPwithSizeInCX:
	push	es
	push	di
	push	ax
	call	Registers_CopySSBPtoESDI
	call	Memory_ZeroESDIwithSizeInCX
	pop		ax
	pop		di
	pop		es
	ret
%endif


;--------------------------------------------------------------------
; Memory_ZeroESDIwithSizeInCX
;	Parameters
;		CX:		Number of bytes to zero
;		ES:DI:	Ptr to destination buffer
;	Returns:
;		DI:		Updated by number of BYTEs stored
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Memory_ZeroESDIwithSizeInCX:
	xor		ax, ax
	; Fall to Memory_StoreCXbytesFromAccumToESDI

;--------------------------------------------------------------------
; Memory_StoreCXbytesFromAccumToESDI
;	Parameters
;		AX:		Word to use to fill buffer
;		CX:		Number of BYTEs to store
;		ES:DI:	Ptr to destination buffer
;	Returns:
;		DI:		Updated by number of BYTEs stored
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
Memory_StoreCXbytesFromAccumToESDI:
	OPTIMIZE_STRING_OPERATION stos
	ret


;--------------------------------------------------------------------
; Memory_ReserveCLbytesFromStackToDSSI
; Memory_ReserveCXbytesFromStackToDSSI
;	Parameters
;		CL/CX:	Number of bytes to reserve
;	Returns:
;		DS:SI:	Ptr to reserved buffer
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB
ALIGN JUMP_ALIGN
Memory_ReserveCLbytesFromStackToDSSI:
	xor		ch, ch
Memory_ReserveCXbytesFromStackToDSSI:
	pop		ax
	push	ss
	pop		ds
	sub		sp, cx
	mov		si, sp
	jmp		ax
%endif


;--------------------------------------------------------------------
; Memory_SumCXbytesFromESSItoAL
;	Parameters
;		CX:		Number of bytes to sum (0=65536)
;		ES:SI:	Ptr to buffer containing the bytes to sum
;	Returns:
;		AL:		Sum of bytes
;		ZF:		Set if result is zero
;				Cleared if result is non-zero
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDECFG OR NO_ATAID_VALIDATION
ALIGN JUMP_ALIGN
Memory_SumCXbytesFromESSItoAL:
	push	si
	dec		si
	xor		al, al
ALIGN JUMP_ALIGN
.AddNextByteToAL:
	inc		si
	add		al, [es:si]
	loop	.AddNextByteToAL
	pop		si
	ret
%endif
