; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h BIOS functions (Floppy and Hard disk).

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
; Int 13h software interrupt handler.
; This handler changes stack to top of stolen conventional memory
; and then calls the actual INT 13h handler (Int13h_DiskFunctionsHandler).
;
; Int13h_DiskFunctionsHandlerWithStackChange
;	Parameters:
;		AH:		Bios function
;		DL:		Drive number
;		Other:	Depends on function
;	Returns:
;		Depends on function
;--------------------------------------------------------------------
%ifdef RELOCATE_INT13H_STACK
ALIGN JUMP_ALIGN
Int13h_DiskFunctionsHandlerWithStackChange:
	sti			; Enable interrupts
	; TODO: Maybe we need to save Flags (DF) as well?
	push	ds	; Save DS:DI on the original stack
	push	di
	call	RamVars_GetSegmentToDS

	; Store entry registers to RAMVARS
%ifdef USE_386
	pop		DWORD [RAMVARS.dwStackChangeDSDI]
%else
	pop		WORD [RAMVARS.wStackChangeDI]	; Pop DS:DI to the top of what
	pop		WORD [RAMVARS.wStackChangeDS]	; is to become the new stack
%endif
	mov		[RAMVARS.fpInt13hEntryStack], sp
	mov		[RAMVARS.fpInt13hEntryStack+2], ss

	; Load new stack and restore DS and DI
	mov		di, ds		; We can save 2 bytes by using PUSH/POP but it's slower
	mov		ss, di		; No need to wrap with CLI/STI since this is for AT only (286+)
	mov		sp, RAMVARS.rgbTopOfStack-4
	pop		di			; DI before stack change
	pop		ds			; DS before stack change

	; Call INT 13h
	pushf
	push	cs
	call	Int13h_DiskFunctionsHandler

	; Restore stack (we must not corrupt FLAGS!)
%ifdef USE_386
	lss		sp, [ss:RAMVARS.fpInt13hEntryStack]
%else
	cli
	mov		sp, [ss:RAMVARS.fpInt13hEntryStack]
	mov		ss, [ss:RAMVARS.fpInt13hEntryStack+2]
	sti
%endif
	retf	2			; Skip FLAGS from stack
%endif ; RELOCATE_INT13H_STACK


;--------------------------------------------------------------------
; Int 13h software interrupt handler.
; Jumps to specific function defined in AH.
;
; Note to developers: Do not make recursive INT 13h calls!
;
; Int13h_DiskFunctionsHandler
;	Parameters:
;		AH:		Bios function
;		DL:		Drive number
;		Other:	Depends on function
;	Returns:
;		Depends on function
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13h_DiskFunctionsHandler:
%ifndef RELOCATE_INT13H_STACK
	sti									; Enable interrupts
%endif
%ifdef CLD_NEEDED
	cld									; String instructions to increment pointers
%endif
	ePUSHA
	push	ds
	push	es
%ifdef USE_386
;	push	fs
;	push	gs
%endif
	sub		sp, BYTE SIZE_OF_IDEPACK_WITHOUT_INTPACK
	mov		bp, sp
	call	RamVars_GetSegmentToDS

%ifdef MODULE_DRIVEXLATE
	call	DriveXlate_ToOrBack
%endif
	call	FindDPT_ForDriveNumberInDL	; DS:DI points to our DPT, or NULL if not our drive
	jc		SHORT .NotOurDrive			; DPT not found so this is not one of our drives

.OurFunction:
	; Jump to correct BIOS function
	eMOVZX	bx, ah
	eSHL_IM	bx, 1
	cmp		ah, 25h						; Possible EBIOS function?
%ifndef MODULE_EBIOS
	ja		SHORT UnsupportedFunction
	jmp		[cs:bx+g_rgw13hFuncJump]	; Jump to BIOS function

%else ; If using MODULE_EBIOS
	ja		SHORT .JumpToEbiosFunction
	jmp		[cs:bx+g_rgw13hFuncJump]	; Jump to BIOS function

