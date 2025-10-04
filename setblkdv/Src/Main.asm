; Section containing code

ORG		100h

SECTION .text

SD_8255_Port_A							EQU		0
SD_8255_Port_B							EQU		1
SD_8255_Port_C							EQU		2
SD_8255_Control_Port					EQU		3

Start:
	jmp		Main_Start

;-------------------------------------------------------------------
UseSplashQuit:
	mov		dx, UseSplash
	mov		ah, 09h
	int		021h
	mov 	ax, 04C01h		; Errorlevel 1 in AL
	int		021h

;-------------------------------------------------------------------
Read_Hex:
	xor		dx,dx
.Read_Digit:
	mov		al,[bx]
	cmp		al,'0'
	jc		SHORT .EndDig
	cmp		al,'9'+1
	jc		SHORT .ShiftDigit
	or		al,020h
	cmp		al,'a'
	jc		SHORT .EndDig
	cmp		al,'f'+1
	jnc		SHORT .EndDig
	sub		al,'a'-10
.ShiftDigit:
	and		al,0fh
	shl		dx,1
	shl		dx,1
	shl		dx,1
	shl		dx,1
	or		dl,al
	inc		bx
	jmp		SHORT .Read_Digit
.EndDig:
	ret

Write_Hex:
	push	cx
	mov		cx,2
.Write_Digit:
	mov		al,dl
	shr		al,1
	shr		al,1
	shr		al,1
	shr		al,1
	shl		dl,1
	shl		dl,1
	shl		dl,1
	shl		dl,1
	cmp		al,10
	jc		SHORT .NoCap
	add		al,'A'-'9'-1
.NoCap:
	add		al,'0'
	push	dx
	mov		dl,al
	mov		ah,02h
	int		021h
	pop		dx
	loop	.Write_Digit
	pop		cx
	ret

Skip_Spaces:
	mov		al,[bx]
	cmp		al,' '
	jnz		.EndSpace
	inc		bx
	jmp		SHORT Skip_Spaces
.EndSpace:
	ret

SmallDelay:
	push	cx
	mov		cx,[slowness]
.SmallDelay2:
	loop	.SmallDelay2
	pop		cx
	ret

;-------------------------------------------------------------------
; Port output timeout
; Outputs a byte to the 8255
;	Parameters
;		DX:		Port Number Base
;		AL:		Byte to output
;	Returns
;		CF:		Cleared if outputted, set if timed out
;	Corrupts registers
;		AL
SDOutTimeout:
	push	dx
	push	cx
	xor		cx,cx
	add		dl,SD_8255_Port_A
	out		dx,al
	add		dl,(SD_8255_Port_C-SD_8255_Port_A)
.SDOutTimeout1:
	in		al,dx
	test	al,080h
	jnz		SHORT .SDOutTimeoutRecv
	call	SmallDelay
	loop	.SDOutTimeout1
	stc
.SDOutTimeout2:
	pop		cx
	pop		dx
	ret
.SDOutTimeoutRecv:
	clc
	jmp		SHORT .SDOutTimeout2

;-------------------------------------------------------------------
; Port input timeout
; Outputs a byte to the 8255
;	Parameters
;		DX:		Port Number Base
;	Returns
;		CF:		Cleared if byte received, set if timed out
;		AL:		Byte input (if one is received)
SDInTimeout:
	push	dx
	push	cx
	xor		cx,cx
	add		dl,SD_8255_Port_C
.SDInTimeout1:
	in		al,dx
	test	al,020h
	jnz		SHORT .SDInTimeoutRecv
	call	SmallDelay
	loop	.SDInTimeout1
	stc
	jmp		SHORT SDOutTimeout.SDOutTimeout2
.SDInTimeoutRecv:
	sub		dl,(SD_8255_Port_C-SD_8255_Port_A)
	in		al,dx
	clc
	jmp		SHORT SDOutTimeout.SDOutTimeout2

;-------------------------------------------------------------------
; SDServer_CheckPort
; Checks for a 8255 and responding microcontroller on port DX
;	Parameters:
;		DX:		Port Number Base   
;	Returns:
;		CF:		Cleared if success, set if error
;	Corrupts registers:
;		AX
SDServer_CheckPort:
	and		dl,0FCh
	add		dl,SD_8255_Control_Port
	mov		al,0FAh
	out		dx,al		; initialize 8255 mode 2
	sub		dl,SD_8255_Control_Port

	push	cx
	mov		cx,16			; Try ring up byte sixteen times
.SDServer_CheckPort1:
	mov		al,0eeh
	call	SDOutTimeout		; Output a byte
	jc		SHORT .SDServer_NextIter
	call	SDInTimeout			; Input the response
	jc		SHORT .SDServer_NextIter
	cmp		al,047h				; Return this byte on success
	jnz		SHORT .SDServer_NextIter

	mov		al,0edh
	call	SDOutTimeout		; Output a byte
	jc		SHORT .SDServer_NextIter
	call	SDInTimeout			; Input the response
	jc		SHORT .SDServer_NextIter
	cmp		al,09Ch				; Return this byte on success
	jz		SHORT .SDServer_CheckPort2

.SDServer_NextIter:
	loop	.SDServer_CheckPort1
	pop		cx					; Did not get a response
	stc
	ret
.SDServer_CheckPort2:
	pop		cx
	clc
	ret

ErrorSplash:
	jmp		UseSplashQuit

;--------------------------------------------------------------------
; Program start
;--------------------------------------------------------------------
Main_Start:
	mov		WORD [skipprogram],1

	mov		bx,081h
	call	Skip_Spaces
	mov		al,[bx]
	cmp		al,0dh
	jz		SHORT ErrorSplash
	call	Read_Hex
	mov		[ioPortAddress],dx
	call	Skip_Spaces
	mov		al,[bx]
	cmp		al,0dh
	jz		SHORT .QueryPort
	call	Read_Hex
	mov		[blkDevCard0],dx
	call	Skip_Spaces
	mov		al,[bx]
	cmp		al,0dh
	jz		SHORT ErrorSplash
	call	Read_Hex
	mov		[blkDevCard1],dx
	call	Skip_Spaces
	mov		al,[bx]
	cmp		al,0dh
	jnz		SHORT ErrorSplash

	mov		WORD [skipprogram],0

	mov		dx, BlkDevSplash
	mov		ah, 09h
	int		021h

	mov		dl, [ioPortAddress+1]
	call	Write_Hex
	mov		dl, [ioPortAddress]
	call	Write_Hex

	mov		dx, BlkDevSplash2
	mov		ah, 09h
	int		021h
	mov		dl, [blkDevCard0]
	call	Write_Hex

	mov		dx, BlkDevSplash3
	mov		ah, 09h
	int		021h
	mov		dl, [blkDevCard1]
	call	Write_Hex

.QueryPort:
	mov		WORD [slowness],1
	mov		dx,[ioPortAddress]
	call	SDServer_CheckPort
	jnc		.FoundPort

	mov		dx, PortNotFound
	mov		ah, 09h
	int		021h
	jmp		.ExitToDOS

.FoundPort:
	mov		WORD [slowness],100

	cmp		WORD [skipprogram],0
	jnz		SHORT .SkipWrite
	mov		al,081h			; set volume
	call	SDOutTimeout
	jc		.CmdError
	mov		al,[blkDevCard0]
	call	SDOutTimeout
	jc		.CmdError
	mov		al,[blkDevCard1]
	call	SDOutTimeout
	jc		.CmdError
	call	SDInTimeout
	jc		.CmdError
	cmp		al,081h
	jnz		.CmdError

.SkipWrite:
	mov		al,082h			; get volume to check
	call	SDOutTimeout
	jc		.CmdError
	call	SDInTimeout
	jc		.CmdError
	mov		[blkDevCard0SetVal],al
	call	SDInTimeout
	jc		.CmdError
	mov		[blkDevCard1SetVal],al
	call	SDInTimeout
	jc		.CmdError
	cmp		al,082h
	jnz		.CmdError

	mov		dx, SetToMsg
	mov		ah, 09h
	int		021h
	mov		dl, [blkDevCard0SetVal]
	call	Write_Hex
	mov		dx, BlkDevSplash3
	mov		ah, 09h
	int		021h
	mov		dl, [blkDevCard1SetVal]
	call	Write_Hex

	mov		dx, LFMessage
	mov		ah, 09h
	int		021h

	cmp		WORD [skipprogram],0
	jnz		SHORT .ExitToDOS

	mov		dx, RebootMsg
	mov		ah, 09h
	int		021h

.ExitToDOS:
	; Exit to DOS
	mov 	ax, 04C00h		; Errorlevel 0 in AL
	int		021h

.CmdError:
	mov		dx,CommandErrorMessage
	mov		ah, 09h
	int		021h
	jmp		SHORT	.ExitToDOS

; Section containing initialized data
SECTION .data

BlkDevSplash:			db		13,10,"SETBLKDEV IOAddr=","$"
BlkDevSplash2:			db		", Block Dev Slot 1=","$"
BlkDevSplash3:			db		", Block Dev Slot 2=","$"

SetToMsg:				db		13,10,"Set to Block Dev Slot 1=","$"

UseSplash:				db		13,10,"SETBLKDEV <IO Port Address Hex> <Block Dev Slot 1> <Block Dev Slot 2>",13,10,"$"

PortNotFound:			db		13,10,13,10,"Port Not Responding",13,10,13,10,"$"
CommandErrorMessage:	db		13,10,13,10,"Error executing command",13,10
LFMessage:				db		13,10,'$'
RebootMsg:				db		13,10,"It is advised to reboot immediately",10,10,'$'

; Section containing uninitialized data
SECTION .bss

ioPortAddress:		resb	2
blkDevCard0:		resb	2
blkDevCard1:		resb	2
blkDevCard0SetVal:	resb	2
blkDevCard1SetVal:	resb	2
slowness:			resb	2
skipprogram:		resb	2
