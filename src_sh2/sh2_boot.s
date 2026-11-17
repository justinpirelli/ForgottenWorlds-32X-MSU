! ============================================================================
! Hitachi SH-2 Entry Trampolines (Loaded at 0x06000000)
! ============================================================================
        .section .text
        .align 2

        .global master_sh2_entry
        .global slave_sh2_entry
        .extern master_sh2_main
        .extern slave_sh2_main

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
        .long   master_sh2_main
slave_main_addr:
        .long   slave_sh2_main