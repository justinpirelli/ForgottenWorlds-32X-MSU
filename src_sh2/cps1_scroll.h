#ifndef CPS1_SCROLL_H
#define CPS1_SCROLL_H

#include <stdint.h>
#include "cps1_blitter.h"

// CPS-1 Tilemap Dimensions (All 3 CPS-1 Scroll planes are 64x64 tiles)
#define CPS1_MAP_TILES      64
#define CPS1_MAP_MASK       63

// CPS-1 Tilemap Entry (Matches 32-bit CPS-1 VRAM Tile Word Format)
typedef struct {
    uint16_t tile_id;       // Tile index in linear GFX ROM
    uint8_t  palette_bank;  // Palette bank (0 - 15)
    uint8_t  flip_flags;    // Bit 0: Flip X, Bit 1: Flip Y
} CPS1_TileEntry;

// CPS-1 Scroll Layer State
typedef struct {
    const uint8_t        *gfx_rom;      // Pointer to linear 8-bit tile graphics
    const CPS1_TileEntry *tilemap;      // Pointer to 64x64 tilemap array (4096 entries)
    int16_t               scroll_x;     // Layer X scroll offset in pixels
    int16_t               scroll_y;     // Layer Y scroll offset in pixels
    const int16_t        *row_scroll;   // Optional per-scanline X offset table (224 entries, NULL if unused)
} CPS1_ScrollLayer;

// Layer Renderers
void cps1_render_scroll1_8x8(const CPS1_ScrollLayer *layer, int16_t camera_x);
void cps1_render_scroll2_16x16(const CPS1_ScrollLayer *layer, int16_t camera_x);
void cps1_render_scroll3_32x32(const CPS1_ScrollLayer *layer, int16_t camera_x);

// Built-In Hardware Verification Test Pattern (Runs when no CPS-1 ROM is linked yet)
void cps1_render_hardware_test_screen(uint16_t frame_num, int16_t camera_x);

#endif // CPS1_SCROLL_H