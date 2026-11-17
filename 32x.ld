/* =========================================================================
   Linker Script for Sega 32X + Sega CD Mode 1 Hybrid Cartridge
   ========================================================================= */
OUTPUT_FORMAT("elf32-m68k")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4M
    /* Top 16KB of 68k Work RAM reserved for Genesis/32X driver (.data/.bss/stack).
       Lower 48KB ($FF0000-$FFBFFF) is reserved for CPS-1 Work RAM & Staged VRAM. */
    RAM (rwx) : ORIGIN = 0x00FFC000, LENGTH = 16K
}

SECTIONS
{
    /* 0x000000 - 0x01FFFF: 68000 Boot Header, Bridge Table, Driver Code & SH-2 Blob */
    .text 0x00000000 :
    {
        KEEP(*(.boot))
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(16);
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

    /* Initialized 68000 Driver Data */
    .data : ALIGN(4)
    {
        _data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    _data_load_start = LOADADDR(.data);
    _data_size       = _data_end - _data_start;

    /* Uninitialized 68000 Driver BSS ($FFC000+) */
    .bss (NOLOAD) : ALIGN(4)
    {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* 0x020000 (128KB Mark): Patched CPS-1 68000 Arcade Program ROM */
    .cps1_prog 0x00020000 : ALIGN(16)
    {
        KEEP(*(.cps1_prog_rom))
    } > ROM

    /* 0x200000 (2MB Mark -> SH-2 0x22200000): Linear 8-bit CPS-1 Tile/Sprite GFX */
    .cps1_gfx 0x00200000 : ALIGN(16)
    {
        KEEP(*(.cps1_gfx_rom))
    } > ROM

    /* 0x300000 (3MB Mark -> SH-2 0x22300000): 1.5KB SFX Table + 8-bit PCM Bank */
    .cps1_sfx 0x00300000 : ALIGN(16)
    {
        KEEP(*(.cps1_sfx_rom))
    } > ROM
}
