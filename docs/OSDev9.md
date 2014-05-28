# Introduction #

Welcome! :)

In the previous tutorial, we looked at how to switch the processor into 32 bit mode. We also learn how we can access up to 4GB of memory. That's great but... *How?!*

Also, remember that the PC boots into real mode, which has a limitation of 16 bit registers, hence the 16 bit segment addressing. This limits the amount of memory you can access in real mode. Because of this, we still cannot access even up to 1GB of memory yet. Heck, we can't even get passed the 1MB barrier yet! What do we do? We have to enable the 20th address line. This will require direct hardware programming, so we will talk abou that as well.

So, this is what's on the menu:

- Direct Hardware Programming - Theory
- Direct Hardware Programming and Controllers
- Keyboard Controller Programming - Basics
- Enabling A20
- Pizza! :)

**Due to the use of high level languages, like C, being able to access more than 1MB of memory ca be critical. Because of this, enabled A20 (address line 20) will be important!**

**Note: Remember that we cannot access over 1MB yet! Doing so will cause a triple fault.**

Also, because we are going to go over direct hardware programming, this tutorial will be a little more complicated than the previous ones. Don't worry, you'll get more experience with direct hardware programming later when we develop device drivers for the kernel.

*Ready?*

# Get Ready #

For those who have been with me this far, I'm certain you know how hard OS development is. However, we have not touched anything close to hard. All the concepts listed are still very basic, and yet quite advanced. However, **things are only going to get much more harder**.

Every single controller must be programmed a special way in order to work correctly. For example, to write (or read) a hard drive, you must first determine if it's an IDE or SCSI drive. Then, you have to determine the drive number and program it using either the IDE controller or SCSI controller, which control the IDE and SCSI connections, respectively. Both of these controllers are different.

To add more complexity, a *sector* might not be 512 bytes, hence *reading and writing sectors* is vague.

Then comes memory management and fragmentation. This is where *paging, virtual address space* and *memory management unit (MMU)* comes into play.

Reading and writing any drive is very different then any other drive. This is even true at the bootsector level. The typical format and file system is different between media, so code that boots from a FAT12 floppy will **NOT** work to boot a CDFS filesystem CDROM. However, by abstracting hardware-specific (and low level code), we can make most of the code work for these devices.

When we say *write a file to hard drive*, we normally don't want to define what a *file* is, because we shouldn't. We shouldn't have to worry about what controller to read to/from nor the exact location on disk. **This is why abstraction is \*VERY\* important!**

Everything here is primarily for protected mode (i.e., it is 32 bit code), although it will work in real mode as well. Because of this, remember the rule of protected mode:
- **No interrupt are available! The use of interrupt will cause a triple fault**

You are **completely** on your own.

# Kernel Debugging #

Debugging is an art form. It provides a way of trapping problems and fixing errors through software before they become serious. **Kernel debugging** relates to debugging kernel-level ring 0 programs. This is never an easy task.

## Debugging in High Level Languages ##

Most debuggers in languages like C and C++, provide a way of displaying variables and routine names, and their values, locations, etc, during runtime. The problem? We don't have any symbolic names yet in any of our programs. We are still working at the binary level.

What this means is that we need a debugger that could work and display memory directly. Bochs has a debugger just for us.

## Bochs Debugger ##

Bochs comes with a debugger called **bocksdbg**. When you launch it, you will be given the same startup screen from **bochs**. Load your configuration file and start the emulation.

Bochs debugger and display window will now appear and you should see the line:

		[0x000ffff0] f000:fff0 (unk. ctxt): jmp f000:e05b		; ea5be000f0
		< bochs:1> _
		
The second line tells you the number of commands sent to it (in this case, this is the first command, so 1 is displayed). You can type your commands here.

The first line is the important line. It tells you the current instruction, absolute address and  segment:offset address. It also gives you the machine language **operation code (OPCode)** equivalent.

### HELP Command ###

The **help** command gives you a list of available commands.

### BREAK Command ###

The **b (break)** command allows you to set breakpoints at addresses in memory. For example, if we are trying to debug our OS, we need to start the at the bootloader (07c00:0). However, Bochs debugger starts where the BIOS is at. Because of this, we will need to set a breakpoint to 0x7c00:0 and continue execution until that breakpoint is reached:

	// BIOS is at 0xea5be000f0
		[0x000ffff0] f000:fff0 (unk. ctxt): jmp f000:e05b
		< bochs:1> b 0x7c00						// Sets the breakpoint to 0x7c00:0
		< bochs:2> c							// Continue execution
		< 0> Breakpoint 1, 0x7c00 in ?? < >		// Our breakpoint is hit
		Next at t=834339						// We are now at our bootloader's first instruction
		< 0> [0x00007c00] 0000:7c00 (unk. ctxt): jmp 7cb5		; e9b200
		
