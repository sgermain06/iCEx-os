# Introduction #

Welcome! :)

In the previous tutorial, we talked about basic VGA programming in protected mode and even built a demo!

This is the tutorial you have been waiting for. It builds directly on all of the previous code and loads our kernel at the 1MB mark. It then executes our kernel.

The kernel is the most important part of our OS. We have talked a little bit about the mysterious foe that is the kernel before, haven't we? We will talk about the kernel and a lot more in the next few tutorials, including design, structure and development.

Right now, we already have everything setup. It's time to load the kernel and say good bye to stage 2!

**Note: this tutorial requires a basic understanding of the bootloader 3 and 4 tutorials. We cover everything in detail here, but all the conceps are explained in dept in the bootloader 3 and 4 tutorials. If you have not read those tutorials, please look at those tutorials first**.

[OS Development Series Tutorial 5: Bootloader 3](file://OSDev5.md)

[OS Development Series Tutorial 6: Bootloader 4](file://OSDev6.md)

If you have read them, this tutorial should not be that hard.

*Ready?*

# A Basic Kernel Stub #

This is the kernel we will load:

	; We are still pure binary. We will fix this in the next few tutorials :)
	
	org		0x10000						; Kernel starts at 1MB
	bits	32							; 32 bit code
	
	jmp		Stage3						; Jump to Stage3
	
	%include "stdio.inc"				; Our stdio.inc file we developed from the previous tutorial
	
	msg		db	10, 10, "Welcome to Kernel Land!!", 10, 0
	
	Stage3:
	
			; Set Registers
			mov		ax, 0x10				; Set data segment to data selector (0x10)
			mov		ds, ax
			mov		ss, ax
			mov		es, ax
			mov		esp, 0x90000			; Stack starts at 0x90000
		
			; Clear screen and print success
			call	ClrScr32
			mov		ebx, msg
			call	Puts32
		
			; Stop execution
			cli
			hlt
		
Okay, there's nothing much here. We will build on this program heavily in the next section.

Notice that it's all 32 bit. Sweet, huh? We are going to be out of the 16 bit world completely here.

For now, we just halt the system when we get to the kernel.

Please note that we will not be using this file probably at all in the rest of the series. Rather, we will be using a 32 bit C++ compiler. After we load the kernel image in memory, we can parse the file in memory for the kernel entry routine and call the C main() routine directly from our 2n stage boot loader. Cool, huh? In other words, we will go from our 2nd stage boot loader directly into the C++ world without any stub file or program. However, we need a starting point. Because of this, we will use a basic stub file in this tutorial to help test and demonstrate it's working.

In the next few tutorials, we will be getting our compilers up and working and use that instead. But now, we are getting ahead of ourselves here. :)

# The Floppy Interface #

Yay! It's time to finish off stage 2! In order to load the kernel, we need to traverse FAT12 again. But, before that, we have to get sectors off disk.

This code is EXACTLY the same from our bootloader and uses the BIOS int 0x13 to load sectors off disk.

Because this tutorial is also a complete review, let's break each routine into sections and describe exactly what is going on.

## Reading A Sector - BIOS INT 0x13 ##

We talked about everything regarding loading sectors in our bootloader 3. Looking back at the tutorial, remember that we can use the **BIOS interrupt 0x13 function 2** to read a sector. If we attempt to call a BIOS interrupt from protected mode, the processor will triple fault, remember?

Anyway, what was the interrupt? Right...

**INT 0x13/AH=0x02 - Disk: READ SECTOR(S) INTO MEMORY**

		AH = 0x02
		AL = Number of sectors to read
		CH = Low eight bits of cylinder number
		CL = Sector number (Bits 0-5). Bits 6-7 are for hard disks only
		DH = Head number
		DL = Drive number (Bit 7 set for hard disks)
	 ES:BX = Buffer to read sectors to
	
Returns:

		AH = Status code
		AL = Number of sectors read
		CF = Set if failure, cleared if successful
		
This is not THAT hard. Remember from the bootloader tutorial though. That is, we need to keep track of the sector, track and head number, and ensure we don't load a sector beyond the track. That is, **remember that there are 18 sectors per track? Setting the number greater than 18 will cause the controller to fail and the processor to triple fault**.

