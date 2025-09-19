; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions for flashing the EEPROM.

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
; Flash_EepromWithFlashvarsInDSSI
;	Parameters:
;		DS:SI:	Ptr to FLASHVARS
;	Returns:
;		FLASHVARS.flashResult
;	Corrupts registers:
;		All, including segments
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Flash_EepromWithFlashvarsInDSSI:
	mov		[si+FLASHVARS.wProgressUpdateParam], bp	; Store handle to progress DIALOG
	mov		bp, si									; Flashvars now in SS:BP
	mov		cx, [bp+FLASHVARS.wPagesToFlash]
ALIGN JUMP_ALIGN
.FlashNextPage:
	call	DisplayFlashProgressWithPagesLeftInCXandFlashvarsInSSBP
	call	Flash_SinglePageWithFlashvarsInSSBP
	jc		SHORT .PollingError
	call	AreSourceAndDestinationPagesEqualFromFlashvarsInSSBP
	jne		SHORT .DataVerifyError

	mov		ax, [bp+FLASHVARS.wEepromPageSize]
	add		[bp+FLASHVARS.fpNextSourcePage], ax
	add		[bp+FLASHVARS.fpNextComparisonPage], ax
	add		[bp+FLASHVARS.fpNextDestinationPage], ax

	loop	.FlashNextPage
%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if FLASH_RESULT.success = 0	; Just in case this should ever change
	mov		[bp+FLASHVARS.flashResult], cl
%else
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.success
%endif
%endif
	ret

.PollingError:
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.PollingTimeoutError
	ret
.DataVerifyError:
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DataVerifyError
	ret


;--------------------------------------------------------------------
; Flash_SinglePageWithFlashvarsInSSBP
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		CF:		Set if polling timeout error
;				Cleared if page written successfully
;	Corrupts registers:
;		AX, BX, DX, SI, DI, DS, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Flash_SinglePageWithFlashvarsInSSBP:
%ifdef CLD_NEEDED
	cld
%endif
	call	AreSourceAndDestinationPagesEqualFromFlashvarsInSSBP
	je		SHORT .NoNeedToFlashThePage	; CF cleared

	push	cx
	call	.GetSdpCommandFunctionToAXwithFlashvarsInSSBP
	mov		cx, [bp+FLASHVARS.wEepromPageSize]
	mov		si, [bp+FLASHVARS.fpNextSourcePage]
	les		di, [bp+FLASHVARS.fpNextComparisonPage]
	mov		bx, [bp+FLASHVARS.fpNextDestinationPage]
	call	WriteAllChangedBytesFromPageToEeprom
	pop		cx
.NoNeedToFlashThePage:
	ret

;--------------------------------------------------------------------
; .GetSdpCommandFunctionToAXwithFlashvarsInSSBP
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		AX:		Ptr to SDP Command function
;	Corrupts registers:
;		BX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.GetSdpCommandFunctionToAXwithFlashvarsInSSBP:
	eMOVZX	bx, [bp+FLASHVARS.bEepromSdpCommand]
	mov		si, [cs:bx+.rgpSdpCommandToEepromTypeLookupTable]
	mov		bl, [bp+FLASHVARS.bEepromType]
	mov		ax, [cs:bx+si]
	ret

ALIGN WORD_ALIGN
.rgpSdpCommandToEepromTypeLookupTable:
	dw		.rgfnFlashWithoutSDP					; SDP_COMMAND.none
	dw		.rgfnEnableSdpAndFlash					; SDP_COMMAND.enable
	dw		.rgfnDisableSdpAndFlash					; SDP_COMMAND.disable
.rgfnFlashWithoutSDP:		; SDP_COMMAND.none
	dw		DoNotWriteAnySdpCommand					; EEPROM_TYPE.2816_2kiB
	dw		DoNotWriteAnySdpCommand					; EEPROM_TYPE.2864_8kiB
	dw		DoNotWriteAnySdpCommand					; EEPROM_TYPE.2864_8kiB_MOD
	dw		DoNotWriteAnySdpCommand					; EEPROM_TYPE.28256_32kiB
	dw		DoNotWriteAnySdpCommand					; EEPROM_TYPE.28512_64kiB
