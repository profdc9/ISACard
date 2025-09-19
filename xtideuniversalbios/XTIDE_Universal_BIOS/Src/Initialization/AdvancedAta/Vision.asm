; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for initializing QDI Vision
;					QD6500 and QD6580 VLB IDE Controllers.

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
; Vision_DetectAndReturnIDinAXandPortInDXifControllerPresent
;	Parameters:
;		Nothing
;	Returns:
;		AX:		ID WORD specific for QDI Vision Controllers
;				(AL = QD65xx Config Register contents)
;				(AH = QDI Vision Controller ID)
;		DX:		Controller port (not IDE port)
;		ZF:		Set if controller found
;				Cleared if supported controller not found (AX,DX = undefined)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Vision_DetectAndReturnIDinAXandPortInDXifControllerPresent:
	; Check QD65xx base port
	mov		dx, QD65XX_BASE_PORT
	in		al, QD65XX_BASE_PORT + QD65XX_CONFIG_REGISTER_in

	call	IsConfigRegisterWithIDinAL
	je		SHORT VisionControllerDetected.Return

	; Check QD65xx alternative base port
	mov		dl, QD65XX_ALTERNATIVE_BASE_PORT
	in		al, QD65XX_ALTERNATIVE_BASE_PORT + QD65XX_CONFIG_REGISTER_in
	; Fall to IsConfigRegisterWithIDinAL

;--------------------------------------------------------------------
; IsConfigRegisterWithIDinAL
;	Parameters:
;		AL:		Possible QD65xx Config Register contents
;	Returns:
;		AH		QDI Vision Controller ID or undefined
;		ZF:		Set if controller found
;				Cleared if supported controller not found (AH = undefined)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
IsConfigRegisterWithIDinAL:
	mov		ah, al
	and		al, MASK_QDCONFIG_CONTROLLER_ID
	cmp		al, ID_QD6500
	je		SHORT VisionControllerDetected
	cmp		al, ID_QD6580
	je		SHORT VisionControllerDetected
	cmp		al, ID_QD6580_ALTERNATE
VisionControllerDetected:
	xchg	ah, al
.Return:
	ret


;--------------------------------------------------------------------
; Vision_DoesIdePortInBXbelongToControllerWithIDinAX
;	Parameters:
;		AL:		QD65xx Config Register contents
;		AH:		QDI Vision Controller ID
;		BX:		IDE Base port to check
;		DX:		Vision Controller port
;	Returns:
;		ZF:		Set if port belongs to controller
;				Cleared if port belongs to another controller
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Vision_DoesIdePortInBXbelongToControllerWithIDinAX:
	cmp		ah, ID_QD6500
	je		SHORT .DoesIdePortInDXbelongToQD6500

	; QD6580 always have Primary IDE at 1F0h
	; Secondary IDE at 170h can be enabled or disabled
	cmp		bx, DEVICE_ATA_PRIMARY_PORT
	je		SHORT .ReturnResultInZF

	; Check if Secondary IDE channel is enabled
	push	ax
	push	dx
	add		dx, BYTE QD6580_CONTROL_REGISTER
	in		al, dx
	test	al, FLG_QDCONTROL_SECONDARY_DISABLED_in
	pop		dx
	pop		ax
	jz		SHORT .CompareBXtoSecondaryIDE
	ret

	; QD6500 has only one IDE channel that can be at 1F0h or 170h
.DoesIdePortInDXbelongToQD6500:
	test	al, FLG_QDCONFIG_PRIMARY_IDE
	jz		SHORT .CompareBXtoSecondaryIDE
	cmp		bx, DEVICE_ATA_PRIMARY_PORT
	ret

.CompareBXtoSecondaryIDE:
	cmp		bx, DEVICE_ATA_SECONDARY_PORT
.ReturnResultInZF:
	ret


;--------------------------------------------------------------------
; Vision_GetMaxPioModeToALandMinCycleTimeToBX
;	Parameters:
;		AL:		QD65xx Config Register contents
;		AH:		QDI Vision Controller ID
;	Returns:
;		AL:		Max supported PIO mode (only if ZF set)
;		AH:		~FLGH_DPT_IORDY if IORDY not supported, -1 otherwise (only if ZF set)
;		BX:		Min PIO Cycle Time (only if ZF set)
;		ZF:		Set if PIO limit necessary
;				Cleared if no need to limit timings
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Vision_GetMaxPioModeToALandMinCycleTimeToBX:
	cmp		ah, ID_QD6500
	jne		SHORT .NoNeedToLimitForQD6580
	mov		ax, (~FLGH_DPT_IORDY & 0FFh) << 8 | 2	; Limit to PIO 2 because QD6500 does not support IORDY
	mov		bx, PIO_2_MIN_CYCLE_TIME_NS
.NoNeedToLimitForQD6580:
	ret