Okay, 18 sectors per track. Remember that each sector is 512 bytes. Also, remember that there are 63 tracks total.

Okay then! All of this information... Sectors per track, the number of tracks, number of heads, the size of a sector and completely depend on the disk itself. Remember that a sector doesn't NEED to be 512 bytes?

We describe everything in the OEM parameter block:

	bpbOEM:						db	"My OS   "
	bpbBytesPerSector:			dw	512
	bpbSectorsPerCluster:		db	1
	bpbReservedSectors:			dw	1
	bpbNumberOfFATs:			db	2
	bpbRootEntries:				dw	224
	bpbTotalSectors:			dw	2880
	bpbMedia:					db	0xF0	; 0xF1
	bpbSectorsPerFAT:			dw	9
	bpbSectorsPerTrack:			dw	18
	bpbHeadsPerCylinder:		dw	2
	bpbHiddenSectors:			dd	0
	bpbTotalSectorsBig:			dd	0
	bsDriveNumber:				db	0
	bsUnused:					db	0
	bsExtBootSignature:			db	0x29
	bsSerialNumber:				dd	0xa0a1a2a3
	bsVolumeLabel:				db	"MOS FLOPPY "
	bsFileSystem:				db	"FAT12   "
	
This should look familiar. Each member has been described in tutorial 5. Please see that tutorial for a full detailed explanation of everything here.

Now, all we need is a method so that we can load any number of sectors from disk to some location in memory. We immediately run into a problem though. Okay, **we know what sector we want to load**. However, **BIOS INT 0x13 does not work with sectors**. Okay, it does, but it also works with cylinder and tracks. Remember that a cylinder is just a head?

So what does this have to do with anything? Imagine we want to load sector 20. We cannot directly use this number because **there are only 18 sectors per track**. Attempting to read from the 20th sector on the current track will cause the floppy controller to fail and the processor to triple fault, as the sector doesn't exist. **In order to read the 20th sector, we have to read track 2 sector 2, head 0**. We will verify this later.

What this means is that, if we want to specify a sector to load, we need to convert our linear sector number into the exact cylinder, track and sector location on disk.

Wait for it... Aha! Remember our **CHS to LBA** conversion routine?

### Converting LBA to CHS ###

This should sound familiar, doesn't it? **Linear Block Addressing (LBA)*** simply represents an indexed location on disk. The first block being 0, the second block being 1. In other words, LBA simply represents the sector number, beginning with 0, where each "block" is a single "sector".

Anyway, we have to find a way to convert this sector number (LBA) to the exact cylinder/head/sector location on disk. **Remember this from bootloader 4 tutorial?**

Some of our readers exclaimed this code was fairly tricky and I am to admit it is. So, I'm going to explain it in detail here.

First, let's look at the formulas again:

	absolute sector	=	(logical sector / sectors per track) + 1
	absolute head	=	(logical sector / sectors per track) % number of heads
	absolute track	=	(logical sector / (sectors per track * number of heads))
	
Okay! This is pretty easy, huh? The "logical sector" is the actual number we want. Note that the **logical sector / sectors per track** is inside of all the above equations.

Because this division is inside of all these equations, we can store its result and use it for the other two expressions.

Let's put this into an example. We already said the 20th sector should be track 2, sector 2, remember? Let's try to put this formula to the test then:

	absolute sector	=	(logical sector / sectors per track) + 1
	2.1111111111111	=	20 / 18 (sector per track) + 1
	
We only keep the absolute number (2) Aha! Sector 2! Note that we need to add 1 because LBA addressing begins from 0. Remember that basic formula "logical sector / sectors per track" is in ALL of these formulas. It's simply 1.111111111 in this example (note in the above formula, we added 1 more). Because we are working with whole numbers, this is simply 1.

	absolute head	=	(logical sector / sectors per track) % number of heads
						(1) % (modulo) number of heads (2)
					=	Head 1
					
Remember the OEM block that we specified 2 heads per cylinder. So far, this indicates sector 2 on head 1. Great, but what track are we on?

	absolute track	=	(logical sector / (sectors per track * number of heads))
						(1) * number of heads (2)
					=	Track 2
						