The above tells us that our main() function in our bootloader is at 0x7cb5. This makes sense because remember that the OEM parameter block is between this jump instruction and the start of main().

Knowing that the bootloader loads stage 2 at 0x500, let's break to it:

		< bochs:3> b 0x500
		< bochs:4> c
		< 0> Breakpoint 2, 0x500 in ?? < >
		Next at t=934606
		< 0> [0x00000500] 0050:0000 (ink. ctxt): jmp 00a0		; e99d00
		< bochs:5> _
	
Now, we are at the beginning of stage 2 and could follow the debugger with our assembly file! Cool, huh? Best of all, you can see the window dynamically update to display the output of your system.

### Single Step ###

The **s (single step)** command is used to walk through one instruction at a time:

		< bochs:6> s
		Next at t=934607
		<0> [0x000005a0] 0050:00a0 (ink. ctxt): cli				; fa
		< bochs:7> s
		Next at t=934608
		<0> [0x000005a1] 0050:00a1 (ink. ctxt): xor AX, AX		; 31c0
		< bochs:8> _

### dump_cpu ###

This command displays the current value of all CPU registers, including RFLAGS, general purpose, test, debug, control and segment registers. It also includes GDTR, IDTR, LDTR, TR and EIP.

### print_stack ###

This displays the current value of the stack. This is critical, considering that we use the stack very often.

### Conclusion ###

There are more commands than this, but these are the most useful. Learning how to use the debugger is very important, especially in the early stages like we are in now.

# Direct Hardware Programming - Theory #

This is where things start getting very hard in operating system development.

*Direct hardware programming* simply refers to communicating directly (and controlling) individual chips. As long as these chips are programmable in some way, we can control them.

In Tutorial 7, we took a very detailed look at how the system works. We also talked about how software ports work, port mapping, the IN and OUT instructions and I gave a huge table with common port mappings on x86 architectures.

Remember that, whenever the processor receives an **IN** or **OUT** instruction, it enables the **I/O ACCESS** line on the **control bus**, which is, of course, part of the **system bus**, on the **motherboard's north bridge**. Because the system bus is connected to both the memory controller and the I/O controller, both controllers listen for specific addresses and activated lines on the control bus. If the I/O ACCESS line is set (electricity runs through it, which means it's active), the I/O controller takes the address.

The I/O controller then gives the port address to every other device and awaits a signal from the controller chip (meaning that it belongs to some device, so give whatever data to that device). If no controller chip responds and the port address is set back, it is ignored.

This is how port mapping works. Please refer to Tutorial 7 for more details.

Also, remember that a single controller chip may be assigned a range of port addresses. Port addresses are assigned by the BIOS POST, even before the BIOS is loaded and executed. Why? A lot of devices need different types of instructions. Some ports may represent *registers*, while others may be *data* or *ready* ports. It's ugly, I know, but it gets worse. On different systems, port addresses may vary widely. Because x86 architecture are backwards compatible, basic devices (such as keyboards and mice) are usually always the same address. However, more complex devices may not be.

# Direct Hardware Programming and Controllers #

To better understand how everything works, let's look at controllers. After all, we will be talking to them a lot, especially in protected mode.

Many PCs are based off the early **Intel 8042 Microcontroller chip**. This controller chip is either embedded as an IC (integrated circuit) chip or directly in the motherboard. It is usually located in the **south bridge**.

This microcontroller communicates through a cord connecting your keyboard to another microcontroller chip in your keyboard.

When you press a key on the keyboard, it presses down on a rubber dome setting beneath the key itself. On the underside of the rubber dome is a contact that, when pressed down, closes a circuit on the keyboard. Because of this, current can flow through. Each key is connected by a pair of electrical lines. As each signal changes (depending on wether keys are pressed), a make code is generated (from the series of lines). This make code is sent to the microcontroller chip inside the keyboard and sent through the cord connected to the computer's hardware port. It is sent through a series of on and off electrical pulses. Depending on the clock cycles, each pulse can be converted to a series of bits representing a bit pattern.

