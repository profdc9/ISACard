; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for generating L-CHS parameters for
;					drives with more than 1024 cylinders.
;
; 					These algorithms are taken from: http://www.mossywell.com/boot-sequence
; 					Take a look at it for more detailed information.
;
;					This file is shared with BIOS Drive Information Tool.

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

%ifdef MODULE_EBIOS
;--------------------------------------------------------------------
; AtaGeometry_GetLbaSectorCountToBXDXAXfromAtaInfoInESSI
;	Parameters:
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		BX:DX:AX:	48-bit sector count
;		CL:			FLGL_DPT_LBA48 if LBA48 supported
;					Zero if only LBA28 is supported
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AtaGeometry_GetLbaSectorCountToBXDXAXfromAtaInfoInESSI:
	mov		bx, Registers_ExchangeDSSIwithESDI
	call	bx	; ATA info now in DS:DI
	push	bx	; We will return via Registers_ExchangeDSSIwithESDI

	; Check if LBA48 supported
	test	BYTE [di+ATA6.wSetSup83+1], A6_wSetSup83_LBA48>>8
	jz		SHORT .GetLba28SectorCount

	; Get LBA48 sector count
	mov		cl, FLGL_DPT_LBA48
	mov		ax, [di+ATA6.qwLBACnt]
	mov		dx, [di+ATA6.qwLBACnt+2]
	mov		bx, [di+ATA6.qwLBACnt+4]
	ret

.GetLba28SectorCount:
	xor		cl, cl
	xor		bx, bx
	mov		ax, [di+ATA1.dwLBACnt]
	mov		dx, [di+ATA1.dwLBACnt+2]
	ret
%endif	; MODULE_EBIOS


;--------------------------------------------------------------------
; AtaGeometry_GetLCHStoAXBLBHfromAtaInfoInESSIwithTranslateModeInDX
;	Parameters:
;		DX:		Wanted translate mode or TRANSLATEMODE_AUTO to autodetect
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		AX:		Number of L-CHS cylinders (1...1027, yes 1027)
;		BL:		Number of L-CHS heads (1...255)
;		BH:		Number of L-CHS sectors per track (1...63)
;		CX:		Number of bits shifted (0...3)
;		DX:		CHS Translate Mode
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AtaGeometry_GetLCHStoAXBLBHfromAtaInfoInESSIwithTranslateModeInDX:
	call	AtaGeometry_GetPCHStoAXBLBHfromAtaInfoInESSI

	; Check if user defined translate mode
	dec		dx						; Set ZF if TRANSLATEMODE_LARGE, SF if TRANSLATEMODE_NORMAL
	jns		SHORT .CheckIfLargeTranslationWanted
	call	AtaGeometry_LimitAXtoMaximumLCylinders	; TRANSLATEMODE_NORMAL maximum cylinders
	inc		dx
.CheckIfLargeTranslationWanted:
	jz		SHORT ConvertPCHfromAXBLtoRevisedEnhancedCHinAXBL
	dec		dx						; Set ZF if TRANSLATEMODE_ASSISTED_LBA
	jz		SHORT .UseAssistedLBA
	; TRANSLATEMODE_AUTO set

%ifndef MODULE_EBIOS
	; Since we do not have EBIOS functions, we might as well use the faster
	; LARGE mode for small drives. Assisted LBA provides more capacity for
	; larger drives.
	; Generate L-CHS using simple bit shift algorithm (ECHS) if
	; 8192 or less cylinders.
	cmp		ax, 8192
	jbe		SHORT ConvertPCHfromAXBLtoEnhancedCHinAXBL
%else
	; Check if the drive is within the limits of NORMAL addressing.
	; If it is, then no CHS translation is necessary.
	cmp		ax, MAX_LCHS_CYLINDERS
	jbe		SHORT ConvertPCHfromAXBLtoEnhancedCHinAXBL
%endif

	; If we have EBIOS functions, we should always use Assisted LBA
	; for drives with LBA support. Otherwise the EBIOS functions are
	; useless since we never do LBA to P-CHS translation.
	; Even if we do not have EBIOS functions, we must do this check
	; since user might have forced LBA mode even though the drive does
	; not support LBA addressing.
	test	BYTE [es:si+ATA1.wCaps+1], A1_wCaps_LBA>>8
	jz		SHORT ConvertPCHfromAXBLtoRevisedEnhancedCHinAXBL

	; Assisted LBA provides most capacity but translation algorithm is
	; slower. The speed difference doesn't matter on AT systems.
.UseAssistedLBA:
	; Fall to GetSectorCountToDXAXfromCHSinAXBLBH


;--------------------------------------------------------------------
; GetSectorCountToDXAXfromCHSinAXBLBH
;	Parameters:
;		AX:		Number of cylinders (1...16383)
;		BL:		Number of heads (1...255)
;		BH:		Number of sectors per track (1...63)
;	Returns:
;		DX:AX:	Total number of CHS addressable sectors
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
GetSectorCountToDXAXfromCHSinAXBLBH:
	xchg	ax, bx
	mul		ah			; AX = Heads * Sectors per track
	mul		bx
	; Fall to ConvertChsSectorCountFromDXAXtoLbaAssistedLCHSinAXBLBH


