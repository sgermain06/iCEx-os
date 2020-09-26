#include "interrupts.h"

void printf(char* str, ...);
void debug(char* str, ...);

InterruptHandler::InterruptHandler(uint8_t interruptNumber, InterruptManager* interruptManager)
{
    this->interruptNumber = interruptNumber;
    this->interruptManager = interruptManager;
    interruptManager->handlers[interruptNumber] = this;
}

InterruptHandler::~InterruptHandler()
{
    if (interruptManager->handlers[interruptNumber] == this) {
        interruptManager->handlers[interruptNumber] = 0;
    }
}

uint32_t InterruptHandler::HandleInterrupt(uint32_t esp)
{
    return esp;
}



InterruptManager::GateDescriptor InterruptManager::interruptDescriptorTable[256];

InterruptManager* InterruptManager::ActiveInterruptManager = 0;

void InterruptManager::SetInterruptDescriptorTableEntry(
    uint8_t interruptNumber,
    uint16_t codeSegmentSelectorOffset,
    void (*handler)(),
    uint8_t DescriptorPrivilegeLevel,
    uint8_t DescriptorType
)
{
    interruptDescriptorTable[interruptNumber].handlerAddressLowBits = ((uint32_t)handler) & 0xFFFF;
    interruptDescriptorTable[interruptNumber].handlerAddressHighBits = (((uint32_t)handler) >> 16) & 0xFFFF;
    interruptDescriptorTable[interruptNumber].gdt_codeSegmentSelector = codeSegmentSelectorOffset;

    const uint8_t IDT_DESC_PRESENT = 0x80;
    interruptDescriptorTable[interruptNumber].access = IDT_DESC_PRESENT | ((DescriptorPrivilegeLevel & 3) << 5) | DescriptorType;
    interruptDescriptorTable[interruptNumber].reserved = 0;
}

InterruptManager::InterruptManager(GlobalDescriptorTable* gdt) :
    picMasterCommand(0x20),
    picMasterData(0x21),
    picSlaveCommand(0xA0),
    picSlaveData(0xA1)
{
    // Set all the entries to the ignoreInterruptRequest.
    // If not all interrupt requests don't have a handler, we get a general protection fault and OS crashes.
    uint32_t CodeSegment = gdt->CodeSegmentSelector();
    const uint8_t IDT_INTERRUPT_GATE = 0xE;

    debug("  - Filling up interrupt descriptor table\n");
    for (uint8_t i = 255; i > 0; --i) {
        SetInterruptDescriptorTableEntry(i, CodeSegment, &InterruptIgnore, 0, IDT_INTERRUPT_GATE);
        handlers[i] = 0;
    }

    debug("  - Enabling 0x20 and 0x21 interrupt handlers\n");
    SetInterruptDescriptorTableEntry(0x20, CodeSegment, &HandleInterruptRequest0x00, 0, IDT_INTERRUPT_GATE);
    SetInterruptDescriptorTableEntry(0x21, CodeSegment, &HandleInterruptRequest0x01, 0, IDT_INTERRUPT_GATE);

    debug("  - Initializing programmable interrupt controllers (master/slave)...\n");
    picMasterCommand.Write(0x11);
    picSlaveCommand.Write(0x11);

    picMasterData.Write(0x20);
    picSlaveData.Write(0x28);

    picMasterData.Write(0x04);
    picSlaveData.Write(0x02);

    picMasterData.Write(0x01);
    picSlaveData.Write(0x01);

    picMasterData.Write(0x00);
    picSlaveData.Write(0x00);

    debug("  - Initializing interrupt descriptor table\n");
    InterruptDescriptorTablePointer idt;
    idt.size  = 256 * sizeof(GateDescriptor) - 1;
    idt.base  = (uint32_t)interruptDescriptorTable;
    asm volatile("lidt %0" : : "m" (idt));
}

void InterruptManager::Activate()
{
    if (ActiveInterruptManager != 0) {
        debug("  - Active Interrupt Manager not empty, deactivating\n");
        ActiveInterruptManager->Deactivate();
    }
    debug("  - Setting active interrupt manager to current instance\n");
    ActiveInterruptManager = this;
    asm("sti");
}

void InterruptManager::Deactivate()
{
    if (ActiveInterruptManager == this) {
        debug("  - Active interrupt manager is current instance, disabling.\n");
        ActiveInterruptManager = 0;
        asm("cli");
    }
}

InterruptManager::~InterruptManager()
{
}


uint32_t InterruptManager::HandleInterrupt(uint8_t interruptNumber, uint32_t esp)
{
    if (ActiveInterruptManager != 0) {
        return ActiveInterruptManager->DoHandleInterrupt(interruptNumber, esp);
    }
    return esp;
}

uint32_t InterruptManager::DoHandleInterrupt(uint8_t interruptNumber, uint32_t esp)
{
    if (handlers[interruptNumber] != 0) {
        esp = handlers[interruptNumber]->HandleInterrupt(esp);
    }
    else if (interruptNumber != 0x20) {
        printf(" UNHANDLED INTERRUPT 0x%x", interruptNumber);
    }

    if (0x20 <= interruptNumber && interruptNumber <= 0x30) {
        // Send answer to hardware interrupts
        picMasterCommand.Write(0x20);
        if (0x28 <= interruptNumber) {
            picSlaveCommand.Write(0x20);
        }
    }

    return esp;
}