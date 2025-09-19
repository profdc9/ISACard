; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Main menu structs and functions.

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
g_MenupageForMainMenu:
istruc MENUPAGE
	at	MENUPAGE.fnEnter,			dw	MainMenu_EnterMenuOrModifyItemVisibility
	at	MENUPAGE.fnBack,			dw	ExitToDosFromBackButton
	at	MENUPAGE.wMenuitems,		dw	9
iend

g_MenuitemMainMenuLicense:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_DisplayHelpMessageFromDSSI
	at	MENUITEM.szName,			dw	g_szItemMainLicense
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainLicense
	at	MENUITEM.szHelp,			dw	g_szHelpMainLicense
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuLoadBiosFromFile:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	LoadBiosFromFile
	at	MENUITEM.szName,			dw	g_szItemMainLoadFile
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainLoadFile
	at	MENUITEM.szHelp,			dw	g_szNfoMainLoadFile
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuLoadXtideUniversalBiosFromRom:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	LoadXtideUniversalBiosFromRom
	at	MENUITEM.szName,			dw	g_szItemMainLoadROM
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainLoadROM
	at	MENUITEM.szHelp,			dw	g_szNfoMainLoadROM
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuLoadOldSettingsFromEeprom:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	LoadOldSettingsFromEeprom
	at	MENUITEM.szName,			dw	g_szItemMainLoadStngs
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainLoadStngs
	at	MENUITEM.szHelp,			dw	g_szNfoMainLoadStngs
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuConfigureXtideUniversalBios:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	ConfigurationMenu_EnterMenuOrModifyItemVisibility
	at	MENUITEM.szName,			dw	g_szItemMainConfigure
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainConfigure
	at	MENUITEM.szHelp,			dw	g_szNfoMainConfigure
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemMainMenuFlashEeprom:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	FlashMenu_EnterMenuOrModifyItemVisibility
	at	MENUITEM.szName,			dw	g_szItemMainFlash
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainFlash
	at	MENUITEM.szHelp,			dw	g_szNfoMainFlash
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemMainMenuSaveFile:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	BiosFile_SaveUnsavedChanges
	at	MENUITEM.szName,			dw	g_szItemMainSave
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainSave
	at	MENUITEM.szHelp,			dw	g_szNfoMainSave
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuExitToDos:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	ExitToDosSelectedFromMenu
	at	MENUITEM.szName,			dw	g_szItemMainExitToDOS
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainExitToDOS
	at	MENUITEM.szHelp,			dw	g_szNfoMainExitToDOS
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemMainMenuHomePage:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_DisplayHelpMessageFromDSSI
	at	MENUITEM.szName,			dw	g_szItemMainHomePage
	at	MENUITEM.szQuickInfo,		dw	g_szNfoMainHomePage
	at	MENUITEM.szHelp,			dw	g_szNfoMainHomePage
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend


; Section containing code
SECTION .text

;--------------------------------------------------------------------
; MainMenu_EnterMenuOrModifyItemVisibility
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except BP
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
MainMenu_EnterMenuOrModifyItemVisibility:
	push	cs
	pop		ds
	call	.EnableOrDisableXtideRomItems
	call	.EnableOrDisableConfigureXtideUniversalBios
	call	.EnableOrDisableFlashEeprom
	call	.EnableOrDisableSave
	mov		si, g_MenupageForMainMenu
	jmp		Menupage_ChangeToNewMenupageInDSSI

;--------------------------------------------------------------------
; .EnableOrDisableXtideRomItems
;	Parameters:
;		DS:		CFGVARS segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, SI, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableXtideRomItems:
	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	jc		SHORT .DisableAllRomItems
	or		BYTE [g_MenuitemMainMenuLoadXtideUniversalBiosFromRom+MENUITEM.bFlags], FLG_MENUITEM_VISIBLE
	call	Buffers_IsXtideUniversalBiosLoaded
	jne		SHORT .DisableLoadSettingFromRom
	or		BYTE [g_MenuitemMainMenuLoadOldSettingsFromEeprom+MENUITEM.bFlags], FLG_MENUITEM_VISIBLE
	ret

ALIGN JUMP_ALIGN
.DisableAllRomItems:
	and		BYTE [g_MenuitemMainMenuLoadXtideUniversalBiosFromRom+MENUITEM.bFlags], ~FLG_MENUITEM_VISIBLE
.DisableLoadSettingFromRom:
	and		BYTE [g_MenuitemMainMenuLoadOldSettingsFromEeprom+MENUITEM.bFlags], ~FLG_MENUITEM_VISIBLE
	ret

