;*****************************************
;	fat12.asm
;		- FAT12 routines
;*****************************************

%ifndef __FAT12_ICEXOS_INCLUDES_INC_FILE__
%define __FAT12_ICEXOS_INCLUDES_INC_FILE__

bits 16

%include "includes/floppy.asm"

%define	ROOT_OFFSET	0x2e00
%define	FAT_SEG		0x2c0
%define	ROOT_SEG	0x2e0

mhere	db	10, 13, "F12 Here!", 10, 13, 0
testEOF	db	10, 13, "Testing EOF", 10, 13, 0
;*****************************************
;	LoadRoot ()
; 		- Load Root Directry Table
;*****************************************

LoadRoot:
		pusha									; Save registers
		push 	es

		; Compute size of root directory and store in "cx"
		xor		cx, cx							; Clear registers
		xor		dx, dx
		mov		ax, 32							; 32 bytes directory entry
		mul		word [bpbRootEntries]			; Total size of directory
		div		word [bpbBytesPerSector]		; Sectors used by directory
		xchg	ax, cx							; Move into AX

		; Compute location of root directory and store in "ax"
		mov 	al, byte [bpbNumberOfFATs]		; Number of FATs
		mul		word [bpbSectorsPerFAT]			; Sectors used by FATs
		add		ax, word [bpbReservedSectors]	; Adjust for boot sector
		mov 	word [dataSector], ax 			; Base of root directory
		add 	word [dataSector], cx

		; Read root directory
		push 	word ROOT_SEG
		pop		es
		mov 	bx, 0 							; Copy root directory
		call 	ReadSectors
		pop 	es
		popa									; Restore registers
		ret

;*****************************************
;	LoadFAT ()
; 		- Load File Allocation Table
;
;	Params
;	ES:DI => Root directory table
;*****************************************

LoadFAT:
		pusha									; Save registers
		push 	es
		; Compute size of FAT and store in "cx"
		xor 	ax, ax
		mov 	al, byte [bpbNumberOfFATs]		; Number of FATs
		mul 	word [bpbSectorsPerFAT]			; Sectors used by FATs
		mov 	cx, ax

		; Compute location of FAT and store in "ax"
		mov 	ax, word [bpbReservedSectors]
		push 	word FAT_SEG
		pop 	es
		xor 	bx, bx

		call 	ReadSectors
		pop 	es
		popa									; Restore registers
		ret

;*****************************************
;	FindFile ()
; 		- Search for file name in root table
;
;	Params
;	DS:SI => File name
;	Return
;	AX => File index number in directory table. -1 if error
;*****************************************

FindFile:
		push 	cx								; Save registers
		push 	dx
		push 	bx
		mov 	bx, si 							; Copy file name for later

		; Browse root directory for binary image
		mov 	cx, word [bpbRootEntries]		; Load loop counter
		mov 	di, ROOT_OFFSET 				; Locate first root entry
		cld 									; Clear direction flag

	FindFile.Loop:
		push 	cx
		mov 	cx, 11							; 11 character name, image name is in SI
		mov 	si, bx							; Image name is in BX
		push 	di
		rep 	cmpsb							; Test for entry match
		pop 	di
		je		FindFile.Found
		pop 	cx
		add		di, 32							; Queue next directory entry
		loop 	FindFile.Loop

	FindFile.NotFound:
		pop 	bx 								; Restore registers
		pop 	dx
		pop 	cx
		mov 	ax, -1 							; Set error code
		ret

	FindFile.Found:
		pop 	ax 								; Restore registers
		pop 	bx
		pop 	dx
		pop 	cx
		ret

;*****************************************
;	LoadFile ()
; 		- Load a file
;
;	Params
;	ES:SI => File address to load
;	BX:BP => Buffer to load the file
;	Return
;	AX => -1 if error, 0 if success
; 	CX => Number of sectors loaded
;*****************************************

LoadFile:

		xor 	ecx, ecx
		push 	ecx

	LoadFile.FindFile:
		push 	bx 								; BX:BP points to the buffer to write to; store it for later.
		push 	bp

		call	FindFile 						; Find our file. ES:SI contains our file name

		cmp 	ax, -1 							; Check AX for error from FindFile
		jne 	LoadFile.LoadImagePre			; No error, load FAT
		pop 	bp 								; Nope, restore registers, set error code and return.
		pop 	bx
		pop 	ecx
		mov 	ax, -1
		ret

	LoadFile.LoadImagePre:
		sub 	edi, ROOT_OFFSET
		sub 	esi, ROOT_OFFSET

		; Get starting cluster
		push 	word ROOT_SEG
		pop 	es
		mov 	dx, word [es:di + 0x001A] 		; ES:DI points to file entry in root directory table.
		mov 	word [cluster], dx 				; Reference the table for file's first cluster
		pop 	bx 								; Get location to write to so we don't screw up the stack
		pop 	es
		push 	bx 								; Store location for later again
		push 	es

		call 	LoadFAT 						; Load the FAT at 0x7c00

	LoadFile.LoadImage:
		mov 	ax, word [cluster] 				; Cluster to read
		pop 	es
		pop 	bx

		call 	CHSLBA							; Convert cluster to LBA

		xor 	cx, cx
		mov 	cl, byte [bpbSectorsPerCluster]	; Sectors to read

		call 	ReadSectors						; Read cluster

		pop 	ecx
		inc 	ecx
		push 	ecx

		push 	bx 								; Save registers for next iteration
		push 	es

		mov 	ax, FAT_SEG
		mov 	es, ax
		xor 	bx, bx

		; Compute next cluster
		mov 	ax, word [cluster]				; Identify current cluster
		mov 	cx, ax 							; Copy current cluster
		mov 	dx, ax 							; Copy current cluster
		shr 	dx, 1 							; Divide by 2
		add 	cx, dx 							; Sum for (3 / 2)

		mov 	bx, 0 							; Location of FAT in memory
		add 	bx, cx 							; Index to FAT
		mov 	dx, word [es:bx] 				; Read 2 bytes from FAT
		test 	ax, 1
		jnz 	LoadFile.OddCluster

	LoadFile.EvenCluster:
		and 	dx, 0000111111111111b			; Take the low 12 bits
		jmp 	LoadFile.Done

	LoadFile.OddCluster:
		shr 	dx, 4							; Take the high 12 bits

	LoadFile.Done:
		mov 	word [cluster], dx 				; Store new cluster
		cmp 	dx, 0x0ff0 						; Test for end of file marker  (0xFF)
		mov 	si, testEOF
		call 	Puts16
		jb 		LoadFile.LoadImage 				; No? Go on to the next cluster then

	LoadFile.Return:
		pop 	es
		pop 	bx
		pop 	ecx
		xor 	ax, ax
		ret


%endif ;__FAT12_ICEXOS_INCLUDES_INC_FILE__