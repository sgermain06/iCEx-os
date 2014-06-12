VOLUMELABEL = ICEXOS
INCLUDES = ./includes

install:

run:

	if [ -a /Volumes/$(VOLUMELABEL)/STAGE2.ICE ]; then rm /Volumes/$(VOLUMELABEL)/STAGE2.ICE; fi;
	if [ -a /Volumes/$(VOLUMELABEL)/IXOSKRNL.ICE ]; then rm /Volumes/$(VOLUMELABEL)/IXOSKRNL.ICE; fi;

	nasm -f bin Bootloader/stage2.asm -o Bootloader/STAGE2.ICE -I$(INCLUDES)
	nasm -f bin Kernel/kernel.asm -o Kernel/IXOSKRNL.ICE -I$(INCLUDES)

	cp Bootloader/STAGE2.ICE /Volumes/$(VOLUMELABEL)
	cp Kernel/IXOSKRNL.ICE /Volumes/$(VOLUMELABEL)

	bochs -f conf/bochs.txt -q