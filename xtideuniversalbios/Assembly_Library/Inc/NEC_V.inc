; Project name	:	Assembly Library
; Description	:	Macros for using NEC V20/V30 specific instructions.

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

%ifndef NEC_V_INC
%define NEC_V_INC

	regAL		equ		000b
	regCL		equ		001b
	regDL		equ		010b
	regBL		equ		011b
	regAH		equ		100b
	regCH		equ		101b
	regDH		equ		110b
	regBH		equ		111b

	regAX		equ		regAL
	regCX		equ		regCL
	regDX		equ		regDL
	regBX		equ		regBL
	regSP		equ		regAH
	regBP		equ		regCH
	regSI		equ		regDH
	regDI		equ		regBH


;--------------------------------------------------------------------
; The REPC string instruction prefix available on NEC V20/V30 CPUs.
;
; Repeats the following string instruction (CMPS or SCAS)
; while CF=1 and CX<>0.
;
; eREPC
;	Parameters:
;		%1:		String instruction (optional for this macro)
;		CX:		String length in BYTEs or WORDs
;		xS:SI:	Pointer to source string. Default segment is DS but can be overridden
;		ES:DI:	Pointer to destination string
;	Returns:
;		CF/CX:	Depends on the result from the string instruction.
;				If CF clear, then CX contains the remaining number of
;				BYTEs or WORDs in the string. If CF set, then CX=0.
;		SI/DI:	Updated depending on the string instruction used and
;				state of the direction flag.
;	Corrupts registers:
;		The string instruction corrupts FLAGS. The prefix corrupts nothing.
;--------------------------------------------------------------------
%macro eREPC 0-1.nolist
	db	65h
	%ifnempty %1
		%1
	%endif
%endmacro


;--------------------------------------------------------------------
; The REPNC string instruction prefix available on NEC V20/V30 CPUs.
;
; Repeats the following string instruction (CMPS or SCAS)
; while CF=0 and CX<>0.
;
; eREPNC
;	Parameters:
;		%1:		String instruction (optional for this macro)
;		CX:		String length in BYTEs or WORDs
;		xS:SI:	Pointer to source string. Default segment is DS but can be overridden
;		ES:DI:	Pointer to destination string
;	Returns:
;		CF/CX:	Depends on the result from the string instruction.
;				If CF set, then CX contains the remaining number of
;				BYTEs or WORDs in the string. If CF clear, then CX=0.
;		SI/DI:	Updated depending on the string instruction used and
;				state of the direction flag.
;	Corrupts registers:
;		The string instruction corrupts FLAGS. The prefix corrupts nothing.
;--------------------------------------------------------------------
%macro eREPNC 0-1.nolist
	db	64h
	%ifnempty %1
		%1
	%endif
%endmacro


;--------------------------------------------------------------------
; The CLR1 instruction available on NEC V20/V30 CPUs.
;
; Clears bit indexed by Source in Destination.
;
; eCLR1
;	Parameters:
;		%1:		Destination (register or memory location)
;		%2:		Source (CL or immediate value)
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing (not even FLAGS)
;--------------------------------------------------------------------
%macro eCLR1 2.nolist
	%assign w 0
	%assign i 0
	%ifnidni %2, cl
		%assign i (1 << 3)
	%endif
	FSIS	], %1
	%if strpos
		FSIS	BYTE, %1
		%ifn strpos = 1
			FSIS	WORD, %1
			%if strpos = 1
				%assign w 1
			%elif i
				%if %2 > 7
					%assign w 1
				%endif
			%else
				%error "Memory operand needs a size specifier!"
			%endif
		%endif
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eCLR1 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, ax
			%assign w 1
			%assign rm regAX
		%elifidni %1, bx
			%assign w 1
			%assign rm regBX
		%elifidni %1, cx
			%assign w 1
			%assign rm regCX
		%elifidni %1, dx
			%assign w 1
			%assign rm regDX
		%elifidni %1, bp
			%assign w 1
			%assign rm regBP
		%elifidni %1, sp
			%assign w 1
			%assign rm regSP
		%elifidni %1, si
			%assign w 1
			%assign rm regSI
		%elifidni %1, di
			%assign w 1
			%assign rm regDI
		%elifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eCLR1! (%1)
		%endif
	%endif
	db	0Fh, 12h | i | w, m | rm
	%if i
		db	%2
		%if w
			%if %2 > 15
				%warning Possibly invalid parameter passed to eCLR1! (%2 > 15)
			%endif
		%else
			%if %2 > 7
				%warning Possibly invalid parameter passed to eCLR1! (%2 > 7)
			%endif
		%endif
	%endif
