## Welcome to iCEx OS!

Simple operating system written in C++.

### Current State

The operating system is able to boot using grub and should run just fine inside a virtual machine using VirtualBox.

#### Important

Booting a physical system with this os might result in not being able to type anything, as there are no USB keyboard support implemented yet.

### Compiling

This code will compile using Linux (or WSL on Windows). Make sure you have the following installed:

- g++
- binutils
- libc6-dev-i386
- grub-pc
- grub-common
- xorriso

#### Release/Debug

The operating system is equipped with debugging information. To compile it in debug mode, simply run this:

```
make debug
```

If you don't need the debug information, simply run:

```
make release
```

This should create a file called `mykernel.iso` under the root directory. Simply use that ISO to boot your virtual machine.

### VirtualBox

Make sure you create your virtual machine specifying an unknown OS. We want the most basic configurations.

![VirtualBox](virtualbox.png)

### Support or Contact

Having trouble with Pages? Check out our [documentation](https://docs.github.com/categories/github-pages-basics/) or [contact support](https://github.com/contact) and we’ll help you sort it out.
