# Introduction #

Welcome! :)

Well, we have finally made it to the most important part of any operating system: the **kernel**.

We have heard this term a lot so far throughout the series already. The reason is because of how important it really is.

The kernel is the core of all operating systems. Understanding what it is and how it affects the operating system is important.

In this tutorial, we will look at what goes behind kernels, what they are and what they are responsible for. Understanding these concepts is essential in coming up with a good design.

*Ready?*

# Kernel: Basic Definition #

In order to understand what an OS **kernel** is, we need to first understand what a *kernel* is at its basic definition. Dictionaries define *kernel* as **core**, **essential part** or even **the body of something**. When applying this definition to an operating system environment, we can easily state that **the kernel is the core component of an operating system**.

Okay, but what does this mean for us? What exactly is an OS kernel and why should we care for it?

There is no rule that states a kernel is mandatory. We can easily just load and execute programs at specific addresses without any *kernel*. In fact, all of the early computer systems started this way. Some modern systems also use this. A notable example of this are the early video game consoles, which required **rebooting** the system in order to execute *one* of the games designed for that console.

So, what is the point of a kernel? In a computing environment, it is impractical to restart every time to execute a program. This means that each program itself would need its own bootloader and direct hardware controller. After all, if the programs need to be executed at boot-up, there would be no need for an operating system.

What we need is an abstraction layer to provide the capability of executing multiple programs and manage their memory allocations. It can also provide an abstraction to the hardware, which will not be possible if each program had to start on boot-up without an OS. After all, the software will be running on raw hardware.

The keyword here is **abstraction**. Let's look closer...

# The Need For Kernel #

The kernel provides the primary abstraction layer to the hardware itself. The kernel is usually at ring 0 because of this very reason: **it has direct control over every little thing**. Because we are still at ring 0, we already experienced this.

This is good, but what about our software? Remember that we are developing an **operating environment**? Our primary goal is to provide a safe and effective environment for applications and other software to execute. If we let all software run at ring 0 alongside the kernel, there would be no need for a kernel, would it? If there was, **the ring 0 software may conflict with the ring 0 kernel**, causing unpredictable results. After all, they all have complete control over every byte in the system. Any software can overwrite the kernel or any other software without any problems. Ouch!

Yet, that is only the beginning of the problems. It's impossible to have multitasking or multiprocessing as there is no common ground to switch between programs and progresses. Only one program can execute at a time.

The basic idea is that a kernel is a necessity. Not only we want to *prevent* other software from controlling everything but we want to create an *abstraction layer* for it.

Understanding where and how the kernel fits in with the rest of the system is very important.

# Abstraction Layers of Software #

Software has a lot of abstractions. All of these abstractions are meant to provide a core and basic interface to hide implementation details, but more importantly, *shield* you from it. Having direct control over everything might seem cool, but imagine how much problems would be caused by doing this.

You might be curious as to what kind of problems I'm referring to. Remember that, at its core, electronics do only what we tell it to do. We can control the software down to the *hardware* level and, in some cases, *electronics* level. Making a mistake at these levels can cause physical damage to those devices.

Let's take a look at each abstraction layer to understand what I mean and where our kernel fits in.

## Relationship with PMode Protection Ring Levels ##

In the **Bootloaders 3 tutorial**, we took a detailed look at the rings of assembly language. We also looked at how this related to *protected mode*.

Remember that **ring 0 software has the lowest protection level**. This means that we have direct control over everything and we are **expected** to never crash. If **any** ring 0 program crash, it will take the system down with it (Triple Fault).

Because of this, we want to *shield* everything else from direct control, and give software the protection level needed to run. Here's an idea of what levels are used for:

- Kernels work in ring 0 (supervisor mode)
- Device drivers work in ring 1 and 2, as they require direct access to hardware devices
- Normal application software run in ring 3 (user mode)

Okay, *how* does this all fit together? Let's take a closer look.

## Level 1: Hardware Level ##

This is the physical component, the actual micro-controller on the motherboard. They send low level commands to other micro-controllers on other devices that physically controls the device. How? We will look at that in level 2.

Examples of hardware are the micro-controller chipset (the *motherboard chipset*), disk drives, SATA, IDE, hard drives, memory, the processor (which is also a controller, refer to level 2 for more information), etc.

