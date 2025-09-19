; Project name	:	Assembly Library
; Description	:	DOS Critical Error Handler (24h) replacements.

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

; Note! Only DOS functions 01h - 0Ch, 30h and 59h can be called from a Critical Error Handler.

; DOS Critical Error Handler return values
struc CRITICAL_ERROR_ACTION
	.ignoreErrorAndContinueProcessingRequest	resb	1
	.retryOperation								resb	1
	.terminateProgramAsThoughInt21hAH4ChCalled	resb	1
	.failSystemCallInProgress					resb	1	; Needs DOS 3.1+
endstruc


; Section containing code
SECTION .text

;--------------------------------------------------------------------
; DosCritical_InstallNewHandlerFromCSDX
;	Parameters:
;		CS:DX:	New Critical Error Handler
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DosCritical_InstallNewHandlerFromCSDX:
	push	ds

	mov		al, DOS_CRITICAL_ERROR_HANDLER_24h
	call	HookInterruptVectorInALwithHandlerInCSDX

	pop		ds
	ret


;--------------------------------------------------------------------
; DosCritical_RestoreDosHandler
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DosCritical_RestoreDosHandler:
	push	ds
	push	dx
	push	ax

	lds		dx, [cs:PSP.fpInt24hCriticalError]
	mov		ax, (SET_INTERRUPT_VECTOR<<8) | DOS_CRITICAL_ERROR_HANDLER_24h
	int		DOS_INTERRUPT_21h

	pop		ax
	pop		dx
	pop		ds
	ret


;--------------------------------------------------------------------
; DosCritical_CustomHandler
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DosCritical_CustomHandler:
	add		sp, 6	; Remove the INT 24h return address and flags from stack

	mov		ah, GET_EXTENDED_ERROR_INFORMATION	; Requires DOS 3.0+
	xor		bx, bx
	int		DOS_INTERRUPT_21h
	mov		[cs:bLastCriticalError], al

	pop		ax
	pop		bx
	pop		cx
	pop		dx
	pop		si
	pop		di
	pop		bp
	pop		ds
	pop		es
	iret			; Return from the INT 21h call

bLastCriticalError:		db	0


;--------------------------------------------------------------------
; DosCritical_HandlerToIgnoreAllErrors
;	Parameters:
;		Nothing
;	Returns:
;		AL:		CRITICAL_ERROR_ACTION
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DosCritical_HandlerToIgnoreAllErrors:
	mov		al, CRITICAL_ERROR_ACTION.ignoreErrorAndContinueProcessingRequest
	iret

