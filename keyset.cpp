#include "keyset.h"

void printf(char*);

KeySet::KeySet(uint8_t keySetCode)
{
    this->flags = 0;
}

KeySet::~KeySet()
{
}

void KeySet::shiftOn() { this->flags |= 1; }
void KeySet::shiftOff() { this->flags &= ~1; }
uint8_t KeySet::isShift() { return this-> flags & 1; }

void KeySet::altOn() { this->flags |= 1 << 1; }
void KeySet::altOff() { this->flags &= ~(1 << 1); }
uint8_t KeySet::isAlt() { return this-> flags & 2; }

void KeySet::metaOn() { this->flags |= 1 << 2; }
void KeySet::metaOff() { this->flags &= ~(1 << 2); }
uint8_t KeySet::isMeta() { return this-> flags & 4; }

void KeySet::ctrlOn() { this->flags |= 1 << 3; }
void KeySet::ctrlOff() { this->flags &= ~(1 << 3); }
uint8_t KeySet::isCtrl() { return this-> flags & 8; }

void KeySet::OnKeyDown(uint8_t keyCode)
{
    switch (keyCode) {
        // Menu Key
        case 0x5D: break;

        // Modifier keys
        case 0x2A: case 0x36: shiftOn(); break;
        case 0x38: altOn(); break;
        case 0x5B: metaOn(); break;
        case 0x1D: ctrlOn(); break;

        // Numbers
        case 0x02: isShift() ? printf("!") : printf("1"); break;
        case 0x03: isShift() ? printf("@") : printf("2"); break;
        case 0x04: isShift() ? printf("#") : printf("3"); break;
        case 0x05: isShift() ? printf("$") : printf("4"); break;
        case 0x06: isShift() ? printf("%") : printf("5"); break;
        case 0x07: isShift() ? printf("^") : printf("6"); break;
        case 0x08: isShift() ? printf("&") : printf("7"); break;
        case 0x09: isShift() ? printf("*") : printf("8"); break;
        case 0x0A: isShift() ? printf("(") : printf("9"); break;
        case 0x0B: isShift() ? printf(")") : printf("0"); break;

        // Punctuation
        case 0x29: isShift() ? printf("~") : printf("`"); break;
        case 0x0C: isShift() ? printf("_") : printf("-"); break;
        case 0x0D: isShift() ? printf("+") : printf("="); break;
        case 0x1A: isShift() ? printf("{") : printf("["); break;
        case 0x1B: isShift() ? printf("}") : printf("]"); break;
        case 0x2B: isShift() ? printf("|") : printf("\\"); break;
        case 0x27: isShift() ? printf(":") : printf(";"); break;
        case 0x28: isShift() ? printf("\"") : printf("'"); break;
        case 0x33: isShift() ? printf("<") : printf(","); break;
        case 0x34: isShift() ? printf(">") : printf("."); break;
        case 0x35: isShift() ? printf("?") : printf("/"); break;

        // Function Keys
        case 0x3B: case 0x3C: case 0x3D: case 0x3E: case 0x3F: case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x57: case 0x58: break;

        // Escape
        case 0x01: break;

        // Enter key
        case 0x1C: printf("\n"); break;

        // Letters
        case 0x10: isCtrl() ? printf("^Q") : isShift() ? printf("Q") : printf("q"); break;
        case 0x11: isCtrl() ? printf("^W") : isShift() ? printf("W") : printf("w"); break;
        case 0x12: isCtrl() ? printf("^E") : isShift() ? printf("E") : printf("e"); break;
        case 0x13: isCtrl() ? printf("^R") : isShift() ? printf("R") : printf("r"); break;
        case 0x14: isCtrl() ? printf("^T") : isShift() ? printf("T") : printf("t"); break;
        case 0x15: isCtrl() ? printf("^Y") : isShift() ? printf("Y") : printf("y"); break;
        case 0x16: isCtrl() ? printf("^U") : isShift() ? printf("U") : printf("u"); break;
        case 0x17: isCtrl() ? printf("^I") : isShift() ? printf("I") : printf("i"); break;
        case 0x18: isCtrl() ? printf("^O") : isShift() ? printf("O") : printf("o"); break;
        case 0x19: isCtrl() ? printf("^P") : isShift() ? printf("P") : printf("p"); break;
        case 0x1E: isCtrl() ? printf("^A") : isShift() ? printf("A") : printf("a"); break;
        case 0x1F: isCtrl() ? printf("^S") : isShift() ? printf("S") : printf("s"); break;
        case 0x20: isCtrl() ? printf("^D") : isShift() ? printf("D") : printf("d"); break;
        case 0x21: isCtrl() ? printf("^F") : isShift() ? printf("F") : printf("f"); break;
        case 0x22: isCtrl() ? printf("^G") : isShift() ? printf("G") : printf("g"); break;
        case 0x23: isCtrl() ? printf("^H") : isShift() ? printf("H") : printf("h"); break;
        case 0x24: isCtrl() ? printf("^J") : isShift() ? printf("J") : printf("j"); break;
        case 0x25: isCtrl() ? printf("^K") : isShift() ? printf("K") : printf("k"); break;
        case 0x26: isCtrl() ? printf("^L") : isShift() ? printf("L") : printf("l"); break;
        case 0x2C: isCtrl() ? printf("^Z") : isShift() ? printf("Z") : printf("z"); break;
        case 0x2D: isCtrl() ? printf("^X") : isShift() ? printf("X") : printf("x"); break;
        case 0x2E: isCtrl() ? printf("^C") : isShift() ? printf("C") : printf("c"); break;
        case 0x2F: isCtrl() ? printf("^V") : isShift() ? printf("V") : printf("v"); break;
        case 0x30: isCtrl() ? printf("^B") : isShift() ? printf("B") : printf("b"); break;
        case 0x31: isCtrl() ? printf("^N") : isShift() ? printf("N") : printf("n"); break;
        case 0x32: isCtrl() ? printf("^M") : isShift() ? printf("M") : printf("m"); break;

        // Spacebar
        case 0x39: printf(" "); break;

        default:
            char* foo = "DOWN 0x00 (    ) ";
            char* hex = "0123456789ABCDEF";
            foo[7] = hex[(keyCode >> 4) & 0x0F];
            foo[8] = hex[keyCode & 0x0F];
            foo[11] = isShift() ? 'S' : ' ';
            foo[12] = isAlt() ? 'A' : ' ';
            foo[13] = isMeta() ? 'M' : ' ';
            foo[14] = isCtrl() ? 'C' : ' ';
            printf(foo);
            break;
    }
}

void KeySet::OnKeyUp(uint8_t keyCode)
{
    switch (keyCode - 0x80) {
        // Modifier keys
        case 0x2A: case 0x36: shiftOff(); break;
        case 0x38: altOff(); break;
        case 0x5B: metaOff(); break;
        case 0x1D: ctrlOff(); break;
        
        default:
            break;
    }
}