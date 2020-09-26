#ifndef __SCREEN_H
#define __SCREEN_H

#include "types.h"

class Screen {
protected:
    uint8_t x, y;
    uint8_t charMap[25][80];

    uint16_t* videoMemory;

    void render();
    void displayChar(char chr);
    void displayString(char* str);
public:
    Screen();
    ~Screen();

    void clear();
    int printf(const char* str, ...);
    int vprintf(const char* str, va_list args);
};

#endif