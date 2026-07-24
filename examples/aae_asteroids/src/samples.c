/* Real sample playback for Asteroids (replaces AAE's stub samples.c). Routes the
 * AAE sample interface (asteroid.c calls sample_start on each sound port write)
 * to the SDK v_playSample path (sim: Web Audio mix; rp2350: silent for now). The
 * sample INDEX = position in gamesamp.h's asteroidsamples[] minus the ".zip"
 * entry, i.e. 0=fire, 2=thrust, 6/7=thump hi/lo — what asteroid.c passes.
 */
extern void v_playSample(int idx, int voice, int loop);
extern void v_stopSample(int voice);
extern int  v_samplePlaying(int voice);

void voice_init(int num) { (void)num; }

void sample_start(int channel, int samplenum, int loop) { v_playSample(samplenum, channel, loop); }

void sample_set_freq(int channel, int freq)     { (void)channel; (void)freq; }
void sample_set_volume(int channel, int volume) { (void)channel; (void)volume; }
void sample_adjust(int channel, int mode)       { (void)channel; (void)mode; }

void sample_stop(int channel) { v_stopSample(channel); }
void sample_end(int channel)  { v_stopSample(channel); }  /* stop the loop (thrust/roar) when the game ends it */

int  sample_playing(int channel) { return v_samplePlaying(channel); }

void free_samples(void)  {}
void mute_sound(void)    {}
void restore_sound(void) {}

void aae_play_streamed_sample(int channel, unsigned char *data, int len, int freq, int volume)
{ (void)channel; (void)data; (void)len; (void)freq; (void)volume; }
