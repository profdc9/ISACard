; Project name	:	BIOS Drive Information Tool
; Description	:	Strings used in this program.

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

; Section containing initialized data
SECTION .data

g_szProgramName:	db	"BIOS Drive Information Tool v1.0.3",CR,LF
					db	"(C) 2012-2021 by XTIDE Universal BIOS Team",CR,LF
					db	"Released under GNU GPL v2",CR,LF
					db	"http://xtideuniversalbios.org/",CR,LF,NULL

g_szPressAnyKey:	db	CR,LF,"Press any key to display next drive.",CR,LF,NULL

g_szHeaderDrive:	db	CR,LF,"-= Drive %2x =-",CR,LF,NULL

g_szAtaInfoHeader:	db	"ATA-information from AH=25h...",CR,LF,NULL
g_szFormatDrvName:	db	" Name         : %s",CR,LF,NULL
g_szChsAndMode:		db	"%s, Mode: %s",CR,LF,NULL
g_szNormal:			db	"NORMAL",NULL
g_szLarge:			db	"LARGE ",NULL
g_szLBA:			db	"LBA   ",NULL
g_szFormatCHS:		db	" Cylinders    : %5u, Heads: %3u, Sectors: %2u",NULL
g_szWillBeModified:	db	"Will be modified to:",CR,LF,NULL		
g_szChsSectors:		db	" CHS   sectors: ",NULL
g_szLBA28:			db	" LBA28 sectors: ",NULL
g_szLBA48:			db	" LBA48 sectors: ",NULL
g_szBlockMode:		db	" Block mode   : Set to %u from max %u sectors",CR,LF,NULL
g_szPIO:			db	" PIO mode     : Max %u, Min cycle times: %u ns, with IORDY %d ns",CR,LF,NULL
g_szXUB:			db	"XTIDE Universal BIOS %s generates following L-CHS...",CR,LF,NULL
g_szXUBversion:		db	ROM_VERSION_STRING	; This one is NULL terminated

g_szOldInfoHeader:	db	"Old INT 13h information from AH=08h and AH=15h...",CR,LF,NULL
					;	Cylinders
g_szSectors:		db	" Total sectors: ",NULL


g_szNewInfoHeader:	db	"EBIOS information from AH=48h...",CR,LF,NULL
g_szNewExtensions:	db	" Version      : %2-x, Interface bitmap: %2-x",CR,LF,NULL
					; Cylinders
					; Total sectors
g_szNewSectorSize:	db	" Sector size  : %u",CR,LF,NULL

g_szBiosError:		db	" BIOS returned error code %x",CR,LF,NULL
g_szDashForZero:	db	"- ",NULL		; Required by Assembly Library

g_szNewline:		db	CR,LF,NULL
