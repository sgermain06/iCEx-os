GCCPARAMS = -m32 -Iinclude -fno-use-cxa-atexit -nostdlib -fno-builtin -fno-rtti -fno-exceptions -fno-leading-underscore -Wno-write-strings
ASPARAMS = --32
LDPARAMS = -melf_i386

objects = 	obj/loader.o \
			obj/hardware/port.o \
			obj/gdt.o \
			obj/hardware/interruptstubs.o \
			obj/hardware/interrupts.o \
			obj/drivers/screen.o \
			obj/drivers/keyset.o \
			obj/drivers/keyboard.o \
			obj/drivers/mouse.o \
			obj/kernel.o 

obj/%.o: src/%.cpp
	@mkdir -p $(@D)
	g++ $(GCCPARAMS) -c -o $@ $<

obj/%.o: src/%.s
	@mkdir -p $(@D)
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
	rm -rf obj
	rm mykernel.bin

.PHONY: clean
clean:
	rm -f $(objects) mykernel.bin mykernel.iso