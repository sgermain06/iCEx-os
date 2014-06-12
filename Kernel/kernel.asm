;*****************************************
;	kernel.asm
;		- iCEx OS Kernel
;*****************************************

org		0x10000					; Kernel starts at 1 MB

bits	32						; 32 bit code

jmp		Kernel					; jump to entry point

%include "includes/stdio.asm"

msg 	db	0x0A, 0x0A, "                                - iCEx OS v0.1 -"
    	db  0x0A, 0x0A, "                            32 Bit Kernel Executing", 0x0A, 0

Kernel:

		mov		ax, 0x10		; set data segments to data selector (0x10)
		mov		ds, ax
		mov		ss, ax
		mov		es, ax
		mov		esp, 0x90000	; stack begins from 90000h

		call	ClrScr32
		mov		ebx, msg
		call	Puts32

		cli
		hlt
		