; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	"Boot settings" menu structs and functions.

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

; Section containing initialized data
SECTION .data

ALIGN WORD_ALIGN
g_MenupageForBootMenuSettingsMenu:
istruc MENUPAGE
	at	MENUPAGE.fnEnter,			dw	BootMenuSettingsMenu_EnterMenuOrModifyItemVisibility
	at	MENUPAGE.fnBack,			dw	ConfigurationMenu_EnterMenuOrModifyItemVisibility
	at	MENUPAGE.wMenuitems,		dw	8
iend

g_MenuitemBootMnuStngsBackToConfigurationMenu:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	ConfigurationMenu_EnterMenuOrModifyItemVisibility
	at	MENUITEM.szName,			dw	g_szItemBackToCfgMenu
	at	MENUITEM.szQuickInfo,		dw	g_szNfoIdeBackToCfgMenu
	at	MENUITEM.szHelp,			dw	g_szNfoIdeBackToCfgMenu
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGEBACK
iend

g_MenuitemBootMnuStngsDisplayMode:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromUnshiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemBootDispMode
	at	MENUITEM.szQuickInfo,		dw	g_szNfoDispMode
	at	MENUITEM.szHelp,			dw	g_szNfoDispMode
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wDisplayMode
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgBootDispMode
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBootDispMode
	at	MENUITEM.itemValue + ITEM_VALUE.rgwChoiceToValueLookup,		dw	g_rgwChoiceToValueLookupForDisplayModes
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForDisplayModes
iend

g_MenuitemBootMnuStngsColorTheme:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromUnshiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemColorTheme
	at	MENUITEM.szQuickInfo,		dw	g_szNfoColorTheme
	at	MENUITEM.szHelp,			dw	g_szHelpColorTheme
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_MODIFY_MENU
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.pColorTheme		; Only ever read - never modified
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgColorTheme
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceColorTheme
	at	MENUITEM.itemValue + ITEM_VALUE.rgwChoiceToValueLookup,		dw	NULL
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForColorTheme
	at	MENUITEM.itemValue + ITEM_VALUE.fnValueReader,				dw	ReadColorTheme
	at	MENUITEM.itemValue + ITEM_VALUE.fnValueWriter,				dw	WriteColorTheme
iend

g_MenuitemBootMnuStngsFloppyDrives:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromUnshiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemBootFloppyDrvs
	at	MENUITEM.szQuickInfo,		dw	g_szNfoBootFloppyDrvs
	at	MENUITEM.szHelp,			dw	g_szHelpBootFloppyDrvs
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_BYTEVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.bMinFddCnt
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgBootFloppyDrvs
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBootFloppyDrvs
	at	MENUITEM.itemValue + ITEM_VALUE.rgwChoiceToValueLookup,		dw	NULL
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForFloppyDrives
iend

g_MenuitemBootMenuSDScanDetect:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromShiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemSDDetect
	at	MENUITEM.szQuickInfo,		dw	g_szNfoSDDetect
	at	MENUITEM.szHelp,			dw	g_szHelpSDDetect
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_FLAGVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wFlags
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgSDDetect
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBooleanFlag
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForFlagBooleans
	at	MENUITEM.itemValue + ITEM_VALUE.wValueBitmask,				dw	FLG_ROMVARS_SD_SCANDETECT
iend

g_MenuitemBootMenuSerialScanDetect:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromShiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemSerialDetect
	at	MENUITEM.szQuickInfo,		dw	g_szNfoSerialDetect
	at	MENUITEM.szHelp,			dw	g_szHelpSerialDetect
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_FLAGVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wFlags
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgSerialDetect
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBooleanFlag
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForFlagBooleans
	at	MENUITEM.itemValue + ITEM_VALUE.wValueBitmask,				dw	FLG_ROMVARS_SERIAL_SCANDETECT
iend

g_MenuitemBootMnuStngsDefaultBootDrive:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateHexInputForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteHexValueStringToBufferInESDIfromItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemBootDrive
	at	MENUITEM.szQuickInfo,		dw	g_szNfoBootDrive
	at	MENUITEM.szHelp,			dw	g_szHelpBootDrive
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_BYTEVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_HEX
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.bBootDrv
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgBootDrive
	at	MENUITEM.itemValue + ITEM_VALUE.wMinValue,					dw	0
	at	MENUITEM.itemValue + ITEM_VALUE.wMaxValue,					dw	0FFh
iend

g_MenuitemBootMnuStngsSelectionTimeout:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateUnsignedInputForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteUnsignedValueStringToBufferInESDIfromItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemBootTimeout
	at	MENUITEM.szQuickInfo,		dw	g_szNfoBootTimeout
	at	MENUITEM.szHelp,			dw	g_szHelpBootTimeout
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_UNSIGNED
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wBootTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgBootTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.wMinValue,					dw	2
	at	MENUITEM.itemValue + ITEM_VALUE.wMaxValue,					dw	1092
iend

