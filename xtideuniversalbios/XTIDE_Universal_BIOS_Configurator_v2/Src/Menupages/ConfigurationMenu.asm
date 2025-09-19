; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	"Configure XTIDE Universal BIOS" menu structs and functions.

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
g_MenupageForConfigurationMenu:
istruc MENUPAGE
	at	MENUPAGE.fnEnter,			dw	ConfigurationMenu_EnterMenuOrModifyItemVisibility
	at	MENUPAGE.fnBack,			dw	MainMenu_EnterMenuOrModifyItemVisibility
	at	MENUPAGE.wMenuitems,		dw	11
iend

g_MenuitemConfigurationBackToMainMenu:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	MainMenu_EnterMenuOrModifyItemVisibility
	at	MENUITEM.szName,			dw	g_szItemCfgBackToMain
	at	MENUITEM.szQuickInfo,		dw	g_szItemCfgBackToMain
	at	MENUITEM.szHelp,			dw	g_szItemCfgBackToMain
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGEBACK
iend

g_MenuitemConfigurationPrimaryIdeController:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	PrimaryIdeController
	at	MENUITEM.szName,			dw	g_szItemCfgIde1
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIde
	at	MENUITEM.szHelp,			dw	g_szNfoCfgIde
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemConfigurationSecondaryIdeController:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	SecondaryIdeController
	at	MENUITEM.szName,			dw	g_szItemCfgIde2
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIde
	at	MENUITEM.szHelp,			dw	g_szNfoCfgIde
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemConfigurationTertiaryIdeController:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	TertiaryIdeController
	at	MENUITEM.szName,			dw	g_szItemCfgIde3
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIde
	at	MENUITEM.szHelp,			dw	g_szNfoCfgIde
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemConfigurationQuaternaryIdeController:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	QuaternaryIdeController
	at	MENUITEM.szName,			dw	g_szItemCfgIde4
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIde
	at	MENUITEM.szHelp,			dw	g_szNfoCfgIde
	at	MENUITEM.bFlags,			db	NULL
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemConfigurationBootMenuSettings:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	BootMenuSettingsMenu_EnterMenuOrModifyItemVisibility
	at	MENUITEM.szName,			dw	g_szItemCfgBootMenu
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgBootMenu
	at	MENUITEM.szHelp,			dw	g_szNfoCfgBootMenu
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_PAGENEXT
iend

g_MenuitemAutoConfigure:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	AutoConfigure_ForThisSystem
	at	MENUITEM.szName,			dw	g_szItemAutoConfigure
	at	MENUITEM.szQuickInfo,		dw	g_szNfoAutoConfigure
	at	MENUITEM.szHelp,			dw	g_szNfoAutoConfigure
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_MODIFY_MENU
	at	MENUITEM.bType,				db	TYPE_MENUITEM_ACTION
iend

g_MenuitemConfigurationFullOperatingMode:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromShiftedItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemCfgFullMode
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgFullMode
	at	MENUITEM.szHelp,			dw	g_szHelpCfgFullMode
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_MODIFY_MENU | FLG_MENUITEM_FLAGVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.wFlags
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgCfgFullMode
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceBooleanFlag
	at	MENUITEM.itemValue + ITEM_VALUE.rgszValueToStringLookup,	dw	g_rgszValueToStringLookupForFlagBooleans
	at	MENUITEM.itemValue + ITEM_VALUE.wValueBitmask,				dw	FLG_ROMVARS_FULLMODE
iend

g_MenuitemConfigurationKiBtoStealFromRAM:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateUnsignedInputForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteUnsignedValueStringToBufferInESDIfromItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemCfgStealSize
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgStealSize
	at	MENUITEM.szHelp,			dw	g_szHelpCfgStealSize
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_BYTEVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_UNSIGNED
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.bStealSize
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgCfgStealSize
	at	MENUITEM.itemValue + ITEM_VALUE.wMinValue,					dw	1
	at	MENUITEM.itemValue + ITEM_VALUE.wMaxValue,					dw	255
iend

g_MenuitemConfigurationIdeControllers:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	ActivateInputForNumberOfIdeControllersMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteUnsignedValueStringToBufferInESDIfromItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemCfgIdeCnt
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIdeCnt
	at	MENUITEM.szHelp,			dw	g_szNfoCfgIdeCnt
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_VISIBLE | FLG_MENUITEM_MODIFY_MENU | FLG_MENUITEM_BYTEVALUE
	at	MENUITEM.bType,				db	TYPE_MENUITEM_UNSIGNED
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.bIdeCnt
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgCfgIdeCnt
	at	MENUITEM.itemValue + ITEM_VALUE.wMinValue,					dw	1
	at	MENUITEM.itemValue + ITEM_VALUE.wMaxValue,					dw	MAX_ALLOWED_IDE_CONTROLLERS
iend

