This series is intended to demonstrate and teach operating system development from the ground up.

# Introduction #

Welcome! :)

We covered a lot so far throughout this series. We looked at bootloaders, system architecture, file systems and real mode addressing, in depth. This is cool, but we have yet to look at the 32 bit world. And are we not building a 32bit OS?

In this tutorial, we are going to make the jump to the 32bit world! Granted, we are not done with the 16 bit world just yet, however it will be much easier to get entering protected mode done now.

So, let's get started then! This tutorial covers:

- Protected Mode Theory
- Protected Mode Addressing
- Entering Protected Mode
- Global Descriptor Table (GDT)

*Ready?*

# stdio.inc #

To make things more *object oriented*, I have moved all input/output routines into a `stdio.inc` file. Please, do not associate this with the C standard library `stdio` library. They have almost nothing in common. We will start working on the standard library while working on the Kernel.

Anyways, here's the file:
	
	;**********************************************
	;		stdio.inc
	;				-Input/Output routines
	;
	;		OS Development Series
	;**********************************************

	%ifndef __STDIO_INC_67343546FDCC56AAB872_INCLUDED__
	%define __STDIO_INC_67343546FDCC56AAB872_INCLUDED__
	
	;**********************************************
	;		Puts16 ()
	;				-Prints a null terminated string
	;		DS=>SI: 0 terminated string
	;**********************************************

	bits 16
	
	Puts16:
			pusha					; Save registers
	Puts16.Loop:
			lodsb					; Load next byte from string from SI to AL
			or		al, al			; Does AL=0?
			jz		Puts16.Done	; Yep, null terminator found, bail out
			mov		ah, 0x0e		; Nope, print the character
			int		0x10			; Invoke BIOS
			jmp		Puts16.Loop	; Repeat until null terminator found
	Puts16.Done:
			popa					; Restore registers
			ret						; We are done, return
	
	%endif ;__STDIO_INC_67343546FDCC56AAB872_INCLUDED__

For those who don't know, `*.INC` files are **include** files. We will add more to this file as needed. I'm not going to explain the `Puts16` function. It's the exact same routine we used in the bootloader, just with an added pusha/popa.

# Welcome to Stage 2 #

The bootloader is small. Way too small to do anything useful. Remember that the bootloader is limited to 512 bytes. No more, no less. Seriously, our code to load Stage 2 was almost 512 bytes already! It's simply way too small.

This is why we want the bootloader to *just* load another program. Because of the FAT12 file system, our second program can be of almost any amount of sectors. Because of this, there is no 512 byte limitation. This is great for us. This, our readers, is Stage 2.

The Stage 2 bootloader will set everything up for the Kernel. This is similar to **NTLDR** (NT Loader), in Windows. In fact, I'm naming the program **KRNLDR** (Kernel Loader). Stage 2 will be responsible for loading our kernel, hence KRNLDR.SYS.

KRNLDR -- Our Stage 2 bootloader, will do several things. It can:

- **Enable and go into protected mode**
- **Retrieve BIOS information**
- **Load and execute the kernel**
- Provide advance boot options (Such as Safe Mode, for example)
- Through configuration files, you can have KRNLDR boot from multiple operating system kernels
- **Enable the 20th address line for access up to 4GB of memory**
- **Provide basic interrupt handling**

...And more. It also sets up the environment for a high level language, like C. In fact, a lot of times, the Stage 2 loader is a mixture of C and x86 assembly.

As you can imagine, writing the stage 2 bootloader can be a large project itself. And yet, it's nearly impossible to develop and advanced bootloader without an already working kernel. Because of this, we are only going to worry about the important details, **bolded** above. When we get a working kernel, we may come back to the bootloader.

We are going to look at entering protected mode first. I'm sure a lot of you are itching to get into the 32 bit world; I know I am!

# World of Protected Mode #

Yippee! It's finally time! You have heard me say *protected mode* a lot and we have described it in some detail before. As you know, protected mode is supposed to offer memory protection. By defining how the memory is used, we can insure certain memory locations cannot be modified or executed as code. The x86 processor maps the memory regions based off the **Global Descriptor Table (GDT)**. **The processor will generate a General Protection Fault (GPF) exception if you do not follow the GDT. Because we have not set p interrupt handlers, this will result in a Triple Fault**.

Let's take a closer look, shall we?

## Descriptor Tables ##

A *Descriptor Table* defines or map something. In our case, memory and how memory is used. There are three types of descriptor tables:

- Global Descriptor Table (GDT)
- Local Descriptor Table  (LDT)
- Interrupt Descriptor Table (IDT)

**Each base address is stored in the GDTR, LDTR and IDTR x86 processor registers**. Because they use special registers, they require special attention. **Note: Some of these instructions are specific to Ring 0 kernel level programs. If a general Ring 3 program attempts to use them, a General Protection Fault (GPF) exception will occur**. In our case, because we are not handling interrupts yet, a Triple Fault will occur.

### Global Descriptor Table ###
THIS will be important to us and you will see it both in the bootloader and the Kernel.

The Global Descriptor Table (GDT) defines the global memory map. It defines what memory can be executed (the **code descriptor**) and what area contains data (**data descriptor**).

Remember that a descriptor defines properties, i.e.: it describes something. In the case of the GDT, it describes starting and base addresses, segment limits and even virtual memory. This will be more clear when we see it all in action, don't worry. ;)

The GDT usually has three descriptors:
- Null Descriptor (Contains all zeros)
- Code Descriptor
- Data Descriptor

Okay! So, what is a *descriptor*? For the GDT, a *descriptor* is an 8 byte QWORD value that describes properties for the descriptor. They are of the format:

- Bits 56-63: Bits 24-32 of the base address
- Bit 55: Granularity
	- 0: None
	- 1: Limit gets multiplied by 4K
- Bit 54: Segment type
	- 0: 16 bit
	- 1: 32 bit
- Bit 53: Reserved (should be zero)
- Bit 52: Reserved for OS use
- Bits 48-51: Bits 16-19 of the segment limit
- Bit 47: Segment is in memory (used with Virtual Memory)
- Bits 45-46: Descriptor privilege level
	- 0: (Ring 0) Highest
	- 3: (Ring 3) Lowest
- Bit 44: Descriptor bit
	- 0: System descriptor
	- 1: Code or data descriptor
- Bits 41-43: Descriptor type
	- Bit 43: Executable segment
		- 0: Data segment
		- 1: Code segment
	- Bit 42: Expansion direction (data segments), conforming (code segments)
	- Bit 41: Readable and writable
		- 0: Read only (data segments), execute only (code segments)
		- 1: Read and write (data segments), read and execute (code segments)
- Bit 40: Access bit (used with Virtual Memory)
- Bits 16-39: Bits 0-23 of the base address
- Bits 0-15: Bits 0-15 of the segment limit

Pretty ugly, huh? Basically, by building up a bit pattern, the 8 byte pattern will describe various properties of the descriptor. Each descriptor defines properties for its memory segment.

To make things simple, let's build a table that defines a code and data descriptors with read and write permissions from the first byte to byte 0xFFFFFFFF in memory. This just means we could read or write any location in memory.

We are first going to look at GDT:

	; This is the beginning of the GDT. Because of this, its offset is 0.
	
	; Null descriptor:
			dd		0				; Null descriptor. Just fill 8 bytes with zero.
			dd		0
			
	; Notice that each descriptor is exactly 8 bytes in size. THIS IS IMPORTANT.
	; Because of this, the code descriptor has an offset of 0x8.
	
	; Code descriptor:				; Code descriptor. Right after null descriptor
			dw 		0xFFFF			; Limit low
			dw 		0				; Base low
			db 		0				; Base middle
			db		10011010b		; Access
			db		11001111b		; Granularity
			db		0				; Base high
			
	; Because each descriptor is 8 byte in size, the Data Descriptor is at offset 0x10 from
	; the beginning of the GDT, or 16 (decimal) bytes from the start.
	
	; Data descriptor:				; Data descriptor. Right after code descriptor
			dw		0xFFFF			; Limit low (Same as code)
			dw 		0				; Base low
			db 		0				; Base middle
			db		10010010b		; Access
			db		11001111b		; Granularity
			db		0				; Base high

That's it! The infamous GDT. This GDT contains three descriptors; each 8 bytes in size. A *null descriptor*, a *code descriptor* and a *data descriptor*. **Each bit in each descriptor corresponds directly with that represented in the above bit table (Shown above the code)**.

Let's break each down into its bits to see what's going on. The null descriptor is all zeros, so we will focus on the other two.

#### Breaking Down the Code Descriptor ####

Let's look at it again:

	; Code descriptor:				; Code descriptor. Right after null descriptor
			dw 		0xFFFF			; Limit low
			dw 		0				; Base low
			db 		0				; Base middle
			db		10011010b		; Access
			db		11001111b		; Granularity
			db		0				; Base high
			
