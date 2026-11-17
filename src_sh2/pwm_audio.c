#include "pwm_audio.h"

// Fixed-point 16.16 step for 7,576 Hz OKI MSM6295 playback inside 22,041 Hz PWM
// (7576 / 22041) * 65536 = 22526 (0x000057FE)
#define OKI_RESAMPLE_STEP_FP 0x000057FEu

typedef struct {
    const int8_t *base;
    uint32_t      length;
    uint32_t      pos_fp;      // 16.16 fixed-point sample position
    uint8_t       loop;
    uint8_t       active;
    uint8_t       pan;
} PWM_Channel;

static PWM_Channel channels[PWM_NUM_CHANNELS];
static uint8_t next_voice = 0;

void pwm_audio_init(void) {
    for (int i = 0; i < PWM_NUM_CHANNELS; i++) {
        channels[i].active = 0;
        channels[i].pos_fp = 0;
    }

    MARS_PWM_CYCLE = 1044; // 23.011 MHz / 1044 = ~22,041 Hz
    MARS_PWM_CTRL  = 0x0005;

    for (int i = 0; i < 3; i++) {
        MARS_PWM_MONO = 522;
    }
}

void pwm_play_sfx(uint8_t sfx_id, const PWM_SampleAsset *sample_table, uint16_t max_samples) {
    if (!sample_table || sfx_id >= max_samples) return;

    const PWM_SampleAsset *asset = &sample_table[sfx_id];
    if (!asset->data || asset->length == 0) return;

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

    channels[chosen].base   = asset->data;
    channels[chosen].length = asset->length;
    channels[chosen].pos_fp = 0;
    channels[chosen].loop   = asset->loop;
    channels[chosen].pan    = asset->pan;
    channels[chosen].active = 1;
}
void pwm_mix_frame(void) {
    for (int s = 0; s < PWM_SAMPLES_PER_FRAME; s++) {
        while (MARS_PWM_LCH & 0x8000);

        int32_t mix_l = 0;
        int32_t mix_r = 0;

        for (int ch = 0; ch < PWM_NUM_CHANNELS; ch++) {
            if (!channels[ch].active) continue;

            uint32_t idx = channels[ch].pos_fp >> 16;
            if (idx >= channels[ch].length) {
                if (channels[ch].loop) {
                    channels[ch].pos_fp = 0;
                    idx = 0;
                } else {
                    channels[ch].active = 0;
                    continue;
                }
            }

            // 2x gain so 8-bit OKI voices cut clearly over Sega CD Redbook music
            int32_t sample = ((int32_t)channels[ch].base[idx]) << 1;
            channels[ch].pos_fp += OKI_RESAMPLE_STEP_FP;

            if (channels[ch].pan == 1) {
                mix_l += sample + (sample >> 1);
                mix_r += sample >> 1;
            } else if (channels[ch].pan == 2) {
                mix_l += sample >> 1;
                mix_r += sample + (sample >> 1);
            } else {
                mix_l += sample;
                mix_r += sample;
            }
        }

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