ALIGN JUMP_ALIGN
.JumpToEbiosFunction:
	test	BYTE [di+DPT.bFlagsLow], FLGL_DPT_LBA
	jz		SHORT UnsupportedFunction	; No eINT 13h for CHS drives
	sub		bl, 41h<<1					; BX = Offset to eINT 13h jump table
	jb		SHORT UnsupportedFunction
	cmp		ah, 48h
	ja		SHORT UnsupportedFunction
	jmp		[cs:bx+g_rgwEbiosFunctionJumpTable]
%endif	; MODULE_EBIOS


ALIGN JUMP_ALIGN
.NotOurDrive:
	test	ah, ah
	jz		SHORT .OurFunction			; We handle all function 0h requests (resets)

%ifndef MODULE_SERIAL_FLOPPY
; Without floppy support, we handle only hard disk traffic for function 08h.
	test	dl, dl
	jns		SHORT Int13h_DirectCallToAnotherBios
%endif
; With floppy support, we handle all traffic for function 08h, as we need to wrap both hard disk and floppy drive counts.
	cmp		ah, GET_DRIVE_PARAMETERS
	je		SHORT .OurFunction
	; Fall to Int13h_DirectCallToAnotherBios


;--------------------------------------------------------------------
; UnsupportedFunction
; Int13h_DirectCallToAnotherBios
;	Parameters:
;		DL:		Translated drive number
;		DS:		RAMVARS segment
;		SS:BP:	Ptr to IDEPACK
;		BX, DI:	Corrupted on Int13h_DiskFunctionsHandler
;		Other:	Function specific INT 13h parameters
;	Returns:
;		Depends on function
;	Corrupts registers:
;		Flags
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
UnsupportedFunction:
Int13h_DirectCallToAnotherBios:
%ifdef MODULE_DRIVEXLATE
	; Disable drive number translations in case of recursive INT 13h calls
	mov		[RAMVARS.xlateVars+XLATEVARS.bXlatedDrv], dl
	push	WORD [RAMVARS.xlateVars+XLATEVARS.wFDandHDswap]
	call	DriveXlate_Reset			; No translation
%endif

	push	bp							; Store offset to IDEPACK (SS:SP now points it)

	; Simulate INT by pushing flags and return address
	push	WORD [bp+IDEPACK.intpack+INTPACK.flags]
%if 0
	; No standard INT 13h function uses FLAGS as parameters so no need to restore them
	popf
	pushf
%endif
	push	cs
	ePUSH_T	di, .ReturnFromAnotherBios	; Can not corrupt flags

	; Push old INT 13h handler and restore registers
%ifdef USE_386
	push	DWORD [RAMVARS.fpOldI13h]
%else
	push	WORD [RAMVARS.fpOldI13h+2]
	push	WORD [RAMVARS.fpOldI13h]
%endif
	mov		bx, [bp+IDEPACK.intpack+INTPACK.bx]
	mov		di, [bp+IDEPACK.intpack+INTPACK.di]
	mov		ds, [bp+IDEPACK.intpack+INTPACK.ds]
	mov		bp, [bp+IDEPACK.intpack+INTPACK.bp]
	retf								; "Return" to old INT 13h
.ReturnFromAnotherBios:

%if 0
	; We need to restore our pointer to IDEPACK but we cannot corrupt any register
	push	ax							; Dummy WORD
	cli
	xchg	bp, sp
	mov		[bp], sp					; Replace dummy WORD with returned BP
	mov		sp, [bp+2]					; Load offset to IDEPACK
	xchg	sp, bp
	sti									; We would have set IF anyway when exiting INT 13h
	pop		WORD [bp+IDEPACK.intpack+INTPACK.bp]
%endif
	; Actually we can corrupt BP since no standard INT 13h function uses it as return
	; register. Above code is kept here just in case if there is some non-standard function.
	; POP BP below also belongs to the above code.
	pop		bp							; Clean IDEPACK offset from stack

	; Store remaining returned values to INTPACK
