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
    audio: { ctx: AudioContext; outputNode: AudioNode } | null,
  ): void {
    if (this.isRecording) return;

    this.mimeType = pickMimeType();
    this.chunks = [];
    this.hasAudio = false;

    // Video track from the canvas.
    const videoStream = canvas.captureStream(fps);
    this.videoTrack = videoStream.getVideoTracks()[0] ?? null;
    const tracks: MediaStreamTrack[] = this.videoTrack ? [this.videoTrack] : [];

    // Parallel audio tap — connect the emulator's output ALSO to a
    // MediaStreamAudioDestinationNode. The existing connection to
    // ctx.destination (speakers) is left completely intact.
    if (audio && audio.ctx && audio.outputNode) {
      try {
        // AudioContext may be suspended until a user gesture — recording is
        // itself triggered by a click, so a resume here is safe.
        if (audio.ctx.state !== 'running') audio.ctx.resume().catch(() => {});
        const dest = audio.ctx.createMediaStreamDestination();
        audio.outputNode.connect(dest);
        this.audioDest = dest;
        this.audioSource = audio.outputNode;
        for (const t of dest.stream.getAudioTracks()) tracks.push(t);
        this.hasAudio = tracks.length > (this.videoTrack ? 1 : 0);
      } catch (e) {
        console.warn('[VideoRecorder] Audio tap failed, recording video-only:', e);
        this.audioDest = null;
        this.audioSource = null;
      }
    }

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
    }, 100);
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
    // Disconnect ONLY our parallel branch, never the emulator→speakers path.
    try {
      if (this.audioSource && this.audioDest) this.audioSource.disconnect(this.audioDest);
    } catch { /* already gone */ }
    try { this.videoTrack?.stop(); } catch { /* noop */ }
    this.audioSource = null;
    this.audioDest = null;
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
