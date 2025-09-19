; Project name	:	XTIDE Universal BIOS
; Description	:	IDE Device Command functions.

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
; IdeCommand_ResetMasterAndSlaveController
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
IdeCommand_ResetMasterAndSlaveController:	; Unused entrypoint OK
	; HSR0: Set_SRST
; Used to be:
;	call	AccessDPT_GetDeviceControlByteToAL
;	or		al, FLG_DEVCONTROL_SRST | FLG_DEVCONTROL_nIEN	; Set Reset bit
; Is now:
	mov		al, FLG_DEVCONTROL_SRST | FLG_DEVCONTROL_nIEN
; ---
	OUTPUT_AL_TO_IDE_CONTROL_BLOCK_REGISTER		DEVICE_CONTROL_REGISTER_out
	mov		ax, HSR0_RESET_WAIT_US
	call	Timer_DelayMicrosecondsFromAX

	; HSR1: Clear_wait
; Used to be:
;	call	AccessDPT_GetDeviceControlByteToAL
;	or		al, FLG_DEVCONTROL_nIEN
;	and		al, ~FLG_DEVCONTROL_SRST						; Clear reset bit
; Is now:
	mov		al, FLG_DEVCONTROL_nIEN
; ---
	OUTPUT_AL_TO_IDE_CONTROL_BLOCK_REGISTER		DEVICE_CONTROL_REGISTER_out
	mov		ax, HSR1_RESET_WAIT_US
	call	Timer_DelayMicrosecondsFromAX

	; HSR2: Check_status
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_MAXIMUM, FLG_STATUS_BSY)
	jmp		IdeWait_PollStatusFlagInBLwithTimeoutInBH

; *FIXME* AccessDPT_GetDeviceControlByteToAL currently always returns with
; AL cleared (0) or with only bit 1 set (FLG_DEVCONTROL_nIEN = 2).
; The commented away instructions above sets FLG_DEVCONTROL_nIEN anyway
; making the call to AccessDPT_GetDeviceControlByteToAL redundant.
; I have left this code as is since I don't know if it's a mistake
; (from all the way back to r150) or if it's coded this way in anticipation
; of some future changes to AccessDPT_GetDeviceControlByteToAL.

;--------------------------------------------------------------------
; IdeCommand_IdentifyDeviceToBufferInESSIwithDriveSelectByteInBH
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Select Register
;		DX:		Autodetected port for XT-CF
;		DS:		Segment to RAMVARS
;		ES:SI:	Ptr to buffer to receive 512-byte IDE Information
;		CS:BP:	Ptr to IDEVARS
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI, DI, ES
;--------------------------------------------------------------------
IdeCommand_IdentifyDeviceToBufferInESSIwithDriveSelectByteInBH:		; Unused entrypoint OK
	; Create fake DPT to be able to use Device.asm functions
	call	FindDPT_ForNewDriveToDSDI
	eMOVZX	ax, bh
	mov		[di+DPT.wFlags], ax
	call	CreateDPT_StoreIdevarsOffsetAndBasePortFromCSBPtoDPTinDSDI
	call	IdeDPT_StoreDeviceTypeToDPTinDSDIfromIdevarsInCSBP
	mov		BYTE [di+DPT_ATA.bBlockSize], 1	; Block = 1 sector

	; Wait until drive motors have reached full speed
	cmp		bp, BYTE ROMVARS.ideVars0	; First controller?
	jne		SHORT .SkipLongWaitSinceDriveIsNotPrimaryMaster
	test	bh, FLG_DRVNHEAD_DRV		; Wait already done for Master
	jnz		SHORT .SkipLongWaitSinceDriveIsNotPrimaryMaster
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_MOTOR_STARTUP, FLG_STATUS_BSY)
	call	IdeWait_PollStatusFlagInBLwithTimeoutInBH
.SkipLongWaitSinceDriveIsNotPrimaryMaster:

	; Create IDEPACK without INTPACK
	push	bp
	call	Idepack_FakeToSSBP