%ifdef USE_386
; We do not use GS or FS at the moment
;	mov		[bp+IDEPACK.intpack+INTPACK.gs], gs
;	mov		[bp+IDEPACK.intpack+INTPACK.fs], fs
%endif
	mov		[bp+IDEPACK.intpack+INTPACK.es], es
	mov		[bp+IDEPACK.intpack+INTPACK.ds], ds
	mov		[bp+IDEPACK.intpack+INTPACK.di], di
	mov		[bp+IDEPACK.intpack+INTPACK.si], si
	mov		[bp+IDEPACK.intpack+INTPACK.bx], bx
%ifdef MODULE_DRIVEXLATE
	mov		[bp+IDEPACK.intpack+INTPACK.dh], dh
%else
	mov		[bp+IDEPACK.intpack+INTPACK.dx], dx
%endif
	mov		[bp+IDEPACK.intpack+INTPACK.cx], cx
	mov		[bp+IDEPACK.intpack+INTPACK.ax], ax
	pushf
	pop		WORD [bp+IDEPACK.intpack+INTPACK.flags]
	call	RamVars_GetSegmentToDS

%ifdef MODULE_DRIVEXLATE
	; Restore drive number translation back to what it was
	pop		WORD [RAMVARS.xlateVars+XLATEVARS.wFDandHDswap]
	cmp		dl, [RAMVARS.xlateVars+XLATEVARS.bXlatedDrv]	; DL is still drive number?
	je		SHORT Int13h_ReturnFromHandlerWithoutStoringErrorCode
	mov		[bp+IDEPACK.intpack+INTPACK.dl], dl	; Something is returned in DL
%endif
	jmp		SHORT Int13h_ReturnFromHandlerWithoutStoringErrorCode
	; We cannot return via Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH!
	; 1. If the other BIOS returns something in DL then that is assumed to be a drive number
	;    (if MODULE_SERIAL_FLOPPY is included) even though it could be anything.
	; 2. Any non-zero value in AH will cause the CF to be set on return from the handler.
	;    This breaks INT 13h/AH=15h for drives handled by the other BIOS.


%ifdef MODULE_SERIAL_FLOPPY
;--------------------------------------------------------------------
; Int13h_ReturnSuccessForFloppy
;
; Some operations, such as format of a floppy disk track, should just
; return success, while for hard disks it should be treated as unsupported.
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13h_ReturnSuccessForFloppy:
	test	dl, dl
	js		SHORT UnsupportedFunction
	xor		ah, ah
	jmp		SHORT Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%endif


;--------------------------------------------------------------------
; Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAHandTransferredSectorsFromCL
;	Parameters:
;		AH:		BIOS Error code
;		CL:		Number of sectors actually transferred
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		All registers are loaded from INTPACK
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAHandTransferredSectorsFromCL:
	mov		[bp+IDEPACK.intpack+INTPACK.al], cl
	; Fall to Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH


;--------------------------------------------------------------------
; Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
; Int13h_ReturnFromHandlerWithoutStoringErrorCode
;	Parameters:
;		AH:		BIOS Error code
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		All registers are loaded from INTPACK
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH:
%ifdef MODULE_SERIAL_FLOPPY
	mov		al, [bp+IDEPACK.intpack+INTPACK.dl]
Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH_ALHasDriveNumber:
	call	Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH_ALHasDriveNumber

%else
	call	Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH
%endif

Int13h_ReturnFromHandlerWithoutStoringErrorCode:
	; Always return with interrupts enabled since there are programs that rely
	; on INT 13h to enable interrupts.
	or		BYTE [bp+IDEPACK.intpack+INTPACK.flags+1], (FLG_FLAGS_IF>>8)

	lea		sp, [bp+SIZE_OF_IDEPACK_WITHOUT_INTPACK]
%ifdef USE_386
;	pop		gs
;	pop		fs
%endif
	pop		es
	pop		ds
	ePOPA
	iret


