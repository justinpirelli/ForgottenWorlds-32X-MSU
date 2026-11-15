#include "cps1_scroll.h"

// ============================================================================
// Internal Helper: Blit an NxN Linear 8-bit Tile (size = 8, 16, or 32)
// ============================================================================
static inline void blit_tile_nxn(
    const uint8_t *tile_rom,
    uint16_t tile_id,
    int16_t screen_x,
    int16_t screen_y,
    uint8_t pal_bank,
    uint8_t flip_flags,
    int size,
    int shift,
    int mask,
    int opaque
) {
    if (screen_x <= -size || screen_x >= SCREEN_WIDTH ||
        screen_y <= -size || screen_y >= SCREEN_HEIGHT) {
        return;
    }

    // Tile byte size = size * size (64, 256, or 1024 bytes)
    const uint8_t *src_tile = tile_rom + ((uint32_t)tile_id << (shift + shift));
    uint8_t pal_offset = (pal_bank & 0x0F) << 4;
    uint8_t flip_x = flip_flags & 0x01;
    uint8_t flip_y = flip_flags & 0x02;

    for (int row = 0; row < size; row++) {
        int16_t dst_y = screen_y + row;
        if (dst_y < 0 || dst_y >= SCREEN_HEIGHT) continue;

        int src_row = flip_y ? (mask - row) : row;
        const uint8_t *src_line = src_tile + (src_row << shift);
        volatile uint8_t *dst_line = MARS_FB_BASE + (dst_y * SCREEN_WIDTH);

        for (int col = 0; col < size; col++) {
            int16_t dst_x = screen_x + col;
            if (dst_x < 0 || dst_x >= SCREEN_WIDTH) continue;

            int src_col = flip_x ? (mask - col) : col;
            uint8_t pixel = src_line[src_col];

            if (opaque || pixel != 0) {
                dst_line[dst_x] = pal_offset | (pixel & 0x0F);
            }
        }
    }
}

// ============================================================================
// Scroll 3: Distant Background Layer (32x32 Tiles, Opaque Back Layer)
// ============================================================================
void cps1_render_scroll3_32x32(const CPS1_ScrollLayer *layer, int16_t camera_x) {
    int16_t total_x = layer->scroll_x + camera_x;
    int16_t total_y = layer->scroll_y;

    int start_tx = (total_x >> 5);
    int start_ty = (total_y >> 5);
    int fine_x   = -(total_x & 31);
    int fine_y   = -(total_y & 31);

    // 320 / 32 = 10 tiles wide (+1 partial), 224 / 32 = 7 tiles tall (+1 partial)
    for (int ty = 0; ty < 8; ty++) {
        int map_y = (start_ty + ty) & CPS1_MAP_MASK;
        int16_t screen_y = fine_y + (ty << 5);

        for (int tx = 0; tx < 11; tx++) {
            int map_x = (start_tx + tx) & CPS1_MAP_MASK;
            int16_t screen_x = fine_x + (tx << 5);

            const CPS1_TileEntry *entry = &layer->tilemap[(map_y << 6) | map_x];
            blit_tile_nxn(
                layer->gfx_rom, entry->tile_id,
                screen_x, screen_y,
                entry->palette_bank, entry->flip_flags,
                32, 5, 31, 1 // Opaque = 1 (clears background automatically)
            );
        }
    }
}

// ============================================================================
// Scroll 2: Main Stage Terrain Layer (16x16 Tiles, Transparent Index 0)
// ============================================================================
void cps1_render_scroll2_16x16(const CPS1_ScrollLayer *layer, int16_t camera_x) {
    int16_t total_x = layer->scroll_x + camera_x;
    int16_t total_y = layer->scroll_y;

    int start_tx = (total_x >> 4);
    int start_ty = (total_y >> 4);
    int fine_x   = -(total_x & 15);
    int fine_y   = -(total_y & 15);

    // 320 / 16 = 20 tiles wide (+1), 224 / 16 = 14 tiles tall (+1)
    for (int ty = 0; ty < 15; ty++) {
        int map_y = (start_ty + ty) & CPS1_MAP_MASK;
        int16_t screen_y = fine_y + (ty << 4);

        for (int tx = 0; tx < 21; tx++) {
            int map_x = (start_tx + tx) & CPS1_MAP_MASK;
            int16_t screen_x = fine_x + (tx << 4);

            const CPS1_TileEntry *entry = &layer->tilemap[(map_y << 6) | map_x];
            if (entry->tile_id == 0) continue; // Skip empty map cells

            blit_tile_nxn(
                layer->gfx_rom, entry->tile_id,
                screen_x, screen_y,
                entry->palette_bank, entry->flip_flags,
                16, 4, 15, 0
            );
        }
    }
}

