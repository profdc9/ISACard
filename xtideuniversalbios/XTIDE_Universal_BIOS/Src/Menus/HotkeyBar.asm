; Project name	:	XTIDE Universal BIOS
; Description	:	Hotkey Bar related functions.

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
; Handler for INT 08h System Timer Tick.
; Reads key presses and draws hotkey bar.
;
; HotkeyBar_TimerTickHandler
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
HotkeyBar_TimerTickHandler:
	push	es
%ifndef USE_186		; LOAD_BDA_SEGMENT_TO will corrupt AX on 8088/8086
	push	ax
%endif
	LOAD_BDA_SEGMENT_TO es, ax

	; Call previous handler
	pushf
	call	FAR [es:BOOTVARS.hotkeyVars+HOTKEYVARS.fpPrevTimerHandler]

	; Update Hotkeybar (process key input and draw) every fourth tick
	test	BYTE [es:BDA.dwTimerTicks], 11b
	jnz		SHORT .ReturnFromHandler

	push	ds
%ifdef USE_186
	pusha
%else
	push	di
	push	si
	push	dx
	push	cx
%endif
	call	RamVars_GetSegmentToDS
	call	HotkeyBar_UpdateDuringDriveDetection
%ifdef USE_186
	popa
%else
	pop		cx
	pop		dx
	pop		si
	pop		di
%endif
	pop		ds

.ReturnFromHandler:
%ifndef USE_186
	pop		ax
%endif
	pop		es
	iret


;--------------------------------------------------------------------
; Scans key presses and draws any hotkey changes.
;
; HotkeyBar_UpdateDuringDriveDetection
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
HotkeyBar_UpdateDuringDriveDetection:
	call	ScanHotkeysFromKeyBufferAndStoreToBootvars

	; If ESC pressed, abort detection by forcing timeout
	cmp		al, ESC_SCANCODE
	jne		SHORT .ContinueDrawing
	mov		BYTE [RAMVARS.bTimeoutTicksLeft], 0
.ContinueDrawing:
	; Fall to HotkeyBar_DrawToTopOfScreen


;--------------------------------------------------------------------
; HotkeyBar_DrawToTopOfScreen
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
HotkeyBar_DrawToTopOfScreen:
	; Store current screen coordinates to stack
	; (to be restored when Hotkey Bar is rendered)
	CALL_DISPLAY_LIBRARY GetSoftwareCoordinatesToAX
	push	ax

	; Move cursor to top left corner (0, 0)
	mov		ax, es
	call	HotkeyBar_SetCursorCoordinatesFromAX
	; Fall to .PrintFloppyDriveHotkeys

;--------------------------------------------------------------------
; .PrintFloppyDriveHotkeys
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
.PrintFloppyDriveHotkeys:
	call	FloppyDrive_GetCountToAX
	xchg	cx, ax		; Any Floppy Drives?
	jcxz	.SkipFloppyDriveHotkeys

	mov		ax, (ANGLE_QUOTE_RIGHT << 8) | DEFAULT_FLOPPY_DRIVE_LETTER
	mov		cl, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bFddLetter]
	mov		di, g_szFDD

	; Clear CH if floppy drive is selected for boot
%if 0 ; Not needed until more flags added
	mov		ch, FLG_HOTKEY_HD_FIRST
	and		ch, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bFlags]
%else
	mov		ch, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bFlags]
%endif
	call	FormatDriveHotkeyString

.SkipFloppyDriveHotkeys:
	; Fall to .PrintHardDriveHotkeys

;--------------------------------------------------------------------
; .PrintHardDriveHotkeys
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
	call	BootVars_GetLetterForFirstHardDriveToAX
	mov		ah, ANGLE_QUOTE_RIGHT
	mov		cx, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.wHddLetterAndFlags]	; Letter to CL, flags to CH
	;and		ch, FLG_HOTKEY_HD_FIRST	; Not needed until more flags added
	xor		ch, FLG_HOTKEY_HD_FIRST		; Clear CH if HD is selected for boot, set otherwise
	mov		di, g_szHDD
	call	FormatDriveHotkeyString
	; Fall to .PrintBootMenuHotkey

;--------------------------------------------------------------------
; .PrintBootMenuHotkey
;	Parameters:
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
.PrintBootMenuHotkey:
%ifdef MODULE_BOOT_MENU
	mov		ax, BOOT_MENU_HOTKEY_SCANCODE | ('2' << 8)
	mov		di, g_szBootMenu
	call	FormatFunctionHotkeyString
