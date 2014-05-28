;*****************************************
;	stage2.asm
;		- Stage 2 of iCEx OS Bootloader
;*****************************************

	org		0x500
	bits 	16

	jmp		main

;*************************************************;
;	Preprocessor directives
;*************************************************;

%include "includes/stdio.asm"			; Basic I/O routines
%include "includes/gdt.asm"				; GDT routines
%include "includes/a20.asm"				; A20 routines

;*************************************************;
;	Messaging and variables
;*************************************************;

Greeting 	db "STAGE2 - Hello, World!", 10,13,0
Preparing	db "Preparing to load Operating System...",10,13,0
AnyKey		db "Press any key to reboot...", 0
GateA20On	db "[A20 ] Enabling Gate A20...", 0
GDTLoading	db "[GDT ] Loading... ", 0
LoadStage3	db "STAGE3 - Loading...", 0
DoneMsg		db "Done.", 10, 13, 0

;*************************************************;
;	Reboot ()
;		- Performs a warm reboot
;*************************************************;

Reboot:
	mov 	si, AnyKey
	call 	Puts16
	call	GetPressedKey16

	; Warm reboot
	db		0x0ea
	dw		0x0000
	dw		0xffff

;*************************************************;
;	main ()
;		- Store BIOS information
;		- Loads Kernel
;		- Installs GDT; go into protected mode (pmode)
;		- Jump to stage 3
;*************************************************;

main:
	; Setup segments and stack
	cli										; Clear interrupts
	xor		ax, ax							; Null segments
	mov		ds, ax							; Align data segment
	mov		es, ax							; Align extra segment (heap)
	mov		ax, 0x9000						; Stack begins at 0x9000-0xFFFF
	mov		ss, ax							; Align stack segment
	mov		sp, 0xffff 						; Set stack endpoint
	sti 									; Enable interrupts

	; Print loading message
	mov		si, Greeting
	call	Puts16
	mov		si, Preparing
	call	Puts16

	; Install GDT
	mov		si, GDTLoading
	call	Puts16
	call	InstallGDT						; Initialize the GDT
	mov		si, DoneMsg
	call	Puts16

	; Enable Gate A20
	mov		si, GateA20On
	call 	Puts16
	call	EnableA20_Kbd					; Enable Gate A20
	mov		si, DoneMsg
	call	Puts16

	; Load Stage 3
	mov 	si, LoadStage3
	call	Puts16

	; Switch to protected mode
	cli										; Clear interrupts <-- IMPORTANT!!!
	mov		eax, cr0						; Load control register 0 to eax
	or 		eax, 1 							; Set eax to 1
	mov		cr0, eax						; Load eax into control register 0

	jmp 	CODE_DESC:Stage3				; Far jump to fix CS. Remember that the code selector is 0x8!

	; Note: Do NOT re-enable interrupts! Doing so will trigger a triple fault!
	; We fix this in Stage 3.

;*************************************************;
;	Stage 3 entry point
;*************************************************;

	bits 	32

Stage3:
	; Setup registers
	mov		ax, DATA_DESC					; Set data segmentsto data selector (0x10)
	mov		ds, ax
	mov 	ss, ax
	mov		es, ax
	mov		esp, 0x90000 					; Stack begins from 0x90000

	; Stop execution
	cli
	hlt