.rgfnEnableSdpAndFlash:		; SDP_COMMAND.enable
	dw		WriteSdpEnableCommandFor2816			; EEPROM_TYPE.2816_2kiB
	dw		WriteSdpEnableCommandFor2864			; EEPROM_TYPE.2864_8kiB
	dw		WriteSdpEnableCommandFor2864mod			; EEPROM_TYPE.2864_8kiB_MOD
	dw		WriteSdpEnableCommandFor28256or28512	; EEPROM_TYPE.28256_32kiB
	dw		WriteSdpEnableCommandFor28256or28512	; EEPROM_TYPE.28512_64kiB
.rgfnDisableSdpAndFlash:	; SDP_COMMAND.disable
	dw		WriteSdpDisableCommandFor2816			; EEPROM_TYPE.2816_2kiB
	dw		WriteSdpDisableCommandFor2864			; EEPROM_TYPE.2864_8kiB
	dw		WriteSdpDisableCommandFor2864mod		; EEPROM_TYPE.2864_8kiB_MOD
	dw		WriteSdpDisableCommandFor28256or28512	; EEPROM_TYPE.28256_32kiB
	dw		WriteSdpDisableCommandFor28256or28512	; EEPROM_TYPE.28512_64kiB


;--------------------------------------------------------------------
; AreSourceAndDestinationPagesEqualFromFlashvarsInSSBP
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		ZF:		Set if pages are equal
;				Cleared if pages are not equal
;	Corrupts registers:
;		SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
AreSourceAndDestinationPagesEqualFromFlashvarsInSSBP:
	push	cx
	mov		cx, [bp+FLASHVARS.wEepromPageSize]
	lds		si, [bp+FLASHVARS.fpNextSourcePage]
	les		di, [bp+FLASHVARS.fpNextDestinationPage]
	repe cmpsb
	pop		cx
	ret


;--------------------------------------------------------------------
; ENABLE_SDP
;	Parameters:
;		%1:		Offset for first command byte
;		%2:		Offset for second command byte
;		DS:		Segment to beginning of EEPROM
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro ENABLE_SDP 2
	mov		BYTE [%1], 0AAh
	mov		BYTE [%2], 55h
	mov		BYTE [%1], 0A0h
%endmacro

;--------------------------------------------------------------------
; DISABLE_SDP
;	Parameters:
;		%1:		Offset for first command byte
;		%2:		Offset for second command byte
;		DS:		Segment to beginning of EEPROM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%macro DISABLE_SDP 2
	mov		ax, 80AAh
%%Again:
	mov		[%1], al		; 0AAh
	shr		al, 1
	mov		[%2], al		; 55h
	mov		[%1], ah		; 80h/20h
	xor		ax, 0A0FFh
	jns		SHORT %%Again
%endmacro

;--------------------------------------------------------------------
; SDP Command Functions
;	Parameters:
;		DS:		Segment to beginning of EEPROM
;	Returns:
;		Nothing but jumps to WriteActualDataByteAfterSdpCommand
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
WriteSdpEnableCommandFor2816:
	ENABLE_SDP 555h, 2AAh
	jmp		ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpEnableCommandFor2864:
	ENABLE_SDP 1555h, 0AAAh
	jmp		ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpEnableCommandFor2864mod:
	ENABLE_SDP 155Ch, 0AA3h
	jmp		SHORT ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpEnableCommandFor28256or28512:
	ENABLE_SDP 5555h, 2AAAh
	jmp		SHORT ReturnFromSdpCommand


ALIGN JUMP_ALIGN
WriteSdpDisableCommandFor2816:
	DISABLE_SDP 555h, 2AAh
	jmp		SHORT ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpDisableCommandFor2864:
	DISABLE_SDP 1555h, 0AAAh
	jmp		SHORT ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpDisableCommandFor2864mod:
	DISABLE_SDP 155Ch, 0AA3h
	jmp		SHORT ReturnFromSdpCommand