Notice that this is the exact same formula as above. The only difference is that simple operation.

Anyway, following the formula, we have: **Logical sector 20 is on sector 2 track 2 head 1**. Compare that with what we originally said in the previous section and notice how this formula works.

Okay, so now let's try to apply these formulas in the code:

#### LBACHS Explanation: Detail ####

Okay, this routine takes one parameter: AX, which contains the logical sector to convert into CHS. Note the formula **(logical sector / sectors per track)** is part of all three formulas. Rather then recalculating this over and over, it's more efficient to just calculate it **once** and use that result in all other calculations. This is how this routine works:

	LBACHS:
			xor		dx, dx							; prepare dx:ax for operation
			div		word [bpbSectorsPerTrack]		; Calculate
		
Now AX contains the logical sector / sectors per track operation.

Begin with sector 1 (remember the +1 in logical sector / sectors per track?)

			inc		dl								; Adjust for sector 0
			mov		byte [absoluteSector], dl
		
Clear DX. AX still contains the result of the logical sector / sectors per track

			xor		dx, dx							; Prepare dx:ax for operation
		
Now for the formulas...

	absolute head	= (logical sector / sectors per track) % number of heads
	absolute track	= logical sector / (sectors per track * number of heads)

The multiplication results into a **division** by the number of heads. So, the only difference between the two operation is, one is division and one is the remainder of that division (the modulus).

Okay, let's see... What instruction can we use that could return both the remainder (%) and division result? `DIV`!

Remember that (logical sector / sectors per track) is still in AX, so all we need to do is divide by the number of heads per cylinder:

			div		word [bpbHeadsPerCylinder]		; Calculate
		
The equations for absolute head and absolute track are very similar. The only actual difference is the operation. **This simple DIV instruction sets both DX and AX. AX now stores the division of bpbHeadsPerCylinder; DX now contains the remainder (modulus) of the same operation**.

			mov		byte [absoluteHead], dl
			mov		byte [absoluteTrack], al
			ret
		
I hope this clears things up a bit. If not, please let me know.

### Converting CHS to LBA

This is a lot simpler:

		CHSLBA:
			; LBA	=	(cluster - 2) * sector per cluster
			sub		ax, 2								; Subtract 2 from cluster number
			xor		cx, cx								; Reset CX
			mov		cl, byte [bpbSectorPerCluster]		; Get sectors per cluster
			mul		cx									; Multiply
			add		ax, word [dataSector]				; Base data sector
			ret
		
### Reading Sectors ###

Okay, so now we have everything to read sectors. This code is also exactly the same from the bootloader.

	;***********************************************
	;	Reads a series of sectors
	;	CX => Number of sectors to read
	;	AX => Starting sector
	;	ES:BX => Buffer to read to
	;***********************************************

	ReadSectors:
		ReadSectors.Main:
			mov		di, 5								; Five retries for error
	
Okay, here we attempt to read the sectors 5 times.

		ReadSectors.Loop:
			push	ax
			push	bx
			push	cx
			call	LBACHS								; Convert starting sector to CHS
			
We store the registers on the stack. The starting sector is a linear sector number (stored in AX). Because we are using BIOS INT 0x13, we need to convert this to CHS before reading from the disk. So, we use our LBA to CHS conversion routine. Now, **absoluteTrack** contains the track number, **absoluteSector** contains the sector within the track and **absoluteHead** contains the head number. All of this was set by our LBA to CHS conversion routine, remember?

			mov		ah, 0x02							; BIOS read sector
			mov		al, 0x01							; Read one sector
			mov		ch, byte [absoluteTrack]			; Track
			mov		cl, byte [absoluteSector]			; Sector
			mov		dh, byte [absoluteHead]				; Head
			mov		dl, byte [bsDriveNumber]			; Drive
			int		0x13								; Invoke BIOS
			
Now we set up to read a sector and invoke the BIOS to read it

