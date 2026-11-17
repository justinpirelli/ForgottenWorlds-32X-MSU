| ============================================================================
| Sega 32X Cartridge Header, TMSS Security Unlock, Bridge Table & V-Blank
| ============================================================================
        .section .boot
        .align 2

        .global _start
        .extern main
        .extern cps1_vblank_handler
        .extern cps1_bridge_read_p1
        .extern cps1_bridge_read_p2
        .extern cps1_bridge_read_dial1
        .extern cps1_bridge_read_dial2
        .extern cps1_bridge_sound_latch
        .extern _sh2_blob_start
        .extern _sh2_blob_size
        .extern _data_load_start
        .extern _data_start
        .extern _data_size

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
| 0x000100 - 0x0001FF: Exact 256-Byte Sega Genesis / 32X ROM Header
| ----------------------------------------------------------------------------
        .ascii  "SEGA 32X        "      | 0x100: Console Name (16 bytes)
        .ascii  "(C)CAPCOM 1988  "      | 0x110: Copyright & Date (16 bytes)
        .ascii  "FORGOTTEN WORLDS - CPS1 EDITION                 " | 0x120: Domestic Name (48 bytes)
        .ascii  "FORGOTTEN WORLDS - CPS1 EDITION                 " | 0x150: Overseas Name (48 bytes)
        .ascii  "GM MK-84500-00"        | 0x180: Product Type & Serial (14 bytes)
        .word   0x0000                  | 0x18E: Checksum (Patched by Makefile)
        .ascii  "J6              "      | 0x190: I/O Support (16 bytes)
        .long   0x00000000              | 0x1A0: ROM Start Address
        .long   0x003FFFFF              | 0x1A4: ROM End Address (4MB Cartridge)
        .long   0x00FF0000              | 0x1A8: RAM Start Address
        .long   0x00FFFFFF              | 0x1AC: RAM End Address
        .ascii  "            "          | 0x1B0: SRAM Info (12 bytes)
        .ascii  "            "          | 0x1BC: Modem Info (12 bytes)
        .ascii  "CPS-1 ARCADE PORT WITH SEGA CD MODE 1   "         | 0x1C8: Memo (40 bytes)
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
        .long   0x06000000              | 0x3E4: Master SH-2 Initial PC
        .long   0x06000008              | 0x3E8: Slave SH-2 Initial PC
        .long   0x0603F800              | 0x3EC: Master SH-2 Stack Pointer
        .long   0x0603FC00              | 0x3F0: Slave SH-2 Stack Pointer
        .long   0x00000000              | 0x3F4: Reserved
        .long   0x00000000              | 0x3F8: Reserved
        .long   0x00000000              | 0x3FC: Reserved

| ----------------------------------------------------------------------------
| 0x000800 - 0x00081F: Fixed CPS-1 Bridge Jump Table (Called by Patched ROM)
| ----------------------------------------------------------------------------
        .org    0x000800
bridge_jump_table:
        jmp     (cps1_bridge_read_p1).l     | 0x0800 (6 bytes)
        jmp     (cps1_bridge_read_p2).l     | 0x0806 (6 bytes)
        jmp     (cps1_bridge_read_dial1).l  | 0x080C (6 bytes)
        jmp     (cps1_bridge_read_dial2).l  | 0x0812 (6 bytes)
        jmp     (cps1_bridge_sound_latch).l | 0x0818 (6 bytes)

| ----------------------------------------------------------------------------
| 0x000820: 68000 Entry Point (_start) - TMSS Unlock & Jump to C main()
| ----------------------------------------------------------------------------
        .org    0x000820
_start:
        move.w  #0x2700, %sr            | Disable interrupts during init

        | Check Genesis Hardware Version & Write 'SEGA' to TMSS ($A14000)
        move.b  (0x00A10001).l, %d0
        andi.b  #0x0F, %d0
        beq.s   .skip_tmss
        move.l  #0x53454741, (0x00A10000).l
.skip_tmss:
        | Clear 68000 Work RAM ($FF0000 - $FFFEFF)
        lea     (0x00FF0000).l, %a0
        move.w  #0x3FBF, %d0
.clear_ram:
        clr.l   (%a0)+
        dbra    %d0, .clear_ram

        | Copy Initialized .data Section from ROM to RAM ($FFC000+)
        move.l  #_data_size, %d0
        beq.s   .skip_data
        lsr.l   #1, %d0
        subq.w  #1, %d0
        lea     (_data_load_start).l, %a0
        lea     (_data_start).l, %a1
.copy_data:
        move.w  (%a0)+, (%a1)+
        dbra    %d0, .copy_data
.skip_data:
        | Jump to C Entry Point (src_68k/main_68k.c)
        jsr     main
.halt:
        bra.s   .halt

| ----------------------------------------------------------------------------
| Level 6 V-Blank Interrupt Handler (60Hz Frame Sync & CPS-1 Arcade Tick)
| ----------------------------------------------------------------------------
vblank_int:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        jsr     cps1_vblank_handler
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rte

ignore_int:
        rte
