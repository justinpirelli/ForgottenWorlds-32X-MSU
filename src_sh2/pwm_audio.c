#include "pwm_audio.h"

typedef struct {
    const int8_t *ptr;
    uint32_t      remaining;
    const int8_t *loop_start;
    uint32_t      loop_length;
    uint8_t       active;
    uint8_t       pan;
} PWM_Channel;

static PWM_Channel channels[PWM_NUM_CHANNELS];
static uint8_t next_voice = 0;

// ============================================================================
// Initialize 32X PWM Hardware (~22,050 Hz Stereo Output)
// ============================================================================
void pwm_audio_init(void) {
    for (int i = 0; i < PWM_NUM_CHANNELS; i++) {
        channels[i].active = 0;
        channels[i].remaining = 0;
    }

    // 23.011 MHz SH-2 Clock / 1044 cycles = ~22,041 Hz sample rate
    MARS_PWM_CYCLE = 1044;

    // Enable Left & Right PWM channels (LMD = 01, RMD = 01 -> 0x0005)
    MARS_PWM_CTRL = 0x0005;

    // Prime FIFO with center silence (522 = half of 1044 cycle)
    for (int i = 0; i < 3; i++) {
        MARS_PWM_MONO = 522;
    }
}

// ============================================================================
// Trigger an 8-bit PCM Voice Clip or Sound Effect on Next Available Channel
// ============================================================================
void pwm_play_sfx(uint8_t sfx_id, const PWM_SampleAsset *sample_table, uint16_t max_samples) {
    if (!sample_table || sfx_id >= max_samples) return;

    const PWM_SampleAsset *asset = &sample_table[sfx_id];
    if (!asset->data || asset->length == 0) return;

    // Pick a free channel first, otherwise steal oldest round-robin channel
    int chosen = -1;
    for (int i = 0; i < PWM_NUM_CHANNELS; i++) {
        if (!channels[i].active) {
            chosen = i;
            break;
        }
    }
    if (chosen < 0) {
        chosen = next_voice;
        next_voice = (next_voice + 1) & (PWM_NUM_CHANNELS - 1);
    }

    channels[chosen].ptr         = asset->data;
    channels[chosen].remaining   = asset->length;
    channels[chosen].loop_start  = asset->loop ? asset->data : 0;
    channels[chosen].loop_length = asset->loop ? asset->length : 0;
    channels[chosen].pan         = asset->pan;
    channels[chosen].active      = 1;
}

// ============================================================================
// Mix 1 Frame (367 Samples) of 4-Channel Audio into the 32X PWM Hardware FIFO
// ============================================================================
void pwm_mix_frame(void) {
    for (int s = 0; s < PWM_SAMPLES_PER_FRAME; s++) {
        // Wait if 32X PWM FIFO is full (Bit 15 of MARS_PWM_LCH/RCH = FIFO Full)
        while (MARS_PWM_LCH & 0x8000);

        int32_t mix_l = 0;
        int32_t mix_r = 0;

        for (int ch = 0; ch < PWM_NUM_CHANNELS; ch++) {
            if (!channels[ch].active) continue;

            int32_t sample = (int32_t)(*channels[ch].ptr++);
            channels[ch].remaining--;

            // Stereo Panning (0 = Center, 1 = Left, 2 = Right)
            if (channels[ch].pan == 1) {
                mix_l += sample << 1;
                mix_r += sample >> 1;
            } else if (channels[ch].pan == 2) {
                mix_l += sample >> 1;
                mix_r += sample << 1;
            } else {
                mix_l += sample;
                mix_r += sample;
            }

            // Handle End-of-Sample or Loop
            if (channels[ch].remaining == 0) {
                if (channels[ch].loop_start) {
                    channels[ch].ptr       = channels[ch].loop_start;
                    channels[ch].remaining = channels[ch].loop_length;
                } else {
                    channels[ch].active = 0;
                }
            }
        }

        // Convert signed mixed sample (-512..+511) to unsigned PWM duty (1..1043)
        int32_t pwm_l = 522 + mix_l;
        int32_t pwm_r = 522 + mix_r;

        if (pwm_l < 1) pwm_l = 1;
        if (pwm_l > 1043) pwm_l = 1043;
        if (pwm_r < 1) pwm_r = 1;
        if (pwm_r > 1043) pwm_r = 1043;

        MARS_PWM_LCH = (uint16_t)pwm_l;
        MARS_PWM_RCH = (uint16_t)pwm_r;
    }
}