ALIGN JUMP_ALIGN
WriteSdpDisableCommandFor28256or28512:
	DISABLE_SDP 5555h, 2AAAh
	jmp		SHORT ReturnFromSdpCommand

DoNotWriteAnySdpCommand EQU ReturnFromSdpCommand


;--------------------------------------------------------------------
; WriteAllChangedBytesFromPageToEeprom
;	Parameters:
;		AX:		Offset to SDP command function
;		BX:		Offset to next destination byte
;		CX:		Number of bytes left to write
;		SI:		Offset to next source byte
;		ES:DI:	Ptr to next comparison byte
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		CF:		Set if polling timeout error
;				Cleared if page written successfully
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI, DS, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
WriteAllChangedBytesFromPageToEeprom:
	mov		dx, [bp+FLASHVARS.fpNextSourcePage+2]		; DX = Source segment
	mov		ds, [bp+FLASHVARS.fpNextDestinationPage+2]	; DS = EEPROM segment
	cli						; Disable interrupts
	jmp		ax				; Write SDP command (once to the beginning of page)
ALIGN JUMP_ALIGN
ReturnFromSdpCommand:
	mov		ds, dx			; DS:SI now points to source byte

ALIGN JUMP_ALIGN
.WriteActualDataByteAfterSdpCommand:
	lodsb					; Load source byte to AL
	scasb					; Compare source byte to comparison byte
	je		SHORT .NoChangesForThisByte

	mov		ds, [bp+FLASHVARS.fpNextDestinationPage+2]	; DS:BX now points to EEPROM
	mov		[bx], al		; Write byte to EEPROM
	mov		ds, dx			; Restore DS
	mov		[bp+FLASHVARS.wLastOffsetWritten], bx
	mov		[bp+FLASHVARS.bLastByteWritten], al

ALIGN JUMP_ALIGN
.NoChangesForThisByte:
	inc		bx				; Increment destination offset
	loop	.WriteActualDataByteAfterSdpCommand
	sti						; Enable interrupts
	; Fall to .WaitUntilEepromPageWriteHasCompleted


;--------------------------------------------------------------------
; .WaitUntilEepromPageWriteHasCompleted
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		CF:		Set if polling timeout error
;				Cleared if page written successfully
;	Corrupts registers:
;		AX, BX, DI, DS, ES
;--------------------------------------------------------------------
.WaitUntilEepromPageWriteHasCompleted:
	push	ss
	pop		ds
	lea		bx, [bp+FLASHVARS.wTimeoutCounter]
	mov		ax, EEPROM_POLLING_TIMEOUT_TICKS
	call	TimerTicks_InitializeTimeoutFromAX
	mov		es, [bp+FLASHVARS.fpNextDestinationPage+2]
	mov		di, [bp+FLASHVARS.wLastOffsetWritten]
ALIGN JUMP_ALIGN
.PollEeprom:
	mov		al, [es:di]							; Load byte from EEPROM
	xor		al, [bp+FLASHVARS.bLastByteWritten]	; Clear SF if the most significant bits are the same
	jns		SHORT .PageWriteCompleted			; With CF cleared
	call	TimerTicks_GetTimeoutTicksLeftToAXfromDSBX
	jnc		SHORT .PollEeprom
ALIGN JUMP_ALIGN, ret
.PageWriteCompleted:
	ret


;--------------------------------------------------------------------
; DisplayFlashProgressWithPagesLeftInCXandFlashvarsInSSBP
;	Parameters:
;		CX:		Number of pages left to flash
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayFlashProgressWithPagesLeftInCXandFlashvarsInSSBP:
	push	bp

	mov		ax, [bp+FLASHVARS.wPagesToFlash]
	sub		ax, cx
	mov		bp, [bp+FLASHVARS.wProgressUpdateParam]	; BP now has MENU handle
	CALL_MENU_LIBRARY SetProgressValueFromAX

	pop		bp
	ret
