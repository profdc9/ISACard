; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions to automatically configure XTIDE
;					Universal BIOS for current system.

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
; AutoConfigure_ForThisSystem
; MENUITEM activation function (.fnActivate)
;	Parameters:
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except segments
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
AutoConfigure_ForThisSystem:
	push	es
	push	ds

	call	Buffers_GetFileBufferToESDI		; ROMVARS now in ES:DI
	push	es
	pop		ds								; ROMVARS now in DS:DI
	call	ChecksumSystemBios
	call	DetectOlivettiM24
	call	ResetIdevarsToDefaultValues
	call	DetectIdePortsAndDevices
	call	EnableInterruptsForAllStandardControllers
	call	StoreAndDisplayNumberOfControllers

	pop		ds
	pop		es
.Return:
	ret


;--------------------------------------------------------------------
; ChecksumSystemBios
;	Parameters:
;		DS:DI:	Ptr to ROMVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ChecksumSystemBios:
	push	ds
	mov		si, 0F000h
	mov		ds, si
	mov		si, 0FFFFh
	; DS:SI now points to the end of the System BIOS.
	std
	mov		cx, 32768	; The smallest known problematic BIOS so far.
	mov		dx, si		; Initialize the checksum
	call	CalculateCRC_CCITTfromDSSIwithSizeInCX
	pop		ds
	mov		bx, .Checksums
	cld
.NextChecksum:
	mov		ax, [cs:bx]
	test	ax, ax
	jz		SHORT AutoConfigure_ForThisSystem.Return
	inc		bx
	inc		bx
	cmp		ax, dx
	jne		SHORT .NextChecksum
	or		BYTE [di+ROMVARS.wFlags], FLG_ROMVARS_CLEAR_BDA_HD_COUNT
	mov		dx, g_szDlgBadBiosFound
	jmp		Dialogs_DisplayNotificationFromCSDX

ALIGN WORD_ALIGN
.Checksums:
	dw		0D192h						; 32 KB Zenith Z-161 (071784)
	dw		02F69h						; 32 KB Zenith Z-171 (031485)
	dw		0


;--------------------------------------------------------------------
; CalculateCRC_CCITTfromDSSIwithSizeInCX
;	Parameters:
;		DS:SI:	Pointer to string to checksum
;		CX:		Length of string to checksum
;		DX:		Checksum (initially 0FFFFh)
;		DF:		Set/Clear depending on direction wanted
;	Returns:
;		DX:		Checksum
;		DS:SI:	Pointer to byte after the end of checksummed string
;	Corrupts registers:
;		AX, BX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
CalculateCRC_CCITTfromDSSIwithSizeInCX:
;	jcxz	.Return
	xor		bh, bh
	mov		ah, 0E0h
.NextByte:
	lodsb
	xor		dh, al
	mov		bl, dh
	rol		bx, 1
	rol		bx, 1
	rol		bx, 1
	rol		bx, 1
	xor		dx, bx
	rol		bx, 1
	xchg	dh, dl
	xor		dx, bx
	ror		bx, 1
	ror		bx, 1
	ror		bx, 1
	ror		bx, 1
	and		bl, ah
	xor		dx, bx
	ror		bx, 1
	xor		dh, bl
	loop	.NextByte
;.Return:
	ret


;--------------------------------------------------------------------
; DetectOlivettiM24
;	Parameters:
;		Nothing
;	Returns:
;		ZF:		Set if computer is not an Olivetti M24
;				Clear if computer is an Olivetti M24
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DetectOlivettiM24:
	mov		ah, 0FEh	; Request the current date and time
	mov		ch, 0FFh	; Set the hours to an invalid value
	int		BIOS_TIME_PCI_PNP_INTERRUPT_1Ah
	inc		ch			; Hours changed?
	jz		SHORT .ThisIsNotAnOlivettiM24
	mov		BYTE [cs:IsOlivettiM24], 1
.ThisIsNotAnOlivettiM24:
	ret

IsOlivettiM24:
	db		0


;--------------------------------------------------------------------
; ResetIdevarsToDefaultValues
;	Parameters:
;		DS:DI:	Ptr to ROMVARS
;		ES:DI:	Ptr to ROMVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ResetIdevarsToDefaultValues:
	push	di
	add		di, BYTE ROMVARS.ideVarsBegin
	mov		cx, ROMVARS.ideVarsEnd - ROMVARS.ideVarsBegin
	call	Memory_ZeroESDIwithSizeInCX	; Never clears ROMVARS.ideVarsSerialAuto
	pop		di

	; Set default values (other than zero)
	mov		ax, DISABLE_WRITE_CACHE | (TRANSLATEMODE_AUTO<<TRANSLATEMODE_FIELD_POSITION) | FLG_DRVPARAMS_BLOCKMODE
	mov		[di+ROMVARS.ideVars0+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags], ax
	mov		[di+ROMVARS.ideVars0+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags], ax

	mov		[di+ROMVARS.ideVars1+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags], ax
	mov		[di+ROMVARS.ideVars1+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags], ax

	mov		[di+ROMVARS.ideVars2+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags], ax
	mov		[di+ROMVARS.ideVars2+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags], ax

	mov		[di+ROMVARS.ideVars3+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags], ax
	mov		[di+ROMVARS.ideVars3+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags], ax
	ret


