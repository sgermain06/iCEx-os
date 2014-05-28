;*****************************************
;	stdio.asm
;		- Basic input/output routines
;*****************************************

%ifndef __STDIO_ICEXOS_INCLUDES_INC_FILE__
%define __STDIO_ICEXOS_INCLUDES_INC_FILE__

bits 16

;*****************************************
;	Puts16 ()
;		- Prints a null terminated string
;	DS=>SI: 0 terminated string
;*****************************************

Puts16:
		pusha					; Save registers
Puts16.Loop:
		lodsb					; Load next byte from string from SI to AL
		or		al, al 			; Does al = 0?
		jz		Puts16.Done		; Yep, null terminated found, bail out.
		mov		ah, 0x0e		; Nope, print the character
		int 	0x10			; Invoke BIOS
		jmp		Puts16.Loop		; Repeat until null terminator found
Puts16.Done:
		popa					; Restore registers
		ret

GetPressedKey16:
	mov 	ah, 0
	int		16h
	ret

%endif ; __STDIO_ICEXOS_INCLUDES_INC_FILE__