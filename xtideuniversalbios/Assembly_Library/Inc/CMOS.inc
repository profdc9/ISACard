; Project name	:	Assembly Library
; Description	:	Defines for accessing CMOS.

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2018 by XTIDE Universal BIOS Team.
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

%ifndef CMOS_INC
%define CMOS_INC

; CMOS Ports
; Note that a data register read or write must follow every write to the address register
CMOS_INDEX_REGISTER				EQU		70h		; Is this write only?
CMOS_DATA_REGISTER				EQU		71h

FLG_CMOS_INDEX_NMI_DISABLE		EQU		(1<<7)	; CMOS Index Register bit 7 is NMI disable/enable bit


; Almost all of the CMOS locations are vendor specific and
; there is very little standardization.
HARD_DISK_TYPES					EQU		12h		; Windows 9x reads this to check if IDE drives
												; are present so it should be safe to access this.
												; Bits 0...3 Hard Disk 1 type (Primary Slave)
												; Bits 4...7 Hard Disk 0 type (Primary Master)
												; Fh = Types 16...47 (defined elsewhere in CMOS)
CHECKSUM_OF_BYTES_10hTo2Dh_LOW	EQU		2Fh		; Most BIOSes store checksum of bytes 10h to 2Dh here
CHECKSUM_OF_BYTES_10hTo2Dh_HIGH	EQU		2Eh		; High byte of the checksum


%endif ; CMOS_INC
