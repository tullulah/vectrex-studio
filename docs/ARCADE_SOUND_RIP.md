# Arcade Sound on the PSG: ripping music out of a game ROM

Arcade boards that we port keep their sound on a **separate CPU with its own
sound chip** — Snow Bros has a Z80B driving a YM3812 (FM synthesis), TNZS has a
third Z80, the AAE boards have POKEYs and custom hardware. The Vectrex has none
of that: one AY-3-8912 PSG, three square-wave channels plus one noise
generator.

The music is nevertheless *in the ROM*, and it does not have to be recomposed.
The sound program's note tables, tempos and effect structure are all there; what
cannot cross over is the **timbre**. Running the real sound program and
recording what it writes to its sound chip gives an exact transcription, which
is then reduced to the PSG. The result is the arcade's own music played on
square waves — the same trade every 8-bit port of an FM arcade made.

This page documents the pipeline as implemented for Snow Bros
(`examples/snowbros_sbt`). It generalises to any board whose sound is **a
program writing registers on a sound chip** — which is most of them, but not
all. When the board synthesises its audio in analogue circuitry there are no
register writes to record, and the port takes the other route on this page:
[digitised samples](#the-other-route-digitised-samples-vsmp). Decide which one
applies before writing any tooling; the answer is in MAME's driver.

## The two stages

Both run **offline**, on the desktop, at build time. Nothing here ships to the
console; only the compiled PSG streams do.

### Stage 1 — rip: run the real sound program

`tools/snd_rip.c` (`make snd_rip`) emulates the sound section: the Z80 under
[mz80](#the-mz80-block-io-patch) with the board's ROM, plus enough of the sound
chip to keep the program running — its timers and status register, faithfully,
because the program is paced by the chip's timer interrupt. Voice registers are
not synthesised, only **logged**.

For each command byte the main CPU can send, it boots the machine clean, sends
the command, and runs until the sound goes quiet:

```
make snd_rip
./build/snd_rip build/sbros4.bin build/snd          # whole catalog
./build/snd_rip build/sbros4.bin build/snd 23 1f    # just these commands
```

Output is one `build/snd/cmd_XX.log` per sound, with `us reg val` lines, and a
one-line summary per command (duration, channels used, whether it loops).

Three things about the rip are not obvious and all three were needed to make it
work:

- **The latch must be cleared after the interrupt.** On the board the main CPU
  writes a command to a latch, which raises NMI on the sound CPU. If the latch
  keeps returning the command afterwards, a driver that also polls it retriggers
  the sound forever — every effect then looks like it loops.
- **"Still sounding" is a key-on question, not a write-traffic question.** The
  driver rewrites the *whole* chip state on every timer tick whether anything
  plays or not, so an effect's end has to be detected from the key-on bits
  (`B0-B8` bit 5 and the rhythm register on a YM3812), never from write volume.
- **Machine facts come from MAME, not from memory.** Clocks, the IO map, which
  interrupt line the latch and the chip's timer drive, and the timer period
  formulas are all checked against `src/mame/kaneko/snowbros.cpp` and ymfm.
  They are quoted in the tool's header with the file they came from.

### Stage 1b — reference: render the real chip

`tools/snd_ref.cpp` (`make snd_ref`) drives MAME's ymfm YM3812 with the same
log, at the board's 3 MHz, and writes a WAV. It answers "what does the arcade
actually sound like?", which is otherwise unanswerable without a cabinet — and
it is also where the SFX conversion gets its numbers.

### Stage 2 — convert: YM to PSG

`tools/snd_conv.py` emits `src/sb_snddata.h`, at **50 Hz** (the tick rate every
SDK sequencer runs at). Music and SFX take **different routes**, and the reason
matters:

**Music is read from the registers, per channel.** It is polyphonic and only
the per-channel view keeps three voices apart. Reading pitch straight off
fnum/block is correct *for this music* because of what the tracks do: every
melodic channel runs its modulator at MULT ×1 or ×2 with the carrier a small
integer multiple, so the FM sidebands land on multiples of the channel
frequency and the perceived fundamental **is** that frequency.

**SFX are measured from the rendered audio.** They are monophonic — one
channel, every time — so measuring is possible, and it is necessary, because
their operators are nothing like the music's. Per 20 ms frame: RMS → volume (at
2 dB per PSG step), autocorrelation → pitch and *tonality*, spectral centroid →
noise colour. A frame too inharmonic to have a pitch becomes **noise**, because
that is what an FM zap is.

> Computing SFX pitch from fnum instead produced a flat 3.7 kHz squeal for the
> shot — which is exactly what it sounded like. The carrier's MULT scales the
> frequency (**MULT=0 means ×0.5**, not ×1), and with feedback 4 against a
> MULT ×6 modulator the spectrum is dense and inharmonic, so no MULT arithmetic
> predicts the result either. Measured, the shot is a 2.8 kHz → 540 Hz sweep
> and the jump rises 500 → 1440 Hz. Both were flat notes before, an octave or
> more too high.

The reduction, for the music path:

| YM3812 | PSG |
|--------|-----|
| `fnum`/`block` of a channel | tone period (`93750 / Hz`, PSG at 1.5 MHz) |
| carrier Total Level (0-63 attenuation) | volume `15 - TL/4` |
| up to 9 melodic channels | 3 voices, most-used channel first, then steal-the-released |
| rhythm register key-ons | short noise burst on voice C |

Two size measures, both worth knowing because music is the expensive asset:

- The **noise period is sticky** — left at whatever the last drum set instead of
  reset between hits. A muted voice's period is unobservable, and rewriting it
  was 626 of 5947 writes in the level theme.
- **Volume changes of one step are dropped** (reaching or leaving silence never
  is). Diffs are taken against the last value actually *emitted*, never against
  the previous frame: a register that creeps one step per frame — which is what
  an FM envelope decay becomes after conversion — would otherwise trip the
  deadband every frame and never be written at all.

Loop detection is **tolerant, not verbatim**: the driver's timer tick is not a
multiple of the 20 ms sampling frame, so each pass places a few notes a frame
early or late. 93% frame-equality over a 4 s window finds the real period
(58.7 s for the Snow Bros level theme); an exact match finds nothing and ships
the whole unrolled recording.

## The stream format

Stage 2 emits exactly what the SDK sequencers already play, so there is no new
player anywhere:

```
MUSIC: [u32 num_events][u32 loop event byte offset][events at +8]
SFX:   [u32 num_events][events at +4]
event: [delay, num_writes, (reg,val) * num_writes]
       num_writes == 0xFF -> loop (music only), == 0x00 -> end
```

Two things about the delay byte, both of which cost real musical damage when
got wrong:

**It is the wait BEFORE its own event fires**, not after. Firing an event
advances the pointer past its writes and reads the delay from *there* — i.e.
from the next event — so each delay is consumed on approach to the event that
carries it, and event 0's own delay byte is never read. Writing the gap as the
current event's delay instead shifts the whole timeline by one event.

**A delay byte of N produces a gap of N+1 frames, so the byte is gap−1.**
Firing sets `delay = N` and returns; the next N ticks each decrement and
return; the tick after that fires. Encoding the gap itself stretches every gap
by a frame — on the level theme, whose average gap is 2.3 frames, that played
the track **40% slow** (300 ms between note onsets where the arcade has 200).
It still sounded like the tune, which is exactly why it is worth measuring
rather than trusting.

## Playing it: the SDK contract

Three calls, same names on every target:

```c
void v_playMusic(const unsigned char *vmus);
void v_stopMusic(void);
void v_playSFX(const unsigned char *vsfx);
```

| Target | Who sequences |
|--------|---------------|
| RP2350 cartridge | BIOS, on core 1 — clocked by real time, so tempo survives a heavy draw frame (`svc #21/#22/#23`) |
| UVM2 (`.um2`) | BIOS `uvm2_audio.c`, ticked once per frame from `SYS_WAIT_RECAL` |
| IDE simulator (F5) | `pitrex-sim/sdk_host.c`, ticked from `v_WaitRecal` |
| IDE RP2350 emulator (Shift+F5) | `Rp2350System.ts`, its own sequencer behind the same `svc` numbers |
| VPy programs | libvpy (`vpy-c/vpy.c`), reached as `PLAY_MUSIC` / `PLAY_SFX` |
| Host harness | silent by design — the harness must stay deterministic |

### Who owns which channel

**Music gets voices A and B plus the noise generator; effects get voice C.**
This is not a style preference, it is what the sequencers implement: an effect
merges only the channel-C mixer bits and mutes register 10 when it ends, so a
track that puts a voice on C loses it to the next gunshot and does not get it
back. The converter enforces it on the *writes*, not merely on the mixer bits —
a music stream setting C's volume to zero silences an effect just as
effectively as claiming it — and `snd_check.py` with no arguments verifies
every stream.

Percussion therefore borrows voice B: routing noise to a channel makes it share
that channel's volume register, so the drum and B's note sound together for the
two frames of a hit. That is how AY ports have always done it.

Register 6 — the noise period — is unavoidably shared: the PSG has **one** noise
generator. An effect that uses noise retunes the music's drums for its duration.

**The merge runs both ways.** An effect keeps the music's A/B bits *and* a music
mixer write keeps the effect's C bits. Only the first half used to be true, and
the consequence was sharp: a track with noise percussion writes register 7 on
every drum hit, which took channel C straight back from a running effect. The
effect fell silent a couple of frames in and stayed that way until its own next
mixer write, which a diff-encoded stream may never make — effects seemed to be
"cut off by the music". Fixed in `uvm2_audio.c`, `vpy-c/vpy.c` and
`pitrex-sim/sdk_host.c`; the IDE's RP2350 emulator already did it.

> The RP2350 **cartridge BIOS lives in a separate repository** and has not had
> this fix applied. Until it does, effects on that target can still be clipped
> by a percussive track.

### Tempo must not follow the frame rate

The assets are compiled at 50 Hz. A game that does not reach 50 fps — every
arcade port here runs at 30-47 — would play its music at that fraction of its
tempo if the sequencer were ticked once per drawn frame. All three paths avoid
it, by different means:

- our cartridge sequences on **core 1**, independent of core-0 draw load;
- UVM2 counts **elapsed Vectrex bus cycles** (`uvm2_svc.c` / `uvm2_core1.c`) —
  a draw-heavy game played at half speed before this;
- the simulator ticks on **elapsed milliseconds**, with a 200 ms cap so a stall
  cannot fast-forward the track.

## Wiring a port

The board's sound latch **is** the trigger — the game's own code decides what
plays and when, so there is no per-event guesswork:

1. Call an audio dispatcher from the latch write in the machine model
   (`sb_hw.c`, address `0x300001` for Snow Bros).
2. The dispatcher (`sb_audio.c`) maps a command byte to a stream and calls
   `v_playMusic` / `v_playSFX` / `v_stopMusic`. Unmapped commands are ignored:
   most of the 256 do nothing on the board either, and an unmapped sound must
   not silence the mapped ones.

To find out which command means what, trace them in play:

```
make host
SB_TRACE_SND=1 AUTOCOIN=300 AUTOPLAY=1 ./build/host_sb 2>/dev/null | grep ^SND
```

## The other route: digitised samples (`.vsmp`)

Some boards have no sound chip to record. Tac/Scan is the case that forced this:
MAME drives it with `SEGAUSB` (`sega/segausb.cpp`), the Sega Universal Sound
Board — an i8035 **whose program is not even in the romset** (the game uploads it
into shared RAM at `$D000`) driving an **analogue netlist** (`nl_segausb.cpp`):
three DAC channels, PITs and filters. There is no register stream, so stage 1 has
nothing to log. The same holds for Star Trek and the rest of the USB family.

What those ports do have is a set of digitised `.wav` files — AAE's own samples,
which the IDE simulator already plays through Web Audio. Getting them onto the
console means playing PCM, and the Vectrex has exactly one way to do that:
**abuse a PSG volume register as a 4-bit DAC** (tone and noise off on that
channel, then write amplitudes at the sample rate). That is the `.vsmp` format —
`.word rate`, `.word num_samples`, 4-bit packed, low nibble = even sample.

### The hard part is the bus, not the DAC

A PSG write needs the Vectrex bus, and the bus belongs to the beam: during a ramp
Port A **is** the X integrator's rate, so writing it deforms the stroke. Samples
therefore cannot be written from outside the frame — they have to be **injected
into the draw list**, at the points where the beam is already parked.

Those points exist and are regular. A lit stroke is a chain of 32-bus-cycle
micro-segments (`tools/uvm2_anatomia.c` decodes a real list):

```
T1CL = 8      wait 0
T1CH = 0      wait 11    <- the ramp runs here: T1 counts 8, there are 11
PORT_A = 159  wait 3     <- already stopped: next segment's Y rate
PORT_B = 0    wait 9     <- mux: sample Y
PORT_B = 1    wait 0
PORT_A = 97   wait 3     <- next segment's X rate
```

Immediately before each `T1CL` the timer has expired, PB7 is high and the
integrators are frozen. A sample costs four commands there — data, BDIR up, BDIR
down, and **restoring Port A** to the rate the coming ramp needs — against the 187
bus cycles that separate two samples at 8 kHz. The player is
`ide/electron/resources/uvmc2-sdk/uvm2-sdk/uvm2_smp.{c,h}`; the emitter is `smp_inyecta` in
`uvm2_draw.c`.

Two consequences worth knowing before using this:

- **The clock is the bus, not the wall.** A list is built one frame before it is
  replayed, so a timestamp taken while emitting says nothing about when the sample
  will sound. The voice cursor advances by *elapsed bus cycles*, which makes the
  pitch exact even though the opportunities fall unevenly (measured: 196 cycles
  where 187 were asked, and a pitch error of +0.01%).
- **A game with samples runs at free refresh.** With a fixed rate, the frame's
  leftover goes to `ritmo_vecfever`'s zero-reference alternation — where the ramp
  is deliberately open and Port A is the discharge current, so nothing can be
  injected — and the audio only covers the drawn part of the frame. Measured with
  `tools/uvm2_smp_test.c`:

  | scene | refresh | frame covered |
  |---|---|---|
  | 40 strokes | 50 Hz | 5% |
  | 127 strokes | 50 Hz | 14% |
  | 300 strokes | 50 Hz | 38% |
  | 127 strokes | free | **91%** |
  | 300 strokes | free | **91%** |

  The cart BIOS already compiles free-running (`build.rs`: `UVM2_HZ=0`); a `.um2`
  asks for it with `make uvm2 UVM2_HZ=0`.

### The samples do not go in the image

This is the part that cost a hardware trip, so it is worth stating plainly: on the
UVM2 the sample data **ships on the SD card, not linked into the `.um2`**.

A `.um2` runs entirely from SRAM and the multicart's loader reserves the low part —
the SDK puts the line at `0x20060000` (`memmap_psram.ld`). Measured: `dkong`, which
works, ends at `0x200605C8`, i.e. right on it. Linking Tac/Scan's 121 KB of samples
pushed the image to `0x20077BAC` and the console came up with a **solid red LED** —
`isr_hardfault`, not a hang. Lowering the sample rate does not rescue it either: the
budget below the line is about 26 KB, which would be 1.3 kHz.

So they travel the way these same games' romset already travels: a bundle read off
the card into PSRAM at startup.

```
"VSMB"          4 bytes
u32 n           how many sounds
u32 offset[n]   byte offset of each .vsmp in the file; 0 = absent
...the .vsmp blobs, 4-byte aligned...
```

### Wiring a port

1. `make snd` — `tools/wav_to_vsmp.py` turns the `.wav` set into that bundle,
   indexed the way the game's own code indexes sounds. It imports the quantiser
   from `tools/audio2vsmp/audio2vsmp.py` rather than re-implementing the format.
   Copy the result next to the `.um2` on the card.
2. Call `uvm2_smp_bundle_load("<name>.vsm")` once at startup and return
   `uvm2_smp_bundle_entry(idx)` from `v_sampleData(int idx)` — both in the game
   (see `aae_tacscan/src/ts_audio.c`). The SDK declares `v_sampleData` weak and
   returning NULL, so a port with no samples needs no change and stays silent.
3. Nothing else: `v_playSample` / `v_stopSample` / `v_samplePlaying` in
   `sdk_rp2350.c` already route to the player — directly inside a `.um2`, and
   through the BIOS function table (version ≥ 2) on the Vectrex Studio cart.

**The cartridge is a different case and is not done.** There the game runs on core 1
while core 0 drives the bus, and the BIOS is explicit that an SD read from the other
core returns garbage — so the game cannot load the bundle itself. That image has 8 MB
of PSRAM and no size problem; the missing piece is having the BIOS preload the bundle
in `SYS_LAUNCH`, next to the `load_rom` it already does for the romset.

## Verifying without a console

`tools/snd_check.py` is a line-by-line port of the SDK sequencer, so what it
reports is what the hardware would do — including a stream that runs off its
end, a bad register number or a loop offset past the end of the data, each of
which it raises instead of playing.

```
snd_check.py                          every stream: bytes, duration, note count
snd_check.py LEVEL                    its notes, as frame / pitch / volume
snd_check.py SHOT --vs 1f             OUR pitch track beside the REAL chip's,
                                      frame by frame — the check to run after
                                      touching the converter. Timbre cannot
                                      match (three square waves are not nine FM
                                      operators) but pitch and envelope must,
                                      and when they do not it is a converter
                                      bug, not a limit of the hardware
snd_check.py LEVEL --wav level.wav    render to audio (square waves + noise)
snd_check.py --session snd.log --wav session.wav
                                      mix a whole gameplay session from a
                                      SB_TRACE_SND log: the streams the
                                      cartridge would play, at the frames the
                                      game asked for them
```

The session mode is the end-to-end check of the whole chain — main CPU, latch,
command, stream, PSG — and it rescales the log's machine frames (57.5 Hz on this
board) to the sequencer's 50 Hz ticks, or the session runs 15% fast.

