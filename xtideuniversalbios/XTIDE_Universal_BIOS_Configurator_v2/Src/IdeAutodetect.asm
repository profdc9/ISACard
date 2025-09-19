; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions to detect ports and devices.

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

IDE_PORT_TO_START_DETECTION			EQU	00h		; Must be zero (not actual port)
FIRST_MEMORY_SEGMENT_ADDRESS		EQU	0C000h

;--------------------------------------------------------------------
; IdeAutodetect_DetectIdeDeviceFromPortDXAndReturnControlBlockInSI
;	Parameters:
;		DX:		IDE Base Port or segment address (Command Block)
;		DS:DI:	Ptr to ROMVARS
;	Returns:
;		AL:		Device Type
;		SI:		IDE Control Block Base port (port mapped devices only)
;		CF:		Clear if IDE Device found
;				Set if IDE Device not found
;	Corrupts registers:
;		AH, BX
;--------------------------------------------------------------------
IdeAutodetect_DetectIdeDeviceFromPortDXAndReturnControlBlockInSI:
	cmp		dh, FIRST_MEMORY_SEGMENT_ADDRESS >> 8
	jb		SHORT DetectPortMappedDeviceFromPortDX
	; Fall to DetectMemoryMappedDeviceFromSegmentDX

;--------------------------------------------------------------------
; DetectMemoryMappedDeviceFromSegmentDX
;	Parameters:
;		DX:		Segment address for Memory Mapped Device
;		DS:DI:	Ptr to ROMVARS
;	Returns:
;		AL:		Device Type
;		CF:		Clear if IDE Device found
;				Set if IDE Device not found
;	Corrupts registers:
;		AH, BX
;--------------------------------------------------------------------
DetectMemoryMappedDeviceFromSegmentDX:
	; *** Try to detect JR-IDE/ISA and ADP50L (only if MODULE_8BIT_IDE_ADVANCED is present) ***
	test	BYTE [di+ROMVARS.wFlags], FLG_ROMVARS_MODULE_8BIT_IDE_ADVANCED
	stc
	jz		SHORT .NoIdeDeviceFound

	push	ds
	mov		ds, dx

	cli
	mov		ah, [JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET + STATUS_REGISTER_in]
	mov		al, [JRIDE_CONTROL_BLOCK_REGISTER_WINDOW_OFFSET + ALTERNATE_STATUS_REGISTER_in]
	sti
	call	CompareIdeStatusRegistersFromALandAH
	mov		al, DEVICE_8BIT_JRIDE_ISA
	jnc		.IdeDeviceFound

	cli
	mov		ah, [ADP50L_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET + (STATUS_REGISTER_in << 1)]
	mov		al, [ADP50L_CONTROL_BLOCK_REGISTER_WINDOW_OFFSET + (ALTERNATE_STATUS_REGISTER_in << 1)]
	sti
	call	CompareIdeStatusRegistersFromALandAH
	mov		al, DEVICE_8BIT_ADP50L

.IdeDeviceFound:
	mov		si, dx						; For IDEDTCT.COM
	pop		ds
.NoIdeDeviceFound:
	ret


;--------------------------------------------------------------------
; DetectPortMappedDeviceFromPortDX
;	Parameters:
;		DX:		IDE Base Port (Command Block)
;		DS:DI:	Ptr to ROMVARS
;	Returns:
;		AL:		Device Type
;		SI:		IDE Control Block Base port
;		CF:		Clear if IDE Device found
;				Set if IDE Device not found
;	Corrupts registers:
;		AH, BX
;--------------------------------------------------------------------
DetectPortMappedDeviceFromPortDX:
	mov		si, dx
	mov		bx, STATUS_REGISTER_in | (ALTERNATE_STATUS_REGISTER_in << 8)
	; *** Try to detect AC-1075 / AC-1070 controllers ***
	cmp		dh, 25h
	jne		SHORT .NotArcoComputerProducts
	add		si, BYTE 8					; Add control block offset
	call	DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH
	mov		al, DEVICE_16BIT_ATA
	ret
.NotArcoComputerProducts:
	; *** Try to detect Standard 16- and 32-bit IDE Devices ***
	mov		al, DEVICE_16BIT_ATA		; Assume 16-bit ISA slot for AT builds
	call	Buffers_IsXTbuildLoaded
	eCMOVE	al, DEVICE_8BIT_ATA			; Assume 8-bit ISA slot for XT builds

	; Start with standard Control Block base port used by Primary and Secondary IDE
	add		si, STANDARD_CONTROL_BLOCK_OFFSET