;--------------------------------------------------------------------
; Int13h_CallPreviousInt13hHandler
;	Parameters:
;		AH:		INT 13h function to call
;		DL:		Drive number
;		DS:		RAMVARS segment
;	Returns:
;		Depends on function
;		NOTE: ES:DI needs to be returned from the previous interrupt
;			  handler, for floppy DPT in function 08h
;	Corrupts registers:
;		None
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int13h_CallPreviousInt13hHandler:
	pushf						; Simulate INT by pushing flags
	call	FAR [RAMVARS.fpOldI13h]
	ret


;--------------------------------------------------------------------
; Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH_ALHasDriveNumber
; Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH
; Int13h_SetErrorCodeToIntpackInSSBPfromAH
;	Parameters:
;		AH:		BIOS error code (00h = no error)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		SS:BP:	Ptr to IDEPACK with error condition set
;	Corrupts registers:
;		DS, BX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
%ifdef MODULE_SERIAL_FLOPPY
Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH_ALHasDriveNumber:
	; Store error code to BDA
	mov		bx, BDA.bHDLastSt
	test	al, al
	js		SHORT .HardDisk
	mov		bl, BDA.bFDRetST & 0xff
.HardDisk:
	LOAD_BDA_SEGMENT_TO	ds, di
	mov		[bx], ah
	; Fall to Int13h_SetErrorCodeToIntpackInSSBPfromAH

%else
Int13h_SetErrorCodeToBdaAndToIntpackInSSBPfromAH:
	; Store error code to BDA
	LOAD_BDA_SEGMENT_TO	ds, di
	mov		[BDA.bHDLastSt], ah
	; Fall to Int13h_SetErrorCodeToIntpackInSSBPfromAH
%endif

	; Store error code to INTPACK
Int13h_SetErrorCodeToIntpackInSSBPfromAH:
	mov		[bp+IDEPACK.intpack+INTPACK.ah], ah
	test	ah, ah
	jnz		SHORT .SetCFtoIntpack
	and		BYTE [bp+IDEPACK.intpack+INTPACK.flags], ~FLG_FLAGS_CF
	ret
.SetCFtoIntpack:
	or		BYTE [bp+IDEPACK.intpack+INTPACK.flags], FLG_FLAGS_CF
	ret


; Jump table for correct BIOS function
ALIGN WORD_ALIGN
g_rgw13hFuncJump:
	dw	AH0h_HandlerForDiskControllerReset			; 00h, Disk Controller Reset (All)
	dw	AH1h_HandlerForReadDiskStatus				; 01h, Read Disk Status (All)
	dw	AH2h_HandlerForReadDiskSectors				; 02h, Read Disk Sectors (All)
	dw	AH3h_HandlerForWriteDiskSectors				; 03h, Write Disk Sectors (All)
	dw	AH4h_HandlerForVerifyDiskSectors			; 04h, Verify Disk Sectors (All)
%ifdef MODULE_SERIAL_FLOPPY
	dw	Int13h_ReturnSuccessForFloppy				; 05h, Format Disk Track (XT, AT, EISA)
%else
	dw	UnsupportedFunction							; 05h, Format Disk Track (XT, AT, EISA)
