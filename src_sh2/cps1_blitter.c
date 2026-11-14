c

#include "cps1_blitter.h"

// ============================================================================
// Convert CPS-1 16-bit Palette Entries (0x0RGB) to 32X CRAM (0x0BGR)
// ============================================================================
void cps1_update_palette(const uint16_t *cps1_pal_ram) {
    for (int i = 0; i < 256; i++) {
        uint16_t cps_color = cps1_pal_ram[i];

        // Extract 4-bit R, G, B from CPS-1 format (0000 RRRR GGGG BBBB)
        // Scale 4-bit (0-15) up to 5-bit (0-31) for 32X VDP
        uint16_t r = ((cps_color >> 8) & 0x0F) << 1;
        uint16_t g = ((cps_color >> 4) & 0x0F) << 1;
        uint16_t b = (cps_color & 0x0F) << 1;

        // Pack into 32X CRAM format: 0 BBBBB GGGGG RRRRR
        MARS_PALETTE_RAM[i] = (b << 10) | (g << 5) | r;
    }
}

// ============================================================================
// Blit a single 16x16 Linear 8-bit Tile/Sprite into the 320x224 Framebuffer
// ============================================================================
void cps1_blit_tile16(
    const uint8_t *tile_rom,
    uint16_t tile_id,
    int16_t screen_x,
    int16_t screen_y,
    uint8_t pal_bank,
    uint8_t flip_flags
) {
    // Quick off-screen rejection
    if (screen_x <= -16 || screen_x >= SCREEN_WIDTH ||
        screen_y <= -16 || screen_y >= SCREEN_HEIGHT) {
        return;
    }

    // Each 16x16 8-bit linear tile occupies 256 bytes (16 * 16)
    const uint8_t *src_tile = tile_rom + ((uint32_t)tile_id << 8);
    uint8_t pal_offset = (pal_bank & 0x0F) << 4;
    uint8_t flip_x = flip_flags & 0x01;
    uint8_t flip_y = flip_flags & 0x02;

    for (int row = 0; row < 16; row++) {
        int16_t dst_y = screen_y + row;
        if (dst_y < 0 || dst_y >= SCREEN_HEIGHT) continue;

        int src_row = flip_y ? (15 - row) : row;
        const uint8_t *src_line = src_tile + (src_row << 4);
        volatile uint8_t *dst_line = MARS_FB_BASE + (dst_y * SCREEN_WIDTH);

        for (int col = 0; col < 16; col++) {
            int16_t dst_x = screen_x + col;
            if (dst_x < 0 || dst_x >= SCREEN_WIDTH) continue;

            int src_col = flip_x ? (15 - col) : col;
            uint8_t pixel = src_line[src_col];

            // Color index 0 in CPS-1 is always transparent
            if (pixel != 0) {
                dst_line[dst_x] = pal_offset | (pixel & 0x0F);
            }
        }
    }
}

// ============================================================================
// Render All Active CPS-1 Sprites (Called by Slave SH-2)
// ============================================================================
void cps1_render_sprites(
    const uint8_t *sprite_rom,
    const CPS1_Sprite *obj_list,
    uint16_t count,
    int16_t camera_x
) {
    for (uint16_t i = 0; i < count; i++) {
        const CPS1_Sprite *spr = &obj_list[i];

        // Bit 7 marks active sprite
        if (!(spr->flags & 0x80)) continue;

        // Apply 384 -> 320 camera pan offset
        int16_t final_x = spr->x - camera_x;

        cps1_blit_tile16(
            sprite_rom,
            spr->tile_id,
            final_x,
            spr->y,
            spr->palette_bank,
            spr->flags
        );
    }
}
