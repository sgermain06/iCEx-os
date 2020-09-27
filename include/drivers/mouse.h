#ifndef __MOUSE_H
#define __MOUSE_H

#include <common/types.h>
#include <hardware/interrupts.h>
#include <hardware/port.h>
#include <drivers/screen.h>

class MouseDriver : public InterruptHandler
{
    Port8Bit dataPort;
    Port8Bit commandPort;

    int8_t buffer[3];
    uint8_t offset;
    uint8_t buttons;

    Screen* screen;
public:
    MouseDriver(InterruptManager* manager, Screen* screen);
    ~MouseDriver();
    virtual uint32_t HandleInterrupt(uint32_t esp);
};

#endif