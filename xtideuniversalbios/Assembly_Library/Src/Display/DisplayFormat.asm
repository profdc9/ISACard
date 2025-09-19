; Project name	:	Assembly Library
; Description	:	Functions for displaying formatted strings.

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
; DisplayFormat_ParseCharacters
;	Parameters:
;		DS:		BDA segment (zero)
;		SS:BP:	Pointer to first format parameter (-=2 updates to next parameter)
;		CS:SI:	Pointer to string to format
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		CS:SI:	Ptr to end of format string (ptr to one past NULL)
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, BX, CX, DX, BP
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayFormat_ParseCharacters:
	call	ReadCharacterAndTestForNull
	jz		SHORT ReturnFromFormat

	ePUSH_T	cx, DisplayFormat_ParseCharacters	; Return address
	xor		cx, cx								; Initial placeholder size
	cmp		al, '%'								; Format specifier?
	jne		SHORT DisplayPrint_CharacterFromAL
	; Fall to ParseFormatSpecifier

;--------------------------------------------------------------------
; ParseFormatSpecifier
;	Parameters:
;		CX:		Placeholder size
;		DS:		BDA segment (zero)
;		SS:BP:	Pointer to first format parameter (-=2 for next parameter)
;		CS:SI:	Pointer to string to format
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		SI:		Updated to first unparsed character
;		DI:		Updated offset to video RAM
;		BP:		Updated to next format parameter
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
ParseFormatSpecifier:
	call	ReadCharacterAndTestForNull
	call	Char_IsDecimalDigitInAL
	jc		SHORT ParsePlaceholderSizeDigitFromALtoCX
	call	GetFormatSpecifierParserToAX
	call	ax				; Parser function
	dec		bp
	dec		bp				; SS:BP now points to next parameter
	inc		cx
	loop	PrependOrAppendSpaces
ReturnFromFormat:
	ret

;--------------------------------------------------------------------
; ParsePlaceholderSizeDigitFromALtoCX
;	Parameters:
;		AL:		Digit character from format string
;		CX:		Current placeholder size
;		DS:		BDA segment (zero)
;	Returns:
;		CX:		Current placeholder size
;		Jumps back to ParseFormatSpecifier
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
ParsePlaceholderSizeDigitFromALtoCX:
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition], di
	sub		al, '0'				; Digit '0'...'9' to integer 0...9
	mov		ah, cl				; Previous number parameter to AH
	aad							; AL += (AH * 10)
	mov		cl, al				; Updated number parameter now in CX
	jmp		SHORT ParseFormatSpecifier


;--------------------------------------------------------------------
; ReadCharacterAndTestForNull
;	Parameters:
;		CS:SI:	Pointer next character from string
;	Returns:
;		AL:		Character from string
;		SI:		Incremented to next character
;		ZF:		Set if NULL, cleared if valid character
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
ReadCharacterAndTestForNull:
	cs lodsb								; Load from CS:SI to AL
	test	al, al							; NULL to end string?
	ret


;--------------------------------------------------------------------
; GetFormatSpecifierParserToAX
;	Parameters:
;		AL:		Format specifier character
;	Returns:
;		AX:		Offset to parser function
;	Corrupts registers:
;		AX, BX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
GetFormatSpecifierParserToAX:
	mov		bx, .rgcFormatCharToLookupIndex
ALIGN DISPLAY_JUMP_ALIGN
.CheckForNextSpecifierParser:
	cmp		al, [cs:bx]
	je		SHORT .ConvertIndexToFunctionOffset
	inc		bx
	cmp		bx, .rgcFormatCharToLookupIndexEnd
	jb		SHORT .CheckForNextSpecifierParser
	mov		ax, c_FormatCharacter
	ret
ALIGN DISPLAY_JUMP_ALIGN
.ConvertIndexToFunctionOffset:
	sub		bx, .rgcFormatCharToLookupIndex
	eSHL_IM	bx, 1				; Shift for WORD lookup
	mov		ax, [cs:bx+.rgfnFormatSpecifierParser]
	ret

.rgcFormatCharToLookupIndex:
%ifndef EXCLUDE_FROM_XUB
	db		"aIAduxsSctz-+%"
%else
	db		"IAuxscz-"		; Required by XTIDE Universal BIOS
