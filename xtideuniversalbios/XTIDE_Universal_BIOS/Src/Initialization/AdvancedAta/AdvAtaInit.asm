; Project name	:	XTIDE Universal BIOS
; Description	:	Common functions for initializing different
;					VLB and PCI IDE Controllers.

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
; AdvAtaInit_DetectControllerForIdeBaseInBX
;	Parameters:
;		BX:		IDE Controller base port
;	Returns:
;		AX:		ID WORD specific for detected controller
;				Zero if no controller detected
;		DX:		Controller base port (not IDE)
;		CF:		Set if controller detected
;				Cleared if no controller
;	Corrupts registers:
;		BX, CX
;--------------------------------------------------------------------
AdvAtaInit_DetectControllerForIdeBaseInBX:
	; Detect if system has PCI bus. If it does, we can skip VLB detection. This is a
	; good thing since detecting Vision QD6580 is dangerous since Intel PIIX4 south bridge
	; mirrors Interrupt Controller registers from Axh to Bxh. This can lead to faulty
	; detection of QD6580 that will eventually crash the system when ports are written.

	; We should save the 32-bit registers but we don't since system BIOS has stored
	; them already and we don't use the 32-bit registers ourselves anywhere at the moment.
	push	bx
	push	di
;	xor		edi, edi		; Some BIOSes require this to be set to zero
	; *FIXME* The above instruction is commented away since RBIL says that this
	; only applies to software looking for the protected-mode entry point.
	mov		ax, PCI_INSTALLATION_CHECK	; May corrupt EAX, EBX, ECX, EDX, EDI
	int		BIOS_TIME_PCI_PNP_INTERRUPT_1Ah
	pop		di
	pop		bx
	test	ah, ah
	jz		SHORT .ThisSystemHasPCIbus

	; Detect VLB controllers
	call	Vision_DetectAndReturnIDinAXandPortInDXifControllerPresent
	jnz		SHORT .NoVisionControllerFound

	call	Vision_DoesIdePortInBXbelongToControllerWithIDinAX
	jz		SHORT .AdvancedControllerFoundForPortBX

.NoVisionControllerFound:
	call	PDC20x30_DetectControllerForIdeBaseInBX
	jnc		SHORT .NoAdvancedControllerForPortBX

.AdvancedControllerFoundForPortBX:
	stc
	ret

.NoAdvancedControllerForPortBX:
.ThisSystemHasPCIbus:
	xor		ax, ax		; Clear ID in AX and CF
	ret


;--------------------------------------------------------------------
; AdvAtaInit_GetControllerMaxPioModeToALandMinPioCycleTimeToBX
;	Parameters:
;		AX:		ID WORD specific for detected controller
;	Returns:
;		AL:		Max supported PIO mode (only if ZF set)
;		AH:		~FLGH_DPT_IORDY if IORDY not supported, -1 otherwise (only if ZF set)
;		BX:		Min PIO cycle time (only if ZF set)
;		ZF:		Set if PIO limit necessary
;				Cleared if no need to limit timings
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AdvAtaInit_GetControllerMaxPioModeToALandMinPioCycleTimeToBX:
	cmp		ah, ID_QD6580_ALTERNATE
%ifdef USE_386
	jae		Vision_GetMaxPioModeToALandMinCycleTimeToBX
	jmp		PDC20x30_GetMaxPioModeToALandMinPioCycleTimeToBX
%else
	jae		SHORT .Vision
	jmp		PDC20x30_GetMaxPioModeToALandMinPioCycleTimeToBX
.Vision:
	jmp		Vision_GetMaxPioModeToALandMinCycleTimeToBX
%endif


;--------------------------------------------------------------------
; AdvAtaInit_InitializeControllerForDPTinDSDI
;	Parameters:
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;	Returns:
;		AH:		Int 13h return status
;		CF:		Cleared if success or no controller to initialize
;				Set if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
AdvAtaInit_InitializeControllerForDPTinDSDI:
	; Call Controller Specific initialization function
	mov		ax, [di+DPT_ADVANCED_ATA.wControllerID]
	test	ax, ax
	jz		SHORT .NoAdvancedController	; Return with CF cleared

	cmp		ah, ID_QD6580_ALTERNATE
	jae		SHORT .Vision
	jmp		PDC20x30_InitializeForDPTinDSDI

.Vision:
	push	bp
	push	si

	call	AdvAtaInit_LoadMasterDPTtoDSSIifSlaveInDSDI
	call	Vision_InitializeWithIDinAH
	xor		ax, ax						; Success

	pop		si
	pop		bp

.NoAdvancedController:
	ret


;--------------------------------------------------------------------
; AdvAtaInit_LoadMasterDPTtoDSSIifSlaveInDSDI
;	Parameters:
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;	Returns:
;		SI:		Offset to Master DPT if Slave Drive present
;				Zero if Slave Drive not present
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
AdvAtaInit_LoadMasterDPTtoDSSIifSlaveInDSDI:
	; Must be Slave Drive if previous DPT has same IDEVARS offset
	lea		si, [di-LARGEST_DPT_SIZE]	; DS:SI points to previous DPT
	mov		al, [di+DPT.bIdevarsOffset]
	cmp		al, [si+DPT.bIdevarsOffset]
	je		SHORT .MasterAndSlaveDrivePresent

	; We only have single drive so zero SI
	xor		si, si
.MasterAndSlaveDrivePresent:
	ret


;--------------------------------------------------------------------
; AdvAtaInit_SelectSlowestCommonPioTimingsToBXandCXfromDSSIandDSDI
;	Parameters:
;		DS:DI:	Ptr to DPT for Single or Slave Drive
;		SI:		Offset to Master DPT if Slave Drive present
;				Zero if Slave Drive not present
;	Returns:
;		BX:		Best common PIO mode
;		CX:		Slowest common PIO Cycle Time in nanosecs
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
AdvAtaInit_SelectSlowestCommonPioTimingsToBXandCXfromDSSIandDSDI:
	eMOVZX	bx, [di+DPT_ADVANCED_ATA.bPioMode]
	mov		cx, [di+DPT_ADVANCED_ATA.wMinPioCycleTime]
	test	si, si
	jz		SHORT .PioTimingsLoadedToBXandCX
	MIN_U	bl, [si+DPT_ADVANCED_ATA.bPioMode]
	MAX_U	cx, [si+DPT_ADVANCED_ATA.wMinPioCycleTime]
.PioTimingsLoadedToBXandCX:
	ret