%ifdef MODULE_8BIT_IDE
	push	si

	; Enable 8-bit PIO for DEVICE_8BIT_ATA (no need to verify device type here)
	call	AH9h_Enable8bitModeForDevice8bitAta

	; Set XT-CF mode. No need to check here if device is XT-CF or not.
%ifdef MODULE_8BIT_IDE_ADVANCED
	call	AH1Eh_GetCurrentXTCFmodeToAX	; Reads from DPT_ATA.bDevice that we just stored
	call	AH9h_SetModeFromALtoXTCF		; Enables/disables 8-bit mode when necessary
%endif ; MODULE_8BIT_IDE_ADVANCED
	pop		si
%endif ; MODULE_8BIT_IDE

	; Prepare to output Identify Device command
	mov		dl, 1						; Sector count (required by IdeTransfer.asm)
	mov		al, COMMAND_IDENTIFY_DEVICE
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRQ, FLG_STATUS_DRQ)
	call	Idepack_StoreNonExtParametersAndIssueCommandFromAL

	; Clean stack and return
	lea		sp, [bp+SIZE_OF_IDEPACK_WITHOUT_INTPACK]	; This assumes BP hasn't changed between Idepack_FakeToSSBP and here
	pop		bp
	ret


;--------------------------------------------------------------------
; IdeCommand_OutputWithParameters
;	Parameters:
;		BH:		System timer ticks for timeout
;		BL:		IDE Status Register bit to poll after command
;		ES:SI:	Ptr to buffer (for data transfer commands)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		INT 13h Error Code
;		CX:		Number of successfully transferred sectors (for transfer commands)
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, (CX), DX, (ES:SI for data transfer commands)
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeCommand_OutputWithParameters:	; Unused entrypoint OK
	push	bx						; Store status register bits to poll

	; Select Master or Slave drive and output head number or LBA28 top bits
	call	IdeCommand_SelectDrive
	jc		SHORT .DriveNotReady

	; Output Device Control Byte to enable or disable interrupts
	mov		al, [bp+IDEPACK.bDeviceControl]
%ifdef MODULE_IRQ
	test	al, FLG_DEVCONTROL_nIEN	; Interrupts disabled?
	jnz		SHORT .DoNotSetInterruptInServiceFlag

	; Clear Task Flag and set Interrupt In-Service Flag
	push	ds
	LOAD_BDA_SEGMENT_TO	ds, dx
	mov		BYTE [BDA.bHDTaskFlg], 1	; Will be adjusted to zero later
	pop		ds
.DoNotSetInterruptInServiceFlag:
%endif
	OUTPUT_AL_TO_IDE_CONTROL_BLOCK_REGISTER		DEVICE_CONTROL_REGISTER_out

	; Output Feature Number
	mov		al, [bp+IDEPACK.bFeatures]
	OUTPUT_AL_TO_IDE_REGISTER	FEATURES_REGISTER_out

	; Output Sector Address High (only used by LBA48)
%ifdef MODULE_EBIOS
	mov		ah, [bp+IDEPACK.bLbaLowExt]
	xor		al, al							; Zero sector count
	mov		cx, [bp+IDEPACK.wLbaMiddleAndHighExt]
	call	OutputSectorCountAndAddress
%endif

	; Output Sector Address Low
	mov		ax, [bp+IDEPACK.wSectorCountAndLbaLow]
	mov		cx, [bp+IDEPACK.wLbaMiddleAndHigh]
	call	OutputSectorCountAndAddress

	; Output command
	mov		al, [bp+IDEPACK.bCommand]
	OUTPUT_AL_TO_IDE_REGISTER	COMMAND_REGISTER_out

	; Wait until command completed
	pop		bx								; Pop status and timeout for polling
	cmp		bl, FLG_STATUS_DRQ				; Data transfer started?
	jne		SHORT .WaitUntilNonTransferCommandCompletes
%ifdef MODULE_8BIT_IDE_ADVANCED
	cmp		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_JRIDE_ISA
	jae		SHORT JrIdeTransfer_StartWithCommandInAL	; DEVICE_8BIT_JRIDE_ISA or DEVICE_8BIT_ADP50L
