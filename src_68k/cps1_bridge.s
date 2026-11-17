| ============================================================================
| CPS-1 Arcade-to-32X Hardware Compatibility Shim (Motorola 68000)
| Bridges CPS-1 JAMMA Inputs, Rotary Dial, 32X 16KB FIFO VRAM & Sound Latch
| ============================================================================
        .section .text
        .align 2

        .global cps1_bridge_init
        .global cps1_bridge_read_p1
        .global cps1_bridge_read_p2
        .global cps1_bridge_read_dial1
        .global cps1_bridge_read_dial2
        .global cps1_bridge_sound_latch
        .global cps1_bridge_flush_vram

        .extern cps1_sound_write
        .extern read_genesis_pad

| Staged CPS-1 VRAM in Genesis Work RAM ($FF8000 - $FFBFFF, 16KB)
.equ CPS1_VRAM_STAGE,   0x00FF8000

| 32X DREQ / FIFO Registers (Genesis 68000 Bus @ $A15100)
.equ MARS_DREQ_CTRL,    0x00A15106      | Bit 2 = 68S (CPU-to-FIFO Mode), Bit 7 = FIFO Full
.equ MARS_DREQ_LEN,     0x00A1510A      | Transfer length in words
.equ MARS_FIFO_PORT,    0x00A15112      | 16-bit FIFO write port to SH-2

| Genesis I/O Data & Control Ports
.equ IO_DATA1,          0x00A10003
.equ IO_CTRL1,          0x00A10009
.equ IO_DATA2,          0x00A10005
.equ IO_CTRL2,          0x00A1000B

| ----------------------------------------------------------------------------
| void cps1_bridge_init(void)
| Initializes rotary dial accumulators in RAM & clears staged CPS-1 VRAM
| ----------------------------------------------------------------------------
cps1_bridge_init:
        clr.b   (dial_angle_p1).l
        clr.b   (dial_angle_p2).l
        lea     (CPS1_VRAM_STAGE).l, %a0
        move.w  #0x0FFF, %d0
.clear_stage:
        clr.l   (%a0)+
        dbra    %d0, .clear_stage
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_p1(void)
| Translates Genesis 6-button P1 pad into active-low CPS-1 JAMMA byte
| ----------------------------------------------------------------------------
cps1_bridge_read_p1:
        movem.l %d1-%d2, -(%sp)
        pea     (IO_CTRL1).l
        pea     (IO_DATA1).l
        jsr     read_genesis_pad
        addq.l  #8, %sp

        | Update Rotary Dial in Work RAM (Bit 10 = X -> CCW, Bit 8 = Z -> CW)
        move.b  (dial_angle_p1).l, %d1
        btst    #10, %d0
        bne.s   .no_ccw1
        subq.b  #3, %d1
.no_ccw1:
        btst    #8, %d0
        bne.s   .no_cw1
        addq.b  #3, %d1
.no_cw1:
        move.b  %d1, (dial_angle_p1).l

        | Pack Genesis buttons into active-low CPS-1 JAMMA format
        moveq   #-1, %d2
        btst    #3, %d0                 | Right
        bne.s   .p1_no_r
        bclr    #0, %d2
.p1_no_r:
        btst    #2, %d0                 | Left
        bne.s   .p1_no_l
        bclr    #1, %d2
.p1_no_l:
        btst    #1, %d0                 | Down
        bne.s   .p1_no_d
        bclr    #2, %d2
.p1_no_d:
        btst    #0, %d0                 | Up
        bne.s   .p1_no_u
        bclr    #3, %d2
.p1_no_u:
        btst    #4, %d0                 | B -> Fire
        bne.s   .p1_no_b1
        bclr    #4, %d2
.p1_no_b1:
        btst    #5, %d0                 | C -> Mega Crash / Shop
        bne.s   .p1_no_b2
        bclr    #5, %d2
.p1_no_b2:
        btst    #7, %d0                 | Start -> 1P Start
        bne.s   .p1_no_st
        bclr    #7, %d2
