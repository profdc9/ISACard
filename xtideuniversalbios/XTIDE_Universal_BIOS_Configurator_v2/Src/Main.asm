; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Program start and exit.

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

; Include .inc files

%define INCLUDE_MENU_DIALOGS
%define INCLUDE_SERIAL_LIBRARY

%include "AssemblyLibrary.inc"	; Assembly Library. Must be included first!
%include "RomVars.inc"			; XTIDE Universal BIOS variables
%include "ATA_ID.inc"			; Needed for Master/Slave Drive menu
%include "IdeRegisters.inc"		; Needed for port and device autodetection
%include "JRIDE_ISA.inc"		; For JR-IDE/ISA default segment
%include "ADP50L.inc"			; For ADP50L default segment
%include "XTCF.inc"				; For XT-CF modes

%include "Version.inc"
%include "MenuCfg.inc"
%include "MenuStructs.inc"
%include "Variables.inc"


; Section containing code
SECTION .text


; Program first instruction.
ORG	100h						; Code starts at offset 100h (DOS .COM)
Start:
	jmp		Main_Start

; Include library sources
%include "AssemblyLibrary.asm"

; Include sources for this program
%include "AutoConfigure.asm"
%include "BiosFile.asm"
%include "Buffers.asm"
%include "Dialogs.asm"
%include "EEPROM.asm"
%include "Flash.asm"
%include "IdeAutodetect.asm"
%include "MenuEvents.asm"
%include "Menuitem.asm"
%include "MenuitemPrint.asm"
%include "Menupage.asm"
%include "Strings.asm"

%include "BootMenuSettingsMenu.asm"
%include "ConfigurationMenu.asm"
%include "FlashMenu.asm"
%include "IdeControllerMenu.asm"
%include "MainMenu.asm"
%include "MasterSlaveMenu.asm"



;--------------------------------------------------------------------
; Program start
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Main_Start:
	mov		ah, GET_DOS_VERSION
	int		DOS_INTERRUPT_21h
	cmp		al, 2
	jae		SHORT .DosVersionIsOK
	mov		dx, g_s$NotMinimumDosVersion
	mov		ah, WRITE_STRING_TO_STANDARD_OUTPUT
	int		DOS_INTERRUPT_21h
	ret
.DosVersionIsOK:
	mov		[bDosVersionMajor], al					; bDosVersionMajor must be initialized by the application (library code depends on it)
	cmp		al, 5
	jb		SHORT .DoNotInstallInt2FhHandler
	; Since we are installing our Int2Fh handler we must also hook interrupt 23h to ensure a clean exit on ctrl-c/ctrl-break
	call	HookInterrupt23h
	call	HookInterrupt2Fh
.DoNotInstallInt2FhHandler:

	mov		ax, SCREEN_BACKGROUND_CHARACTER_AND_ATTRIBUTE
	call	InitializeScreenWithBackgroundCharAndAttrInAX

	call	Main_InitializeCfgVars
	call	MenuEvents_DisplayMenu
	mov		ax, DOS_BACKGROUND_CHARACTER_AND_ATTRIBUTE
	call	InitializeScreenWithBackgroundCharAndAttrInAX

	call	UnhookInterrupt2Fh

	; Exit to DOS
	mov 	ax, TERMINATE_WITH_RETURN_CODE<<8		; Errorlevel 0 in AL
	int		DOS_INTERRUPT_21h


;--------------------------------------------------------------------
; InitializeScreenWithBackgroundCharAndAttrInAX
;	Parameters:
;		AL:		Background character
;		AH:		Background attribute
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
InitializeScreenWithBackgroundCharAndAttrInAX:
	xchg	dx, ax
	CALL_DISPLAY_LIBRARY InitializeDisplayContext	; Reset cursor etc
	xchg	ax, dx
	JMP_DISPLAY_LIBRARY ClearScreenWithCharInALandAttrInAH


;--------------------------------------------------------------------
; Main_InitializeCfgVars
;	Parameters:
;		DS:		Segment to CFGVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Main_InitializeCfgVars:
	push	es

	call	Buffers_Clear
	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	jc		SHORT .InitializationCompleted
	mov		[CFGVARS.wEepromSegment], es
.InitializationCompleted:
	pop		es
	ret


; Section containing initialized data
SECTION .data

ALIGN WORD_ALIGN
g_cfgVars:
istruc CFGVARS
	at	CFGVARS.pMenupage,			dw	g_MenupageForMainMenu
	at	CFGVARS.wFlags,				dw	DEFAULT_CFGVARS_FLAGS
	at	CFGVARS.wEepromSegment,		dw	0
	at	CFGVARS.bEepromType,		db	DEFAULT_EEPROM_TYPE
	at	CFGVARS.bEepromPage,		db	DEFAULT_PAGE_SIZE
	at	CFGVARS.bSdpCommand,		db	DEFAULT_SDP_COMMAND
iend


; Section containing uninitialized data
SECTION .bss

bDosVersionMajor:	resb	1

