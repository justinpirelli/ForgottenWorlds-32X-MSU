#include <stdint.h>
#include "cps1_blitter.h"
#include "cps1_scroll.h"

// 32X SH-2 System & VDP Registers (Cache-Through Space)
#define SH2_MARS_COMM0      (*(volatile uint16_t *)0x20004020) // Command from 68000
#define SH2_MARS_COMM4      (*(volatile uint16_t *)0x20004024) // Camera X Pan (0-64)
#define SH2_VDP_MODE        (*(volatile uint16_t *)0x20004100) // VDP Display Mode
#define SH2_VDP_FBCTL       (*(volatile uint16_t *)0x2000410A) // Framebuffer Swap Control

// Shared SDRAM Pointers (Populated by 68000 CPS-1 Arcade Code)
#define SHARED_PALETTE_RAM  ((const uint16_t *)0x22000000)
#define SHARED_SPRITE_LIST  ((const CPS1_Sprite *)0x22000400)
#define SHARED_SPRITE_COUNT (*(volatile uint16_t *)0x22000200)

// Cartridge ROM Offset for Converted 8-bit CPS-1 Sprite Tiles (2MB mark)
#define CART_SPRITE_ROM     ((const uint8_t *)0x22200000)

static uint16_t sh2_frame_num = 0;

void init_32x_vdp(void) {
    // 0x0001 = 256-Color Packed Pixel Mode (320x224)
    SH2_VDP_MODE = 0x0001;

    // Populate the 32X VDP Line Table (first 256 words of both framebuffer banks)
    volatile uint16_t *line_table = (volatile uint16_t *)0x24000000;
    for (int bank = 0; bank < 2; bank++) {
        SH2_VDP_FBCTL = bank;
        while ((SH2_VDP_FBCTL & 0x0001) != bank); // Wait for bank swap

        for (int line = 0; line < 224; line++) {
            // Each line starts at word offset 0x100 (byte 0x200) + line * 160 words (320 bytes)
            line_table[line] = 0x0100 + (line * 160);
        }
    }
}

// ============================================================================
// Master SH-2 Entry Point (VDP Control, Palette Sync & Background Layers)
// ============================================================================
void master_sh2_main(void) {
    while (1) {
        uint16_t cmd = SH2_MARS_COMM0;

        if (cmd == 0x0001) {
            init_32x_vdp();
            SH2_MARS_COMM0 = 0x0000; // Acknowledge init complete
        } 
        else if (cmd == 0x0002) {
            // Swap active framebuffer bank
            uint16_t fb = SH2_VDP_FBCTL & 0x0001;
            SH2_VDP_FBCTL = fb ^ 0x0001;

            #ifdef USE_CPS1_ARCADE_ROM
            // Sync CPS-1 256-color palette to 32X CRAM
            cps1_update_palette(SHARED_PALETTE_RAM);
#else
            // Render live 3-layer parallax hardware test screen
            int16_t camera_x = (int16_t)SH2_MARS_COMM4;
            cps1_render_hardware_test_screen(sh2_frame_num++, camera_x);
#endif

            // Signal Slave SH-2 to draw sprites over backgrounds
            SH2_MARS_COMM0 = 0x0003;
        }
    }
}

// ============================================================================
// Slave SH-2 Entry Point (Dedicated Sprite / Object Blitter)
// ============================================================================
void slave_sh2_main(void) {
    while (1) {
        if (SH2_MARS_COMM0 == 0x0003) {
            int16_t camera_x = (int16_t)SH2_MARS_COMM4;
            uint16_t obj_count = SHARED_SPRITE_COUNT;

            cps1_render_sprites(
                CART_SPRITE_ROM,
                SHARED_SPRITE_LIST,
                obj_count,
                camera_x
            );

            // Signal 68000 that full frame render is finished
            SH2_MARS_COMM0 = 0x0000;
        }
    }
}