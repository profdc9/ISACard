; Project name	:	XTIDE Universal BIOS
; Description	:	Command and port direction functions for different device types.

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


%macro TEST_USING_DPT_AND_JUMP_IF_SERIAL_DEVICE 1
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SERIAL_DEVICE
	jnz		SHORT %1
%endmacro

%macro TEST_USING_DPT_AND_JUMP_IF_SD_DEVICE 1
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SD_DEVICE
	jnz		SHORT %1
%endmacro

%macro CMP_USING_IDEVARS_IN_CSBP_AND_JUMP_IF 2
	cmp		BYTE [cs:bp+IDEVARS.bDevice], %1
	je		SHORT %2
%endmacro



;--------------------------------------------------------------------
; Device_FinalizeDPT
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
%ifdef MODULE_SERIAL OR MODULE_SD
Device_FinalizeDPT:
%ifdef MODULE_SD
	; Needs to check IDEVARS vs. checking the DPT as the SD bit in the DPT is set in the Finalize routine
	cmp		BYTE [cs:bp+IDEVARS.bDevice], DEVICE_SD
	jne		SHORT .Device_FinalizeDPT1
    jmp		SDDPT_Finalize
%endif
.Device_FinalizeDPT1:
%ifdef MODULE_SERIAL
	cmp		BYTE [cs:bp+IDEVARS.bDevice], DEVICE_SERIAL_PORT
	jne		SHORT .Device_FinalizeDPT2
	jmp		SerialDPT_Finalize
%endif
.Device_FinalizeDPT2:
	jmp		IdeDPT_Finalize
%else
	Device_FinalizeDPT		EQU		IdeDPT_Finalize
%endif

;--------------------------------------------------------------------
; Device_ResetMasterAndSlaveController
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
%ifdef MODULE_SERIAL OR MODULE_SD	; IDE + Serial
Device_ResetMasterAndSlaveController:
%ifdef MODULE_SD
	TEST_USING_DPT_AND_JUMP_IF_SD_DEVICE		ReturnSuccessForSerialPort
%endif
%ifdef MODULE_SERIAL
	TEST_USING_DPT_AND_JUMP_IF_SERIAL_DEVICE	ReturnSuccessForSerialPort
%endif
	jmp		IdeCommand_ResetMasterAndSlaveController

%else					; IDE
	Device_ResetMasterAndSlaveController	EQU		IdeCommand_ResetMasterAndSlaveController
%endif


;--------------------------------------------------------------------
; Device_IdentifyToBufferInESSIwithDriveSelectByteInBH
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Select Register
;		CX:		XUB_INT13h_SIGNATURE to ignore illegal ATA-ID values, otherwise
;				correct them (only used if NOT build with NO_ATAID_CORRECTION)
;		DX:		Autodetected port (for devices that support autodetection)
;		DS:		Segment to RAMVARS
;		ES:SI:	Ptr to buffer to receive 512-byte IDE Information
;		CS:BP:	Ptr to IDEVARS
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI, DI, ES
;--------------------------------------------------------------------
Device_IdentifyToBufferInESSIwithDriveSelectByteInBH:
%ifndef NO_ATAID_CORRECTION
	cmp		cx, XUB_INT13h_SIGNATURE
	je		SHORT .DoNotFixAtaInformation
	push	es
	push	si
	ePUSH_T	cx, AtaID_PopESSIandFixIllegalValuesFromESSI	; Here we modify ATA information if necessary
.DoNotFixAtaInformation:
%endif

%ifdef MODULE_SD
	cmp		BYTE [cs:bp+IDEVARS.bDevice], DEVICE_SD
	jne		SHORT .Device_IdentifyToBufferInESSIwithDriveSelectByteInBH1
	jmp		SDCommand_IdentifyDeviceToBufferInESSIwithDriveSelectByteInBH
%endif
.Device_IdentifyToBufferInESSIwithDriveSelectByteInBH1:
%ifdef MODULE_SERIAL
	cmp		BYTE [cs:bp+IDEVARS.bDevice], DEVICE_SERIAL_PORT
	jne		SHORT .Device_IdentifyToBufferInESSIwithDriveSelectByteInBH2
	jmp		SerialCommand_IdentifyDeviceToBufferInESSIwithDriveSelectByteInBH
%endif
.Device_IdentifyToBufferInESSIwithDriveSelectByteInBH2:
	jmp		IdeCommand_IdentifyDeviceToBufferInESSIwithDriveSelectByteInBH

;--------------------------------------------------------------------
; Device_OutputCommandWithParameters
;	Parameters:
;		BH:		Default system timer ticks for timeout (can be ignored)
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
%ifdef MODULE_SERIAL OR MODULE_SD	; IDE + Serial/SD
ALIGN JUMP_ALIGN
Device_OutputCommandWithParameters:
%ifdef MODULE_SD
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SD_DEVICE
	jz		.Device_OutputCommandWithParameters1
	jmp		SDCommand_OutputWithParameters
%endif
.Device_OutputCommandWithParameters1:
%ifdef MODULE_SERIAL
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SERIAL_DEVICE
	jz		.Device_OutputCommandWithParameters2
	jmp		SerialCommand_OutputWithParameters
%endif
.Device_OutputCommandWithParameters2:
	jmp		IdeCommand_OutputWithParameters
%else
	Device_OutputCommandWithParameters		EQU		IdeCommand_OutputWithParameters
%endif

;--------------------------------------------------------------------
; Device_ReadLBAlowRegisterToAL
; Returns LBA low register / Sector number register contents.
; Note that this returns valid value only after transfer command (read/write/verify)
; has stopped to an error. Do not call this otherwise.
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AL:		Byte read from the device register
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
;%ifdef MODULE_SERIAL	; IDE + Serial
;ALIGN JUMP_ALIGN
;Device_ReadLBAlowRegisterToAL:
;	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SERIAL_DEVICE
;%ifdef USE_386
;	jz		IdeCommand_ReadLBAlowRegisterToAL
;	jmp		SerialCommand_ReadLBAlowRegisterToAL
;%else
;	jnz		SHORT .ReadFromSerialPort
;	jmp		IdeCommand_ReadLBAlowRegisterToAL

;ALIGN JUMP_ALIGN
;.ReadFromSerialPort:
;	jmp		SerialCommand_ReadLBAlowRegisterToAL
;%endif

;%else					; IDE only
	Device_ReadLBAlowRegisterToAL		EQU		IdeCommand_ReadLBAlowRegisterToAL
;%endif
; TODO: For now we simply assume serial device do not produce verify errors


;--------------------------------------------------------------------
; Device_SelectDrive
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		INT 13h Error Code
;		CF:		Cleared if success, Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
%ifdef MODULE_SERIAL OR MODULE_SD
Device_SelectDrive:
%ifdef MODULE_SD
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SD_DEVICE
	jnz		SHORT ReturnSuccessForSerialPort
%endif
%ifdef MODULE_SERIAL
	test	BYTE [di+DPT.bFlagsHigh], FLGH_DPT_SERIAL_DEVICE
	jnz		SHORT ReturnSuccessForSerialPort
%endif
	jmp		IdeCommand_SelectDrive
%else
	Device_SelectDrive		EQU		IdeCommand_SelectDrive
%endif

%ifdef MODULE_SERIAL OR MODULE_SD
ALIGN JUMP_ALIGN
ReturnSuccessForSerialPort:
	xor		ax, ax
	ret
%endif
