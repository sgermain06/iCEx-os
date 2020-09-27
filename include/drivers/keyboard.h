#ifndef __KEYBOARD_H
#define __KEYBOARD_H

#include <common/types.h>
#include <hardware/interrupts.h>
#include <hardware/port.h>
#include <drivers/keyset.h>

class KeyboardDriver : public InterruptHandler
{
    Port8Bit dataPort;
    Port8Bit commandPort;
    KeySet keySet;
public:
    KeyboardDriver(InterruptManager* manager, uint8_t keySet);
    ~KeyboardDriver();
    virtual uint32_t HandleInterrupt(uint32_t esp);
};

#endif