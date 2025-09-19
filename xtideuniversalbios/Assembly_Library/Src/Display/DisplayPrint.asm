; Project name	:	Assembly Library
; Description	:	Functions for display output.

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
; Supports following formatting types:
;	%a		Specifies attribute for next character
;	%A		Specifies attribute for remaining string (or until next %A)
;	%d		Prints signed 16-bit decimal integer
;	%u		Prints unsigned 16-bit decimal integer
;	%x		Prints 16-bit hexadecimal integer
;	%s		Prints string (from CS segment)
;	%S		Prints string (far pointer)
;	%c		Prints character
;	%t		Prints character number of times (character needs to be pushed first, then repeat times)
;	%%		Prints '%' character (no parameter pushed)
;
;	Any placeholder can be set to minimum length by specifying
;	minimum number of characters. For example %8d would append spaces
;	after integer so that at least 8 characters would be printed.
;
;	When placing '-' after number, then spaces will be used for prepending.
;	For example %8-d would prepend integer with spaces so that at least
;	8 characters would be printed.
;
; DisplayPrint_FormattedNullTerminatedStringFromCSSI
;	Parameters:
;		BP:		SP before pushing parameters
;		DS:		BDA segment (zero)
;		CS:SI:	Pointer to string to format
;		ES:DI:	Ptr to cursor location in video RAM
;		Stack:	Parameters for formatting placeholders.
;				Parameter for first placeholder must be pushed first.
;				Low word must pushed first for placeholders requiring
;				32-bit parameters (two words).
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_FormattedNullTerminatedStringFromCSSI:
	push	bp
	push	si
	push	cx
	push	bx
	push	WORD [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute]

	dec		bp					; Point BP to...
	dec		bp					; ...first stack parameter
	call	DisplayFormat_ParseCharacters

	; Pop original character attribute
	pop		ax
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute], al

	pop		bx
	pop		cx
	pop		si
	pop		bp

	ret


;--------------------------------------------------------------------
; DisplayPrint_SignedWordFromAXWithBaseInBL
;	Parameters:
;		AX:		Word to display
;		BL:		Integer base (binary=2, octal=8, decimal=10, hexadecimal=16)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, BH, DX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_SignedWordFromAXWithBaseInBL:
	sahf
	jns		SHORT DisplayPrint_WordFromAXWithBaseInBL

	push	ax
	mov		al, '-'
	call	DisplayPrint_CharacterFromAL
	pop		ax
	neg		ax
	; Fall to DisplayPrint_WordFromAXWithBaseInBL
%endif


;--------------------------------------------------------------------
; DisplayPrint_WordFromAXWithBaseInBL
;	Parameters:
;		AX:		Word to display
;		BL:		Integer base (binary=2, octal=8, decimal=10, hexadecimal=16)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, BH, DX
;--------------------------------------------------------------------
%ifndef MODULE_STRINGS_COMPRESSED
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_WordFromAXWithBaseInBL:
	push	cx

	xor		cx, cx
	xor		bh, bh				; Base now in BX
ALIGN DISPLAY_JUMP_ALIGN
.DivideLoop:
	inc		cx					; Increment character count
	xor		dx, dx				; DX:AX now holds the integer
	div		bx					; Divide DX:AX by base
	push	dx					; Push remainder
	test	ax, ax				; All divided?
	jnz		SHORT .DivideLoop	;  If not, loop

ALIGN DISPLAY_JUMP_ALIGN
PrintAllPushedDigits:			; Unused entrypoint OK
.PrintNextDigit:
	pop		ax					; Pop digit
	cmp		al, 10				; Convert binary digit in AL to ASCII hex digit ('0'-'9' or 'A'-'F')
	sbb		al, 69h
	das
	call	DisplayPrint_CharacterFromAL
	loop	.PrintNextDigit

	pop		cx
	ret
%endif ; ~MODULE_STRINGS_COMPRESSED

;--------------------------------------------------------------------
; DisplayPrint_QWordFromSSBPwithBaseInBX
;	Parameters:
;		SS:BP:	QWord to display
;		BX:		Integer base (binary=2, octal=8, decimal=10, hexadecimal=16)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX, [SS:BP]
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB OR EXCLUDE_FROM_XTIDECFG
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_QWordFromSSBPwithBaseInBX:
	push	cx

	mov		cx, bx				; CX = Integer base
	xor		bx, bx				; BX = Character count
ALIGN DISPLAY_JUMP_ALIGN
.DivideLoop:
	call	Math_DivQWatSSBPbyCX; Divide by base
	push	dx					; Push remainder
	inc		bx					; Increment character count
	cmp		WORD [bp], BYTE 0	; All divided?
	jne		SHORT .DivideLoop	;  If not, loop
	xchg	cx, bx				; Character count to CX, Integer base to BX
	jmp		SHORT PrintAllPushedDigits
%endif


;--------------------------------------------------------------------
; DisplayPrint_CharacterBufferFromBXSIwithLengthInCX
;	Parameters:
;		CX:		Buffer length (characters)
;		BX:SI:	Ptr to NULL terminated string
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB OR EXCLUDE_FROM_BIOSDRVS
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_CharacterBufferFromBXSIwithLengthInCX:
	jcxz	.NothingToPrintSinceZeroLength
	push	si
	push	cx

ALIGN DISPLAY_JUMP_ALIGN
.PrintNextCharacter:
	mov		ds, bx
	lodsb
	LOAD_BDA_SEGMENT_TO	ds, dx
	call	DisplayPrint_CharacterFromAL
	loop	.PrintNextCharacter

	pop		cx
	pop		si
