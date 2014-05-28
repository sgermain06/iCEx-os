This series is intended to demonstrate and teach operating system development from the ground up.

#Introduction#

Welcome! :) In the previous tutorial, we **finally** finished the bootloader (yay!), for now, anyway.

We covered the FAT12 file system in detail and looked at loading, parsing and executing stage 2.

This tutorial will continue where the last one left off. We are going to first look at the x86 architecture in detail. This will be important to us, especially in protected mode, understanding how protected mode works.

We are going to cover every single aspect of how the computer works and operates, down at the bit level. To understand how this fits in with the BIOS during bootup,you have to remember that you can "start" other processors. The BIOS does just this with the main processor and we can do the same to support multi-processor systems.

We will cover:

- The 80x86 registers
- System organization
- The system bus
- Real mode memory map
- How an instruction executes
- Software ports

In some way, this is like a system architecture tutorial. However, we are going to look at the architecture from an OS development point of view. **Also we will cover every single thing within the architecture.**

Understanding the basic concepts will make understanding **Protected Mode** a lot easier and a lot more in depth. In the next tutorial, we are going to use everything we learn here to switch to protected mode.

*Lets have some fun, shall we?*

#The World of Protected Mode#

We all heard this term before, haven't we? Protected mode (PMode) is an operation mode available from the 80286 processor and later. PMode was primarily designed to increase the stability of the system.

As you know from previous tutorials, Real Mode has some significant drawbacks. For one, we can write a byte anywhere we want. This can overwrite code or data, that may be used by software ports, the processor or even our own code! And yet, we can do this in over 4,000 different ways; both directly and indirectly.

- No **Memory Protection**. All data and code are dumped into a single all-purpose memory block.
- You are limited to 16bits registers. Because of this, you are also limited to accessing only 1MB of memory.
- No support for hardware level Memory Protection or Multitasking
	
Quite possibly, the biggest flaw is that there is no such thing as "rings". All programs execute at Ring 0, as every program has full control over the system. This means, in a single tasking environment, a single instruction (such as **cli/hlt**) can crash the entire OS, if you are not careful.

A lot of this should sound familiar from when we covered real mode in depth. Protected mode fixes all of these problems.

Protected Mode:

- Has **memory protection**.
- Has hardware support for **Virtual Memory** and **Task State Switching (TSS)**.
- Hardware support for interrupting programs and executing another.
- 4 Operating modes: Ring 0, 1, 2 and 3.
- Access to 32bits registers.
- Access to up to 4GB of memory.

We covered the rings of assembly language in a previous tutorial. Remember that **we are in Ring 0, while normal applications are in Ring 3 (usually)**. We have access to special instructions that normal applications do not. In this tutorial, we will be using the **LGDT** instruction, along with a **far jump** using our own defined segment and the use of the **processor control registers**. None of this is available in normal programs.

Understanding the system architecture and how the processor works will help us understand this a lot better.

# System Architecture #

The x86 family of computers follow the *Van Nuemann Architecture*. The Van Nuemann Architecture is a design specification that states a typical computer has three main components:
- Central Processing Unit (CPU)
- Memory
- Input/Output (IO)

For example:

