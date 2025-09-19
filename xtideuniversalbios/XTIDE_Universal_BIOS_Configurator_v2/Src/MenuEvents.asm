; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Menu event handling.

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
; MenuEvents_DisplayMenu
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except segments
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
MenuEvents_DisplayMenu:
	mov		bx, MenuEventHandler
	JMP_MENU_LIBRARY DisplayWithHandlerInBXandUserDataInDXAX


;--------------------------------------------------------------------
; MenuEventHandler
;	Common parameters for all events:
;		BX:			Menu event (anything from MENUEVENT struct)
;		SS:BP:		Menu library handle
;	Common return values for all events:
;		CF:			Set if event processed
;					Cleared if event not processed
;	Corrupts registers:
;		All
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
MenuEventHandler:
	cmp		bx, MENUEVENT.RefreshItemFromCX	; Above last supported item?
	ja		SHORT .EventNotHandled
	jmp		[cs:bx+.rgfnEventSpecificHandlers]
.EventNotHandled:
.IdleProcessing:
	clc
	ret

ALIGN WORD_ALIGN
.rgfnEventSpecificHandlers:
	dw		.InitializeMenuinitFromDSSI
	dw		.ExitMenu
	dw		.IdleProcessing
	dw		.ItemHighlightedFromCX
	dw		.ItemSelectedFromCX
	dw		.KeyStrokeInAX
	dw		.RefreshTitle
	dw		.RefreshInformation
	dw		.RefreshItemFromCX


; Parameters:
;	DS:SI:		Ptr to MENUINIT struct to initialize
; Returns:
;	DS:SI:		Ptr to initialized MENUINIT struct
ALIGN JUMP_ALIGN
.InitializeMenuinitFromDSSI:
	push	ds
	push	cs
	pop		ds
	mov		di, g_MenupageForMainMenu
	call	Menupage_SetActiveMenupageFromDSDI
	call	Menupage_GetVisibleMenuitemsToAXfromDSDI
	pop		ds

	mov		[si+MENUINIT.wItems], ax
	mov		WORD [si+MENUINIT.wTitleAndInfoLines], INFO_LINES_IN_MENU << 8 | TITLE_LINES_IN_MENU
	mov		BYTE [si+MENUINIT.bWidth], MENU_WIDTH
	CALL_DISPLAY_LIBRARY GetColumnsToALandRowsToAH
	mov		[si+MENUINIT.bHeight], ah
	call	MainMenu_EnterMenuOrModifyItemVisibility
	stc
	ret


; Parameters:
;	None
; Returns:
;	CF:		Set to exit menu
;			Clear to cancel exit
ALIGN JUMP_ALIGN
.ExitMenu:
	call	Menupage_GetActiveMenupageToDSDI
	mov		si, [di+MENUPAGE.fnBack]
	cmp		si, ExitToDosFromBackButton
	je		SHORT .QuitProgram
	call	si					; Back to previous menu
	clc
	ret

ALIGN JUMP_ALIGN
.QuitProgram:
	mov		bx, g_szDlgExitToDos
	call	Dialogs_DisplayYesNoResponseDialogWithTitleStringInBX
	jz		SHORT .ExitToDOS
	clc
	ret
.ExitToDOS:
	call	Buffers_SaveChangesIfFileLoaded
	CALL_MENU_LIBRARY Close
	stc
	ret


; Parameters:
;	CX:			Index of new highlighted item
;	DX:			Index of previously highlighted item or NO_ITEM_HIGHLIGHTED
ALIGN JUMP_ALIGN
.ItemHighlightedFromCX:
	CALL_MENU_LIBRARY ClearInformationArea
	CALL_MENU_LIBRARY RefreshInformation
	stc
	ret


; Parameters:
;	CX:			Index of selected item
ALIGN JUMP_ALIGN
.ItemSelectedFromCX:
	call	Menupage_GetActiveMenupageToDSDI
	call	Menupage_GetCXthVisibleMenuitemToDSSIfromDSDI
	call	[si+MENUITEM.fnActivate]
	stc
	ret