g_MenuitemBootMnuStngsClearBdaDriveCount:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromShiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemClearBdaDriveCount
	at	MENUITEM.szQuickInfo,		dw	g_szNfoClearBdaDriveCount
	at	MENUITEM.szHelp,			dw	g_szHelpClearBdaDriveCount
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_FLAGVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wFlags
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgClearBdaDriveCount
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBooleanFlag
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForFlagBooleans
	at	MENUITEM.itemValue + ITEM_VALUE.wValueBitmask,				dw	FLG_ROMVARS_CLEAR_BDA_HD_COUNT
iend


g_rgwChoiceToValueLookupForDisplayModes:
	dw	DEFAULT_TEXT_MODE
	dw	CGA_TEXT_MODE_BW40
	dw	CGA_TEXT_MODE_CO40
	dw	CGA_TEXT_MODE_BW80
	dw	CGA_TEXT_MODE_CO80
	dw	MDA_TEXT_MODE
g_rgszValueToStringLookupForDisplayModes:
	dw	g_szValueBootDispModeBW40
	dw	g_szValueBootDispModeCO40
	dw	g_szValueBootDispModeBW80
	dw	g_szValueBootDispModeCO80
	dw	g_szValueBootDispModeDefault
	dw	NULL
	dw	NULL
	dw	g_szValueBootDispModeMono

g_rgszValueToStringLookupForFloppyDrives:
	dw	g_szValueBootFloppyDrvsAuto
	dw	g_szValueBootFloppyDrvs1
	dw	g_szValueBootFloppyDrvs2
	dw	g_szValueBootFloppyDrvs3
	dw	g_szValueBootFloppyDrvs4

g_rgszValueToStringLookupForColorTheme:
	dw	g_szValueColorTheme0
	dw	g_szValueColorTheme1
	dw	g_szValueColorTheme2
	dw	g_szValueColorTheme3
	dw	g_szValueColorTheme4
	dw	g_szValueColorTheme5

ColorThemeTable:
	; Classic (default)
	db	COLOR_ATTRIBUTE(COLOR_YELLOW, COLOR_BLUE)							; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLUE)						; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLUE)							; .cItem
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_CYAN)						; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_RED, COLOR_BLUE) | FLG_COLOR_BLINK			; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_GREEN, COLOR_BLUE)							; .cNormalTimeout
	; Argon Blue
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_BLUE, COLOR_BLACK)						; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLACK)					; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLACK)							; .cItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_BLUE, COLOR_BLACK)						; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_BLUE, COLOR_BLACK) | FLG_COLOR_BLINK	; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_BLUE, COLOR_BLACK)						; .cNormalTimeout
	; Neon Red
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK)						; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLACK)					; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLACK)							; .cItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK)						; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK) | FLG_COLOR_BLINK		; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK)						; .cNormalTimeout
	; Phosphor Green
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK)						; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLACK)					; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLACK)							; .cItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK)						; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK) | FLG_COLOR_BLINK	; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK)						; .cNormalTimeout
	; Moon Surface
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLACK)					; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLACK)							; .cItem
	db	COLOR_ATTRIBUTE(COLOR_BROWN, COLOR_BLACK)							; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_BRIGHT_WHITE, COLOR_BLACK) | FLG_COLOR_BLINK	; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_WHITE, COLOR_BLACK)							; .cNormalTimeout
	; Toxic Waste
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK)						; .cBordersAndBackground
	db	COLOR_ATTRIBUTE(COLOR_GRAY, COLOR_BLACK)							; .cShadow
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_GREEN, COLOR_BLACK)						; .cTitle
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_CYAN, COLOR_BLACK)						; .cItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_CYAN, COLOR_BLUE)						; .cHighlightedItem
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK) | FLG_COLOR_BLINK		; .cHurryTimeout
	db	COLOR_ATTRIBUTE(COLOR_LIGHT_RED, COLOR_BLACK)						; .cNormalTimeout
EndOfColorThemeTable:
CountOfThemes	equ		(EndOfColorThemeTable-ColorThemeTable) / ATTRIBUTE_CHARS_size


; Section containing code
SECTION .text

;--------------------------------------------------------------------
; BootMenuSettingsMenu_EnterMenuOrModifyItemVisibility
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except BP
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenuSettingsMenu_EnterMenuOrModifyItemVisibility:
	push	cs
	pop		ds
	call	Buffers_GetRomvarsFlagsToAX
	call	.EnableOrDisableScanForSerialDrives
	call	.EnableOrDisableScanForSDDrives
	call	.EnableOrDisableDefaultBootDrive
	call	.EnableOrDisableColorThemeSelection
	call	.EnableOrDisableBootMenuSelectionTimeout
	mov		si, g_MenupageForBootMenuSettingsMenu
	jmp		Menupage_ChangeToNewMenupageInDSSI


;--------------------------------------------------------------------
; .EnableOrDisableScanForSDDrives
;	Parameters:
;		AX:		ROMVARS.wFlags
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableScanForSDDrives:
	mov		bx, g_MenuitemBootMenuSDScanDetect
	test	ax, FLG_ROMVARS_MODULE_SD
	jmp		SHORT .DisableMenuitemFromCSBXifZFset