Remember that, in assembly language, each declared byte, word, dword, qword, instruction, whatever is literally right after each other. In the above, 0xffff is, of course, two bytes filled with ones. We can easily break this up into its binary form because most of it is already done:

	11111111	11111111	00000000	00000000	00000000	10011010	11001111	00000000
	
Remember (from the above bit table) that **bits 0-15 (the first two bytes)** represents the segment limit. This just means, we cannot use an address greater than 0xFFFF (which is in the first 2 bytes) within a segment. Doing so will cause a *GPF*.

Bits 16-39 (the next three bytes) represent bits 0-23 of the base address (the starting address of the segment). In our case, it's 0x0. **Because the base address is 0x0 and the limit address is 0xFFFF, the code descriptor can access eery byte from 0x0 through 0xFFFF**. Cool?

The next byte (byte 6) is where the interesting stuff happens. Let's break it down, bit by bit -- literally:

	db		10011010b		; Access
	
- Bit 0 (Bit 40 in GDT): Access bit (used with Virtual Memory). Because we don't use Virtual Memory (yet, anyway), we will ignore it. Hence, it is 0.
- Bit 1 (Bit 41 in GDT): is the readable/writable bit. It is set (for code descriptor) so we can read and execute data in the segment (from 0x0 through 0xFFFF) as code.
- Bit 2 (Bit 42 in GDT): is the "expansion direction" bit. We will look more into this later. For now, ignore it.
- Bit 3 (Bit 43 in GDT): tells the processor if this is a code or data descriptor. This is a code descriptor so the bit is set to 1.
- Bit 4 (Bit 44 in GDT): Represents this as a *system* or *code/data* descriptor. This is a code descriptor so the bit is set to 1.
- Bits 5-6 (Bit 45-46 in GDT): is the privilege level (i.e., ring 0 or ring 3). We are in ring 0 so both bits are set to 0.
- Bit 7 (Bit 47 in GDT): Used to indicate the segment is in memory (used with Virtual Memory). Set to zero for now, since we are not using Virtual Memory yet.

**The access byte is VERY important!**

We will need to define different descriptors in order to execute ring 3 applications and software. We will look at this a lot more closely when we start getting into the kernel.

Putting this together, this byte indicates: **This is a read/write segment, we are a code descriptor running in ring 0**.

Let's look at the next bytes:

	db		11001111b		; Granularity
	db		0				; Base high

Looking at the granularity byte, let's break it down. Remember to use the GDT bit table above:
- Bits 0-3 (Bits 48-51 in GDT): Represents bits 16-19 of segment limit. So, let's see... 1111b is equal to 0xf. Remember that, in the first two bytes of this descriptor, we set 0xFFFF as the first 15 bits. Grouping the low and high bits, **it means we can access up to 0xFFFF**. Cool? It gets better. By enabling the 20th address line, we ca access **up to 4GB of memory** using this descriptor. We will look closer at this later.
- Bit 4 (Bit 52 in GDT): Reserved for our OS's use, we could do whatever we want here. Set it to 0.
- Bit 5 (Bit 53 in GDT): Reserved for something. Future options, maybe? Who knows. Set it to 0.
- Bit 6 (Bit 54 in GDT): is the segment type (16 or 32 bits). Let's see, we want 32 bits, don't we? After all, we are building a 32 bit OS! So yeah, set it to 1.
- Bit 7 (Bit 55 in GDT): Granularity. By setting it to 1, each segment will be bounded by 4KB.

The last byte is bits 24-32 of the base (starting) address, which is of course, 0.

That's all there is to it!

#### Breaking Down the Data Descriptor ####

Okay then, go back up to the GDT we made and compare the code and data descriptors. **They are exactly the same, except for one single bit, bit 43. If it's set to 1, it's a code descriptor. If it's set to 0, it's a data descriptor.

#### Conclusion ####

This is the most comprehensive GDT description I have ever seen (and written)! That's a good thing though, right?

Okay, okay. I know, the GDT is ugly. Loading it for use is very easy though, so it has benefits! Actually, all you need to do is load the address of a pointer.

This GDT pointer stores the size of the GDT (**minus one!**) and the beginning address of the GDT. For example:

	toc:
			dw		end_of_gdt - gdt_data - 1	; Limit (Size of GDT)
			dd 		gdt_data					; Base of GDT
			
