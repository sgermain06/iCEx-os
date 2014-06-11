;*****************************************
;	stage2.asm
;		- Stage 2 of iCEx OS Bootloader
;*****************************************

org		0x500
bits 16

jmp		main

;*************************************************;
;	Preprocessor directives
;*************************************************;

%include "includes/stdio.asm"					; Basic I/O routines
%include "includes/gdt.asm"						; GDT routines
%include "includes/a20.asm"						; A20 routines
%include "includes/fat12.asm"					; Fat12 driver
%include "includes/common.asm"					; Common definitions

;*************************************************;
;	Messaging and variables
;*************************************************;

Greeting 	db "STAGE2 - Hello, World!", 10,13,0
Preparing	db "Preparing to load Operating System...",10,13,0
AnyKey		db "Press any key to reboot...", 0
GateA20On	db "Enabling Gate A20...", 10, 13, 0
GDTLoaded	db "GDT Installed...", 10, 13, 0
LoadStage3	db "Kernel - Loading", 0
loadKernel 	db 10, 13, "Loading kernel file", 0
EnterPmode	db 10, 13, "Entering Protected Mode", 0
testBla		db "Bla!", 0

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
		call	InstallGDT						; Initialize the GDT
		mov		si, GDTLoaded
		call	Puts16

		; Enable Gate A20
		mov		si, GateA20On
		call 	Puts16

		call	EnableA20_Kbd					; Enable Gate A20

		mov 	si, LoadStage3
		call	Puts16

		; Load kernel
		call	LoadRoot 						; Load root directory table

;	mov		ebx, 0			; BX:BP points to buffer to load to
;   mov		bp, IMAGE_RMODE_BASE
;	mov		si, ImageName		; our file to load
;	call	LoadFile		; load our file
;	mov		dword [ImageSize], ecx	; save size of kernel
;	cmp		ax, 0			; Test for success
;	je		EnterStage3		; yep--onto Stage 3!
;	mov		si, msgFailure		; Nope--print error
;	call	Puts16
;	mov		ah, 0
;	int     0x16                    ; await keypress
;	int     0x19                    ; warm boot computer
;	cli				; If we get here, something really went wong
;	hlt
		;call 	ResetFloppy

		mov 	ebx, 0 							; BX:BP points to buffer to load to
		mov 	bp, IMAGE_RMODE_BASE
		mov 	si, ImageName 					; Kernel file to load
		call	LoadFile 						; Load kernel file
		mov 	dword [ImageSize], ecx 			; Size of kernel
		cmp 	ax, 0 							; Check for file load error

		je 		main.EnterStage3				; No error, load Stage 3!
		mov 	si, msgFailure 					; Error, print error
		call 	Puts16
		mov 	ah, 0

		int 	0x16							; Await keypress
		int 	0x19 							; Warm boot computer

		cli 									; If we get here, something went horribly wrong...
		hlt

	main.EnterStage3:

		mov 	si, EnterPmode
		call 	Puts16

		; Switch to protected mode
		cli										; Clear interrupts <-- IMPORTANT!!!
		mov		eax, cr0						; Load control register 0 to eax
		or 		eax, 1 							; Set eax to 1
		mov		cr0, eax						; Load eax into control register 0

		jmp 	CODE_DESC:LoadKernel			; Far jump to fix CS. Remember that the code selector is 0x8!

		; Note: Do NOT re-enable interrupts! Doing so will trigger a triple fault!
		; We fix this in Stage 3.

;*************************************************;
;	Kernel entry point
;*************************************************;

	bits 32

LoadKernel:

		; Setup registers
		mov		ax, DATA_DESC					; Set data segmentsto data selector (0x10)
		mov		ds, ax
		mov 	ss, ax
		mov		es, ax
		mov		esp, 90000h 					; Stack begins from 0x90000

		; Copy kernel to 1MB (0x10000)

;  		 mov	eax, dword [ImageSize]
;  		 movzx	ebx, word [bpbBytesPerSector]
;  		 mul	ebx
;  		 mov	ebx, 4
;  		 div	ebx
;   	 cld
;   	 mov    esi, IMAGE_RMODE_BASE
;   	 mov	edi, IMAGE_PMODE_BASE
;   	 mov	ecx, eax
;   	 rep	movsd                   ; copy image to its protected mode address

	LoadKernel.CopyImage:

		mov 	eax, dword [ImageSize]
		movzx	ebx, word [bpbBytesPerSector]
		mul 	ebx
		mov 	ebx, 4
		div 	ebx
		cld
		mov 	esi, IMAGE_RMODE_BASE
		mov 	edi, IMAGE_PMODE_BASE
		mov 	ecx, eax
		rep 	movsd 							; Copy image to its protected mode address

		call 	CODE_DESC:IMAGE_PMODE_BASE