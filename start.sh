#!/bin/bash

VOLUMELABEL=ICEXOS

rm /Volumes/$VOLUMELABEL/STAGE2.SYS

nasm -f bin Bootloader/stage2.asm -o Bootloader/STAGE2.SYS -I./includes
nasm -f bin Kernel/kernel.asm -o Kernel/IXOSKRNL.SYS -I./includes

cp Bootloader/STAGE2.SYS /Volumes/$VOLUMELABEL
cp Kernel/IXOSKRNL.SYS /Volumes/$VOLUMELABEL

bochs -f conf/bochs.txt -q