;--------------------------------------------------------------------
; LBA assist calculation (or Assisted LBA)
;
; This algorithm translates P-CHS sector count up to largest possible
; L-CHS sector count (1024, 255, 63). Note that INT 13h interface allows
; 256 heads but DOS supports up to 255 head. That is why BIOSes never
; use 256 heads.
;
; L-CHS parameters generated here require the drive to use LBA addressing.
;
; Here is the algorithm:
; If cylinders > 8192
;  Variable CH = Total CHS Sectors / 63
;  Divide (CH - 1) by 1024 and add 1
;  Round the result up to the nearest of 16, 32, 64, 128 and 255. This is the value to be used for the number of heads.
;  Divide CH by the number of heads. This is the value to be used for the number of cylinders.
;
; ConvertChsSectorCountFromDXAXtoLbaAssistedLCHSinAXBLBH:
;	Parameters:
;		DX:AX:	Total number of P-CHS sectors for CHS addressing
;				(max = 16383 * 16 * 63 = 16,514,064)
;	Returns:
;		AX:		Number of cylinders (?...1027)
;		BL:		Number of heads (16, 32, 64, 128 or 255)
;		BH:		Number of sectors per track (always 63)
;		CX:		Number of bits shifted (0)
;		DX:		TRANSLATEMODE_ASSISTED_LBA
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ConvertChsSectorCountFromDXAXtoLbaAssistedLCHSinAXBLBH:
	; Value CH = Total sector count / 63
	; Max = 16,514,064 / 63 = 262128
	mov		cx, LBA_ASSIST_SPT			; CX = 63

	; --- Math_DivDXAXbyCX inlined (and slightly modified) since it's only used here
	xor		bx, bx
	xchg	bx, ax
	xchg	dx, ax
	div		cx
	xchg	ax, bx
	div		cx
	mov		dx, bx
	; ---

	push	ax
	push	dx							; Value CH stored for later use

	; BX:DX:AX = Value CH - 1
	; Max = 262128 - 1 = 262127
	xor		bx, bx
	sub		ax, BYTE 1
	sbb		dx, bx

	; AX = Number of heads = ((Value CH - 1) / 1024) + 1
	; Max = (262127 / 1024) + 1 = 256
	call	Size_DivideSizeInBXDXAXby1024	; Preserves CX and returns with BH cleared
	pop		dx
	inc		ax							; + 1

	; Heads must be 16, 32, 64, 128 or 255 (round up to the nearest)
	; Max = 255
	mov		bl, 16						; Min number of heads
.CompareNextValidNumberOfHeads:
	cmp		ax, bx
	jbe		SHORT .NumberOfHeadsNowInBX
	eSHL_IM	bx, 1						; Double number of heads
	jpo		SHORT .CompareNextValidNumberOfHeads	; Reached 256 heads?
	dec		bx							;  If so, limit heads to 255
.NumberOfHeadsNowInBX:

	; DX:AX = Number of cylinders = Value CH (without - 1) / number of heads
	; Max = 262128 / 255 = 1027
	pop		ax							; Value CH back to DX:AX
	div		bx

	xchg	bh, cl						; Sectors per Track to BH, zero to CL (CX)
	mov		dl, TRANSLATEMODE_ASSISTED_LBA
	; All combinations of value CH from 1 to 262128 divided by number of heads
	; (16/32/64/128/255) has been verified to return with DH cleared.
ReturnLCHSinAXBLBH:
	ret


;--------------------------------------------------------------------
; AtaGeometry_GetPCHStoAXBLBHfromAtaInfoInESSI
;	Parameters:
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		AX:		Number of P-CHS cylinders (1...16383)
;		BL:		Number of P-CHS heads (1...16)
;		BH:		Number of P-CHS sectors per track (1...63)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AtaGeometry_GetPCHStoAXBLBHfromAtaInfoInESSI:
	mov		ax, [es:si+ATA1.wCylCnt]	; Cylinders (1...16383)
	mov		bl, [es:si+ATA1.wHeadCnt]	; Heads (1...16)
	mov		bh, [es:si+ATA1.wSPT]		; Sectors per Track (1...63)
	ret