#### INT 0x13/AH=0x02 - Disk: Read Sector(s) to Memory ####

	   AH 	= 0x02
	   AL 	= Number of sectors to read
	   CH 	= Low eight bits of cylinder number
	   CL 	= Sector number (Bits 0-5). Bits 6-7 are for hard disks only
	   DH 	= Head number
	   DL	= Drive number (Bit 7 set for hard disks)
	ES:BX	= Buffer to read sectors to
	
Compare this to how we execute the code above, fairly simple, huh?

Remember that the buffer to write to is in ES:EX, which INT 0x13 references as the buffer. We passed ES:BX into this routine, so that is the location to load the sectors to.

			jnc		ReadSector.Success					; Test for read error
			xor		ax, ax								; BIOS Reset disk
			int		0x13								; Invoke BIOS
			dec		di
			pop		cx
			pop		bx
			pop		ax
			jnz		ReadSector.Loop						; Attempt to read again
			
The BIOS INT 0x13 function 2 sets the *Carry Flag (CF)* if there is an error. If there's an error, decrement the counter (remember we set up the loop to try 5 times?)

If all 5 attempts failed (CX = 0, zero flag set), then we fall down to the INT 0x18 instruction:

			int		0x18
			
Which reboots the computer.
			
If the *Carry Flag* was NOT set (CF = 0), then the **jnz** instruction jumps here, as it indicates that there was no error. The sector was read successfully.

		ReadSector.Success:
			pop		cx
			pop		bx
			pop		ax
			add		bx, word [bpbBytesPerSector]		; Queue next buffer
			inc		ax									; Queue next sector
			loop	ReadSector.Main						; Read next sector
			ret
			
Now, just restore the registers and go to the next sector. Not too hard :) Note that, because ES:BX contains the address to load the sectors to, we need to increment BX by the bytes per sector to go to the next sector.

AX contained the **starting sector** to read from, so we need to increment that too.

I guess that's all for now. Please reference bootloader 4 for a full explanation of this routine.

### Floppy16.inc ###

In the example demo, all of the floppy access routines are in **Floppy16.inc**.

# FAT12 Interface #

Yay! We can load sectors. Woohoo! :) As you know, we cannot really do much with that. What we need to do next is create a basic definition of a *file* and what a *file* is. We do this by means of a **file system**.

File systems can get quite complex. Please reference bootloader 4 while I explain this code to fully understand how this code works.

## Constants ##

During the parsing of FAT12, we will need a location to load the root directory table and the FAT table. To make things somewhat easier, let's hide these locations behind constants:

	%define	ROOT_OFFSET	0x2e00
	%define	FAT_SEG		0x2c0
	%define	ROOT_SEG	0x2e0
	
We will be loading our root directory table to 0x2e00 and our FAT to 0x2c00. FAT_SEG and ROOT_SEG are used for loading into segment registers.

## Traversing FAT12 ##

As you know, some OS code can simply get ugly. File systems code, in my opinion, is one of them. This is one of the reasons why I decided to go over this code in this review, like tutorial. The FAT12 code is basically the same as the bootloader, but I decided to modify it to decrease dependencies with the main program. Because of this, I decided ti in detail here.

Please note, I will not go over FAT12 in detail here. Please see the bootloader 4 tutorial for complete details.

Anyway, as you know, in order to traverse FAT12, the first thing we need is to load the **root directory table**. So, let's take a look at that first.

### Loading the Root Directory Table ###

*Disk Structure*:
<table>
	<tr>
		<td bgcolor="#dddddd">Boot Sector</td>
		<td bgcolor="#dddddd">Extra Reserved Sectors</td>
		<td bgcolor="#dddddd">File Allocation Table 1</td>
		<td bgcolor="#dddddd">File Allocation Table 2</td>
		<td bgcolor="#aaaaaa">Root Directory (FAT12/16 Only)</td>
		<td bgcolor="#dddddd">Data Region containing Files and Directories</td>
	</tr>
</table>

Remember that the root directory table is located right after the FATs and reserved sectors?

In loading the root directory table, we need to find a location in memory that we do not currently need to copy it there. For now, I choose 0x7E00 (real mode: 0x7E0:0). This is right above our bootloader, which is **still in memory** because we have never overwritten it.