![System Architecture](http://www.brokenthorn.com/Resources/images/Arch.jpg)

There are a couple of important things to note. As you know, the CPU fetches data and instructions from the memory. The memory controller is responsible for calculating the exact RAM chip and memory cell that it resides in. Because of this, **the CPU communicates with the memory controller**.

Also, notice the "I/O Devices". They are connected to the system bus. **All I/O ports are mapped to a given memory location. This allows us to use the IN and OUT instructions**.

The hardware devices can access memory through the System Bus. It also allows us to notify a device when something is happening. For example, if we write a byte to a memory location for a **hardware device controller** to read, **the processor can signal the device that there is data at that address**. It does this through the *Control Bus* part of the entire *System Bus*. This is basically how software interacts with hardware devices. We will go into much more detail later, as this is the *only* way to communicate with devices in protected mode. **This is important**.

We will cover everything in detail first. Then, we will combine them and learn how they all work together by watching an instruction get executed at the hardware level. From here, we will talk about I/O ports and how software interacts with hardware.

As you have experienced with x86 assembly, some, or even a lot of this, should sound familiar. However, we are going to cover a lot of things most assembly books don't cover in detail; more specifically, things specific to Ring 0 programs.

# The System Bus #

The *System bus* is also known as the *Front Side Bus* that connects the CPU to the *North Bridge* on a motherboard.

The System Bus is a combination of the *Data Bus*, *Address Bus* and *Control Bus*. **Each electronic line on this bus represents a single bit**. The voltage level used to represent a *zero* and *one* is based off **Standard Transistor-Transistor Logic (TTL) Levels**. We don't need to know this though. TTL is part of **Digital Logic Electronics**, on which computers are built.

As you know, the System Bus is made up of 3 busses. Let's look at them in detail, shall we?

## Data Bus ##

The data bus is a series of electronic lines that carries data. The size of the data bus is 16 lines (bits), 32 lines (bits) or 64 lines (bits). Note the direct relationship between an electronic line and a single bit.

This means, **a 32bits processor has (and uses) a 32bits data bus**. This means, it can carry a 4 byte piece of data simultaneously. Knowing this, we can watch the data sizes in our programs and help increase speed.

How? The processor will need to pad 1, 2, 4, 8 and 16 bit data to the size of the data bus with 0's. Larger pieces of data will need to be broken down (and padded) so the processor can send the bytes correctly over the data bus. **Sending a piece of data that is the size of the data bus will be faster because no extra processing is done**.

For example, let's say we have a 64bits data type, but a 32bits data bus. In the first *Clock Cycle*, only the first 30 bits are sent through the data bus to the memory controller. In the second clock cycle, the processor references the last 32bits. **Note: Notice that, the larger the data type, the more clock cycles it will take!**

Generally, the terms "32bits processor", "16bits processor", etc, generally refers to the size of the data bus. So, a "32bits processor" uses a 32bits data bus.

## Address Bus ##

Whenever the processor or an I/O device needs to reference memory, it places its address on the Address Bus. Okay, we know that a *memory address* represents a location in memory. This is an abstraction.

A *Memory Address* is **just a number used by the memory controller**. That's it! The memory controller takes the number from this bus and interprets it as a memory location. **Knowing the size of each RAM chip, the memory controller can easily reference the exact RAM chip and byte offset in it**. Beginning with *Memory Cell 0*, the memory controller interprets this offset as the **requested address**.

The address bus is connected to the processor through the **Control Unit (CU)** and the **I/O Controller**. The *Control Unit* is inside the processor, so we will look at that later. The *I/O Controller* controls the interface to hardware devices. We will look at that later also.

Just like the data bus, **each electronic line represents a single bit**. Because there are only two unique values in a bit, **there's exactly 2^n unique address that a CPU can access**. Therefore, **the number of buts/lines in the address bus represents the maximum memory the CPU can access**.

In the 8080 through 80186 processor, each had 20 line/bit address busses. The 80286 and 80386 have 24 lines/bits and the 80486 and later have 32 line/bits.

Remember that the entire x86 family is designed to be portable with all older processors. This is why it starts in *Real Mode*. **The processor architecture were limited to 1MB because they only had access to 20 address lines -- line 0 through 19**.

This is important to us because this limitation still applies to us. What we need to do is enable access through the 20th address line. This will allow our OS to access more than 4GB of memory. We will cover more on this later.

## Control Bus ##

Okay, we could place data on the Data Bus and reference memory address using the Address bus. But how do we know what to do with this data? Are we reading it from memory? Are we writing the data?

The *Control Bus* is a series of lines/bits that represents what a device is trying to do. For example, the processor would set the READ bit or WRITE bit to let the memory controller know it wants to read or write data in the data bus from the memory location stored in the address bus.

The Control Bus also allows the processor to signal a device. This lets a device know that we need its attention. For example, perhaps we need the device to read from the memory location from the address bus? This will let the device know what we need. **This is important for I/O software ports**.

Remember, the system bus is not directly connected to the hardware devices. Instead it is connected to a central controller -- **the I/O controller**, which, in turn, signals the devices.

## That's all! ##

That's all there is to the system bus. It's the pathway for accessing and reading memory from the processor (through its control unit (CU)) and the I/O devices (through the I/O controller) to the memory controller, which is responsible for calculating the exact RAM chip and finding the memory cell we want to access.

"**Controller**"... You will see this term a lot. I'll explain why later.

# Memory Controller #

The memory controller is the primary interface between the System Bus (aka Front Side Bus (FSB)) on the motherboard to the physical RAM chips.

We've seen the term **Controller** before, haven't we? What exactly is a controller?

## Controllers ##
A controller provides basic hardware control functionality. **It also provides the basic interface between hardware and software**. This is important to us. Remember that in protected mode, we will **not have any interrupts available to us**. In the bootloader, we used several interrupts to communicate with the hardware. **Using these interrupts in protected mode will cause a Triple Fault**. Yikes! So, what do we do?

We will need to communicate with the hardware directly. We do this through the controllers. We will talk more about how controllers work later when we cover the I/O sub system.

## Memory Controller ##

The memory controller provides a way of reading and writing memory locations through software. The memory controller is also responsible for constant refreshing of the RAM chips, to ensure they retain the information.

The memory controller's *Multiplexer* and *Demultiplexer* circuits selects the exact RAM chip and location that references the address in the Address Bus.

### Double Data Rate (DDR) Controller ###

A DDR Controller is used to refresh DDR SDRAM, which uses the *System Clock* pulse to allow reading from and writing to memory.

### Dual Channel Controller ###

A Dual Channel Controller is used where DRAM devices are separated into two small busses, allowing reading and writing two memory locations at once. This helps increasing speed when accessing RAM.

### Memory Controller Conclusion ###

The memory controller takes the address we put into the address bus. This is good and all, but how do we tell the memory controller to read or write memory? And where does it get its data from? When reading memory, **the processor sets the read bit in the control bus**. Similarly, **the processor sets the write bit when writing memory on the control bus**.

Remember that the control bus allows the processor to control how other devices use the bus.

The data the memory controller uses is inside the data bus. The address to use is in the address bus.

#### Reading Memory ####

When reading memory, the processor places the absolute address to read from on the address bus. The processor then sets the READ control line.

The memory controller now has control. The controller converts the absolute address into a physical RAM location using its *multiplexer* circuit and places the data into the data bus. It then resets the READ bit to 0 and sets the READY bit.

The processor now knows the data is now on the data bus. It copies this data and executes the rest of the instruction; perhaps store it in BX?

#### Writing Memory ####

The process of writing memory is similar.

First, the processor places the memory address into the address bus. It then places the data to write on the data bus. Then, it sets the WRITE bit on the control bus.

This lets the memory controller know to write the data present on the data bus to the absolute address on the address bus. When done, the memory controller resets the WRITE bit and sets the READY bit on the control bus.

#### Conclusion ####

We do not communicate directly with the memory controller through software, but instead, we communicate indirectly with it. **Whenever we read from or write to memory, we are using the memory controller. This is the interface between our software and the memory controller / RAM chips hardware**.

Yippee! Let's take a look at the I/O subsystem now, shall we? Oh wait, what about the *Multiplexer* circuit? That is a physical electronic circuit in the memory controller. To understand how it works, one has to know **Digital Logic Electronics**. Because this is irrelevant to us, we are not going to cover it here. If you would like to know more, Google! :)

# I/O Subsystem #

The I/O subsystem simply represents **Port I/O**. **This is the basic system that provides the interface between software and hardware controllers**.

Let's look closer.

## Ports ##

A *port* simply provides an interface between two devices. There are two types of ports: **Hardware ports** and **Software ports**.

### Hardware Ports ###

A hardware port provides the interface between two physical devices. This port is usually a connection device of sorts. This includes, but not limited to:
- Serial ports
- Parallel ports
- PS/2 ports
- 1394 ports (FireWire)
- USB ports
- etc

These ports are usually on the side/back or front of a typical computer system.

Okay... um, if you want to see a port, just follow any line that connects to your computer. Please, for the sake of Jeeves, don't ask me what these do, you have got to know already now! Seriously!

In typical electronics, the pins in these ports carry signals that represent different things, depending on the hardware device. These pins represent, just like the system bus--wait for it... Bits! Each pin represents a single bit. Yep, that's it!

Two general classifications for hardware ports include *Male* and *Female* ports. Male ports are connections where the pins emerge from the connector. Female ports are the opposite of this. Hardware ports are accessed through controllers. I'll talk more about this later.

### Software Ports ###

THIS will be very important to us. This is our interface to the hardware. A *Software port* is a number. That's it! This number represents a hardware controller... Kind of.

You may know that several port numbers could represent the same controller. The reason? **Memory mapped I/O**. The basic idea is that we communicate with the hardware by specifying certain memory addresses. **The port number represents this address**. Once more, kind of. The meaning of the addresses could represent a specific register in a device or a control register.

We will look into this more closely later.

## Memory Mapping ##

On the x86 architecture, the processor uses specific memory locations to represent certain things.

For example, **the address 0xA000:0 represents the start of VRAM on the video card**. By writing bytes to this location, you effectively change what is currently in the video memory and effectively, what is displayed on screen.

Other memory addresses can represent something else; let's say, a register for the floppy drive controller (FDC)?

Understanding what addresses are what is critical and very important to us.

### x86 Real Mode Memory Map ###

General x86 Real Mode memory map:
- **0x00000000 - 0x000003FF** - Real Mode Interrupt Vector Table
- **0x00000400 - 0x000004FF** - BIOS Data Area
- **0x00000500 - 0x00007BFF** - Unused
- **0x00007C00 - 0x00007DFF** - Bootloader
- **0x00007E00 - 0x0009FFFF** - Unused
- **0x000A0000 - 0x000BFFFF** - Video RAM (VRAM) Memory
- **0x000B0000 - 0x000B7777** - Monochrome Video Memory
- **0x000B8000 - 0x000BFFFF** - Color Video Memory
- **0x000C0000 - 0x000C7FFF** - Video ROM BIOS
- **0x000C8000 - 0x000EFFFF** - BIOS Shadow Area
- **0x000F0000 - 0x000FFFFF** - System BIOS

**Note: It is possible to remap all of the above devices to use different regions of memory**. This is what the BIOS POST does to map the devices to the table above.

Okay, this is cool and all. Because these addresses represent different things, by reading (or writing) to specific addresses, we obtain (or change) information with ease from different parts of the computer.

For example, remember when we talked about **INT 0x19**? We referenced that writing the value 0x1234 at 0x0040:0x0072 and jumping to 0xFFFF:0, we performed a warm reboot on the computer (Similar to CTRL+ALT+DEL). Remembering the conversation between segment:offset addressing mode and absolute addressing, we can convert 0x0040:0x0072 to the absolute address 0x00000472, a byte within the BIOS data area.

Another example is text output. But by writing two bytes into 0x000B8000, we can effectively change what is in text mode memory. Because this is constantly refreshed  when displayed, it effectively displays the character on the screen. Cool?

Let's go back to port mapping, shall we? We will look back at this table a lot more later.

### Port Mapping - Memory Mapped I/O ###

A "port address" is a special number that each controller listens to. **When booting, the ROM BIOS assigns different numbers to these controller devices**. Remember that the ROM BIOS and the BIOS are related, but different software. The ROM BIOS is an electronic maleware on the BIOS chip. It starts the primary processor, loads the BIOS program at 0xFFFF:0 (**Remember this? Compare this with the table in the previous section**).

The ROM BIOS assigns these numbers to different controllers, so controllers have a way to identify themselves. This allows the BIOS to set up the Interrupt Vector Table, which communicates to the hardware, using this special number.

The processor uses the same system bus when working with I/O controllers. **The processor puts the special port number onto the address bus**, as if it was reading memory. It also sets the READ or WRITE lines on the control bus as well. This is cool, but there's a problem. How does the processor differentiate writing memory and accessing a controller?

The processor sets another line on the control bus, the *I/O ACCESS* line. **If this line is set, the I/O controller from within the I/O subsystem watches the address bus. If the address bus corresponds to a number that is assigned to the device, that device takes the value from the data bus and acts upon it**. The memory controller ignores any request if this line is set. So, if the port number has not been assigned, absolutely nothing happens. No controller acts on it and the memory controller ignores it.

Let's take a look a these port addresses. **This is very important! This is the *only* way of communicating with hardware in protected mode!**:

**Warning: This table is huge!**

<table border=1 bgcolor="CCCCCC">
	<tr>
		<th colspan=5 bgcolor="FFFFFF">Default x86 Port Address Assignments</th>
	</tr>
	<tr bgcolor="AAAAAA"> 
		<td>Address Range</td>
		<td>First QWORD</td>
		<td>Second QWORD</td>
		<td>Third QWORD</td>
		<td>Fourth QWORD</td> 
	</tr>
 	<tr>
 		<td bgcolor="ffffff">0x000-0x00F</td>
 		<td colspan=4>DMA Controller Channels 0-3</td>
 	</tr>
	<tr>
		<td bgcolor="ffffff">0x010-0x01F</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x020-0x02F</td>
		<td>Interrupt Controller 1</td>
		<td colspan=3>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x030-0x03F</td>
		<td colspan=4>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x040-0x04F</td>
 		<td>System Timers</td>
 		<td colspan=3>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x050-0x05F</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x060-0x06F</td>
		<td>Keyboard/PS2 Moude (Port 0x60)<br>Speaker (0x61)</td>
		<td>Keyboard/PS2 Mouse (0x64)</td>
		<td colspan=2>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x070-0x07F</td>
		<td>RTC/CMOS/NMI (0x70, 0x71)</td>
		<td colspan=3>DMA Controller Channels 0-3</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x080-0x08F</td>
 		<td>DMA Page Register 0-2 (0x81 - 0x83)</td>
 		<td>DMA Page Register 3 (0x87)</td>
 		<td>DMA Page Register 4-6 (0x89-0x8B)</td>
 		<td>DMA Page Register 7 (0x8F)</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x090-0x09F</td>
		<td colspan=4>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x0A0-0x0AF</td>
 		<td>Interrupt Controller 2 (0xA0-0xA1)</td>
 		<td colspan=3>System Use</td>
 	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x0B0-0x0BF</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x0C0-0x0CF</td>
		<td colspan=4>DMA Controller Channels 4-7 (0x0C0-0x0DF), bytes 1-16</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x0D0-0x0DF</td>
		<td colspan=4>DMA Controller Channels 4-7 (0x0C0-0x0DF), bytes 16-32</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x0E0-0x0EF</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x0F0-0x0FF</td>
		<td colspan=4>Floating Point Unit (FPU/NPU/Mah Copprocessor)</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x100-0x10F</td>
 		<td colspan=4>System Use</td>
 	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x110-0x11F</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x120-0x12F</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x130-0x13F</td>
		<td colspan=4>SCSI Host Adapter (0x130-0x14F), bytes 1-16</td>
	</tr>
 	<tr>
 		<td bgcolor="ffffff">0x140-0x14F</td>
 		<td colspan=2>SCSI Host Adapter (0x130-0x14F), bytes 17-32</td>
 		<td colspan=2>SCSI Host Adapter (0x140-0x15F), bytes 1-16</td>
 	</tr>
 	<tr>
 		<td bgcolor="ffffff">0x150-0x15F</td>
		<td colspan=4>SCSI Host Adapter (0x140-0x15F), bytes 17-32</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x160-0x16F</td>
		<td colspan=2>System Use</td>
		<td colspan=2>Quaternary IDE Controller, master slave</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x170-0x17F</td>
		<td colspan=2>Secondary IDE Controller, Master drive</td>
		<td colspan=2>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x180-0x18F</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x190-0x19F</td>
		<td colspan=4>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x1A0-0x1AF</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x1B0-0x1BF</td>
		<td colspan=4>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x1C0-0x1CF</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x1D0-0x1DF</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x1E0-0x1EF</td>
		<td colspan=2>System Use</td>
		<td colspan=2>Tertiary IDE Controller, master slave</td>
	</tr> 
	<tr>
		<td bgcolor="FFFFFF">0x1F0-0x1FF</td>
		<td colspan=2>Primary IDE Controller, master slave</td>
		<td colspan=2>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x200-0x20F</td>
 		<td colspan=2>Joystick Port</td>
 		<td colspan=2>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x210-0x21F</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td rowspan=3 bgcolor="FFFFFF">0x220-0x22F</td>
 		<tr>
			<td colspan=4>Sound Card</td>
		</tr>
		<tr>
			<td>Non-NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
 	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x230-0x23F</td>
 		<td colspan=4>SCSI Host Adapter (0x220-0x23F), bytes 17-32)</td>
 	</tr>
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x240-0x24F</td>
		<tr>
			<td colspan=4>Sound Card</td>
		</tr>
 		<tr>
 			<td>Non-NE2000 Network Card</td>
 			<td colspan=3>System Use</td>
 		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x240-0x25F) Bytes 1-16</td>
		</tr>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x250-0x25F</td>
		<td colspan=4>NE2000 Network Card (0x240-0x25F) Bytes 17-32</td>
	</tr>
 	<tr>
 		<td rowspan=4 bgcolor="FFFFFF">0x260-0x26F</td>
		<tr>
			<td colspan=4>Sound Card</td>
		</tr>
 		<tr>
 			<td>Non-NE2000 Network Card</td>
 			<td colspan=3>System Use</td>
 		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x240-0x27F) Bytes 1-16</td>
		</tr>
	</tr>
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x270-0x27F</td>
		<tr>
			<td>System Use</td>
			<td>Plug and Play System Devices</td>
			<td colspan=2>LPT2 - Second Parallel Port</td>
		</tr>
 		<tr>
 			<td colspan=2>System Use</td>
 			<td colspan=2>LPT3 - Third Parallel Port (Monochrome Systems)</td>
 		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x260-0x27F) Bytes 17-32</td>
		</tr>
	</tr>
 	<tr>
 		<td rowspan=4 bgcolor="FFFFFF">0x280-0x28F</td>
		<tr>
			<td colspan=4>Sound Card</td>
		</tr>
 		<tr>
 			<td>Non NE2000 Network Card</td>
 			<td colspan=3>System Use</td>
 		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x280-0x29F) Bytes 1-16</td>
		</tr>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x290-0x29F</td>
		<td colspan=4>NE2000 Network Card (0x280-0x29F) Bytes 17-32</td>
	</tr>
 	<tr>
 		<td rowspan=3 bgcolor="FFFFFF">0x2A0-0x2AF</td>
		<tr>
			<td>Non NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x280-0x29F) Bytes 1-16</td>
		</tr>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x2B0-0x2BF</td>
		<td colspan=4>NE2000 Network Card (0x280-0x29F) Bytes 17-32</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x2C0-0x2CF</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x2D0-0x2DF</td>
		<td colspan=4>System Use</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x2E0-0x2EF</td>
		<td colspan=2>System Use</td>
		<td colspan=2>COM4 - Fourth Serial Port</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x2F0-0x2FF</td>
		<td colspan=2>System Use</td>
		<td colspan=2>COM2 - Second Serial Port</td>
	</tr>
 	<tr>
 		<td rowspan=4 bgcolor="FFFFFF">0x300-0x30F</td>
		<tr>
			<td>Sound Card / MIDI Port</td>
			<td colspan=3>System Use</td>
		</tr> 
		<tr>
			<td>Non NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x300-0x31F) Bytes 1-16</td>
		</tr>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x310-0x31F</td>
 		<td colspan=4>NE2000 Network Card (0x300-0x32F) Bytes 17-32</td>
 	</tr>
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x320-0x32F</td>
		<tr>
			<td>Sound Card / MIDI Port (0x330, 0x331)</td>
			<td colspan=3>System Use</td>
		</tr> 
		<tr>
			<td colspan=4>NE2000 Network Card (0x300-0x31F) Bytes 17-32</td>
		</tr>
		<tr>
			<td colspan=4>SCSI Host Adapter (0x330-0x34F) Bytes 1-16</td> 
 		</tr> 
 	</tr>
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x330-0x33F</td>
		<tr>
			<td>Sound Card / MIDI Port</td>
			<td colspan=3>System Use</td>
		</tr>
		<tr>
			<td>Non NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x300-0x31F) Bytes 1-16</td>
		</tr>
 	</tr> 
	<tr>
		<td rowspan=5 bgcolor="FFFFFF">0x340-0x34F</td>
		<tr>
			<td colspan=4>SCSI Host Adapter (0x330-0x34F) Bytes 17-32</td>
		</tr>
		<tr>
			<td colspan=4>SCSI Host Adapter (0x340-0x35F) Bytes 1-16</td>
		</tr>
		<tr>
			<td>Non NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
 		<tr>
 			<td colspan=4>NE2000 Network Card (0x340-0x35F) Bytes 1-16</td>
 		</tr>
 	</tr>
	<tr>
		<td rowspan=3 bgcolor="FFFFFF">0x350-0x35F</td>
		<tr>
			<td colspan=4>SCSI Host Adapter (0x340-0x35F) Bytes 17-32</td>
		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x300-0x31F) Bytes 1-16</td>
		</tr>
 	</tr> 
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x360-0x36F</td>
		<tr>
			<td>Tape Accelerator Card (0x360)</td>
			<td colspan=2>System Use</td>
			<td>Quaternary IDE Controller (Slave Drive)(0x36E-0x36F)</td>
		</tr>
		<tr>
			<td>Non NE2000 Network Card</td>
			<td colspan=3>System Use</td>
		</tr>
		<tr>
			<td colspan=4>NE2000 Network Card (0x300-0x31F) Bytes 1-16</td>
		</tr>
 	</tr> 
	<tr>
		<td rowspan=4 bgcolor="FFFFFF">0x370-0x37F</td>
		<tr>
			<td>Tape Accelerator Card (0x370)</td>
			<td>Secondary IDE Controller (Slave Drive)</td>
			<td colspan=2>LPT1 - First Parallel Port (Color systems)</td>
		</tr>
		<tr>
			<td colspan=2>System Use</td>
			<td colspan=2>LPT2 - Second Parallel Port (Monochrome Systems)</td>
		</tr>
 		<tr>
 			<td colspan=4>NE2000 Network Card (0x360-0x37F) Bytes 1-16</td>
 		</tr>
 	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x380-0x38F</td>
 		<td colspan=2>System Use</td>
 		<td>Sound Card (FM Synthesizer)</td>
 		<td>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x390-0x39F</td>
		<td colspan=4>System Use</td>
	</tr>
 	<tr>
 		<td bgcolor="FFFFFF">0x3A0-0x3AF</td>
 		<td colspan=4>System Use</td>
 	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x3B0-0x3BF</td>
		<td colspan=3>VGA/Monochrome Video</td>
		<td>LPT1 - First Parallel Port (Monochrome Systems)</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x3C0-0x3CF</td>
		<td colspan=4>VGA/CGA Video</td>
	</tr>
	<tr>
		<td bgcolor="FFFFFF">0x3D0-0x3DF</td>
		<td colspan=4>VGA/CGA Video</td>
	</tr>
 	<tr>
 		<td rowspan=3 bgcolor="FFFFFF">0x3E0-0x3EF</td>
		<tr>
			<td>Tape Accelerator Card (0x370)</td>
			<td>System Use</td>
			<td colspan=2>COM3 - Third Serial Port</td>
		</tr>
		<tr>
			<td colspan=3>System Use</td>
			<td>Tertiary IDE Controller (Slave Drive)(0x3EE-0x3EF)</td>
		</tr>
 	</tr>
	<tr>
		<td rowspan=3 bgcolor="FFFFFF">0x3F0-0x3FF</td>
		<tr>
			<td colspan=2>Floppy Disk Controller</td>
			<td colspan=2>COM1 - First Serial Port</td>
		</tr>
		<tr>
			<td>Tape Accelerator Card (0x3F0)</td>
			<td>Primary IDE Controller (Slave Drive)(0x3F6-0x3F7)</td>
			<td colspan=2>System Use</td>
		</tr>
	</tr> 