This is the lowest level and the most detailed as it is pure electronics.

## Level 2: Firmware Level ##

The firmware sets on top of the electronics level. It contains the software needed by each hardware device and micro-controller. One example of firmware is the BIOS POST.

Remember that the processor itself is nothing more than a controller. And just like other controllers, relies on its firmware. The **instruction decoder** within the processor dissects a single machine instruction into either *macrocode* or directly to *microcode*. Please see **Tutorial 7: System Architecture** for more information.

### Microcode ###

Firmware is usually developed using microcode and either assembled (with a micro-assembler) and uploaded into a storage area (such as the BIOS POST) or hardwired into the logic circuits of the device through various means.

Microcode is usually stored within a ROM chip, such as EEPROM.

Microcode is very hardware specific. Whenever there is a new change or revision, a new microcode instruction set and micro-assembler needs to be developed. On some systems, microcode has been used to control individual electronic gates and switches with the circuit. Yes, it's that low level.

### Macrocode ###

Microcode is **very** low level and can be **very** hard to develop with, especially in complex systems such as a microprocessor or CPU. It also must be re-implemented whenever a change happens. Not only the code, but the micro-programs as well.

Because of this, some systems have implemented a higher level language called **macrocode** on top of microcode. Because of this abstraction layer, macrocode changes less frequently than microcode and is more portable. Also, due to its abstraction layer, is easier to work with.

However, it's still very low level. It's used as internal logic instruction set to convert higher level machine language into microcode, which is translated by the instruction decoder.

## Level 3: Ring 0 - Kernel Level ##

This is where we are at. The stage 2 bootloader's only focus was to set everything up so that our kernel has an environment to run in.

Our kernel provides the abstraction between device drivers, application software and the firmware the hardware uses.

## Level 4: Ring 1 and 2 - Device Drivers ##

Device drivers go through the kernel to access the hardware. Device drivers need a lot of freedom and control because they require direct control over specific micro-controllers. However, having **too much** control can crash the system. For example, what would happen if a driver modified the GDT or set up its own? Doing so will immediately crash the kernel. Because of this, we will want to make sure these drivers cannot use **LGDT** to load its own GDT. **This is why we want drivers to operate at either ring 1 or ring 2, not ring 0**.

For example, a **keyboard device driver** will need to provide the interface between application software and the keyboard micro-controller. The driver may be loaded by the kernel as a library providing the routines to indirectly access the controller.

As long as there is a standard interface used, we can provide a very portable kernel, as long as we hide all hardware dependencies.

## Level 5: Ring 3 - Application Level ##

This is where the software is at. It uses the interfaces provided by the system API and device driver interfaces. Normally, they do not access the kernel directly.

## Conclusion ##

This series will be developing drivers during the development of the kernel. This will allow us to keep things object-oriented and provide an abstraction layer for the kernel.

With that in mind, notice where we are at, **Level 0**. All other programs rely on the kernel. Why? Let's take a look at the kernel.

# The Kernel #

Because the kernel is the core component, it needs to provide the management for everything that relies on it. **The primary purpose of the kernel is to manage system resources and provide an interface so other programs can access these resources**. In a lot of cases, the kernel itself is unable to use the interface it provides to other resources. **It has been stated that the kernel is the most complex and difficult task in programming**.

This implies that designing and implementing a good kernel is very difficult.

In tutorial 2, we took a brief look at different past operating systems. We have bolded a lot of new terms inside that tutorial and have compiled a list of those terms at the end of it. This is where that list starts to get implemented.

Let's first look at that list again and look at how it's related to the kernel. Everything **bolded** is handled by the kernel:

- **Memory management**
- **Program management**
- **Multitasking**
- **Memory protection**
- Fixed base address (covered in Tutorial 2)
- Multi-user - This is usually implemented by a shell
- **Kernel** (Duh! ;))
- **File System**
- Command shell
- Graphical User Interface (GUI)
- Graphical shell
- Linear Block Addressing (LBA) (covered in Tutorial 2)
- Bootloader (Completed)

Some of the above can be implemented as separate drivers, used by the kernel. For example, Windows uses **ntfs.sys** as an NTFS file system driver.

