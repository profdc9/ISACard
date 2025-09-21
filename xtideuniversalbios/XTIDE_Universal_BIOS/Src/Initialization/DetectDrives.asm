; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for detecting drive for the BIOS.

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
; Detects all IDE hard disks to be controlled by this BIOS.
;
; DetectDrives_FromAllIDEControllers
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		All (not segments)
;--------------------------------------------------------------------
DetectDrives_FromAllIDEControllers:
	call	RamVars_GetIdeControllerCountToCX
	mov		bp, ROMVARS.ideVars0			; CS:BP now points to first IDEVARS

.DriveDetectLoop:							; Loop through IDEVARS
	push	cx

	mov		cx, g_szDetectMaster
	mov		bh, MASK_DRVNHEAD_SET								; Select Master drive
	call	StartDetectionWithDriveSelectByteInBHandStringInCX	; Detect and create DPT + BOOTNFO

	test	BYTE [cs:bp+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags], FLG_DRVPARAMS_DO_NOT_DETECT
	jnz		SHORT .SkipSlaveDetection
	mov		cx, g_szDetectSlave
	mov		bh, MASK_DRVNHEAD_SET | FLG_DRVNHEAD_DRV
	call	StartDetectionWithDriveSelectByteInBHandStringInCX
.SkipSlaveDetection:

%ifdef MODULE_HOTKEYS
%ifdef MODULE_SERIAL OR MODULE_SD
	; This is only needed for hotkey F6 (ComDtct) to work
	call	ScanHotkeysFromKeyBufferAndStoreToBootvars			; Done here while CX is still protected
%endif
%endif

	pop		cx

	add		bp, BYTE IDEVARS_size			; Point to next IDEVARS

%ifdef MODULE_SERIAL OR MODULE_SD
	jcxz	.AddHardDisks					; Set to zero on .ideVarsSerialAuto iteration (if any)
%endif
	loop	.DriveDetectLoop

%ifdef MODULE_SD
	call	FindDPT_ToDSDIforSDDevice	; Does not modify AX
	jnc		SHORT .ContModuleSerial
	mov		bp, ROMVARS.ideVarsSDAuto	; Point to our special IDEVARS structure, just for SD scans

	mov		al, [cs:ROMVARS.wFlags]			; Configurator set to always scan?
	and		al, 16							; FLG_ROMVARS_SD_SCANDETECT
	jnz		SHORT .DriveDetectLoop
.ContModuleSerial:
%endif

