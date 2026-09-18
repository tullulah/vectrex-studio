/* snd_ref.cpp — render what the arcade ACTUALLY sounds like, with the real chip.
 *
 * Drives MAME's ymfm YM3812 (OPL2) with the register writes captured by
 * snd_rip, at the board's 3 MHz, and writes the result as a WAV. Two uses:
 *
 *   1. A reference to listen to. "Does our PSG version resemble the arcade?"
 *      is otherwise unanswerable without a cabinet.
 *   2. The input to snd_conv's measurements. FM output cannot be deduced from
 *      the channel frequency alone — the operator MULT scales it (MULT=0 is
 *      HALF), and strong inharmonic modulation turns a "note" into a noise
 *      burst. Reading pitch and tonality off the rendered audio replaces a
 *      pile of guessed thresholds with a measurement.
 *
 * Usage: snd_ref <cmd.log> <out.wav|-> [seconds]
 *        "-" writes raw mono float32 to stdout (what the analyser reads).
 */
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <vector>
#include "ymfm_opl.h"

/* ymfm's interface has working defaults for everything we need: we drive the
 * chip from a log, so nothing here has to service timers or interrupts. */
class ref_intf : public ymfm::ymfm_interface { };

#define YM_CLOCK 3000000u          /* XTAL(12'000'000)/4, per MAME's driver */

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <cmd.log> <out.wav|-> [seconds]\n", argv[0]);
        return 1;
    }
    double limit = (argc > 3) ? atof(argv[3]) : 0.0;

    ref_intf intf;
    ymfm::ym3812 chip(intf);
    chip.reset();
    const uint32_t rate = chip.sample_rate(YM_CLOCK);     /* 41666 Hz */

    FILE *f = fopen(argv[1], "r");
    if (!f) { fprintf(stderr, "cannot read %s\n", argv[1]); return 1; }

    std::vector<int16_t> pcm;
    unsigned long long us_now = 0, us_first = 0;
    bool first = true;
    unsigned long long us_log;
    unsigned reg, val;

    /* The log is (microsecond, reg, val). Generate audio up to each write's
     * timestamp, then apply it — so the chip hears the same sequence, with the
     * same gaps, that it heard on the board. */
    while (fscanf(f, "%llu %x %x", &us_log, &reg, &val) == 3) {
        if (first) { us_first = us_log; us_now = us_log; first = false; }
        if (limit > 0 && (double)(us_log - us_first) / 1e6 > limit) break;
        unsigned long long want = (unsigned long long)((us_log - us_first) * (double)rate / 1e6);
        while (pcm.size() < want) {
            ymfm::ym3812::output_data out;
            chip.generate(&out, 1);
            pcm.push_back((int16_t)out.data[0]);
        }
        chip.write_address((uint8_t)reg);
        chip.write_data((uint8_t)val);
        us_now = us_log;
    }
    fclose(f);

    /* tail: let envelopes finish */
    double tail = (limit > 0) ? 0.2 : 0.5;
    for (unsigned i = 0; i < (unsigned)(rate * tail); i++) {
        ymfm::ym3812::output_data out;
        chip.generate(&out, 1);
        pcm.push_back((int16_t)out.data[0]);
    }

    if (!strcmp(argv[2], "-")) {
        /* raw stream for the analyser: rate first, then int16 samples */
        fwrite(&rate, 4, 1, stdout);
        fwrite(pcm.data(), 2, pcm.size(), stdout);
        return 0;
    }

    FILE *w = fopen(argv[2], "wb");
    if (!w) { fprintf(stderr, "cannot write %s\n", argv[2]); return 1; }
    uint32_t dlen = (uint32_t)(pcm.size() * 2), hdr = 36 + dlen;
    uint32_t brate = rate * 2;
    uint16_t one = 1, bits = 16, align = 2;
    fwrite("RIFF", 1, 4, w); fwrite(&hdr, 4, 1, w); fwrite("WAVEfmt ", 1, 8, w);
    uint32_t fmtlen = 16; fwrite(&fmtlen, 4, 1, w);
    fwrite(&one, 2, 1, w); fwrite(&one, 2, 1, w);
    fwrite(&rate, 4, 1, w); fwrite(&brate, 4, 1, w);
    fwrite(&align, 2, 1, w); fwrite(&bits, 2, 1, w);
    fwrite("data", 1, 4, w); fwrite(&dlen, 4, 1, w);
    fwrite(pcm.data(), 2, pcm.size(), w);
    fclose(w);
    fprintf(stderr, "%s: %.2f s at %u Hz\n", argv[2], (double)pcm.size() / rate, rate);
    return 0;
}
