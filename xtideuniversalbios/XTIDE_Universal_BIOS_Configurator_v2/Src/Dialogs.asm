; Project name	:	XTIDE Univeral BIOS Configurator v2
; Description	:	Functions for displaying dialogs.

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
; Dialogs_DisplayNotificationFromCSDX
; Dialogs_DisplayErrorFromCSDX
;	Parameters:
;		CS:DX:	Ptr to notification/error string to display
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Dialogs_DisplayNotificationFromCSDX:
	push	di
	mov		di, g_szNotificationDialog
	jmp		SHORT DisplayMessageDialogWithMessageInCSDXandDialogInputInDSSI

ALIGN JUMP_ALIGN
Dialogs_DisplayErrorFromCSDX:
	push	di
	mov		di, g_szErrorDialog
	SKIP1B	al
	; Fall to DisplayMessageDialogWithMessageInCSDXandDialogInputInDSSI

;--------------------------------------------------------------------
; Dialogs_DisplayHelpFromCSDXwithTitleInCSDI
;	Parameters:
;		CS:DX:	Ptr to help string to display
;		CS:DI:	Ptr to title string for help dialog
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
Dialogs_DisplayHelpFromCSDXwithTitleInCSDI:
	push	di

DisplayMessageDialogWithMessageInCSDXandDialogInputInDSSI:
	push	ds
	push	si
	push	cx

	mov		cl, DIALOG_INPUT_size
	call	Memory_ReserveCLbytesFromStackToDSSI
	call	InitializeDialogInputFromDSSI
	mov		[si+DIALOG_INPUT.fszTitle], di
	mov		[si+DIALOG_INPUT.fszItems], dx
	CALL_MENU_LIBRARY DisplayMessageWithInputInDSSI

	add		sp, BYTE DIALOG_INPUT_size
	pop		cx
	pop		si
	pop		ds

	pop		di
	ret


;--------------------------------------------------------------------
; Dialogs_DisplayFileDialogWithDialogIoInDSSI
;	Parameters:
;		DS:SI:	Ptr to FILE_DIALOG_IO
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Dialogs_DisplayFileDialogWithDialogIoInDSSI:
	push	es

	call	Buffers_GetFileDialogItemBufferToESDI
	mov		WORD [si+FILE_DIALOG_IO.fszTitle], g_szDlgFileTitle
	mov		[si+FILE_DIALOG_IO.fszTitle+2], cs
	mov		[si+FILE_DIALOG_IO.fszItemBuffer], di
	mov		[si+FILE_DIALOG_IO.fszItemBuffer+2], es
	mov		BYTE [si+FILE_DIALOG_IO.bDialogFlags], FLG_FILEDIALOG_DRIVES
	mov		BYTE [si+FILE_DIALOG_IO.bFileAttributes], FLG_FILEATTR_DIRECTORY | FLG_FILEATTR_ARCHIVE
	mov		WORD [si+FILE_DIALOG_IO.fpFileFilterString], g_szDlgFileFilter
	mov		[si+FILE_DIALOG_IO.fpFileFilterString+2], cs
	CALL_MENU_LIBRARY GetFileNameWithIoInDSSI

	pop		es
	ret


;--------------------------------------------------------------------
; Dialogs_DisplayYesNoResponseDialogWithTitleStringInBX
;	Parameters:
;		BX:		Offset to dialog title string
;		SS:BP:	Menu handle
;	Returns:
;		ZF:		Set if user wants to do the action
;				Cleared if user wants to cancel
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Dialogs_DisplayYesNoResponseDialogWithTitleStringInBX:
	push	ds

	mov		cl, DIALOG_INPUT_size
	call	Memory_ReserveCLbytesFromStackToDSSI
	call	InitializeDialogInputFromDSSI
	mov		[si+DIALOG_INPUT.fszTitle], bx
	mov		WORD [si+DIALOG_INPUT.fszItems], g_szMultichoiceBooleanFlag
	CALL_MENU_LIBRARY GetSelectionToAXwithInputInDSSI
	add		sp, BYTE DIALOG_INPUT_size
	dec		ax				; -1 = NO, 0 = YES

	pop		ds
	ret


;--------------------------------------------------------------------
; Dialogs_DisplayProgressDialogForFlashingWithDialogIoInDSSIandFlashvarsInDSBX
;	Parameters:
;		DS:BX:	Ptr to FLASHVARS
;		DS:SI:	Ptr to PROGRESS_DIALOG_IO
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Dialogs_DisplayProgressDialogForFlashingWithDialogIoInDSSIandFlashvarsInDSBX:
	; Initialize progress dialog I/O in DS:SI with flashvars in DS:BX
	call	InitializeDialogInputFromDSSI
	mov		WORD [si+DIALOG_INPUT.fszTitle], g_szFlashTitle

	xor		ax, ax
	mov		[si+PROGRESS_DIALOG_IO.wCurrentProgressValue], ax
	mov		dx, [bx+FLASHVARS.wPagesToFlash]
	mov		[si+PROGRESS_DIALOG_IO.wMaxProgressValue], dx
	mov		[si+PROGRESS_DIALOG_IO.wMinProgressValue], ax
	mov		WORD [si+PROGRESS_DIALOG_IO.fnTaskWithParamInDSSI], Flash_EepromWithFlashvarsInDSSI
	mov		[si+PROGRESS_DIALOG_IO.fnTaskWithParamInDSSI+2], cs
	; Init done

	mov		dx, ds
	mov		ax, bx
	JMP_MENU_LIBRARY StartProgressTaskWithIoInDSSIandParamInDXAX


;--------------------------------------------------------------------
; InitializeDialogInputFromDSSI
;	Parameters:
;		DS:SI:	Ptr to DIALOG_INPUT
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
InitializeDialogInputFromDSSI:
	mov		[si+DIALOG_INPUT.fszTitle+2], cs
	mov		[si+DIALOG_INPUT.fszItems+2], cs
	mov		WORD [si+DIALOG_INPUT.fszInfo], g_szGenericDialogInfo
	mov		[si+DIALOG_INPUT.fszInfo+2], cs
	ret