</table> 

The table is not complete and hopefully has no errors in it. I will add to this table as time goes on and more devices are developed.

All of these memory ranges are used by certain controllers, as the above table shows. The exact meaning of a port address depends on the controller. It could represent a controller register, state register or virtually anything. This is unfortunate.

**I highly recommend to print out a copy of the table above. We will need to reference it every time we are communicating with hardware**.

I will update (at the beginning of the tutorial), if I have updated the table. That way, you can print out the table again, insuring everyone has the latest copy.

With all of this in mind, let's put it all together.

### IN and OUT Instructions ###

The x86 processor has two instructions used for port I/O. They are *IN* and *OUT*.

These instructions tell the processor that we want to communicate with a device. This insures the processor sets the I/O DEVICE line on the control bus.

Let's have a complete example and try to see if we can read from the keyboard controller input buffer.

Let's see, looking at our trusty Port table above, we can see the *keyboard controller* is in port addresses **0x60 through 0x6F**. The table displays that the first QWORD and second QWORD (Starting from port address 0x60) is for the keyboard and PS/2 mouse. The last two QWORDS are for system use, so we will ignore them.

Okay, so our keyboard controller is mapped to ports 0x60 through, technically, port 0x68. This is cool, but what does it mean to us? This is device specific, remember?

For our keyboard, **port 0x60 is a control register, port 0x64 is a status register**. Remember from before; I said we would hear these terms a lot more and in different contexts. **If bit 1 in the status register is set, data is inside the input buffer**. So, let's see, if we set the CONTROL register to READ, we can copy the contents of the input buffer somewhere.

	WaitLoop:	in		al, 64h		; Get status register value.
				and		al, 10b		; Test bit 1 of status register.
				jz		WaitLoop	; IF status register bit not set, no data is in buffer.
				in		al, 60h		; It's set, get the byte from the buffer (port 0x60) and store it.
				
