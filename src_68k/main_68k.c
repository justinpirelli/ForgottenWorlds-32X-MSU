#include <stdint.h>

// ============================================================================
// 32X System & Communication Registers (Genesis 68000 Side)
// ============================================================================
#define MARS_SYS_ADEN       (*(volatile uint16_t *)0xA15100) // 32X Adapter Enable
#define MARS_SYS_INTMASK    (*(volatile uint16_t *)0xA15102) // SH-2 Interrupt Mask
#define MARS_COMM0          (*(volatile uint16_t *)0xA15120) // Render Command Mailbox
#define MARS_COMM2          (*(volatile uint16_t *)0xA15122) // SFX / Voice ID Mailbox
#define MARS_COMM4          (*(volatile uint16_t *)0xA15124) // Camera X Pan (0 - 64)
#define MARS_COMM6          (*(volatile uint16_t *)0xA15126) // Frame Counter / Sync

// Genesis VDP & Z80 Bus Control Registers
#define VDP_CTRL            (*(volatile uint16_t *)0xC00004)
#define Z80_BUSREQ          (*(volatile uint16_t *)0xA11100)
#define Z80_RESET           (*(volatile uint16_t *)0xA11200)

// Genesis I/O Controller Ports (6-Button Support for Satellite Rotation)
#define GEN_IO_DATA1        (*(volatile uint8_t *)0xA10003)
#define GEN_IO_CTRL1        (*(volatile uint8_t *)0xA10009)
#define GEN_IO_DATA2        (*(volatile uint8_t *)0xA10005)
#define GEN_IO_CTRL2        (*(volatile uint8_t *)0xA1000B)

// Relocated CPS-1 Vector Table Base (0x020000 in 32X ROM)
#define CPS1_ROM_BASE       0x00020000
#define CPS1_RESET_VEC      (*(volatile uint32_t *)(CPS1_ROM_BASE + 0x04))
#define CPS1_VBLANK_VEC     (*(volatile uint32_t *)(CPS1_ROM_BASE + 0x78))

// ============================================================================
// External Assembly Drivers (msu_mode1.s & cps1_bridge.s)
// ============================================================================
extern int  msu_init(void);
extern void msu_play_track(uint8_t track_num, uint8_t loop);
extern void msu_stop(void);

extern void cps1_bridge_init(void);
extern void cps1_bridge_flush_vram(void);

// ============================================================================
// Intercepted CPS-1 Sound Latch ($800180 on Arcade PCB)
// Maps CPS-1 BGM IDs 0x01..0x0B -> CD Tracks 02..12 via Sega CD Mode 1
// ============================================================================
void cps1_sound_write(uint8_t sound_cmd) {
    if (sound_cmd >= 0x01 && sound_cmd <= 0x0B) {
        uint8_t cd_track = sound_cmd + 1;
        uint8_t loop_flag = 1;
        if (sound_cmd == 0x05 || sound_cmd == 0x0A || sound_cmd == 0x0B) {
            loop_flag = 0;
        }
        msu_play_track(cd_track, loop_flag);
    } else if (sound_cmd == 0xF0) {
        msu_stop();
    } else if (sound_cmd >= 0x20 && sound_cmd <= 0xEF) {
        MARS_COMM2 = 0x8000 | (uint16_t)sound_cmd;
    }
}

// ============================================================================
// Read Genesis 3-Button / 6-Button Controller (Z80 Bus-Safe)
// ============================================================================
uint16_t read_genesis_pad(volatile uint8_t *data_port, volatile uint8_t *ctrl_port) {
    Z80_BUSREQ = 0x0100;
    while (Z80_BUSREQ & 0x0100);

    *ctrl_port = 0x40;
    *data_port = 0x40;
    __asm__ volatile ("nop\nnop");
    uint8_t hi = *data_port & 0x3F; // Up, Down, Left, Right, B, C

    *data_port = 0x00;
    __asm__ volatile ("nop\nnop");
    uint8_t lo = *data_port & 0x3F; // Start, A

    // Pulse TH line to read X, Y, Z, Mode on 6-button controllers
    *data_port = 0x40;
    __asm__ volatile ("nop\nnop");
    *data_port = 0x00;
    __asm__ volatile ("nop\nnop");
    *data_port = 0x40;
    __asm__ volatile ("nop\nnop");
    uint8_t extra = *data_port & 0x0F; // Z, Y, X, Mode

    *data_port = 0x40;
    Z80_BUSREQ = 0x0000;

    return ((uint16_t)extra << 8) | ((uint16_t)(lo & 0x30) << 2) | hi;
}

