; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions for accessing file and flash buffers.

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
; Buffers_Clear
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_Clear:
	call	Buffers_GetFileBufferToESDI
	mov		cx, ROMVARS_size
	jmp		Memory_ZeroESDIwithSizeInCX


;--------------------------------------------------------------------
; Buffers_IsXtideUniversalBiosLoaded
;	Parameters:
;		Nothing
;	Returns:
;		ZF:		Set if supported version of XTIDE Universal BIOS is loaded
;				Cleared if no file or some other file is loaded
;	Corrupts registers:
;		CX, SI, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_IsXtideUniversalBiosLoaded:
	test	BYTE [cs:g_cfgVars+CFGVARS.wFlags], FLG_CFGVARS_FILELOADED | FLG_CFGVARS_ROMLOADED
	jnz		SHORT .FileOrBiosLoaded
	test	sp, sp		; Clear ZF
	ret

.FileOrBiosLoaded:
	call	Buffers_GetFileBufferToESDI
	; Fall to Buffers_IsXtideUniversalBiosSignatureInESDI


;--------------------------------------------------------------------
; Buffers_IsXtideUniversalBiosSignatureInESDI
;	Parameters:
;		ES:DI:	Ptr to possible XTIDE Universal BIOS location
;	Returns:
;		ZF:		Set if supported version of XTIDE Universal BIOS is loaded
;				Cleared if no file or some other file is loaded
;	Corrupts registers:
;		CX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_IsXtideUniversalBiosSignatureInESDI:
	push	di

	mov		si, g_sXtideUniversalBiosSignature
	add		di, BYTE ROMVARS.rgbSign
	mov		cx, XTIDE_SIGNATURE_LENGTH / 2
%ifdef CLD_NEEDED
	cld
%endif
	eSEG_STR repe, cs, cmpsw

	pop		di
	ret


;--------------------------------------------------------------------
; Buffers_IsXTbuildLoaded
;	Parameters:
;		Nothing
;	Returns:
;		ZF:		Set if XT or XT+ build is loaded
;				Cleared if some other (AT, 386) build is loaded
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_IsXTbuildLoaded:
%strlen BUILD_TYPE_OFFSET	TITLE_STRING_START
	push	es
	push	di
	call	Buffers_GetFileBufferToESDI
	cmp		WORD [es:di+ROMVARS.szTitle+BUILD_TYPE_OFFSET+1], 'XT'	; +1 is for '('
	pop		di
	pop		es
	ret
%undef BUILD_TYPE_OFFSET


;--------------------------------------------------------------------
; Buffers_NewBiosWithSizeInDXCXandSourceInALhasBeenLoadedForConfiguration
;	Parameters:
;		AL:		EEPROM source (FLG_CFGVARS_FILELOADED or FLG_CFGVARS_ROMLOADED)
;		DX:CX:	EEPROM size in bytes
;	Returns:
;		Nothing
;	Corrupts registers:
;		CX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_NewBiosWithSizeInDXCXandSourceInALhasBeenLoadedForConfiguration:
	and		BYTE [cs:g_cfgVars+CFGVARS.wFlags], ~(FLG_CFGVARS_FILELOADED | FLG_CFGVARS_ROMLOADED | FLG_CFGVARS_UNSAVED)
	or		[cs:g_cfgVars+CFGVARS.wFlags], al
	shr		dx, 1
	rcr		cx, 1
	adc		cx, BYTE 0		; Round up to next WORD
	mov		[cs:g_cfgVars+CFGVARS.wImageSizeInWords], cx
	ret


;--------------------------------------------------------------------
; Buffers_SetUnsavedChanges
; Buffers_ClearUnsavedChanges
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_SetUnsavedChanges:
	or		BYTE [cs:g_cfgVars+CFGVARS.wFlags], FLG_CFGVARS_UNSAVED
	ret

ALIGN JUMP_ALIGN
Buffers_ClearUnsavedChanges:
	and		BYTE [cs:g_cfgVars+CFGVARS.wFlags], ~FLG_CFGVARS_UNSAVED
	ret


;--------------------------------------------------------------------
; Buffers_SaveChangesIfFileLoaded
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_SaveChangesIfFileLoaded:
	mov		al, [cs:g_cfgVars+CFGVARS.wFlags]
	and		al, FLG_CFGVARS_FILELOADED | FLG_CFGVARS_UNSAVED
	jz		SHORT .NothingToSave
	jpo		SHORT .NothingToSave
	mov		bx, g_szDlgSaveChanges
	call	Dialogs_DisplayYesNoResponseDialogWithTitleStringInBX
	jnz		SHORT .NothingToSave
	jmp		BiosFile_SaveUnsavedChanges
