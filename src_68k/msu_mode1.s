asm

| ============================================================================
| Sega CD Mode 1 (MSU-MD Compatible) Main-CPU Driver for 32X Cartridges
| ============================================================================
        .section .text
        .align 2

        .global msu_init
        .global msu_play_track
        .global msu_stop

| Sega CD Gate Array Registers (Main 68000 Bus @ $A12000)
.equ SCD_RESET,      0xA12001    | Sub-CPU Reset / Bus Request
.equ SCD_MEM_MODE,   0xA12003    | PRG-RAM Bank & Write Protect Control
.equ SCD_COMM_FLAG,  0xA1200E    | Main-CPU -> Sub-CPU Handshake Flag
.equ SCD_COMM_CMD,   0xA12010    | Command Word (Track # & Loop Flag)
.equ SCD_COMM_STAT,  0xA12020    | Sub-CPU Status Return
.equ SCD_PRG_RAM,    0x420000    | Sub-CPU PRG-RAM Window (Bank 0)

| ----------------------------------------------------------------------------
| int msu_init(void)
| Detects Sega CD, loads Sub-CPU Mode 1 payload to PRG-RAM, and boots BIOS
| ----------------------------------------------------------------------------
msu_init:
        movem.l d1-d2/a0-a1, -(sp)

        | 1. Check for Sega CD BIOS signature at $415800 ("SEGA")
        lea     0x415800, a0
        cmp.l   #0x53454741, (a0)
        bne.s   .no_scd

        | 2. Halt Sub-CPU & Request PRG-RAM Bus Access
        move.b  #0x02, SCD_RESET        | Assert BusReq + Reset Sub-CPU
.wait_bus:
        btst    #1, SCD_RESET
        beq.s   .wait_bus

        | Disable PRG-RAM write-protect & select Bank 0
        move.b  #0x00, SCD_MEM_MODE

        | 3. Copy compiled Sub-CPU payload into Sega CD PRG-RAM ($420000)
        lea     sub_cpu_payload(pc), a0
        lea     SCD_PRG_RAM, a1
        move.w  #((sub_cpu_payload_end - sub_cpu_payload) / 2) - 1, d1
.copy_loop:
        move.w  (a0)+, (a1)+
        dbra    d1, .copy_loop

        | 4. Release BusReq & Run Sub-CPU
        move.b  #0x01, SCD_RESET

        | 5. Wait for Sub-CPU SP_INIT to signal ready ($0001 in COMM_STAT)
        move.l  #0x000FFFFF, d1
.wait_bios:
        cmp.w   #0x0001, SCD_COMM_STAT
        beq.s   .scd_ready
        subq.l  #1, d1
        bne.s   .wait_bios
        bra.s   .no_scd

.scd_ready:
        moveq   #1, d0
        movem.l (sp)+, d1-d2/a0-a1
        rts

.no_scd:
        moveq   #0, d0
        movem.l (sp)+, d1-d2/a0-a1
        rts

| ----------------------------------------------------------------------------
| void msu_play_track(uint8_t track_num, uint8_t loop)
| ----------------------------------------------------------------------------
msu_play_track:
        move.b  7(sp), d0               | track_num
        move.b  11(sp), d1              | loop (1 = loop, 0 = once)
        lsl.w   #8, d1
        or.b    d0, d1

        move.w  d1, SCD_COMM_CMD
        bset    #0, SCD_COMM_FLAG       | Signal Sub-CPU

.wait_ack:
        cmp.w   SCD_COMM_STAT, d1       | Wait for Sub-CPU to echo command
        bne.s   .wait_ack

        bclr    #0, SCD_COMM_FLAG       | Clear flag to complete handshake
        rts

| ----------------------------------------------------------------------------
| void msu_stop(void)
| ----------------------------------------------------------------------------
msu_stop:
        move.w  #0x0000, SCD_COMM_CMD
        bset    #0, SCD_COMM_FLAG

.wait_stop_ack:
        tst.w   SCD_COMM_STAT
        bne.s   .wait_stop_ack

        bclr    #0, SCD_COMM_FLAG
        rts

| ----------------------------------------------------------------------------
| Embedded Sub-CPU Binary Payload (Built from src_scd/sub_cpu.s)
| ----------------------------------------------------------------------------
        .align 2
sub_cpu_payload:
        .incbin "build/sub_cpu.bin"
sub_cpu_payload_end:
