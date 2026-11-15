asm

! ============================================================================
! Hitachi SH-2 Vector Table & C Entry Trampolines (Loaded at 0x06000000)
! ============================================================================
        .section .text
        .align 2

        .global master_sh2_entry
        .global slave_sh2_entry
        .extern _master_sh2_main
        .extern _slave_sh2_main

master_sh2_entry:
        mov.l   master_main_addr, r0
        jmp     @r0
        nop

slave_sh2_entry:
        mov.l   slave_main_addr, r0
        jmp     @r0
        nop

        .align 2
master_main_addr:
        .long   _master_sh2_main
slave_main_addr:
        .long   _slave_sh2_main