### Samples

Two different questions, two different tools, and confusing them wastes a day:

- **How will it sound?** `make snd SND_ARGS="--preview build/snd"` writes a
  `.wav` per sound reconstructed from the packed 4-bit data, at the rate that
  will ship. That is the honest preview of the quantisation.
- **Will it play at all, and when?** `tools/uvm2_smp_test.c` builds real
  command lists on the desktop and checks the injection over the packed bytes:
  that every sample lands just before a `T1CL`, that Port A is restored, what
  fraction of the frame is covered, and that a sample of known length takes
  exactly `n × 1.5 MHz / rate` bus cycles — the pitch check, which is the one
  thing that can be wrong without anything looking wrong.

  ```
  cc -O2 -DUVM2_HOST -DUVM2_BANCO_SIN_NUCLEO1 -DUVM2_SUBUNIDAD \
     -DUVM2_ZERO_SETTLE_E=40 -DUVM2_DAC_CERO=0 -DUVM2_DRAW_SCALE=127 \
     -DUVM2_T1_TRANSPORT=110 -DUVM2_BLANK_SETTLE_E=10 -I. -o /tmp/smp \
     tools/uvm2_smp_test.c uvm2_draw.c uvm2_smp.c \
     ../vectrex-draw/cabi/target/release/libvectrex_draw_cabi.a
  ```

