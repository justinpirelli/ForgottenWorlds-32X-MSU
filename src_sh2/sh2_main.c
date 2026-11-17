#include <stdint.h>
#include "cps1_blitter.h"
#include "cps1_scroll.h"
#include "pwm_audio.h"

// 32X SH-2 System, DREQ/FIFO & VDP Registers (Cache-Through Space)
#define SH2_MARS_DREQ_CTRL  (*(volatile uint16_t *)0x20004006) // Bit 6 = FIFO Empty
#define SH2_MARS_FIFO_PORT  (*(volatile uint16_t *)0x20004012) // 16-bit FIFO Read Port
#define SH2_MARS_COMM0      (*(volatile uint16_t *)0x20004020) // Command from 68000
#define SH2_MARS_COMM2      (*(volatile uint16_t *)0x20004022) // SFX / Voice ID Mailbox
#define SH2_MARS_COMM4      (*(volatile uint16_t *)0x20004024) // Camera X Pan (0-64)
#define SH2_VDP_MODE        (*(volatile uint16_t *)0x20004100) // VDP Display Mode
#define SH2_VDP_FBCTL       (*(volatile uint16_t *)0x2000410A) // Framebuffer Swap Control

// Raw 16KB Staged CPS-1 VRAM Received from 68000 FIFO (0x26028000 - 0x2602BFFF)
#define RAW_CPS1_VRAM       ((volatile uint16_t *)0x26028000)

// Translated 32X SDRAM Buffers (0x26030000 - 0x2603DFFF, safe below 0x0603F800 stacks)
#define SHARED_PALETTE_RAM  ((uint16_t *)0x26030000)
#define SHARED_SPRITE_COUNT (*(volatile uint16_t *)0x26030200)
#define SHARED_SPRITE_LIST  ((CPS1_Sprite *)0x26030400)        // Up to 512 expanded 16x16 sprites
#define SHARED_SCROLL1_MAP  ((CPS1_TileEntry *)0x26031400)     // 64x64 * 4B = 16KB (0x26031400..0x260353FF)
#define SHARED_SCROLL2_MAP  ((CPS1_TileEntry *)0x26035400)     // 64x64 * 4B = 16KB (0x26035400..0x260393FF)
#define SHARED_SCROLL3_MAP  ((CPS1_TileEntry *)0x26039400)     // 64x64 * 4B = 16KB (0x26039400..0x2603D3FF)

// Cartridge ROM Offsets for Converted Linear Assets (2MB & 3MB Marks)
#define CART_SPRITE_ROM     ((const uint8_t *)0x22200000)
#define CART_SFX_TABLE      ((const PWM_SampleAsset *)0x22300000)

static uint16_t sh2_frame_num = 0;

void init_32x_vdp(void) {
    SH2_VDP_MODE = 0x0001; // 256-Color Packed Pixel Mode (320x224)

    volatile uint16_t *line_table = (volatile uint16_t *)0x24000000;
    for (int bank = 0; bank < 2; bank++) {
        SH2_VDP_FBCTL = bank;
        while ((SH2_VDP_FBCTL & 0x0001) != bank);

        for (int line = 0; line < 224; line++) {
            line_table[line] = 0x0100 + (line * 160);
        }
    }

    pwm_audio_init();
}

// Receive 16KB (8192 words) of staged CPS-1 VRAM + CPS-A registers from 68000 FIFO
static void receive_68k_vram_fifo(void) {
    volatile uint16_t *dst = RAW_CPS1_VRAM;
    for (int i = 0; i < 8192; i++) {
        while (SH2_MARS_DREQ_CTRL & 0x0040);
        dst[i] = SH2_MARS_FIFO_PORT;
    }
}

// Unpack a 64x64 CPS-1 Tilemap Page (4096 entries * 2 words) into CPS1_TileEntry structs
static void unpack_cps1_tilemap(const volatile uint16_t *src_words, CPS1_TileEntry *dst_map) {
    for (int i = 0; i < 4096; i++) {
        uint16_t tile_id = src_words[(i << 1) + 0];
        uint16_t attr    = src_words[(i << 1) + 1];
        dst_map[i].tile_id      = tile_id;
        dst_map[i].palette_bank = (uint8_t)(attr & 0x0F);
        dst_map[i].flip_flags   = (uint8_t)((attr >> 5) & 0x03); // Bit 5=FlipX, Bit 6=FlipY
    }
}

