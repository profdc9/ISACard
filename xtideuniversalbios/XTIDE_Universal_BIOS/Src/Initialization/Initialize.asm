; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for initializing the BIOS.

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
; Initializes the BIOS.
; This function is called from main BIOS ROM search routine.
;
; Initialize_FromMainBiosRomSearch
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Initialize_FromMainBiosRomSearch:		; unused entrypoint ok
	pushf								; To store IF
	sti									; Enable interrupts for keystrokes
	push	ds
	push	ax							; We use AX to install very late init handler
	LOAD_BDA_SEGMENT_TO	ds, ax

	test	BYTE [BDA.bKBFlgs1], (1<<2)	; Clears ZF if CTRL is held down
	jnz		SHORT .SkipRomInitialization

	; Install INT 19h handler (boot loader) where drives are detected
	mov		WORD [BIOS_BOOT_LOADER_INTERRUPT_19h*4], Int19h_BootLoaderHandler
	mov		[BIOS_BOOT_LOADER_INTERRUPT_19h*4+2], cs

%ifdef MODULE_VERY_LATE_INIT
	push	es
	; Install special INT 13h handler that initializes XTIDE Universal BIOS
	; when our INT 19h is not called
	les		ax, [BIOS_DISK_INTERRUPT_13h*4]	; Load system INT 13h handler
	mov		WORD [BIOS_DISK_INTERRUPT_13h*4], Int13hBiosInit_Handler
	mov		[BIOS_DISK_INTERRUPT_13h*4+2], cs
	mov		[TEMPORARY_VECTOR_FOR_SYSTEM_INT13h*4], ax
	mov		[TEMPORARY_VECTOR_FOR_SYSTEM_INT13h*4+2], es
	pop		es
%endif

.SkipRomInitialization:
	pop		ax
	pop		ds
	popf
	retf


;--------------------------------------------------------------------
; Initializes the BIOS variables and detects IDE drives.
;
; Initialize_AndDetectDrives
;	Parameters:
;		ES:		BDA Segment
;	Returns:
;		DS:		RAMVARS segment
;	Corrupts registers:
;		All, except ES
;--------------------------------------------------------------------
Initialize_AndDetectDrives:
	call	DetectPrint_InitializeDisplayContext
	call	DetectPrint_RomFoundAtSegment
	call	RamVars_Initialize
	call	BootVars_Initialize
%ifdef MODULE_HOTKEYS
	; This is a simple fix for the so called "No Fixed Disk Present in FDISK"-bug introduced in r551. MODULE_HOTKEYS includes the internal
	; module MODULE_DRIVEXLATE which is needed if interrupt handlers are installed before drive detection. The reason for this is that
	; Interrupts_InitializeInterruptVectors won't install our interrupt 13h handler if no drives were detected (unless MODULE_DRIVEXLATE is included).
	; Since the drive detection hasn't been done yet, the handler will not be installed, causing the above mentioned bug.
	call	Interrupts_InitializeInterruptVectors	; HotkeyBar requires INT 40h so install handlers before drive detection
	call	DetectDrives_FromAllIDEControllers
%else
	; Without MODULE_HOTKEYS (or actually MODULE_DRIVEXLATE) we *must* use this call order.
	call	DetectDrives_FromAllIDEControllers
	call	Interrupts_InitializeInterruptVectors
%endif
	mov		[RAMVARS.wDrvDetectSignature], es		; No longer in drive detection mode (set normal timeouts)
	; Fall to .StoreDptPointersToIntVectors

;--------------------------------------------------------------------
; .StoreDptPointersToIntVectors
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA and interrupt vector segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
%ifdef MODULE_COMPATIBLE_TABLES
.StoreDptPointersToIntVectors:
%ifndef USE_AT
	test	BYTE [cs:ROMVARS.wFlags], FLG_ROMVARS_FULLMODE
	jz		SHORT .SkipToReturn				; Only Full operating mode has extra RAM to spare
%endif

	mov		bx, HD0_DPT_POINTER_41h * 4
	mov		dl, 80h
.FindForNextDrive:
	call	FindDPT_ForDriveNumberInDL		; DPT to DS:DI
	jc		SHORT .NextDrive				; Store nothing if not our drive

	push	dx
	call	CompatibleDPT_CreateToAXSIforDriveDL
	pop		dx

	mov		[es:bx], si
	mov		[es:bx+2], ax

.NextDrive:
	inc		dx
	add		bx, (HD1_DPT_POINTER_46h - HD0_DPT_POINTER_41h) * 4
	cmp		dl, 82h
	jb		SHORT .FindForNextDrive

.SkipToReturn:
%endif ; MODULE_COMPATIBLE_TABLES
	ret
