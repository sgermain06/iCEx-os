;*****************************************
;	stage1.asm
;		- Stage 1 of iCEx OS Bootloader
;*****************************************

	org 	0x7c00			; We are loaded by BIOS at 0x7c00
	bits	16				; We are still in 16 bits Real Mode
	jmp 	Loader

;*************************************************;
;	OEM Parameter block
;*************************************************;

;TIMES 0Bh-$+start DB 0

bpbOEM					DB "iCEx OS "
bpbBytesPerSector:  	DW 512
bpbSectorsPerCluster: 	DB 1
bpbReservedSectors: 	DW 1
bpbNumberOfFATs: 	    DB 2
bpbRootEntries: 	    DW 224
bpbTotalSectors: 	    DW 2880
bpbMedia: 	            DB 0xF0
bpbSectorsPerFAT: 	    DW 9
bpbSectorsPerTrack: 	DW 18
bpbHeadsPerCylinder: 	DW 2
bpbHiddenSectors: 	    DD 0
bpbTotalSectorsBig:     DD 0
bsDriveNumber: 	        DB 0
bsUnused: 	            DB 0
bsExtBootSignature: 	DB 0x29
bsSerialNumber:	        DD 0xa0a1a2a3
bsVolumeLabel: 	        DB "IXOS FLOPPY"
bsFileSystem: 	        DB "FAT12   "

;*************************************************;
;	Messaging and variables
;*************************************************;

Greeting 	db "Hello, World!", 0
Preparing	db "Preparing to load Operating System...",0
AnyKey		db "Press any key to reboot...", 0

Println:
	lodsb
	or 		al, al
	jz		Println.complete
	mov		ah,	0eh
	int		10h
	jmp 	Println
Println.complete:
	call PrintNwl

PrintNwl:
	mov		al, 0
	stosb

	mov		ah, 0eh
	mov		al, 0dh
	int		10h
	mov		al, 0ah
	int		10h
	ret

Reboot:
	mov 	si, AnyKey
	call 	Println
	call	GetPressedKey

	db		0x0ea
	dw		0x0000
	dw		0xffff

GetPressedKey:
	mov 	ah, 0
	int		16h
	ret

Loader:
	cli
	
	mov		ax, cs
	mov		ds, ax
	mov		es, ax
	mov		ss, ax

	sti

	mov		si, Greeting
	call	Println

	mov		si, Preparing
	call	Println

	call	Reboot

	times 	510 - ($-$$) db 0	; We have to be 512 bytes. Clear the rest of the bytes with 0

	dw		0xAA55			; Boot signature