// Translate Raw CPS-1 Object RAM, Palette RAM & Scroll Registers into 32X Structures
static void cps1_translate_vram(CPS1_ScrollLayer *s1, CPS1_ScrollLayer *s2, CPS1_ScrollLayer *s3) {
    // CPS-A Shadow Registers stored at end of 16KB staging buffer (word offset 0x1F80 = $FFBF00)
    const volatile uint16_t *cps_regs = &RAW_CPS1_VRAM[0x1F80];

    // Extract CPS-A Scroll X/Y offsets ($80010C..$800116 -> indices 6..11)
    s1->scroll_x = (int16_t)cps_regs[6];
    s1->scroll_y = (int16_t)cps_regs[7];
    s2->scroll_x = (int16_t)cps_regs[8];
    s2->scroll_y = (int16_t)cps_regs[9];
    s3->scroll_x = (int16_t)cps_regs[10];
    s3->scroll_y = (int16_t)cps_regs[11];

    // Copy 256-entry CPS-1 Palette RAM (Page at word offset 0x1800)
    const volatile uint16_t *pal_src = &RAW_CPS1_VRAM[0x1800];
    for (int i = 0; i < 256; i++) {
        SHARED_PALETTE_RAM[i] = pal_src[i];
    }

    // Expand Native CPS-1 Object RAM (up to 256 entries, 4 words each) into 16x16 CPS1_Sprites
    const volatile uint16_t *obj_src = &RAW_CPS1_VRAM[0x0000];
    uint16_t out_count = 0;

    for (int i = 0; i < 256 && out_count < 512; i++) {
        uint16_t raw_x = obj_src[(i << 2) + 0];
        uint16_t raw_y = obj_src[(i << 2) + 1];
        uint16_t code  = obj_src[(i << 2) + 2];
        uint16_t attr  = obj_src[(i << 2) + 3];

        // CPS-1 Object list terminates when attribute high byte == 0xFF
        if ((attr & 0xFF00) == 0xFF00) break;

        uint8_t pal_bank   = (uint8_t)(attr & 0x0F);
        uint8_t flip_flags = (uint8_t)((attr >> 5) & 0x03);
        uint8_t cols       = (uint8_t)(((attr >> 8) & 0x0F) + 1); // NxM block width (1..16)
        uint8_t rows       = (uint8_t)(((attr >> 12) & 0x0F) + 1); // NxM block height (1..16)

        // CPS-1 active display starts at X=64, Y=16 inside 512x262 raster
        int16_t base_x = (int16_t)(raw_x & 0x01FF) - 64;
        int16_t base_y = (int16_t)(raw_y & 0x01FF) - 16;

        for (uint8_t r = 0; r < rows && out_count < 512; r++) {
            uint8_t src_r = (flip_flags & 0x02) ? (rows - 1 - r) : r;
            for (uint8_t c = 0; c < cols && out_count < 512; c++) {
                uint8_t src_c = (flip_flags & 0x01) ? (cols - 1 - c) : c;

                CPS1_Sprite *dst = &SHARED_SPRITE_LIST[out_count++];
                dst->x            = base_x + (c << 4);
                dst->y            = base_y + (r << 4);
                dst->tile_id      = code + (src_r << 4) + src_c; // CPS-1 16-tile row stride
                dst->palette_bank = pal_bank;
                dst->flags        = flip_flags | 0x80;           // Bit 7 = Active
            }
        }
    }
    SHARED_SPRITE_COUNT = out_count;

    // Unpack Scroll 1, Scroll 2, and Scroll 3 Tilemaps into SDRAM
    unpack_cps1_tilemap(&RAW_CPS1_VRAM[0x0400], SHARED_SCROLL1_MAP);
    unpack_cps1_tilemap(&RAW_CPS1_VRAM[0x0C00], SHARED_SCROLL2_MAP);
    unpack_cps1_tilemap(&RAW_CPS1_VRAM[0x1400], SHARED_SCROLL3_MAP);
}

// ============================================================================
// Master SH-2 Entry Point (VDP Control, FIFO Sync & Background Layers)
// ============================================================================
void master_sh2_main(void) {
    CPS1_ScrollLayer scroll3 = { CART_SPRITE_ROM, SHARED_SCROLL3_MAP, 0, 0, 0 };
    CPS1_ScrollLayer scroll2 = { CART_SPRITE_ROM, SHARED_SCROLL2_MAP, 0, 0, 0 };
    CPS1_ScrollLayer scroll1 = { CART_SPRITE_ROM, SHARED_SCROLL1_MAP, 0, 0, 0 };

    while (1) {
        uint16_t cmd = SH2_MARS_COMM0;

        if (cmd == 0x0001) {
            init_32x_vdp();
            SH2_MARS_COMM0 = 0x0000;
        } else if (cmd == 0x0002) {
            uint16_t fb = SH2_VDP_FBCTL & 0x0001;
            SH2_VDP_FBCTL = fb ^ 0x0001;

            int16_t camera_x = (int16_t)SH2_MARS_COMM4;

#ifdef USE_CPS1_ARCADE_ROM
            // 1. Drain 16KB staged CPS-1 VRAM from 68000 FIFO
            receive_68k_vram_fifo();

            // 2. Translate CPS-1 Object RAM, Palette & Scroll Registers
            cps1_translate_vram(&scroll1, &scroll2, &scroll3);

            // 3. Sync CPS-1 256-color palette to 32X CRAM
            cps1_update_palette(SHARED_PALETTE_RAM);

            // 4. Render CPS-1 Background Layers Back-to-Front (Scroll 3 -> 2 -> 1)
            cps1_render_scroll3_32x32(&scroll3, camera_x);
            cps1_render_scroll2_16x16(&scroll2, camera_x);
            cps1_render_scroll1_8x8(&scroll1, camera_x);
#else
            cps1_render_hardware_test_screen(sh2_frame_num++, camera_x);
#endif

            // Signal Slave SH-2 to draw sprites over backgrounds & mix PWM audio
            SH2_MARS_COMM0 = 0x0003;
        }
    }
}

// ============================================================================
// Slave SH-2 Entry Point (Dedicated Sprite / Object Blitter & PWM Mixer)
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

            uint16_t sfx_cmd = SH2_MARS_COMM2;
            if (sfx_cmd & 0x8000) {
                uint8_t sfx_id = (uint8_t)(sfx_cmd & 0x7F);
                pwm_play_sfx(sfx_id, CART_SFX_TABLE, 128);
                SH2_MARS_COMM2 = 0x0000;
            }

            pwm_mix_frame();
            SH2_MARS_COMM0 = 0x0000;
        }
    }
}