asm

| ============================================================================
| Sega CD Mode 1 (MSU-MD Compatible) Audio Driver for 32X Cartridges
| ============================================================================
        .section .text
        .align 2

        .global msu_init
        .global msu_play_track
        .global msu_stop

| Sega CD Gate Array Registers (Mapped at $A12000 when booted from Cart)
.equ SCD_RESET,      0xA12001    | Sub-CPU Reset / Bus Request
.equ SCD_MEM_MODE,   0xA12003    | Word RAM / PRG-RAM Bank Control
.equ SCD_COMM_FLAG,  0xA1200E    | Main-CPU -> Sub-CPU Handshake Flag
.equ SCD_COMM_CMD,   0xA12010    | Command Word (Track # & Loop Flag)
.equ SCD_COMM_STAT,  0xA12020    | Sub-CPU Status Return

| ----------------------------------------------------------------------------
| int msu_init(void)
| Detects Sega CD hardware, boots BIOS in Mode 1, and loads CD-DA driver
| Returns: d0 = 1 if Sega CD detected & ready, 0 if not present
| ----------------------------------------------------------------------------
msu_init:
        movem.l d1-d2/a0-a1, -(sp)

        | Check for Sega CD BIOS signature at $415800 ("SEGA")
        lea     0x415800, a0
        cmp.l   #0x53454741, (a0)       | 'SEGA'
        bne.s   .no_scd

        | Request Sub-CPU Bus & Reset to initialize Mode 1
        move.b  #0x02, SCD_RESET        | Assert BusReq
        move.b  #0x00, SCD_RESET        | Release Reset
        move.b  #0x01, SCD_RESET        | Run Sub-CPU

        | Wait for Sub-CPU BIOS to signal ready in COMM_STAT
        move.w  #0xFFFF, d1
.wait_bios:
        cmp.w   #0x0001, SCD_COMM_STAT
        beq.s   .scd_ready
        dbra    d1, .wait_bios
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
| Stack args: 4(sp) = track_num, 8(sp) = loop (1 = loop, 0 = once)
| ----------------------------------------------------------------------------
msu_play_track:
        move.b  7(sp), d0               | Get track_num
        move.b  11(sp), d1              | Get loop flag
        lsl.w   #8, d1
        or.b    d0, d1                  | Pack: High byte = loop, Low byte = track

        move.w  d1, SCD_COMM_CMD        | Write command to Sub-CPU mailbox
        move.b  #0x01, SCD_COMM_FLAG    | Trigger Sub-CPU command interrupt
        rts

| ----------------------------------------------------------------------------
| void msu_stop(void)
| Stops CD-DA playback immediately
| ----------------------------------------------------------------------------
msu_stop:
        move.w  #0x0000, SCD_COMM_CMD   | Command 0x0000 = Stop Audio
        move.b  #0x01, SCD_COMM_FLAG
        rts
