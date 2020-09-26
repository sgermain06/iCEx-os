#include "screen.h"

char tbuf[32];
char bchars[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

void itoa(uint32_t i, uint32_t base, char* buf) {
   int32_t pos = 0;
   int32_t opos = 0;
   int32_t top = 0;

   if (i == 0 || base > 16) {
      buf[0] = '0';
      buf[1] = '\0';
      return;
   }

   while (i != 0) {
      tbuf[pos] = bchars[i % base];
      pos++;
      i /= base;
   }
   top = pos--;
   for (opos = 0; opos < top; pos--, opos++) {
      buf[opos] = tbuf[pos];
   }
   buf[opos] = 0;
}

void itoa_s(uint32_t i, uint32_t base, char* buf) {
   if (base > 16) return;
   if (i < 0) {
      *buf++ = '-';
      i *= -1;
   }
   itoa(i, base, buf);
}

Screen::Screen()
{
    this->videoMemory = (uint16_t*)0xb8000;
    clear();
    render();
}

Screen::~Screen()
{

}

void Screen::render()
{
    for (uint8_t row = 0; row < 25; row++) {
        for (uint8_t col = 0; col < 80; col++) {
            this->videoMemory[row * 80 + col] = (this->videoMemory[row * 80 + col] & 0xFF00) | this->charMap[row][col];
        }
    }
}

void Screen::clear()
{
    for (uint8_t row = 0; row < 25; row++) {
        for (uint8_t col = 0; col < 80; col++) {
            this->charMap[row][col] = ' ';
        }
    }
    this->x = 0;
    this->y = 0;
}

void Screen::displayChar(char chr)
{
    switch (chr) {
        case 0:
            return;
        case '\n':
        case '\r':
            this->x = 0;
            this->y++;
            break;
        default:
            // Display the character
            this->videoMemory[this->y * 80 + this->x] = (this->videoMemory[this->y * 80 + this->x] & 0xFF00) | chr;
            // Also store it so we can scroll
            this->charMap[this->y][this->x] = chr;
            this->x++;
            break;
    }

    if (this->x >= 80) {
        this->x = 0;
        this->y++;
    }

    if (this->y >= 25) {
        // Loop through all rows - 1
        for (uint8_t row = 0; row < 24; row++) {
            for (uint8_t col = 0; col < 80; col++) {
                this->charMap[row][col] = this->charMap[row+1][col];
            }
        }

        for (uint8_t col = 0; col < 80; col++) {
            this->charMap[24][col] = ' ';
        }
        this->y = 24;
        render();
    }
}

void Screen::displayString(char* str)
{
    if (!str) {
        return;
    }

    for (uint32_t i = 0; str[i] != '\0'; i++) {
        displayChar(str[i]);
    }
}

int Screen::printf(const char* str, ...)
{
    va_list args;
    va_start(args, str);
    vprintf(str, args);
    va_end(args);
}

int Screen::vprintf(const char* str, va_list args)
{
    if (!str) {
        return 0;
    }

    for (uint32_t i = 0; str[i] != '\0'; i++) {

        switch(str[i]) {

            case '%':
                switch(str[i+1]) {

					/*** characters ***/
                    case 'c': {
                        char c = va_arg (args, char);
                        displayChar(c);
                        i++;
                        break;
                    }

                    case 's': {
                        char* c = va_arg(args, char*);
                        displayString(c);
                        i++;
                        break;
                    }

					/*** address of ***/
					case 'p': {
						int32_t c = (int32_t&) va_arg(args, char);
						char str[32]={0};
						itoa_s (c, 16, str);
						displayString(str);
						i++;		// go to next character
						break;
					}

					/*** integers ***/
					case 'd':
					case 'i': {
						int32_t c = va_arg(args, int32_t);
						char str[32] = {0};
						itoa_s(c, 10, str);
						displayString(str);
						i++;		// go to next character
						break;
					}

					/*** display in hex ***/
					case 'X':
					case 'x': {
						int32_t c = va_arg(args, int32_t);
						char str[32] = {0};
						itoa_s(c, 16, str);
						displayString(str);
						i++;		// go to next character
						break;
					}

					default:
						va_end(args);
						return 1;
				}
                break;

            default:
                displayChar(str[i]);
                break;
        }
    }

    return 1;
}