ALIGN JUMP_ALIGN
.NothingToSave:
	ret


;--------------------------------------------------------------------
; Buffers_AppendZeroesIfNeeded
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_AppendZeroesIfNeeded:
	push	es

	eMOVZX	di, [cs:g_cfgVars+CFGVARS.bEepromType]
	mov		cx, [cs:di+g_rgwEepromTypeToSizeInWords]
	sub		cx, [cs:g_cfgVars+CFGVARS.wImageSizeInWords]	; CX = WORDs to append
	jbe		SHORT .NoNeedToAppendZeroes

	call	Buffers_GetFileBufferToESDI
	mov		ax, [cs:g_cfgVars+CFGVARS.wImageSizeInWords]
	eSHL_IM	ax, 1
	add		di, ax			; ES:DI now point first unused image byte
	xor		ax, ax
%ifdef CLD_NEEDED
	cld
%endif
	rep stosw
ALIGN JUMP_ALIGN
.NoNeedToAppendZeroes:
	pop		es
	ret


;--------------------------------------------------------------------
; Buffers_GenerateChecksum
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_GenerateChecksum:
	push	es
	push	dx

	call	Buffers_GetFileBufferToESDI
	call	EEPROM_GetXtideUniversalBiosSizeFromESDItoDXCX
%ifdef CLD_NEEDED
	cld
%endif

; Compatibility fix for 3Com 3C503 cards where the ASIC returns 8080h as the last two bytes of the ROM.

	; Assume the BIOS size is not 8K, ie generate a normal checksum.
	dec		cx
	mov		ax, 100h
	cmp		cx, 8192 - 1
	jne		SHORT .BiosSizeIsNot8K
	; The BIOS size is 8K and therefore a potential candidate for a 3Com 3C503 card.
	mov		cl, (8192 - 3) & 0FFh
	mov		ah, 3
ALIGN JUMP_ALIGN
.BiosSizeIsNot8K:
.SumNextByte:
	add		al, [es:di]
	inc		di
	loop	.SumNextByte
.NextChecksumByte:
	neg		al
	stosb
	dec		ah
	jnz		SHORT .NextChecksumByte

	pop		dx
	pop		es
	ret


;--------------------------------------------------------------------
; Buffers_GetRomvarsFlagsToAX
;	Parameters:
;		Nothing
;	Returns:
;		AX:		ROMVARS.wFlags
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_GetRomvarsFlagsToAX:
	mov		bx, ROMVARS.wFlags
	; Fall to Buffers_GetRomvarsValueToAXfromOffsetInBX

;--------------------------------------------------------------------
; Buffers_GetRomvarsValueToAXfromOffsetInBX
;	Parameters:
;		BX:		ROMVARS offset
;	Returns:
;		AX:		Value
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_GetRomvarsValueToAXfromOffsetInBX:
	push	es
	push	di
	call	Buffers_GetFileBufferToESDI
	mov		ax, [es:bx+di]
	pop		di
	pop		es
	ret


;--------------------------------------------------------------------
; Buffers_GetIdeControllerCountToCX
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		CX:		Number of IDE controllers to configure
;		ES:DI:	Ptr to file buffer
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_GetIdeControllerCountToCX:
	xor		cx, cx
	call	Buffers_GetFileBufferToESDI
	or		cl, [es:di+ROMVARS.bIdeCnt]
	jnz		SHORT .LimitControllerCountForLiteMode
	inc		cx				; Make sure there is at least one controller

.LimitControllerCountForLiteMode:
	test	BYTE [es:di+ROMVARS.wFlags], FLG_ROMVARS_FULLMODE
	jnz		SHORT .ReturnControllerCountInCX
	MIN_U	cl, MAX_LITE_MODE_CONTROLLERS

.ReturnControllerCountInCX:
	ret


;--------------------------------------------------------------------
; Buffers_GetFlashComparisonBufferToESDI
; Buffers_GetFileDialogItemBufferToESDI
; Buffers_GetFileBufferToESDI
;	Parameters:
;		Nothing
;	Returns:
;		ES:DI:	Ptr to file buffer
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Buffers_GetFlashComparisonBufferToESDI:
Buffers_GetFileDialogItemBufferToESDI:
	call	Buffers_GetFileBufferToESDI
	mov		di, es
	SKIP2B	f
Buffers_GetFileBufferToESDI:
	mov		di, cs
	add		di, 1000h		; Change to next 64k page
	mov		es, di
	xor		di, di			; Ptr now in ES:DI
	ret