g_MenuitemConfigurationIdleTimeout:
istruc MENUITEM
	at	MENUITEM.fnActivate,		dw	Menuitem_ActivateMultichoiceSelectionForMenuitemInDSSI
	at	MENUITEM.fnFormatValue,		dw	MenuitemPrint_WriteLookupValueStringToBufferInESDIfromRawItemInDSSI
	at	MENUITEM.szName,			dw	g_szItemCfgIdleTimeout
	at	MENUITEM.szQuickInfo,		dw	g_szNfoCfgIdleTimeout
	at	MENUITEM.szHelp,			dw	g_szHelpCfgIdleTimeout
	at	MENUITEM.bFlags,			db	FLG_MENUITEM_BYTEVALUE | FLG_MENUITEM_CHOICESTRINGS
	at	MENUITEM.bType,				db	TYPE_MENUITEM_MULTICHOICE
	at	MENUITEM.itemValue + ITEM_VALUE.wRomvarsValueOffset,		dw	ROMVARS.bIdleTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.szDialogTitle,				dw	g_szDlgCfgIdleTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.szMultichoice,				dw	g_szMultichoiceIdleTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.rgwChoiceToValueLookup,		dw	g_rgwChoiceToValueLookupForIdleTimeout
	at	MENUITEM.itemValue + ITEM_VALUE.rgszChoiceToStringLookup,	dw	g_rgszChoiceToStringLookupForIdleTimeout
iend

g_rgwChoiceToValueLookupForIdleTimeout:
	%assign i -12
	%rep 21
		%assign i i+12
		dw	i		; i / 12 = 0 (disabled) or 1...20 minutes
	%endrep
	%rep 4
		%assign i i+1
		dw	i		; 241...244 = (i - 240) * 30 minutes
	%endrep
g_rgszChoiceToStringLookupForIdleTimeout:
	%assign i 0
	%rep 25
		dw	g_szIdleTimeoutChoice%[i]
		%assign i i+1
	%endrep
		dw	NULL


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
ConfigurationMenu_EnterMenuOrModifyItemVisibility:
	push	cs
	pop		ds
	call	.DisableAllIdeControllerMenuitems
	call	.EnableIdeControllerMenuitemsBasedOnConfiguration
	call	.EnableOrDisableOperatingModeSelection
	call	.EnableOrDisableKiBtoStealFromRAM
	call	.EnableOrDisableIdleTimeout
	call	LimitIdeControllersForLiteMode
	mov		si, g_MenupageForConfigurationMenu
	jmp		Menupage_ChangeToNewMenupageInDSSI

;--------------------------------------------------------------------
; .DisableAllIdeControllerMenuitems
; .EnableIdeControllerMenuitemsBasedOnConfiguration
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.DisableAllIdeControllerMenuitems:
	mov		cx, MAX_ALLOWED_IDE_CONTROLLERS-1
	mov		ax, DisableMenuitemFromCSBX
	jmp		SHORT .Go

ALIGN JUMP_ALIGN
.EnableIdeControllerMenuitemsBasedOnConfiguration:
	call	Buffers_GetIdeControllerCountToCX
	dec		cx			; Primary always enabled
	jz		SHORT .PrimaryControllerAlreadyEnabled
	mov		ax, EnableMenuitemFromCSBX
.Go:
	mov		bx, g_MenuitemConfigurationSecondaryIdeController
ALIGN JUMP_ALIGN
.EnableOrDisableNextIdeControllerMenuitem:
	call	ax
	add		bx, BYTE MENUITEM_size
	loop	.EnableOrDisableNextIdeControllerMenuitem
.PrimaryControllerAlreadyEnabled:
	ret


;--------------------------------------------------------------------
; .EnableOrDisableOperatingModeSelection
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableOperatingModeSelection:
	mov		bx, g_MenuitemConfigurationFullOperatingMode
	call	Buffers_IsXTbuildLoaded
	je		SHORT .EnableMenuitemFromCSBX
	jmp		SHORT .DisableMenuitemFromCSBX


;--------------------------------------------------------------------
; .EnableOrDisableKiBtoStealFromRAM
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableKiBtoStealFromRAM:
	call	Buffers_GetRomvarsFlagsToAX
	mov		bx, g_MenuitemConfigurationKiBtoStealFromRAM
	test	al, FLG_ROMVARS_FULLMODE
	jz		SHORT .DisableMenuitemFromCSBX
	jmp		SHORT .EnableMenuitemFromCSBX


;--------------------------------------------------------------------
; .EnableOrDisableIdleTimeout
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.EnableOrDisableIdleTimeout:
	call	Buffers_GetRomvarsFlagsToAX
	mov		bx, g_MenuitemConfigurationIdleTimeout
	test	al, FLG_ROMVARS_MODULE_POWER_MANAGEMENT
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
; MENUITEM activation functions (.fnActivate)
;	Parameters:
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except segments
;--------------------------------------------------------------------
%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if (ROMVARS.ideVars0 | ROMVARS.ideVars1 | ROMVARS.ideVars2 | ROMVARS.ideVars3) & 0FF00h = 0
PrimaryIdeController:
	mov		bl, ROMVARS.ideVars0 & 0FFh
	SKIP2B	f
SecondaryIdeController:
	mov		bl, ROMVARS.ideVars1 & 0FFh
	SKIP2B	f
TertiaryIdeController:
	mov		bl, ROMVARS.ideVars2 & 0FFh
	SKIP2B	f