%endmacro


;--------------------------------------------------------------------
; The SET1 instruction available on NEC V20/V30 CPUs.
;
; Sets bit indexed by Source in Destination.
;
; eSET1
;	Parameters:
;		%1:		Destination (register or memory location)
;		%2:		Source (CL or immediate value)
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing (not even FLAGS)
;--------------------------------------------------------------------
%macro eSET1 2.nolist
	%assign w 0
	%assign i 0
	%ifnidni %2, cl
		%assign i (1 << 3)
	%endif
	FSIS	], %1
	%if strpos
		FSIS	BYTE, %1
		%ifn strpos = 1
			FSIS	WORD, %1
			%if strpos = 1
				%assign w 1
			%elif i
				%if %2 > 7
					%assign w 1
				%endif
			%else
				%error "Memory operand needs a size specifier!"
			%endif
		%endif
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eSET1 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, ax
			%assign w 1
			%assign rm regAX
		%elifidni %1, bx
			%assign w 1
			%assign rm regBX
		%elifidni %1, cx
			%assign w 1
			%assign rm regCX
		%elifidni %1, dx
			%assign w 1
			%assign rm regDX
		%elifidni %1, bp
			%assign w 1
			%assign rm regBP
		%elifidni %1, sp
			%assign w 1
			%assign rm regSP
		%elifidni %1, si
			%assign w 1
			%assign rm regSI
		%elifidni %1, di
			%assign w 1
			%assign rm regDI
		%elifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eSET1! (%1)
		%endif
	%endif
	db	0Fh, 14h | i | w, m | rm
	%if i
		db	%2
		%if w
			%if %2 > 15
				%warning Possibly invalid parameter passed to eSET1! (%2 > 15)
			%endif
		%else
			%if %2 > 7
				%warning Possibly invalid parameter passed to eSET1! (%2 > 7)
			%endif
		%endif
	%endif
%endmacro


;--------------------------------------------------------------------
; The NOT1 instruction available on NEC V20/V30 CPUs.
;
; Inverts bit indexed by Source in Destination.
;
; eNOT1
;	Parameters:
;		%1:		Destination (register or memory location)
;		%2:		Source (CL or immediate value)
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing (not even FLAGS)
;--------------------------------------------------------------------
%macro eNOT1 2.nolist
	%assign w 0
	%assign i 0
	%ifnidni %2, cl
		%assign i (1 << 3)
	%endif
	FSIS	], %1
	%if strpos
		FSIS	BYTE, %1
		%ifn strpos = 1
			FSIS	WORD, %1
			%if strpos = 1
				%assign w 1
			%elif i
				%if %2 > 7
					%assign w 1
				%endif
			%else
				%error "Memory operand needs a size specifier!"
			%endif
		%endif
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eNOT1 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, ax
			%assign w 1
			%assign rm regAX
		%elifidni %1, bx
			%assign w 1
			%assign rm regBX
		%elifidni %1, cx
			%assign w 1
			%assign rm regCX
		%elifidni %1, dx
			%assign w 1
			%assign rm regDX
		%elifidni %1, bp
			%assign w 1
			%assign rm regBP
		%elifidni %1, sp
			%assign w 1
			%assign rm regSP
		%elifidni %1, si
			%assign w 1
			%assign rm regSI
		%elifidni %1, di
			%assign w 1
			%assign rm regDI
		%elifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eNOT1! (%1)
		%endif
	%endif
	db	0Fh, 16h | i | w, m | rm
	%if i
		db	%2
		%if w
			%if %2 > 15
				%warning Possibly invalid parameter passed to eNOT1! (%2 > 15)
			%endif
		%else
			%if %2 > 7
				%warning Possibly invalid parameter passed to eNOT1! (%2 > 7)
			%endif
		%endif
	%endif
%endmacro