.NothingToPrintSinceZeroLength:
	ret
%endif


;--------------------------------------------------------------------
; DisplayPrint_ClearScreenWithCharInALandAttributeInAH
;	Parameters:
;		AL:		Character to clear with
;		AH:		Attribute to clear with
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifdef INCLUDE_MENU_LIBRARY
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_ClearScreenWithCharInALandAttributeInAH:
	push	di
	push	cx

	xchg	cx, ax
	xor		ax, ax
	call	DisplayCursor_SetCoordinatesFromAX		; Updates DI
	call	DisplayPage_GetColumnsToALandRowsToAH
	mul		ah		; AX = AL*AH = Characters on screen
	xchg	cx, ax	; AX = Char+Attr, CX = WORDs to store
	rep stosw

	pop		cx
	pop		di
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition], di
	ret
%endif


;--------------------------------------------------------------------
; DisplayPrint_ClearAreaWithHeightInAHandWidthInAL
;	Parameters:
;		AH:		Area height
;		AL:		Area width
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB OR EXCLUDE_FROM_BIOSDRVS
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_ClearAreaWithHeightInAHandWidthInAL:
	push	si
	push	cx
	push	bx

	xchg	bx, ax							; Area size to BX
	call	DisplayCursor_GetSoftwareCoordinatesToAX
	xchg	si, ax							; Software (Y,X) coordinates now in SI
	xor		cx, cx

ALIGN DISPLAY_JUMP_ALIGN
.ClearRowLoop:
	mov		cl, bl							; Area width now in CX
	mov		al, SCREEN_BACKGROUND_CHARACTER
	call	DisplayPrint_RepeatCharacterFromALwithCountInCX

	xchg	ax, si							; Coordinates to AX
	inc		ah								; Increment row
	mov		si, ax
	call	DisplayCursor_SetCoordinatesFromAX
	dec		bh								; Decrement rows left
	jnz		SHORT .ClearRowLoop

	pop		bx
	pop		cx
	pop		si
	ret
%endif

%ifdef EXCLUDE_FROM_XUB
	%define EXCLUDE
	%ifndef MODULE_STRINGS_COMPRESSED
		%undef EXCLUDE
	%endif
	%ifdef MODULE_HOTKEYS OR MODULE_BOOT_MENU
		%undef EXCLUDE
	%endif
%endif

%ifndef EXCLUDE
;--------------------------------------------------------------------
; DisplayPrint_RepeatCharacterFromALwithCountInCX
;	Parameters:
;		AL:		Character to display
;		CX:		Repeat count
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_RepeatCharacterFromALwithCountInCX:
	jcxz	.NothingToRepeat
	push	cx

ALIGN DISPLAY_JUMP_ALIGN
.RepeatCharacter:
	push	ax
	call	DisplayPrint_CharacterFromAL
	pop		ax
	loop	.RepeatCharacter

	pop		cx
.NothingToRepeat:
	ret
%endif
%undef EXCLUDE

;--------------------------------------------------------------------
; DisplayPrint_NullTerminatedStringFromCSSI
;	Parameters:
;		CS:SI:	Ptr to NULL terminated string
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifndef MODULE_STRINGS_COMPRESSED
;;;
;;; Take care when using this routine with compressed strings (which is why it is disabled).
;;; All strings in CSSI should go through the DisplayFormatCompressed code to be decoded.
;;;
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_NullTerminatedStringFromCSSI:
	push	bx
	mov		bx, cs
	call	DisplayPrint_NullTerminatedStringFromBXSI
	pop		bx
	ret
%endif


;;;
;;; Note that the following routines need to be at the bottom of this file
;;; to accomodate short jumps from the next file (DisplayFormat/DisplayFormatCompressed)
;;;

;--------------------------------------------------------------------
; DisplayPrint_Newline
;	Parameters:
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifdef MODULE_STRINGS_COMPRESSED
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_Newline_FormatAdjustBP:
	inc		bp					; we didn't need a parameter after all, readjust BP
	inc		bp
	; fall through to DisplayPrint_Newline
%endif

ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_Newline:
	mov		al, LF
	call	DisplayPrint_CharacterFromAL
	mov		al, CR
	; Fall to DisplayPrint_CharacterFromAL

;--------------------------------------------------------------------
; DisplayPrint_CharacterFromAL
;	Parameters:
;		AL:		Character to display
;				Zero value is ignored (no character is printed)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_CharacterFromAL:
	test	al, al
	jz		DisplayPrint_Ret

	mov		ah, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute]
	jmp		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fnCharOut]


;--------------------------------------------------------------------
; DisplayPrint_NullTerminatedStringFromBXSI
;	Parameters:
;		DS:		BDA segment (zero)
;		BX:SI:	Ptr to NULL terminated string
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPrint_NullTerminatedStringFromBXSI:
	push	si
	push	cx

	xor		cx, cx
ALIGN DISPLAY_JUMP_ALIGN
.PrintNextCharacter:
	mov		ds, bx				; String segment to DS
	lodsb
	mov		ds, cx				; BDA segment to DS
	test	al, al				; NULL?
	jz		SHORT .EndOfString
	call	DisplayPrint_CharacterFromAL
	jmp		SHORT .PrintNextCharacter

ALIGN DISPLAY_JUMP_ALIGN
.EndOfString:
	pop		cx
	pop		si

DisplayPrint_Ret:				; random ret to jump to
	ret

