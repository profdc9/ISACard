; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=24h, Set Multiple Blocks.

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
; Int 13h function AH=24h, Set Multiple Blocks.
;
; AH24h_HandlerForSetMultipleBlocks
;	Parameters:
;		AL:		Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		AL:		Number of Sectors per Block (1, 2, 4, 8, 16, 32, 64 or 128)
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH24h_HandlerForSetMultipleBlocks:
%ifndef USE_186
	call	AH24h_SetBlockSize
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%else
	push	Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
	; Fall to AH24h_SetBlockSize
%endif


;--------------------------------------------------------------------
; AH24h_SetBlockSize
;	Parameters:
;		AL:		Number of Sectors per Block (1, 2, 4, 8, 16, 32, 64 or 128)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, CX, DX
;--------------------------------------------------------------------
AH24h_SetBlockSize:
%ifdef MODULE_8BIT_IDE_ADVANCED
	; XT-CF does not support largest block size in DMA mode.
	cmp		al, XTCF_DMA_MODE_MAX_BLOCK_SIZE
	jbe		SHORT .NoNeedToLimitBlockSize

	; Return error if we tried too large block for XT-CF.
	; Do not limit it to maximum supported since software calling AH=24h
	; must know what the actual block size is.
	cmp		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_XTCF_DMA
	je		SHORT ProcessXTCFsubcommandFromAL.AH1Eh_LoadInvalidCommandToAHandSetCF
.NoNeedToLimitBlockSize:
%endif ; MODULE_8BIT_IDE_ADVANCED

	push	bx

	push	ax			; Store block size for later use
	xchg	dx, ax		; DL = Block size (Sector Count Register)
	mov		al, COMMAND_SET_MULTIPLE_MODE
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRDY, FLG_STATUS_DRDY)
	call	Idepack_StoreNonExtParametersAndIssueCommandFromAL

	; Disable block mode if failure or if called with block size of 1 sector.
	; Some drives allow block mode commands for 1 sector blocks and some do not.
	pop		bx			; Pop block size to BL
	jc		SHORT .DisableBlockMode

	; All valid block sizes are powers of 2 which means BL have just one bit set (parity odd).
	; Incrementing BX will cause all block sizes except 1 to have two bits set (parity even).
	; Note that PF reflects only the lowest 8 bits of any register being modified.
	inc		bx						; 1 -> 2 ?
	jpo		SHORT .DisableBlockMode	; Jump if BL = 2
	dec		bx						; Restore block size (was larger than 1)

	; Enable block mode and store block size
	or		BYTE [di+DPT.bFlagsHigh], FLGH_DPT_USE_BLOCK_MODE_COMMANDS
	jmp		SHORT .StoreBlockSizeFromBLandReturn

.DisableBlockMode:
	and		BYTE [di+DPT.bFlagsHigh], ~FLGH_DPT_USE_BLOCK_MODE_COMMANDS
	mov		bl, 1
	stc
.StoreBlockSizeFromBLandReturn:
	mov		[di+DPT_ATA.bBlockSize], bl
	pop		bx
	ret
