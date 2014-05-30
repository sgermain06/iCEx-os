;*****************************************
;	floppy.asm
;		- Basic floppy routines
;*****************************************

%ifndef __FLOPPY_ICEXOS_INCLUDES_INC_FILE__
%define __FLOPPY_ICEXOS_INCLUDES_INC_FILE__

bits 16

;*************************************************
;	OEM Parameter block
;*************************************************

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

dataSector				dw 0x0000
cluster					dw 0x0000

msgProgress				db ".", 0
msgFailure  			db "X", 13, 10, "ERROR : Press Any Key to Reboot", 13, 0

;************************************************
;	CHSLBA ()
; 		- Convert CHS to LBA
;	LBA = (cluster - 2) * sectors per cluster
;************************************************

CHSLBA:
		sub 	ax, 2								; zero base cluster number
		xor		cx, cx
		mov		cl, BYTE [bpbSectorsPerCluster]		; convert byte to word
		mul		cx
		add		ax, WORD [dataSector]				; base data sector
		ret

;************************************************
;	LBACHS ()
; 		- Convert LBA to CHS
;
;	Params:
;	AX => LBA Address to convert
;
;	absolute sector = (logical sector / sectors per track) + 1
;	absolute head   = (logical sector / sectors per track) % number of heads
;	absolute track  = logical sector / (sectors per track * number of heads)
;
;************************************************

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

;************************************************
;	ReadSectors ()
; 		- Reads a series of sectors
;
;	Params:
; 	CX    => Number of sectors to read
; 	AX    => Starting sector
; 	ES:BX => Buffer to read to
;************************************************

ReadSectors:
	ReadSectors.Main:
		mov		di, 5 								; five retries for error
	ReadSectors.Loop:
		push    ax
		push    bx
		push    cx
		call    LBACHS 								; convert starting sector to CHS
		mov     ah, 0x02 							; BIOS read sector
		mov     al, 0x01 							; read one sector
		mov     ch, BYTE [absoluteTrack]			; track
		mov     cl, BYTE [absoluteSector]			; sector
		mov     dh, BYTE [absoluteHead]				; head
		mov     dl, BYTE [bsDriveNumber]			; drive
		int     0x13 								; invoke BIOS
		jnc     ReadSectors.Success					; test for read error
		xor     ax, ax 								; BIOS reset disk
		int     0x13 								; invoke BIOS
		dec     di 									; decrement error counter
		pop     cx
		pop     bx
		pop     ax
		jnz     ReadSectors.Loop 					; attempt to read again
		mov		si, msgFailure
		call 	Puts16
		int     0x18
	ReadSectors.Success:
		mov     si, msgProgress
		call    Puts16
		pop     cx
		pop     bx
		pop     ax
		add     bx, WORD [bpbBytesPerSector]		; queue next buffer
		inc     ax									; queue next sector
		loop    ReadSectors.Main					; read next sector
		ret

%endif ;__FLOPPY_ICEXOS_INCLUDES_INC_FILE__