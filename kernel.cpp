#include "types.h"
#include "gdt.h"
#include "interrupts.h"
#include "keyboard.h"

uint8_t strlen(char* str) {
    uint8_t returnVal = 0;
    for (int i = 0; str[i] != '\0'; ++i) {
        returnVal++;
    }
    return returnVal;
}

void printf(char* str)
{
    static uint16_t* videoMemory = (uint16_t*)0xb8000;

    static uint8_t x = 0, y = 0;

    for (int i = 0; str[i] != '\0'; ++i) {
        switch (str[i]) {
            case '\n':
                x = 0;
                y++;
                break;
            default:
                videoMemory[(y * 80 + x)] = (videoMemory[(y * 80 + x)] & 0xFF00) | str[i];
                x++;
                break;
        }

        if (x >= 80) {
            x = 0;
            y++;
        }
        if (y >= 25) {
            for (y = 0; y < 25 ; y++) {
                for (x = 0; x < 80; x++) {
                    videoMemory[y * 80 + x] = (videoMemory[(y * 80 + x)] & 0xFF00) | ' ';
                }
            }
            x = 0;
            y = 0;
        }
    }
}

void printf(char* str, uint8_t number)
{
    char* hex = "0123456789ABCDEF";
    uint8_t length = strlen(str);

    str[length + 1] = hex[(number >> 4) & 0x0F];
    str[length + 2] = hex[number & 0x0F];
    str[length + 3] = '\0';
    
    printf(str);
}

void debug(char* str) {
    #ifdef DEBUG
    printf(str);
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
    printf("Hello, world! Welcome to iCEx OS!\n");

    debug("- Creating Global Descriptor Table\n");
    GlobalDescriptorTable gdt;
    debug("- Initializing Interrupt Manager\n");
    InterruptManager interrupts(&gdt);

    KeyboardDriver keyboardDriver(&interrupts, 1);


    debug("- Activating interrupts\n");
    interrupts.Activate();

    while(1);
}