;--------------------------------------------------------------------
; .EnableOrDisableScanForSerialDrives
;	Parameters:
;		AX:		ROMVARS.wFlags
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableScanForSerialDrives:
	mov		bx, g_MenuitemBootMenuSerialScanDetect
	test	ax, FLG_ROMVARS_MODULE_SERIAL
	jmp		SHORT .DisableMenuitemFromCSBXifZFset


;--------------------------------------------------------------------
; .EnableOrDisableDefaultBootDrive
;	Parameters:
;		AX:		ROMVARS.wFlags
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableDefaultBootDrive:
	mov		bx, g_MenuitemBootMnuStngsDefaultBootDrive
	test	ax, FLG_ROMVARS_MODULE_HOTKEYS | FLG_ROMVARS_MODULE_BOOT_MENU
	jmp		SHORT .DisableMenuitemFromCSBXifZFset


;--------------------------------------------------------------------
; .EnableOrDisableColorThemeSelection
;	Parameters:
;		AX:		ROMVARS.wFlags
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableColorThemeSelection:
	mov		bx, g_MenuitemBootMnuStngsColorTheme
	test	ax, FLG_ROMVARS_MODULE_BOOT_MENU
	jmp		SHORT .DisableMenuitemFromCSBXifZFset


;--------------------------------------------------------------------
; .EnableOrDisableBootMenuSelectionTimeout
;	Parameters:
;		AX:		ROMVARS.wFlags
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableBootMenuSelectionTimeout:
	mov		bx, g_MenuitemBootMnuStngsSelectionTimeout
	test	ax, FLG_ROMVARS_MODULE_BOOT_MENU
.DisableMenuitemFromCSBXifZFset:
	jz		SHORT .DisableMenuitemFromCSBX
	; Fall to .EnableMenuitemFromCSBX


;--------------------------------------------------------------------
; .EnableMenuitemFromCSBX
; .DisableMenuitemFromCSBX
;	Parameters:
;		CS:BX:	Ptr to MENUITEM
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableMenuitemFromCSBX:
	jmp		EnableMenuitemFromCSBX

ALIGN JUMP_ALIGN
.DisableMenuitemFromCSBX:
	jmp		DisableMenuitemFromCSBX


;--------------------------------------------------------------------
; ReadColorTheme
;	Parameters:
;		AX:		Value read from the ROMVARS location
;		ES:DI:	ROMVARS location where the value was just read from
;		DS:SI:	MENUITEM pointer
;	Returns:
;		AX:		Value that the MENUITEM system will interact with and display
;	Corrupts registers:
;		BX, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ReadColorTheme:
	push	ds

	push	es							; ES -> DS
	pop		ds
	push	cs							; CS -> ES
	pop		es

	mov		di, EndOfColorThemeTable-1	; ES:DI now points to the end of the last theme in the table of available themes in XTIDECFG
	xor		bx, bx

	push	si
	push	cx
	mov		cx, CountOfThemes
	std
.NextTheme:
	push	cx
	mov		cl, ATTRIBUTE_CHARS_size
	mov		si, ax						; [ROMVARS.pColorTheme] to SI
	dec		si
	add		si, cx						; DS:SI now points to the end of the ColorTheme in the loaded BIOS
	sub		di, bx						; Update the pointer to the end of the next theme in the table

	; We verify that the theme in the loaded BIOS exists in our table. If it doesn't exist then that most likely means
	; the loaded BIOS doesn't contain MODULE_BOOT_MENU and the theme actually isn't a theme - it's code. Either way,
	; we don't trust it enough to copy it over as corrupt/invalid settings could render the UI in XTIDECFG unreadable.
	repe	cmpsb
	mov		bx, cx
	pop		cx
	loopne	.NextTheme
	cld
	mov		ax, cx
	jne		SHORT .SkipCopy

	; Copy the color theme fron the loaded BIOS overwriting XTIDECFG's own theme
	inc		si
	mov		di, ColorTheme				; ES:DI now points to ColorTheme in XTIDECFG

	mov		cl, ATTRIBUTE_CHARS_size
	call	Memory_CopyCXbytesFromDSSItoESDI

.SkipCopy:
	pop		cx
	pop		si
	pop		ds
	ret


;--------------------------------------------------------------------
; WriteColorTheme
;	Parameters:
;		AX:		Value that the MENUITEM system was interacting with
;		ES:DI:	ROMVARS location where the value is to be stored
;		DS:SI:	MENUITEM pointer
;	Returns:
;		AX:		Value to actually write to ROMVARS
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
WriteColorTheme:
	push	cx
	push	si
	push	di

	mov		cx, ATTRIBUTE_CHARS_size
	mul		cl							; Multiply with the menu choice index
	mov		si, [es:di]					; Fetch the ptr to ColorTheme
	add		ax, ColorThemeTable
	xchg	si, ax
	mov		di, ax

	call	Memory_CopyCXbytesFromDSSItoESDI

	pop		di
	pop		si
	pop		cx
	ret