%endif
	jmp		IdeTransfer_StartWithCommandInAL

.WaitUntilNonTransferCommandCompletes:
%ifdef MODULE_IRQ
	test	BYTE [bp+IDEPACK.bDeviceControl], FLG_DEVCONTROL_nIEN
%ifdef USE_386
	jnz		IdeWait_IRQorStatusFlagInBLwithTimeoutInBH
%else
	jz		SHORT .PollStatusFlagInsteadOfWaitIrq
	jmp		IdeWait_IRQorStatusFlagInBLwithTimeoutInBH
.PollStatusFlagInsteadOfWaitIrq:
%endif
%endif ; MODULE_IRQ
	jmp		IdeWait_PollStatusFlagInBLwithTimeoutInBH

.DriveNotReady:
	pop		bx							; Clean stack
	ret


;--------------------------------------------------------------------
; IdeCommand_SelectDrive
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeCommand_SelectDrive:
	; We use different timeout value when detecting drives.
	; This prevents unnecessary long delays when drive is not present.
	mov		cx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRDY, FLG_STATUS_DRDY)
	cmp		WORD [RAMVARS.wDrvDetectSignature], RAMVARS_DRV_DETECT_SIGNATURE
	eCMOVE	ch, TIMEOUT_SELECT_DRIVE_DURING_DRIVE_DETECTION

	; Select Master or Slave Drive
	mov		al, [bp+IDEPACK.bDrvAndHead]
	OUTPUT_AL_TO_IDE_REGISTER	DRIVE_AND_HEAD_SELECT_REGISTER
	mov		bx, cx
	call	IdeWait_PollStatusFlagInBLwithTimeoutInBH

	; Output again to make sure head bits are set. They were lost if the device
	; was busy when we first output drive select (although it shouldn't be busy
	; since we have waited error result after previous command). Some low power
	; drives (CF cards, 1.8" HDDs etc) have some internal sleep modes that
	; might cause trouble? Normal HDDs seem to work fine.
	;
	; Now commented away since this fix was not necessary. Let's keep it here
	; if some drive someday has problems crossing 8GB
	;mov		al, [bp+IDEPACK.bDrvAndHead]
	;OUTPUT_AL_TO_IDE_REGISTER	DRIVE_AND_HEAD_SELECT_REGISTER

	; Ignore errors from IDE Error Register (set by previous command)
	cmp		ah, RET_HD_TIMEOUT
	je		SHORT .FailedToSelectDrive
	xor		ax, ax					; Always success unless timeout
	ret
.FailedToSelectDrive:
	stc
	ret


;--------------------------------------------------------------------
; OutputSectorCountAndAddress
;	Parameters:
;		AH:		LBA low bits (Sector Number)
;		AL:		Sector Count
;		CL:		LBA middle bits (Cylinder Number low)
;		CH:		LBA high bits (Cylinder Number high)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AL, BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
OutputSectorCountAndAddress:
	OUTPUT_AL_TO_IDE_REGISTER	SECTOR_COUNT_REGISTER

	mov		al, ah
	OUTPUT_AL_TO_IDE_REGISTER	LBA_LOW_REGISTER

	mov		al, cl
	OUTPUT_AL_TO_IDE_REGISTER	LBA_MIDDLE_REGISTER

	mov		al, ch
	OUTPUT_AL_TO_IDE_REGISTER	LBA_HIGH_REGISTER
	ret


;--------------------------------------------------------------------
; IdeCommand_ReadLBAlowRegisterToAL
; Returns LBA low register / Sector number register contents.
; Note that this returns valid value only after transfer command (read/write/verify)
; has stopped to an error. Do not call this otherwise.
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AL:		Byte read from the register
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeCommand_ReadLBAlowRegisterToAL:
	; HOB bit (defined in 48-bit address feature set) should be zero by default
	; so we get the correct value for CHS, LBA28 and LBA48 drives and commands
	INPUT_TO_AL_FROM_IDE_REGISTER	LBA_LOW_REGISTER
	ret
