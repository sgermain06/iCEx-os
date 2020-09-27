#ifndef __SCREEN_H
#define __SCREEN_H

#include <common/types.h>

class Screen {
protected:
    uint8_t x, y;
    uint8_t charMap[25][80];

    int8_t mouseX, mouseY;
    bool mouseInitialized;

    uint16_t* videoMemory;

    void render();
    void displayChar(char chr);
    void displayString(char* str);
    void renderMouse(int8_t x, int8_t y);
public:
    Screen();
    ~Screen();

    void clear();
    int printf(const char* str, ...);
    int vprintf(const char* str, va_list args);
    void displayHeader(char* str);
    void displayFooter(char* str, ...);

    void moveMouse(int8_t x, int8_t y);

    void printMouseCoordinates();
};

#endif