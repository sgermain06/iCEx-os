#include <drivers/mouse.h>

void printf(char* str, ...);

MouseDriver::MouseDriver(InterruptManager* manager, Screen* screen) :
    InterruptHandler(0x2C, manager),
    dataPort(0x60),
    commandPort(0x64)
{
    offset = 0;
    buttons = 0;
    this->screen = screen;

    this->screen->moveMouse(40, 12);

    commandPort.Write(0xA8); // Start sending keyboard interrupts
    commandPort.Write(0x20); // Ask PIC for current state
    uint8_t status = dataPort.Read() | 2;
    commandPort.Write(0x60); // Set state 
    dataPort.Write(status);

    commandPort.Write(0xD4);
    dataPort.Write(0xE8);
    while (!commandPort.Read() & 1) asm("pause");
    uint8_t setResolutionCmdResponse = dataPort.Read();
    printf("Set Resolution Comamnd Response: %x\n", setResolutionCmdResponse);

    commandPort.Write(0xD4);
    dataPort.Write(0x00);
    while (!commandPort.Read() & 1) asm("pause");
    uint8_t setResolutionValResponse = dataPort.Read();
    printf("Set Resolution Value Response: %x\n", setResolutionValResponse);

    commandPort.Write(0xD4);
    dataPort.Write(0xF4);    // Activate the keyboard
    dataPort.Read();    // Activate the keyboard
}

MouseDriver::~MouseDriver()
{

}

uint32_t MouseDriver::HandleInterrupt(uint32_t esp)
{
    uint8_t status = commandPort.Read();
    if (!(status & 0x20)) {
        return esp;
    }

    buffer[offset] = dataPort.Read();
    offset = (offset + 1) % 3;

    if (offset == 0) {
        if (buffer[1] != 0 || buffer[2] != 0) {
            int8_t xOffset = (buffer[1] / 8);
            int8_t yOffset = (buffer[2] / 8);
            this->screen->moveMouse(xOffset, yOffset);
        }

        //TODO: Need to implement buttons clicks.
        // for (uint8_t i = 0; i < 3; i++) {
        //     if ((buffer[0] * (0x1<<i)) != (buttons & (0x1 << i))) {
        //         if (buttons & (0x1 <<i)) {
        //             this->onMouseUp(i+1);
        //         }
        //         else {
        //             this->onMouseDown(i+1);
        //         }
        //     }
        // }
        buttons = buffer[0];
    }

    return esp;
}
