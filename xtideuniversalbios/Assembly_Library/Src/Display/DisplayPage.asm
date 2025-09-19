; Project name	:	Assembly Library
; Description	:	Functions for managing display page.

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
; DisplayPage_SetFromAL
;	Parameters:
;		AL:		New display page
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XUB OR EXCLUDE_FROM_XTIDECFG OR EXCLUDE_FROM_BIOSDRVS
ALIGN DISPLAY_JUMP_ALIGN
DisplayPage_SetFromAL:
	xor		ah, ah
	mul		WORD [VIDEO_BDA.wBytesPerPage]		; AX = Offset to page
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition], ax
	ret
%endif


%ifdef EXCLUDE_FROM_XUB
	%define EXCLUDE
	%ifdef MODULE_HOTKEYS OR MODULE_BOOT_MENU
		%undef EXCLUDE
	%endif
%endif

%ifndef EXCLUDE OR EXCLUDE_FROM_BIOSDRVS
;--------------------------------------------------------------------
; DisplayPage_GetColumnsToALandRowsToAH
;	Parameters:
;		DS:		BDA segment (zero)
;	Returns:
;		AL:		Number of columns in selected text mode
;		AH:		Number of rows in selected text mode
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPage_GetColumnsToALandRowsToAH:
	mov		al, [VIDEO_BDA.wColumns]		; 40 or 80
	mov		ah, 25							; Always 25 rows on standard text modes
	ret
%endif
%undef EXCLUDE

;--------------------------------------------------------------------
; DisplayPage_SynchronizeToHardware
;	Parameters:
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN DISPLAY_JUMP_ALIGN
DisplayPage_SynchronizeToHardware:
	xor		dx, dx
	mov		ax, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition]
	div		WORD [VIDEO_BDA.wBytesPerPage]	; AX = Page

	cmp		al, [VIDEO_BDA.bActivePage]
	je		SHORT .Return					; Same page, no need to synchronize
	mov		ah, SELECT_ACTIVE_DISPLAY_PAGE
	int		BIOS_VIDEO_INTERRUPT_10h
.Return:
	ret
