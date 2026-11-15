#ifndef PWM_AUDIO_H
#define PWM_AUDIO_H

#include <stdint.h>

// 32X PWM Hardware Registers (SH-2 Cache-Through Space)
#define MARS_PWM_CTRL       (*(volatile uint16_t *)0x20004030) // PWM Control & Sample Rate
#define MARS_PWM_CYCLE      (*(volatile uint16_t *)0x20004032) // PWM Cycle Register (Clock Divider)
#define MARS_PWM_LCH        (*(volatile uint16_t *)0x20004034) // Left Channel Pulse Width
#define MARS_PWM_RCH        (*(volatile uint16_t *)0x20004036) // Right Channel Pulse Width
#define MARS_PWM_MONO       (*(volatile uint16_t *)0x20004038) // Mono Pulse Width (Both Channels)

// 4-Channel Mixer (Matches Capcom CPS-1 OKI MSM6295 4-Voice Architecture)
#define PWM_NUM_CHANNELS    4
#define PWM_SAMPLE_RATE     22050
#define PWM_SAMPLES_PER_FRAME (PWM_SAMPLE_RATE / 60) // 367 samples per 60Hz V-Blank

// Sample Descriptor in Cartridge ROM
typedef struct {
    const int8_t *data;     // Pointer to 8-bit signed PCM waveform in ROM
    uint32_t      length;   // Sample length in bytes
    uint8_t       loop;     // 1 = Loop continuously, 0 = Play once
    uint8_t       pan;      // 0 = Center, 1 = Left, 2 = Right
} PWM_SampleAsset;

// Functions
void pwm_audio_init(void);
void pwm_play_sfx(uint8_t sfx_id, const PWM_SampleAsset *sample_table, uint16_t max_samples);
void pwm_mix_frame(void);

#endif // PWM_AUDIO_H