There is an important concept here. Notice that we have to load everything in absolute memory locations. This is very bad, as we have to physically keep track of where things are located. This is where a **low level memory manager** comes into play. More later...

	;***********************************************
	;	LoadRoot ()
	;			- Load Root Directory Table
	;***********************************************

	LoadRoot:
			pusha								; Store registers
			push	es
			
We first store the current state of the registers. Not doing so will affect the rest of the program that uses it, which is very bad.

Now we get the size of the root directory table so that we know the number of sectors to load.

Remember from bootloader 4: Each entry is 32 bytes in size. When we add the new file in a FAT12 formatted disk, Windows automatically appends to the root directory for us and adds the **bpbRootEntries** byte offset variable to the **OEM parameter block**.

See? Windows is nice.

So, let's see. Knowing each entry is 32 bytes in size, **multiplying 32 bytes by the number of root directories will tell us how many bytes there are in the root directory table**. Simple enough, but we need the number of **sectors**, so we divide this result by the number of sectors:

		; Compute size of root directory and store in "cx"
			xor		cx, cx						; Clear registers
			xor		dx, dx
			mov		ax, 32						; 32 byte directory entry
			mul		word [bpbRootEntries]		; Total size of directory
			div		word [bpbBytesPerSector]	; Sectors used by directory
			xchg	ax, cx						; Move into AX
			
okay, so now AX = number of sectors the root directory takes. Now, we have to find a starting location.

Remember from bootloader 4: **the root directory table is right after both FATs and reserved sectors on disk**. Please look at the above disk structure table to see where the root directory table is located.

So, all we need to do is get the amount of sectors for the FATs and add that to the reserved sectors to get the exact location on disk:

		; Compute location of root directory and store in "ax"
			mov		al, byte [bpbNumberOfFATs]		; Number of FATs
			mul		word [bpbSectorsPerFAT]			; Sectors used by FATs
			add		ax, word [bpbReservedSectors]	; Adjust for boot sector
			mov		word [dataSector], ax			; Base of root directory
			add		word [dataSector], cx
			
Now that we have the number of sectors to read and exact starting sector, let's read it!

		; Read root directory
			push	word ROOT_SEG
			pop		es
			mov		bx, 0x0							; Copy root directory
			call	ReadSectors
			pop		es
			popa									; Restore registers
			ret
			
Notice that we set the segment:offset location to read into ROOT_SEG:0.

Next up, loading the FAT!

### Loading the FAT ###

Okay, remember from bootloader 4, we talked about the disk structure of a FAT12 formatted disk. Going Back in Time(tm), let's take another look:

*Disk Structure*:
<table>
	<tr>
		<td bgcolor="#dddddd">Boot Sector</td>
		<td bgcolor="#dddddd">Extra Reserved Sectors</td>
		<td bgcolor="#aaaaaa">File Allocation Table 1</td>
		<td bgcolor="#aaaaaa">File Allocation Table 2</td>
		<td bgcolor="#dddddd">Root Directory (FAT12/16 Only)</td>
		<td bgcolor="#dddddd">Data Region containing Files and Directories</td>
	</tr>
</table>

Remember that there are either one or two FATs? Also, notice that they are **right after** the reserved sectors on disk. **This should look familiar!**

	;***********************************************
	;	LoadFAT ()
	;			- Loads FAT table
	;	ES:DI => Root Directory Table
	;***********************************************

	LoadFAT:
	
			pusha									; Save registers
			push	es
			
First, we need to know how many sectors to load. Look back at the disk structure again. We store the number of FATs (and the sectors per FAT) in the OEM parameter block. So, to get the total sectors, just multiply them:

		; Compute size of FAT and store in "cx"
			xor		ax, ax
			mov		al, byte [bpbNumberOfFATs]		; Number of FATs
			mul		word [bpbSectorsPerFAT]			; Sectors used by FATs
			mov		cx, ax
			
Now, we need to take the reserved sectors into consideration, as they are before the FAT.

		; Compute location of FAT and store in "ax"
			mov		ax, word [bpbReservedSectors]
			