.RedetectTertiaryOrQuaternaryWithDifferentControlBlockAddress:
	push	ax							; Store device type
	call	DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH
	pop		ax							; Restore device type
	jnc		SHORT .IdeDeviceFound

	; 16- or 32-bit IDE Device was not found but we may have used wrong Control Block port if we were trying
	; to detect Tertiary or Quaternary IDE controllers. Control Block port location is not standardized. For
	; example Promise FloppyMAX has Control Block at STANDARD_CONTROL_BLOCK_OFFSET but Sound Blaster 16 (CT2290)
	; use DEVICE_ATA_SECONDARY_PORTCTRL for Tertiary and Quaternary even though only Secondary should use that.
	call	ChangeControlBlockAddressInSI
	jz		SHORT .RedetectTertiaryOrQuaternaryWithDifferentControlBlockAddress

	; Detect 8-bit devices only if MODULE_8BIT_IDE is available
	test	BYTE [di+ROMVARS.wFlags], FLG_ROMVARS_MODULE_8BIT_IDE | FLG_ROMVARS_MODULE_8BIT_IDE_ADVANCED
	jz		SHORT NoIdeDeviceFound
	jpo		SHORT .SkipXTCF				; Only 1 bit set means no MODULE_8BIT_IDE_ADVANCED

	; *** Try to detect XT-CF ***
	mov		si, dx
	add		si, BYTE XTCF_CONTROL_BLOCK_OFFSET
	eSHL_IM	bx, 1						; SHL 1 register offsets for XT-CF
	call	DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH
	jc		SHORT .ContinueDetection
	mov		al, DEVICE_8BIT_XTCF_PIO8_WITH_BIU_OFFLOAD
	cmp		BYTE [cs:IsOlivettiM24], 1
	jne		SHORT .IdeDeviceFound
	mov		al, DEVICE_8BIT_XTCF_PIO8
	ret		; With CF cleared
.ContinueDetection:
	shr		bx, 1
.SkipXTCF:

	; *** Try to detect 8-bit XT-IDE rev 1 or rev 2 ***
	; Note that A0<->A3 address swaps Status Register and Alternative
	; Status Register addresses. That is why we need another step
	; to check is this XT-IDE rev 1 or rev 2.
	mov		si, dx
	add		si, BYTE XTIDE_CONTROL_BLOCK_OFFSET
	call	DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH
	jc		SHORT NoIdeDeviceFound		; No XT-IDE rev 1 or rev 2 found

	; Now we can be sure that we have XT-IDE rev 1 or rev 2.
	; Rev 2 swaps address lines A0 and A3 thus LBA Low Register
	; moves from offset 3h to offset Ah. There is no Register at
	; offset Ah so if we can write to it and read back, then we
	; must have XT-IDE rev 2 or modded rev 1.
	push	dx
	add		dx, BYTE 0Ah				; LBA Low Register for XT-IDE rev 2
	mov		al, DEVICE_8BIT_XTIDE_REV2	; Our test byte
	out		dx, al						; Output our test byte
	JMP_DELAY
	in		al, dx						; Read back
	pop		dx
	cmp		al, DEVICE_8BIT_XTIDE_REV2
	jne		SHORT .XtideRev1
	cmp		BYTE [cs:IsOlivettiM24], 1
	jne		SHORT .IdeDeviceFound
	mov		al, DEVICE_8BIT_XTIDE_REV2_OLIVETTI
	ret		; With CF cleared
.XtideRev1:
	mov		al, DEVICE_8BIT_XTIDE_REV1	; We must have rev 1
.IdeDeviceFound:
	clc
	ret


;--------------------------------------------------------------------
; DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH
;	Parameters:
;		BL:		Offset to IDE Status Register
;		BH:		Offset to Alternative Status Register
;		DX:		IDE Base Port address
;		SI:		IDE Control Block address
;	Returns:
;		CF:		Clear if IDE Device found
;				Set if IDE Device not found
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
DetectIdeDeviceFromPortsDXandSIwithOffsetsInBLandBH:
	; Read Status and Alternative Status Registers
	push	dx

	add		dl, bl
	cli							; Disable Interrupts
	in		al, dx				; Read Status Register...
	mov		ah, al				; ...to AH
	mov		dx, si
	add		dl, bh
	in		al, dx				; Read Alternative Status Register to AL
	sti							; Enable Interrupts

	pop		dx
	; Fall to CompareIdeStatusRegistersFromALandAH


