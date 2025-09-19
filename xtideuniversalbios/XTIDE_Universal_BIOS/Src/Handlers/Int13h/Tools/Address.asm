; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for address translations.

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
; Address_ExtractLCHSparametersFromOldInt13hAddress
;	Parameters:
;		CH:		Cylinder number, bits 7...0
;		CL:		Bits 7...6: Cylinder number bits 9 and 8
;				Bits 5...0:	Sector number
;		DH:		Head number
;	Returns:
;		BL:		Sector number (1...63)
;		BH:		Head number (0...255)
;		CX:		Cylinder number (0...1023)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Address_ExtractLCHSparametersFromOldInt13hAddress:
	mov		bl, 3Fh				; Load sector number mask
	and		bl, cl				; Sector number now in BL
%ifndef USE_186
	sub		cl, bl				; Remove from cylinder number high
	rol		cl, 1				; High bits to beginning
	rol		cl, 1
%else
	shr		cl, 6
%endif
	mov		bh, dh				; Copy Head number
	xchg	cl, ch				; Cylinder number now in CX
	ret


;---------------------------------------------------------------------
; Converts LARGE addressing mode LCHS parameters to IDE P-CHS parameters.
; PCylinder	= (LCylinder << n) + (LHead / PHeadCount)
; PHead		= LHead % PHeadCount
; PSector	= LSector
;
; ConvertLargeModeLCHStoPCHS:
;	Parameters:
;		BL:		Sector number (1...63)
;		BH:		Head number (0...239)
;		CX:		Cylinder number (0...1023)
;		DS:DI:	Ptr to Disk Parameter Table
;	Returns:
;		BL:		Sector number (1...63)
;		BH:		Head number (0...15)
;		CX:		Cylinder number (0...16382)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ConvertLargeModeLCHStoPCHS:
	; LHead / PHeadCount and LHead % PHeadCount
	eMOVZX	ax, bh					; Copy L-CHS Head number to AX
	div		BYTE [di+DPT.bPchsHeads]; AL = LHead / PHeadCount, AH = LHead % PHeadCount
	mov		bh, ah					; Copy P-CHS Head number to BH
	xor		ah, ah					; AX = LHead / PHeadCount

	; (LCylinder << n) + (LHead / PHeadCount)
	mov		dx, cx					; Copy L-CHS Cylinder number to DX
	mov		cl, MASKL_DPT_CHS_SHIFT_COUNT	; Load shift count mask
	and		cl, [di+DPT.bFlagsLow]	; Shift count now in CL
	shl		dx, cl					; DX = LCylinder << n
	add		ax, dx					; AX = P-CHS Cylinder number
	xchg	cx, ax					; Move P-CHS Cylinder number to CX
DoNotConvertLCHS:
	ret

; *FIXME* The above function description doesn't match the code.
; If CX has a maximum value of 1023 on entry then there is no way CX can be 16382 on return.
; 1023 SHL 3 (MASKL_DPT_CHS_SHIFT_COUNT) is 8184. With the addition of AX (at most 255?)
; the result is 8439.

;--------------------------------------------------------------------
; Address_OldInt13hAddressToIdeAddress
;	Parameters:
;		CH:		Cylinder number, bits 7...0
;		CL:		Bits 7...6: Cylinder number bits 9 and 8
;				Bits 5...0:	Starting sector number (1...63)
;		DH:		Starting head number (0...255)
;		DS:DI:	Ptr to DPT
;	Returns:
;		BL:		LBA Low Register / Sector Number Register (LBA 7...0)
;		CL:		LBA Mid Register / Low Cylinder Register (LBA 15...8)
;		CH:		LBA High Register / High Cylinder Register (LBA 23...16)
;		BH:		Drive and Head Register (LBA 27...24)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Address_OldInt13hAddressToIdeAddress:
	call	Address_ExtractLCHSparametersFromOldInt13hAddress
	mov		al, [di+DPT.bFlagsLow]
	and		al, MASKL_DPT_TRANSLATEMODE

;;; 0: TRANSLATEMODE_NORMAL
	jz		SHORT DoNotConvertLCHS

;;; 1: TRANSLATEMODE_LARGE
	test	al, FLGL_DPT_ASSISTED_LBA
	jz		SHORT ConvertLargeModeLCHStoPCHS

;;; 2: TRANSLATEMODE_ASSISTED_LBA
	; Fall to ConvertAssistedLBAModeLCHStoLBARegisterValues


;---------------------------------------------------------------------
; Converts LCHS parameters to 28-bit LBA address.
; Only 24-bits are used since LHCS to LBA28 conversion has 8.4GB limit.
; LBA = ((cylToSeek*headsPerCyl+headToSeek)*sectPerTrack)+sectToSeek-1
; headsPerCyl and sectPerTrack are the current translation values (L-CHS).
;
; Returned address is in same registers that
; DoNotConvertLCHS and ConvertLargeModeLCHStoPCHS returns.
;
; ConvertAssistedLBAModeLCHStoLBARegisterValues:
;	Parameters:
;		BL:		Sector number (1...63)
;		BH:		Head number (0...254)
;		CX:		Cylinder number (0...1023)
;		DS:DI:	Ptr to Disk Parameter Table
;	Returns:
;		BL:		LBA Low Register / Sector Number Register (LBA 7...0)
;		CL:		LBA Mid Register / Low Cylinder Register (LBA 15...8)
;		CH:		LBA High Register / High Cylinder Register (LBA 23...16)
;		BH:		Drive and Head Register (LBA 27...24)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ConvertAssistedLBAModeLCHStoLBARegisterValues:
	; cylToSeek*headsPerCyl (18-bit result)
	; Max = 1023 * 255 = 260,865 = 3FB01h
	mov		ax, LBA_ASSIST_SPT		; Load Sectors per Track
	xchg	cx, ax					; Cylinder number to AX, Sectors per Track to CX
%ifdef USE_386
	movzx	dx, [di+DPT.bLchsHeads]
%else
	cwd
	mov		dl, [di+DPT.bLchsHeads]
%endif
	mul		dx						; DX:AX = cylToSeek*headsPerCyl

	; +=headToSeek (18-bit result)
	; Max = 260,865 + 254 = 261,119 = 3FBFFh
	add		al, bh					; Add Head number to DX:AX
	adc		ah, dh					; DH = Zero after previous multiplication
	adc		dl, dh

	; *=sectPerTrack (18-bit by 6-bit multiplication with 24-bit result)
	; Max = 261,119 * 63 = 16,450,497 = FB03C1h
	xchg	ax, dx					; Hiword to AX, loword to DX
	mul		cl						; AX = hiword * Sectors per Track
	mov		bh, al					; Backup hiword * Sectors per Track
	xchg	ax, dx					; Loword back to AX
	mul		cx						; DX:AX = loword * Sectors per Track
	add		dl, bh					; DX:AX = (cylToSeek*headsPerCyl+headToSeek)*sectPerTrack

	; +=sectToSeek-1 (24-bit result)
	; Max = 16,450,497 + 63 - 1 = 16,450,559 = FB03FFh
	mov		bh, ch					; Sector number now in BX, CH=zero
	dec		bx						; sectToSeek-=1
	add		bx, ax					; Add loword to BX (BL = Sector Number Register (LBA 7...0))
	adc		ch, dl					; Add possible carry to byte2 (CH = High Cylinder Register (LBA 23...16))
	mov		cl, bh					; CL = Low Cylinder Register (LBA 15...8)
	mov		bh, dh					; BH = Drive and Head Register (LBA 27...24)
	ret
