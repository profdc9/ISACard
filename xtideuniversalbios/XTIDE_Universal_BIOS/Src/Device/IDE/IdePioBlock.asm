; Project name	:	XTIDE Universal BIOS
; Description	:	IDE Read/Write functions for transferring block using PIO modes.
;					These functions should only be called from IdeTransfer.asm.

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


; --------------------------------------------------------------------------------------------------
;
; READ routines follow
;
; --------------------------------------------------------------------------------------------------

%ifdef MODULE_8BIT_IDE
;--------------------------------------------------------------------
; IdePioBlock_ReadFromXtideRev1
;	Parameters:
;		CX:		Block size in 512 byte sectors
;		DX:		IDE Data port address
;		ES:DI:	Normalized ptr to buffer to receive data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_ReadFromXtideRev1:
	UNROLL_SECTORS_IN_CX_TO_OWORDS
	mov		bl, 8		; Bit mask for toggling data low/high reg
ALIGN JUMP_ALIGN
.InswLoop:
	%rep 8	; WORDs
		XTIDE_INSW
	%endrep
	loop	.InswLoop
	ret


;--------------------------------------------------------------------
; IdePioBlock_ReadFromXtideRev2_Olivetti
;	Parameters:
;		CX:		Block size in 512 byte sectors
;		DX:		IDE Data port address
;		ES:DI:	Normalized ptr to buffer to receive data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_ReadFromXtideRev2_Olivetti:
	UNROLL_SECTORS_IN_CX_TO_OWORDS
ALIGN JUMP_ALIGN
.InswLoop:
	%rep 8	; WORDs
		XTIDE_MOD_OLIVETTI_INSW
	%endrep
	loop	.InswLoop
	ret


;--------------------------------------------------------------------
; 8-bit PIO from a single data port.
;
; IdePioBlock_ReadFrom8bitDataPort
;	Parameters:
;		CX:		Block size in 512 byte sectors
;		DX:		IDE Data port address
;		ES:DI:	Normalized ptr to buffer to receive data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_ReadFrom8bitDataPort:
%ifdef USE_186
	shl		cx, 9		; Sectors to BYTEs
	rep insb
	ret
%else ; 808x
	UNROLL_SECTORS_IN_CX_TO_OWORDS
ALIGN JUMP_ALIGN
.ReadNextOword:
	%rep 16	; BYTEs
		in		al, dx	; Read BYTE
		stosb			; Store BYTE to [ES:DI]
	%endrep
	loop	.ReadNextOword
	ret
%endif
%endif ; MODULE_8BIT_IDE


;--------------------------------------------------------------------
; 16-bit and 32-bit PIO from a single data port.
;
; IdePioBlock_ReadFrom16bitDataPort
; IdePioBlock_ReadFrom32bitDataPort
;	Parameters:
;		CX:		Block size in 512 byte sectors
;		DX:		IDE Data port address
;		ES:DI:	Normalized ptr to buffer to receive data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_ReadFrom16bitDataPort:
%ifdef USE_186
	xchg	cl, ch		; Sectors to WORDs
	rep insw
	ret

%else ; 808x
	UNROLL_SECTORS_IN_CX_TO_OWORDS
ALIGN JUMP_ALIGN
.ReadNextOword:
	%rep 8	; WORDs
		in		ax, dx	; Read WORD
		stosw			; Store WORD to [ES:DI]
	%endrep
	loop	.ReadNextOword
	ret
%endif


;--------------------------------------------------------------------
%ifdef MODULE_ADVANCED_ATA
ALIGN JUMP_ALIGN
IdePioBlock_ReadFrom32bitDataPort:
	shl		cx, 7		; Sectors to DWORDs
	rep insd
	ret
%endif ; MODULE_ADVANCED_ATA


; --------------------------------------------------------------------------------------------------
;
; WRITE routines follow
;
; --------------------------------------------------------------------------------------------------

%ifdef MODULE_8BIT_IDE
;--------------------------------------------------------------------
; IdePioBlock_WriteToXtideRev1
;	Parameters:
;		CX:		Block size in 512-byte sectors
;		DX:		IDE Data port address
;		DS:SI:	Normalized ptr to buffer containing data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_WriteToXtideRev1:
	UNROLL_SECTORS_IN_CX_TO_QWORDS
	mov		bl, 8		; Bit mask for toggling data low/high reg
ALIGN JUMP_ALIGN
.OutswLoop:
	%rep 4	; WORDs
		XTIDE_OUTSW
	%endrep
	loop	.OutswLoop
	ret


;--------------------------------------------------------------------
; IdePioBlock_WriteToXtideRev2	or rev 1 with swapped A0 and A3 (chuck-mod)
;	Parameters:
;		CX:		Block size in 512-byte sectors
;		DX:		IDE Data port address
;		DS:SI:	Normalized ptr to buffer containing data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_WriteToXtideRev2:
	UNROLL_SECTORS_IN_CX_TO_QWORDS
ALIGN JUMP_ALIGN
.WriteNextQword:
	%rep 4	; WORDs
		XTIDE_MOD_OUTSW
	%endrep
	loop	.WriteNextQword
	ret


;--------------------------------------------------------------------
; IdePioBlock_WriteTo8bitDataPort
;	Parameters:
;		CX:		Block size in 512-byte sectors
;		DX:		IDE Data port address
;		DS:SI:	Normalized ptr to buffer containing data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_WriteTo8bitDataPort:
%ifdef USE_186
	shl		cx, 9		; Sectors to BYTEs
	rep outsb
	ret

%else ; 808x
	UNROLL_SECTORS_IN_CX_TO_QWORDS
ALIGN JUMP_ALIGN
.WriteNextQword:
	%rep 8	; BYTEs
		lodsb			; Load BYTE from [DS:SI]
		out		dx, al	; Write BYTE
	%endrep
	loop	.WriteNextQword
	ret
%endif
%endif ; MODULE_8BIT_IDE


;--------------------------------------------------------------------
; IdePioBlock_WriteTo16bitDataPort		Normal 16-bit IDE, XT-CFv3 in BIU Mode
; IdePioBlock_WriteTo32bitDataPort		VLB/PCI 32-bit IDE
;	Parameters:
;		CX:		Block size in 512-byte sectors
;		DX:		IDE Data port address
;		DS:SI:	Normalized ptr to buffer containing data
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdePioBlock_WriteTo16bitDataPort:
%ifdef USE_186
	xchg	cl, ch		; Sectors to WORDs
	rep outsw
	ret

%else ; 808x
	UNROLL_SECTORS_IN_CX_TO_QWORDS
ALIGN JUMP_ALIGN
.WriteNextQword:
	%rep 4	; WORDs
		lodsw			; Load WORD from [DS:SI]
		out		dx, ax	; Write WORD
	%endrep
	loop	.WriteNextQword
	ret
%endif

;--------------------------------------------------------------------
%ifdef MODULE_ADVANCED_ATA
ALIGN JUMP_ALIGN
IdePioBlock_WriteTo32bitDataPort:
	shl		cx, 7		; Sectors to DWORDs
	rep outsd
	ret
%endif ; MODULE_ADVANCED_ATA