Yippee! Now, CX contains the n umber of sectors to load, so call our routine to load the sectors.

		; Read FAT into memory (Overwrite our bootloader at 0x7c00)
			push	word FAT_SEG
			pop		es
			xor		bx, bx
			call	ReadSectors
			pop		es
			popa									; Restore registers
			ret
			
That's all there is to it! :)

### Searching for a File ###

In searching for a file, we need the filename to search for. Remember that DOS uses 11 bytes file names following the common 8.3 naming convention (8 bytes file name, 3 bytes extension). Because of the way the entries in the root directory is structure, **this must be 11 bytes, no exception!**

Remember the format of the root directory table. The file name is stored within the **first** 11 bytes of an entry. Let's take another look at the format of each directory entry:

- **Bytes 0-7**: **DOS file name (padded with spaces)**
- **Bytes 8-10**: **DOS file extension (padded with spaces)**
- **Byte 11**: File attributes. This is a bit pattern:
	- **Bit 0**: Read only
	- **Bit 1**: Hidden
	- **Bit 2**: System
	- **Bit 3**: Volume label
	- **Bit 4**: Subdirectory
	- **Bit 5**: Archive
	- **Bit 6**: Device (internal use)
	- **Bit 7**: Unused
- **Byte 12**: Unused
- **Byte 13**: Creation time in milliseconds
- **Bytes 14-15**: Created time, using the following format:
	- **Bits 0-4**: Seconds (0-59)
	- **Bits 5-10**: Minutes (0-59)
	- **Bits 11-15**: Hours (0-23)
- **Bytes 16-17**: Created date in the following format:
	- **Bits 0-4**: Year (0=1980, 127=2107)
	- **Bits 5-8**: Month (1=January, 12=December)
	- **Bits 9-15**: Hours (0-23)
- **Bytes 18-19**: Last access date (same pattern as above)
- **Bytes 20-21**: EA Index (Used in OS/2 and NT, don't worry about it)
- **Bytes 22-23**: Last modified time (See bytes 14-15 for format)
- **Bytes 24-25**: Last modified date (See bytes 16-16 for format)
- **Bytes 26-27**: **First cluster**
- **Bytes 28-32**: **File size**

All **bolded** entries are the important ones. We must compare the **first 11 bytes** of each entry, as they contain the file name.

Once we find a match, **we need to reference byte 26 of the entry to get its current cluster**. All of this should sound familiar.

Now, on to the code!

	;***********************************************
	;	FindFile ()
	;			- Search for file name in root table
	;	Params
	;	DS:SI => File name
	;	Return
	;	AX => File index number in directory table. -1 if error
	;***********************************************

	FindFile:
			push	cx								; Store registers
			push	dx
			push	bx
			mov		bx, si							; Copy filename for later
			
We first store the current register states. We need to use SI, so we need to save the current filename somewhere. BX, perhaps?

Remember that we need to parse the root directory table to find the image name. To do this, we need to check the first 11 bytes of each entry in the directory table to see if we found a match. Sounds simple, huh?

To do this, we need to know how many entries there are.

		; Browse root directory for binary image
			mov		cx, word [bpbRootEntries]		; Load loop counter
			mov		di, ROOT_OFFSET					; Locate first root entry
			cld										; Clear direction flag
			
Okay, so CX now contains the number of entries to look in. All we need to do now is loop and compare the 11 bytes character filename. Because we are using string instructions, we want to first ensure the direction flag is cleared, which is what **cld** does.

DI is set to the current offset into the directory table. This is the location of the table. I.e., ES:DI points to the starting location of the table, so let's parse it!

		FindFile.Loop:
			push	cx
			mov		cx, 11							; 11 character name, image name is in SI
			mov		si, bx							; Image name is in BX
			push	di
			rep		cmpsb							; Test for entry match
			
If the 11 bytes match, the file was found. Because DI contains the location of the entry within the table, we immediately jump to FindFile.Found.

If it doesn't match, we need to try the next entry in the table. We add **32 bytes** onto DI. (**Remember that each entry is 32 bytes?)

			pop		di
			je		FindFile.Found
			pop		cx
			add		di, 32							; Queue next directory entry
			loop	FindFile.Loop
		
If the file was not found, restore only the registers that are still on the stack, and return -1 (error).

		FindFile.NotFound:
			pop		bx								; Restore registers
			pop		dx
			pop		cx
			mov		ax, -1							; Set error code
			ret
			
If the file was found, restore all the registers. AX contains the entry location within the root directory table so that it can be loaded.

		FindFile.Found:
			pop		ax								; Return value into AX contains entry of file
			pop		bx								; Restore registers and return
			pop		dx
			pop		cx
			ret
			
Yay! Now that we can find the file (and get its location within the root directory table), let's load it!

### Loading a File ###

Now that everything is finally set up, it's finally time to load the file!

Most of this is pretty easy, as it calls our other routines. It's here that we loop and ensure that all of the file's clusters are loaded into memory.

	;***********************************************
	;	LoadFile ()
	;			- Load a file
	;	Params
	;	ES:SI => File to load
	;	BX:BP => Buffer to load file to
	;	Return
	;	AX => -1 on error, 0 on success
	;	CX => Number of sectors loaded
	;***********************************************

	LoadFile:
			xor		ecx, ecx
			push	ecx
			
		LoadFile.FindFile:
			push	bx								; BX=>BP points to buffer to write to; store it for later
			push	bp
			
			call	FindFile						; Find our file. ES:SI contains our filename
			
			cmp		ax, -1							; Check for error
			jne		LoadFile.LoadImagePre			; No error :) Load FAT
			pop		bp								; Nope :( Restore registers, set error code and return.
			pop		bx
			pop		ecx
			mov		ax, -1
			ret
			
Okay, so if we get here, the file was found. ES:DI contains the location of the first root entry, which was set by FindFile(), so by referencing ES:DI, we effectively get the file's entry.

		LoadFile.LoadImagePre
			sub		edi, ROOT_OFFSET
			sub		eax, ROOT_OFFSET
			
			; Get starting cluster
			
			push	word ROOT_SEG
			pop		es
			mov		dx, word [es:di + 0x001A]		; ES:DI points to file entry in root directory table.
			mov		word [cluster], dx				; Reference the table for file's first cluster
			pop		bx								; Get location to write to so we don't screw up the stack
			pop		es
			push	bx								; Store location for later again
			push	es
			
The above is messy, I know. Remember that AX was set to the entry number by the call to FindFile? We need to store that here, but need to keep the buffer to write to on the **top** of the stack still. This is why I played with the stack a little here :)

