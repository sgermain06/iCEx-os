#ifndef __KEYBOARD_H
#define __KEYBOARD_H

#include "types.h"
#include "interrupts.h"
#include "port.h"
#include "keyset.h"

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