We are on the motherboard. This series of bits goes through the south bridge as electrical signals, all the way to the 8042 microcontroller. This microcontroller decodes the make code into a scan code and stores it within an internal register. That's our buffer. The internal registers can be an EEPROM chip, or similar, so we can electrically overwrite the data whenever we want.

When booting, the BIOS POST assigns each device (through the I/O controller) port addresses. It does this by querying the devices. In the usual case, the BIOS POST sets this internal register at port address 0x60. This means, **whenever we reference port 0x60, we are requesting to read from this internal register**.

You know the rest of the story regarding port mapping and IN/OUT instructions, so let's read from that register:

		in	al, 0x60				; get byte from 8042 microcontroller input register
		
As you can probablu guess, **the 8042 microcontroller is the keyboard controller**. By communicating with the various registers with the chip, we can read input from the keyboard, map scan codes, even several other things: **like enabling A20**.

You might be wondering why you have to communicate to the keyboard controller to enable A20. We will look at this next.

# Gate A20 - Theory #

Finally, we cover A20. I know, I know, most of this tutorial so far covers other topics that are not directly related to A20. However, I wanted to start with the basics of direct hardware programming first before going into A20; as A20 requires it, along with any microcontroller programming.

## A Little History ##

When IBM designed the IBM PC AT machines, it used their newer **Intel 80286 microprocessor**, which was not entirely compatible with previous x86 microprocessor when in real mode. The problem? The older x86 processors **did not** have address lines A20 through A31. They did not have an address bus that size yet. **Any programs that go beyond the first 1MB would appear to wrap around**. While it worked back then, the 80286's address space required 32 address lines. However, if all 32 lines are accessible, we get the wrapping problem again.

To fix the problem, Intel put a logic gate on the 20th address line between the processor and the system bus. This logic gate got named **Gate A20**, as it can be enabled and disabled. For older program, it can be disabled for programs that rely on the wrap around and enabled for newer programs.

**When booting, the BIOS enables A20 when counting and testing memory and then disables it again before giving control to our operating system**.

There are a lot of ways to enable A20. By enabling the A20 gate, we have access to all 32 lines on the address bus and can reference 32 bit addresses, or up to 0xFFFFFFFF (4GB of memory).

The Gate A20 is an electronic OR gate that was originally connected to P21 electrical line of the 8042 microcontroller (the keyboard controller). This gate is an output line that is treated as **bit 1** of the output port data. We can send the command to receive this data and even modify it. By setting this bit and writing the output line data, we can have the microcontroller set the OR gate, this enabling the A20 line. We can either do this ourselves directly or indirectly. We will look at this more in the next section.

During bootup, the BIOS enables the A20 line to test memory. After the memory test, the BIOS disables the A20 line to retain compatibility with older processors. Because of this, by default, the A20 line is disabled for our operating system.

There can be several different ways to re-enable gate A20, depending on your motherboard configuration. Because of this, I will cover several different, more common, methods to enable A20.

Let's look at this next.

# Gate A20 - Enabling #

Remember that there are a lot of different ways to enable A20. If you are wanting to get just your system working, all you need to do is use a method that works for you. If portability is a requirement, you may be required to use a mixture of methods.

## Method 1: System Control Port A ##

This is a very fast, yet less portable, method of enabling the A20 address line.

On some systems, including MCA and EISA, we can control A20 form the system control port I/O 0x92. The exact details and functions of port 0x92 vary greatly by manufacturer. There are several bits that are commonly used though:

- Bit 0: Setting to 1 causes a fast reset (used to switch back to real mode)
- Bit 1: 0: Disable A20; 1: Enable A20
- Bit 2: Manufacturer define
- Bit 3: Power on password bytes (CMOS bytes 0x38-0x3f, or 0x36-0x3f). 0: accessible; 1: inaccessible.
- Bits 4-5: Manufacturer defined
- Bits 6-7: 00: HDD activity LED off; any other value is "on"

Here's an example that enables A20 using this method:

		mov		al, 2						; Set bit 2 (enable A20)
		out		0x92, al
		
Notice there are a lot of things we can do with this port:

		mov		al, 1						; Set bit 1 (fast reset)
		out		0x92, al
		
This method seems to work with Bochs as well.

### Warning! ###

While this is one of the easier methods, I have seen this method conflict with some other hardware devices. It would normally cause the system to halt. If you want to use this method (and it works for you), I would stick with using it, but please keep this in mind.

### Other ports ###

I feel that I should mention that some systems allow the use of other I/O ports to enable and disable A20.