// ============================================================================
// 60Hz V-Blank Sync & Hardware Frame Tick
// ============================================================================
static volatile uint16_t frame_counter = 0;
static uint16_t demo_camera_x = 0;
static int8_t   demo_pan_dir  = 1;

static void wait_genesis_vblank(void) {
    while (VDP_CTRL & 0x0008);    // Wait until active scan finishes
    while (!(VDP_CTRL & 0x0008)); // Wait for V-Blank start
}

// Called by Level 6 V-Blank IRQ (boot_32x.s) during CPS-1 Arcade Execution
void cps1_vblank_handler(void) {
#ifdef USE_CPS1_ARCADE_ROM
    // 1. Stream staged Palette & Object RAM ($FF8000-$FFBFFF) to SH-2 via 32X FIFO
    cps1_bridge_flush_vram();

    // 2. Kick off Master -> Slave SH-2 frame render
    MARS_COMM0 = 0x0002;

    // 3. Invoke relocated CPS-1 60Hz V-Blank game logic (Vector 30)
    uint32_t cps1_vblank_addr = CPS1_VBLANK_VEC;
    if (cps1_vblank_addr >= CPS1_ROM_BASE && cps1_vblank_addr < 0x00120000) {
        ((void (*)(void))cps1_vblank_addr)();
    }

    frame_counter++;
    MARS_COMM6 = frame_counter;
#endif
}

// ============================================================================
// Genesis 68000 Entry Point
// ============================================================================
int main(void) {
    // 1. Enable 32X hardware & release SH-2 CPUs
    MARS_SYS_ADEN = 0x0001;

    // 2. Initialize Genesis VDP (Enable Display + Level 6 V-Blank Interrupts)
    VDP_CTRL = 0x8004; // Reg 0: Mode 1
    VDP_CTRL = 0x8164; // Reg 1: Display Enable + V-Blank IRQ Enable (0x20)

    // 3. Detect Sega CD & initialize Mode 1 CD-DA audio driver
    int scd_ready = msu_init();
    if (scd_ready) {
        cps1_sound_write(0x01); // Play & loop Track 02 (Opening Theme)
    }

    // 4. Tell Master SH-2 to initialize 256-color Packed Pixel VDP mode
    MARS_COMM0 = 0x0001;
    while (MARS_COMM0 != 0x0000);

#ifdef USE_CPS1_ARCADE_ROM
    // 5A. Initialize CPS-1 Bridge, Enable IRQs & Jump to Patched Arcade ROM
    cps1_bridge_init();
    __asm__ volatile ("move.w #0x2000, %sr"); // Enable Level 6 V-Blank Interrupts

    uint32_t cps1_entry = CPS1_RESET_VEC;
    if (cps1_entry >= CPS1_ROM_BASE && cps1_entry < 0x00120000) {
        ((void (*)(void))cps1_entry)();
    }
    while (1);
#else
    // 5B. Hardware Test Pattern Mode (60Hz V-Blank Locked)
    while (1) {
        wait_genesis_vblank();

        demo_camera_x += demo_pan_dir;
        if (demo_camera_x >= 64) demo_pan_dir = -1;
        if (demo_camera_x == 0)  demo_pan_dir = 1;
        MARS_COMM4 = demo_camera_x;

        MARS_COMM0 = 0x0002;
        while (MARS_COMM0 != 0x0000);

        frame_counter++;
        MARS_COMM6 = frame_counter;
    }
#endif

    return 0;
}
