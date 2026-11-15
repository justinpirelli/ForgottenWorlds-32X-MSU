ld

/* =========================================================================
   Linker Script for Sega 32X + Sega CD Mode 1 Hybrid Cartridge
   ========================================================================= */
OUTPUT_FORMAT("elf32-m68k")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4M
    RAM (rwx) : ORIGIN = 0x00FF0000, LENGTH = 64K
}

SECTIONS
{
    /* 68000 Boot Header & Code */
    .text 0x00000000 :
    {
        KEEP(*(.boot))
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > ROM

    /* Embedded SH-2 Binary Blob (Copied to 32X SDRAM 0x06000000 by BIOS) */
    .sh2_code : ALIGN(16)
    {
        _sh2_blob_start = .;
        KEEP(*(.sh2_binary))
        . = ALIGN(16);
        _sh2_blob_end = .;
    } > ROM

    _sh2_blob_size = _sh2_blob_end - _sh2_blob_start;

    /* Initialized 68000 Data */
    .data : ALIGN(4)
    {
        _data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    /* Uninitialized 68000 BSS */
    .bss (NOLOAD) : ALIGN(4)
    {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM
}
