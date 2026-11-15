| ============================================================================
| Sega 32X Cartridge Header, TMSS Security Unlock & SH-2 Entry Vectors
| ============================================================================
        .section .boot
        .align 2

        .global _start
        .extern main
        .extern master_sh2_main
        .extern slave_sh2_main

| ----------------------------------------------------------------------------
| 0x000000 - 0x0000FF: Motorola 68000 Exception & Interrupt Vector Table
| ----------------------------------------------------------------------------
vectors:
        .long   0x00FFFFFE              | 00: Initial Stack Pointer (Top of Work RAM)
        .long   _start                  | 01: Reset / Entry Point
        .long   ignore_int              | 02: Bus Error
        .long   ignore_int              | 03: Address Error
        .long   ignore_int              | 04: Illegal Instruction
        .long   ignore_int              | 05: Zero Divide
        .long   ignore_int              | 06: CHK Instruction
        .long   ignore_int              | 07: TRAPV Instruction
        .long   ignore_int              | 08: Privilege Violation
        .long   ignore_int              | 09: Trace
        .long   ignore_int              | 10: Line 1010 Emulator
        .long   ignore_int              | 11: Line 1111 Emulator
        .rept   16
        .long   ignore_int              | 12-27: Reserved / Unassigned
        .endr
        .long   ignore_int              | 28: Level 4 Interrupt (H-Blank)
        .long   ignore_int              | 29: Level 5 Interrupt
        .long   vblank_int              | 30: Level 6 Interrupt (V-Blank)
        .long   ignore_int              | 31: Level 7 Interrupt (NMI)
        .rept   32
        .long   ignore_int              | 32-63: TRAP & User Vectors
        .endr

| ----------------------------------------------------------------------------
| 0x000100 - 0x0001FF: Standard Sega Genesis / 32X ROM Header
| ----------------------------------------------------------------------------
        .ascii  "SEGA 32X        "      | 0x100: Console Name (16 bytes)
        .ascii  "(C)CAPCOM 1988"      | 0x110: Copyright & Date (16 bytes)
        .ascii  "FORGOTTEN WORLDS - CPS1 EDITION   " | 0x120: Domestic Name (48 bytes)
        .ascii  "FORGOTTEN WORLDS - CPS1 EDITION   " | 0x150: Overseas Name (48 bytes)
        .ascii  "GM MK-84500-00"        | 0x180: Product Type & Serial (14 bytes)
        .word   0x0000                  | 0x18E: Checksum (Patched by build script)
        .ascii  "J6              "      | 0x190: I/O Support ("J" = 3-btn, "6" = 6-btn)
        .long   0x00000000              | 0x1A0: ROM Start Address
        .long   0x003FFFFF              | 0x1A4: ROM End Address (4MB Cartridge)
        .long   0x00FF0000              | 0x1A8: RAM Start Address
        .long   0x00FFFFFF              | 0x1AC: RAM End Address
        .ascii  "            "          | 0x1B0: SRAM Info (12 bytes)
        .ascii  "            "          | 0x1BC: Modem Info (12 bytes)
        .ascii  "CPS-1 ARCADE PORT WITH SEGA CD MODE 1 AUDIO     " | 0x1C8: Memo (40 bytes)
        .ascii  "JUE             "      | 0x1F0: Region Codes (16 bytes)

| ----------------------------------------------------------------------------
| 0x000200 - 0x0003BF: Padding to reach 32X Security Block at 0x3C0
| ----------------------------------------------------------------------------
        .org    0x0003C0

| ----------------------------------------------------------------------------
| 0x0003C0 - 0x0003FF: 32X MARS Security & SH-2 Boot Table
| ----------------------------------------------------------------------------
mars_header:
        .ascii  "MARS CHECK MODE "      | 0x3C0: Required 32X ID String (16 bytes)
        .long   0x00000000              | 0x3D0: Reserved
        .long   _sh2_blob_start         | 0x3D4: SH-2 Code Source Offset in ROM
        .long   _sh2_blob_size          | 0x3D8: SH-2 Code Size in Bytes
        .long   0x06000000              | 0x3DC: Master SH-2 SDRAM Load Address
        .long   0x06000000              | 0x3E0: Slave SH-2 SDRAM Load Address
        .long   master_sh2_entry        | 0x3E4: Master SH-2 Initial PC
        .long   slave_sh2_entry         | 0x3E8: Slave SH-2 Initial PC
        .long   0x0603F800              | 0x3EC: Master SH-2 Stack Pointer
        .long   0x0603FC00              | 0x3F0: Slave SH-2 Stack Pointer
        .long   0x00000000              | 0x3F4: Reserved
        .long   0x00000000              | 0x3F8: Reserved
        .long   0x00000000              | 0x3FC: Reserved

| ----------------------------------------------------------------------------
| 0x000400: 68000 Entry Point (_start) - TMSS Unlock & Jump to C main()
| ----------------------------------------------------------------------------
        .org    0x000400
_start:
        move.w  #0x2700, %sr            | Disable interrupts during init

        | Check Genesis Hardware Version & Write 'SEGA' to TMSS ($A14000)
        move.b  (0xA10001).l, %d0
        andi.b  #0x0F, %d0
        beq.s   .skip_tmss
        move.l  #0x53454741, (0xA14000).l   | 'SEGA'
.skip_tmss:
        | Clear 68000 Work RAM ($FF0000 - $FFFF00)
        lea     (0xFF0000).l, %a0
        move.w  #0x3FBF, %d0
.clear_ram:
        clr.l   (%a0)+
        dbra    %d0, .clear_ram

        | Jump to C Entry Point (src_68k/main_68k.c)
        jsr     main
.halt:
        bra.s   .halt

vblank_int:
        rte

ignore_int:
        rte