;--------------------------------------------------------------------
; CompareIdeStatusRegistersFromALandAH
;	Parameters:
;		AH:		Possible IDE Status Register contents
;		AL:		Possible IDE Alternative Status Register contents
;	Returns:
;		CF:		Clear if valid Status Register Contents
;				Set if not possible IDE Status Registers
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
CompareIdeStatusRegistersFromALandAH:
	; Status Register now in AH and Alternative Status Register in AL.
	; They must be the same if base port was in use by IDE device.
	cmp		al, ah
	jne		SHORT NoIdeDeviceFound

	; Bytes were the same but it is possible they were both FFh, for
	; example. We must make sure bits are what is expected from valid
	; IDE Status Register. So far all drives I've tested return 50h
	; (FLG_STATUS_DRDY and FLG_STATUS_DSC set) or 00h.
	; I suspect that the zero might mean non available drive is selected. For example if Master
	; drive is present but Slave is selected from IDE Drive and Head Select Register,
	; then the Status Register can be 00h. We cannot accept 00h as valid byte
	; since that can easily cause invalid JR-IDE/ISA detections.
	test	al, FLG_STATUS_BSY | FLG_STATUS_DF | FLG_STATUS_DRQ | FLG_STATUS_ERR
	jnz		SHORT NoIdeDeviceFound	; Busy or Errors cannot be set
	test	al, FLG_STATUS_DRDY
	jz		SHORT NoIdeDeviceFound	; Device needs to be ready
	ret								; Return with CF cleared

NoIdeDeviceFound:
	stc
	ret


;--------------------------------------------------------------------
; ChangeControlBlockAddressInSI
;	Parameters:
;		DX:		IDE Base Port address
;		SI:		IDE Control Block address
;	Returns:
;		ZF:		Set if SI changed
;				Cleared if different control block address is not possible
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ChangeControlBlockAddressInSI:
	cmp		si, 368h
	je		SHORT .TrySecondAlternative
	cmp		si, 3E8h
	je		SHORT .TrySecondAlternative

	cmp		si, 360h
	je		SHORT .TryLastAlternative
	cmp		si, 3E0h
	jne		SHORT .Return	; With ZF cleared

.TryLastAlternative:
	mov		si, DEVICE_ATA_SECONDARY_PORTCTRL + 8	; Changes to 370h used by Sound Blaster 16 (CT2290)
	; Fall to .TrySecondAlternative
.TrySecondAlternative:
	lea		si, [si-8]		; 368h to 360h, 3E8h to 3E0h
.Return:
	ret


;--------------------------------------------------------------------
; IdeAutodetect_IncrementDXtoNextIdeBasePort
;	Parameters:
;		DX:		Previous IDE Base Port or IDE_PORT_TO_START_DETECTION
;	Returns:
;		DX:		Next IDE Base Port
;		ZF:		Set if no more Base Ports (DX was last base port on entry)
;				Clear if new base port returned in DX
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeAutodetect_IncrementDXtoNextIdeBasePort:
	cmp		dx, [cs:.wLastIdePort]
	je		SHORT .AllPortsAlreadyDetected

	push	si
	mov		si, .rgwIdeBasePorts
.CompareNextIdeBasePort:
	cmp		[cs:si], dx
	lea		si, [si+2]			; Increment SI and preserve FLAGS
	jne		SHORT .CompareNextIdeBasePort

	mov		dx, [cs:si]			; Get next port
	test	dx, dx				; Clear ZF
	pop		si
.AllPortsAlreadyDetected:
	ret


	; All ports used in autodetection. Ports can be in any order.
ALIGN WORD_ALIGN
.rgwIdeBasePorts:
	dw		IDE_PORT_TO_START_DETECTION		; Must be first
	; Standard IDE
	dw		DEVICE_ATA_PRIMARY_PORT
	dw		DEVICE_ATA_SECONDARY_PORT
	dw		DEVICE_ATA_TERTIARY_PORT
	dw		DEVICE_ATA_QUATERNARY_PORT
	; 8-bit Devices
	dw		200h
	dw		220h
	dw		240h
	dw		260h
	dw		280h
	dw		2A0h
	dw		2C0h
	dw		2E0h
	dw		300h
	dw		320h
	dw		340h
	dw		360h	; Acculogic sIDE-1/16 (same controller type as XT-IDE rev 1)
	dw		380h
	dw		3A0h
	dw		3C0h
	dw		3E0h
	; Arco Computer Products AC-1075 / AC-1070 (16-bit MCA IDE adapters with Control Block at +8 and no IRQ)
	dw		2510h
	dw		2520h
	; Memory Segment Addresses
	dw		0C000h	; JR-IDE/ISA
	dw		0C400h	; JR-IDE/ISA
	dw		0C800h	; JR-IDE/ISA and ADP50L
	dw		0CA00h	; ADP50L
	dw		0CC00h	; JR-IDE/ISA and ADP50L
	dw		0CE00h	; ADP50L
	dw		0D000h	; JR-IDE/ISA
	dw		0D400h	; JR-IDE/ISA
	dw		0D800h	; JR-IDE/ISA
.wLastIdePort:
	dw		0DC00h	; JR-IDE/ISA
