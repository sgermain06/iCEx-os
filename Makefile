GCCPARAMS = -m32 -fno-use-cxa-atexit -nostdlib -fno-builtin -fno-rtti -fno-exceptions -fno-leading-underscore -Wno-write-strings
ASPARAMS = --32
LDPARAMS = -melf_i386

objects = 	loader.o \
			gdt.o \
			port.o \
			interruptstubs.o \
			interrupts.o \
			screen.o \
			keyset.o \
			keyboard.o \
			kernel.o

%.o: %.cpp
	g++ $(GCCPARAMS) -c -o $@ $<

%.o: %.s
	as $(ASPARAMS) -o $@ $<


mykernel.bin: linker.ld $(objects)
	ld $(LDPARAMS) -T $< -o $@ $(objects)

debug: GCCPARAMS += -DDEBUG -g
debug: release

release: mykernel.bin
	mkdir -p iso/boot/grub
	cp $< iso/boot/
	echo 'set timeout=0'                   > iso/boot/grub/grub.cfg
	echo 'set default=0'                  >> iso/boot/grub/grub.cfg
	echo 'menuentry "iCEx OS" {'          >> iso/boot/grub/grub.cfg
	echo '  multiboot /boot/mykernel.bin' >> iso/boot/grub/grub.cfg
	echo '  boot'                         >> iso/boot/grub/grub.cfg
	echo '}'                              >> iso/boot/grub/grub.cfg
	grub-mkrescue --output=mykernel.iso iso
	rm -rf iso
	rm *.o
	rm mykernel.bin

.PHONY: clean
clean:
	rm -f $(objects) mykernel.bin mykernel.iso