%endif
	; Fall to .PrintComDetectHotkey

;--------------------------------------------------------------------
; .PrintComDetectHotkey
;	Parameters:
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
.PrintComDetectHotkey:
%ifdef MODULE_SERIAL
	mov		ax, COM_DETECT_HOTKEY_SCANCODE | ('6' << 8)
	mov		di, g_szHotComDetect
	call	FormatFunctionHotkeyString
%endif
	; Fall to .PrintRomBootHotkey

;--------------------------------------------------------------------
; .PrintRomBootHotkey
;	Parameters:
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
.PrintRomBootHotkey:
	mov		ax, ROM_BOOT_HOTKEY_SCANCODE | ('8' << 8)
	mov		di, g_szRomBoot
	call	FormatFunctionHotkeyString
	; Fall to .EndHotkeyBarRendering

;--------------------------------------------------------------------
; .EndHotkeyBarRendering
;	Parameters:
;		Stack:	Screen coordinates before drawing Hotkey Bar
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DI
;--------------------------------------------------------------------
.EndHotkeyBarRendering:
	; Clear the rest of the top row
	CALL_DISPLAY_LIBRARY GetColumnsToALandRowsToAH
	eMOVZX	cx, al
	CALL_DISPLAY_LIBRARY GetSoftwareCoordinatesToAX
	sub		cl, al
	mov		al, ' '
	CALL_DISPLAY_LIBRARY PrintRepeatedCharacterFromALwithCountInCX

	; Restore the saved coordinates from stack
	pop		ax
	; Fall to HotkeyBar_SetCursorCoordinatesFromAX


;--------------------------------------------------------------------
; HotkeyBar_SetCursorCoordinatesFromAX
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DI
;--------------------------------------------------------------------
HotkeyBar_SetCursorCoordinatesFromAX:
	JMP_DISPLAY_LIBRARY SetCursorCoordinatesFromAX


;--------------------------------------------------------------------
; FormatDriveHotkeyString
;	Parameters:
;		CH:		Zero if letter in CL is selected for boot
;		CL:		Drive letter hotkey from BOOTVARS
;		AL:		First character for drive key string
;		AH:		Second character for drive key string (ANGLE_QUOTE_RIGHT)
;		SI:		Offset to hotkey description string
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
FormatDriveHotkeyString:
	; Invalid scancodes are filtered on HotkeyBar_StoreHotkeyToBootvarsIfValidKeystrokeInAX
	; so here we have either drive letter or function key pressed. If latter, draw
	; drive letters as unselected
	cmp		BYTE [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bScancode], FIRST_FUNCTION_KEY_SCANCODE
	jae		SHORT GetNonSelectedHotkeyDescriptionAttributeToDX

	; Drive selected to boot from?
	test	ch, ch
	jnz		SHORT GetNonSelectedHotkeyDescriptionAttributeToDX
	jmp		SHORT GetSelectedHotkeyDescriptionAttributeToDX


;--------------------------------------------------------------------
; FormatFunctionHotkeyString
;	Parameters:
;		AL:		Scancode of function key, to know which if any to show as selected
;				Later replaced with an 'F' for the call to the output routine
;		AH:		Second character for drive key string
;		SI:		Offset to hotkey description string
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI, DI
;--------------------------------------------------------------------
FormatFunctionHotkeyString:
	xor		cx, cx		; Null character, eaten in output routines

	cmp		[es:BOOTVARS.hotkeyVars+HOTKEYVARS.bScancode], al
	mov		al, 'F'		; Replace scancode with character for output

%ifdef MODULE_BOOT_MENU

GetSelectedHotkeyDescriptionAttributeToDX:
	mov		si, ATTRIBUTE_CHARS.cHighlightedItem	; Selected hotkey
	je		SHORT GetDescriptionAttributeToDX		; From compare with bScancode above and from FormatDriveHotkeyString

GetNonSelectedHotkeyDescriptionAttributeToDX:
	mov		si, ATTRIBUTE_CHARS.cItem				; Unselected hotkey

	; Display Library should not be called like this
GetDescriptionAttributeToDX:
	xchg	dx, ax
	call	MenuAttribute_GetToAXfromTypeInSI
	xchg	dx, ax					; DX = Description attribute
	;;  fall through to PushHotkeyParamsAndFormat


%else ; if no MODULE_BOOT_MENU - No boot menu so use simpler attributes