This, right here, is the bases of hardware programming and device drivers.

In an *IN* instruction, the processor places the port address, like 0x64, into the address bus and sets the I/O DEVICE line on the control bus, followed by the READ line. The device that has been assigned to 0x60 by the ROM BIOS; in this case, the Status Register in the keyboard controller, knows it's a read operation because the READ line is set. So, it copies data from some location inside the keyboard registers onto the data bus, resets the READ and the I/O DEVICE lines on the control bus and sets the READY line. Now, the processor has the data from the data bus that was read.

An *OUT* instruction is similar. The processor copies the byte to be written on the data bus (zero extending it to the data bus width). Then, it sets the WRITE and I/O DEVICE lines on the control bus. It then copies the port address; let's say 0x60, onto the address bus. **Because the I/O DEVICE line is set, it is a signal that tells all controllers to watch the address bus. If the  number on the address bus corresponds with their assigned number, the device acts on that data**. In this case, the keyboard controller. The keyboard controller knows it's a WRITE operation because the WRITE line is set on the control bus. So, it copies the value on the data bus into its control register, which was assigned port address 0x60. The keyboard controller resets the WRITE and I/O DEVICE lines and sets the READY line on the control bus and the processor is back in control.

**Port mapping and port I/O are very important. It is our only way of communicating with hardware in protected mode. Remember: interrupts are not available until we write them. To write them, along with any hardware routine, such as input and output, it requires us to write drivers. All of this requires direct hardware access. If you don't feel comfortable with this, practice a little first and reread this section. If you have any questions, let me know**.

