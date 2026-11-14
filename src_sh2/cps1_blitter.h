
#ifndef CPS1_BLITTER_H
#define CPS1_BLITTER_H

#include <stdint.h>

// 32X Framebuffer & CRAM (Color Palette RAM) Addresses (SH-2 Cache-Through Space)
#define MARS_FB_BASE        ((volatile uint8_t *)0x24000200)
#define MARS_CRAM_BASE      ((volatile uint16_t *)0x24000200) // Wait: 32X CRAM is at 0x20004200
#define MARS_PALETTE_RAM    ((volatile uint16_t *)0x20004200)

// Screen Dimensions
#define SCREEN_WIDTH        320
#define SCREEN_HEIGHT       224
#define CPS1_ARCADE_WIDTH   384

// CPS-1 Sprite / Object Descriptor (Matches CPS-1 Object RAM Format)
typedef struct {
    int16_t  x;             // Arcade X position (0 - 383)
    int16_t  y;             // Arcade Y position (0 - 223)
    uint16_t tile_id;       // Index into 16x16 linear tile ROM
    uint8_t  palette_bank;  // High 4 bits of 256-color index (0 - 15)
    uint8_t  flags;         // Bit 0: Flip X, Bit 1: Flip Y, Bit 7: Active
} CPS1_Sprite;

// Functions
void cps1_update_palette(const uint16_t *cps1_pal_ram);
void cps1_blit_tile16(const uint8_t *tile_rom, uint16_t tile_id, int16_t screen_x, int16_t screen_y, uint8_t pal_bank, uint8_t flip_flags);
void cps1_render_sprites(const uint8_t *sprite_rom, const CPS1_Sprite *obj_list, uint16_t count, int16_t camera_x);

#endif // CPS1_BLITTER_H
