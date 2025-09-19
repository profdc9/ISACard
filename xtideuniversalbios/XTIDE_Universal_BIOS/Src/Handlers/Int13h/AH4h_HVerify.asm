; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=4h, Verify Disk Sectors.

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
; Int 13h function AH=4h, Verify Disk Sectors.
;
; AH4h_HandlerForVerifyDiskSectors
;	Parameters:
;		AL, CX, DH:	Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK in SS:BP:
;		AL:		Number of sectors to verify (1...128)
;		CH:		Cylinder number, bits 7...0
;		CL:		Bits 7...6: Cylinder number bits 9 and 8
;				Bits 5...0:	Starting sector number (1...63)
;		DH:		Starting head number (0...255)
;	Returns with INTPACK in SS:BP:
;		AH:		Int 13h/40h floppy return status
;		AL:		Number of sectors actually verified (only valid if CF set for some BIOSes)
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
AH4h_HandlerForVerifyDiskSectors:
	mov		ah, COMMAND_VERIFY_SECTORS
	call	Prepare_ByValidatingSectorsInALforOldInt13h	; Preserves AX
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRQ, FLG_STATUS_DRDY)
	push	ax			; Store number of sectors to verify
	call	Idepack_TranslateOldInt13hAddressAndIssueCommandFromAH
	pop		cx			; Number of sectors verified if successful
	jnc		SHORT .NoErrors

; TODO: For now we assume serial device do not produce verify errors
	call	AH4h_CalculateNumberOfSuccessfullyVerifiedSectors
.NoErrors:
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAHandTransferredSectorsFromCL


;--------------------------------------------------------------------
; Calculates number of succesfully verified sectors. This function works only
; if verify command stopped to an device error (such as bad sector) since IDE
; register contents are not valid unless error.
;
; AH4h_CalculateNumberOfSuccessfullyVerifiedSectors
;	Parameters:
;		AH:		INT 13h error code
;		CX:		Number of sectors that was meant to be verified
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns with INTPACK in SS:BP:
;		CX:		Number of sectors succesfully verified
;		CF:		1
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
AH4h_CalculateNumberOfSuccessfullyVerifiedSectors:
	xchg	cx, ax						; Store error code to CH
	call	Device_ReadLBAlowRegisterToAL
	sub		al, [bp+IDEPACK.bLbaLow]	; AL = sector address with verify failure - starting sector address
	xor		ah, ah
	xchg	cx, ax						; Number of successfully verified sectors in CX, error code in AH
	stc
	ret