**gdt_data** is the beginning of the GDT. **end\_of\_gdt** is, of course, a label at the end of the GDT. Notice the size of the pointer and note its format. **The GDT pointer must follow this format**. Not doing so will cause unpredictable results. Most likely, a triple fault.

The processor uses a special register -- GDTR, that stores the data within the base GDT pointer.  To load the GDT into the GDTR register, we need a special instruction. LGDT (Load GDT). It's very easy to use:

			lgdt	[toc]						; Load GDT into GDTR
			
This is not a joke, it really is that simple. Not much times you actually get nice breaks like this one in OS development. Enjoy it while it lasts!

### Local Descriptor Table ###

The *Local Descriptor Table (LDT)* is a smaller form of the GDT, defined for specialized uses. It doesn't define the entire memory map of the system, but instead, only up to 8192 memory segments. We will go into this more in depth later, as it doesn't have anything to do with protected mode. Cool?

### Interrupt Descriptor Table ###

THIS will be important. Not yet, though. The *Interrupt Descriptor Table (IDT)* defines the Interrupt Vector Table (IVT). It always resides from address 0x0 to 0x3FF. The first 32 vectors are reserved for hardware exceptions generated by the processor. For example, a **General Protection Fault** or a **Double Fault Exception**. this allows us to trap processor errors without triple faulting. More on this later.

The other interrupt vectors are mapped through a **Programmable Interrupt Controller** chip on the motherboard. we will need to program this chip directly while in protected mode. More on this later.

# PMode Memory Addressing #

Remember that *PMode* (Protected Mode) uses a different addressing scheme then real mode. Real mode uses the **segment:offset** memory model. However, PMode uses the **descriptor:offset** model.

This means, in order to access memory in PMode, we have to go through the correct descriptor in the GDT. The descriptor is stored in CS. This allows us to indirectly reference memory within the current descriptor.

For example, if we need to read from a memory location, we do not need to describe what descriptor to use; it will use the one that is currently in CS. So, this will work:

			mov		bx, byte [0x1000]
			
This is great, but sometimes we need to reference a specific descriptor. For example, Real Mode doesn't use a GDT, while PMode requires it. Because of this, when entering protected mode, **we need to select what descriptor to use** to continue execution in protected mode. After all, because real mode doesn't know what a GDT is, there's no guarantee that CS will contain the correct descriptor. We need to set it.

To do this, we need to set the descriptor directly:

			jmp		0x8:Stage2
			
You will see this code again. Remember that the first number is the **descriptor** (remember, PMode uses descriptor:address memory model)

You might be curious about where the 0x8 came from. Please look back at the GDT. **Remember that each descriptor is 8 bytes in size**. Because our *code descriptor* is 8 bytes from the start of the GDT, we need to offset 0x8 bytes in the GDT.

**Understanding this memory model is very important to understand how protected mode works**.

# Entering Protected Mode #

To enter protected mode is fairly simple. At the same time, it can be a complete pain. To enter protected mode, we have to load a new GDT which describes permission levels when accessing memory. We then need to actually switch the processor into protected mode and jump into the 32 bit world. Sounds easy, don't you think?

The problem is in the details. **One little mistake can triple fault the processor**. In other words, watch out!

## Step 1: Load the Global Descriptor Table ##

Remember that the GDT describes how we can access memory. If we do not set a GDT, the default GDT will be used (which is set by the BIOS; not the ROM BIOS). As you can imagine, this is by no means standard among BIOSes. **If we don't watch the limitations of the GDT (i.e., if we access the code descriptor as data), the processor will generate a General Protection Fault (GPF). Because no interrupt handler is set, the processor will also generate a second fault exception, which leads to a triple fault**.

Anyway... Basically, all we need to do is create the table. For example:

	; Offset 0 in GDT: Descriptor code = 0
	
	gdt_data:
			dd		0							; Null descriptor
			dd		0
			
	; Offset 0x8 bytes from start of GDT: Descriptor code therefore is 8
	
	; gdt code:									; Code Descriptor
			dw		0xFFFF						; Limit low
			dw		0							; Base low
			db		0							; Base middle
			db		10011010b					; Access
			db		11001111b					; Granularity
			db		0							; Base high
			
	; Offset 0x10 bytes from start of GDT: Descriptor code therefore is 16
	; gdt data:									; Data Descriptor
			dw		0xFFFF						; Limit low
			dw		0							; Base low
			db		0							; Base middle
			db		10010010b					; Access
			db		11001111b					; Granularity
			db		0							; Base high
	
	;...Other descriptors begin at offset 0x18. Remember that each descriptor is 8 bytes in size?
	; Add other descriptors for ring 3 applications, stack, whatever here.
	
	end_of_gdt:
	toc:
			dw		end_of_gdt - gdt_data - 1	; Limit (Size of GDT)
			dd		gdt_data					; Base of GDT
			