In the IDE, **Shift+F5** (Emulate RP2350) plays the voices through Web Audio, so
it tells you *what* plays and *when* — the game logic — but not how it will
sound: on hardware the same samples are 4 bits through the PSG. On-console the
counter to read is `uvm2_stats.samples`, the samples injected in the last frame.
With a voice playing it should be about `frame_cycles / 187`; a zero there means
the list had no gaps to inject into, which is a different fault from a player
that never started.

## The mz80 block I/O patch

`tools/mz80/` is a **local, patched** copy of the mz80 Z80 core. All 8 block
I/O instructions (`INI`/`IND`/`OUTI`/`OUTD` and the repeating
`INIR`/`INDR`/`OTIR`/`OTDR`) built their flags from the transferred data byte
and never set ZERO when `B` reached 0, where a real Z80 sets Z from the
decremented `B`. Snow Bros' sound program ends its register loop with
`OUTI / JR NZ,loop`, which under the bug never exits and sprays all 256
registers with whatever follows in memory. Each fixed site is tagged
`block I/O: Z tracks B==0`; `LDIR`/`LDDR` are deliberately untouched, since
those really do not set Z.

Second, non-bug behaviour of the same core: block I/O matches the port handler
table against the **full 16-bit BC**, so with `B` as a loop counter the port
appears as e.g. `0x1603`. Handler ranges must cover `0x0000-0xffff` and decode
`port & 0xff` themselves, like the board does.

