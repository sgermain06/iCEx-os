;*****************************************
;	stage1.asm
;		- Stage 1 of iCEx OS Bootloader
;*****************************************

	org 	0			; We are loaded by BIOS at 0x7c00
	bits	16				; We are still in 16 bits Real Mode
	jmp 	Loader

;*************************************************;
;	OEM Parameter block
;*************************************************;

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

absoluteSector			db 0x00
absoluteHead			db 0x00
absoluteTrack			db 0x00

datasector				dw 0x0000
cluster					dw 0x0000

msgLoading				db 13, 10, "iCEx OS v0.1b; Loading Boot ",0
msgProgress				db ".", 0
msgFailure  			db 13, 10, "ERROR : Press Any Key to Reboot", 13, 0
msgNewLine				db 13, 10, 0
ImageName				db "STAGE2  SYS"

Print:
		lodsb
		or		al, al
		jz		Print.complete
		mov		ah,	0eh
		int		10h
		jmp 	Print
	Print.complete:
		ret

;************************************************;
; Reads a series of sectors
; CX    => Number of sectors to read
; AX    => Starting sector
; ES:BX => Buffer to read to
;************************************************;

ReadSectors:
	.MAIN:
		mov		di, 0x0005                          ; five retries for error
	.SECTORLOOP:
		push    ax
		push    bx
		push    cx
		call    LBACHS                              ; convert starting sector to CHS
		mov     ah, 0x02                            ; BIOS read sector
		mov     al, 0x01                            ; read one sector
		mov     ch, byte [absoluteTrack]            ; track
		mov     cl, byte [absoluteSector]           ; sector
		mov     dh, byte [absoluteHead]             ; head
		mov     dl, byte [bsDriveNumber]            ; drive
		int     0x13                                ; invoke BIOS
		jnc     .SUCCESS                            ; test for read error
		xor     ax, ax                              ; BIOS reset disk
		int     0x13                                ; invoke BIOS
		dec     di                                  ; decrement error counter
		pop     cx
		pop     bx
		pop     ax
		jnz     .SECTORLOOP							; attempt to read again
		int     0x18
		mov		si, msgFailure
		call 	Print
	.SUCCESS:
		mov     si, msgProgress
		call    Print
		pop     cx
		pop     bx
		pop     ax
		add     bx, WORD [bpbBytesPerSector]		; queue next buffer
		inc     ax									; queue next sector
		loop    .MAIN								; read next sector
		ret

;************************************************;
; Convert CHS to LBA
; LBA = (cluster - 2) * sectors per cluster
;************************************************;

ClusterLBA:
		sub 	ax, 0x0002                          ; zero base cluster number
		xor		cx, cx
		mov		cl, BYTE [bpbSectorsPerCluster]     ; convert byte to word
		mul		cx
		add		ax, WORD [datasector]               ; base data sector
		ret
     
;************************************************;
; Convert LBA to CHS
; AX => LBA Address to convert
;
; absolute sector = (logical sector / sectors per track) + 1
; absolute head   = (logical sector / sectors per track) % number of heads
; absolute track  = logical sector / (sectors per track * number of heads)
;
;************************************************;

LBACHS:
		xor		dx, dx								; prepare dx:ax for operation
		div		WORD [bpbSectorsPerTrack]			; calculate
		inc		dl									; adjust for sector 0
		mov		BYTE [absoluteSector], dl
		xor		dx, dx								; prepare dx:ax for operation
		div		WORD [bpbHeadsPerCylinder]			; calculate
		mov		BYTE [absoluteHead], dl
		mov		BYTE [absoluteTrack], al
		ret

;*********************************************
;	Bootloader Entry Point
;*********************************************

Loader:

	;----------------------------------------------------
	; code located at 0000:7C00, adjust segment registers
	;----------------------------------------------------
     
		cli						; disable interrupts
		mov		ax, 0x07C0
		mov		ds, ax
		mov		es, ax
		mov		fs, ax
		mov		gs, ax

	;----------------------------------------------------
	; create stack
	;----------------------------------------------------
     
		mov		ax, 0x0000		; set the stack
		mov		ss, ax
		mov		sp, 0xFFFF
		sti						; restore interrupts

	;----------------------------------------------------
	; Display loading message
	;----------------------------------------------------
     
		mov		si, msgLoading
		call	Print
          
	;----------------------------------------------------
	; Load root directory table
	;----------------------------------------------------