# The Processor #

## Special Instructions ##

Most 80x86 instructions can be executed by any program. However, there are some instructions that only Kernel-level software can access. Because of this, some of these instructions may not be familiar to our readers. We will require the use of most of these instructions, so understanding them is important.

<table>
	<tr>
		<th>Privileged Level (Ring 0) Instructions</th>
	</tr>
	<tr>
		<td bgcolor="#999999">Instruction</td>
		<td bgcolor="#999999">Description</td>
	</tr>
	<tr>
		<td>LGDT</td>
		<td bgcolor="#c0c0c0">Loads an address of a GDT into GDTR</td>
	</tr>
	<tr>
		<td>LLDT</td>
		<td bgcolor="#c0c0c0">Loads an address of a LDT into LDTR</td>
	</tr>
	<tr>
		<td>LTR</td>
		<td bgcolor="#c0c0c0">Loads a Task Register into TR</td>
	</tr>
	<tr>
		<td>MOV <i>Control Register</i></td>
		<td bgcolor="#c0c0c0">Copy data and store in Control Registers</td>
	</tr>
	<tr>
		<td>LMSW</td>
		<td bgcolor="#c0c0c0">Load a new Machine Status WORD</td>
	</tr>
	<tr>
		<td>CLTS</td>
		<td bgcolor="#c0c0c0">Clear Task Switch flag in Control Register CR0</td>
	</tr>
	<tr>
		<td>MOV <i>Debug Register</i></td>
		<td bgcolor="#c0c0c0">Copy data and store in debug registers</td>
	</tr>
	<tr>
		<td>INVD</td>
		<td bgcolor="#c0c0c0">Invalidate Cache without writeback</td>
	</tr>
	<tr>
		<td>INVLPG</td>
		<td bgcolor="#c0c0c0">Invalidate TLB entry</td>
	</tr>
	<tr>
		<td>WBINVD</td>
		<td bgcolor="#c0c0c0">Invalidate Cache with writeback</td>
	</tr>
	<tr>
		<td>HLT</td>
		<td bgcolor="#c0c0c0">Halt processor</td>
	</tr>
	<tr>
		<td>RDMSR</td>
		<td bgcolor="#c0c0c0">Read model-specific registers (MSR)</td>
	</tr>
	<tr>
		<td>WRMSR</td>
		<td bgcolor="#c0c0c0">Write model-specific registers (MSR)</td>
	</tr>
	<tr>
		<td>RDPMC</td>
		<td bgcolor="#c0c0c0">Read performance monitoring counter</td>
	</tr>
	<tr>
		<td>RDTSC</td>
		<td bgcolor="#c0c0c0">Read timestamp counter</td>
	</tr>
</table>Executing any of the above instructions by any other program that does not have Kernel mode access (Ring 0) will generate a **General Protection Fault** or a **Triple Fault**.

Don't worry if you don't understand these instructions, I will cover each of them throughout the series as we need them.

## 80x86 Registers ##

The x86 processor has a lot of different *registers* for storing its current state. Most applications only have access to the *general*, *segment* and *eflags*. Other registers are specific to Ring 0 programs, such as our kernel.

The x86 family has the following registers: RAX(EAX(AX/AH/AL)), RBX(EBX(BX/BH/BL)), RCX(ECX(CX/CH/CL)), RDX(EDX(DX/DH/DL)), CS, SS, ES, DS, FS, GS, RSI(ESI(SI)), RDI(EDI(DI)), RBP(EBP(BP)), RSP(ESP(SP)), RIP(EIP(IP)), RFLAGS(EFLAGS(FLAGS)), DR0, DR1, DR2, DR3, DR4, DR5, DR6, DR7, TR1, TR2, TR3, TR4, TR5, TR6, TR7, CR0, CR1, CR2, CR3, CR4, CR5, CR6, CR8, ST, mm0, mm1, mm2, mm3, mm4, mm5, mm6m mm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, GDTR, LDTR, IDTR, MSR and TR. All of these registers are store in a special area of memory inside the processor called a **register file**. Please see the **Processor Architecture** section for more information. Other registers include, but may not be in the register file, are: PC, IR, vector registers and hardware registers.

A lot of these registers are **only** available to real mode ring 0 programs and for very good reasons. Most of these registers affect a lot of states within the processor. Incorrectly setting them can easily triple fault the CPU. Other cases might cause the CPU to malfunction (especially the use of TR4, TR5, TR6 and TR7).

Some of the other registers are **internal to the CPU** and **cannot** be accessed through normal means. One would need to reprogram the processor itself in order to access them, most notably the IR and the vector registers.

We will need to know some of these special registers so let's take a look closer, shall we?

## General Purpose Registers ##

These are 32 bits registers that can be used for almost any purpose. However, each of these registers have a special purpose as well.

- EAX - Accumulator register. Primary purpose: Math calculations.
- EBX - Base Address register. Primary purpose: Indirectly address memory through a base address.
- ECX - Counter register. Primary purpose: Use in counting and looping.
- EDX - Data register. Primary purpose: Um... Store data. Yep, that's about it! :)

Each of these 32 bit registers has two parts. The *high order word* and the *low order word*. The high order word is the upper 16 bits. The low order word is the lower 16 bits.

On 64 bit processors, these registers are 64 bits wide and are named RAX, RBX, RCX and RDX. The lower 32 bits is the 32 bit EAX register.

The upper 16 bits doesn't have a special name associated with them. However, **the lower 16 bits do**. **These names have an appended 'H' (for higher 8 bits in low word) or an appended 'L' for the lower 8 bits**.

For example, in RAX, we have:

						       			   +--- AH ----+--- AL ---+
										   |           |          |
	+-------------------------------------------------------------+
	|		      		  | 	    	   |                      |
	+-------------------------------------------------------------+
	|		      		  |									      |
	|		      		  +--------EAX lower 32 bits--------------| -- Available only on 32 bit processors.
	|							      							  |
	|------------------ RAX Complete 64 bits----------------------| -- Available only on 64 bit processors.
	
What does this mean? **AH and AL are part of AX, which, in turn, is part of EAX. Thus, modifying any of these names effectively modifies the same register - EAX**.

This, in turn, modifies RAX, on 64 bit machines.

The above is also true for BX, CX and DX.

General purpose registers can be used within any program, from Ring 0 to Ring 3. Because they are basic assembly language, I will assume you already know how they work.

## Segment Registers ##

The segment registers modify the current segment addresses in real mode. They are all 16 bit.

- CS - Segment address of Code Segment
- DS - Segment address of Data Segment
- ES - Segment address of Extra Segment (Heap)
- SS - Segment address of Stack Segment
- FS - Far Segment address
- GS - General purpose register

Remember: **Real Mode uses the segment:offset memory addressing model**. The *segment address* stored within a segment register. Another register, such as BP, SP or BX can store the *offset* address.

It is usually referenced like: **DS:SI**, where DS contains the segment address and SI contains the offset address.

Segment registers can be used within any program, from Ring 0 to Ring 3. Because they are basic assembly language, I will assume you already know how they work.

## Index Registers ##

The x86 uses several registers that help when accessing memory.

- SI - Source Index
- DI - Destination Index
- BP - Base Pointer
- SP - Stack Pointer

Each of these registers store a 16 bit base address (that may be used as an offset address as well).

On 32 bit processors, these registers are 32 bits and have the names ESI, EDI, EBP and ESP.

On 64 bit processors, these registers are 64 bits and have the names RSI, RDI, RBP and RSP.

The 16 bit registers are a subset of the 32 bit registers, which is a subset of the 64 bit registers, the same way as RAX.

The *Stack Pointer* is automatically incremented and decremented a certain amount of bytes whenever certain instructions are encountered; such as push, pop instructions, ret/iret, call, syscall, etc.

**The C programming language, in fact most languages, use the stack regularly. We need to insure we set the tack up at the good address to insure C works properly. Also, remember: the Stack trows *downward*!**

## Instruction Pointer / Program Counter ##

The Instruction Pointer (IP) register stores the current offset address of the currently executing instruction. Remember: **This is an offset address, NOT an absolute address!**

The instruction Pointer (IP) is sometimes also called the Program Counter (PC).

On 32 bit processors, IP is 32 bits and uses the name EIP.

On 64 bit processors, IP is 64 bits and uses the name RIP.

## Instruction Register ##

This is an internal processor register that cannot be accessed through normal means. It is stored within the *control unit (CU)* of the processor inside the *instruction cache*. It stores the current instruction that is being translated to Microinstructions for use internally by the processor. Please see **Processor Architecture** for more information.

## EFlags Register ##

The EFLAGS register is the x86 processor status register. It is used to determine the um... Current status! We have actually used this a lot already so far. A simple example: jc, jnc, jb, jnb instructions.

Most instructions manipulates the EFLAGS register so that you can test for conditions (like if the value was lower or higher than another).

*EFLAGS* is compised of *FLAGS* register. Similarly, *RFLAGS* is composed of *EFLAGS* and *FLAGS*. ie:

	 +---------- EFLAGS (32 Bits) ----+
	 |                                |
	 |-- FLAGS (16 bits)-             |
	 |                  |             |
	 ====================================================================  < Register Bits
	 |                                                                  |
	 +------------------------- RFLAGS (64 Bits) -----------------------+
	 |                                                                  |
	Bit 0                                                              Bit 63
	
