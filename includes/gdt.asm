;*****************************************
;	gdt.asm
;		- GDT routines
;*****************************************

%ifndef __GDT_ICEXOS_INCLUDES_INC_FILE__
%define __GDT_ICEXOS_INCLUDES_INC_FILE__

bits 16

;*****************************************
;	InstallGDT ()
;		- Installs the GDT
;*****************************************

InstallGDT:
		cli									; Clear interrupts
		pusha								; Save registers
		lgdt	[toc]						; Loads GDT into GDTR
		sti									; Enable interrupts
		popa								; Restore registers
		ret 								; Return!

;*****************************************
;	Global Descriptor Table (GDT)
;*****************************************

gdt_data:
		dd		0							; Null Descriptor
		dd		0

; gdt_code: 								; Code descriptor
		dw		0xFFFF						; Limit low
		dw		0 							; Base low
		db		0 							; Base middle
		db 		10011010b					; Access
		db		11001111b					; Granularity
		db		0 							; Base high

; gdt_data:									; Data descriptor
		dw		0xFFFF						; Limit low
		dw		0 							; Base low
		db		0 							; Base middle
		db 		10010010b					; Access
		db		11001111b					; Granularity
		db		0 							; Base high
end_of_gdt:
toc:
		dw		end_of_gdt - gdt_data - 1 	; Limit (Size of GDT)
		dd		gdt_data					; Base of GDT

%define NULL_DESC 0
%define CODE_DESC 0x8
%define DATA_DESC 0x10

%endif ; __GDT_ICEXOS_INCLUDES_INC_FILE__