This will do for now. Notice **toc**. This is the pointer to the table. The first word in the pointer is the size if the GDT - 1. The second dword is the actual address of the GDT. **This pointer must follow this format. Do NOT forget to subtract the 1!**

We use a special ring 0-only instruction - LGDT, to load the GDT (based on this pointer) into the GDTR register. It's a single, simple, one line instruction:

			cli									; Make sure to clear interrupts first!
			lgdt	[toc]						; Load GDT into GDTR
			sti									; Re-enable interrupts
			
That's simple, huh? Now, onto protected mode! Um, oh yeah, here's GDT.inc to hide all the ugly GDT stuff:

	;**********************************************
	;		stdio.inc
	;				-Input/Output routines
	;
	;		OS Development Series
	;**********************************************

	%ifndef __GDT_INC_67343546FDCC56AAB872_INCLUDED__
	%define __GDT_INC_67343546FDCC56AAB872_INCLUDED__
	
	;**********************************************
	;		InstallGDT ()
	;				-Installs our GDT
	;**********************************************

	InstallGDT:
			cli									; Clear interrupts
			pusha								; Save registers by pushing them on the stack
			lgdt	[toc]						; Load GDT into GDTR
			sti									; Enable interrupts
			popa								; Restore registers by popping them from the stack
			ret									; Done, return
			
	;**********************************************
	; Global Descriptor Table
	;**********************************************

	gdt_data:
			dd		0							; Null descriptor
			dd		0
			
	; Code Descriptor
			dw		0xFFFF						; Limit low
			dw		0							; Base low
			db		0							; Base middle
			db		10011010b					; Access
			db		11001111b					; Granularity
			db		0							; Base high
			
	; Data Descriptor
			dw		0xFFFF						; Limit low
			dw		0							; Base low
			db		0							; Base middle
			db		10010010b					; Access
			db		11001111b					; Granularity
			db		0							; Base high
			
	end_of_gdt:
	toc:
			dw		end_of_gdt - gdt_data - 1	; Limit (size of GDT)
			dd		gdt_data					; Base of GDT
			
	%endif ; __GDT_INC_67343546FDCC56AAB872_INCLUDED__
	
## Step 2: Entering protected mode ##

Remember that bit table of the CR0 register? What was it? Oh yeah...

- Bit 0 (PE): Puts the system into protected mode
- Bit 1 (MP): Monitor co-processor flag. This controls the operation of the WAIT instruction
- Bit 2 (EM): Emulate flag. When set, co-processor instructions will generate an exception
- Bit 3 (TS): Task switched flag. This will be set when the processor switches to another task
- Bit 4 (ET): Extension type flag. This tells us what type of co-processor is installed.
	- 0: 80287 is installed
	- 1: 80387 is installed
- Bit 5: Unused
- Bit 6 (PG): Enable memory paging

The important bit is bit 0. **By setting bit 0, the processor continues execution in a 32 bit state**. That is, **setting bit 0 enables protected mode**.

Here's an example:

			mov		eax, cr0					; Copy CR0 into EAX
			or		eax, 1						; Set bit 0 to 1, go to PMode
			mov		cr0, eax					; Copy EAX into CR0
			
That's it! If bit 0 is set, Bochs Emulator will know you are in protected mode (PMode).

Remember: the code is still 16 bits until you specify **bits 32**. As long as your code is in 16 bit, you can use segment:offset memory model.