%ifdef MODULE_SERIAL
;----------------------------------------------------------------------
;
; if serial drive detected, do not scan (avoids duplicate drives and isn't needed - we already have a connection)
;
	call	FindDPT_ToDSDIforSerialDevice	; Does not modify AX
	jnc		SHORT .AddHardDisks

	mov		bp, ROMVARS.ideVarsSerialAuto	; Point to our special IDEVARS structure, just for serial scans

%ifdef MODULE_HOTKEYS
	cmp		al, COM_DETECT_HOTKEY_SCANCODE	; Set by last call to ScanHotkeysFromKeyBufferAndStoreToBootvars above
	je		SHORT .DriveDetectLoop
%endif

	mov		al, [cs:ROMVARS.wFlags]			; Configurator set to always scan?
	or		al, [es:BDA.bKBFlgs1]			; Or, did the user hold down the ALT key?
	and		al, 8							; 8 = alt key depressed, same as FLG_ROMVARS_SERIAL_SCANDETECT
	jnz		SHORT .DriveDetectLoop
%endif ; MODULE_SERIAL

.AddHardDisks:
;----------------------------------------------------------------------
;
; Add in hard disks to BDA, finalize our Count and First variables
;
; Note that we perform the add to bHDCount and store bFirstDrv even if the count is zero.
; This is done because we use the value of .bFirstDrv to know how many drives were in the system
; at the time of boot, and to return that number on int13h/8h calls.  Because the count is zero,
; FindDPT_ForDriveNumber will not find any drives that are ours.
;

; This is a hack to get Windows 9x to load its built-in protected mode IDE driver.
;
; The Windows hack has two parts. First part is to try to alter CMOS address 12h as that
; is what Windows 9x driver reads to detect IDE drives. Altering is not possible on all
; systems since CMOS has a checksum but its location is not standardized. We will first
; try to detect valid checksum. If it succeeds, then it is safe to assume this system
; has compatible CMOS and we can alter it.
; If verify fails, we do the more dirty hack to zero BDA drive count. Then Windows 9x works
; as long as user has configured at least one drive in the BIOS setup.
%ifdef MODULE_WIN9X_CMOS_HACK
	mov		dl, HARD_DISK_TYPES
	call	CMOS_ReadFromIndexInDLtoAL
	test	al, 0F0h
	jnz		SHORT .ClearBdaDriveCount		; CMOS byte 12h is ready for Windows 9x
	call	CMOS_Verify10hTo2Dh				; Can we modify CMOS?
	jnz		SHORT .ClearBdaDriveCount		; Unsupported BIOS, use plan B

	; Now we can alter CMOS location 12h. Award BIOS locks if we set drive 0 type to Fh
	; (but accept changes to drive type 1). Windows 9x requires that the drive 0 type is
	; non zero and ignores drive 1 type. So if we only set drive 1, then Award BIOS
	; won't give problems but Windows 9x stays in MS-DOS compatibility mode.
	;
	; For Award BIOSes we could set the Drive 0 type to 1 and then clear the BDA drive count.
	; So essentially we could automatically do what user needs to do manually to get Windows 9x
	; working on Award BIOSes. However, I think that should be left to do manually since
	; there may be SCSI drives on the system or FLG_ROMVARS_CLEAR_BDA_HD_COUNT could
	; be intentionally cleared and forcing the dummy drive might cause only trouble.

	; Try to detect Award BIOS (Seems to work on a tested 128k BIOS so hopefully
	; there will be no need to scan E000h segment)
	mov		cx, 65536 - 4
	mov		eax, 'Awar'						; Four characters should be enough
	mov		di, 0F000h						; Scan 64k starting from segment F000h
	mov		fs, di							; No need to preserve FS since we set it to zero soon when we boot
	xor		di, di
.ScanNextCharacters:
	cmp		[fs:di], eax
	je		SHORT .ClearBdaDriveCount		; Award detected, cannot modify CMOS
	inc		di								; Increment offset by one character (not four)
	loop	.ScanNextCharacters

	; Now it should be safe to write
	mov		dl, HARD_DISK_TYPES
	mov		al, 0F0h						; Drive 0 type 16...47 (supposed to be defined elsewhere in the CMOS)
	call	CMOS_WriteALtoIndexInDL
	call	CMOS_StoreNewChecksumFor10hto2Dh
.ClearBdaDriveCount:
%endif ; MODULE_WIN9X_CMOS_HACK

	mov		cx, [RAMVARS.wDrvCntAndFlopCnt]	; Our count of hard disks
	mov		al, [es:BDA.bHDCount]
%ifndef MODULE_MFM_COMPATIBILITY
	; This is excluded when MODULE_MFM_COMPATIBILITY is included because it doesn't make sense to use both at the same time anyway.
	; Note that the option to "Remove other hard drives" is still visible in XTIDECFG.COM for builds including MODULE_MFM_COMPATIBILITY.
	; Changing that option just won't do anything. We might want to remove the option for builds that contain MODULE_MFM_COMPATIBILITY
	; but that would require a ROMVARS flag that is probably better spent on other things.
	test	BYTE [cs:ROMVARS.wFlags], FLG_ROMVARS_CLEAR_BDA_HD_COUNT	; Clears CF
	jz		SHORT .ContinueInitialization
%ifdef USE_UNDOC_INTEL
	salc
%else
	xor		al, al
%endif
.ContinueInitialization:
%endif ; MODULE_MFM_COMPATIBILITY
	add		cl, al
	mov		[es:BDA.bHDCount], cl			; Update the system count
	or		al, 80h							; Or in hard disk flag
	mov		[RAMVARS.bFirstDrv], al			; Store first drive number

.AddFloppies:
%ifdef MODULE_SERIAL_FLOPPY
;----------------------------------------------------------------------
;
; Add in any emulated serial floppy drives, finalize our packed Count and First variables
;
	dec		ch
	mov		al, ch
	js		SHORT .NoFloppies				; If no drives are present, we store 0FFh

	call	FloppyDrive_GetCountFromBIOS_or_BDA

	push	ax

	add		al, ch							; Add our drives to existing drive count
	cmp		al, 3							; For BDA, max out at 4 drives (ours is zero based)
	jb		SHORT .MaxBDAFloppiesExceeded
	mov		al, 3
.MaxBDAFloppiesExceeded:
	eROR_IM	al, 2							; move to bits 6-7
	inc		ax								; low order bit, indicating floppy drive exists

	mov		ah, 3Eh							; AND mask to AH (all bits set except floppy drive count/present)
	and		ah, [es:BDA.wEquipment]			; Load Equipment WORD low byte and mask off drive number and drives present bit
	or		al, ah							; Or in new values
	mov		[es:BDA.wEquipment], al			; and store

	mov		al, 1Eh							; BDA pointer to Floppy DPT
	mov		si, AH8h_FloppyDPT
	call	Interrupts_InstallHandlerToVectorInALFromCSSI

	pop		ax

	shr		ch, 1							; number of drives, 1 or 2 only, to CF flag (clear=1, set=2)
	eRCL_IM	al, 1							; starting drive number in upper 7 bits, number of drives in low bit
.NoFloppies:
	mov		[RAMVARS.xlateVars+XLATEVARS.bFlopCntAndFirst], al
%endif
	ret

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
	%if FLG_ROMVARS_SERIAL_SCANDETECT != 8
		%error "DetectDrives is currently coded to assume that FLG_ROMVARS_SERIAL_SCANDETECT is the same bit as the ALT key code in the BDA.  Changes in the code will be needed if these values are no longer the same."
	%endif
%endif


;--------------------------------------------------------------------
; StartDetectionWithDriveSelectByteInBHandStringInCX
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		CX:		Offset to "Master" or "Slave" string
;		CS:BP:	Ptr to IDEVARS for the drive
;		DS:		RAMVARS segment
;		ES:		Zero (BDA segment)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BL, CX, DX, SI, DI
;--------------------------------------------------------------------
StartDetectionWithDriveSelectByteInBHandStringInCX:
	call	DetectPrint_StartDetectWithMasterOrSlaveStringInCXandIdeVarsInCSBP
	; Fall to .ReadAtaInfoFromHardDisk


;--------------------------------------------------------------------
; .ReadAtaInfoFromHardDisk
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		DX:		Autodetected port (for devices that support autodetection)
;		CS:BP:	Ptr to IDEVARS for the drive
;		DS:		RAMVARS segment
;		ES:		Zero (BDA segment)
;	Returns:
;		CF:		Cleared if ATA-information read successfully
;				Set if any error
;	Corrupts registers:
;		AX, BL, CX, DX, SI, DI
;--------------------------------------------------------------------
.ReadAtaInfoFromHardDisk:
	mov		si, BOOTVARS.rgbAtaInfo			; ES:SI now points to ATA info location
	push	es
	push	si
	push	dx
	push	bx
	call	Device_IdentifyToBufferInESSIwithDriveSelectByteInBH
	pop		bx
	pop		dx
	pop		si
	pop		es
	jnc		SHORT CreateBiosTablesForHardDisk
	; Fall to .ReadAtapiInfoFromDrive

.ReadAtapiInfoFromDrive:					; Not yet implemented
	;call	ReadAtapiInfoFromDrive			; Assume CD-ROM
	;jnc	SHORT _CreateBiosTablesForCDROM

	;jmp	short DetectDrives_DriveNotFound
;;; fall-through instead of previous jmp instruction
;--------------------------------------------------------------------
; DetectDrives_DriveNotFound
;	Parameters:
;		Nothing
;	Returns:
;		CF:		Set (from DetectPrint_NullTerminatedStringFromCSSIandSetCF)
;	Corrupts registers:
;		AX, SI
;--------------------------------------------------------------------
DetectDrives_DriveNotFound:
	mov		si, g_szNotFound
	jmp		DetectPrint_NullTerminatedStringFromCSSIandSetCF


;--------------------------------------------------------------------
; CreateBiosTablesForHardDisk
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		DX:		Autodetected port (for devices that support autodetection)
;		CS:BP:	Ptr to IDEVARS for the drive
;		ES:SI	Ptr to ATA information for the drive
;		DS:		RAMVARS segment
;		ES:		BDA segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
CreateBiosTablesForHardDisk:
%ifndef NO_ATAID_VALIDATION
	push	bx
	call	AtaID_VerifyFromESSI
	pop		bx
	jnz		SHORT DetectDrives_DriveNotFound
%endif
	call	CreateDPT_FromAtaInformation
	jc		SHORT DetectDrives_DriveNotFound
	call	DriveDetectInfo_CreateForHardDisk
	jmp		SHORT DetectPrint_DriveNameFromDrvDetectInfoInESBX