;--------------------------------------------------------------------
; DetectIdePortsAndDevices
;	Parameters:
;		DS:DI:	Ptr to ROMVARS
;	Returns:
;		CX:		Number of controllers detected
;	Corrupts registers:
;		AX, BX, DX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DetectIdePortsAndDevices:
	xor		cx, cx							; Number of devices found
	xor		dx, dx							; IDE_PORT_TO_START_DETECTION
	lea		si, [di+ROMVARS.ideVarsBegin]	; DS:SI points to first IDEVARS

.DetectFromNextPort:
	call	IdeAutodetect_IncrementDXtoNextIdeBasePort
	jz		SHORT .AllPortsAlreadyDetected
	push	si
	call	IdeAutodetect_DetectIdeDeviceFromPortDXAndReturnControlBlockInSI
	mov		bx, si
	pop		si
	jc		SHORT .DetectFromNextPort

	; Device found from port DX, Device Type returned in AL
	inc		cx	; Increment number of controllers found
	mov		[si+IDEVARS.wBasePort], dx
	mov		[si+IDEVARS.wControlBlockPort], bx
	mov		[si+IDEVARS.bDevice], al

	; Point to next IDEVARS
	add		si, IDEVARS_size
	cmp		si, ROMVARS.ideVars3
	jbe		SHORT .DetectFromNextPort
.AllPortsAlreadyDetected:
	ret


;--------------------------------------------------------------------
; EnableInterruptsForAllStandardControllers
;	Parameters:
;		DS:DI:	Ptr to ROMVARS
;		CX:		Number of controllers detected
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EnableInterruptsForAllStandardControllers:
	jcxz	.NoControllersDetected
	call	Buffers_IsXTbuildLoaded
	je		SHORT .DoNotEnableIRQforXTbuilds
	push	di
	push	cx

	add		di, BYTE ROMVARS.ideVars0	; DS:DI now points first IDEVARS
.CheckNextController:
	mov		al, 14
	cmp		WORD [di+IDEVARS.wBasePort], DEVICE_ATA_PRIMARY_PORT
	je		SHORT .EnableIrqAL

	inc		ax	; 15
	cmp		WORD [di+IDEVARS.wBasePort], DEVICE_ATA_SECONDARY_PORT

%if 0
	je		SHORT .EnableIrqAL

	; Defaults on the GSI Inc. Model 2C EIDE controller
	mov		al, 11
	cmp		WORD [di+IDEVARS.wBasePort], DEVICE_ATA_TERTIARY_PORT
	je		SHORT .EnableIrqAL

	dec		ax	; 10
	cmp		WORD [di+IDEVARS.wBasePort], DEVICE_ATA_QUATERNARY_PORT
%endif

	jne		SHORT .DoNotEnableIRQ

.EnableIrqAL:
	mov		[di+IDEVARS.bIRQ], al
.DoNotEnableIRQ:
	add		di, IDEVARS_size
	loop	.CheckNextController
	pop		cx
	pop		di
.DoNotEnableIRQforXTbuilds:
.NoControllersDetected:
	ret


;--------------------------------------------------------------------
; StoreAndDisplayNumberOfControllers
;	Parameters:
;		CX:		Number of controllers detected
;		DS:DI:	Ptr to ROMVARS
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, DX, DI, SI, DS, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
StoreAndDisplayNumberOfControllers:
	xor		ax, ax
	or		al, cl
	jnz		SHORT .AtLeastOneController
	inc		ax							; Cannot store zero
.AtLeastOneController:
	test	BYTE [di+ROMVARS.wFlags], FLG_ROMVARS_FULLMODE
	jnz		SHORT .FullModeSoNoNeedToLimit
	MIN_U	al, MAX_LITE_MODE_CONTROLLERS
.FullModeSoNoNeedToLimit:

	; Store number of IDE Controllers. This will also modify
	; menu and set unsaved changes flag.
	push	cs
	pop		ds
	mov		si, g_MenuitemConfigurationIdeControllers
	call	Menuitem_StoreValueFromAXtoMenuitemInDSSI

	; Display results (should be changed to proper string formatting)
	add		cl, '0'
	mov		[cs:g_bControllersDetected], cl
	mov		dx, g_szDlgAutoConfigure
	jmp		Dialogs_DisplayNotificationFromCSDX
