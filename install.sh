#!/bin/bash

VOLUMELABEL=ICEXOS

# Remove old image
rm icexboot.img

# Create empty floppy image, 1.44MB, 512 block size
dd if=/dev/zero of=icexboot.img bs=512 count=2880

# Compile stage1 bootloader
nasm -f bin Bootloader/stage1.asm -o Bootloader/stage1.bin
nasm -f bin Bootloader/stage2.asm -o Bootloader/STAGE2.SYS -I./includes

# Mount temporary image
DISKMOUNT=`hdid -nomount icexboot.img`

# Create FAT12 partition on disk with label "ICEXOS"
diskutil eraseVolume "MS-DOS FAT12" $VOLUMELABEL $DISKMOUNT

# Unmount partition
diskutil unmountDisk $DISKMOUNT

# Copy boot sector
dd if=Bootloader/stage1.bin of=$DISKMOUNT bs=512 count=1

# Mount the partition to copy stage2
diskutil mount $DISKMOUNT

echo "Installing Stage2..."
cp Bootloader/STAGE2.SYS /Volumes/$VOLUMELABEL

# Eject disk
diskutil eject $DISKMOUNT
