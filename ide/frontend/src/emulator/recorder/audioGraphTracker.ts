/**
 * audioGraphTracker — universal Web Audio tap discovery for the video recorder.
 *
 * The emulator plays sound through an AudioContext, but WHICH one (and which
 * node feeds the speakers) varies by target/subsystem and some paths were
 * impossible to find by hand. Instead of hunting, we patch — once, at app
 * startup — the AudioContext constructors and AudioNode.connect so we always
 * know every live context and every node connected (directly) to a context's
 * destination (the speakers).
 *
 * `getRunningAudioTap()` then returns a { ctx, outputNode } for whichever
 * context is actually 'running' with a node feeding its destination — exactly
 * what the recorder needs to attach a parallel MediaStreamAudioDestinationNode,
 * regardless of which subsystem produced the sound.
 *
 * install() is idempotent and must run before any AudioContext is created
 * (import it at the very top of the app entry).
 */

interface TrackedCtx {
  ctx: BaseAudioContext;
  /** Nodes observed connecting directly to ctx.destination (feed the speakers). */
  outputs: Set<AudioNode>;
}

const tracked: TrackedCtx[] = [];
let installed = false;

function findOrAdd(ctx: BaseAudioContext): TrackedCtx {
  let t = tracked.find(x => x.ctx === ctx);
  if (!t) { t = { ctx, outputs: new Set() }; tracked.push(t); }
  return t;
}

export function installAudioGraphTracker(): void {
  if (installed) return;
  installed = true;

  const g = globalThis as any;

  // 1) Track every AudioContext instance.
  for (const key of ['AudioContext', 'webkitAudioContext'] as const) {
    const Orig = g[key];
    if (typeof Orig !== 'function') continue;
    const Patched = function (this: any, ...args: any[]) {
      const inst = new Orig(...args);
      try { findOrAdd(inst); } catch { /* noop */ }
      return inst;
    } as any;
    Patched.prototype = Orig.prototype;
    g[key] = Patched;
  }

  // 2) Track nodes that connect to a context's destination (= feed the speakers).
  const AN = g.AudioNode;
  if (AN?.prototype?.connect) {
    const origConnect = AN.prototype.connect;
    AN.prototype.connect = function (this: AudioNode, dest: any, ...rest: any[]) {
      try {
        const ctx = (this as any).context as BaseAudioContext | undefined;
        if (ctx && dest === ctx.destination) findOrAdd(ctx).outputs.add(this);
      } catch { /* noop */ }
      return origConnect.call(this, dest, ...rest);
    };
  }
}

/** Snapshot of all tracked contexts (for diagnostics). */
export function debugAudioContexts(): Array<{ state: string; outputs: number }> {
  return tracked.map(t => ({ state: (t.ctx as any).state ?? '?', outputs: t.outputs.size }));
}

/**
 * Best { ctx, outputNode } to tap: a RUNNING context that has a node feeding its
 * destination. Prefers running contexts; falls back to any with outputs.
 */
export function getRunningAudioTap(): { ctx: AudioContext; outputNode: AudioNode } | null {
  const withOutputs = tracked.filter(t => t.outputs.size > 0);
  const pick =
    withOutputs.find(t => (t.ctx as any).state === 'running') ?? withOutputs[0];
  if (!pick) return null;
  // Use the most recently added output node (last connect wins for live audio).
  const outputNode = Array.from(pick.outputs).pop()!;
  return { ctx: pick.ctx as AudioContext, outputNode };
}

/**
 * Every tracked node feeding the speakers OF ONE GIVEN CONTEXT.
 *
 * Use this when the caller already knows WHICH context it wants (the active
 * emulation target's). `getRunningContextOutputs()` picks the first running
 * context it finds, which after switching targets can be a stale one that is
 * still 'running' but silent — the recorder then taps it, captures nothing, and
 * reports success. Pinning the context first and asking for its outputs here
 * keeps the full-mix behaviour without that failure mode.
 */
export function getOutputsForContext(ctx: BaseAudioContext | null | undefined): AudioNode[] {
  if (!ctx) return [];
  const t = tracked.find(x => x.ctx === ctx);
  return t ? Array.from(t.outputs) : [];
}

/**
 * The running context and ALL nodes feeding its speakers. The video recorder
 * connects every one to its tap (and re-checks for newly-added nodes each tick),
 * so it captures the FULL mix — PSG music AND late-arriving BufferSources like a
 * PLAY_SAMPLE track — not just whichever single node existed first.
 */
export function getRunningContextOutputs(): { ctx: AudioContext; outputs: AudioNode[] } | null {
  const withOutputs = tracked.filter(t => t.outputs.size > 0);
  const pick =
    withOutputs.find(t => (t.ctx as any).state === 'running') ?? withOutputs[0];
  if (!pick) return null;
  return { ctx: pick.ctx as AudioContext, outputs: Array.from(pick.outputs) };
}

/**
 * EVERY live context that has something feeding its speakers, most recently
 * created last.
 *
 * WHY THE RECORDER WANTS ALL OF THEM AND NOT THE BEST ONE. Picking is what kept
 * going wrong. getRunningContextOutputs() picks the first running context, which
 * after switching targets is often a stale silent one. getOutputsForContext()
 * fixed that by pinning the ACTIVE TARGET's context — but only a component the
 * panel knows about can be "the active target", and the WASM simulator is a
 * React component that owns its own audio and is not one of them. Its recordings
 * came out silent end to end, video and all, and the recorder reported success.
 *
 * Tapping every live context cannot have that failure: a stale one contributes
 * silence to a mix, which costs nothing, while the one that is actually sounding
 * is in there by construction. There is no judgement left to get wrong.
 *
 * Closed contexts are skipped — connecting to one throws.
 */
export function getAllLiveContextOutputs(): Array<{ ctx: AudioContext; outputs: AudioNode[] }> {
  return tracked
    .filter(t => t.outputs.size > 0 && (t.ctx as any).state !== 'closed')
    .map(t => ({ ctx: t.ctx as AudioContext, outputs: Array.from(t.outputs) }));
}