;--------------------------------------------------------------------
; The TEST1 instruction available on NEC V20/V30 CPUs.
;
; Tests bit indexed by Source in Destination.
;
; eTEST1
;	Parameters:
;		%1:		Destination (register or memory location)
;		%2:		Source (CL or immediate value)
;	Returns:
;		ZF:		Set if tested bit is zero
;				Cleared if tested bit is not zero
;		CF:		Cleared
;		OF:		Cleared
;	Corrupts registers:
;		All other FLAGS
;--------------------------------------------------------------------
%macro eTEST1 2.nolist
	%assign w 0
	%assign i 0
	%ifnidni %2, cl
		%assign i (1 << 3)
	%endif
	FSIS	], %1
	%if strpos
		FSIS	BYTE, %1
		%ifn strpos = 1
			FSIS	WORD, %1
			%if strpos = 1
				%assign w 1
			%elif i
				%if %2 > 7
					%assign w 1
				%endif
			%else
				%error "Memory operand needs a size specifier!"
			%endif
		%endif
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eTEST1 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, ax
			%assign w 1
			%assign rm regAX
		%elifidni %1, bx
			%assign w 1
			%assign rm regBX
		%elifidni %1, cx
			%assign w 1
			%assign rm regCX
		%elifidni %1, dx
			%assign w 1
			%assign rm regDX
		%elifidni %1, bp
			%assign w 1
			%assign rm regBP
		%elifidni %1, sp
			%assign w 1
			%assign rm regSP
		%elifidni %1, si
			%assign w 1
			%assign rm regSI
		%elifidni %1, di
			%assign w 1
			%assign rm regDI
		%elifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eTEST1! (%1)
		%endif
	%endif
	db	0Fh, 10h | i | w, m | rm
	%if i
		db	%2
		%if w
			%if %2 > 15
				%warning Possibly invalid parameter passed to eTEST1! (%2 > 15)
			%endif
		%else
			%if %2 > 7
				%warning Possibly invalid parameter passed to eTEST1! (%2 > 7)
			%endif
		%endif
	%endif
%endmacro


;--------------------------------------------------------------------
; The EXT instruction available on NEC V20/V30 CPUs.
;
; Loads AX with a zero-extended bitfield, from [xS:SI] plus an additional
; bit offset specified in Destination, with Source+1 number of bits.
; Both Source and Destination must be at most 15.
;
; eEXT
;	Parameters:
;		xS:SI:	Pointer to bitfield. Default segment is DS but can be overridden
;		%1:		Destination (8-bit register)
;		%2:		Source (8-bit register or immediate value)
;	Returns:
;		AX:		Extracted bitfield
;		%1:		(%1 + %2 + 1) MOD 16
;		SI:		SI + 2 (but only if %1 wrapped around)
;	Corrupts registers:
;		FLAGS
;--------------------------------------------------------------------
%macro eEXT 2.nolist
	%assign m (11b << 6)
	%assign i 0
	%assign r 0
	%ifidni %2, al
		%assign r (regAL << 3)
	%elifidni %2, ah
		%assign r (regAH << 3)
	%elifidni %2, bl
		%assign r (regBL << 3)
	%elifidni %2, bh
		%assign r (regBH << 3)
	%elifidni %2, cl
		%assign r (regCL << 3)
	%elifidni %2, ch
		%assign r (regCH << 3)
	%elifidni %2, dl
		%assign r (regDL << 3)
	%elifidni %2, dh
		%assign r (regDH << 3)
	%else
		%if %2 > 15
			%error Invalid parameter passed to eEXT! (%2 > 15)
		%endif
		%assign i (1 << 3)
	%endif
	%ifidni %1, al
		%assign rm regAL
	%elifidni %1, ah
		%assign rm regAH
	%elifidni %1, bl
		%assign rm regBL
	%elifidni %1, bh
		%assign rm regBH
	%elifidni %1, cl
		%assign rm regCL
	%elifidni %1, ch
		%assign rm regCH
	%elifidni %1, dl
		%assign rm regDL
	%elifidni %1, dh
		%assign rm regDH
	%else
		%error Invalid parameter passed to eEXT! (%1)
	%endif
	db	0Fh, 33h | i, m | r | rm
	%if i
		db	%2
	%endif
%endmacro


;--------------------------------------------------------------------
; The INS instruction available on NEC V20/V30 CPUs.
;
; Stores the Source+1 least significant bits in AX to [xS:DI]
; plus an additional bit offset specified in Destination.
; Both Source and Destination must be at most 15.
;
; eINS
;	Parameters:
;		xS:DI:	Pointer to bitfield. Default segment is ES but can be overridden
;		%1:		Destination (8-bit register)
;		%2:		Source (8-bit register or immediate value)
;	Returns:
;		%1:		(%1 + %2 + 1) MOD 16
;		DI:		DI + 2 (but only if %1 wrapped around)
;	Corrupts registers:
;		FLAGS
;--------------------------------------------------------------------
%macro eINS 2.nolist
	%assign m (11b << 6)
	%assign i 0
	%assign r 0
	%ifidni %2, al
		%assign r (regAL << 3)
	%elifidni %2, ah
		%assign r (regAH << 3)
	%elifidni %2, bl
		%assign r (regBL << 3)
	%elifidni %2, bh
		%assign r (regBH << 3)
	%elifidni %2, cl
		%assign r (regCL << 3)
	%elifidni %2, ch
		%assign r (regCH << 3)
	%elifidni %2, dl
		%assign r (regDL << 3)
	%elifidni %2, dh
		%assign r (regDH << 3)
	%else
		%if %2 > 15
			%error Invalid parameter passed to eINS! (%2 > 15)
		%endif
		%assign i (1 << 3)
	%endif
	%ifidni %1, al
		%assign rm regAL
	%elifidni %1, ah
		%assign rm regAH
	%elifidni %1, bl
		%assign rm regBL
	%elifidni %1, bh
		%assign rm regBH
	%elifidni %1, cl
		%assign rm regCL
	%elifidni %1, ch
		%assign rm regCH
	%elifidni %1, dl
		%assign rm regDL
	%elifidni %1, dh
		%assign rm regDH
	%else
		%error Invalid parameter passed to eINS! (%1)
	%endif
	db	0Fh, 31h | i, m | r | rm
	%if i
		db	%2
	%endif
%endmacro


;--------------------------------------------------------------------
; The ROL4 instruction available on NEC V20/V30 CPUs.
;
; Rotates the destination four bits to the left via the low nibble of AL.
;
; eROL4
;	Parameters:
;		%1:		8-bit destination (register or memory location)
;	Returns:
;		AL:		The high nibble of %1 in the low nibble of AL
;		%1:		The low nibble of %1 in the high nibble of %1
;				The low nibble of AL in the low nibble of %1
;	Corrupts registers:
;		Nothing (not even FLAGS)
;--------------------------------------------------------------------
%macro eROL4 1.nolist
	FSIS	], %1
	%if strpos
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eROL4 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eROL4! (%1)
		%endif
	%endif
	db	0Fh, 28h, m | rm
%endmacro


;--------------------------------------------------------------------
; The ROR4 instruction available on NEC V20/V30 CPUs.
;
; Rotates the destination four bits to the right via the low nibble of AL.
;
; eROR4
;	Parameters:
;		%1:		8-bit destination (register or memory location)
;	Returns:
;		AL:		The low nibble of %1 in the low nibble of AL
;		%1:		The high nibble of %1 in the low nibble of %1
;				The low nibble of AL in the high nibble of %1
;	Corrupts registers:
;		Nothing (not even FLAGS)
;--------------------------------------------------------------------
%macro eROR4 1.nolist
	FSIS	], %1
	%if strpos
		%assign m (00b << 6)
		FSIS	[bx+si], %1
		%if strpos
			%assign rm 000b
		%else
			FSIS	[bx+di], %1
			%if strpos
				%assign rm 001b
			%else
				FSIS	[bp+si], %1
				%if strpos
					%assign rm 010b
				%else
					FSIS	[bp+di], %1
					%if strpos
						%assign rm 011b
					%else
						FSIS	[si], %1
						%if strpos
							%assign rm 100b
						%else
							FSIS	[di], %1
							%if strpos
								%assign rm 101b
							%else
								FSIS	[bx], %1
								%if strpos
									%assign rm 111b
								%else
									%error "Memory operands are not (yet) fully supported by the eROR4 macro!"
								%endif
							%endif
						%endif
					%endif
				%endif
			%endif
		%endif
	%else
		%assign m (11b << 6)
		%ifidni %1, al
			%assign rm regAL
		%elifidni %1, ah
			%assign rm regAH
		%elifidni %1, bl
			%assign rm regBL
		%elifidni %1, bh
			%assign rm regBH
		%elifidni %1, cl
			%assign rm regCL
		%elifidni %1, ch
			%assign rm regCH
		%elifidni %1, dl
			%assign rm regDL
		%elifidni %1, dh
			%assign rm regDH
		%else
			%error Invalid parameter passed to eROR4! (%1)
		%endif
	%endif
	db	0Fh, 2Ah, m | rm
