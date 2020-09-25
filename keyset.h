#ifndef __KEYSET_H
#define __KEYSET_H

#include "types.h"

class KeySet {
protected:
    uint8_t flags;
    /*
        0000
        |||- Shift
        ||-- Alt
        |--- Meta (Windows)
        ---- Ctrl
    */
   void shiftOn();
   void shiftOff();
   uint8_t isShift();

   void ctrlOn();
   void ctrlOff();
   uint8_t isCtrl();

   void metaOn();
   void metaOff();
   uint8_t isMeta();

   void altOn();
   void altOff();
   uint8_t isAlt();

public:
    KeySet(uint8_t keySetCode);
    ~KeySet();

    void OnKeyDown(uint8_t);
    void OnKeyUp(uint8_t);
};

#endif