// ============================================================================
// Scroll 1: Foreground HUD / Text Layer (8x8 Tiles, Fixed/Scrollable)
// ============================================================================
void cps1_render_scroll1_8x8(const CPS1_ScrollLayer *layer, int16_t camera_x) {
    int16_t total_x = layer->scroll_x + camera_x;
    int16_t total_y = layer->scroll_y;

    int start_tx = (total_x >> 3);
    int start_ty = (total_y >> 3);
    int fine_x   = -(total_x & 7);
    int fine_y   = -(total_y & 7);

    // 320 / 8 = 40 tiles wide (+1), 224 / 8 = 28 tiles tall (+1)
    for (int ty = 0; ty < 29; ty++) {
        int map_y = (start_ty + ty) & CPS1_MAP_MASK;
        int16_t screen_y = fine_y + (ty << 3);

        for (int tx = 0; tx < 41; tx++) {
            int map_x = (start_tx + tx) & CPS1_MAP_MASK;
            int16_t screen_x = fine_x + (tx << 3);

            const CPS1_TileEntry *entry = &layer->tilemap[(map_y << 6) | map_x];
            if (entry->tile_id == 0) continue;

            blit_tile_nxn(
                layer->gfx_rom, entry->tile_id,
                screen_x, screen_y,
                entry->palette_bank, entry->flip_flags,
                8, 3, 7, 0
            );
        }
    }
}

// ============================================================================
// Self-Contained 32X Hardware Verification Pattern (No External ROM Required)
// Demonstrates 3-layer parallax scrolling, 256-color CRAM, and 384->320 pan
// ============================================================================
void cps1_render_hardware_test_screen(uint16_t frame_num, int16_t camera_x) {
    // Load test colors into 32X CRAM on frame 0
    if (frame_num == 0) {
        MARS_PALETTE_RAM[0] = (4 << 10)  | (1 << 5)  | 1;   // Deep Cosmic Blue Sky
        MARS_PALETTE_RAM[1] = (14 << 10) | (5 << 5)  | 2;   // Distant Horizon Indigo
        MARS_PALETTE_RAM[2] = (6 << 10)  | (10 << 5) | 18;  // Ancient Ruins Sandstone
        MARS_PALETTE_RAM[3] = (3 << 10)  | (6 << 5)  | 11;  // Ruins Shadow Trim
        MARS_PALETTE_RAM[4] = (31 << 10) | (28 << 5) | 10;  // Unnamed Soldier Cyan/Gold
        MARS_PALETTE_RAM[5] = (8 << 10)  | (26 << 5) | 31;  // Satellite Gun Gold
        MARS_PALETTE_RAM[6] = (31 << 10) | (31 << 5) | 31;  // Pure White HUD Bar
    }

    int scroll_bg   = (frame_num >> 1) + camera_x; // Slow distant parallax
    int scroll_main = (frame_num << 1) + camera_x; // Fast foreground ruins

    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        volatile uint8_t *line = MARS_FB_BASE + (y * SCREEN_WIDTH);

        // Top HUD Zone (Simulates Scroll 1 8x8 status bar)
        if (y < 16) {
            uint8_t hud_col = (y == 15) ? 6 : 0;
            for (int x = 0; x < SCREEN_WIDTH; x++) line[x] = hud_col;
        }
        // Sky & Distant Horizon Grid (Simulates Scroll 3 32x32 parallax)
        else if (y < 160) {
            for (int x = 0; x < SCREEN_WIDTH; x++) {
                int wx = x + scroll_bg;
                line[x] = (((wx >> 5) ^ (y >> 5)) & 1) ? 1 : 0;
            }
        }
        // Lower Ruins Terrain Floor (Simulates Scroll 2 16x16 foreground)
        else {
            for (int x = 0; x < SCREEN_WIDTH; x++) {
                int wx = x + scroll_main;
                line[x] = (((wx >> 4) ^ (y >> 4)) & 1) ? 2 : 3;
            }
        }
    }

    // Draw Animated Test "Soldier + Orbiting Satellite" Sprite (384px -> 320px panned)
    int soldier_x = 120 - camera_x;
    int soldier_y = 96;
    for (int dy = 0; dy < 24; dy++) {
        int py = soldier_y + dy;
        if (py < 0 || py >= SCREEN_HEIGHT) continue;
        volatile uint8_t *line = MARS_FB_BASE + (py * SCREEN_WIDTH);
        for (int dx = 0; dx < 16; dx++) {
            int px = soldier_x + dx;
            if (px >= 0 && px < SCREEN_WIDTH) line[px] = 4;
        }
    }

    // Orbiting Satellite Pod
    int sat_x = soldier_x + 28;
    int sat_y = soldier_y - 10 + ((frame_num >> 2) & 7);
    for (int dy = 0; dy < 10; dy++) {
        int py = sat_y + dy;
        if (py < 0 || py >= SCREEN_HEIGHT) continue;
        volatile uint8_t *line = MARS_FB_BASE + (py * SCREEN_WIDTH);
        for (int dx = 0; dx < 10; dx++) {
            int px = sat_x + dx;
            if (px >= 0 && px < SCREEN_WIDTH) line[px] = 5;
        }
    }
}