GetSelectedHotkeyDescriptionAttributeToDX:
	mov		dx, (COLOR_ATTRIBUTE(COLOR_YELLOW, COLOR_CYAN) << 8) | MONO_REVERSE_BLINK
	je		SHORT SelectAttributeFromDHorDLbasedOnVideoMode		; From compare with bScancode above and from FormatDriveHotkeyString

GetNonSelectedHotkeyDescriptionAttributeToDX:
	mov		dx, (COLOR_ATTRIBUTE(COLOR_BLACK, COLOR_CYAN) << 8) | MONO_REVERSE

SelectAttributeFromDHorDLbasedOnVideoMode:
	mov		ch, [es:BDA.bVidMode]		; We only need to preserve CL
	shr		ch, 1
	jnc		SHORT .AttributeLoadedToDL	; Black & White modes
	shr		ch, 1
	jnz		SHORT .AttributeLoadedToDL	; MDA
	mov		dl, dh
.AttributeLoadedToDL:
	;;  fall through to PushHotkeyParamsAndFormat

%endif ; MODULE_BOOT_MENU


;--------------------------------------------------------------------
; PushHotkeyParamsAndFormat
;	Parameters:
;		AL:		First character
;		AH:		Second character
;		DX:		Description Attribute
;		CX:		Description string parameter
;		CS:DI:	Description string
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, SI, DI
;--------------------------------------------------------------------
PushHotkeyParamsAndFormat:
	push	bp
	mov		bp, sp

	mov		si, MONO_BRIGHT

	push	si				; Key attribute
	push	ax				; First Character
	mov		al, ah
	push	ax				; Second Character

	push	dx				; Description attribute
	push	di				; Description string
	push	cx				; Description string parameter

	push	si				; Key attribute for last space

	mov		si, g_szHotkey
	jmp		DetectPrint_FormatCSSIfromParamsInSSBP


;--------------------------------------------------------------------
; HotkeyBar_StoreDefaultDriveLettersToHotkeyVars
;	Parameters:
;		ES:		BDA Segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
HotkeyBar_StoreDefaultDriveLettersToHotkeyVars:
	call	BootVars_GetLetterForFirstHardDriveToAX
	mov		ah, DEFAULT_FLOPPY_DRIVE_LETTER
	xchg	al, ah
	mov		[es:BOOTVARS.hotkeyVars+HOTKEYVARS.wFddAndHddLetters], ax
	ret


;--------------------------------------------------------------------
; HotkeyBar_InitializeVariables
;	Parameters:
;		DS:		RAMVARS Segment
;		ES:		BDA Segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, DI
;--------------------------------------------------------------------
HotkeyBar_InitializeVariables:
	push	ds
	push	es
	pop		ds

	; Store System Timer Tick handler and install our hotkeybar handler
	mov		ax, [BIOS_SYSTEM_TIMER_TICK_INTERRUPT_08h*4]
	mov		[BOOTVARS.hotkeyVars+HOTKEYVARS.fpPrevTimerHandler], ax
	mov		ax, [BIOS_SYSTEM_TIMER_TICK_INTERRUPT_08h*4+2]
	mov		[BOOTVARS.hotkeyVars+HOTKEYVARS.fpPrevTimerHandler+2], ax
	mov		al, BIOS_SYSTEM_TIMER_TICK_INTERRUPT_08h
	mov		si, HotkeyBar_TimerTickHandler
	call	Interrupts_InstallHandlerToVectorInALFromCSSI

	; Store time when hotkeybar is displayed
	; (it will be displayed after initialization is complete)
	mov		ax, [BDA.dwTimerTicks]
	mov		[BOOTVARS.hotkeyVars+HOTKEYVARS.wTimeWhenDisplayed], ax

	pop		ds

	; Initialize HOTKEYVARS by storing default drives to boot from
	call	HotkeyBar_StoreDefaultDriveLettersToHotkeyVars
	mov		dl, [cs:ROMVARS.bBootDrv]
	; Fall to HotkeyBar_StoreHotkeyToBootvarsForDriveNumberInDL


;--------------------------------------------------------------------
; HotkeyBar_StoreHotkeyToBootvarsForDriveNumberInDL
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;		DL:		Drive Number
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DL, DI
;--------------------------------------------------------------------
HotkeyBar_StoreHotkeyToBootvarsForDriveNumberInDL:
	call	DriveXlate_ConvertDriveNumberFromDLtoDriveLetter
	; Fall to StoreHotkeyToBootvarsForDriveLetterInDL


