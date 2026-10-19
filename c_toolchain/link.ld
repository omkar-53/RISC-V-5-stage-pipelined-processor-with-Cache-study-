OUTPUT_ARCH(riscv)
ENTRY(_start)

STACK_SIZE = 512;

MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 1K
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 2K
}

SECTIONS {
    .text : {
        KEEP(*(.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > ROM

    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
    } > RAM AT> ROM

    /* Fixed base makes the simulation testbench able to check C results. */
    .bss 0x100 (NOLOAD) : {
        __bss_start = .;
        KEEP(*(.results))
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_bottom = ORIGIN(RAM) + LENGTH(RAM) - STACK_SIZE;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}

ASSERT(SIZEOF(.text) <= LENGTH(ROM), "program exceeds the 1 KB instruction ROM")
ASSERT(ADDR(.data) + SIZEOF(.data) <= 0x100, "initialized data overlaps the fixed .bss/results region")
ASSERT(__bss_end <= __stack_bottom, "data and bss leave less than 512 bytes for stack")
