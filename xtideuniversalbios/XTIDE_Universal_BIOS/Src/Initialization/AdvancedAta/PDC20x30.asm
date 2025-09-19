; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for initializing Promise
;					PDC 20230 and 20630 VLB IDE Controllers.

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
; PDC20x30_DetectControllerForIdeBaseInBX
;	Parameters:
;		BX:		IDE Base Port
;	Returns:
;		AX:		ID WORD for detected controller
;		DX:		Controller base port
;		CF:		Set if PDC detected
;	Corrupts registers:
;		BX (only when PDC detected)
;--------------------------------------------------------------------
PDC20x30_DetectControllerForIdeBaseInBX:
	mov		dx, bx
	call	EnablePdcProgrammingMode
	jnz		SHORT DisablePdcProgrammingMode.Return	; PDC controller not detected
;	ePUSH_T	ax, DisablePdcProgrammingMode			; Uncomment this if GetPdcIDtoAX needs to be a real function
	; Fall to GetPdcIDtoAX

;--------------------------------------------------------------------
; Programming mode must be enabled for this function.
; This function also enables PDC 20630 extra registers.
;
; GetPdcIDtoAX
;	Parameters:
;		DX:		IDE Base port
;	Returns:
;		AH:		PDC ID
;	Corrupts registers:
;		AL, BX
;--------------------------------------------------------------------
GetPdcIDtoAX:
	push	dx

	; Try to enable PDC 20630 extra registers
	add		dx, BYTE LOW_CYLINDER_REGISTER
	in		al, dx
	or		al, FLG_PDCLCR_ENABLE_EXTRA_REGISTERS
	out		dx, al

	; Try to access PDC 20630 registers to see if they are available
	; Hopefully this does not cause problems for systems with PDC 20230
	add		dx, BYTE PDC20630_INDEX_REGISTER - LOW_CYLINDER_REGISTER
	mov		al, PDCREG7_STATUS	; Try to access PDC 20630 status register
	out		dx, al
	xchg	bx, ax
	in		al, dx				; Does index register contain status register index?
	cmp		al, bl
	mov		ah, ID_PDC20630
	eCMOVNE	ah, ID_PDC20230

	pop		dx
;	ret							; Uncomment this to make GetPdcIDtoAX a real function
	; Fall to DisablePdcProgrammingMode


;--------------------------------------------------------------------
; DisablePdcProgrammingMode
;	Parameters:
;		DX:		Base port
;	Returns:
;		CF:		Set
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
DisablePdcProgrammingMode:
	add		dx, BYTE HIGH_CYLINDER_REGISTER
	in		al, dx
	add		dx, -HIGH_CYLINDER_REGISTER		; Sets CF for PDC20x30_DetectControllerForIdeBaseInBX
.Return:
	ret


;--------------------------------------------------------------------
; EnablePdcProgrammingMode
;	Parameters:
;		DX:		Base port
;	Returns:
;		CF:		Cleared
;		ZF:		Set if programming mode enabled
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
EnablePdcProgrammingMode:
	; Set bit 7 to sector count register
	inc		dx
	inc		dx
	in		al, dx	; 1F2h (SECTOR_COUNT_REGISTER)
	or		al, 80h
	out		dx, al

	; PDC detection sequence (should delay be added between register reads?)
	add		dx, BYTE HIGH_CYLINDER_REGISTER - SECTOR_COUNT_REGISTER
	in		al, dx	; 1F5h
	cli
	sub		dx, BYTE HIGH_CYLINDER_REGISTER - SECTOR_COUNT_REGISTER
	in		al, dx	; 1F2h
	add		dx, STANDARD_CONTROL_BLOCK_OFFSET + (ALTERNATE_STATUS_REGISTER_in - SECTOR_COUNT_REGISTER)
	in		al, dx	; 3F6h
	in		al, dx	; 3F6h
	sub		dx, STANDARD_CONTROL_BLOCK_OFFSET + (ALTERNATE_STATUS_REGISTER_in - SECTOR_COUNT_REGISTER)
	in		al, dx	; 1F2h
	in		al, dx	; 1F2h
	sti

	; PDC20230C and PDC20630 clears the bit we set at the beginning
	in		al, dx	; 1F2h
	dec		dx
	dec		dx		; Base port
	test	al, 80h	; Clears CF
	ret


;--------------------------------------------------------------------
; PDC20x30_GetMaxPioModeToALandMinPioCycleTimeToBX
;	Parameters:
;		AX:		ID WORD specific for detected controller
;	Returns:
;		AL:		Max supported PIO mode (only if ZF set)
;		AH:		~FLGH_DPT_IORDY if IORDY not supported, -1 otherwise (only if ZF set)
;		BX:		Min PIO cycle time (only if ZF set)
;		ZF:		Set if PIO limit necessary
;				Cleared if no need to limit timings
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
PDC20x30_GetMaxPioModeToALandMinPioCycleTimeToBX:
	cmp		ah, ID_PDC20230
	jne		SHORT .Return							; No need to limit anything for ID_PDC20630
	mov		ax, (~FLGH_DPT_IORDY & 0FFh) << 8 | 2	; Limit PIO to 2 for ID_PDC20230
	mov		bx, PIO_2_MIN_CYCLE_TIME_NS
.Return:
	ret


;--------------------------------------------------------------------
; PDC20x30_InitializeForDPTinDSDI
;	Parameters:
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;	Returns:
;		AH:		Int 13h return status
;		CF:		Cleared if success or no controller to initialize
;				Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
PDC20x30_InitializeForDPTinDSDI:
%ifdef USE_386
	xor		ch, ch
	test	BYTE [di+DPT.bFlagsLow], FLGL_DPT_SLAVE
	setnz	cl
%else
	xor		cx, cx
	test	BYTE [di+DPT.bFlagsLow], FLGL_DPT_SLAVE
	jz		SHORT .NotSlave
	inc		cx
.NotSlave:
%endif

	mov		dx, [di+DPT.wBasePort]
	call	EnablePdcProgrammingMode
	call	SetSpeedForDriveInCX
	cmp		BYTE [di+DPT_ADVANCED_ATA.wControllerID+1], ID_PDC20630
	jne		SHORT .InitializationCompleted
	call	SetPdc20630SpeedForDriveInCX
.InitializationCompleted:
	mov		dx, [di+DPT.wBasePort]
	call	DisablePdcProgrammingMode
	xor		ah, ah
	ret


;--------------------------------------------------------------------
; SetSpeedForDriveInCX
;	Parameters:
;		CX:		0 for master, 1 for slave drive
;		DX:		IDE Base port
;		DS:DI:	Ptr to DPT
;	Returns:
;		DX:		Sector Number Register
;	Corrupts registers:
;		AX, BX
;--------------------------------------------------------------------
SetSpeedForDriveInCX:
	mov		bx, .rgbPioModeToPDCspeedValue
	mov		al, [di+DPT_ADVANCED_ATA.bPioMode]
	MIN_U	al, 2	; Limit to PIO2
	cs xlat
	xchg	bx, ax

	add		dx, BYTE SECTOR_NUMBER_REGISTER
	mov		bh, ~MASK_PDCSCR_DEV1SPEED	; Assume slave
	inc		cx
	loop	.SetSpeed
	eSHL_IM	bl, POS_PDCSCR_DEV0SPEED
	mov		bh, ~MASK_PDCSCR_DEV0SPEED
.SetSpeed:
	in		al, dx
	and		al, bh
	or		al, bl
	cmp		bl, 7
	jb		SHORT .OutputNewValue
	or		al, FLG_PDCSCR_UNKNOWN_BIT7	; Flag for PIO 2 and above?
.OutputNewValue:
	out		dx, al
	ret

.rgbPioModeToPDCspeedValue:
	db		0		; PIO 0
	db		4		; PIO 1
	db		7		; PIO 2


;--------------------------------------------------------------------
; SetPdc20630SpeedForDriveInCX
;	Parameters:
;		CX:		0 for master, 1 for slave drive
;		DS:DI:	Ptr to DPT
;		DX:		Sector Number Register
;	Returns:
;		DX:		Low Cylinder Register
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
SetPdc20630SpeedForDriveInCX:
	inc		dx		; LOW_CYLINDER_REGISTER
	mov		ah, ~(FLG_PDCLCR_DEV0SPEED_BIT4 | FLG_PDCLCR_DEV0IORDY)
	ror		ah, cl
	in		al, dx
	and		al, ah	; Clear drive specific bits
	cmp		BYTE [di+DPT_ADVANCED_ATA.bPioMode], 2
	jbe		.ClearBitsOnly
	not		ah
	or		al, ah
.ClearBitsOnly:
	out		dx, al
	ret

