; Project name	:	Assembly Library
; Description	:	Interrupt handlers and related functions.

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
; Int2Fh_Handler
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int2Fh_Handler:
	cmp		ax, 4A00h			; DOS 5+ - FLOPPY-DISK LOGICAL DRIVE CHANGE NOTIFICATION
	je		SHORT .CallMightBeForMe
.CallIsNotForMe:
	db		0EAh				; Far jump opcode
.fpPreviousInt2FhHandler:
	dd		0					; Pointer is filled in when handler is installed

.CallMightBeForMe:
	inc		cx
	loop	.CallIsNotForMe
	dec		cx
ReturnFromNestedCall:
	iret


;--------------------------------------------------------------------
; Int23h_Handler
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int23h_Handler:
	cmp		BYTE [cs:Interrupt23hInProgress], 0
	jne		SHORT ReturnFromNestedCall
	inc		BYTE [cs:Interrupt23hInProgress]
	push	ds
	push	dx
	push	ax
	call	UnhookInterrupt2Fh
	pop		ax
	pop		dx
	pop		ds
	dec		BYTE [cs:Interrupt23hInProgress]	; Not really needed since we should not be called again
	; Special return to terminate program - might not work under DR-DOS (see RBIL)
	stc
	retf

Interrupt23hInProgress:		db		0


;--------------------------------------------------------------------
; HookInterrupt23h
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, DS
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
HookInterrupt23h:
	mov		al, DOS_CTRL_C_CTRL_BREAK_HANDLER_23h
	mov		dx, Int23h_Handler
	jmp		SHORT HookInterruptVectorInALwithHandlerInCSDX


;--------------------------------------------------------------------
; HookInterrupt2Fh
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, DX, DS, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
HookInterrupt2Fh:
	mov		ax, GET_INTERRUPT_VECTOR << 8 | DOS_TSR_MULTIPLEX_INTERRUPT_2Fh
	int		DOS_INTERRUPT_21h
	mov		[cs:Int2Fh_Handler.fpPreviousInt2FhHandler], bx
	mov		[cs:Int2Fh_Handler.fpPreviousInt2FhHandler+2], es
	mov		dx, Int2Fh_Handler
	jmp		SHORT HookInterruptVectorInALwithHandlerInCSDX


;--------------------------------------------------------------------
; UnhookInterrupt2Fh
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, DS
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
UnhookInterrupt2Fh:
	lds		dx, [cs:Int2Fh_Handler.fpPreviousInt2FhHandler]
	mov		ax, ds
	or		ax, dx
	jz		SHORT NotHooked		; Only hooked on DOS 5+
	mov		al, DOS_TSR_MULTIPLEX_INTERRUPT_2Fh
	SKIP2B	f

;--------------------------------------------------------------------
; HookInterruptVectorInALwithHandlerInCSDX
;	Parameters:
;		AL:		Interrupt vector to hook
;		DX:		Offset to handler
;	Returns:
;		Nothing
;	Corrupts registers:
;		AH, DS
;--------------------------------------------------------------------
HookInterruptVectorInALwithHandlerInCSDX:
	push	cs
	pop		ds
	; Fall to HookInterruptVectorInALwithHandlerInDSDX

;--------------------------------------------------------------------
; HookInterruptVectorInALwithHandlerInDSDX
;	Parameters:
;		AL:		Interrupt vector to hook
;		DX:		Offset to handler
;		DS:		Segment of handler
;	Returns:
;		Nothing
;	Corrupts registers:
;		AH
;--------------------------------------------------------------------
HookInterruptVectorInALwithHandlerInDSDX:
	mov		ah, SET_INTERRUPT_VECTOR
	int		DOS_INTERRUPT_21h
NotHooked:
	ret