; Parameters:
;	AL:			ASCII character for the key
;	AH:			Keyboard library scan code for the key
ALIGN JUMP_ALIGN
.KeyStrokeInAX:
	cmp		ah, KEY_DISPLAY_ITEM_HELP
	jne		SHORT .EventNotHandled

;ALIGN JUMP_ALIGN
;.DisplayHelp:
	call	Menupage_GetActiveMenupageToDSDI
	CALL_MENU_LIBRARY GetHighlightedItemToAX
	xchg	cx, ax
	call	Menupage_GetCXthVisibleMenuitemToDSSIfromDSDI
	call	Menuitem_DisplayHelpMessageFromDSSI
	stc
	ret


; Parameters:
;	CX:			Index of item to refresh
;	Cursor has been positioned to the beginning of item line
ALIGN JUMP_ALIGN
.RefreshItemFromCX:
	inc		cx					; NO_ITEM_HIGHLIGHTED ?
	jz		SHORT .NothingToRefresh
	dec		cx
	call	Menupage_GetActiveMenupageToDSDI
	call	Menupage_GetCXthVisibleMenuitemToDSSIfromDSDI
	jnc		SHORT .NothingToRefresh
	call	MenuitemPrint_NameWithPossibleValueFromDSSI
.NothingToRefresh:
	stc
	ret


; Parameters:
;	CX:			Index of highlighted item
;	Cursor has been positioned to the beginning of first line
ALIGN JUMP_ALIGN
.RefreshInformation:
	inc		cx					; NO_ITEM_HIGHLIGHTED ?
	jz		SHORT .NothingToRefresh
	dec		cx
	call	Menupage_GetActiveMenupageToDSDI
	call	Menupage_GetCXthVisibleMenuitemToDSSIfromDSDI
	call	MenuitemPrint_PrintQuickInfoFromDSSI
	stc
	ret


; Parameters:
;	CX:			Index of highlighted item
;	Cursor has been positioned to the beginning of first line
ALIGN JUMP_ALIGN
.RefreshTitle:
	call	.PrintProgramName
	call	.PrintLoadStatus
	call	.PrintStatusOfUnsavedChanges
	stc
.ReturnSinceNothingToPrint:
	ret

ALIGN JUMP_ALIGN
.PrintProgramName:
	mov		si, g_szProgramTitle
	JMP_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI

ALIGN JUMP_ALIGN
.PrintLoadStatus:
	mov		al, [g_cfgVars+CFGVARS.wFlags]
	test	al, FLG_CFGVARS_FILELOADED
	jnz		SHORT .PrintNameOfLoadedFile
	test	al, FLG_CFGVARS_ROMLOADED
	mov		si, g_szEEPROM
	jnz		SHORT .PrintNameOfLoadedFileOrEeprom
	; Fall to .PrintNothingLoaded

.PrintNothingLoaded:
	mov		si, g_szBiosIsNotLoaded
	JMP_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI

ALIGN JUMP_ALIGN
.PrintNameOfLoadedFile:
	mov		si, g_cfgVars+CFGVARS.szOpenedFile
	; Fall to .PrintNameOfLoadedFileOrEeprom

ALIGN JUMP_ALIGN
.PrintNameOfLoadedFileOrEeprom:
	CALL_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI
	; Fall to .PrintTypeOfLoadedBios

.PrintTypeOfLoadedBios:
	mov		si, g_szSourceAndTypeSeparator
	CALL_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI
	call	Buffers_IsXtideUniversalBiosLoaded
	jne		SHORT .PrintUnidentifiedType

	call	Buffers_GetFileBufferToESDI
	mov		bx, es
	lea		si, [di+ROMVARS.szVersion]
	JMP_DISPLAY_LIBRARY PrintNullTerminatedStringFromBXSI

ALIGN JUMP_ALIGN
.PrintUnidentifiedType:
	mov		si, g_szUnidentified
	JMP_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI

ALIGN JUMP_ALIGN
.PrintStatusOfUnsavedChanges:
	test	BYTE [g_cfgVars+CFGVARS.wFlags], FLG_CFGVARS_UNSAVED
	jz		SHORT .ReturnSinceNothingToPrint
	mov		si, g_szUnsaved
	JMP_DISPLAY_LIBRARY PrintNullTerminatedStringFromCSSI
