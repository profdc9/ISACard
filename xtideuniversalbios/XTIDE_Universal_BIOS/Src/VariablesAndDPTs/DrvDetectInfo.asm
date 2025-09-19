; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for generating and accessing drive
;					information to be displayed on boot menu.

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
; Creates new DRVDETECTINFO struct for detected hard disk.
;
; DriveDetectInfo_CreateForHardDisk
;	Parameters:
;		DL:		Drive number
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		ES:BX:	Ptr to DRVDETECTINFO (if successful)
;	Corrupts registers:
;		AX, BX, CX, DX, DI
;--------------------------------------------------------------------
DriveDetectInfo_CreateForHardDisk:
	call	DriveDetectInfo_ConvertDPTtoBX		; ES:BX now points to new DRVDETECTINFO

	; Store Drive Name
	push	ds									; Preserve RAMVARS
	push	si

	push	es									; ES copied to DS
	pop		ds

	add		si, BYTE ATA1.strModel				; DS:SI now points drive name (Clears CF)
%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if DRVDETECTINFO.szDrvName = 0
	mov		di, bx
%else
	lea		di, [bx+DRVDETECTINFO.szDrvName]	; ES:DI now points to name destination
%endif
%endif
	mov		cx, MAX_HARD_DISK_NAME_LENGTH / 2	; Max number of WORDs allowed
.CopyNextWord:
	lodsw
	xchg	al, ah								; Change endianness
	stosw
	loop	.CopyNextWord
	xchg	cx, ax								; Zero AX (CF already cleared from the ADD above)
	stosw										; Terminate with NULL

	pop		si
	pop		ds

	ret


;--------------------------------------------------------------------
; Returns offset to DRVDETECTINFO based on DPT pointer.
;
; DriveDetectInfo_ConvertDPTtoBX
;	Parameters:
;		DS:DI:	DPT Pointer
;	Returns:
;		BX:		Offset to DRVDETECTINFO struct
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
DriveDetectInfo_ConvertDPTtoBX:
%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if DPT_DRVDETECTINFO_SIZE_MULTIPLIER = 2
%if BOOTVARS.rgDrvDetectInfo & 1					; Should never be odd but better safe than sorry
	lea		bx, [di-RAMVARS_size]
	eSHL_IM	bx, 1
	add		bx, BOOTVARS.rgDrvDetectInfo
%else
	lea		bx, [di-RAMVARS_size+(BOOTVARS.rgDrvDetectInfo/2)]
	eSHL_IM	bx, 1
%endif
%else
%ifdef USE_186
	lea		bx, [di-RAMVARS_size]
	imul	bx, DPT_DRVDETECTINFO_SIZE_MULTIPLIER
	add		bx, BOOTVARS.rgDrvDetectInfo
%else
	lea		ax, [di-RAMVARS_size]					; subtract off base of DPTs
	mov		bl, DPT_DRVDETECTINFO_SIZE_MULTIPLIER	; DRVDETECTINFO are a whole number multiple of DPT size
	mul		bl
	add		ax, BOOTVARS.rgDrvDetectInfo			; add base of DRVDETECTINFO
	xchg	bx, ax
%endif
%endif
%endif
	ret
