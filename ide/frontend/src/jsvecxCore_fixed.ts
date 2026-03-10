import type { MetricsSnapshot, RegistersSnapshot, Segment } from './emulatorCore';

export class JsVecxCore {
  private mod: any = null;
  private inst: any = null;
  private biosOk: boolean = false;
  private frameCounter: number = 0;
  private lastFrameSegments: Segment[] = [];
  private fcInitCached: number | null = null;
  private memScratch: Uint8Array | null = null;

  async init(){
    if (this.mod) return;
    try {
      // SIMPLIFICADO: Usar la instancia global window.vecx creada por index.html
      // Los scripts de jsvecx_deploy/ ya se cargan en orden correcto en index.html
      // y crean window.vecx con soporte multibank ($DF00)
      const globalVecx = (window as any).vecx;
      const GlobalVecXClass = (window as any).VecX;
      const GlobalGlobals = (window as any).Globals;
      
      if (!globalVecx || !GlobalVecXClass) {
        console.warn('[JsVecxCore] window.vecx no disponible; backend jsvecx inerte');
        return;
      }
      
      console.log('[JsVecxCore] Using global window.vecx instance (with multibank support)');
      this.mod = { VecX: GlobalVecXClass, Globals: GlobalGlobals } as any;
      this.inst = globalVecx; // Usar instancia existente, no crear nueva
      
      // La instancia global ya está completamente inicializada por index.html
      // NO sobrescribimos read8/write8 porque vecx.js ya tiene soporte multibank
      console.log('[JsVecxCore] Instance ready - multibank:', this.inst.isMultibank, 'bankRegister:', this.inst.bankRegister?.toString(16));
      
    } catch (e){
      console.warn('[JsVecxCore] init failed', e);
    }
  }
  
  loadBios(bytes: Uint8Array){
    // jsvecx espera 8K ROM en this.rom; copiamos mínimo (clamp a 0x2000)
    if (!this.inst) return; 
    
    // Asegurar que el array ROM existe
    if (!this.inst.rom) {
      this.inst.rom = new Array(0x2000).fill(0);
    }
    
    const maxLen = Math.min(bytes.length, 0x2000);
    for (let i = 0; i < maxLen; i++) {
      this.inst.rom[i] = bytes[i];
    }
    this.biosOk = true;
    console.log(`[JsVecxCore] BIOS loaded: ${maxLen} bytes copied to ROM`);
  }
  
  isBiosLoaded(){ return this.biosOk; }
  
  reset(){
    if (!this.inst) return;
    
    try { 
      this.inst.vecx_reset(); 
      console.log('[JsVecxCore] Reset successful');
    } catch(e) { 
      console.warn('[JsVecxCore] Reset failed:', e);
    } 
    this.frameCounter = 0; 
  }

  loadProgram(bytes: Uint8Array, _base?: number){
    if (!this.inst) return;

    const romSize = bytes.length;

    if (!this.inst.cart || this.inst.cart.length < romSize) {
      this.inst.cart = new Array(Math.max(romSize, 0x8000)).fill(0);
    }

    for (let i = 0; i < romSize; i++) {
      this.inst.cart[i] = bytes[i];
    }

    this.inst.loaded_rom_size = romSize;
    console.log(`[JsVecxCore] Program loaded: ${romSize} bytes (${Math.ceil(romSize / 0x4000)} banks)`);
  }

  runFrame(_maxInstr?: number){
    if (!this.inst) return { stepsRun: 0, vectors: [] };
    
    try { 
      // Intentar ejecutar un frame usando la función jsvecx
      this.inst.vecx_emu(40000, 0); // Aprox 40K cycles por frame
      
      // Extraer vectores del frame actual
      const vectors: Segment[] = [];
      if (this.inst.vectors_draw && Array.isArray(this.inst.vectors_draw)) {
        for (const v of this.inst.vectors_draw) {
          if (v && typeof v === 'object') {
            vectors.push({
              x0: v.x0 || 0,
              y0: v.y0 || 0,
              x1: v.x1 || 0,
              y1: v.y1 || 0,
              intensity: v.intensity || 0,
              frame: this.frameCounter
            });
          }
        }
      }
      
      this.lastFrameSegments = vectors;
      this.frameCounter++;
      
      return { 
        stepsRun: 40000, // Estimado 
        vectors: vectors 
      };
    } catch(e){ 
      console.warn('[JsVecxCore] runFrame failed:', e);
      return { stepsRun: 0, vectors: [] };
    }
  }

  metrics(): MetricsSnapshot | null {
    if (!this.inst) return null;
    
    // MetricsSnapshot interface requires specific fields
    return {
      total: 0,
      unimplemented: 0,
      frames: this.frameCounter,
      draw_vl: this.lastFrameSegments.length,
      last_intensity: 0,
      unique_unimplemented: [],
      cycles: this.inst.fcycles || 0,
      top_opcodes: []
    };
  }

  registers(): RegistersSnapshot | null {
    if (!this.inst?.e6809) return null;
    
    const cpu = this.inst.e6809;
    return {
      pc: cpu.reg_pc || 0,
      a: cpu.reg_a || 0,
      b: cpu.reg_b || 0,
      dp: cpu.reg_dp || 0,
      x: cpu.reg_x?.value || 0,
      y: cpu.reg_y?.value || 0,
      u: cpu.reg_u?.value || 0,
      s: cpu.reg_s?.value || 0,
      cycles: this.inst.fcycles || 0,
      frame_count: this.frameCounter,
      last_intensity: 0
    };
  }

  getSegmentsShared(): Segment[] { return this.lastFrameSegments; }

  resetStats(){ /* noop */ }
  biosCalls(){ return []; }
  clearBiosCalls(){ /* noop */ }
}
