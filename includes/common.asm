;*****************************************
;	fat12.asm
;		- FAT12 routines
;*****************************************

%ifndef __COMMON_ICEXOS_INCLUDES_INC_FILE__
%define __COMMON_ICEXOS_INCLUDES_INC_FILE__

; where the kernel is to be loaded to in protected mode
%define IMAGE_PMODE_BASE 0x10000

; where the kernel is to be loaded to in real mode
%define IMAGE_RMODE_BASE 0x3000

; kernel name (Must be 11 bytes)
ImageName     db "IXOSKRNLSYS"

; size of kernel image in bytes
ImageSize     db 0

%endif ;__COMMON_ICEXOS_INCLUDES_INC_FILE__
