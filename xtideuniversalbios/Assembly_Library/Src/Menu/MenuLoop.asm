; Project name	:	Assembly Library
; Description	:	Menu loop for waiting keystrokes.

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
; MenuLoop_Enter
;	Parameters
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN MENU_JUMP_ALIGN
MenuLoop_Enter:
	call	KeystrokeProcessing
	call	TimeoutProcessing
%ifdef MENUEVENT_IDLEPROCESSING_ENABLE
	call	MenuEvent_IdleProcessing	; User idle processing
%endif
	test	BYTE [bp+MENU.bFlags], FLG_MENU_EXIT
	jz		SHORT MenuLoop_Enter
	ret


;--------------------------------------------------------------------
; KeystrokeProcessing
; TimeoutProcessing
;	Parameters
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except SS:BP
;--------------------------------------------------------------------
ALIGN MENU_JUMP_ALIGN
KeystrokeProcessing:
	call	Keyboard_GetKeystrokeToAX
	jnz		SHORT ProcessKeystrokeFromAX
NoKeystrokeToProcess:
	ret

ALIGN MENU_JUMP_ALIGN
TimeoutProcessing:
	call	MenuTime_UpdateSelectionTimeout
	jnc		NoKeystrokeToProcess
	mov		al, CR	; Fake ENTER to select item
	; Fall to ProcessKeystrokeFromAX


;--------------------------------------------------------------------
; ProcessKeystrokeFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN MENU_JUMP_ALIGN
ProcessKeystrokeFromAX:
	xchg	cx, ax
	call	MenuTime_StopSelectionTimeout
	xchg	ax, cx
	call	.ProcessMenuSystemKeystrokeFromAX
	jc		SHORT NoKeystrokeToProcess
	jmp		MenuEvent_KeyStrokeInAX

;--------------------------------------------------------------------
; .ProcessMenuSystemKeystrokeFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		CF:		Set if keystroke processed
;				Cleared if keystroke not processed
;		AL:		ASCII character (if CF cleared)
;		AH:		BIOS scan code (if CF cleared)
;	Corrupts registers:
;		BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN MENU_JUMP_ALIGN
.ProcessMenuSystemKeystrokeFromAX:
%ifndef MENU_NO_ESC
	cmp		al, ESC
	jne		SHORT .NotEscape

	; Leave menu without selecting item
	call	MenuEvent_ExitMenu
	jnc		SHORT .CancelMenuExit
	call	MenuInit_CloseMenuWindow
	mov		WORD [bp+MENUINIT.wHighlightedItem], NO_ITEM_HIGHLIGHTED
.CancelMenuExit:
	stc
	ret
%endif

ALIGN MENU_JUMP_ALIGN
.NotEscape:
	cmp		al, CR
	jne		SHORT .NotCarriageReturn

	; Select item
	mov		cx, [bp+MENUINIT.wHighlightedItem]
	call	MenuEvent_ItemSelectedFromCX
	stc
.Return:
	ret

ALIGN MENU_JUMP_ALIGN
.NotCarriageReturn:
	test	BYTE [bp+MENU.bFlags], FLG_MENU_USER_HANDLES_SCROLLING
	jnz		SHORT .Return	; With CF cleared since keystroke not processed
	; Fall to MenuLoop_ProcessScrollingKeysFromAX


;--------------------------------------------------------------------
; MenuLoop_ProcessScrollingKeysFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		CF:		Set if keystroke processed
;				Cleared if keystroke not processed
;		AL:		ASCII character (if CF cleared)
;		AH:		BIOS scan code (if CF cleared)
;	Corrupts registers:
;		BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN MENU_JUMP_ALIGN
MenuLoop_ProcessScrollingKeysFromAX:
	xchg	ah, al
	cmp		al, MENU_KEY_PGUP
	je		SHORT .ChangeToPreviousPage
	cmp		al, MENU_KEY_PGDN
	je		SHORT .ChangeToNextPage
	cmp		al, MENU_KEY_HOME
	je		SHORT .SelectFirstItem
	cmp		al, MENU_KEY_END
	je		SHORT .SelectLastItem

	cmp		al, MENU_KEY_UP
	je		SHORT .DecrementSelectedItem
	cmp		al, MENU_KEY_DOWN
	je		SHORT .IncrementSelectedItem
	clc		; Clear CF since keystroke not processed
	xchg	ah, al
	ret

ALIGN MENU_JUMP_ALIGN
.ChangeToPreviousPage:
	call	MenuScrollbars_GetMaxVisibleItemsOnPageToCX
	neg		cx
	mov		ax, cx
	add		cx, [bp+MENUINIT.wHighlightedItem]
	jge		SHORT .MoveHighlightedItemByAX	; No rotation for PgUp
	; Fall to .SelectFirstItem
ALIGN MENU_JUMP_ALIGN
.SelectFirstItem:
	mov		ax, [bp+MENUINIT.wHighlightedItem]
	neg		ax
	jmp		SHORT .MoveHighlightedItemByAX

ALIGN MENU_JUMP_ALIGN
.ChangeToNextPage:
	call	MenuScrollbars_GetMaxVisibleItemsOnPageToCX
	mov		ax, cx
	add		cx, [bp+MENUINIT.wHighlightedItem]
	cmp		cx, [bp+MENUINIT.wItems]
	jb		SHORT .MoveHighlightedItemByAX	; No rotation for PgDn
	; Fall to .SelectLastItem
ALIGN MENU_JUMP_ALIGN
.SelectLastItem:
	stc
	mov		ax, [bp+MENUINIT.wItems]
	sbb		ax, [bp+MENUINIT.wHighlightedItem]
	jmp		SHORT .MoveHighlightedItemByAX

ALIGN MENU_JUMP_ALIGN
.DecrementSelectedItem:
	mov		al, -1
	SKIP2B	cx
.IncrementSelectedItem:
	mov		al, 1
	cbw
ALIGN MENU_JUMP_ALIGN
.MoveHighlightedItemByAX:
	call	MenuScrollbars_MoveHighlightedItemByAX
	stc
	ret
