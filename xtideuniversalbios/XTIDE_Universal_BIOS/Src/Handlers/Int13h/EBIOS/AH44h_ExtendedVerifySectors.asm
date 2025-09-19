; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=44h, Extended Verify Sectors.

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
; Int 13h function AH=44h, Extended Verify Sectors.
;
; AH44h_HandlerForExtendedVerifySectors
;	Parameters:
;		SI:		Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		DS:SI:	Ptr to Disk Address Packet
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Return with Disk Address Packet in INTPACK:
;		.wSectorCount	Number of sectors verified successfully
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
AH44h_HandlerForExtendedVerifySectors:
	call	Prepare_ByLoadingDapToESSIandVerifyingForTransfer
	push	WORD [es:si+DAP.wSectorCount]				; Store for successful number of sectors transferred
	mov		ah, [cs:bx+g_rgbVerifyCommandLookup]
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRQ, FLG_STATUS_DRDY)
	call	Idepack_ConvertDapToIdepackAndIssueCommandFromAH

	; Now we need number of succesfully verifed sectors to CX. Since we did not transfer anything,
	; we did not have any sector counter like in read and write functions.
	; In case of error, drive LBA registers are set to address where the error occurred. We must
	; calculate number of succesfully transferred sectors from it.
	pop		cx
	jnc		SHORT .AllSectorsVerifiedSuccessfully

; TODO: For now we assume serial device do not produce verify errors
	call	AH4h_CalculateNumberOfSuccessfullyVerifiedSectors

ALIGN JUMP_ALIGN
.AllSectorsVerifiedSuccessfully:
	jmp		SHORT AH42h_ReturnFromInt13hAfterStoringErrorCodeFromAHandTransferredSectorsFromCX
