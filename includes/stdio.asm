;*****************************************
;	stdio.asm
;		- Basic input/output routines
;*****************************************

%ifndef __STDIO_ICEXOS_INCLUDES_INC_FILE__
%define __STDIO_ICEXOS_INCLUDES_INC_FILE__

;*****************************************
;	16 bit Real Mode routines
;*****************************************

bits 16

;*****************************************
;	Puts16 ()
;		- Prints a null terminated string
;	DS=>SI: 0 terminated string
;*****************************************

Puts16:
		pusha							; Save registers
Puts16.Loop:
		lodsb							; Load next byte from string from SI to AL
		or		al, al 					; Does al = 0?
		jz		Puts16.Done				; Yep, null terminated found, bail out.
		mov		ah, 0x0e				; Nope, print the character
		int 	0x10					; Invoke BIOS
		jmp		Puts16.Loop				; Repeat until null terminator found
Puts16.Done:
		popa							; Restore registers
		ret

GetPressedKey16:
	mov 	ah, 0
	int		16h
	ret

;*****************************************
;	32 bit Protected Mode routines
;*****************************************

bits 32

%define			VIDMEM		0xB8000		; Video memory base address
%define			COLS		80			; Number of characters wide
%define			LINES		25			; Number of characters high

%define			CUR_LOC_LO	0x0F		; Cursor Location Low
%define			CUR_LOC_HI	0x0E 		; Cursor Location High

%define 		VGA_INDEX	0x3D4		; VGA Index Register port address
%define			VGA_DATA	0x3D5		; VGA Data Register port address

_CurX			db			0 			; Cursor X position
_CurY			db			0 			; Cursor Y position

_CharAttr		db			0x7			; Default color: light gray on black background

;*****************************************
;	Putch32 ()
;		- Prints a character to screen
;	BL: Character to print
;*****************************************

bits 32

Putch32:
		pusha							; Save registers
		mov		edi, VIDMEM				; Get pointer to video memory

		xor		eax, eax				; Reset eax

		; Get current position
		mov		ecx, COLS * 2 			; Multiply by 2 because Mode 7 uses 2 bytes per character (character and attribute)
		mov		al, byte [_CurY]		; Get Y position
		mul 	ecx						; Multiply Y by COLS
		push 	eax						; Save the Y position to the stack

		mov		al, byte [_CurX]		; Get X position
		mov		cl, 2
		mul 	cl
		pop 	ecx						; Get Y position from stack
		add 	eax, ecx				; Get linear address of _CurX + (_CurY * COLS)

		xor 	ecx, ecx				; Reset ecx
		add 	edi, eax				; Add linear calculation to base video address

		; Watch for new line
		cmp		bl, 0x0A				; Compare character to print with 0x0A (\r)
		je		Putch32.Row				; Yep, go to the next row

		; Print the character
		mov		dl, bl 					; Copy the character from BL to Data register (low)
		mov		dh, _CharAttr			; Put the character attribute in the Data Register (high)
		mov		word [edi], dx			; Move a word from dx at the address edi is pointing to

		; Update next position
		inc 	byte [_CurX]			; Go to next character (x axis)
		cmp 	byte [_CurX], COLS		; Is this the last column?
		je		Putch32.Row 			; Yep, new line needed
		jmp 	Putch32.Done			; Nope, bail out!

	Putch32.Row:
		mov 	byte [_CurX], 0 		; Reset X position of cursor to 0 (left)
		inc 	byte [_CurY]			; Go to the next row

	Putch32.Done:
		popa							; Restore registers
		ret

;*****************************************
;	Puts32 ()
;		- Prints a null terminated string
;	EBX: Address of string to print
;*****************************************

bits 32

Puts32:
		pusha							; Save registers
		push 	ebx 					; Push the string address on stack
		pop 	edi 					; Pop it back into edi

	Puts32.Loop:
		mov 	bl, byte [edi]			; Get next character
		cmp 	bl, 0 					; Is it the end of the string?
		je 		Puts32.Done				; Yep, we're done!

		call 	Putch32					; Call routine to print character in BL.

		inc 	edi 					; Move pointer to next character
		jmp 	Puts32.Loop 			; Loop! 

	Puts32.Done:

		mov 	bh, byte [_CurY]		; Get Y position
		mov 	bl, byte [_CurX] 		; Get X position
		call 	UpdCursor32				; Call UpdCursor routine

		popa							; Restore registers
		ret

;*****************************************
;	UpdCursor32 ()
;		- Updates the hardware cursor position
;	EBX: Address to move the cursor to
;*****************************************

bits 32

UpdCursor32:
		pusha							; Save registers

		xor		eax, eax				; Reset accumulator register (eax)
		mov 	ecx, COLS				; Copy COLS to counter register (ecx)
		mov 	al, bh					; Move Y position into al
		mul 	ecx						; Multiply Y position by COLS
		add 	al, bl 					; Add X position to Y * COLS
		mov 	ebx, eax				; Copy linear address from eax into ebx

		; Set low byte index to VGA register
		mov 	al, CUR_LOC_LO			; Copy function "Cursor Location Low" into accumulator (low)
		mov 	dx, VGA_INDEX			; Copy port address for VGA Index Register into data register
		out 	dx, al 					; Push Cursor Location Low to VGA Index Register port

		mov 	al, bl 					; Copy cursor X position into accumulator (low)
		mov 	dx, VGA_DATA			; Copy port address for VGA Data Register
		out 	dx, al 					; Push cursor X position to VGA Data Register port

		; Set high byte index to VGA register
		xor		eax, eax				; Reset accumulator register (eax)

		mov 	al, CUR_LOC_HI			; Copy function "Cursor Location High" into accumulator (low)
		mov 	dx, VGA_INDEX			; Copy port address for VGA Index Register into data register
		out 	dx, al 					; Push Cursor Location High to VGA Index Register port

		mov 	al, bh					; Copy cursor Y position into accumulator (low)
		mov 	dx, VGA_DATA			; Copy port address for VGA Data Register
		out 	dx, al 					; Push cursor Y position to VGA Data Register port

		popa							; Restore registers
		ret

;*****************************************
;	ClrScr32 ()
;		- Clears the screen
;*****************************************

bits 32

ClrScr32:
		pusha							; Save registers

		cld								; Clear direction flag
		mov 	edi, VIDMEM				; Copy video memory address into edi
		mov 	cx, 2000				; Copy 2000 into counter
		mov 	ah, _CharAttr			; Set character attribute into accumulator (high)
		mov 	al, ' '					; Copy space character into accumulator (low)
		rep 	stosw

		mov 	byte [_CurX], 0 		; Set cursor X position to 0
		mov 	byte [_CurY], 0 		; Set cursor Y position to 0
		
		popa							; Restore registers
		ret
		
;*****************************************
;	GotoXY32 ()
;		- Moves the cursor to X/Y position
;	AL: X position
; 	AH: Y position
;*****************************************

bits 32

GotoXY32:

		pusha							; Save registers
		mov 	byte [_CurX], al 		; Copy accumulator (low) to cursor X
		mov 	byte [_CurY], ah 		; Copy accumulator (high) to cursor Y
		popa							; Restore registers
		ret

%endif ; __STDIO_ICEXOS_INCLUDES_INC_FILE__