;--------------------------------------------------------------------
; .EnableOrDisableConfigureXtideUniversalBios
;	Parameters:
;		DS:		CFGVARS segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		CX, SI, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableConfigureXtideUniversalBios:
	call	Buffers_IsXtideUniversalBiosLoaded
	jne		SHORT .DisableConfigureXtideUniversalBios
	or		BYTE [g_MenuitemMainMenuConfigureXtideUniversalBios+MENUITEM.bFlags], FLG_MENUITEM_VISIBLE
	ret

ALIGN JUMP_ALIGN
.DisableConfigureXtideUniversalBios:
	and		BYTE [g_MenuitemMainMenuConfigureXtideUniversalBios+MENUITEM.bFlags], ~FLG_MENUITEM_VISIBLE
	ret

;--------------------------------------------------------------------
; .EnableOrDisableFlashEeprom
;	Parameters:
;		DS:		CFGVARS segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableFlashEeprom:
	test	BYTE [g_cfgVars+CFGVARS.wFlags], FLG_CFGVARS_FILELOADED | FLG_CFGVARS_ROMLOADED
	jz		SHORT .DisableFlashEeprom
	or		BYTE [g_MenuitemMainMenuFlashEeprom+MENUITEM.bFlags], FLG_MENUITEM_VISIBLE
	ret

ALIGN JUMP_ALIGN
.DisableFlashEeprom:
	and		BYTE [g_MenuitemMainMenuFlashEeprom+MENUITEM.bFlags], ~FLG_MENUITEM_VISIBLE
	ret

;--------------------------------------------------------------------
; .EnableOrDisableSave
;	Parameters:
;		DS:		CFGVARS segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableSave:
	test	BYTE [g_cfgVars+CFGVARS.wFlags], FLG_CFGVARS_FILELOADED
	jz		SHORT .DisableSave
	or		BYTE [g_MenuitemMainMenuSaveFile+MENUITEM.bFlags], FLG_MENUITEM_VISIBLE
	ret

ALIGN JUMP_ALIGN
.DisableSave:
	and		BYTE [g_MenuitemMainMenuSaveFile+MENUITEM.bFlags], ~FLG_MENUITEM_VISIBLE
	ret

;--------------------------------------------------------------------
; MENUITEM activation functions (.fnActivate)
;	Parameters:
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except segments
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ExitToDosSelectedFromMenu:
	JMP_MENU_LIBRARY CloseMenuIfExitEventAllows


ALIGN JUMP_ALIGN
LoadBiosFromFile:
	call	Buffers_SaveChangesIfFileLoaded
	mov		cl, FILE_DIALOG_IO_size
	call	Memory_ReserveCLbytesFromStackToDSSI
	call	Dialogs_DisplayFileDialogWithDialogIoInDSSI
	cmp		BYTE [si+FILE_DIALOG_IO.bUserCancellation], TRUE
	je		SHORT .CancelFileLoading

	add		si, BYTE FILE_DIALOG_IO.szFile
	call	BiosFile_LoadFileFromDSSItoRamBuffer
	call	LoadColorTheme
	call	MainMenu_EnterMenuOrModifyItemVisibility
.CancelFileLoading:
	add		sp, BYTE FILE_DIALOG_IO_size
ExitToDosFromBackButton:
	ret


ALIGN JUMP_ALIGN
LoadXtideUniversalBiosFromRom:
	call	Buffers_SaveChangesIfFileLoaded
	call	EEPROM_LoadXtideUniversalBiosFromRomToRamBufferAndReturnSizeInDXCX
	mov		al, FLG_CFGVARS_ROMLOADED
	call	Buffers_NewBiosWithSizeInDXCXandSourceInALhasBeenLoadedForConfiguration
	mov		dx, g_szDlgMainLoadROM
	call	Dialogs_DisplayNotificationFromCSDX
	call	LoadColorTheme
	jmp		MainMenu_EnterMenuOrModifyItemVisibility


ALIGN JUMP_ALIGN
LoadOldSettingsFromEeprom:
	call	Buffers_SaveChangesIfFileLoaded
	call	EEPROM_LoadOldSettingsFromRomToRamBuffer
	call	Buffers_SetUnsavedChanges
	mov		dx, g_szDlgMainLoadStngs
	call	Dialogs_DisplayNotificationFromCSDX
	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	call	LoadColorTheme.FromROM
	jmp		MainMenu_EnterMenuOrModifyItemVisibility


;--------------------------------------------------------------------
; LoadColorTheme
;	Parameters:
;		ES:		ROMVARS segment (only when loading theme from ROM)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, SI, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
LoadColorTheme:
	call	Buffers_GetFileBufferToESDI
	call	Buffers_IsXtideUniversalBiosSignatureInESDI
	jnz		SHORT .Return
.FromROM:
	mov		ax, [es:ROMVARS.pColorTheme]
	jmp		ReadColorTheme
.Return:
	ret

