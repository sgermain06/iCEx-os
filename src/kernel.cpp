#include <common/types.h>
#include <gdt.h>
#include <hardware/interrupts.h>

// Consolidating drivers includes
#include <drivers/drivers.h>

Screen screen;

void printf(char* str, ...)
{
    va_list args;
    va_start(args, str);
    screen.vprintf(str, args);
    va_end(args);
}

void debug(char* str, ...) {
    #ifdef DEBUG
    va_list args;
    va_start(args, str);
    screen.vprintf(str, args);
    va_end(args);
    #endif
}

typedef void (*constructor)();
extern "C" constructor start_ctors;
extern "C" constructor end_ctors;
extern "C" void callConstructors()
{
    for (constructor* i = &start_ctors; i != &end_ctors; i++) {
        (*i)();
    }
}

extern "C" void kernelMain(const void* multiboot_structure, uint32_t magicnumber)
{
    screen.displayHeader("                        Hello, world! Welcome to iCEx OS");
    debug("Testing arguments: Decimal: %d, Hex: 0x%x\n", 32, 32);
    debug("- Creating Global Descriptor Table\n");
    GlobalDescriptorTable gdt;
    debug("- Initializing Interrupt Manager\n");
    InterruptManager interrupts(&gdt);

    KeyboardDriver keyboardDriver(&interrupts, 1);
    MouseDriver mouseDriver(&interrupts, &screen);

    debug("- Activating interrupts\n");
    interrupts.Activate();

    while(1);
}