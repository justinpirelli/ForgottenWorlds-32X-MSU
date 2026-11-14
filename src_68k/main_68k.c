
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

// Genesis I/O Controller Ports (6-Button Support for Satellite Rotation)
#define GEN_IO_DATA1        (*(volatile uint8_t *)0xA10003)
#define GEN_IO_CTRL1        (*(volatile uint8_t *)0xA10009)
#define GEN_IO_DATA2        (*(volatile uint8_t *)0xA10005)
#define GEN_IO_CTRL2        (*(volatile uint8_t *)0xA1000B)

// ============================================================================
// External Functions from src_68k/msu_mode1.s (Sega CD Mode 1 Driver)
// ============================================================================
extern int  msu_init(void);
extern void msu_play_track(uint8_t track_num, uint8_t loop);
extern void msu_stop(void);

// ============================================================================
// Intercepted CPS-1 Sound Latch ($800180 on Arcade PCB)
// Maps CPS-1 BGM IDs to PC Engine CD Redbook Tracks via Sega CD Mode 1
// ============================================================================
void cps1_sound_write(uint8_t sound_cmd) {
    // 0x01 - 0x1F: Background Music (Route to Sega CD Mode 1)
    if (sound_cmd >= 0x01 && sound_cmd <= 0x1F) {
        // Track 01 is dummy data; PC Engine CD music starts at Track 02
        uint8_t cd_track = sound_cmd + 1;
        uint8_t loop_flag = 1;

        // Fanfare / Victory / Ending / Game Over tracks do not loop
        if (sound_cmd == 0x05 || sound_cmd == 0x0A || sound_cmd == 0x0B) {
            loop_flag = 0;
        }

        msu_play_track(cd_track, loop_flag);
    }
    // 0xF0: Stop / Fade Out Music
    else if (sound_cmd == 0xF0) {
        msu_stop();
    }
    // 0x20 - 0xEF: ADPCM Voice Clips & Sound Effects (Route to 32X PWM)
    else if (sound_cmd >= 0x20 && sound_cmd <= 0xEF) {
        MARS_COMM2 = 0x8000 | (uint16_t)sound_cmd;
    }
}

// ============================================================================
// Read Genesis 3-Button / 6-Button Controller (Maps X/Z to Satellite Rotation)
// ============================================================================
uint16_t read_genesis_pad(volatile uint8_t *data_port, volatile uint8_t *ctrl_port) {
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

    return ((uint16_t)extra << 8) | ((uint16_t)(lo & 0x30) << 2) | hi;
}

// ============================================================================
// Transcoded CPS-1 Arcade Main Loop Hook (Stub until CPS-1 ROM is linked)
// ============================================================================
static uint16_t demo_camera_x = 0;
static int8_t   demo_pan_dir  = 1;

void cps1_arcade_vblank_tick(void) {
    // Poll Player 1 & Player 2 controllers
    uint16_t p1_input = read_genesis_pad(&GEN_IO_DATA1, &GEN_IO_CTRL1);
    uint16_t p2_input = read_genesis_pad(&GEN_IO_DATA2, &GEN_IO_CTRL2);
    (void)p1_input;
    (void)p2_input;

    // Default test behavior: Smoothly pan 320px window across 384px field
    demo_camera_x += demo_pan_dir;
    if (demo_camera_x >= 64) demo_pan_dir = -1;
    if (demo_camera_x == 0)  demo_pan_dir = 1;

    MARS_COMM4 = demo_camera_x;
}

// ============================================================================
// Genesis 68000 Entry Point
// ============================================================================
int main(void) {
    // 1. Enable 32X hardware & release SH-2 CPUs
    MARS_SYS_ADEN = 0x0001;

    // 2. Detect Sega CD & initialize Mode 1 CD-DA audio driver
    int scd_ready = msu_init();
    if (scd_ready) {
        // Trigger Sound ID 0x01 -> Plays & loops Track 02 (Opening Theme)
        cps1_sound_write(0x01);
    }

    // 3. Tell Master SH-2 to initialize 256-color Packed Pixel VDP mode
    MARS_COMM0 = 0x0001;
    while (MARS_COMM0 != 0x0000) {
        // Wait for SH-2 VDP init handshake
    }

    // 4. Main 60Hz Frame Loop
    uint16_t frame_counter = 0;
    while (1) {
        // Run one frame of game logic
        cps1_arcade_vblank_tick();

        // Trigger Master -> Slave SH-2 frame render
        MARS_COMM0 = 0x0002;
        while (MARS_COMM0 != 0x0000) {
            // Wait for SH-2 CPUs to finish blitting tiles & sprites
        }

        frame_counter++;
        MARS_COMM6 = frame_counter;
    }

    return 0;
}
