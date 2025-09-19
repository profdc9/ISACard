; Project name	:	Assembly Library
; Description	:	Functions for accessing drives.

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
; Drive_GetNumberOfAvailableDrivesToAX
;	Parameters:
;		Nothing
;	Returns:
;		AX:		Number of available drives
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDECFG
ALIGN JUMP_ALIGN
Drive_GetNumberOfAvailableDrivesToAX:
	push	dx
	push	cx

	call	Drive_GetFlagsForAvailableDrivesToDXAX
	call	Bit_GetSetCountToCXfromDXAX
	xchg	ax, cx

	pop		cx
	pop		dx
	ret
%endif


;--------------------------------------------------------------------
; Drive_GetFlagsForAvailableDrivesToDXAX
;	Parameters:
;		Nothing
;	Returns:
;		DX:AX:	Flags containing valid drives (bit 0 = drive A, bit 1 = drive B ...)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Drive_GetFlagsForAvailableDrivesToDXAX:
	push	cx
	push	bx
	mov		dx, DosCritical_HandlerToIgnoreAllErrors
	call	DosCritical_InstallNewHandlerFromCSDX

	call	.GetNumberOfPotentiallyValidDriveLettersToCX
	xor		bx, bx
	xor		ax, ax				; Temporary use BX:AX for flags
	cwd							; Start from drive 0
	call	.CheckDriveValidityUntilCXisZero
	mov		dx, bx				; Flags now in DX:AX

	call	DosCritical_RestoreDosHandler
	pop		bx
	pop		cx
	ret

;--------------------------------------------------------------------
; .GetNumberOfPotentiallyValidDriveLettersToCX
;	Parameters:
;		Nothing
;	Returns:
;		CX:		Number of potentially valid drive letters available
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.GetNumberOfPotentiallyValidDriveLettersToCX:
	call	Drive_GetDefaultToAL
	xchg	dx, ax			; Default drive to DL
	call	Drive_SetDefaultFromDL
	cmp		al, 32			; Number of potentially valid drive letters available
	jb		SHORT .Below32
	mov		al, 32
.Below32:
	cbw
	xchg	cx, ax
	ret

;--------------------------------------------------------------------
; .CheckDriveValidityUntilCXisZero
;	Parameters:
;		CX:		Number of potentially valid drive letters left
;		DL:		Drive number (00h=A:, 01h=B: ...)
;		BX:AX:	Flags for drive numbers
;	Returns:
;		BX:AX:	Flags for valid drive numbers
;	Corrupts registers:
;		CX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.CheckDriveValidityUntilCXisZero:
	call	.IsValidDriveNumberInDL
	jnz		SHORT .PrepareToCheckNextDrive
	call	.SetFlagToBXAXfromDriveInDL
ALIGN JUMP_ALIGN
.PrepareToCheckNextDrive:
	inc		dx
	loop	.CheckDriveValidityUntilCXisZero
	ret

;--------------------------------------------------------------------
; .IsValidDriveNumberInDL
;	Parameters:
;		DL:		Drive number (00h=A:, 01h=B: ...)
;	Returns:
;		ZF:		Set if drive number is valid
;				Cleared if drive number is invalid
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.IsValidDriveNumberInDL:
	push	ds
	push	ax
	cmp		dl, 1
	jbe		SHORT .FloppyDrive

.MessageSuppressedByInt2FhHandler:
.MoreThanOneFloppyDrive:
.NoFloppyDrive:
	push	bx

	inc		dx			; Default drive is 00h and first drive is 01h
	mov		ax, CHECK_IF_BLOCK_DEVICE_REMOTE	; Needs DOS 3.1+
	mov		bx, dx
	push	dx
	int		DOS_INTERRUPT_21h
	pop		dx
	jnc		SHORT .DriveIsValid
	cmp		ax, ERR_DOS_INVALID_DRIVE
	je		SHORT .DriveIsNotValid
	; Fall back to old method if ERR_DOS_FUNCTION_NUMBER_INVALID

	mov		ah, GET_DOS_DRIVE_PARAMETER_BLOCK_FOR_SPECIFIC_DRIVE
	int		DOS_INTERRUPT_21h
.DriveIsValid:
.DriveIsNotValid:
	dec		dx
	test	al, al

	pop		bx
.ReturnFromFloppyDriveFiltering:
	pop		ax
	pop		ds
	ret

.FloppyDrive:
; On single-floppy-drive systems, both A: and B: will point to the same physical drive. The problem is that DOS will print a message telling the user
; to "insert a disk and press any key to continue" when swapping from one logical drive to the other. To avoid this mess we hook interrupt 2Fh/AX=4A00h
; to signal to DOS that we will handle this ourselves. However, this only works on DOS 5+ so on older DOS versions we instead try to filter out
; the "other" logical drive (the one that isn't the current drive) during drive enumeration so the user can't select the "phantom" drive to begin with.
; This will have the somewhat strange effect of having a drive B: but no drive A: if B: happens to be the current logical floppy drive.

	cmp		BYTE [bDosVersionMajor], 5		; bDosVersionMajor must be provided by the application as it's not part of the library
	jae		SHORT .MessageSuppressedByInt2FhHandler
	LOAD_BDA_SEGMENT_TO ds, ax
	mov		al, [BDA.wEquipment]
	test	al, 0C0h
	jnz		SHORT .MoreThanOneFloppyDrive	; No phantom drive so no need for any filtering
	test	al, 1							; Any floppy drive at all?
	jz		SHORT .NoFloppyDrive			; A pre-DOS 5 machine with no FDD is indeed a strange beast. However, don't trust the BIOS - let DOS decide
	cmp		dl, [504h]						; MS-DOS - LOGICAL DRIVE FOR SINGLE-FLOPPY SYSTEM (A: / B:)
	jmp		SHORT .ReturnFromFloppyDriveFiltering

;--------------------------------------------------------------------
; .SetFlagToBXAXfromDriveInDL
;	Parameters:
;		DL:		Drive number (0...31)
;		BX:AX:	Flags containing drive numbers
;	Returns:
;		BX:AX:	Flags with wanted drive bit set
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.SetFlagToBXAXfromDriveInDL:
	push	cx

	mov		cl, dl
	xchg	dx, bx
	call	Bit_SetToDXAXfromIndexInCL
	xchg	bx, dx

	pop		cx
	ret


;--------------------------------------------------------------------
; Drive_GetDefaultToAL
;	Parameters:
;		Nothing
;	Returns:
;		AL:		Current default drive (00h=A:, 01h=B: ...)
;	Corrupts registers:
;		AH
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Drive_GetDefaultToAL:
	mov		ah, GET_CURRENT_DEFAULT_DRIVE
	SKIP2B	f	; cmp ax, <next instruction>
	; Fall to Drive_SetDefaultFromDL


;--------------------------------------------------------------------
; Drive_SetDefaultFromDL
;	Parameters:
;		DL:		New default drive (00h=A:, 01h=B: ...)
;	Returns:
;		AL:		Number of potentially valid drive letters available
;	Corrupts registers:
;		AH
;--------------------------------------------------------------------
Drive_SetDefaultFromDL:
	mov		ah, SELECT_DEFAULT_DRIVE
	int		DOS_INTERRUPT_21h
	ret
