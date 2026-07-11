// Reproductor de audio PSG basado en polling delta PCM del backend (IEmulatorCore audio* API).
// Política: No reprocesar ni sintetizar; simplemente convertir i16 -> Float32 y empujar a un AudioWorklet o fallback ScriptProcessor.
// Si el navegador no soporta AudioWorklet, se usa un nodo ScriptProcessor con pequeño buffer.

import { emuCore } from './emulatorCoreSingleton.js';

class RingBufferF32 {
  private buf: Float32Array;
  private mask: number;
  private w = 0;
  private r = 0;
  constructor(pow2=15){ // 32k frames (~0.7s a 44.1k)
    const size = 1<<pow2; this.buf = new Float32Array(size); this.mask=size-1;
  }
  push(samples: Float32Array){ for (let i=0;i<samples.length;i++){ this.buf[this.w & this.mask]=samples[i]; this.w++; if (this.w - this.r > this.buf.length){ this.r = this.w - this.buf.length; } } }
  pop(count:number): Float32Array { const avail = this.w - this.r; if (avail<=0) return new Float32Array(); const n = Math.min(count, avail); const out = new Float32Array(n); for (let i=0;i<n;i++){ out[i]=this.buf[this.r & this.mask]; this.r++; } return out; }
  available(){ return this.w - this.r; }
  capacity(){ return this.buf.length; }
}

export class PsgAudioStreamer {
  private ctx: AudioContext | null = null;
  private workletReady = false;
  private running = false;
  private ring = new RingBufferF32();
  private pumpTimer: number | null = null;
  private sampleRateBackend = 0;
  private spNode: ScriptProcessorNode | null = null;
  private overflowCount = 0;
  private pushedSamples = 0;
  private consumedSamples = 0; // estimado (ScriptProcessor) o real (worklet callback future)
  private lastStatsTime = 0;
  private baselineConsumed = 0; // valor inicial de consumed para evitar buffered negativo mientras no hay producción

  async init(){
    if (this.ctx) return;
    this.ctx = new AudioContext({ latencyHint:'interactive' });
    this.sampleRateBackend = emuCore.audioSampleRate?.() || 44100;
    // Intentar cargar worklet inline (generamos un blob con procesador simple)
    try {
      // Skip AudioWorklet due to CSP restrictions in development
      // Use ScriptProcessor directly for better compatibility
      throw new Error('[PsgAudio] Skipping AudioWorklet due to CSP restrictions, using ScriptProcessor');
    } catch (e){
      console.warn('[PsgAudio] Using ScriptProcessor (AudioWorklet blocked by CSP)', e);
      if (this.ctx) {
        this.spNode = this.ctx.createScriptProcessor(1024, 0, 1);
        this.spNode.onaudioprocess = (ev)=>{
          const out = ev.outputBuffer.getChannelData(0);
          const need = out.length;
            let off=0;
            while(off<need){
              const chunk = this.ring.pop(need-off);
              if (chunk.length===0) break;
              out.set(chunk, off);
              off += chunk.length;
            }
          for (let i=off;i<need;i++) out[i]=0;
          this.consumedSamples += need;
        };
        this.spNode.connect(this.ctx.destination);
      }
    }
  }

  start(){ if (this.running) return; this.running=true; this.schedulePump(); }
  stop(){ this.running=false; if (this.pumpTimer){ clearTimeout(this.pumpTimer); this.pumpTimer=null; } }

  /** For the video recorder's parallel audio tap. Returns this streamer's
   *  AudioContext + its output node (the ScriptProcessor feeding the speakers),
   *  or null if audio hasn't been initialised. The legacy JSVecX 6809 path
   *  produces sound HERE, so the recorder must tap this too. */
  getAudioContextAndOutputNode(): { ctx: AudioContext; outputNode: AudioNode } | null {
    if (this.ctx && this.spNode) return { ctx: this.ctx, outputNode: this.spNode };
    return null;
  }

  private schedulePump(){ if (!this.running) return; this.pumpTimer = window.setTimeout(()=>this.pump(), 16); }

  private pump(){
    try {
      const delta = emuCore.audioPrepareDelta?.();
      if (delta && delta.length){
        const f32 = new Float32Array(delta.length);
        const norm = 1/32768;
        for (let i=0;i<delta.length;i++){ f32[i] = (delta[i]/32768); }
        // push into ring or send to worklet
        if (this.workletReady && (this as any)._node){ (this as any)._node.port.postMessage({ cmd:'push', buf:f32 }); }
        else { this.ring.push(f32); }
        this.pushedSamples += f32.length;
        if (emuCore.audioHasOverflow?.()) this.overflowCount++;
      }
    } catch (e){ /* noop */ }
    this.schedulePump();
  }
  getStats(){
    const sr = this.sampleRateBackend || (this.ctx?.sampleRate || 44100);
    // Ajuste: si aún no hemos empujado nada, consideramos baseline el consumed actual
    if (this.pushedSamples === 0 && this.consumedSamples !== 0 && this.baselineConsumed === 0){ this.baselineConsumed = this.consumedSamples; }
    const effectiveConsumed = Math.max(0, this.consumedSamples - this.baselineConsumed);
    const buffered = Math.max(0, this.pushedSamples - effectiveConsumed);
    const ms = buffered > 0 ? (buffered / sr * 1000) : 0;
    return { sampleRate: sr, pushed: this.pushedSamples, consumed: effectiveConsumed, bufferedSamples: buffered, bufferedMs: ms, overflowCount: this.overflowCount };
  }
  /**
   * Manual probe para inspeccionar evolución de métricas sin UI.
   * Uso (en consola del renderer): psgAudio.runManualStatsProbe({intervalMs:1000, durationMs:8000})
   * No fabrica datos: sólo llama a getStats() periódicamente y loguea delta pushed/consumed.
   */
  runManualStatsProbe(opts?:{intervalMs?:number; durationMs?:number}){
    const intervalMs = opts?.intervalMs ?? 1000;
    const durationMs = opts?.durationMs ?? 8000;
    const start = performance.now();
    let last = this.getStats();
    console.log('[psgAudio][probe] start', last);
    const tick = () => {
      const nowStats = this.getStats();
      const dp = nowStats.pushed - last.pushed;
      const dc = nowStats.consumed - last.consumed;
      console.log('[psgAudio][probe]', { t:((performance.now()-start)|0)+'ms', pushed: nowStats.pushed, consumed: nowStats.consumed, dP: dp, dC: dc, bufferedMs: nowStats.bufferedMs.toFixed(2), overflows: nowStats.overflowCount });
      last = nowStats;
      if (performance.now() - start < durationMs){ setTimeout(tick, intervalMs); } else { console.log('[psgAudio][probe] end'); }
    };
    setTimeout(tick, intervalMs);
  }
}

export const psgAudio = new PsgAudioStreamer();
// Exponer global para pruebas manuales (solo dev). No rompe si window no existe (SSR no usado aquí).
try { (window as any).psgAudio = psgAudio; } catch {}
