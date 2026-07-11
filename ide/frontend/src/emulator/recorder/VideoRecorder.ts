/**
 * VideoRecorder — captures real pixels + audio from the running emulator and
 * packages them as a WebM blob (VP9/VP8 + Opus) via the browser's
 * MediaRecorder API.
 *
 * This is SEPARATE from VectorRecorder (.vrec): that captures the abstract
 * per-frame vector draw list for attract-mode playback; this captures the
 * actual rendered canvas + speaker audio so the user can upload gameplay to
 * YouTube etc. The WebM blob is handed to the Electron main process, which
 * transcodes it to H.264/AAC .mp4 with the bundled ffmpeg.
 *
 * Capture model:
 *   - Video: canvas.captureStream(fps) taps the live display canvas.
 *   - Audio: a MediaStreamAudioDestinationNode created on the emulator's own
 *     AudioContext; the emulator's existing output node is connected to it in
 *     PARALLEL (the path to ctx.destination / the speakers is never touched).
 *   - Both tracks are combined into a single MediaStream fed to MediaRecorder.
 *
 * Zero overhead when not recording: nothing is created until start().
 */

/** Preferred WebM mime types in descending order of quality/compatibility. */
const MIME_CANDIDATES = [
  'video/webm;codecs=vp9,opus',
  'video/webm;codecs=vp8,opus',
  'video/webm;codecs=vp9',
  'video/webm;codecs=vp8',
  'video/webm',
];

/** Pick the first mime type MediaRecorder actually supports (or '' for default). */
function pickMimeType(): string {
  if (typeof MediaRecorder === 'undefined') return '';
  for (const mime of MIME_CANDIDATES) {
    try {
      if (MediaRecorder.isTypeSupported(mime)) return mime;
    } catch { /* isTypeSupported may throw on odd inputs */ }
  }
  return '';
}

export class VideoRecorder {
  private recorder: MediaRecorder | null = null;
  private chunks: BlobPart[] = [];
  private stream: MediaStream | null = null;
  private videoTrack: MediaStreamTrack | null = null;
  /** Parallel audio sink on the emulator's AudioContext (null = video-only). */
  private audioDest: MediaStreamAudioDestinationNode | null = null;
  private audioSource: AudioNode | null = null;
  private tapGain: GainNode | null = null;
  private silentGain: GainNode | null = null;
  private analyser: AnalyserNode | null = null;
  private analyserBuf: Uint8Array | null = null;
  // Recorder-owned audio context: holds the recording's audio track from frame
  // 0 and receives the emulator's audio once it appears (cross-context bridge).
  private recCtx: AudioContext | null = null;
  private recDest: MediaStreamAudioDestinationNode | null = null;
  private getAudioCtx: (() => { ctx: AudioContext; outputs: AudioNode[] } | null) | null = null;
  private bridgeEmuCtx: AudioContext | null = null;
  private bridgeEmuDest: MediaStreamAudioDestinationNode | null = null;
  private bridgeSource: MediaStreamAudioSourceNode | null = null;
  private tappedNodes: Set<AudioNode> | null = null;
  private tapGains: Array<[AudioNode, GainNode]> | null = null;
  private startedAt = 0;
  private tickTimer: number | null = null;

  /** Chosen mime type after start() (for diagnostics / blob typing). */
  mimeType = '';
  /** True while a recording is in progress. */
  isRecording = false;
  /** True if audio was successfully tapped; false = video-only capture. */
  hasAudio = false;

  /** Fires ~10×/s with elapsed seconds so the UI can show a live timer. */
  onTick: ((elapsedSeconds: number) => void) | null = null;

  /**
   * Begin recording. Combines the canvas video track with the active target's
   * audio (if available). If audio can't be tapped the recording proceeds
   * video-only (hasAudio = false) rather than failing.
   *
   * @param canvas  The live emulator display canvas.
   * @param fps     Capture frame rate (emulator runs at 50/60 Hz).
   * @param audio   The active target's { ctx, outputNode }, or null.
   */
  start(
    canvas: HTMLCanvasElement,
    fps: number,
    getAudioCtx: () => { ctx: AudioContext; outputs: AudioNode[] } | null,
  ): void {
    if (this.isRecording) return;

    this.mimeType = pickMimeType();
    this.chunks = [];
    this.hasAudio = false;
    this.getAudioCtx = getAudioCtx;

    // Video track from the canvas.
    const videoStream = canvas.captureStream(fps);
    this.videoTrack = videoStream.getVideoTracks()[0] ?? null;
    const tracks: MediaStreamTrack[] = this.videoTrack ? [this.videoTrack] : [];

    // OWN audio context + a MediaStreamAudioDestinationNode. Its (initially
    // silent) track is added to the recording FROM FRAME 0, so the recording
    // always has an audio track even if the emulator's audio doesn't exist yet
    // (e.g. recording the intro from the start, before the game boots). The
    // emulator's audio is bridged into this track later, once it appears — see
    // tryBridgeAudio(). MediaRecorder can't add tracks after start, but the
    // track's CONTENT can change from silence to real audio.
    try {
      this.recCtx = new AudioContext();
      this.recDest = this.recCtx.createMediaStreamDestination();
      for (const t of this.recDest.stream.getAudioTracks()) tracks.push(t);
    } catch (e) {
      console.warn('[VideoRecorder] own AudioContext failed → video-only:', e);
      this.recCtx = null;
      this.recDest = null;
    }
    // Try to bridge immediately (in case audio is already running).
    this.tryBridgeAudio();

    this.stream = new MediaStream(tracks);
    try {
      this.recorder = this.mimeType
        ? new MediaRecorder(this.stream, { mimeType: this.mimeType })
        : new MediaRecorder(this.stream);
    } catch (e) {
      // Last-resort fallback: let the browser choose everything.
      console.warn('[VideoRecorder] MediaRecorder init failed, using default codec:', e);
      this.recorder = new MediaRecorder(this.stream);
      this.mimeType = this.recorder.mimeType || '';
    }

    this.recorder.ondataavailable = (ev: BlobEvent) => {
      if (ev.data && ev.data.size > 0) this.chunks.push(ev.data);
    };

    this.recorder.start(1000); // flush a chunk each second
    this.isRecording = true;
    this.startedAt = performance.now();

    this.tickTimer = window.setInterval(() => {
      this.onTick?.((performance.now() - this.startedAt) / 1000);
      // Keep bridging: picks up late-arriving audio nodes (e.g. a PLAY_SAMPLE
      // BufferSource) for the whole recording, not just once.
      this.tryBridgeAudio();
    }, 100);
  }

