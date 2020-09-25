ENTRY(loader)                                                   /* Name of the entry point */
OUTPUT_FORMAT(elf32-i386)                                       /* Output format */
OUTPUT_ARCH(i386:i386)                                          /* Output architecture */

SECTIONS
{
    . = 0x0100000;                                              /* The code should be loaded at 1MB */

    .text :                                                     /* All text sections from all files */
    {
        *(.multiboot)
        *(.text*)
        *(.rodata)
    }

    .data :                                                     /* All data sections from all files */
    {
        start_ctors = .;
        KEEP(*( .init_array ));
        KEEP(*(SORT_BY_INIT_PRIORITY( .init_array.* )));
        end_ctors = .;

        *(.data)
    }

    .bss :                                                      /* All bss sections from all files */
    {
        *(.bss)
    }

    /DISCARD/ :
    {
        *(.fini_array*)
        *(.comment)
    }
}