; Project name	:	XTIDE Universal BIOS
; Description	:	Sets SD Device specific parameters to DPT.

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
; SDDPT_Finalize
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		CF:		Set, indicates that this is a floppy disk
;				Clear, indicates that this is a hard disk
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
SDDPT_Finalize:
	mov		ax, [es:si+SDServer_ATA_wPortIO8255]
	mov		[di+DPT_SD.wPortIO8255], ax

	mov		al, [es:si+SDServer_ATA_wDriveFlags]
	eSHL_IM	al, 1
	mov		BYTE [di+DPT.bFlagsHigh], al
	ret
