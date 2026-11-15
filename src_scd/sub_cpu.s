| ============================================================================
| Sega CD Sub-CPU Mode 1 CD-DA Audio Payload (Runs in PRG-RAM @ $000000)
| ============================================================================
        .section .text
        .align 2

| Sega CD Sub-CPU Gate Array Registers
.equ SUB_LED,        0xFF8000    | Green/Red Access LEDs
.equ SUB_RESET,      0xFF8001    | Peripheral Reset (CD Drive)
.equ SUB_MEM_MODE,   0xFF8003    | Word RAM Mode
.equ SUB_COMM_FLAG,  0xFF800E    | Handshake Flags (High byte = Main, Low = Sub)
.equ SUB_COMM_CMD,   0xFF8010    | Command Word from Main 68000
.equ SUB_COMM_STAT,  0xFF8020    | Status Word to Main 68000

| Sega CD BIOS Entry Point
.equ _CDBIOS,        0x005F22
.equ BIOS_DRVINIT,   0x0002
.equ BIOS_MSCPLAY,   0x0011
.equ BIOS_MSCPLAYR,  0x0012
.equ BIOS_MSCSTOP,   0x0014

| ----------------------------------------------------------------------------
| Standard Sega CD Sub-CPU Program Header (Required by Sega CD Boot ROM)
| ----------------------------------------------------------------------------
sub_header:
        .ascii  "MAIN       "           | 11-byte module name ("MAIN" + 7 spaces)
        .byte   0x00                    | Flag
        .word   0x0100                  | Version
        .word   0x0000                  | Type
        .long   0x00000000              | Next module pointer
        .long   (sub_end - sub_header)  | Module size
        .long   (sp_init - sub_header)  | Offset to SP_INIT
        .long   0x00000000              | Work RAM size

| Jump Table expected by BIOS
sp_init:
        bra.w   init_sub_cpu
sp_main:
        bra.w   main_sub_loop
sp_int2:
        rte                             | Level 2 Interrupt (Main-CPU IRQ) unused
sp_user:
        rte

| ----------------------------------------------------------------------------
| SP_INIT: Initialize CD Drive & Read Disc TOC
| ----------------------------------------------------------------------------
init_sub_cpu:
        move.b  #0x01, SUB_RESET        | Release CD drive reset
        lea     drv_init_params(pc), a0
        move.w  #BIOS_DRVINIT, d0
        jsr     _CDBIOS

        | Signal Main 68000 (Genesis/32X) that Sega CD Mode 1 is ready
        move.w  #0x0001, SUB_COMM_STAT
        rts

drv_init_params:
        .byte   0x01                    | Start at Track 1
        .byte   0xFF                    | Read all tracks in TOC

| ----------------------------------------------------------------------------
| SP_MAIN: Infinite Mailbox Polling Loop for Track Playback Commands
| ----------------------------------------------------------------------------
main_sub_loop:
        | Wait for Main 68000 to set Bit 0 of Main Comm Flag ($FF800E)
        btst    #0, SUB_COMM_FLAG
        beq.s   main_sub_loop

        | Read packed command: High byte = Loop (1/0), Low byte = Track #
        move.w  SUB_COMM_CMD, d1
        tst.w   d1
        beq.s   .cmd_stop               | 0x0000 = Stop CD Audio

        | Store Track # in local variable for _CDBIOS pointer (a0)
        moveq   #0, d2
        move.b  d1, d2
        lea     track_arg(pc), a0
        move.w  d2, (a0)

        | Check Loop flag in bit 8 (High byte)
        btst    #8, d1
        bne.s   .cmd_play_loop

.cmd_play_once:
        move.w  #BIOS_MSCPLAY, d0
        jsr     _CDBIOS
        bra.s   .ack_command

.cmd_play_loop:
        move.w  #BIOS_MSCPLAYR, d0
        jsr     _CDBIOS
        bra.s   .ack_command

.cmd_stop:
        move.w  #BIOS_MSCSTOP, d0
        jsr     _CDBIOS

.ack_command:
        | Acknowledge command by mirroring status & waiting for Main to clear flag
        move.w  d1, SUB_COMM_STAT
.wait_main_clear:
        btst    #0, SUB_COMM_FLAG
        bne.s   .wait_main_clear

        move.w  #0x0001, SUB_COMM_STAT  | Return to Ready status
        bra.s   main_sub_loop

        .align 2
track_arg:
        .word   0x0002

sub_end:
