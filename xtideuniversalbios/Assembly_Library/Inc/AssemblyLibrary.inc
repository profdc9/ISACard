; Project name	:	Assembly Library
; Description	:	Common defines for all library functions.
%ifndef ASSEMBLY_LIBRARY_INC
%define ASSEMBLY_LIBRARY_INC

; Include .inc files
%include "Emulate.inc"			; Must be included first!
%include "Macros.inc"
%include "BiosData.inc"
%include "BiosFunctions.inc"
%include "CgaSnow.inc"
%include "CMOS.inc"
%include "Debug.inc"
%include "Delay.inc"
%include "DosFunctions.inc"
%include "File.inc"
%include "Math.inc"
%include "Registers.inc"
%include "SystemTimer.inc"


; Library dependencies
%ifdef INCLUDE_MENU_LIBRARY OR INCLUDE_MENU_DIALOGS	; To prevent warnings with Nasm 2.13.xx
	%include "Menu.inc"
	%include "MenuEvents.inc"
	%define INCLUDE_KEYBOARD_LIBRARY
	%define INCLUDE_TIME_LIBRARY

	%ifdef INCLUDE_MENU_DIALOGS
		%include "Dialog.inc"
		%define INCLUDE_MENU_LIBRARY
		%define INCLUDE_FILE_LIBRARY
	%endif
%endif

%ifdef INCLUDE_KEYBOARD_LIBRARY
	%define INCLUDE_DISPLAY_LIBRARY
	%define INCLUDE_UTIL_LIBRARY
%endif

%ifdef INCLUDE_DISPLAY_LIBRARY
	%include "Display.inc"
	%define INCLUDE_STRING_LIBRARY
%endif

%ifdef INCLUDE_STRING_LIBRARY
	%define INCLUDE_UTIL_LIBRARY
%endif

%ifdef INCLUDE_FILE_LIBRARY
	%define INCLUDE_UTIL_LIBRARY
%endif


%endif ; ASSEMBLY_LIBRARY_INC