This list should look familiar from Tutorial 2. We have also covered some of these terms. Let's look at the **bolded** terms and see how they relate to the kernel. We will also look at some new concepts.

## Memory Management ##

This is quite possibly the most important part of any kernel and rightfully so. All programs and data require it. As you know, in the kernel, because we are still in **supervisor mode** (ring 0), **we have direct access to every byte in memory**. This is very powerful, but also produces problems, especially in a multitasking environment, where multiple programs and data require memory.

One of the primary problems we have to solve is: what do we do when we run out of memory?

Another problem is *fragmentation*. **It's not always possible to load a file or program into a sequential area of memory**. For example, let's say we have 2 programs loaded; one at 0x0 and the other a 0x900. Both of these programs requested to load files, so we load the data files:

![Memory Schema](http://www.brokenthorn.com/Resources/images/MemFrag.gif)

Notice what is happening here. There is a lot of unused memory between all of these program and files. Okay, what happens if we add a bigger file that is unable to fit in? This is when big problem arise with the current scheme. We can't manipulate memory directly in any specific way, as it will corrupt the currently executing programs and loaded files.

Then, there's the problem of where each program is loaded at. Each program will be required to be *position independent* or to provide *relocation tables*. Without this, we will not know what base address the program is supposed to be loaded at.

Let's look at these deeper. Remember the **org** directive? This directive sets the location where your program is expected to load from. By loading the program at a different location, the program will reference incorrect addresses and will crash. We can easily test this theory. Right now, stage 2 expects to be loaded at 0x500. However, if we load it at 0x400 within stage 1 (while keeping the **org 0x500** within stage 2), a triple fault will occur.

This adds on two new problems. How do we know where to load a program at? Since all we have is binary images, we **cannot** know. However, if we make it standard that all programs begin at the same address; let's say, 0x0, then we can know. This would work, but is impossible to implement if we plan to support multitasking. **However, if we give each program their own memory space, that virtually begins at 0x0, this will work**. After all, from each program's perspective, they are all loaded at the same base address, even if they are different in the real (physical) memory.

What we need is some way to abstract the physical memory. Let's look closer.

### Virtual Address Space (VAS) ###

A **virtual address space** is a **program's address space**. One needs to take note that this does **not** have to do with **system memory**. The idea is **so that each program has their own independent address space. This makes sure that one program cannot access another program, because they are using a different address space**.

Because **VAS** is **virtual** and not directly used with the physical memory, it allows the use of other sources, such as disk drives, as if it was memory. That is, **it allows us to use more memory than what is physically installed in the system**.

This fixes the *Not enough memory* problem.

Also, as each program uses its own **VAS**, we can have each program always begin at base 0x0000:0000. This solves the relocation problem discussed earlier, as well as memory fragmentation, as we no longer need to worry about allocating continuous physical blocks of memory for each program.

**Virtual addresses are mapped by the kernel through the MMU. More on this later**.

### Virtual Memory: Abstract ###

**Virtual memory** is a special **memory addressing scheme** implemented by both the hardware and software. It allows non-contiguous memory to act as if it was contiguous.

Virtual memory is based off the **virtual address space** concepts. It provides every program its own virtual address space, allowing memory protection and decreasing memory fragmentation.

Virtual memory also provides a way to indirectly use more memory than we actually have within the system. One common way of approaching this is by using **page files**, stored on the **hard drive**.

Virtual memory needs to be mapped through a hardware device controller in order to work, as it's handled at the hardware level. This is normally done through the **MMU**, which we will look at later.

For an example of seeing virtual memory in use, let's look at it in action:

![Virtual Address demo](http://www.brokenthorn.com/Resources/images/virtual-memory[1].png)

Notice what's going on here. Each memory block within the **virtual addresses** are linear. Each memory block is *mapped* to either its location within the real physical RAM or another device, such as the hard disk. The blocks are swapped between these devices as an *as needed* basis. This might seem slow, but it's very fast, thanks to the MMU.

**Remember: each program will have its own virtual address space, shown above**. Because each address space is linear and begins at 0x0000:0000, this immediately fixes a lot of problems relating to memory fragmentation and program relocation issues.

Also, because virtual memory uses different devices in using memory blocks, it can easily manage more than the amount of memory within the system, i.e., if there's no more system memory, we can allocate blocks on the hard drive instead. If we run out of memory, we can either increase this page file on an *as needed* basis or display a warning/error message.

Each memory *block* is known as a **page**, which is usually **4096 bytes (4KB)** in size.

Once again, we'll cover everything in much detail later.

### Memory Management Unit (MMU): Abstract ###

My, oh my, where have we heard this term before? o.O :)

The MMU, also known as **Paged Memory Management Unit (PMMU)** is a component inside the microprocessor responsible for the management of the memory requested by the CPU. It has a number of responsibilities, including **translating virtual addresses to physical addresses, memory protection, cache control and more**.

### Segmentation: Abstract ###

Segmentation is a method of **memory protection**. In segmentation, we allocate a certain address space from the currently running program. This is done through the **hardware registers**.

Segmentation is one of the most widely used memory protection scheme. On the x86, it's usually handled by the **segment registers**: CS, SS, DS and ES.

We have seen the use of this through real mode.

### Paging: Abstract ###

THIS will be important to us. Paging is the process of managing program access to the virtual memory mode pages that are not in RAM. We will cover this a lot more later.

## Program Management ##

THIS is where the rig levels start becoming important.

As you know, our kernel is at ring 0, while the applications are at ring 3. This is good, as it prevents the applications direct access to certain system resources. This is also bad, as a lot of these resources are needed by the applications.

You might be curious on how the processor knows what ring level it's in and how we can switch ring levels. The processor simply uses an internal flag to store the current ring level. Okay, but how does the processor know what ring to execute the code in?

This is where the **GDT** and **LDT** become important.

As you know, in real mode, there's no protection level. Because of this, everything is *ring 0*. Remember that **we have to setup a GDT prior to going into protected mode?** Also, remember that we needed to execute a **far jump** to enter the 32 bit mode. Let's go over this in more detail here, as they will play very important roles here.

### Supervisor Mode ###

Ring 0 is known as **supervisor mode**. It has access to every instruction, register, table and other more privileged resources that no other applications with higher ring levels can access.

Ring 0 is also known as **kernel level** and is **expected** to never fail. If a ring 0 program crashes, it will take the system down with it. Remember that: ***"With great power comes great responsibility"***. This is the primary reason for protected mode.

Supervisor mode utilizes a hardware flag that can be changed by system level software. System level software (ring 0) will have this flag set, while application level software (ring 3) won't.

There's a lot of things that only ring 0 code can do, that ring 3 code cannot. Remember the flags register from Tutorial 7? The **IOPL flag** of the RFLAGS register determines what level is required to execute certain instructions, such as **IN and OUT** instructions. Because the IOPL is usually 0, this means that **only ring 0 programs have direct access to hardware via software ports**. Because of this, we will need to switch back to ring 0 often.

### Kernel Space ###

**Kernel space** refers to a special region of memory that is reserved for the kernel and ring 0 device drivers. In most cases, **kernel space should never be swapped out to disk, like virtual memory**.

If an operating software runs in **user space**, it is often known as "**Userland**".

### User Space ###

This is normally the **ring 3 application programs**. Each application usually executes in its own **virtual address space (VAS)** and can be swapped from different disk devices. **Because each application is within their own virtual memory, they are unable to access another program memory directly**. Because of this, they will be required to go through a ring 0 program to do this. This is necessary for **debuggers**.

Applications are normally the least privileged. Because of this, they usually need to request support from a ring 0 kernel level software to access system resources.

### Switching Protection Levels ###

What we need is a way so that these applications can query the system for these resources. However, to do this, we need to be in ring 0, not ring 3. Because of this, we need a way to switch the processor state from ring 3 to ring 0 and allow applications to query our system.

Remember back in Tutorial 5 we covered the rings of assembly language. Remember that the processor will change the current ring level under these conditions:

- A directed instruction, such as a **far jump, far call, far ret**, etc.
- A **trap** instruction, such as **INT, SYSCALL, SYSEXIT, SYSENTER, SYSRETURN**, etc.
- **Exceptions**

So, in order for an application to execute a system routine (while switching to ring 0), the application must either **far jump**, execute an **interrupt** or use a special instruction, such as **SYSENTER**.

This is great, but how does the processor know what ring level to switch to? This is where the GDT comes into play.

Remember that, in each descriptor of the GDT, we have to setup a **ring level** for each descriptor? In our current GDT, we have 2 descriptors: each for kernel mode ring 0. **This is our kernel space**.

All we need to do is add 2 more descriptors to our current GDT, **but set for ring 3 access. This is our user space**.

Let's take a closer look.

**Remember from tutorial 8 that the important byte here is the access byte!** Because of this, here is the byte pattern again:

- Bit 0 (Bit 40 in GDT): Access bit (used with virtual memory). Because we don't use virtual memory (yet, anyway), we will ignore it. Hence, it's 0
- Bit 1 (Bit 41 in GDT): is the readable/writable bit. It's set (for code selector), so we can read and execute data in the segment (from 0x0 through 0xffff) as code
- Bit 2 (Bit 42 in GDT): is the "expansion direction" bit. We will look more at this later. For now, ignore it.
- Bit 3 (Bit 43 in GDT): tells the processor this is a code or data descriptor. (It's set, so we have a code descriptor)
- Bit 4 (Bit 44 in GDT): represents this as a "system" or "code/data" descriptor. This is a code selector so the bit is set to 1.
- Bits 5-6 (Bits 45-46 in GDT): is the privilege level (i.e., ring 0 or ring 3). We are in ring 0 so both bits are 0.
- Bit 7 (Bit 47 in GDT): used to indicate the segment in memory (used with virtual memory). Set to zero for now, since we are not using virtual memory yet.

Here's the code:

	;*******************************************
	; Global Descriptor Table (GDT)
	;*******************************************
 
	gdt_data: 
 
	; Null descriptor (Offset: 0x0)--Remember each descriptor is 8 bytes!
			dd 0 				; null descriptor
			dd 0 
 
	; Kernel Space code (Offset: 0x8 bytes)
			dw 0FFFFh 			; limit low
			dw 0 				; base low
			db 0 				; base middle
			db 10011010b 		; access - Notice that bits 5 and 6 (privilege level) are 0 for Ring 0
			db 11001111b 		; granularity
			db 0 				; base high
 
	; Kernel Space data (Offset: 16 (0x10) bytes
			dw 0FFFFh 			; limit low (Same as code)10:56 AM 7/8/2007
			dw 0 				; base low
			db 0 				; base middle
			db 10010010b		; access - Notice that bits 5 and 6 (privilege level) are 0 for Ring 0
			db 11001111b		; granularity
			db 0				; base high
 
	; User Space code (Offset: 24 (0x18) bytes)
			dw 0FFFFh 			; limit low
			dw 0 				; base low
			db 0 				; base middle
			db 11111010b		; access - Notice that bits 5 and 6 (privilege level) are 11b for Ring 3
			db 11001111b 		; granularity
			db 0 				; base high
 
	; User Space data (Offset: 32 (0x20) bytes
			dw 0FFFFh 			; limit low (Same as code)10:56 AM 7/8/2007
			dw 0 				; base low
			db 0 				; base middle
			db 11110010b		; access - Notice that bits 5 and 6 (privilege level) are 11b for Ring 3
			db 11001111b 		; granularity
			db 0				; base high
			
Notice what is happening here. All code and data  have the same range values. The only difference is the **ring levels**.

As you know, **protected mode** uses CS to store the **current privilege level (CPL)**. When entering protected mode for the first time, **we needed to switch to ring 0**. Because the value of CS was invalid (from real mode), we need to choose the correct descriptor from the GDT into CS. **Please see tutorial 8 for more information**.

This required a far jump, as we needed to upload a new value into CS. By **far jumping** to a ring 3 descriptor, we can effectively enter a ring 3 state.

As you know, we can use a **INT, SYSCALL/SYSEXIT/SYSENTER/SYSRET, far call or an exception** to have the processor switch back to ring 0.

Let's take a closer look at these methods.

### System API: Abstract ###

The program relies on the system API to access system resources. Most applications reference the system API directly or through their language API, such as the **C runtime library**.

The system API provides the **interface** between applications and system resources through **system calls**.

### Interrupts ###

A **Software interrupt** is a special type of interrupt implemented in software. Interrupts are used quite often and rely on the use of a special table, the **Interrupt Descriptor Table (IDT)**. We will look at interrupts a lot more closer later, as it is the first thing we will implement in our kernel.

Linux uses INT 0x80 for all system calls.

**Interrupts are the most portable way to implement system calls**. Because of this, we will be using interrupts as the first way of invoking a system routine.

### Call Gates ###

Call gates provide a way for ring 3 applications to execute more privileged (ring 0, 1 or 2) code. The **call gate** interfaces between the ring 0 routines and the ring 3 applications and is normally setup by the kernel.

Call gates provide a single gate (entry point) to **far call**. This entry point is defined within the GDT or LDT.

It's much easier to understand a call gate with an example.

    ;*******************************************
    ; Global Descriptor Table (GDT)
    ;*******************************************
    
    gdt_data: 
    
    ; Null descriptor (Offset: 0x0)--Remember each descriptor is 8 bytes!
			dd 0 				; null descriptor
			dd 0 
    
    ; Kernel Space code (Offset: 0x8 bytes)
			dw 0FFFFh 			; limit low
			dw 0 				; base low
			db 0 				; base middle
			db 10011010b		; access - Notice that bits 5 and 6 (privilege level) are 0 for Ring 0
			db 11001111b		; granularity
			db 0 				; base high
    
    ; Kernel Space data (Offset: 16 (0x10) bytes
			dw 0FFFFh 			; limit low (Same as code)10:56 AM 7/8/2007
			dw 0 				; base low
			db 0 				; base middle
			db 10010010b		; access - Notice that bits 5 and 6 (privilege level) are 0 for Ring 0
			db 11001111b		; granularity
			db 0				; base high
    
    ; Call gate (Offset: 24 (0x18) bytes
    
    CallGate1:
			dw (Gate1 & 0xFFFF)	; limit low address of gate routine
			dw 0x8				; code segment selector
			db 0				; base middle
			db 11101100b		; access - Notice that bits 5 and 6 (privilege level) are 11 for Ring 3
			db 0				; granularity
			db (Gate1 >> 16)	; base high of gate routine
    
    ; End of the GDT. Define the routine wherever
    
    ; The call gate routine
    
    Gate1:
			; do something special here at Ring 3
			retf			; far return back to calling routine
			
The above is an example of a call gate.

To execute the call gate, we offset from the **descriptor code** within the GDT. Notice how similar this is from our **jmp 0x8:Stage2** instruction?

	; execute the call gate
			call far	0x18:0	; far calls -- calls our Gate1 routine
			
Call gates are not used too often in modern operating systems. One of the reasons is that most architectures don't support call gates. They are also quite slow, as they require **far call** and **far ret** instructions.

On systems where the GDT is not in protected memory, it's also possible for other programs to create their own call gates to raise its protection level (and get ring 0 access). They have also been known to have security issues. One notable worm, for example, is **Gurong**, which installs its own call gate in the Windows Operating system.

### SYSENTER / SYSEXIT Instructions ###

These instructions were introduced from the Pentium II and later CPUs. Some recent AMD processors also support these instructions.

**SYSENTER** can be executed by any application. **SYSRET** can only be executed by ring 0 programs.

These instructions are used as a fast way to transfer control from a user mode (ring 3) to a privileged mode (ring 0) and back quickly. This allows a fast and safe way to execute system routines from user mode.

**These instructions directly rely on the Model Specific Registers (MSRs). Please see tutorial 7 for an explanation of MSRs and the RDMSR and WRMSR instructions.**

#### SYSENTER ####

The **SYSENTER** instruction automatically sets the following registers to their locations defined within the MSR:

- CS = IA32\_SYSENTER\_CS MSR + the value 8
- ESP = IA32\_SYSENTER\_ESP MSR
- EIP = IA32\_SYSENTER\_IP MSR
- SS = IA32\_SYSENTER\_SS MSR

This instruction is only used to transfer control from a ring 3 code to ring 0. At startup, we will need to set these MSRs to point to a **starting location**, which will be our **syscall entry point** for all system calls.

Let's take a look at SYSEXIT.

#### SYSEXIT ####

The **SYSEXIT** instruction auomatically sets the following registers to their locations defined within the  MSR:

- CS = IA32\_SYSENTER\_CS MSR + the value 16
- ESP = ECX register
- EIP = EDX register
- SS = IA32\_SYSENTER\_CS MSR + 24

#### Using SYSENTER/SYSEXIT ####

Okay, using these instructions might seem complicated but they're not too hard.

Because SYSENTER and SYSEXIT require that the MSRs are set up *prior* to calling them, we first need to initialize those MSRs.

**Remember that IA32\_SYSENTER\_CS is index 0x174, IA32\_SYSENTER\_ESP is 0x175 and IA32\_SYSENTER\_IP is 0x176 within the MSR. Remember tutorial 7?**

Knowing this, let's set them up for SYSENTER:

			%define IA32_SYSENTER_CS		0x174
			%define IA32_SYSENTER_ESP	0x175
			%define IA32_SYSENTER_EIP	0x176
			
			mov		eax, 0x8
			mov		edx, 0
			mov		ecx, IA32_SYSENTER_CS
			wrmsr
			
			mov		eax, esp
			mov		edx, 0
			mov		ecx, IA32_SYSENTER_ESP
			wrmsr
			
			mov		eax, SYSENTER_Entry
			mov		edx, 0
			mov		ecx, IA32_SYSENTER_EIP
			wrmsr
			
			; Now, we can use sysenter to execute SYSENTER_Entry at ring 0 from either a ring 0 program or ring 3:
			sysenter
			
	SYSENTER_Entry:

			; sysenter jumps here, it's executing this code at privilege level 0. Similar to call gates, normally we will
			; provide a single entry point for all system calls.
			
If the code that executes sysenter is at ring 3 and SYSENTER_Entry is at protection level 0, the processor will switch mode within the SYSENTER instruction.

In the above code, both are at protection level 0, so the processor will just call the routine without changing modes.

As you can see, there's a bit of work that must be done prior to calling SYSENTER and SYSEXIT.

**SYSENTER and SYSEXIT are not portable**. Because of this, it is wise to implement another, more portable, method alongside SYSENTER/SYSEXIT.

### SYSCALL / SYSRET Instructions ###

*[I plan on adding a special section for SYSCALL and SYSRET here soon]*

### Error Handling ###

What do we do if a program causes a problem? How will we know what the problem is and how to handle it?

Normally, this is done by means of **exception handling**. Whenever the processor enters an invalid state caused by an invalid instruction, like divide by 0, the processor triggers an **Interrupt Service Routine (ISR)**. If you have mapped your own ISRs, it will call our routines.

The ISR called depends on what the problem was. This is great, as we know what the problem is and can try to find the program that originally caused the problem.

One way of doing this is simply getting the last program that you have given processor time to. This is guaranteed to be the one that has generated the ISR.

Once you have the program information, then one can either output or attempt to shutdown the program.

**IRQs are mapped by the internal programmable interrupt controller (PIC) inside the processor. They are mapped to interrupt entries within the interrupt descriptor table (IDT). This is the first thing we will work on inside the kernel, so we will cover everything later.**

# Conclusion #

We looked at a lot of different concepts in this tutorial, ranging from kernel theory, memory management concepts, virtual memory addressing (VMA) and program management, including separating ring 0 from ring 3 and providing the interface between applications and system software. Whew! That's a lot, don't you think?

A lot of concepts in this tutorial may be new to you, don't worry. This is more of a "get your feet wet" tutorial, where we cover all the basic concepts related to kernels.

This tutorial has barely scratched the surface of what a kernel must do. That is a start, though. :)

In the next tutorial, we are going to look at kernels from a different perspective. We will cover some new concepts yet again and talk about kernel designs and implementations. Afterwards, we will start building our compilers and toolchains to work with C and C++. Sounds fun?

I am currently using C++ with Xcode 5.1 for my kernel.

We will also finish off other concepts that we have not looked at here, including **multitasking, TSS, Filesystems** and more. *It's going to be fun! :)*

Until next time,

Simon