;--------------------------------------------------------------------
; StoreHotkeyToBootvarsForDriveLetterInDL
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;		DL:		Drive Letter ('A'...)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DI
;--------------------------------------------------------------------
StoreHotkeyToBootvarsForDriveLetterInDL:
	eMOVZX	ax, dl
	or		al, 32	; Upper case drive letter to lower case keystroke
	jmp		SHORT HotkeyBar_StoreHotkeyToBootvarsIfValidKeystrokeInAX


;--------------------------------------------------------------------
; ScanHotkeysFromKeyBufferAndStoreToBootvars
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		AL:		Last scancode value
;	Corrupts registers:
;		AH, CX
;--------------------------------------------------------------------
ScanHotkeysFromKeyBufferAndStoreToBootvars:
	call	Keyboard_GetKeystrokeToAX
	jz		SHORT NoHotkeyToProcess

	; Prepare to read another key from buffer
	ePUSH_T	cx, ScanHotkeysFromKeyBufferAndStoreToBootvars
	; Fall to HotkeyBar_StoreHotkeyToBootvarsIfValidKeystrokeInAX


;--------------------------------------------------------------------
; HotkeyBar_StoreHotkeyToBootvarsIfValidKeystrokeInAX
;	Parameters:
;		AL:		Hotkey ASCII code
;		AH:		Hotkey Scancode
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		AL:		Last scancode seen
;		CF:		Set if valid hotkey in AL
;				Clear if scancode in AL is not for any hotkey
;	Corrupts registers:
;		AH, CX, DI
;--------------------------------------------------------------------
HotkeyBar_StoreHotkeyToBootvarsIfValidKeystrokeInAX:
	mov		di, BOOTVARS.hotkeyVars+HOTKEYVARS.bScancode

	; All scancodes are saved, even if it wasn't a drive letter,
	; which also covers our function key case.  Invalid function keys
	; will not do anything (won't be printed, won't be accepted as input)
	mov		[es:di], ah

	; Drive letter hotkeys remaining, allow 'a' to 'z'
	call	Char_IsLowerCaseLetterInAL
	jnc		SHORT .KeystrokeIsNotValidDriveLetter
	and		al, ~32					; We want to print upper case letters

	; Clear HD First flag to assume Floppy Drive hotkey
	dec		di
	and		BYTE [es:di], ~FLG_HOTKEY_HD_FIRST

	; Determine if Floppy or Hard Drive hotkey
	xchg	cx, ax
	call	BootVars_GetLetterForFirstHardDriveToAX
	cmp		cl, al
	jb		SHORT .StoreDriveLetter	; Store Floppy Drive letter

	; Store Hard Drive letter
	or		BYTE [es:di], FLG_HOTKEY_HD_FIRST

.StoreDriveLetter:
	sbb		di, BYTE 1				; Sub CF if Floppy Drive
	xchg	ax, cx
	stosb
	stc								; Valid hotkey scancode returned in AL

.KeystrokeIsNotValidDriveLetter:
NoHotkeyToProcess:
	mov		al, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bScancode]
	ret


;--------------------------------------------------------------------
; HotkeyBar_GetBootDriveNumbersToDX
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		DX:		Drives selected as boot device, DL is primary
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
HotkeyBar_GetBootDriveNumbersToDX:
	mov		dx, [es:BOOTVARS.hotkeyVars+HOTKEYVARS.wFddAndHddLetters]

	; HotkeyBar_GetBootDriveNumbersToDX is called when all drives are detected and
	; drive letters are known.
	; Replace unavailable hard drive letter with first hard drive.
	; If we have boot menu, it will be displayed instead.
%ifndef MODULE_BOOT_MENU
	call	BootVars_GetLetterForFirstHardDriveToAX
	mov		ah, al
	add		al, [es:BDA.bHDCount]	; AL now contains first unavailable HD letter
	cmp		dh, al					; Unavailable drive?
	jb		SHORT .ValidHardDriveLetterInDH
	mov		dh, ah					; Replace unavailable drive with first drive
.ValidHardDriveLetterInDH:
%endif

	test	BYTE [es:BOOTVARS.hotkeyVars+HOTKEYVARS.bFlags], FLG_HOTKEY_HD_FIRST
	jnz		SHORT .noflip
	xchg	dl, dh
.noflip:
	call	DriveXlate_ConvertDriveLetterInDLtoDriveNumber
	xchg	dl, dh
	; Fall to HotkeyBar_FallThroughTo_DriveXlate_ConvertDriveLetterInDLtoDriveNumber

HotkeyBar_FallThroughTo_DriveXlate_ConvertDriveLetterInDLtoDriveNumber:

