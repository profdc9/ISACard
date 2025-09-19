; Project name	:	Assembly Library
; Description	:	Math related macros.
%ifndef MATH_INC
%define MATH_INC

FALSE		EQU		0
TRUE		EQU		1


;--------------------------------------------------------------------
; MIN_U		Unsigned comparison
; MIN_S		Signed comparison
;	Parameters:
;		%1:		Operand 1
;		%2:		Operand 2
;	Returns:
;		%1:		Lesser operand
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro MIN_U 2
	cmp		%1, %2				; Is %1 smaller?
	jb		%%Return			;  If so, return
	mov		%1, %2				; Copy %2 to %1
%%Return:
%endmacro

%macro MIN_S 2
	cmp		%1, %2				; Is %1 smaller?
	jl		%%Return			;  If so, return
	mov		%1, %2				; Copy %2 to %1
%%Return:
%endmacro


;--------------------------------------------------------------------
; MAX_U		Unsigned comparison
; MAX_S		Signed comparison
;	Parameters:
;		%1:		Operand 1
;		%2:		Operand 2
;	Returns:
;		%1:		Greater operand
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro MAX_U 2
	cmp		%1, %2				; Is %1 greater?
	ja		%%Return			;  If so, return
	mov		%1, %2				; Copy %2 to %1
%%Return:
%endmacro

%macro MAX_S 2
	cmp		%1, %2				; Is %1 greater?
	jg		%%Return			;  If so, return
	mov		%1, %2				; Copy %2 to %1
%%Return:
%endmacro


;--------------------------------------------------------------------
; SHL_DXAX
;	Parameters:
;		%1:		Number of bits to shift. Can be (in preferred order) CX, CL or an immediate value.
;	Returns:
;		DX:AX	Shifted value
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
%macro SHL_DXAX 1
%ifdef USE_386
	%ifnidni %1, cx
		; %1 is CL or an immediate
		shld	dx, ax, %1
		shl		ax, %1
	%else
		; %1 is CX
		shld	dx, ax, cl
		shl		ax, cl
	%endif
%else
	%ifidni %1, cl
		; %1 is CL
		xor		ch, ch
	%elifnidni %1, cx
		; %1 is an immediate
		mov		cx, %1
	%endif
ALIGN JUMP_ALIGN
.ShiftNextBit:
	eSHL_IM	ax, 1
	eRCL_IM	dx, 1
	loop	.ShiftNextBit
%endif
%endmacro


;--------------------------------------------------------------------
; SHR_DXAX
;	Parameters:
;		%1:		Number of bits to shift. Can be (in preferred order) CX, CL or an immediate value.
;	Returns:
;		DX:AX	Shifted value
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
%macro SHR_DXAX 1
%ifdef USE_386
	%ifnidni %1, cx
		; %1 is CL or an immediate
		shrd	ax, dx, %1
		shr		dx, %1
	%else
		; %1 is CX
		shrd	ax, dx, cl
		shr		dx, cl
	%endif
%else
	%ifidni %1, cl
		; %1 is CL
		xor		ch, ch
	%elifnidni %1, cx
		; %1 is an immediate
		mov		cx, %1
	%endif
ALIGN JUMP_ALIGN
.ShiftNextBit:
	shr		dx, 1
	rcr		ax, 1
	loop	.ShiftNextBit
%endif
%endmacro


%endif ; MATH_INC