The most common of these are I/O port 0xEE. If I/O port 0xEE (FAST A20 GATE) is enabled on these systems, reading from this port enables A20 and writing to it disables A20. A similar effect occurs for port 0xEF (FAST CPU RESET) as well for resetting the system.

Other systems may use different ports (i.e., AT&T 6300+ needs to write 0x90 to I/O port 0x3f20 to enable A20 and write 0 to disable A20). There are also rumors of systems that exist that use bit 2 of I/O port 0x65 or bit 0 of I/O port 0x1f8 for enabling and disabling A20 (0: disable, 1: enable).

As you can see, there are a lot of headaches when it comes to working with A20. the only way to be sure is with your motherboard manufacturer.

## Method 2: BIOS ##

A lot of BIOS' make interrupts available for enabling and disabling A20.

### Bochs Support ###

It seems some versions of Bochs recognizes these methods but it may not be supported in some versions of Bochs.

### INT 0x15 Function 2400 - Disable A20 ###

This function disables the A20 gate. It is very easy to use:

		mov		ax, 0x2400
		int		0x15
		
Returns:

	Success:
		CF: Clear
		AH: 0
	Error:
		CF: Set on error
		AH: status (01: Keyboard controller is in secure mode, 0x86: function not supported)
	
### INT 0x15 Function 2401 - Enable A20 ###

This function enables the A20 gate.

		mov		ax, 0x2401
		int		0x15
		
Returns:

	Success:
		CF: Clear
		AH: 0
	Error:
		CF: Set on error
		AH: status (01: Keyboard controller is in secure mode, 0x86: function not supported)
	
### INT 0x15 Function 2402 - A20 Status ###

This function returns the current status of the A20 gate.

		mov		ax, 0x2402
		int		0x15
		
Returns:

	Success:
		CF: Clear
		AH: Status (01: Keyboard controller is in secure mode, 0x86: function not supported)
		AL: Current state (00: Disabled, 01: Enabled)
		CX: Set to 0xffff is keyboard controller is not ready, in 0xc000 read attempts.
	Error:
		CF: set on error
		
### INT 0x15 Function 2403 - Query A20 support

This function is used to query the system for A20 support.

		mov		ax, 0x2403
		int		0x15
		
Returns:
	
	Success:
		CF: Clear
		AH: Status (01: Keyboard controller is in secure mode, 0x86: function not supported)
		BX: Status
		
BX contains a bit pattern:
- Bit 0: 1 if supported on keyboard controller
- Bit 1: 1 if supported on bit 1 of I/O port 0x92
- Bits 2-14: Reserved
- Bit 15: 1 if additional data is available

## Method 3: Keyboard Controller ##

This is probably the most common method of enabling A20. it's quite easy, but requires some knowledge of programming the keyboard microcontroller. This will be the method I will be using, as it seems it is also the most portable. Because this requires some knowledge of programming the keyboard microcontroller, we should look at that a little bit first.

This is also the reason why I wanted to cover hardware programming first. This will be our first glimpse into direct hardware programming and what it's all about. Don't worry, it's not too bad. It can get quite complex at times though.

### 8043 Keyboard Controller - Port Mapping ###

Remember that, in order for us to communicate with this controller, we must know what I/O port the controller uses.

This controller has the following port mapping:

<table>
	<tr>
		<th bgcolor="#999999" colspan="3">Port Mapping</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Port</td>
		<td bgcolor="#c0c0c0">Read/Write</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x60</td>
		<td>Read</td>
		<td>Read input buffer</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x60</td>
		<td>Write</td>
		<td>Write output buffer</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x64</td>
		<td>Read</td>
		<td>Read status register</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x64</td>
		<td>Write</td>
		<td>Send command to controller</td>
	</tr>
</table>

We send commands to this controller by writing the command byte to I/O port 0x64. If the command accepts a parameter, this parameter is sent to port 0x60. Likewise, any results returned by the command may be read from port 0x60.

We must note that the keyboard controller itself is quite slow. Because our code will be executing faster than the keyboard controller, we must provide a way to wait for the controller to be ready before we continue on.

This is usually done by querying the controller status. If this seems confusing, don't worry, everything will be clear soon enough.

### 8043 Keyboard Controller Status Register ###

Okay, how do we get the status of the controller? Looking at the table above, we can see that we must read from I/O port 0x64. The value read from this register is an 8 bit value that follows a specific format. Here it is:

- Bit 0: **Output Buffer Status**
	- 0: Output buffer empty, don't read yet.
	- 1: Output buffer full, please read me! :)
