| ============================================================================
| Sega CD Mode 1 (MSU-MD Compatible) Main-CPU Driver for 32X Cartridges
| ============================================================================
        .section .text
        .align 2

        .global msu_init
        .global msu_play_track
        .global msu_stop

| Sega CD Gate Array Registers (Main 68000 Bus @ $A12000)
.equ SCD_RESET,      0x00A12001  | Bit 0: SRES (1=Run), Bit 1: SBRQ (1=BusReq)
.equ SCD_MEM_MODE,   0x00A12003  | PRG-RAM Bank & Write Protect Control
.equ SCD_COMM_FLAG,  0x00A1200E  | Main-CPU -> Sub-CPU Handshake Flag
.equ SCD_COMM_CMD,   0x00A12010  | Command Word (Track # & Loop Flag)
.equ SCD_COMM_STAT,  0x00A12020  | Sub-CPU Status Return
.equ SCD_BIOS_HDR,   0x00400100  | Sega CD Mode 1 BIOS ROM Header ("SEGA")
.equ SCD_PRG_SP,     0x00426000  | Sub-CPU PRG-RAM System Program Entry ($006000)

| ----------------------------------------------------------------------------
| int msu_init(void)
| Detects Sega CD Mode 1 BIOS, loads SP payload at $426000, and boots Sub-CPU
| ----------------------------------------------------------------------------
msu_init:
        movem.l %d1-%d2/%a0-%a1, -(%sp)
        clr.b   (scd_present).l

        | 1. Check for Sega CD Mode 1 BIOS signature at $400100 ("SEGA")
        lea     (SCD_BIOS_HDR).l, %a0
        cmp.l   #0x53454741, (%a0)
        bne.s   .no_scd

        | 2. Assert Sub-CPU Reset & Request PRG-RAM Bus Access
        move.b  #0x02, (SCD_RESET).l
.wait_bus:
        btst    #1, (SCD_RESET).l
        beq.s   .wait_bus

        | Disable PRG-RAM write-protect & select Bank 0
        move.b  #0x00, (SCD_MEM_MODE).l

        | 3. Copy compiled Sub-CPU SP payload into PRG-RAM @ $426000 ($006000 Sub)
        lea     sub_cpu_payload(%pc), %a0
        lea     (SCD_PRG_SP).l, %a1
        move.w  #((sub_cpu_payload_end - sub_cpu_payload) / 2) - 1, %d1
.copy_loop:
        move.w  (%a0)+, (%a1)+
        dbra    %d1, .copy_loop

        | 4. Release BusReq & Start Sub-CPU
        move.b  #0x01, (SCD_RESET).l
.wait_run:
        btst    #0, (SCD_RESET).l
        beq.s   .wait_run

        | 5. Wait for Sub-CPU SP_INIT & CD TOC spin-up ($0001 in COMM_STAT)
        move.l  #0x002FFFFF, %d1
.wait_bios:
        cmp.w   #0x0001, (SCD_COMM_STAT).l
        beq.s   .scd_ready
        subq.l  #1, %d1
        bne.s   .wait_bios
        bra.s   .no_scd

.scd_ready:
        move.b  #1, (scd_present).l
        moveq   #1, %d0
        movem.l (%sp)+, %d1-%d2/%a0-%a1
        rts

.no_scd:
        moveq   #0, %d0
        movem.l (%sp)+, %d1-%d2/%a0-%a1
        rts

| ----------------------------------------------------------------------------
| void msu_play_track(uint8_t track_num, uint8_t loop)
| ----------------------------------------------------------------------------
msu_play_track:
        tst.b   (scd_present).l         | Safe no-op if Sega CD is not attached
        beq.s   .play_done

        move.b  7(%sp), %d0             | track_num
        move.b  11(%sp), %d1            | loop (1 = loop, 0 = once)
        lsl.w   #8, %d1
        or.b    %d0, %d1

        move.w  %d1, (SCD_COMM_CMD).l
        bset    #0, (SCD_COMM_FLAG).l

.wait_ack:
        cmp.w   (SCD_COMM_STAT).l, %d1
        bne.s   .wait_ack

        bclr    #0, (SCD_COMM_FLAG).l
.play_done:
        rts

| ----------------------------------------------------------------------------
| void msu_stop(void)
| ----------------------------------------------------------------------------
msu_stop:
        tst.b   (scd_present).l
        beq.s   .stop_done

        move.w  #0x0000, (SCD_COMM_CMD).l
        bset    #0, (SCD_COMM_FLAG).l

.wait_stop_ack:
        tst.w   (SCD_COMM_STAT).l
        bne.s   .wait_stop_ack

        bclr    #0, (SCD_COMM_FLAG).l
.stop_done:
        rts

| ----------------------------------------------------------------------------
| Embedded Sub-CPU Binary Payload (Built from src_scd/sub_cpu.s)
| ----------------------------------------------------------------------------
        .align 2
sub_cpu_payload:
        .incbin "build/sub_cpu.bin"
sub_cpu_payload_end:

        .section .bss
        .align 2
scd_present:
        .space  1
