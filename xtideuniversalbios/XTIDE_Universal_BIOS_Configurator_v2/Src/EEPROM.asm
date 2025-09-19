; Project name	:	XTIDE Univeral BIOS Configurator v2
; Description	:	Functions for managing EEPROM contents.

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

; Section containing initialized data
SECTION .data

ALIGN WORD_ALIGN
g_rgwEepromTypeToSizeInWords:
	dw		(2<<10) / 2		; EEPROM_TYPE.2816_2kiB
	dw		(8<<10) / 2
	dw		(8<<10) / 2		; EEPROM_TYPE.2864_8kiB_MOD
	dw		(32<<10) / 2
	dw		(64<<10) / 2

g_rgwEepromPageToSizeInBytes:
	dw		1				; EEPROM_PAGE.1_byte
	dw		2
	dw		4
	dw		8
	dw		16
	dw		32
	dw		64



; Section containing code
SECTION .text

;--------------------------------------------------------------------
; EEPROM_LoadXtideUniversalBiosFromRomToRamBufferAndReturnSizeInDXCX
;	Parameters:
;		Nothing
;	Returns:
;		DX:CX:	BIOS size in bytes
;	Corrupts registers:
;		BX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EEPROM_LoadXtideUniversalBiosFromRomToRamBufferAndReturnSizeInDXCX:
	push	es

	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	call	EEPROM_GetXtideUniversalBiosSizeFromESDItoDXCX
	xor		si, si				; Load from beginning of ROM
	call	LoadBytesFromRomToRamBuffer

	pop		es
	ret


;--------------------------------------------------------------------
; EEPROM_GetXtideUniversalBiosSizeFromESDItoDXCX
;	Parameters:
;		ES:DI:	Ptr to XTIDE Universal BIOS
;	Returns:
;		DX:CX:	Bios size in bytes
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EEPROM_GetXtideUniversalBiosSizeFromESDItoDXCX:
	xor		dx, dx
	mov		ch, [es:di+ROMVARS.bRomSize]
	mov		cl, dl
	eSHL_IM	ch, 1
	eRCL_IM	dl, 1
	ret


;--------------------------------------------------------------------
; EEPROM_LoadOldSettingsFromRomToRamBuffer
;	Parameters:
;		Nothing
;	Returns:
;		CF:		Cleared if EEPROM was found
;				Set if EEPROM not found
;	Corrupts registers:
;		BX, CX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EEPROM_LoadOldSettingsFromRomToRamBuffer:
	mov		cx, ROMVARS_size - ROMVARS.wFlags	; Number of bytes to load
	mov		si, ROMVARS.wFlags					; Offset where to start loading
	; Fall to LoadBytesFromRomToRamBuffer

;--------------------------------------------------------------------
; LoadBytesFromRomToRamBuffer
;	Parameters:
;		CX:		Number of bytes to load from ROM
;		SI:		Offset to first byte to load
;	Returns:
;		CF:		Cleared if EEPROM was found
;				Set if EEPROM not found
;	Corrupts registers:
;		BX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
LoadBytesFromRomToRamBuffer:
	push	es
	push	ds
	push	di

	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	jc		SHORT .XtideUniversalBiosNotFound
	push	es
	pop		ds											; DS:SI points to ROM

	call	Buffers_GetFileBufferToESDI
	mov		di, si										; ES:DI points to RAM buffer

%ifdef CLD_NEEDED
	cld
%endif
	call	Memory_CopyCXbytesFromDSSItoESDI			; Clears CF

.XtideUniversalBiosNotFound:
	pop		di
	pop		ds
	pop		es
	ret


;--------------------------------------------------------------------
; EEPROM_FindXtideUniversalBiosROMtoESDI
;	Parameters:
;		Nothing
;	Returns:
;		ES:DI:	EEPROM segment
;		CF:		Cleared if EEPROM was found
;				Set if EEPROM not found
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EEPROM_FindXtideUniversalBiosROMtoESDI:
	push	si
	push	cx

	xor		di, di					; Zero DI (offset)
	mov		bx, 0C000h				; First possible ROM segment
ALIGN JUMP_ALIGN
.SegmentLoop:
	mov		es, bx					; Possible ROM segment to ES
	call	Buffers_IsXtideUniversalBiosSignatureInESDI
	je		SHORT .RomFound			; If equal, CF=0
	add		bx, 80h					; Increment by 2kB (minimum possible distance from the beginning of one option ROM to the next)
	jnc		SHORT .SegmentLoop		; Loop until segment overflows
.RomFound:
	pop		cx
	pop		si
	ret


;--------------------------------------------------------------------
; EEPROM_LoadFromRomToRamComparisonBuffer
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX, CX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EEPROM_LoadFromRomToRamComparisonBuffer:
	push	es
	push	ds

	mov		ds, [cs:g_cfgVars+CFGVARS.wEepromSegment]
	xor		si, si
	call	Buffers_GetFlashComparisonBufferToESDI
	eMOVZX	bx, [cs:g_cfgVars+CFGVARS.bEepromType]
%ifdef CLD_NEEDED
	cld
%endif
	mov		cx, [cs:bx+g_rgwEepromTypeToSizeInWords]
	rep movsw

	pop		ds
	pop		es
	ret