- Bit 1: **Input buffer Status**
	- 0: Input buffer empty, can be written
	- 1: Input buffer full, don't write yet
- Bit 2: System Flag
	- 0: Set after power on reset
	- 1: Set after successful completion of the keyboard controller self-test (Basic Assurance Test (BAT))
- Bit 3: Command Data
	- 0: Last write into input buffer was data (via port 0x60)
	- 1: Last write into input buffer was a command (via port 0x64)
- Bit 4: Keyboard locked
	- 0: Locked
	- 1: Not locked
- Bit 5: Auxiliary output buffer full
	- PS/2 systems:
		- 0: Determines if read from port 0x60 is valid. If valid, 0 = Keyboard data
		- 1: Mouse data, only if you can read from port 0x60
	- AT systems:
		- 0: OK flag
		- 1: Timeout on transmission from keyboard controller to keyboard. **This may indicate no keyboard is present**.
- Bit 6: Timeout
	- 0: OK flag
	- 1: Timeout
	- PS/2:
		- General Timeout
	- AT
		- Timeout on transmission from keyboard controller to keyboard. **Possible parity error (in which case both bits 6 and 7 are set)
- Bit 7: Parity error
	- 0: OK flag, no error
	- 1: Parity error with last byte
	
As you can see, there's a lot going on there! The important bits are bolded above. They will tell us if the controller's output or input buffers are full or not.

Here's an example. Let's say we send a command to the controller. This is placed in the controller's input buffer. So, as long as this buffer is still full, we know our command is still being performed. Here's what our code might look like:

	wait_input:
		in		al, 0x64						; Read status register
		test	al, 2							; Test bit 2 (input buffer status)
		jnz		wait_input						; Jump if it's not 0 (not empty) to continue waiting.
		
We will be needing to do this for both the input and output buffers.

Now that we are able to wait for the controller, we must be able to tell the controller what we need it to do. This is done through command bytes. Let's take a look!

### 8043 Keyboard Command Register ###

Looking back at the I/O port table, we can tell that we need to write to I/O port 0x64 to send commands to the controller.

The keyboard controller has **a lot** of commands. Because this is not a tutorial on keyboard programming, I will not list them all here. However, I will list the more important onces:

<table>
	<tr>
		<th colspan="2" bgcolor="#999999">Keyboard Controller Commands</th>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Keyboard Command</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x20</td>
		<td>Read Keyboard Controller Command Byte</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0x60</td>
		<td>Write Keyboard Controller Command Byte</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xAA</td>
		<td>Self Test</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xAB</td>
		<td>Interface Test</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xAD</td>
		<td>Disable Keyboard</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xAE</td>
		<td>Enable Keyboard</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xC0</td>
		<td>Read Input Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xD0</td>
		<td>Read Output Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xD1</td>
		<td>Write Output Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xDD</td>
		<td>Enable A20 Address Line</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xDF</td>
		<td>Disable A20 Address Line</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xE0</td>
		<td>Read Test Inputs</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xFE</td>
		<td>System Reset</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">Mouse Command</td>
		<td bgcolor="#c0c0c0">Description</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xA7</td>
		<td>Disable Mouse Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xA8</td>
		<td>Enable Mouse Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xA9</td>
		<td>Test Mouse Port</td>
	</tr>
	<tr>
		<td bgcolor="#c0c0c0">0xD4</td>
		<td>Write To Mouse</td>
	</tr>
</table>

Again, please take note that there are **A LOT** more commands than this. We will look at them later, don't worry. :)

### Method 3.1: Enabling A20 Through Keyboard Controller ###

Notice the command bytes **0xDD** and **0xDF** in the table above. This is one way to enable A20 using the keyboard controller:

		mov		al, 0xdd						; Set AL to command 0xDD
		out		0x64, al						; Send command to port 0x64
		
Not all keyboard controllers support this function. If it works, I would stick with it for its simplicity.

### Method 3.2: Enabled A20 Through Output Port ###

Yet *another* method of enabling A20 is through the keyboard controller's output port. To do this, we need to use the commands D0 and D1 to read and write the output port (please see the **keyboard controller commands** table again for reference).

This method is a little bit more complex than the other methods, but it's not too bad. Basically, we can disable the keyboard and read the output from the controller. The 8042 contains three ports: input, output and the third is for testing. These "ports" are just the hardware pins on the microcontroller.