Anyway, next, we load the FAT. This is incredibly easy.

			call	LoadFAT							; Load the FAT to 0x7c00
			
Okay then! Now that the FAT is loaded and that we have a starting file cluster, it is time to actually read in the file's sector.

		LoadFile.LoadImage:
			mov		ax, word [cluster]				; Cluster to read
			pop		es
			pop		bx
			call	CHSLBA							; Convert cluster to LBA
			xor		cx, cx
			mov		cl, byte [bpbSectorsPerCluster]	; Sectors to read
			call	ReadSectors						; Read cluster
			
			pop		ecx
			inc		ecx
			push	ecx
			
			push	bx								; Save registers for next iteration
			push	es
			
			mov		ax, FAT_SEG
			mov		es, ax
			xor		bx, bx
			
This code is not that bad. Remember that, for FAT12, **each cluster is just 512 bytes**? I.e., each cluster simply represents a "sector". We first get the starting cluster/sector number. We cannot do much with just a cluster number though, as it is a **linear** number. That is, it's the sector number in CHS, not LBA format. It assume we have the track and head information. Because our ReadSectors() requires an LBA linear sector number, **we convert this CHS to an LBA address**. Then, get the sectors per cluster and read it in!

Note that we pop ES and BX, they were pushed on the stack from the beginning. **ES:BX points to the ES:BP buffer that was passed to this routine. It contains the buffer to load the sectors into**.

Okay, so now that a cluster was loaded, we have to check with the FAT to determine if the end of file is reached. However, **remember that each FAT entry is 512 bytes?** We found out from bootloader 4 that there is a **pattern** when reading the FAT:

**For every even cluster, take the low twelve bits, for every odd cluster, take the high twelve bits**.