  /**
   * Bridge the emulator's audio into the recording's own track. Captures the
   * FULL mix reaching the speakers, not one node: on first run it builds the
   * cross-context path (emuCtx MediaStreamDestination → recCtx source → recDest),
   * then on EVERY call connects any output node not yet tapped. This catches
   * late-arriving sources — e.g. a PLAY_SAMPLE BufferSource that starts after
   * recording began — so audio isn't missed just because it appeared late.
   * Called repeatedly from the tick timer.
   */
  private tryBridgeAudio(): void {
    if (!this.recCtx || !this.recDest || !this.getAudioCtx) return;
    const info = this.getAudioCtx();
    if (!info || !info.ctx || info.outputs.length === 0) return;
    try {
      const ctx = info.ctx;
      // First time we see a running context: build the cross-context path.
      if (!this.bridgeEmuDest || this.bridgeEmuCtx !== ctx) {
        if (ctx.state !== 'running') ctx.resume().catch(() => {});
        const emuDest = ctx.createMediaStreamDestination();
        const src = this.recCtx.createMediaStreamSource(emuDest.stream);
        src.connect(this.recDest);
        this.bridgeEmuDest = emuDest;
        this.bridgeEmuCtx = ctx;
        this.bridgeSource = src;
        this.tappedNodes = new Set();
        this.tapGains = [];
      }
      // Connect every not-yet-tapped output node (via a unity gain — direct
      // ScriptProcessor→dest is unreliable in Chromium).
      for (const node of info.outputs) {
        if (this.tappedNodes!.has(node)) continue;
        const g = ctx.createGain();
        g.gain.value = 1;
        node.connect(g);
        g.connect(this.bridgeEmuDest);
        this.tappedNodes!.add(node);
        this.tapGains!.push([node, g]);
        this.hasAudio = true;
      }
    } catch (e) {
      console.warn('[VideoRecorder] audio bridge failed:', e);
    }
  }

  /** Elapsed recording time in seconds. */
  get elapsedSeconds(): number {
    return this.isRecording ? (performance.now() - this.startedAt) / 1000 : 0;
  }

  /**
   * Stop recording and resolve with the assembled WebM Blob. Tears down the
   * parallel audio tap and the canvas capture track — the speaker path is
   * untouched. Resolves with null if nothing was captured.
   */
  stop(): Promise<Blob | null> {
    return new Promise((resolve) => {
      const rec = this.recorder;
      if (!rec || !this.isRecording) {
        this.cleanup();
        resolve(null);
        return;
      }
      rec.onstop = () => {
        const blob = this.chunks.length
          ? new Blob(this.chunks, { type: this.mimeType || 'video/webm' })
          : null;
        this.cleanup();
        resolve(blob);
      };
      try {
        rec.stop();
      } catch (e) {
        console.warn('[VideoRecorder] stop() threw:', e);
        this.cleanup();
        resolve(this.chunks.length ? new Blob(this.chunks, { type: this.mimeType || 'video/webm' }) : null);
      }
      this.isRecording = false;
    });
  }

  /** Abort without producing a blob (e.g. component unmount). */
  discard(): void {
    try { if (this.recorder && this.isRecording) this.recorder.stop(); } catch { /* noop */ }
    this.chunks = [];
    this.isRecording = false;
    this.cleanup();
  }

  /** Detach the parallel audio sink and the canvas capture track. */
  private cleanup(): void {
    if (this.tickTimer !== null) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }
    // Disconnect ONLY our parallel taps, never the emulator→speakers path.
    if (this.tapGains) {
      for (const [node, g] of this.tapGains) {
        try { node.disconnect(g); } catch { /* gone */ }
        try { g.disconnect(); } catch { /* gone */ }
      }
    }
    try { this.bridgeSource?.disconnect(); } catch { /* gone */ }
    try { this.recCtx?.close(); } catch { /* gone */ }
    try { this.videoTrack?.stop(); } catch { /* noop */ }
    this.audioSource = null;
    this.audioDest = null;
    this.tapGain = null;
    this.analyser = null;
    this.silentGain = null;
    this.analyserBuf = null;
    this.recCtx = null;
    this.recDest = null;
    this.bridgeEmuCtx = null;
    this.bridgeEmuDest = null;
    this.bridgeSource = null;
    this.tappedNodes = null;
    this.tapGains = null;
    this.getAudioCtx = null;
    this.videoTrack = null;
    this.stream = null;
    this.recorder = null;
  }
}

/** Default suggested filename for a gameplay MP4 (timestamped). */
export function defaultVideoName(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `gameplay_${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}
