/* sb_audio.c — the arcade's sound commands, played on the Vectrex PSG.
 *
 * On the board the 68000 writes a one-byte command to a latch at 0x300001 and
 * a Z80 + YM3812 plays the corresponding tune or effect. We do not have that
 * chip, but the MUSIC is in the ROM: tools/snd_rip.c runs the real sound
 * program and logs its YM register writes, tools/snd_conv.py reduces them to
 * PSG event streams, and src/sb_snddata.h is the result. So this is Snow Bros'
 * own music and its own effects, played on three square waves instead of nine
 * FM operators — the same trade every 8-bit port of an FM arcade made.
 *
 * sb_hw.c calls sb_audio_cmd() from the latch write, so the game's own logic
 * decides what plays and when; there is no per-event guesswork here.
 *
 * Commands not in the table are silently ignored: most of the 256 do nothing
 * on the board either (the ripper found 17 effects, 12 tracks and a stop out
 * of the whole range), and a sound we have not mapped yet must not stop the
 * ones we have.
 */
#include "sb_snddata.h"

/* The SDK contract, same three calls on every target: the cartridges reach the
 * BIOS sequencer by svc, the sim runs the software one in sdk_host.c. */
void v_playMusic(const unsigned char *vmus);
void v_stopMusic(void);
void v_playSFX(const unsigned char *vsfx);

#define SB_CMD_STOP 0xfe        /* the board's silence-everything command */

int sb_audio_music;             /* the track currently handed to the player */

void sb_audio_cmd(unsigned char cmd)
{
    unsigned i;

    if (cmd == SB_CMD_STOP) {
        v_stopMusic();
        sb_audio_music = 0;
        return;
    }

    for (i = 0; i < sizeof sb_snd_table / sizeof sb_snd_table[0]; i++) {
        if (sb_snd_table[i].cmd != cmd) continue;
        if (sb_snd_table[i].is_music) {
            v_playMusic(sb_snd_table[i].data);
            sb_audio_music = cmd;
        } else {
            v_playSFX(sb_snd_table[i].data);
        }
        return;
    }
}