QuaternaryIdeController:
	mov		bl, ROMVARS.ideVars3 & 0FFh
	xor		bh, bh
	; Fall to DisplayIdeControllerMenu
%else
ALIGN JUMP_ALIGN
PrimaryIdeController:
	mov		bx, ROMVARS.ideVars0
	jmp		SHORT DisplayIdeControllerMenu

ALIGN JUMP_ALIGN
SecondaryIdeController:
	mov		bx, ROMVARS.ideVars1
	jmp		SHORT DisplayIdeControllerMenu

ALIGN JUMP_ALIGN
TertiaryIdeController:
	mov		bx, ROMVARS.ideVars2
	jmp		SHORT DisplayIdeControllerMenu

ALIGN JUMP_ALIGN
QuaternaryIdeController:
	mov		bx, ROMVARS.ideVars3
	; Fall to DisplayIdeControllerMenu
%endif
%endif

ALIGN JUMP_ALIGN
DisplayIdeControllerMenu:
	call	IdeControllerMenu_InitializeToIdevarsOffsetInBX
	jmp		IdeControllerMenu_EnterMenuOrModifyItemVisibility


ALIGN JUMP_ALIGN
ActivateInputForNumberOfIdeControllersMenuitemInDSSI:
	call	Menuitem_ActivateUnsignedInputForMenuitemInDSSI
	; Fall to LimitIdeControllersForLiteMode

;--------------------------------------------------------------------
; LimitIdeControllersForLiteMode
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
LimitIdeControllersForLiteMode:
	push	es
	call	Buffers_GetIdeControllerCountToCX
	mov		[es:di+ROMVARS.bIdeCnt], cl
	CALL_MENU_LIBRARY GetHighlightedItemToAX
	CALL_MENU_LIBRARY RefreshItemFromAX
	pop		es
	; Fall to ConfigurationMenu_CheckAndMoveSerialDrivesToBottom

;----------------------------------------------------------------------
; ConfigurationMenu_CheckAndMoveSerialDrivesToBottom
;
; Checks to ensure that serial adapters are at the end of the
; IDEVARS structures list, as serial floppies (if present) need to be
; the last drives detected by the BIOS.  If there are other controllers
; after a serial controller, the other controllers are moved up on the list
; and the serial controller is placed at the end of the list.
;
;	Parameters:
;		SS:BP:	Menu handle
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX
;----------------------------------------------------------------------
ConfigurationMenu_CheckAndMoveSerialDrivesToBottom:
	push	es
	push	ds
	push	di
	push	si

	call	Buffers_GetIdeControllerCountToCX	; will also set ES:DI to point to file buffer
	push	es
	pop		ds
	mov		dx, cx						; Controller count to DL (will always be at least 1) while also clearing notification flag in DH

	lea		bx, [di+ROMVARS.ideVars0]	; add in offset of first idevars

.outerLoop:
	mov		di, bx						; start of idevars
	xor		si, si						; first serial found
	xor		ax, ax						; first non-serial found
	mov		cl, dl						; idevars count

.loop:
	cmp		BYTE [di+IDEVARS.bDevice], DEVICE_SERIAL_PORT
	jne		SHORT .notSerial

	test	si, si						; record the first serial controller that we find
	jnz		SHORT .next
	mov		si, di
	SKIP2B	f

.notSerial:
	mov		ax, di						; record the *last* non-serial controller that we find

.next:
	add		di, IDEVARS_size
	loop	.loop

	test	si, si						; no serial drives, nothing to do
	jz		SHORT .done
	cmp		si, ax						; serial port is already later on the list than any other controllers
	ja		SHORT .done					; (also takes care of the case where there are no other controllers)

;
; move serial to end of list, others up
;
%ifdef CLD_NEEDED
	cld
%endif
	mov		ax, di						; save end pointer of list after scan
	sub		sp, IDEVARS_size			; copy serial to temporary space on stack
	mov		di, sp

	push	ss
	pop		es

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if IDEVARS_size & 1
	mov		cl, IDEVARS_size
	rep	movsb
%else
	mov		cl, IDEVARS_size / 2
	rep movsw
%endif
%endif

	lea		di, [si-IDEVARS_size]		; move up all the idevars below the serial, by one slot
	mov		cx, ax						; restore end pointer of list, subtract off end of serial idevars
	sub		cx, si

	push	ds
	pop		es

	rep	movsb

	mov		si, sp						; place serial (currently on the stack) at bottom of list
	push	ss
	pop		ds
	; di is already at last IDEVARS position

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if IDEVARS_size & 1
	mov		cl, IDEVARS_size
	rep	movsb
%else
	mov		cl, IDEVARS_size / 2
	rep movsw
%endif
%endif

	add		sp, IDEVARS_size

	push	es
	pop		ds

	mov		dh, 1						; set flag that we have done a relocation
	jmp		SHORT .outerLoop

.done:
	pop		si
	pop		di
	pop		ds
	pop		es

	test	dh, dh
	jz		SHORT .noWorkDone

	mov		dx, g_szSerialMoved
	call	Dialogs_DisplayNotificationFromCSDX

.noWorkDone:
	ret
