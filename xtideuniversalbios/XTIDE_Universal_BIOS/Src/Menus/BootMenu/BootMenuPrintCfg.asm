; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for printing drive configuration
;					information on Boot Menu.
;
; Included by BootMenuPrint.asm, this routine is to be inserted into
; BootMenuPrint_RefreshInformation.
;

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

;;; fall-into from BootMenuPrint_RefreshInformation.

;--------------------------------------------------------------------
; Prints Hard Disk configuration for drive handled by our BIOS.
; Cursor is set to configuration header string position.
;
; .BootMenuPrintCfg_ForOurDrive
;	Parameters:
;		DS:DI:		Pointer to DPT
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, DX
;--------------------------------------------------------------------
.BootMenuPrintCfg_ForOurDrive:
	; Fall to .PushAddressingMode

;--------------------------------------------------------------------
; .PushAddressingMode
;	Parameters:
;		DS:DI:	Ptr to DPT
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX, BX, DX
;--------------------------------------------------------------------
.PushAddressingMode:
	mov		al, [di+DPT.bFlagsLow]
	and		ax, BYTE MASKL_DPT_TRANSLATEMODE
	;;
	;; This multiply both shifts the addressing mode bits down to low order bits, and
	;; at the same time multiplies by the size of the string displacement.  The result is in AH,
	;; with AL clear, and so we exchange AL and AH after the multiply for the final result.
	;;
%ifdef USE_186
	imul	ax, g_szAddressingModes_Displacement << (8-TRANSLATEMODE_FIELD_POSITION)
%else
	mov		bx, g_szAddressingModes_Displacement << (8-TRANSLATEMODE_FIELD_POSITION)
	mul		bx
%endif
	xchg	al, ah		; AL = always zero after above multiplication
	add		ax, g_szAddressingModes
	push	ax
	; Fall to .PushBlockMode

;--------------------------------------------------------------------
; .PushBlockMode
;	Parameters:
;		DS:DI:	Ptr to DPT
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
.PushBlockMode:
	mov		ax, 1
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_USE_BLOCK_MODE_COMMANDS
	jz		SHORT .PushBlockSizeFromAX
	mov		al, [di+DPT_ATA.bBlockSize]
.PushBlockSizeFromAX:
	push	ax
	; Fall to .PushDeviceType

;--------------------------------------------------------------------
; .PushDeviceType
;	Parameters:
;		DS:DI:	Ptr to DPT
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX, BX
;--------------------------------------------------------------------
.PushDeviceType:
	call	AccessDPT_GetIdevarsToCSBX
	mov		ah, [cs:bx+IDEVARS.bDevice]
%ifdef MODULE_SD
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SERIAL_DEVICE	; Clears CF
	jz		SHORT .PushDeviceType1
%endif
%ifdef MODULE_SD
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SD_DEVICE	; Clears CF
	jz		SHORT .PushDeviceType1
%endif
	jnz		SHORT .PushDeviceType2
.PushDeviceType1:
	mov		ah, [di+DPT_ATA.bDevice]	; DPT_ATA contains up to date device information for IDE drives
.PushDeviceType2:
	mov		al, g_szDeviceTypeValues_Displacement
	mul		ah

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
	%if (COUNT_OF_ALL_IDE_DEVICES * 2 * g_szDeviceTypeValues_Displacement) > 255
		%error "The USE_UNDOC_INTEL block in .PushDeviceType needs to be removed (would cause an overflow)!"
	%endif
%endif

	shr		ax, 1	; Divide by 2 since IDEVARS.bDevice is multiplied by 2
	add		ax, g_szDeviceTypeValues
	push	ax
	; Fall to .PushIRQ

;--------------------------------------------------------------------
; .PushIRQ
;	Parameters:
;		DS:DI:	Ptr to DPT
;		CS:BX:	Ptr to IDEVARS
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
.PushIRQ:
	mov		al, [cs:bx+IDEVARS.bIRQ]
	cbw
	push	ax
	; Fall to .PushResetStatus

;--------------------------------------------------------------------
; .PushResetStatus
;	Parameters:
;		DS:DI:	Ptr to DPT
;		CS:BX:	Ptr to IDEVARS
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
.PushResetStatus:
	mov		al, [di+DPT.bInitError]
	push	ax

;;; fall-out to BootMenuPrint_RefreshInformation.