LOAD_ROOT:
	; compute size of root directory and store in "cx"
		xor     cx, cx
		xor     dx, dx
		mov     ax, 32								; 32 byte directory entry
		mul     word [bpbRootEntries]				; total size of directory
		div     word [bpbBytesPerSector]			; sectors used by directory
		xchg    ax, cx

	; compute location of root directory and store in "ax"
		mov     al, BYTE [bpbNumberOfFATs]			; number of FATs
		mul     word [bpbSectorsPerFAT]				; sectors used by FATs
		add     ax, word [bpbReservedSectors]		; adjust for bootsector
		mov     word [datasector], ax				; base of root directory
		add     word [datasector], cx

	; read root directory into memory (:0200)
		mov     bx, 0x0200							; copy root dir above bootcode
		call    ReadSectors

 	;----------------------------------------------------
	; Find stage 2
	;----------------------------------------------------

	; browse root directory for binary image
		mov     cx, word [bpbRootEntries]			; load loop counter
		mov     di, 0x0200							; locate first root entry
	.LOOP:
		push    cx
		mov     cx, 0x000B							; eleven character name
		mov     si, ImageName						; image name to find
		push    di
		rep		cmpsb								; test for entry match
		pop     di
		je      LOAD_FAT
		pop     cx
		add     di, 0x0020							; queue next directory entry
		loop    .LOOP
		jmp     FAILURE

	;----------------------------------------------------
	; Load FAT
	;----------------------------------------------------

LOAD_FAT:
	; save starting cluster of boot image
		mov		dx, word [di + 0x001A]
		mov		word [cluster], dx					; file's first cluster

	; compute size of FAT and store in "cx"
		xor     ax, ax
		mov     al, BYTE [bpbNumberOfFATs]          ; number of FATs
		mul     word [bpbSectorsPerFAT]             ; sectors used by FATs
		mov     cx, ax

	; compute location of FAT and store in "ax"
		mov     ax, word [bpbReservedSectors]       ; adjust for bootsector

	; read FAT into memory (7C00:0200)
		mov     bx, 0x0200                          ; copy FAT above bootcode
		call    ReadSectors

	; read image file into memory (0050:0000)
		mov     ax, 0x0050
		mov     es, ax                              ; destination for image
		mov     bx, 0x0000                          ; destination for image
		push    bx

	;----------------------------------------------------
	; Load Stage 2
	;----------------------------------------------------

LOAD_IMAGE:
 		mov		ax, word [cluster]					; cluster to read
		pop		bx									; buffer to read into
		call	ClusterLBA							; convert cluster to LBA
		xor		cx, cx
		mov		cl, BYTE [bpbSectorsPerCluster]		; sectors to read
		call	ReadSectors
		push	bx
          
	; compute next cluster
		mov     ax, word [cluster]					; identify current cluster
		mov		cx, ax								; copy current cluster
		mov		dx, ax								; copy current cluster
		shr		dx, 0x0001							; divide by two
		add		cx, dx								; sum for (3/2)
		mov		bx, 0x0200							; location of FAT in memory
		add		bx, cx								; index into FAT
		mov		dx, word [bx]						; read two bytes from FAT
		test	ax, 0x0001
		jnz		.ODD_CLUSTER

	.EVEN_CLUSTER:
		and     dx, 0000111111111111b				; take low twelve bits
		jmp     .DONE

	.ODD_CLUSTER:
		shr     dx, 0x0004							; take high twelve bits

	.DONE:
		mov     word [cluster], dx					; store new cluster
		cmp     dx, 0x0FF0							; test for end of file
		jb      LOAD_IMAGE
          
DONE:
		mov		si, msgNewLine
		call 	Print
		push	word 0x0050
		push	word 0x0000
		retf

FAILURE:
		mov		si, msgFailure
		call	Print
		mov		ah, 0x00
		int		0x16								; await keypress
		int		0x19								; warm boot computer
     
		times 	510 - ($-$$) db 0					; We have to be 512 bytes. Clear the rest of the bytes with 0

		dw		0xAA55								; Boot signature