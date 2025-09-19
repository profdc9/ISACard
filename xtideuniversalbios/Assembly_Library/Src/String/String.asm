; Project name	:	Assembly Library
; Description	:	Functions for handling characters.

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
; String_ConvertDSSItoLowerCase
;	Parameters:
;		DS:SI:	Ptr to string to convert
;	Returns:
;		CX:		Number of characters processed
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN STRING_JUMP_ALIGN
String_ConvertDSSItoLowerCase:
	push	dx
	push	ax

	mov		dx, StringProcess_ConvertToLowerCase
	call	StringProcess_DSSIwithFunctionInDX

	pop		ax
	pop		dx
	ret


;--------------------------------------------------------------------
; String_ConvertWordToAXfromStringInDSSIwithBaseInBX
;	Parameters:
;		BX:		Numeric base (10 or 16)
;		DS:SI:	Ptr to string to convert
;	Returns:
;		AX:		Word converted from string
;		CX:		Number of characters processed
;		CF:		Cleared if successful
;				Set if error during conversion
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN STRING_JUMP_ALIGN
String_ConvertWordToAXfromStringInDSSIwithBaseInBX:
	push	di
	push	dx

	xor		di, di
	mov		dx, StringProcess_ConvertToWordInDIWithBaseInBX
	call	StringProcess_DSSIwithFunctionInDX
	xchg	ax, di

	pop		dx
	pop		di
	ret


;--------------------------------------------------------------------
; String_CopyDSSItoESDIandGetLengthToCX
;	Parameters:
;		DS:SI:	Ptr to source NULL terminated string
;		ES:DI:	Ptr to destination buffer
;	Returns:
;		CX:		Number of characters copied
;		SI,DI:	Updated by CX characters
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN STRING_JUMP_ALIGN
String_CopyDSSItoESDIandGetLengthToCX:
	push	ax

	xor		cx, cx
ALIGN STRING_JUMP_ALIGN
.CopyNextCharacter:
	lodsb						; Load from DS:SI to AL
	test	al, al				; NULL to end string?
	jz		SHORT .EndOfString
	stosb						; Store from AL to ES:DI
	inc		cx					; Increment number of characters written
	jmp		SHORT .CopyNextCharacter

ALIGN STRING_JUMP_ALIGN
.EndOfString:
	pop		ax
	ret


;--------------------------------------------------------------------
; String_GetLengthFromDSSItoCX
;	Parameters:
;		DS:SI:	Ptr to NULL terminated string
;	Returns:
;		CX:		String length in characters
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN STRING_JUMP_ALIGN
String_GetLengthFromDSSItoCX:
	push	ax
	push	si

	call	Registers_ExchangeDSSIwithESDI
	xor		ax, ax		; Find NULL
	mov		cx, -1		; Full segment if necessary
	repne scasb
	mov		cx, di
	call	Registers_ExchangeDSSIwithESDI

	pop		si
	stc
	sbb		cx, si		; Subtract NULL
	pop		ax
	ret
