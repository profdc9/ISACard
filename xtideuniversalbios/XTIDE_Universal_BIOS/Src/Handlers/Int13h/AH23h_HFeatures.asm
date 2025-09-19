; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=23h,
;					Set Controller Features Register.

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
; Int 13h function AH=23h, Set Controller Features Register.
;
; AH23h_HandlerForSetControllerFeatures
;	Parameters:
;		AL, CX:	Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		AL:		Feature Number (parameter to Features Register = subcommand)
;	(Parameter registers are undocumented, these are specific for this BIOS):
;		BL:		Parameter to Sector Count Register (subcommand specific)
;		BH:		Parameter to LBA Low / Sector Number Register (subcommand specific)
;		CL:		Parameter to LBA Middle / Cylinder Low Register (subcommand specific)
;		CH:		Parameter to LBA High / Cylinder High Register (subcommand specific)
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH23h_HandlerForSetControllerFeatures:
	xchg	si, ax		; SI = Feature Number
	mov		dx, [bp+IDEPACK.intpack+INTPACK.bx]
%ifndef USE_186
	call	AH23h_SetControllerFeatures
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%else
	push	Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
	; Fall to AH23h_SetControllerFeatures
%endif


;--------------------------------------------------------------------
; AH23h_SetControllerFeatures
;	Parameters:
;		DL:		Parameter to Sector Count Register (subcommand specific)
;		DH:		Parameter to LBA Low / Sector Number Register (subcommand specific)
;		CL:		Parameter to LBA Middle / Cylinder Low Register (subcommand specific)
;		CH:		Parameter to LBA High / Cylinder High Register (subcommand specific)
;		SI:		Feature Number (parameter to Features Register = subcommand)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
AH23h_SetControllerFeatures:
	mov		al, COMMAND_SET_FEATURES
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_BSY, FLG_STATUS_BSY)
	jmp		Idepack_StoreNonExtParametersAndIssueCommandFromAL


;--------------------------------------------------------------------
; AH23h_Enable8bitPioMode
; AH23h_Disable8bitPioMode
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
%ifdef MODULE_8BIT_IDE
AH23h_Enable8bitPioMode:
	mov		si, FEATURE_ENABLE_8BIT_PIO_TRANSFER_MODE
	jmp		SHORT AH23h_SetControllerFeatures

%ifdef MODULE_8BIT_IDE_ADVANCED
AH23h_Disable8bitPioMode:
	mov		si, FEATURE_DISABLE_8BIT_PIO_TRANSFER_MODE
	call	AH23h_SetControllerFeatures
	xor		ah, ah			; Clear error since modern drives might not understand the command and are
	ret						; always in 16-bit mode anyway
%endif ; MODULE_8BIT_IDE_ADVANCED
%endif ; MODULE_8BIT_IDE


;--------------------------------------------------------------------
; Enable/disable advanced power management command can be used to scale
; power consumption and performance. Drive supporting Enable APM might not
; support Disable APM so we set the drive to max performance if stand by
; timer value is 0 (idle/standby disabled)
;
;
; AH23h_EnableOrDisableAdvancedPowerManagement
;	Parameters:
;		DL:		Stand By timer value (0=disable APM)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
%ifdef MODULE_POWER_MANAGEMENT
AH23h_EnableOrDisableAdvancedPowerManagement:
	mov		si, FEATURE_ENABLE_ADVANCED_POWER_MANAGEMENT
	test	dl, dl
	jnz		SHORT .EnablePowerSave
	mov		dl, 0FEh	; Maximum performance
	SKIP2B	f

; TODO: We should add power management level to IDEVARS to be adjustable with xtidecfg
.EnablePowerSave:
	mov		dl, 0BFh	; For Toshiba 1.8" HDD: 80h...BFh = Mode 1
	jmp		SHORT AH23h_SetControllerFeatures
%endif ; MODULE_POWER_MANAGEMENT
