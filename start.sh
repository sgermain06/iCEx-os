#!/bin/bash

VOLUMELABEL=ICEXOS

rm /Volumes/$VOLUMELABEL/STAGE2.ICE

nasm -f bin Bootloader/stage2.asm -o Bootloader/STAGE2.ICE -I./includes
nasm -f bin Kernel/kernel.asm -o Kernel/IXOSKRNL.ICE -I./includes

cp Bootloader/STAGE2.ICE /Volumes/$VOLUMELABEL
cp Kernel/IXOSKRNL.ICE /Volumes/$VOLUMELABEL

bochs -f conf/bochs.txt -q
