#ifndef __SCREEN_H
#define __SCREEN_H

#include "types.h"

/* va list parameter list */
typedef uint8_t* va_list;
/* width of stack == width of int */
#define	STACKITEM int32_t
 
/* round up width of objects pushed on stack. The expression before the
& ensures that we get 0 for objects of size 0. */
#define	VA_SIZE(TYPE) ((sizeof(TYPE) + sizeof(STACKITEM) - 1) & ~(sizeof(STACKITEM) - 1))

/* &(LASTARG) points to the LEFTMOST argument of the function call
(before the ...) */
#define	va_start(AP, LASTARG) (AP=((va_list)&(LASTARG) + VA_SIZE(LASTARG)))

/* nothing for va_end */
#define va_end(AP)

#define va_arg(AP, TYPE) (AP += VA_SIZE(TYPE), *((TYPE *)(AP - VA_SIZE(TYPE))))

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