<table>
	<tr>
		<th bgcolor="#999999" colspan="3">FLAGS Register Status Bits</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Bit Number</td>
		<td bgcolor="#c0c0c0">Abbreviation</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0</td>
		<td>CF</td>
		<td>Carry Flag - Status Bit</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">1</td>
		<td></td>
		<td>Reserved</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">2</td>
		<td>PF</td>
		<td>Parity Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">3</td>
		<td></td>
		<td>Reserved</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">4</td>
		<td>AF</td>
		<td>Adjust Flag - Status Bit</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">5</td>
		<td></td>
		<td>Reserved</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">6</td>
		<td>ZF</td>
		<td>Zero Flag - Status Bit</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">7</td>
		<td>SF</td>
		<td>Sign Flag - Status Bit</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">8</td>
		<td>TF</td>
		<td>Trap Flag (Single Step) - System Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">9</td>
		<td>IF</td>
		<td>Interrupt Enabled Flag - System Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">10</td>
		<td>DF</td>
		<td>Direction Flag - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">11</td>
		<td>OF</td>
		<td>Overflow Flag - Status Bit</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">12-13</td>
		<td>IOPL</td>
		<td>I/O Privilege Level (286+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">14</td>
		<td>NT</td>
		<td>Nested Task Flag (286+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">15</td>
		<td></td>
		<td>Reserved</td>
	</tr>
	<tr>
		<th colspan="3" bgcolor="#999999">EFLAGS Register Status bit</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Bit Number</td>
		<td bgcolor="#c0c0c0">Abbreviation</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">16</td>
		<td>RF</td>
		<td>Resume Flag (386+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">17</td>
		<td>VM</td>
		<td>v8086 Mode Flag (386+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">18</td>
		<td>AC</td>
		<td>Alignment Check (486SX+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">19</td>
		<td>VIF</td>
		<td>Virtual Interrupt Flag (Pentium+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">20</td>
		<td>VIP</td>
		<td>Virtual Interrupt Pending (Pentium+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">21</td>
		<td>ID</td>
		<td>Identification (Pentium+ only) - Control Flag</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">22-31</td>
		<td></td>
		<td>Reserved</td>
	</tr>
	<tr>
		<th colspan="3" bgcolor="#999999">RFLAGS Register Status bit</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Bit Number</td>
		<td bgcolor="#c0c0c0">Abbreviation</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">32-63</td>
		<td></td>
		<td>Reserved</td>
	</tr>
</table>

the **I/O Privilege Level (IOPL)** controls the current ring level required to use certain instructions. For example, the **CLI, STI, IN and OUT** instructions will only execute if the current privilege level is equal or greater then the IOPL. If not, a **General Protection Fault (GPF)** will be generated by the processor.

Most operating systems set the IOPF to 0 or 1. This means that only kernel-level software can access these instructions. This is a  very good thing. After all, if an application issues a CLI, it can effectively stop the kernel from running.

For most operations, we only need to use the FLAGS register. Notice that the last 32 bits of the RFLAGS registers are null. So, um... Yeah. For speed purposes, of course, but a lot of bytes being wasted... yeah...

Because of the size of this table, I recommend printing it out for future reference.

## Test Registers ##

The x86 family uses some registers for testing purposes. Many of these registers are undocumented. On the x86 series, these registers are **TR4, TR5, TR6 and TR7**.

TR6 is most commonly used for command testing and TR7 for a test data register. One can use the MOV instruction to access them. **They are only available in ring 0 for both pmode and real mode. Any other attempt will cause a General Protection Fault (GPF) leading to a Triple Fault**.

## Debug Registers ##

These registers are used for program debugging. They are DR0-7. Just like the test registers, they can be accessed using the MOV instruction and only in ring 0. **Any attempt will cause a General Protection Fault (GPF) leading to a Triple Fault**.

### Breakpoint Registers ###

The registers DR0-3 store an absolute address of a breakpoint condition. If *paging* is enabled, the address will be converted to its absolute address. These breakpoint conditions are further defined in DR7.

### Debug Control Register ###

DR7 is a 32 bit register that uses a bit pattern to identify the current debugging task. Here it is:

- Bit 0..7 - Enable the four debug registers  (See below)
- Bit 8..14 - ?
- Bit 15..23 - When the breakpoint triggers. Each 2 bits represents a single Debug register. This can be done by the following:
	- 00 - Break on execution
	- 01 - Break on data write
	- 10 - Break on IO read or write. No hardware currently supports this.
	- 11 - Break on data read or write
- Bit 24..31 - Defines the size of the memory block to watch. Each 2 bits represents a single debug register. This can be done by the following:
	- 00 - One byte
	- 01 - Two bytes
	- 10 - Eight bytes
	- 11 - Four bytes

The debug registers uses two methods to enable. This is local and global levels. If you are using different *tasks* (such as *paging*, all *local debug changes only affect that task*. The processor automatically clears all local changes when switching between tasks. Global tasks, however, are not.

In bits 0..7 in the list above:

- Bit 0: Enable local DR0 register
- Bit 1: Enable global DR0 register
- Bit 2: Enable local DR1 register
- Bit 3: Enable global DR1 register
- Bit 4: Enable local DR2 register
- Bit 5: Enable global DR2 register
- Bit 6: Enable local DR3 register
- Bit 7: Enable global DR3 register

### Debug Status Register ###

This is used by debuggers to determine what happened when an error occurred. **When the processor runs into an enabled exception error, it sets the low 4 bits of this register and executes the Exception Handler**.

**Warning: The debug status register, DR6, is never cleared. If you have the program continue, make sure to clear this register!**

## Model-Specific Register ##

This is a special control register that provides special processor specific features that may not be on others. As these are system level, only ring 0 programs can access this register.

Because these registers are specific to each processor, the actual register may change.

The x86 has two special instructions that are used to access this register:

- **RDMSR** - Read from MSR
- **WRMSR** - Write from MSR

The registers are very processor-specific. Because of this, it is wise to use the CPUID instruction before using them.

To access a given register, one must pass the instruction an address which represents the register you want access to.

Through the years, Intel has used some MSRs that are not machine-specific. These MSRs are common within the x86 architecture.

<table>
	<tr>
		<th bgcolor="#999999" colspan="3">Model Specific Registers (MSRs)</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Register Address</td>
		<td bgcolor="#c0c0c0">Register Name</td>
		<td bgcolor="#c0c0c0">Register IA-32 Processor Family</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x0</td>
		<td>IA32_PS_MC_ADDR</rd>
		<td>Pentium Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x1</td>
		<td>IA32_PS_MC_TYPE</rd>
		<td>Pentium 4 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x6</td>
		<td>IA32_PS_MONITOR_FILTER_SIZE</rd>
		<td>Pentium Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x10</td>
		<td>IA32_TIME_STAMP_COUNTER</rd>
		<td>Pentium Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x17</td>
		<td>IA32_PLATFORM_ID</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x1B</td>
		<td>IA32_APIC_BASE</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x3A</td>
		<td>IA32_FEATURE_CONTROL</rd>
		<td>Pentium 4 / Processor 673</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x79</td>
		<td>IA32_BIOS_UPDT_TRIG</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x8B</td>
		<td>IA32_BIOS_SIGN_ID</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x9B</td>
		<td>IA32_SMM_MONITOR_CTL</rd>
		<td>Pentium 4 / Processors 672</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xC1</td>
		<td>IA32_PMC0</rd>
		<td>Intel Core Duo</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xC2</td>
		<td>IA32_PMC1</rd>
		<td>Intel Core Duo</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xE7</td>
		<td>IA32_MPERF</rd>
		<td>Intel Core Duo</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xE8</td>
		<td>IA32_APERF</rd>
		<td>Intel Core Duo</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xFE</td>
		<td>IA32_MTRRCAP</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x174</td>
		<td>IA32_SYSENTER_CS</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x175</td>
		<td>IA32_SYSENTER_ESP</rd>
		<td>P6 Processors</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x176</td>
		<td>IA32_SYSENTER_IP</rd>
		<td>P6 Processors</td>
	</tr>
</table>

There are a lot more MSRs than those that are listed. Please see [Appendix B from the Intel Development Manual](http://developer.intel.com/design/processor/manuals/253669.pdf) for the complete list.

I'm not sure what MSRs we will be referencing as this series is still in development. I will add onto this list as needed.

### RDMSR Instruction ###

This instruction loads the MSR specified by CX into EDX:EAX.

This instruction is a *privileged* instruction and can only be executed at ring 0 (kernel level). A **General Protection Fault (GPF)**, or **Triple Fault** will occur of a non-privileged program attempts to execute this instruction or the value in CS does not represent a valid MSR address.

This instruction doesn't affect any flag.

Here's an example of using this instruction (you will see this again later in tutorials):

	; This reads from the IA32_SYSENTER_CS MSR
	
	MOV		cx, 0x174	; Register 0x174: IA32_SYSENTER_CS
	RDMSR
	
	; Now EDX:EAX contains the lower and upper 32 bits of the 64 bit register

Cool, huh?

### WRMSR Instruction ###

This instruction writes the MSR specified by CX, the 64 bit value stored in EDX:EAX.

This instruction is also a privileged instruction and can only be executed in ring 0. A **General Protection Fault (GPF)** or a **Triple Fault** will occur of a non-privileged program attempts to execute this instruction or the value in CS does not represent a valid MSR address.

This instruction doesn't affect any flag.

Here's an example:

	; This writes to the IA32_SYSENTER_CS MSR
	
	MOV		cx, 0x174	; Register 0x174: IA32_SYSENTER_CS
	WRMSR
	
## Control Registers ##

THIS is going to be important to us.

The control registers allow us to change the behavior of the processor. They are CR0-4

### CR0 Control Register ###

CR0 is the primary control register. It is 32 bits, which are defined as follows:

- Bit 0 (PE) : Puts the system in protected mode.
- Bit 1 (MP) : Monitor Coprocessor Flag. This controls the operation of the WAIT instruction.
- Bit 2 (EM) : Emulate Flag. When set, coprocessor instructions will generate an exception.
- Bit 3 (TS) : Task Switched Flag. This will be set when the processor switches to another task.
- Bit 4 (ET) : ExtensionType Flag. This tells us what type of coprocessor is installed.
	- 0 - 80287 is installed.
	- 1 - 80387 is installed.
- Bit 5 (NE) : Numeric Error.
	- 0 - Enable standard error reporting
	- 1 - Enable internal x87 FPU error reporting
- Bit 6-15 : Unused
- Bit 16 (WP) : Write Protect
- Bit 17 : Unused
- Bit 18 (AM) : Alignment Mask
	- 0 - Alignment Check Disabled
	- 1 - Alignment Check Enabled (Also requires AC flag set in EFLAGS and ring 3)
- Bit 19-28: Unused
- Bit 29 (NW) : Not Write-Through
- Bit 30 (CD) : Cache Disabled
- Bit 31 (PG) : Enables Memory Paging.
	- 0 - Disable
	- 1 - Enable and use CR3 register.

Wow, a lot of new stuff, huh? Let's look at bit 0 -- **puts system in protected mode**. This means, **by setting bit 0 in the CR0 register, we effectively enter protected mode**.

For example:

	MOV		ax, cr0		; Get value in CR0
	or		ax, 1		; Set bit 0 -- Enter protected mode
	MOV		cr0, ax		; Bit 0 is set, we are in 32 bits mode!
	
Wow, it's that easy! Not quite... ;)

If you dump this code into our bootloader, it's almost guaranteed to Triple Fault. Protected mode uses a different addressing system than real mode. Also, **remember that pmode has no interrupts**. A single interrupt will Triple Fault. Also, because we use a different addressing model, **CS is invalid**. We would need to update CS to go to 32 bit code. And yet, **we didn't set privilege levels for the memory map**.

We will go more into details later.

### CR1 Control Register ###

Reserved by Intel. Do not use.

### CR2 Control Register ###

Page Fault Linear Address. If a Page Fault Exception occurs, CR2 contains the address that access was attempted.

### CR3 Control Register ###

Used when the PG bit in CR0 is set. Last 20 bits contain the Page Directory Base Register (PDBR)

### CR4 Control Register ###

Used in protected mode to control operations, such as v8086 mode, enabling I/O breakpoints, page size extension and machine check exceptions.

I don't know if we will use any of these flags or not. I decided to include it here for completeness' sake. Don't worry too much if you don't understand what these are.

- Bit 0 (VME) : Enables virtual 8086 mode extensions
- Bit 1 (PVI) : Enables protected mode virtual interrupts
- Bit 2 (TSD) : Time stamp enable
	- 0 - RDTSC instruction can be used in any privilege level
	- 1 - RDTSC instruction can only be used in ring 0
- Bit 3 (DE) : Enable debugging extensions
- Bit 4 (PSE) : Page size extension
	- 0 - Page size is 4KB.
	- 1 - Page size is 4KB. With PAE, it's 2MB.
- Bit 5 (PAE) : Physical address extension
- Bit 6 (MCE) : Machine check extension
- Bit 7 (PGE) : Page global enable
- Bit 8 (PCE) : Performance monitoring counter enable
	- 0 - RDPMC instruction can be used in any privilege level
	- 1 - RDPMC instruction can be used only in ring 0
- Bit 9 (OSFXSR) : OS support for FXSAVE and FXSTOR instructions (SSE)
- Bit 10 (OSXMMEXCPT) : OS support for unmasked SIMD FPU exceptions
- bit 11-12 : Unused
- Bit 13 (VMXE) : VMX Enable

### CR8 Control Register ###

Provides read and write access to the **Task Priority Register (TPR)**.

## PMode Segmentation Registers ##

The x86 family uses several registers to store the current linear address of each *segment descriptor*. More on this later.

These registers are:

- GDTR - Global Descriptor Table Register
- IDTR - Interrupt Descriptor Table Register
- LDTR - Local Descriptor Table Register
- TR - Task Register

We will take a closer look at these register in the next section.

# Processor Architecture #

Throughout this series, you will notice a lot of similarities between processor and microcontrollers. That is, microcontrollers have registers and execute instructions similar to the processor. **The CPU itself is nothing more than a specialized controller chip**.

We will look at the boot process again a little later, but from a very low level perspective. This will answer a lot of questions regarding how the BIOS POST actually starts and how it executes the POST, starts the primary processor and load the BIOS. We have covered the *what*, but we have not covered the *how* yet.

**Note: This section is fairly technical. If you don't understand everything, don't worry, as we don't need to understand everything. I'm including this section for completeness's sake; to dive into the main component required in any computer system and the one that is responsible for executing our code**. How does it execute our given code? What is so special about machine language? All of this will be answered here.

Later on, when we dive into the Kernel and Device Driver deployment, you will learn and understand the basic hardware controller components themselves cannot only be a great learning experience, but sometimes a necessity in understanding how to program that controller.

## Breaking Apart a Processor ##

We will be looking at the Pentium III processor here for explanation purposes. Let's open up and dissect this processor into its individual components first.

![Pentium 3 Map](http://www.brokenthorn.com/Resources/images/P3chiplarg.jpg)

A lot of things in the processor, huh? Notice how complex this is. We are not going to learn much from this picture alone so let's look at each component.

- L2: Level 2 Cache
- CLK: Clock
- PIC: Programmable Interrupt Controller
- EBL: Front Bus Logic
- BBL: Back Bus Logic
- IEU: Integer Execution Unit
- FEU: Floating Point Execution Unit
- MOB: Memory Order Buffer
- MIU/MMU: Memory Interface Unit / Memory Management Unit
- DCU: Data Cache Unit
- IFU: Instruction Fetch Unit
- ID: Instruction Decoder
- ROB - Re-Order Buffer
- MS: Microinstruction Sequencer
- BTB: Branch Target Buffer
- BAC: Branch Allocator Buffer
- RAT: Register Alias Table
- SIMD: Packed Floating Point
- DTLB: Data TLB
- RS: Reservation Station
- PMH: Page Miss Handler
- PFU: Pre-Fetch Unit
- TAP: Test Access Port

*I plan on adding to this section*.

# How Instructions Execute #

Okay, **remember that the IP register contains the offset address of the currently executing instruction. CS contains the segment address**.

Okay, so what exactly happens when the processor needs to execute an instruction?

It first calculates the absolute address that it needs to read from. **Remember that the segment:offset model, the absolute address = segment * 16 + offset**. Or, essentially, **absolute address = CS * 16 + IP**.

The processor copies this address onto the address bus. **Remember that the address bytes are just a series of electronic lines, each representing a single bit. This bit pattern represents the binary form of the absolute address of the next instruction**.

After this, the processor enables the *Read Memory* line (by setting its bit to 1). This tells the *memory controller* that we need to read from memory.

The *memory controller* takes control. The memory controller copies the address from the address bus and calculates its exact location in a particular RAM chip. The memory controller references this location and copies it on to the data bus. It does this because the *read memory* line is set on the control bus.

The memory controller resets the control bus so the processor knows it's done executing. The processor takes the value(s) from the data bus and uses its digital logic gates to "execute" it. This "value"is just a binary representation of a machine instruction, encoded as a series of electronic pulses.

Let's say, the instruction is `mov ax, 0x4c00`. The value 0xB8004C will be on the data bus for the processor. 0xB8004C is what is known as an **operation code (OPCODE)**. Every instruction has an opcode associated with it. For the x86 architecture, we would evalueate the opcode 0xB8004C. We can convert this number to binary and can see the pattern as electronic lines, where 1 means the line is high (active) and a 0 means the line is low:

	101110000000000001001100
	
The processor follows a series of discrete instructions hard-built into the digital logic circuit of the CPU. These instructions tell the processor how to encode a series of bits. All x86 processors will encode this bit pattern as our `mov ax, 0x4c00` instruction.

Due to the increasing complexity of instructions, most newer processor actually follow their own internal instruction sets. This is not new to processors, a lot of microcontrollers may use multiple internal instruction sets to decrease the complexity of the electronics. Normally these are **macrocode** and **microcode**.

Macrocode is an abstract set of instructions the processor uses to decode an instruction into microcode. Macrocode is normally written in a special macro language developed by the electronic engineers and stored on a ROM chip inside of the controller and compiled in a macro assembler. The macro assembler assembles the macrocode into an even lower level language, which is the language of the controllers: microcode.

Microcode is a very low level language developed by the electronic engineers. Microcode is used by the controller or processor to decode an instruction, such as our 0xB8004C (`mov ax, 0x4c00`) instruction.

Using its **Algorithmic Logic Unit**, the CPU can get a number, 0x4C00. And copy it into AX (a simple bit copy).

This example demonstrates how everything comes together. How the CPU uses the system bus **and relies on the memory controller to decode the memory location and follow the control bus**.

**This is an important concept. Software ports rely on the memory controller in a similar fashion**.

# Protected Mode - Theory #

Okay, so why did we talk about architecture? The unfortunate truth is that in protected mode, there is no interrupt. So let's see... No interrupts, no system calls, no standard library, no nothing. Everything we do, we have to do ourselves. Because of this, there is no helping hand to guide us. One mistake can either crash your system or even destroy your hardware if you're not careful, not only floppy disks but hard disks, external (and internal) devices, etc.

Understanding the system architecture will help us understand everything a lot better, to ensure that we don't make too many mistakes. Also, it gives us an introduction to direct hardware programming, because this is the only thing we can do.

You might be thinking: Wait, what about the awesome C Kernel you promised us? Well, remember that C is a low level language, in a way. Through inline assembly, we could create an interface to the hardware. And C, just like C++, only produces x86 machine instructions that could be executed directly by the processor. **Just remember, however, that there is no standard library and that you are programming in a very low level environment, even if you are using a high level language.

We will go over this when we start the kernel.

# Conclusion #

I never like writing these types of tutorials. They are packed with huge amounts of information, little code, displaying concepts in discrete detail for better understanding. They are simply hard to write, you know?

I hope I explained everything well enough. We went over *a lot*. Memory mapping, port mapping, the x86 port addresses, all x86 registers, the x86 memory map, system architecture, IN/OUT keywords and how they execute and how instructions execute step by step. We also have taken a look at basic hardware programming, in which we will be doing a lot.

In the next tutorial, we are going to make the switch. **Welcome to the 32 bit world!** We are also going to be looking at the GDT in detail, as we will need to make the switch. I'm also going to give warnings for common errors every step of the way. As I said before, a small itty-bitty mistake when entering protected mode ***will*** crash your program.

It's going to be fun! :)

Until next time!
