; Project name	:	XTIDE Universal BIOS
; Description	:	SD Card Server Defines

%ifndef SDSERVER_INC
%define SDSERVER_INC

%include "SD.inc"

;
; Command codes
;
SDServer_Command_Header					EQU		0a0h
SDServer_Command_Write					EQU		(SDServer_Command_Header | 3)
SDServer_Command_Read					EQU		(SDServer_Command_Header | 2)
SDServer_Command_Inquire				EQU		(SDServer_Command_Header | 0)
SDServer_Command_Custom_Read			EQU		(SDServer_Command_Header | 4)
SDServer_Command_Custom_Write			EQU		(SDServer_Command_Header | 5)

SDServer_SubCommand_Image_SendInitiate		EQU		1
SDServer_SubCommand_Image_SendSectors		EQU		2
SDServer_SubCommand_Image_SendComplete		EQU		3

;
; Locations within the ATA 512-byte Inquire structure, taken from the "Vendor specific area",
; for specific information that is returned by the server for an inquire.
;
; NOTE: These are byte offsets (because of the "*2"), which is more convenient here, while
;       the ATA structure defines these in terms of word offsets.
;
SDServer_ATA_wServerVersion			EQU		(157*2)
SDServer_ATA_wDriveFlags			EQU		(158*2)
SDServer_ATA_wPortIO8255			EQU		(159*2)

; Command structure passed to SDServer_SendReceive.  This mirrors IDEPACK in the XTIDE Universal BIOS, 
; since that structure is passed directly without copying values into this structure.
;
struc SDServer_Command
	.wCommandAndCustom:	
	.bCommand				resb	1

	.bCustomCommand:	
	.bDrvAndHead			resb	1	; LBA28 27...24

	.wSectorCountAndLbaLow:
	.bSectorCount			resb	1

	.bCustomData3:		
	.bSectorNumber:
	.bLbaLow				resb	1	; LBA 7...0

	.wCustomData1:		
	.bCustomData1:		
	.wCylinder:
	.wLbaMiddleAndHigh:
	.bLbaMiddle				resb	1	; LBA 15...8

	.bCustomData2:		
	.bLbaHigh				resb	1	; LBA 23...16
endstruc

%endif

