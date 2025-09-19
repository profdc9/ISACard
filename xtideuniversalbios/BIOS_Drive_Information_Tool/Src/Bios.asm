; Project name	:	BIOS Drive Information Tool
; Description	:	Functions to read information from BIOS.

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

;---------------------------------------------------------------------
; Bios_GetNumberOfHardDrivesToDX
;	Parameters:
;		Nothing
;	Returns: (if no errors)
;		DX:		Number of hard drives in system
;		CF:		Set if no hard drives found
;	Corrupts registers:
;		AX, BX, CX
;--------------------------------------------------------------------
Bios_GetNumberOfHardDrivesToDX:
	mov		dl, 80h		; First hard drive
	mov		ah, GET_DRIVE_PARAMETERS
	int		BIOS_DISK_INTERRUPT_13h
	mov		dh, 0		; Preserve CF
	ret


;---------------------------------------------------------------------
; Bios_ReadOldInt13hParametersFromDriveDL
;	Parameters:
;		DL:		BIOS drive number
;	Returns: (if no errors)
;		BL:		Drive Type (for floppies only)
;		AX:		Sectors per track (1...63)
;		DX:		Number of heads (1...255)
;		CX:		Number of cylinders (1...1024)
;		CF:		Cleared = no errors
;				Set = BIOS error code stored in AH
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Bios_ReadOldInt13hParametersFromDriveDL:
	mov		ah, GET_DRIVE_PARAMETERS
	int		BIOS_DISK_INTERRUPT_13h
	jc		SHORT ReturnWithBiosErrorCodeInAH
	; Fall to ExtractCHSfromOldInt13hDriveParameters

;---------------------------------------------------------------------
; ExtractCHSfromOldInt13hDriveParameters
;	Parameters:
;		CH:		Maximum cylinder number, bits 7...0
;		CL:		Bits 7...6: Maximum cylinder number, bits 9 and 8
;				Bits 5...0:	Maximum sector number (1...63)
;		DH:		Maximum head number (0...254)
;	Returns:
;		BL:		Drive Type (for floppies only)
;		AX:		Sectors per track (1...63)
;		DX:		Number of heads (1...255)
;		CX:		Number of cylinders (1...1024)
;		CF:		Cleared
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ExtractCHSfromOldInt13hDriveParameters:
	mov		al, cl				; Copy sector number...
	and		ax, BYTE 3Fh		; ...and limit to 1...63
	sub		cl, al				; Remove from max cylinder high
	eROL_IM	cl, 2				; High bits to beginning
	eMOVZX	dx, dh				; Copy Max head to DX
	xchg	cl, ch				; Max cylinder now in CX
	inc		cx					; Max cylinder to number of cylinders
	inc		dx					; Max head to number of heads
	clc							; No errors
	ret


;---------------------------------------------------------------------
; Bios_ReadOldInt13hCapacityFromDriveDL
;	Parameters:
;		DL:		BIOS drive number
;	Returns: (if no errors)
;		CX:DX:	Total number of sectors
;		AH:		BIOS Error code
;		CF:		Cleared = no errors
;				Set = BIOS error code stored in AH
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Bios_ReadOldInt13hCapacityFromDriveDL:
	mov		ah, GET_DISK_TYPE
	int		BIOS_DISK_INTERRUPT_13h
	jc		SHORT ReturnInvalidErrorCodeInAH
	xor		ah, ah
	ret


;---------------------------------------------------------------------
; Bios_ReadAtaInfoFromDriveDLtoBX
;	Parameters:
;		DL:		BIOS drive number
;	Returns: (if no errors)
;		DS:BX:	Ptr to ATA information
;		AH:		BIOS Error code
;		CF:		Cleared = no errors
;				Set = BIOS error code stored in AH
;	Corrupts registers:
;		CX, ES
;--------------------------------------------------------------------
Bios_ReadAtaInfoFromDriveDLtoBX:
	mov		bx, g_rgbAtaInfo
	push	ds
	pop		es
	mov		cx, XUB_INT13h_SIGNATURE	; Signature to read unaltered ATA ID
	mov		ah, GET_DRIVE_INFORMATION
	int		BIOS_DISK_INTERRUPT_13h
	ret


;---------------------------------------------------------------------
; Bios_ReadEbiosVersionFromDriveDL
;	Parameters:
;		DL:		BIOS drive number
;	Returns:
;		AH:		BIOS error code
;		BX:		Version of extensions
;		CX:		Interface support bit map
;		CF:		Cleared = no errors
;				Set = BIOS error code stored in AH
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Bios_ReadEbiosVersionFromDriveDL:
	mov		ah, CHECK_EXTENSIONS_PRESENT
	mov		bx, 55AAh
	int		BIOS_DISK_INTERRUPT_13h
	jc		SHORT ReturnInvalidErrorCodeInAH	; No EBIOS present
	xor		bx, 0AA55h
	jnz		SHORT ReturnInvalidErrorCodeInAH	; No EBIOS present
	xchg	bl, ah			; Version to BX, BIOS error code to AH
	ret


;---------------------------------------------------------------------
; Bios_ReadEbiosInfoFromDriveDLtoDSSI
;	Parameters:
;		DL:		BIOS drive number
;	Returns: (if no errors)
;		DS:SI:	Ptr to EDRIVE_INFO
;		AH:		BIOS Error code
;		CF:		Cleared = no errors
;				Set = BIOS error code stored in AH
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Bios_ReadEbiosInfoFromDriveDLtoDSSI:
	mov		si, g_edriveInfo
	mov		WORD [si+EDRIVE_INFO.wSize], MINIMUM_EDRIVEINFO_SIZE
	mov		ah, GET_EXTENDED_DRIVE_INFORMATION
	int		BIOS_DISK_INTERRUPT_13h
	ret


;---------------------------------------------------------------------
; ReturnInvalidErrorCodeInAH
; ReturnWithBiosErrorCodeInAH
;	Parameters:
;		Nothing
;	Returns: (if no errors)
;		AH:		BIOS Error code
;		CF:		Set
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ReturnInvalidErrorCodeInAH:
	stc
	mov		ah, RET_HD_INVALID
ReturnWithBiosErrorCodeInAH:
	ret


; Section containing uninitialized data
SECTION .bss

g_edriveInfo:
g_rgbAtaInfo:		resb	512
