;*****************************************
;	gdt.asm
;		- GDT routines
;*****************************************

%ifndef __A20_ICEXOS_INCLUDES_INC_FILE__
%define __A20_ICEXOS_INCLUDES_INC_FILE__

	bits 16

;*****************************************
;	EnableA20_Kbd ()
;		- Enables Gate A20 through the keyboard command 0xDD
;*****************************************
EnableA20_Kbd:

	cli										; Clear interrupts
	push 	ax 								; Push AX onto stack (save register)

	mov 	al, 0xdd						; Copy command 0xDD into al (enable A20)
	out 	0x64, al 						; Send command to port 0x64 (keyboard status port)
	call 	wait_input						; Wait for input buffer to be empty

	pop 	ax 								; Pop AX from stack (restore register)
	sti 									; Enable interrupts
	ret 									; Return!

;*****************************************
;	EnableA20_Kbd_out ()
;		- Enables Gate A20 through the keyboard's output buffer
;*****************************************
EnableA20_Kbd_out:

	cli										; Clear interrupts
	pusha									; Save registers

	call	wait_input						; Wait for input buffer to be empty
	mov 	al, 0xad						; Copy command 0xAD into al (disable keyboard)
	out 	0x64, al 						; Send command to port 0x64 (keyboard status port)
	call 	wait_input						; Wait for input buffer to be empty

	mov		al, 0xd0						; Copy command 0xD0 into al (read output buffer)
	out		0x64, al						; Send command to port 0x64 (keyboard status port)
	call	wait_output						; Wait for output buffer to be empty

	in 		al, 0x60						; Read from port 0x60 (keyboard data port)
	push	eax								; Move value of the stack
	call	wait_input						; Wait for input buffer to be empty

	mov 	al, 0xd1						; Copy command 0xD1 into al (write output buffer)
	out 	0x64, al						; Send command to port 0x64 (keyboard status port)
	call	wait_input						; Wait for input buffer to be empty

	pop		eax								; Bring back value from stack
	or		al, 2							; Set bit 2 to 1 (2 = 10b)
	out 	0x60, al						; Write value of AL into port 0x60 (keyboard data port)

	call 	wait_input						; Wait for output buffer to be empty
	mov 	al, 0xae						; Copy command 0xAE into al (enable keyboard)
	out 	0x64, al 						; Send command to port 0x64 (keyboard status port)
	call 	wait_input						; Wait for output buffer to be empty

	popa									; Restore registers
	sti										; Enable interrupts
	ret										; Return!

wait_output:
	in 		al, 0x64						; Read from port 0x64 into al (keyboard status port)
	test	al, 1 							; Test of al with binary mask 00000001 (output buffer)
	jnz		wait_output						; If it's not 0, go back to waiting
	ret 									; It's zero, done! Return.

wait_input:
	in 		al, 0x64						; Read from port 0x64 into al (keyboard status port)
	test 	al, 2							; Test of al with binary mask 00000010 (input buffer)
	jnz		wait_input						; If it's not 0, go back to waiting
	ret 									; It's zero, done! Return.

;*****************************************
;	EnableA20_Bios ()
;		- Enables a20 line through bios
;*****************************************

EnableA20_Bios:
	pusha									; Save registers
	mov		ax, 0x2401						; Copy command 0x2401 into AX
	int		0x15							; Interrupt 0x15
	popa									; Restore registers
	ret 									; Return!

;*****************************************
;	EnableA20_SysControlA ()
; 		- Enables a20 line through system control port A
;*****************************************

EnableA20_SysControlA:
	push	ax 								; Save register AX onto stack
	mov		al, 2							; Move value 2 into al
	out		0x92, al 						; Send command to port 0x92
	pop		ax 								; Restore register AX from stack
	ret 									; Return!

%endif ; __A20_ICEXOS_INCLUDES_INC_FILE__