;--------------------------------------------------------------------
; Revised Enhanced CHS calculation (Revised ECHS)
;
; This algorithm translates P-CHS sector count to L-CHS sector count
; with bit shift algorithm. Since 256 heads are not allowed
; (DOS limit), this algorithm makes translations so that maximum of
; 240 L-CHS heads can be used. This makes the maximum addressable capacity
; to 7,927,234,560 bytes ~ 7.38 GiB. LBA addressing needs to be used to
; get more capacity.
;
; L-CHS parameters generated here require the drive to use CHS addressing.
;
; Here is the algorithm:
; If cylinders > 8192 and heads = 16
;  Heads = 15
;  Cylinders = cylinders * 16 / 15 (losing the fraction component)
;  Do a standard ECHS translation
;
; *FIXME* The above algorithm seems to be conflicting with info found here
; https://web.archive.org/web/20000817071418/http://www.firmware.com:80/support/bios/over4gb.htm
; which says that Revised ECHS is used when the cylinder count is > 8191.
;
; ConvertPCHfromAXBLtoRevisedEnhancedCHinAXBL:
;	Parameters:
;		AX:		Number of P-CHS cylinders (8193...16383)
;		BL:		Number of P-CHS heads (1...16)
;	Returns:
;		AX:		Number of L-CHS cylinders (?...1024)
;		BL:		Number of L-CHS heads (?...240)
;		CX:		Number of bits shifted (0...3)
;		DX:		TRANSLATEMODE_NORMAL or TRANSLATEMODE_LARGE
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ConvertPCHfromAXBLtoRevisedEnhancedCHinAXBL:
	; Generate L-CHS using simple bit shift algorithm (ECHS) if
	; 8192 or less cylinders
	call	AtaGeometry_IsDriveSmallEnoughForECHS
	jc		SHORT ConvertPCHfromAXBLtoEnhancedCHinAXBL

	eMOVZX	cx, bl	; CX = 16
	dec		bx		; Heads = 15
	mul		cx		; DX:AX = Cylinders * 16
	dec		cx		; CX = 15
	div		cx		; AX = (Cylinders * 16) / 15
	; Fall to ConvertPCHfromAXBLtoEnhancedCHinAXBL


;--------------------------------------------------------------------
; Enhanced CHS calculation (ECHS)
;
; This algorithm translates P-CHS sector count to L-CHS sector count
; with simple bit shift algorithm. Since 256 heads are not allowed
; (DOS limit), this algorithm require that there are at most 8192
; P-CHS cylinders. This makes the maximum addressable capacity
; to 4,227,858,432 bytes ~ 3.94 GiB. Use Revised ECHS or Assisted LBA
; algorithms if there are more than 8192 P-CHS cylinders.
;
; L-CHS parameters generated here require the drive to use CHS addressing.
;
; Here is the algorithm:
;  Multiplier = 1
;  Cylinder = Cylinder - 1
;  Is Cylinder < 1024? If not:
;  Do a right bitwise rotation on the cylinder (i.e., divide by 2)
;  Do a left bitwise rotation on the multiplier (i.e., multiply by 2)
;  Use the multiplier on the Cylinder and Head values to obtain the translated values.
;
; ConvertPCHfromAXBLtoEnhancedCHinAXBL:
;	Parameters:
;		AX:		Number of P-CHS cylinders (1...8192, or up to 17475 if fell from above)
;		BL:		Number of P-CHS heads (1...16)
;	Returns:
;		AX:		Number of L-CHS cylinders (?...1024)
;		BL:		Number of L-CHS heads (?...128, or up to 240 if fell from above)
;		CX:		Number of bits shifted (0...3)
;		DX:		TRANSLATEMODE_NORMAL or TRANSLATEMODE_LARGE
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ConvertPCHfromAXBLtoEnhancedCHinAXBL:
	cwd					; Assume TRANSLATEMODE_NORMAL
	xor		cx, cx		; No bits to shift initially
.ShiftIfMoreThan1024Cylinder:
	cmp		ax, MAX_LCHS_CYLINDERS
	jbe		SHORT ReturnLCHSinAXBLBH
	shr		ax, 1		; Halve cylinders
	eSHL_IM	bl, 1		; Double heads
	inc		cx			; Increment bit shift count
	mov		dl, TRANSLATEMODE_LARGE
	jmp		SHORT .ShiftIfMoreThan1024Cylinder


;--------------------------------------------------------------------
; Checks should LARGE mode L-CHS be calculated with ECHS or Revised ECHS
; algorithm. Revised ECHS is needed for drives with 8193 or more cylinders
; AND 16 heads.
;
; AtaGeometry_IsDriveSmallEnoughForECHS:
;	Parameters:
;		AX:		Number of P-Cylinders
;		BL:		Number of P-Heads
;	Returns:
;		CF:		Clear if Reviced ECHS is necessary
;				Set if ECHS is enough
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AtaGeometry_IsDriveSmallEnoughForECHS:
	; Generate L-CHS using simple bit shift algorithm (ECHS) if
	; 8192 or less cylinders. Use Revised ECHS if 8193 or more cylinders
	; AND 16 heads.
	cmp		ax, 8193
	jb		SHORT .RevisedECHSisNotNeeded
	cmp		bl, 16	; Drives with 8193 or more cylinders can report 15 heads
.RevisedECHSisNotNeeded:
	ret


;--------------------------------------------------------------------
; AtaGeometry_LimitAXtoMaximumLCylinders
;	Parameters:
;		AX:		Number of total L-CHS cylinders (1...1027)
;	Returns:
;		AX:		Number of usable L-CHS cylinders (1...1024)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AtaGeometry_LimitAXtoMaximumLCylinders:
	MIN_U	ax, MAX_LCHS_CYLINDERS
	ret