.p1_no_st:
        move.b  %d2, %d0
        movem.l (%sp)+, %d1-%d2
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_p2(void)
| Translates Genesis 6-button P2 pad into active-low CPS-1 JAMMA byte
| ----------------------------------------------------------------------------
cps1_bridge_read_p2:
        movem.l %d1-%d2, -(%sp)
        pea     (IO_CTRL2).l
        pea     (IO_DATA2).l
        jsr     read_genesis_pad
        addq.l  #8, %sp

        move.b  (dial_angle_p2).l, %d1
        btst    #10, %d0
        bne.s   .no_ccw2
        subq.b  #3, %d1
.no_ccw2:
        btst    #8, %d0
        bne.s   .no_cw2
        addq.b  #3, %d1
.no_cw2:
        move.b  %d1, (dial_angle_p2).l

        moveq   #-1, %d2
        btst    #3, %d0
        bne.s   .p2_no_r
        bclr    #0, %d2
.p2_no_r:
        btst    #2, %d0
        bne.s   .p2_no_l
        bclr    #1, %d2
.p2_no_l:
        btst    #1, %d0
        bne.s   .p2_no_d
        bclr    #2, %d2
.p2_no_d:
        btst    #0, %d0
        bne.s   .p2_no_u
        bclr    #3, %d2
.p2_no_u:
        btst    #4, %d0
        bne.s   .p2_no_b1
        bclr    #4, %d2
.p2_no_b1:
        btst    #5, %d0
        bne.s   .p2_no_b2
        bclr    #5, %d2
.p2_no_b2:
        btst    #7, %d0
        bne.s   .p2_no_st
        bclr    #7, %d2
.p2_no_st:
        move.b  %d2, %d0
        movem.l (%sp)+, %d1-%d2
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_dial1(void) / cps1_bridge_read_dial2(void)
| ----------------------------------------------------------------------------
cps1_bridge_read_dial1:
        move.b  (dial_angle_p1).l, %d0
        rts

cps1_bridge_read_dial2:
        move.b  (dial_angle_p2).l, %d0
        rts

| ----------------------------------------------------------------------------
| void cps1_bridge_sound_latch(uint8_t cmd in d0)
| ----------------------------------------------------------------------------
cps1_bridge_sound_latch:
        movem.l %d0-%d1/%a0-%a1, -(%sp)
        andi.l  #0x000000FF, %d0
        move.l  %d0, -(%sp)
        jsr     cps1_sound_write
        addq.l  #4, %sp
        movem.l (%sp)+, %d0-%d1/%a0-%a1
        rts

| ----------------------------------------------------------------------------
| void cps1_bridge_flush_vram(void)
| Streams full 16KB staged VRAM + CPS-A regs ($FF8000-$FFBFFF) via 32X FIFO
| ----------------------------------------------------------------------------
cps1_bridge_flush_vram:
        movem.l %d0/%a0-%a1, -(%sp)
        lea     (CPS1_VRAM_STAGE).l, %a0
        lea     (MARS_FIFO_PORT).l, %a1

        | Configure 32X DREQ for 68000 CPU-to-FIFO transfer (8192 words = 16KB)
        move.w  #0x2000, (MARS_DREQ_LEN).l
        move.w  #0x0004, (MARS_DREQ_CTRL).l

        move.w  #0x07FF, %d0            | 2048 blocks * 4 words (8 bytes) = 16384 bytes
.fifo_loop:
        btst    #7, (MARS_DREQ_CTRL).l  | Wait while 32X 4-word FIFO is full
        bne.s   .fifo_loop
        move.w  (%a0)+, (%a1)
        move.w  (%a0)+, (%a1)
        move.w  (%a0)+, (%a1)
        move.w  (%a0)+, (%a1)
        dbra    %d0, .fifo_loop

        move.w  #0x0000, (MARS_DREQ_CTRL).l
        movem.l (%sp)+, %d0/%a0-%a1
        rts

| ----------------------------------------------------------------------------
| Writable Genesis Work RAM (.bss)
| ----------------------------------------------------------------------------
        .section .bss
        .align 2
dial_angle_p1:
        .space  1
dial_angle_p2:
        .space  1