%endmacro


;--------------------------------------------------------------------
; The ADD4S instruction available on NEC V20/V30 CPUs.
;
; Adds packed BCD string at xS:SI to packed BCD string at ES:DI
; with (preferably even) nibble count in CL.
;
; eADD4S
;	Parameters:
;		CL:		Number of packed BCD digits (nibbles in string) ranging
;				from 1 to 254. Should be an even number or the CPU will
;				treat it as CL+1.
;		xS:SI:	Pointer to source string. Default segment is DS but
;				can be overridden.
;		ES:DI:	Pointer to destination string.
;	Returns:
;		ES:DI:	Pointer to destination string.
;		CF/ZF:	Set according to result.
;	Corrupts registers:
;		All other FLAGS
;--------------------------------------------------------------------
%macro eADD4S 0.nolist
	db	0Fh, 20h
%endmacro


;--------------------------------------------------------------------
; The SUB4S instruction available on NEC V20/V30 CPUs.
;
; Subtracts packed BCD string at xS:SI from packed BCD string at ES:DI
; with (preferably even) nibble count in CL.
;
; eSUB4S
;	Parameters:
;		CL:		Number of packed BCD digits (nibbles in string) ranging
;				from 1 to 254. Should be an even number or the CPU will
;				treat it as CL+1.
;		xS:SI:	Pointer to source string. Default segment is DS but
;				can be overridden.
;		ES:DI:	Pointer to destination string.
;	Returns:
;		ES:DI:	Pointer to destination string.
;		CF/ZF:	Set according to result.
;	Corrupts registers:
;		All other FLAGS
;--------------------------------------------------------------------
%macro eSUB4S 0.nolist
	db	0Fh, 22h
%endmacro


;--------------------------------------------------------------------
; The CMP4S instruction available on NEC V20/V30 CPUs.
;
; Compares packed BCD string at xS:SI with packed BCD string at ES:DI
; with (preferably even) nibble count in CL.
;
; eCMP4S
;	Parameters:
;		CL:		Number of packed BCD digits (nibbles in string) ranging
;				from 1 to 254. Should be an even number or the CPU will
;				treat it as CL+1.
;		xS:SI:	Pointer to source string. Default segment is DS but
;				can be overridden.
;		ES:DI:	Pointer to destination string.
;	Returns:
;		CF/ZF:	Set according to result.
;	Corrupts registers:
;		All other FLAGS
;--------------------------------------------------------------------
%macro eCMP4S 0.nolist
	db	0Fh, 26h
%endmacro


;--------------------------------------------------------------------
; The BRKEM instruction available on NEC V20/V30 CPUs.
;
; Starts 8080 CPU emulation mode by invoking the software interrupt in %1.
;
; eBRKEM
;	Parameters:
;		%1:		8-bit interrupt vector number
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro eBRKEM 1.nolist
	%if %1 > 255
		%error Invalid parameter passed to eBRKEM! (%1 > 255)
	%else
		db	0Fh, 0FFh, %1
	%endif
%endmacro


;--------------------------------------------------------------------
; The CALLN instruction available on NEC V20/V30 CPUs.
;
; This instruction is used while in 8080 CPU emulation mode to invoke
; the native (x86) software interrupt in %1.
;
; eCALLN
;	Parameters:
;		%1:		8-bit interrupt vector number
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro eCALLN 1.nolist
	%if %1 > 255
		%error Invalid parameter passed to eCALLN! (%1 > 255)
	%else
		db	0EDh, 0EDh, %1
	%endif
%endmacro


;--------------------------------------------------------------------
; The RETEM instruction available on NEC V20/V30 CPUs.
;
; Ends 8080 CPU emulation mode by returning from the software interrupt
; invoked by BRKEM.
;
; eRETEM
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro eRETEM 0.nolist
	db	0EDh, 0FDh
%endmacro


%endif ; NEC_V_INC