%endif
.rgcFormatCharToLookupIndexEnd:
ALIGN WORD_ALIGN
.rgfnFormatSpecifierParser:
%ifndef EXCLUDE_FROM_XUB
	dw		a_FormatAttributeForNextCharacter
%endif
	dw		I_FormatDashForZero
	dw		A_FormatAttributeForRemainingString
%ifndef EXCLUDE_FROM_XUB
	dw		d_FormatSignedDecimalWord
%endif
	dw		u_FormatUnsignedDecimalWord
	dw		x_FormatHexadecimalWord
	dw		s_FormatStringFromSegmentCS
%ifndef EXCLUDE_FROM_XUB
	dw		S_FormatStringFromFarPointer
%endif
	dw		c_FormatCharacter
%ifndef EXCLUDE_FROM_XUB
	dw		t_FormatRepeatCharacter
%endif
	dw		z_FormatStringFromSegmentZero
	dw		PrepareToPrependParameterWithSpaces
%ifndef EXCLUDE_FROM_XUB
	dw		PrepareToAppendSpacesAfterParameter
	dw		percent_FormatPercent
%endif


;--------------------------------------------------------------------
; PrependOrAppendSpaces
;	Parameters:
;		CX:		Minimum length for format specifier in characters
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
PrependOrAppendSpaces:
	mov		ax, di
	sub		ax, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition]
	test	cx, cx
	js		SHORT .PrependWithSpaces
	; Fall to .AppendSpaces

;--------------------------------------------------------------------
; .AppendSpaces
;	Parameters:
;		AX:		Number of format parameter BYTEs printed
;		CX:		Minimum length for format specifier in characters
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX
;--------------------------------------------------------------------
.AppendSpaces:
	call	DisplayContext_GetCharacterOffsetToAXfromByteOffsetInAX
	sub		cx, ax
	jle		SHORT .NothingToAppendOrPrepend
	mov		al, ' '
	jmp		DisplayPrint_RepeatCharacterFromALwithCountInCX

;--------------------------------------------------------------------
; .PrependWithSpaces
;	Parameters:
;		AX:		Number of format parameter BYTEs printed
;		CX:		Negative minimum length for format specifier in characters
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
.PrependWithSpaces:
	xchg	ax, cx
	neg		ax
	call	DisplayContext_GetByteOffsetToAXfromCharacterOffsetInAX
	sub		ax, cx				; AX = BYTEs to prepend, CX = BYTEs to move
	jle		SHORT .NothingToAppendOrPrepend

	std
	push	si

	lea		si, [di-1]			; SI = Offset to last byte formatted
	add		di, ax				; DI = Cursor location after preceeding completed
	push	di
	dec		di					; DI = Offset where to move last byte formatted
	xchg	bx, ax				; BX = BYTEs to prepend
	call	.ReverseCopyCXbytesFromESSItoESDI
	xchg	ax, bx
	call	.ReversePrintAXspacesStartingFromESDI

	pop		di
	pop		si
	cld							; Restore DF
.NothingToAppendOrPrepend:
	ret

;--------------------------------------------------------------------
; .ReverseCopyCXbytesFromESSItoESDI
;	Parameters:
;		CX:		Number of bytes to copy
;		DS:		BDA segment (zero)
;		ES:SI:	Ptr to old location
;		ES:DI:	Ptr to new location
;	Returns:
;		DI:		Updated to before last character copied
;	Corrupts registers:
;		AX, CX, DX, SI
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
.ReverseCopyCXbytesFromESSItoESDI:
	test	BYTE [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bFlags], FLG_CONTEXT_ATTRIBUTES
	jz		SHORT .CopyWithoutDisplayProcessing

	CALL_WAIT_FOR_RETRACE_IF_NECESSARY_THEN rep movsb
	dec		di					; Point to preceeding character instead of attribute
	ret

ALIGN DISPLAY_JUMP_ALIGN
.CopyWithoutDisplayProcessing:
	eSEG_STR rep, es, movsb
	ret