%endif
	dw	UnsupportedFunction							; 06h, Format Disk Track with Bad Sectors (XT)
	dw	UnsupportedFunction							; 07h, Format Multiple Cylinders (XT)
	dw	AH8h_HandlerForReadDiskDriveParameters		; 08h, Read Disk Drive Parameters (All)
	dw	AH9h_HandlerForInitializeDriveParameters	; 09h, Initialize Drive Parameters (All)
	dw	UnsupportedFunction							; 0Ah, Read Disk Sectors with ECC (XT, AT, EISA)
	dw	UnsupportedFunction							; 0Bh, Write Disk Sectors with ECC (XT, AT, EISA)
	dw	AHCh_HandlerForSeek							; 0Ch, Seek (All)
	dw	AH9h_HandlerForInitializeDriveParameters	; 0Dh, Alternate Disk Reset (All)
	dw	UnsupportedFunction							; 0Eh, Read Sector Buffer (XT, PS/1), ESDI Undocumented Diagnostic (PS/2)
	dw	UnsupportedFunction							; 0Fh, Write Sector Buffer (XT, PS/1), ESDI Undocumented Diagnostic (PS/2)
	dw	AH10h_HandlerForCheckDriveReady				; 10h, Check Drive Ready (All)
	dw	AH11h_HandlerForRecalibrate					; 11h, Recalibrate (All)
	dw	UnsupportedFunction							; 12h, Controller RAM Diagnostic (XT)
	dw	UnsupportedFunction							; 13h, Drive Diagnostic (XT)
	dw	AH10h_HandlerForCheckDriveReady				; 14h, Controller Internal Diagnostic (All)
	dw	AH15h_HandlerForReadDiskDriveSize			; 15h, Read Disk Drive Size (AT+)
	dw	UnsupportedFunction							; 16h,
	dw	UnsupportedFunction							; 17h,
	dw	UnsupportedFunction							; 18h,
	dw	UnsupportedFunction							; 19h, Park Heads (PS/2)
	dw	UnsupportedFunction							; 1Ah, Format ESDI Drive (PS/2)
	dw	UnsupportedFunction							; 1Bh, Get ESDI Manufacturing Header (PS/2)
	dw	UnsupportedFunction							; 1Ch, ESDI Special Functions (PS/2)
	dw	UnsupportedFunction							; 1Dh,
%ifdef MODULE_8BIT_IDE_ADVANCED
	dw	AH1Eh_HandlerForXTCFfeatures				; 1Eh, Lo-tech XT-CF features (XTIDE Universal BIOS)
%else
	dw	UnsupportedFunction							; 1Eh,
%endif
	dw	UnsupportedFunction							; 1Fh,
	dw	UnsupportedFunction							; 20h,
	dw	UnsupportedFunction							; 21h, Read Disk Sectors, Multiple Blocks (PS/1)
	dw	UnsupportedFunction							; 22h, Write Disk Sectors, Multiple Blocks (PS/1)
	dw	AH23h_HandlerForSetControllerFeatures		; 23h, Set Controller Features Register (PS/1)
	dw	AH24h_HandlerForSetMultipleBlocks			; 24h, Set Multiple Blocks (PS/1)
	dw	AH25h_HandlerForGetDriveInformation			; 25h, Get Drive Information (PS/1)

%ifdef MODULE_EBIOS
g_rgwEbiosFunctionJumpTable:
	dw	AH41h_HandlerForCheckIfExtensionsPresent	; 41h, Check if Extensions Present (EBIOS)*
	dw	AH42h_HandlerForExtendedReadSectors			; 42h, Extended Read Sectors (EBIOS)*
	dw	AH43h_HandlerForExtendedWriteSectors		; 43h, Extended Write Sectors (EBIOS)*
	dw	AH44h_HandlerForExtendedVerifySectors		; 44h, Extended Verify Sectors (EBIOS)*
	dw	UnsupportedFunction							; 45h, Lock and Unlock Drive (EBIOS)***
	dw	UnsupportedFunction							; 46h, Eject Media Request (EBIOS)***
	dw	AH47h_HandlerForExtendedSeek				; 47h, Extended Seek (EBIOS)*
	dw	AH48h_HandlerForGetExtendedDriveParameters	; 48h, Get Extended Drive Parameters (EBIOS)*
;	dw	UnsupportedFunction							; 49h, Get Extended Disk Change Status (EBIOS)***
;	dw	UnsupportedFunction							; 4Ah, Initiate Disk Emulation (Bootable CD-ROM)
;	dw	UnsupportedFunction							; 4Bh, Terminate Disk Emulation (Bootable CD-ROM)
;	dw	UnsupportedFunction							; 4Ch, Initiate Disk Emulation and Boot (Bootable CD-ROM)
;	dw	UnsupportedFunction							; 4Dh, Return Boot Catalog (Bootable CD-ROM)
;	dw	UnsupportedFunction							; 4Eh, Set Hardware Configuration (EBIOS)**
;
;   * = Enhanced Drive Access Support (minimum required EBIOS functions)
;  ** = Enhanced Disk Drive (EDD) Support
; *** = Drive Locking and Ejecting Support
%endif