Please see bootloader 4 to see this in detail.

To determine if it is even or odd, just divide by 2:

		; Compute next cluster
			mov		ax, word [cluster]				; Identify current cluster
			mov		cx, ax							; Copy current cluster
			mov		dx, ax							; Copy current cluster
			shr		dx, 1							; Divide by 2
			add		cx, dx							; Sum for (3 / 2)
			
			mov		bx, 0							; Location of FAT in memory
			add		bx, cx							; Index into FAT
			mov		dx, word [es:bx]				; Read 2 bytes from FAT
			test	ax, 1
			jnz		LoadFile.OddCluster
			
		LoadFile.EvenCluster:
			and		dx, 0000111111111111b			; Take low twelve bits
			jmp		LoadFile.Done
			
		LoadFile.OddCluster:
			shr		dx, 4							; Take high twelve bits
			
		LoadFile.Done:
			mov		word [cluster], dx				; Store new cluster
			cmp		dx, 0x0ff0						; Test for end of file marker (0xFF)
			jb		LoadFile.LoadImage				; No? Go on to the next cluster then.
			
			pop		es								; Restore all registers
			pop		bx
			pop		ecx
			xor		ax, ax							; Return success code
			ret
			
That's all there is to it! Granted, it's a little complex, but not too hard, I hope! :)

### Fat12.inc ###

Great! All of the FAT12 code is in **Fat12.inc**.

# Finishing Stage 2 #

## Back to Stage 2 - Loading and Executing the Kernel ##

Now that the messy code is over, all we need to do is load our kernel image into memory from stage 2 and execute our kernel. The problem is: where?

While we do want to load it to 1MB, we cannot do this directly yet. The reason is that we are still in real mode. Because of this, we will first need to load the image to a lower address first. After we switch into protected mode, we can copy our kernel to a new location. This can be 1MB, or even 3GB if paging is enabled.

		call	LoadRoot							; Load root directory table
		
		mov		ebx, 0								; BX:BP points to buffer to load to
		mov		ebp, IMAGE_RMODE_BASE
		mov		esi, ImageName						; Our file to load
		call	LoadFile							; Load our file
		mov		dword [ImageSize], ecx				; Size of kernel
		cmp		ax, 0								; Test for success
		je		EnterStage3							; Yep! Onto stage 3!
		mov		si, msgFailure						; Nope, print error
		call	Puts16
		mov		ah, 0
		int		0x16								; Await keypress
		int		0x19								; Warm boot computer
		cli											; If we get here, something went really wrong...
		hlt
		
Now our kernel is loaded to IMAGE_RMODE_BASE:0. ImageSize contains the number of sectors loaded (the size of the kernel).

To execute inside of protected mode, all we need to do is jump or call it. Because we want our kernel at 1MB, we first need to copy it before we execute it:

	bits 32
	
	Stage3:
			mov		ax, DATA_DESC					; Set data segments to data selector (0x10)
			mov		ds, ax
			mov		ss, ax
			mov		es, ax
			mov		esp, 0x90000					; Stack begins from 0x90000
			
	; Copy kernel to 1MB (0x10000)
	
	CopyImage:
			mov		eax, dword [ImageSize]
			movzx	ebx, word [bpbBytesPerSector]
			mul		ebx
			mov		ebx, 4
			div		ebx
			cld
			mov		esi, IMAGE_RMODE_BASE
			mov		edi, IMAGE_PMODE_BASE
			mov		ecx, eax
			rep		movsd							; Copy image to its protected mode address
			
			call	CODE_DESC:IMAGE_PMODE_BASE		; Execute our kernel!
			
There is a little problem here, though. This assumes that our kernel is a **pure binary file**. We cannot have this, because C doesn't support this. We need the kernel to be a binary format that C supports and we will need to parse it in order to load the kernel using C. For now, we will keep this pure binary, but will fix this within the next few tutorials. Sounds good?

# Demo #

![Demo](http://www.brokenthorn.com/Resources/images/Krnl1.gif)

Our pure binary 32 bit kernel executing.

[Download Demo Here](http://www.brokenthorn.com/Resources/Demos/Demo4.zip)