;--------------------------------------------------------------------
; .ReversePrintAXspacesStartingFromESDI
;	Parameters:
;		AX:		Number of spaces to print
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to destination in video RAM
;	Returns:
;		DI:		Updated
;	Corrupts registers:
;		AX, CX, DX
ALIGN DISPLAY_JUMP_ALIGN
.ReversePrintAXspacesStartingFromESDI:
	call	DisplayContext_GetCharacterOffsetToAXfromByteOffsetInAX
	xchg	cx, ax				; CX = Spaces to prepend
	mov		al, ' '
	jmp		DisplayPrint_RepeatCharacterFromALwithCountInCX



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Formatting functions
;	Parameters:
;		DS:		BDA segment (zero)
;		SS:BP:	Pointer to next format parameter (-=2 updates to next parameter)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		SS:BP:	Points to last WORD parameter used
;	Corrupts registers:
;		AX, BX, DX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%ifndef EXCLUDE_FROM_XUB
ALIGN DISPLAY_JUMP_ALIGN
a_FormatAttributeForNextCharacter:
	mov		bl, [bp]
	xchg	bl, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute]
	push	bx
	push	cx
	push	di
	call	DisplayFormat_ParseCharacters	; Recursive call
	pop		WORD [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition]
	pop		cx
	pop		bx
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute], bl
	ret
%endif

ALIGN DISPLAY_JUMP_ALIGN
A_FormatAttributeForRemainingString:
	mov		al, [bp]
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute], al
	ret

%ifndef EXCLUDE_FROM_XUB
ALIGN DISPLAY_JUMP_ALIGN
d_FormatSignedDecimalWord:
	mov		ax, [bp]
	mov		bl, 10
	jmp		DisplayPrint_SignedWordFromAXWithBaseInBL
%endif

ALIGN DISPLAY_JUMP_ALIGN
u_FormatUnsignedDecimalWord:
	mov		ax, [bp]
	mov		bl, 10
	jmp		DisplayPrint_WordFromAXWithBaseInBL

ALIGN DISPLAY_JUMP_ALIGN
x_FormatHexadecimalWord:
	mov		ax, [bp]
	mov		bl, 16
	call	DisplayPrint_WordFromAXWithBaseInBL
	mov		al, 'h'
	jmp		DisplayPrint_CharacterFromAL

ALIGN DISPLAY_JUMP_ALIGN
I_FormatDashForZero:
	cmp		WORD [bp], 0
	jne		SHORT u_FormatUnsignedDecimalWord
	mov		WORD [bp], g_szDashForZero
;;; fall-through

ALIGN DISPLAY_JUMP_ALIGN
s_FormatStringFromSegmentCS:
	push	si
	push	cx
	mov		si, [bp]

	cmp		si, BYTE 7Fh		; well within the boundaries of ROMVARS_size
	jb		.notFormatted

	dec		bp
	dec		bp
	call	DisplayFormat_ParseCharacters
	inc		bp					; will be decremented after the call is done
	inc		bp
	jmp		.done

.notFormatted:
	call	DisplayPrint_NullTerminatedStringFromCSSI

.done:
	pop		cx
	pop		si
	ret

ALIGN DISPLAY_JUMP_ALIGN
z_FormatStringFromSegmentZero:
	xchg	si, [bp]
	xor		bx, bx
	call	DisplayPrint_NullTerminatedStringFromBXSI
	mov		si, [bp]
	ret

%ifndef EXCLUDE_FROM_XUB
ALIGN DISPLAY_JUMP_ALIGN
S_FormatStringFromFarPointer:
	mov		bx, [bp-2]
	xchg	si, [bp]
	call	DisplayPrint_NullTerminatedStringFromBXSI
	mov		si, [bp]
	dec		bp
	dec		bp
	ret
%endif

ALIGN DISPLAY_JUMP_ALIGN
c_FormatCharacter:
	mov		al, [bp]
	jmp		DisplayPrint_CharacterFromAL

%ifndef EXCLUDE_FROM_XUB
ALIGN DISPLAY_JUMP_ALIGN
t_FormatRepeatCharacter:
	push	cx
	mov		cx, [bp-2]
	mov		al, [bp]
	call	DisplayPrint_RepeatCharacterFromALwithCountInCX
	pop		cx
	dec		bp
	dec		bp
	ret

ALIGN DISPLAY_JUMP_ALIGN
percent_FormatPercent:
	mov		al, '%'
	jmp		DisplayPrint_CharacterFromAL
%endif

ALIGN DISPLAY_JUMP_ALIGN
PrepareToPrependParameterWithSpaces:
	neg		cx
	; Fall to PrepareToAppendSpacesAfterParameter

ALIGN DISPLAY_JUMP_ALIGN
PrepareToAppendSpacesAfterParameter:
	add		sp, BYTE 2				; Remove return offset
	jmp		ParseFormatSpecifier