To keep things simple (and because this isn't a keyboard programming tutorial), we will look at the output port for now.

Okay, read from the output port, simply send the read output port command (0xD0) to the controller.

		mov		al, 0xd0						; Set AL to command 0xD0
		out		0x64, al						; Send command to port 0x64
		
Now we have gotten the output port data. Great, but that isn't very useful, is it? Well, actually, the output port data follows, yet again, a specific bit format.

*Let's take a look:*

- Bit 0: **System Reset**
	- 0: Reset computer
	- 1: Normal operation
- Bit 1: A20
	- 0: Disabled
	- 1: Enabled
- Bits 2-3: Undefined
- Bit 4: Input buffer full
- Bit 5: Output buffer empty
- Bit 6: Keyboard clock
	- 0: High-Z
	- 1: Pull clock low
- Bit 6: Keyboard Data
	- 0: High-Z
	- 1: Pull data low
	
Most of these bits we don't want to change. Setting bit 0 to 1 resets the computer; setting bit 1 enables gate A20. You should OR this value to set the bit to insure none of the other buts get touched. After setting the bit, just write the value back (command byte 0xD1).

**The commands used to read and write the output port use the input and output buffers of the controller for its data.**

This means, if we read the output port, the data read will be in the controller's input buffer register. Looking back at the I/O port table, this means to get the data we read from I/O port 0x60.

Let's look at an example. During any read or write operation, we will want to wait for the controller to be ready. **wait_input** waits for the input buffer to be empty, while **wait_output** waits for the output buffer to be empty.

		mov		al, 0xdd						; Copy command 0xD0 to AL
		out		0x64, al						; Write command to port 0x64
		call	wait_output						; Wait for output buffer to be empty
		
		in		al, 0x60						; Copy data at port 0x60 into AL
		push	eax								; Push eax to the stack
		call	wait_input						; Wait for input buffer to be empty
		
		mov		al, 0xd1						; Copy command 0xD1 to AL
		out		0x64, al						; Write the command to port 0x64
		call	wait_input						; Wait for output buffer to be empty
		
		pop		eax								; Bring the data back from the stack into eax
		or		al, 2							; Set bit 2 (2 = 10b)
		out		0x60, al						; Write data to the output port. This is done through the output buffer. (0x60)
		
That's all there is to it! :) This method is a bit more complex than the other methods but is also the most portable.

## Cautions ##

Because of its emulation, most of these don't apply to Bochs. Real hardware will work though.

### Controller Executes the Wrong Command ###

If the controller executes the wrong command, it will usually do something you don't want. Like, perhaps, read data from a port instead of write data, which may corrupt your data. For example, using `in al, 0x61` instead of `in al, 0x60` which will read from a different register in the keyboard microcontroller, instead of the status register (port 0x60).

### Unknown Controller Command ###

Most controllers ignore commands it doesn't know and just discards it (clears its command register, if any).

However, some controllers may malfunction. Please see the "Malfunction" section for more information.

### Controller Malfunctions ###

This happens rarely, bit is possible. Two notable instances are both with the Pentium processor, including the infamous FDIV and food bugs. FDIV bug was an internal CPU design flaw, in which the FPU inside the processor gives incorrect results.

The foof problem is more series. When the processor is given the command bytes 0xf0 0x0f 0xc7 0xc7, which is an example of an **Halt and Catch Fire (HCF)** instruction (an **undocumented instruction**). Most of these instructions may lock up the processor itself, forcing the user to hard reboot. Others may cause unusual side effects.

One should consider these problems that may happen. It does happen and controllers are no exception. Remember that we send instruction bytes to individual ports? For example, 0x64 -- the command register in the keyboard controller.

Most of these malfunctions can easily be considered "design flaws" of the device though.

### Physical Hardware Damage ###

Although also rare, it is possible to inflict hardware damage through software. An easy example is the floppy drive. You have to control the floppy drive motor directly though the **Floppy Drive Controller (FDC)**. Forgetting to send the command to stop the motor can cause the floppy drive to wear out and break. Be careful!

### Triple Fault ###

The microcontroller may signal the primary processor that there is a problem via the control bus, in which case the processor signals an exception, which will, of course, reboot the computer.

### Controller problems in Bochs ###

If there is a controller problem, Bochs will provoke a triple fault and log the information into the log.

For example, if you try to send an unknown command (such as 0) to the keyboard controller:

		mov		al, 0x00						; Some random command
		out		0x64, al						; Try to send the command to the controller
		
Bochs will provoke a triple fault and log the information:

		[KBD   ] unsupported io write to keyboard port 64, value = 0
		
"KBD" represents that the log was written by the keyboard controller device.