**The other copies in the tree are unpatched** (`tnzs_sbt/src/mz80/`,
`aae-src/mz80/`, `aae-src/z80/`). If a TNZS or SegaG80 port misbehaves around
block I/O, this patch is the first thing to port across.

## Snow Bros command catalog

Found by ripping the whole range; confirmed against what the game sends in play.

| Commands | What |
|----------|------|
| `01` | coin (629 ms) |
| `02` | attract (935 ms) |
| `03`-`05`, `07`-`0d`, `10`-`13`, `1b`-`1d`, `1f` | effects, 17 ms - 1.4 s (`1f` shot, `1c` jump, `09`/`0c`/`0d` hits) |
| `20` | start (640 ms) |
| `21` | stage clear (3.1 s) |
| `22`-`2d` | 12 looping tracks (`23` = the in-game level theme) |
| `2e` | death (3.2 s) |
| `2f` | 50 s, does not loop |
| `fe` | stop everything |
| `06`, `0e`, `0f`, `14`-`1a`, `1e`, `30`-`3f`, `f0`-`ff` | no-ops on the board too |

All 23 effects are compiled in — together they are 2.6 KB, so there is no
reason to guess which ones a game reaches. **Music is not**: a 58-second track
is ~13 KB and the twelve of them are 254 KB, more than the 68000 program
itself. Only the tracks the port actually reaches are compiled in; the rest are
one converter run away in `build/snd`.
