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
