; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h handler that is used by MODULE_MFM_COMPATIBILITY.
;					It is placed between XUB Int 13h handler and system INT 13h handler
;					to hide XUB from MFM controllers whose BIOS assumes they handle
;					all hard drives on the system.

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
; Int 13h software interrupt handler for MFM compatibility.
;
; Some MFM controllers require that BDA drive count is what they have set.
; The purpose for this handler is to restore BDA drive count to what MFM controller
; expects and then call MFM controller INT 13h.
;
; Int13hMFMcompatibilityHandler
;	Parameters:
;		Any INT 13h function and parameters
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13hMFMcompatibilityHandler:
	eENTER	6, 0
	push	es
	push	ds
	push	di

	LOAD_BDA_SEGMENT_TO es, di
	call	RamVars_GetSegmentToDS

	; Remove our drives from BDA drive count
	push	ax
	mov		al, [RAMVARS.bDrvCnt]
	mov		[bp-2], al			; Store our drive count for later use
	sub		[es:HDBDA.bHDCount], al
	pop		ax

	; Copy MFM controller INT 13h address to stack
	les		di, [RAMVARS.fpMFMint13h]
	mov		[bp-4], es
	mov		[bp-6], di

	; Restore registers so we can call MFM int 13h
	pop		di
	pop		ds
	pop		es

	pushf	; Push flags to simulate INT
	call	FAR [bp-6]

	; Now we can restore BDA drive count
	push	ds
	push	ax
	lahf					; Get return flags to AH
	mov		[bp-12], ah		; Store return flags to be popped by iret
	LOAD_BDA_SEGMENT_TO ds, ax
	mov		al, [bp-2]
	add		[HDBDA.bHDCount], al
	pop		ax
	pop		ds

	; Return from this handler
	eLEAVE
	iret
