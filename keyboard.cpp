#include "keyboard.h"

void printf(char* str);

KeyboardDriver::KeyboardDriver(InterruptManager* manager, uint8_t keySet) :
    InterruptHandler(0x21, manager),
    dataPort(0x60),
    commandPort(0x64),
    keySet(keySet)
{
    this->keySet = KeySet(keySet);
    while(commandPort.Read() & 0x1) {
        dataPort.Read();
    }
    commandPort.Write(0xAE); // Start sending keyboard interrupts
    commandPort.Write(0x20); // Ask PIC for current state
    uint8_t status = (dataPort.Read() | 1) & ~0x10;
    commandPort.Write(0x60); // Set state 
    dataPort.Write(status);

    dataPort.Write(0xF4);    // Activate the keyboard
}

KeyboardDriver::~KeyboardDriver()
{

}

uint32_t KeyboardDriver::HandleInterrupt(uint32_t esp)
{
    uint8_t key = dataPort.Read();

    if (key < 0x80) {
        keySet.OnKeyDown(key);
    }
    else {
        keySet.OnKeyUp(key);
    }

    return esp;
}