**Warning! Ensure interrupts are DISABLED before going into the 32 bit code! If it is enabled, the processor will triple fault**. (Remember, we can't access IVT from PMode?)

After entering protected mode, we run into an immediate problem. Remember that, in real mode, we used the *segment:offset* memory model? However, protected mode relies on the *descriptor:address* memory model.

Also, remember that real mode does not know what a GDT is. While in PMode, the use of it is **Required** because of the addressing mode. Because of this, in real mode, CS still contains the last segment address used, **not the descriptor to use**.

Remember that PMode uses CS to store the current code descriptor? So, in order to fix CS (so that it's set to our code descriptor) we need to **far jump**, using our code descriptor.

Because our code descriptor is 0x8 (8 bytes offset from the start of the GDT), just jump like so:

			jmp		0x8:Stage3					; Far jump to fix CS. Remember that the code descriptor is 0x8!

Also, once in PMode, we have to reset all of the registers (as they are incorrect) to their correct descriptor numbers.

			mov		ax, 0x10					; Set the accumulator to the data descriptor offset
			mov		ds, ax						; Set data segment to ax
			mov		ss, ax						; Set stack segment to ax
			mov		es, ax						; Set extra segment (heap) to ax
			
Remember that our data descriptor was 16 (0x10) bytes from the start of the GDT?

You might be curious at why all of the three references inside the GDT (to select the descriptor) are offsets. Offsets of what? Remember the GDT pointer that we loaded in via the **LGDT** instruction? The processor bases all offset addresses off of the base address that we set the GDT pointer to point to.

Here's the entire Stage 2 bootloader in its entirety:

	;**********************************************
	;		stage2.asm
	;
	;		OS Development Series
	;**********************************************

	bits	16
	
	; Remember the memory map -- 0x500 through 0x7bff is unused above the BIOS data area.
	; We are loaded at 0x500 (0x50:0)
	
	org		0x500
	
	jmp		main								; Go to start
	
	;**********************************************
	;		Preprocessor Directives
	;**********************************************
	
	%include 	"stdio.inc"						; Basic I/O routines
	%include 	"gdt.inc"						; GDT routines
	
	;**********************************************
	;		Data Section
	;**********************************************

	msgLoading		db "Preparing to load operation system...", 13, 10, 0

	;**********************************************
	;		STAGE 2 ENTRY POINT
	;
	;				-Store BIOS information
	;				-Load Kernel
	;				-Install GDT; go into protected mode (pmode)
	;				-Jump to Stage 3
	;**********************************************

	main:
			;-------------------------------;
			;	Setup segments and stack    ;
			;-------------------------------;
			
			cli									; Clear interrupts
			xor		ax, ax						; Null segments
			mov		ds, ax
			mov		es, ax
			mov		ax, 0x9000					; Begin stack at 0x9000
			mov		ss, ax
			mov		sp, 0xFFFF
			sti									; Enable interrupts
			
			;-------------------------------;
			;	Print loading message	    ;
			;-------------------------------;

			mov		si, msgLoading
			call	Puts16

			;-------------------------------;
			;	Install our GDT			    ;
			;-------------------------------;
			
			call InstallGDT					; Install our GDT
			
			;-------------------------------;
			;	Switch to Protected Mode    ;
			;-------------------------------;

			cli									; Clear interrupts, will generate TF if not turned off
			mov		eax, cr0					; Copy CR0 into EAX
			or		eax, 1						; Set bit 0 to 1, go to PMode
			mov		cr0, eax					; Copy EAX into CR0
			
			jmp		0x8:Stage3					; Far jump to fix CS. Remember that the code descriptor is 0x8!
			
			; Note: To NOT re-enable interrupts! Doing so will triple fault!
			; We will fix this in Stage 3.
			
	;**********************************************
	;		STAGE 3 ENTRY POINT
	;**********************************************
	
	bits 	32									; Welcome to the 32 bit world!
	
	Stage3:
	
			;-------------------------------;
			;	Set Registers 			    ;
			;-------------------------------;

			mov		ax, 0x10					; Copy the address of data descriptor to accumulator (0x10)
			mov		ds, ax						; Set data segment to data descriptor
			mov		ss, ax						; Set stack segment to data descriptor
			mov		es, ax						; Set extra segment (heap) to data descriptor
			mov		esp, 0x90000				; Stack begins from 0x90000
			
	;**********************************************
	;		Stop execution
	;**********************************************

	STOP:
			cli
			hlt
			
# Conclusion #

I'm excited, are you? We went over a lot in this tutorial. We talked about the GDT, descriptor tables and getting into protected mode.

**Welcome to the 32 bit world!**

This is great for us. Most compilers only generate 32 bit code so protected mode is necessary. Now, we would be able to execute the 32 bit programs written from almost any language - C or assembly.

We are not done with the 16 bit world yet though. In the next tutorial, we are going to get BIOS information and loading the kernel through FAT12. This also means, of course, we will create a small little stub kernel. Cool, huh?

Hope to see you there!

Until next time.