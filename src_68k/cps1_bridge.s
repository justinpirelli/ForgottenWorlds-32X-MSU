| ============================================================================
| CPS-1 Arcade-to-32X Hardware Compatibility Shim (Motorola 68000)
| Bridges CPS-1 JAMMA Inputs, Rotary Dial, VRAM Staging & Sound Latch
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
| 32X Shared SDRAM Window (68000 Cache-Through Space @ $22000000 / $880000)
.equ MARS_SDRAM_BASE,   0x00880000

| Genesis I/O Data & Control Ports
.equ IO_DATA1,          0x00A10003
.equ IO_CTRL1,          0x00A10009
.equ IO_DATA2,          0x00A10005
.equ IO_CTRL2,          0x00A1000B

| ----------------------------------------------------------------------------
| void cps1_bridge_init(void)
| Initializes rotary dial accumulators & clears staged CPS-1 VRAM
| ----------------------------------------------------------------------------
cps1_bridge_init:
        lea     dial_angle_p1(%pc), %a0
        clr.w   (%a0)+                  | Reset P1 & P2 satellite dial angles
        lea     (CPS1_VRAM_STAGE).l, %a0
        move.w  #0x0FFF, %d0
.clear_stage:
        clr.l   (%a0)+
        dbra    %d0, .clear_stage
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_p1(void)
| Translates Genesis 6-button P1 pad into active-low CPS-1 JAMMA byte
| CPS-1 Bits: 0=Right, 1=Left, 2=Down, 3=Up, 4=Btn1(Fire), 5=Btn2(Mega), 7=Start
| Also updates P1 Rotary Dial angle from X (CCW) and Z (CW) buttons
| ----------------------------------------------------------------------------
cps1_bridge_read_p1:
        movem.l %d1-%d2/%a0, -(%sp)
        pea     (IO_CTRL1).l
        pea     (IO_DATA1).l
        jsr     read_genesis_pad
        addq.l  #8, %sp

        | d0 returns active-low Genesis bits: [Z Y X Mode | Start A C B | R L D U]

        | Update Rotary Dial (Bit 10 = X -> Rotate CCW, Bit 8 = Z -> Rotate CW)
        lea     dial_angle_p1(%pc), %a0
        move.b  (%a0), %d1
        btst    #10, %d0                | X button pressed (active low = 0)?
        bne.s   .no_ccw1
        subq.b  #3, %d1                 | Rotate satellite counter-clockwise
.no_ccw1:
        btst    #8, %d0                 | Z button pressed (active low = 0)?
        bne.s   .no_cw1
        addq.b  #3, %d1                 | Rotate satellite clockwise
.no_cw1:
        move.b  %d1, (%a0)

        | Pack Genesis buttons into CPS-1 JAMMA format (active low)
        moveq   #-1, %d2                | Start with 0xFF (all unpressed)
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
        btst    #7, %d0                 | Start -> 1P Start + Coin
        bne.s   .p1_no_st
        bclr    #7, %d2
.p1_no_st:
        move.b  %d2, %d0
        movem.l (%sp)+, %d1-%d2/%a0
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_p2(void)
| Translates Genesis 6-button P2 pad into active-low CPS-1 JAMMA byte
| ----------------------------------------------------------------------------
cps1_bridge_read_p2:
        movem.l %d1-%d2/%a0, -(%sp)
        pea     (IO_CTRL2).l
        pea     (IO_DATA2).l
        jsr     read_genesis_pad
        addq.l  #8, %sp

        lea     dial_angle_p2(%pc), %a0
        move.b  (%a0), %d1
        btst    #10, %d0
        bne.s   .no_ccw2
        subq.b  #3, %d1
.no_ccw2:
        btst    #8, %d0
        bne.s   .no_cw2
        addq.b  #3, %d1
.no_cw2:
        move.b  %d1, (%a0)

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
        movem.l (%sp)+, %d1-%d2/%a0
        rts

| ----------------------------------------------------------------------------
| uint8_t cps1_bridge_read_dial1(void) / cps1_bridge_read_dial2(void)
| Returns current 8-bit rotary dial angle (0x00 - 0xFF)
| ----------------------------------------------------------------------------
cps1_bridge_read_dial1:
        move.b  dial_angle_p1(%pc), %d0
        rts

cps1_bridge_read_dial2:
        move.b  dial_angle_p2(%pc), %d0
        rts

| ----------------------------------------------------------------------------
| void cps1_bridge_sound_latch(uint8_t cmd in d0)
| Forwards intercepted CPS-1 $800180 sound writes to C cps1_sound_write()
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
| Copies staged CPS-1 Palette & Object RAM ($FF8000) to 32X SDRAM ($880000)
| ----------------------------------------------------------------------------
cps1_bridge_flush_vram:
        movem.l %d0/%a0-%a1, -(%sp)
        lea     (CPS1_VRAM_STAGE).l, %a0
        lea     (MARS_SDRAM_BASE).l, %a1
        move.w  #0x03FF, %d0            | Copy 4KB (Palette + Sprite List)
.flush_loop:
        move.l  (%a0)+, (%a1)+
        dbra    %d0, .flush_loop
        movem.l (%sp)+, %d0/%a0-%a1
        rts

        .align 2
dial_angle_p1:
        .byte   0x00
dial_angle_p2:
        .byte   0x00