;--------------------------------------------------------------------
; Vision_InitializeWithIDinAH
;	Parameters:
;		AH:		QDI Vision Controller ID
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;		SI:		Offset to Master DPT if Slave Drive present
;				Zero if Slave Drive not present
;	Returns:
;		CF:		Cleared if success
;				Set if error
;	Corrupts registers:
;		AX, BX, CX, DX, BP
;--------------------------------------------------------------------
Vision_InitializeWithIDinAH:
	; QD6580 has a Control Register that needs to be programmed
	cmp		ah, ID_QD6500
	mov		dx, [di+DPT_ADVANCED_ATA.wControllerBasePort]
	mov		bp, QD6500_MAX_ACTIVE_TIME_CLOCKS | (QD6500_MIN_ACTIVE_TIME_CLOCKS << 8)	; Assume QD6500
	je		SHORT .CalculateTimingsForQD65xx
	mov		bp, QD6580_MAX_ACTIVE_TIME_CLOCKS | (QD6580_MIN_ACTIVE_TIME_CLOCKS << 8)	; It's a QD6580

	; Program QD6580 Control Register (not available on QD6500) to
	; Enable or Disable Read-Ahead and Post-Write Buffer to match
	; jumper setting on the multi I/O card.
	add		dx, BYTE QD6580_CONTROL_REGISTER
	in		al, dx						; Read to get ATAPI jumper status
	test	al, FLG_QDCONTROL_HDONLY_in
	mov		al, MASK_QDCONTROL_FLAGS_TO_SET
	eCMOVNZ	al, FLG_QDCONTROL_NONATAPI | MASK_QDCONTROL_FLAGS_TO_SET	; Enable Read-Ahead and Post-Write Buffers
	out		dx, al
	dec		dx							; Secondary Channel IDE Timing Register

	; Now we need to determine is the drive connected to the Primary or Secondary channel.
	; QD6500 has only one channel that can be Primary at 1F0h or Secondary at 170h.
	; QD6580 always has Primary channel at 1F0h. Secondary channel at 170h can be Enabled or Disabled.
	cmp		BYTE [di+DPT.wBasePort], DEVICE_ATA_SECONDARY_PORT & 0FFh
	je		SHORT .CalculateTimingsForQD65xx		; Secondary Channel so no need to modify DX
	dec		dx
	dec		dx							; Primary Channel IDE Timing Register

	; We need the PIO Cycle Time in CX to calculate Active and Recovery Times.
.CalculateTimingsForQD65xx:
	call	AdvAtaInit_SelectSlowestCommonPioTimingsToBXandCXfromDSSIandDSDI

	; Calculate Active Time value for QD65xx IDE Timing Register
	call	AtaID_GetActiveTimeToAXfromPioModeInBX
	call	ConvertNanosecsFromAXwithLimitsInBPtoRegisterValue
	xchg	bp, ax

	; Calculate Recovery Time value for QD65xx IDE Timing Register
	xchg	ax, cx
	mov		bl, [cs:bx+.rgbToSubtractFromCycleTimeBasedOnPIOmode]
	sub		ax, bx
	mov		bx, bp						; Active Time value now in BL
	mov		bp, QD65xx_MAX_RECOVERY_TIME_CLOCKS | (QD65xx_MIN_RECOVERY_TIME_CLOCKS << 8)
	call	ConvertNanosecsFromAXwithLimitsInBPtoRegisterValue

	; Merge the values to a single byte to output
	eSHL_IM	al, POSITION_QD65XXIDE_RECOVERY_TIME
	or		al, bl
	out		dx, al
	ret									; Return with CF cleared

.rgbToSubtractFromCycleTimeBasedOnPIOmode:
	; For PIO 0 to 2 this method (t0 - (t1+t8+t9)) seems to give closest (little less) values to the fixed preset
	; values used by QDI6580 DOS driver v3.7
	db		(PIO_0_MIN_ADDRESS_VALID_NS + PIO_0_MAX_ADDR_VALID_TO_IOCS16_RELEASED + PIO_0_DIORW_TO_ADDR_VALID_HOLD)
	db		(PIO_1_MIN_ADDRESS_VALID_NS + PIO_1_MAX_ADDR_VALID_TO_IOCS16_RELEASED + PIO_1_DIORW_TO_ADDR_VALID_HOLD)
	db		(PIO_2_MIN_ADDRESS_VALID_NS + PIO_2_MAX_ADDR_VALID_TO_IOCS16_RELEASED + PIO_2_DIORW_TO_ADDR_VALID_HOLD)
	db		102		; QDI6580 DOS driver v3.7 uses fixed values for PIO 3...
	db		61		; ...and PIO 4. No idea where these values come from.
	db		(PIO_5_MIN_CYCLE_TIME_NS / 2) ; PIO 5 and 6 were not available when QD6850 was released. Use values...
	db		(PIO_6_MIN_CYCLE_TIME_NS / 2) ; ...that resembles those used for PIO 4


;--------------------------------------------------------------------
; ConvertNanosecsFromAXwithLimitsInBPtoRegisterValue
;	Parameters:
;		AX:		Nanosecs to convert
;		BP:		Low Byte:	Maximum allowed ticks
;				High Byte:	Minimum allowed ticks
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;	Returns:
;		AL:		Timing value for QD65xx register
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ConvertNanosecsFromAXwithLimitsInBPtoRegisterValue:
	push	cx

	; Get VLB Cycle Time in nanosecs
	mov		cl, VLB_33MHZ_CYCLE_TIME	; Assume 33 MHz or slower VLB bus (30 ns)
	test	BYTE [di+DPT_ADVANCED_ATA.wControllerID], FLG_QDCONFIG_ID3
	eCMOVZ	cl, VLB_40MHZ_CYCLE_TIME	; (25 ns)

	; Convert value in AX to VLB ticks
	div		cl							; AL = VLB ticks
	inc		ax							; Round up

	; Limit value to QD65xx limits
	mov		cx, bp
	MAX_U	al, ch						; Make sure not below minimum
	MIN_U	al, cl						; Make sure not above maximum

	; Not done yet, we need to invert the ticks since 0 is the slowest
	; value on the timing register
	sub		cl, al
	xchg	ax, cx						; Return in AL

	pop		cx
	ret
