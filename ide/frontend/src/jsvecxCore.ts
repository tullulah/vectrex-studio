import type { MetricsSnapshot, RegistersSnapshot, Segment, IEmulatorCore } from './emulatorCore.js';

export class JsVecxEmulatorCore implements IEmulatorCore {
  private mod: any = null;
  private inst: any = null;
  private biosOk: boolean = false;
  private frameCounter: number = 0;
  private lastFrameSegments: Segment[] = [];
  private fcInitCached: number | null = null;
  private memScratch: Uint8Array | null = null;
  private vecxEmuPatched: boolean = false;
  
  // Debug output system
  private debugMessages: string[] = [];
  private debugLabelBuffer: { high: number | null; low: number | null } = { high: null, low: null };
  private lastDebugOutput: string = '';
  private lastDebugValue: number = 0xFF; // Track last value at $DFFF
  private debugRam = new Uint8Array(256); // Debug pseudo-RAM for D800-D8FF area
  private pollFrameCount: number = 0; // Frame counter for reducing log spam

  async init(){
    if (this.mod) return;
    try {
      // Usar la instancia global de JSVecX creada en index.html (igual que test_jsvecx_exact.html)
      console.log('[JsVecxCore] Using global vecx instance...');
      
      // Verificar que las clases globales existen
      const VecX = (window as any).VecX;
      const vecx = (window as any).vecx;
      const Globals = (window as any).Globals;
      
      if (!VecX) {
        console.error('[JsVecxCore] VecX class not found in global scope - JSVecX scripts not loaded?');
        return;
      }
      
      if (!vecx) {
        console.error('[JsVecxCore] Global vecx instance not found - creation failed?');
        return;
      }
      
      console.log('[JsVecxCore] Found global VecX class and vecx instance');
      this.mod = { VecX, Globals };
      this.inst = vecx;
      
      // CRÍTICO: Interceptar la función write8 original de JSVecx para debug
      console.log('[JsVecxCore] Original write8 function:', typeof this.inst.write8);
      const originalWrite8 = this.inst.write8.bind(this.inst);
      this.inst.write8 = (address: number, data: number) => {
        // Interceptar escrituras al área de debug C000-C003 (unmapped gap)
        if (address >= 0xC000 && address <= 0xC003) {
          const debugAddr = address - 0xC000;
          this.debugRam[debugAddr] = data;
          console.log(`[DEBUG-WRITE] Wrote ${data} to debug address C0${debugAddr.toString(16).padStart(2, '0').toUpperCase()}`);
          // No llamar originalWrite8 - es un gap, no hay RAM real aquí
          return;
        }
        // Para otras direcciones, usar la función original
        return originalWrite8(address, data);
      };
      
      // También interceptar read8 si existe
      if (this.inst.read8) {
        console.log('[JsVecxCore] Original read8 function:', typeof this.inst.read8);
        const originalRead8 = this.inst.read8.bind(this.inst);
        this.inst.read8 = (address: number) => {
          // Interceptar lecturas del área de debug C000-C003
          if (address >= 0xC000 && address <= 0xC003) {
            const debugAddr = address - 0xC000;
            const value = this.debugRam[debugAddr] || 0xFF; // Leer del buffer interno
            console.log(`[DEBUG-READ] Read ${value} from debug address C0${debugAddr.toString(16).padStart(2, '0').toUpperCase()}`);
            return value;
          }
          // Para otras direcciones, usar la función original
          return originalRead8(address);
        };
      } else {
        console.log('[JsVecxCore] No read8 function found in JSVecx');
      }
      
      // NUEVO: También interceptar acceso directo a arrays de memoria
      console.log('[JsVecxCore] Available memory arrays:', {
        ram: this.inst.ram ? 'available' : 'not found',
        cart: this.inst.cart ? 'available' : 'not found',
        rom: this.inst.rom ? 'available' : 'not found'
      });
      
      console.log('[JsVecxCore] Debug memory interceptor installed');
      
      // Verificar que la instancia tiene los componentes necesarios
      if (!this.inst.rom) {
        console.warn('[JsVecxCore] vecx.rom not initialized - this may cause issues');
      }
      if (!this.inst.cart) {
        console.warn('[JsVecxCore] vecx.cart not initialized - this may cause issues');  
      }
      
      console.log('[JsVecxCore] JSVecX core initialized successfully');
      
      // INICIO DE BLOQUE TRY PARA INICIALIZACIÓN JSVECX
      try {
        // ¡DEJAR QUE JSVECX HAGA SU INICIALIZACIÓN NATIVA!
        // El constructor VecX ya inicializa todo correctamente
        console.log('[JsVecxCore] Using jsvecx native initialization...');
        
        // Solo verificar que los componentes principales existen
        if (!this.inst.rom) {
          console.error('[JsVecxCore] jsvecx failed to initialize ROM array');
          return;
        }
        if (!this.inst.cart) {
          console.error('[JsVecxCore] jsvecx failed to initialize cart array');
          return;
        }
        if (!this.inst.e6809) {
          console.error('[JsVecxCore] jsvecx failed to initialize CPU');
          return;
        }
        
        console.log('[JsVecxCore] jsvecx native initialization verified - rom, cart, cpu ready');
        
        // CONFIGURAR PC CORRECTAMENTE PARA ARRANQUE DE BIOS (sin hacks de cartridge)
        console.log('[JsVecxCore] Setting up proper BIOS startup...');
        
        console.log('[JsVecxCore] Attempting vecx_reset...');
        try {
          this.inst.vecx_reset();
          console.log('[JsVecxCore] vecx_reset completed successfully');
        } catch (resetError) {
          console.warn('[JsVecxCore] vecx_reset failed, doing manual initialization:', resetError);
          // Reset manual básico
          this.inst.vector_draw_cnt = 0;
          this.inst.fcycles = 0;
        }
        
        // NOTA: PC se configurará al reset vector DESPUÉS de cargar la BIOS en loadBios()
        console.log('[JsVecxCore] PC will be set to reset vector after BIOS loading');
        
        // FINAL DE INICIALIZACIÓN - RECREAR FUNCIONES DE MEMORIA
        console.log('[JsVecxCore] Recreating memory bus functions after initialization...');
        this.recreateMemoryFunctions();
        this.assignMemoryFunctionsToAllContexts();
        
      } catch (jsvecxError) {
        console.warn('[JsVecxCore] jsvecx initialization failed', jsvecxError);
      }
    } catch (e) {
      console.warn('[JsVecxCore] init failed', e);
    }
  }

  private recreateMemoryFunctions() {
    // No-op: vecx_full.js read8/write8 handle all memory mapping including bank switching.
  }

  private assignMemoryFunctionsToAllContexts() {
    if (!this.inst || !this.inst.read8 || !this.inst.write8) return;
    
    console.log('[JsVecxCore] Assigning memory functions to all possible contexts...');
    console.log('[JsVecxCore] Our write8 function reference:', this.inst.write8.toString().substring(0, 100) + '...');
    
    // CRÍTICO: jsvecx parece buscar las funciones en el contexto global/this de e6809_sstep
    // Vamos a asignar a ABSOLUTAMENTE TODOS los contextos posibles
    
    // 1. Contexto global (window)
    (window as any).read8 = this.inst.read8;
    (window as any).write8 = this.inst.write8;
    
    // 2. Contexto del módulo completo
    if (this.mod) {
      (this.mod as any).read8 = this.inst.read8;
      (this.mod as any).write8 = this.inst.write8;
      
      // 3. Todos los contextos internos del módulo
      if ((this.mod as any).Globals) {
        (this.mod.Globals as any).read8 = this.inst.read8;
        (this.mod.Globals as any).write8 = this.inst.write8;
      }
      
      if ((this.mod as any).HEAP8) {
        (this.mod.HEAP8 as any).read8 = this.inst.read8;
        (this.mod.HEAP8 as any).write8 = this.inst.write8;
      }
      
      // 4. Asignar al propio constructor VecX
      if (this.mod.VecX) {
        (this.mod.VecX as any).read8 = this.inst.read8;
        (this.mod.VecX as any).write8 = this.inst.write8;
        (this.mod.VecX.prototype as any).read8 = this.inst.read8;
        (this.mod.VecX.prototype as any).write8 = this.inst.write8;
      }
    }
    
    // 5. Instancia principal
    this.inst.read8 = this.inst.read8; // Redundante pero asegurar
    this.inst.write8 = this.inst.write8;
    
    // 6. Asignar al CPU y TODOS sus contextos
    if (this.inst.e6809) {
      console.log('[JsVecxCore] Assigning memory functions to CPU...');
      (this.inst.e6809 as any).read8 = this.inst.read8;
      (this.inst.e6809 as any).write8 = this.inst.write8;
      
      // También asignar al prototipo del CPU si existe
      if (this.inst.e6809.constructor) {
        (this.inst.e6809.constructor as any).read8 = this.inst.read8;
        (this.inst.e6809.constructor as any).write8 = this.inst.write8;
        if (this.inst.e6809.constructor.prototype) {
          (this.inst.e6809.constructor.prototype as any).read8 = this.inst.read8;
          (this.inst.e6809.constructor.prototype as any).write8 = this.inst.write8;
        }
      }
    }
    
    // 7. CRÍTICO: Asignar a 'this' del contexto actual de la función
    (this as any).read8 = this.inst.read8;
    (this as any).write8 = this.inst.write8;
    
    // 8. SÚPER CRÍTICO: En JavaScript, a veces las funciones buscan en el objeto global
    try {
      (globalThis as any).read8 = this.inst.read8;
      (globalThis as any).write8 = this.inst.write8;
    } catch {}
    
    // 9. NUEVO ENFOQUE: Interceptar e6809_sstep para asignar funciones JUSTo antes de ejecutar
    if (this.inst.e6809 && (this.inst.e6809 as any).e6809_sstep && !(this.inst.e6809 as any)._originalSstep) {
      const originalSstep = (this.inst.e6809 as any).e6809_sstep;
      // CRÍTICO: Guardar referencia para evitar recursión infinita
      (this.inst.e6809 as any)._originalSstep = originalSstep;
      
      (this.inst.e6809 as any).e6809_sstep = (...args: any[]) => {
        // ESTRATEGIA AGRESIVA: Inyectar funciones en el scope global Y local
        const memoryFunctions = {
          read8: this.inst.read8,
          write8: this.inst.write8
        };
        
        // Asignar a TODOS los posibles contextos que e6809_sstep podría usar
        (this.inst.e6809 as any).read8 = memoryFunctions.read8;
        (this.inst.e6809 as any).write8 = memoryFunctions.write8;
        (this.inst as any).read8 = memoryFunctions.read8;
        (this.inst as any).write8 = memoryFunctions.write8;
        (window as any).read8 = memoryFunctions.read8;
        (window as any).write8 = memoryFunctions.write8;
        (globalThis as any).read8 = memoryFunctions.read8;
        (globalThis as any).write8 = memoryFunctions.write8;
        
        // USAR LA FUNCIÓN ORIGINAL GUARDADA para evitar recursión
        try {
          return (this.inst.e6809 as any)._originalSstep.call(this.inst.e6809, ...args);
        } catch (e) {
          console.warn('[JsVecxCore] e6809_sstep with call failed, trying direct:', e);
          return (this.inst.e6809 as any)._originalSstep.apply(this.inst.e6809, args);
        }
      };
      console.log('[JsVecxCore] Intercepted e6809_sstep to inject memory functions before each CPU step');
    }
    
    // 10. ENFOQUE EXTREMO: Bind las funciones al contexto del CPU
    if (this.inst.e6809) {
      try {
        (this.inst.e6809 as any).read8 = this.inst.read8.bind(this.inst);
        (this.inst.e6809 as any).write8 = this.inst.write8.bind(this.inst);
        console.log('[JsVecxCore] Bound memory functions to CPU context');
      } catch (e) {
        console.log('[JsVecxCore] Could not bind memory functions:', e);
      }
    }
    
    // 11. ENFOQUE NUCLEAR: Definir funciones en el scope global de JavaScript
    try {
      const globalCode = `
        if (typeof read8 === 'undefined') {
          window.read8 = ${this.inst.read8.toString()};
          window.write8 = ${this.inst.write8.toString()};
          var read8 = window.read8;
          var write8 = window.write8;
        }
      `;
      // Usar setTimeout para ejecutar en el siguiente tick
      setTimeout(() => {
        try {
          (window as any).eval(globalCode);
          console.log('[JsVecxCore] Global functions defined via eval');
        } catch (evalError) {
          console.warn('[JsVecxCore] Eval failed:', evalError);
        }
      }, 0);
    } catch (e) {
      console.log('[JsVecxCore] Could not set global functions:', e);
    }
    
    console.log('[JsVecxCore] Memory functions assigned to ALL contexts (inst, e6809, Globals, module, HEAP8, window, VecX, globalThis, this)');
    
    // Debug final de función assignments
    console.log('[JsVecxCore] Function assignment verification:');
    console.log('  inst.read8 =', typeof this.inst.read8);
    console.log('  e6809.read8 =', typeof (this.inst.e6809 as any)?.read8);
    console.log('  Globals.read8 =', typeof (this.mod?.Globals as any)?.read8);
    console.log('  module.read8 =', typeof (this.mod as any)?.read8);
    console.log('  window.read8 =', typeof (window as any).read8);
    console.log('  globalThis.read8 =', typeof (globalThis as any).read8);
    console.log('  this.read8 =', typeof (this as any).read8);
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
    
    // CRITICAL: Start PSG audio system
    if (this.inst.e8910 && typeof this.inst.e8910.start === 'function') {
      this.inst.e8910.start();
      console.log(`[JsVecxCore] PSG audio system started`);
      
      // CRITICAL: Intercept e8910_write for PSG logging
      const originalWrite = this.inst.e8910.e8910_write;
      if (originalWrite) {
        this.inst.e8910.e8910_write = (reg: number, val: number) => {
          console.log(`[PSG-WRITE] Register ${reg} = 0x${val.toString(16).toUpperCase()}`);
          return originalWrite.call(this.inst.e8910, reg, val);
        };
        console.log(`[JsVecxCore] PSG write interceptor installed`);
      }
    } else {
      console.warn(`[JsVecxCore] PSG audio system not available or already started`);
    }
    
    // AHORA QUE LA BIOS ESTÁ CARGADA, CONFIGURAR PC AL RESET VECTOR
    if (this.inst.rom.length >= 0x2000 && this.inst.e6809) {
      // Reset vector está en 0xFFFE-0xFFFF (últimos 2 bytes de ROM)
      const resetVectorLow = this.inst.rom[0x1FFE];   // 0xFFFE - 0xE000 = 0x1FFE 
      const resetVectorHigh = this.inst.rom[0x1FFF];  // 0xFFFF - 0xE000 = 0x1FFF
      const resetVector = (resetVectorHigh << 8) | resetVectorLow;
      
      console.log(`[JsVecxCore] Reset vector bytes: High=0x${resetVectorHigh.toString(16).toUpperCase()}, Low=0x${resetVectorLow.toString(16).toUpperCase()}`);
      console.log(`[JsVecxCore] Calculated reset vector: 0x${resetVector.toString(16).toUpperCase()}`);
      
      // VERIFICAR si la BIOS está realmente cargada
      const biosCheck = this.inst.rom.slice(0x1FF0, 0x2000);
      console.log(`[JsVecxCore] BIOS end bytes (0xFFF0-0xFFFF):`, biosCheck.map((b: number) => b.toString(16).padStart(2, '0')).join(' '));
      
      // Configurar PC directamente al reset vector de la BIOS
      if (resetVector !== 0 && resetVector >= 0x1000) {
        this.inst.e6809.reg_pc = resetVector;
        console.log(`[JsVecxCore] PC set to BIOS reset vector: 0x${resetVector.toString(16).toUpperCase()}`);
      } else {
        console.warn(`[JsVecxCore] Invalid reset vector 0x${resetVector.toString(16)}, using fallback 0xF000`);
        this.inst.e6809.reg_pc = 0xF000;
        console.log('[JsVecxCore] PC set to fallback BIOS address: 0xF000');
      }
    }
  }
  
  isBiosLoaded(){ return this.biosOk; }
  
  reset(coldReset: boolean = true){
    if (!this.inst) return;
    
    try { 
      this.inst.vecx_reset(); 
      console.log(`[JsVecxCore] Reset successful (${coldReset ? 'cold' : 'warm'} reset)`);
    } catch(e) { 
      console.warn('[JsVecxCore] Reset failed, doing manual reset:', e);
      // Reset manual básico
      this.inst.vector_draw_cnt = 0;
      this.inst.fcycles = 0;
      
      // Recrear funciones de memoria tras fallo de reset
      this.recreateMemoryFunctions();
      this.assignMemoryFunctionsToAllContexts();
    } 
    
    // CONFIGURAR PC Y MEMORIA SEGÚN TIPO DE RESET
    if (coldReset) {
      // COLD RESET: Limpiar Vec_Cold_Flag y ir al inicio de BIOS
      if (this.inst.ram) {
        // Clear Vec_Cold_Flag to force cold start with VECTREX screen and music
        // Vec_Cold_Flag is at $CBFE, which maps to RAM index 0x3FE (0xCBFE & 0x3FF)
        this.inst.ram[0x3FE] = 0x00;  // Clear cold start flag
        this.inst.ram[0x3FF] = 0x00;  // Clear both bytes to ensure it's not $7321
        console.log('[JsVecxCore] Cold reset: Vec_Cold_Flag cleared');
      }
      
      // Set PC to BIOS start for cold start sequence
      if (this.inst.e6809) {
        this.inst.e6809.reg_pc = 0xF000;  // BIOS start address
        console.log('[JsVecxCore] Cold reset: PC set to BIOS start 0xF000');
      }
    } else {
      // WARM RESET: Usar reset vector normal (conserva memoria)
      if (this.inst.rom && this.inst.rom.length >= 0x2000 && this.inst.e6809) {
        // Reset vector está en 0xFFFE-0xFFFF (últimos 2 bytes de ROM)
        const resetVectorLow = this.inst.rom[0x1FFE];   // 0xFFFE - 0xE000 = 0x1FFE 
        const resetVectorHigh = this.inst.rom[0x1FFF];  // 0xFFFF - 0xE000 = 0x1FFF
        const resetVector = (resetVectorHigh << 8) | resetVectorLow;
        
        console.log(`[JsVecxCore] Reset vector bytes: High=0x${resetVectorHigh.toString(16).toUpperCase()}, Low=0x${resetVectorLow.toString(16).toUpperCase()}`);
        console.log(`[JsVecxCore] Reset vector calculated: 0x${resetVector.toString(16).toUpperCase()}`);
        
        if (resetVector !== 0 && resetVector >= 0x1000) {
          this.inst.e6809.reg_pc = resetVector;
          console.log(`[JsVecxCore] Warm reset: PC set to BIOS reset vector: 0x${resetVector.toString(16).toUpperCase()}`);
        } else {
          // Fallback si el reset vector es sospechoso
          this.inst.e6809.reg_pc = 0xF000;
          console.log(`[JsVecxCore] Warm reset: Suspicious reset vector 0x${resetVector.toString(16)}, using fallback 0xF000`);
        }
      } else if (this.inst.e6809) {
        // Fallback básico
        this.inst.e6809.reg_pc = 0xF000;
        console.log('[JsVecxCore] Warm reset: PC set to default BIOS address: 0xF000');
      }
    }
    
    this.frameCounter = 0; 
  }

  loadProgram(bytes: Uint8Array, _base?: number){
    if (!this.inst) return;

    const romSize = bytes.length;

    // Use the existing 4MB cart from vecx_full.js init; only reallocate if missing or too small
    if (!this.inst.cart || this.inst.cart.length < romSize) {
      this.inst.cart = new Array(Math.max(romSize, 0x8000)).fill(0);
    }

    // Load the full ROM — no 32KB truncation
    for (let i = 0; i < romSize; i++) {
      this.inst.cart[i] = bytes[i];
    }

    // Tell the emulator how large this ROM is so fixed-bank mapping works correctly
    this.inst.loaded_rom_size = romSize;

    console.log(`[JsVecxCore] Program loaded: ${romSize} bytes to cartridge (${Math.ceil(romSize / 0x4000)} banks)`);
  }

  runFrame(_maxInstr?: number){
    console.log('%c[JsVecxCore] 🎬 runFrame CALLED', 'background: #f0f; color: #fff; font-weight: bold; font-size: 14px');
    
    if (!this.inst) return { stepsRun: 0, vectors: [] };
    
    try { 
      // CRITICAL: Ensure PSG audio is started (idempotent call)
      if (this.inst.e8910 && typeof this.inst.e8910.start === 'function' && !this.inst.e8910.ctx) {
        this.inst.e8910.start();
        console.log('[JsVecxCore] PSG audio started in runFrame');
      }
      
      // CRÍTICO: Re-asignar funciones de memoria antes de cada frame 
      // por si jsvecx las pierde durante reset o ejecución
      console.log('[JsVecxCore] Re-assigning memory functions before frame execution...');
      this.assignMemoryFunctionsToAllContexts();
      
      // NUEVO: Monkey-patch vecx_emu para asegurar funciones antes de CADA llamada
      if (!this.vecxEmuPatched && this.inst.vecx_emu) {
        const originalVecxEmu = this.inst.vecx_emu;
        this.inst.vecx_emu = (cycles: number, cyclesDone: number) => {
          // Asegurar funciones JUSTO antes de ejecutar emulación
          console.log('[JsVecxCore] Patched vecx_emu: Re-assigning functions before execution...');
          this.assignMemoryFunctionsToAllContexts();
          
          // EXTRA DEBUG: Verificar si se ejecutan instrucciones cerca de $DFFF
          let debugCallCount = 0;
          const originalStep = this.inst.e6809?.sstep;
          if (originalStep) {
            this.inst.e6809.sstep = () => {
              const result = originalStep.call(this.inst.e6809);
              const pc = this.inst.e6809.pc || 0;
              
              // Log PC si está cerca de areas importantes o es una escritura a debug
              if (pc >= 0x0 && pc < 0x2000) { // Cartridge area
                if (debugCallCount < 50) { // Limit debug spam
                  console.log(`[DEBUG-CPU] PC=$${pc.toString(16).toUpperCase()}`);
                  debugCallCount++;
                }
              }
              
              return result;
            };
          }
          
          const result = originalVecxEmu.call(this.inst, cycles, cyclesDone);
          
          // CRITICAL: Poll debug memory AFTER each frame execution
          this.pollDebugMemory();
          
          return result;
        };
        this.vecxEmuPatched = true;
        console.log('[JsVecxCore] ✅ Patched vecx_emu - debug polling will run every frame');
      }
      
      // Intentar ejecutar un frame usando la función jsvecx
      this.inst.vecx_emu(40000, 0); // Aprox 40K cycles por frame
      
      // [DEBUG] Log vector count after frame execution
      const vectorCount = this.inst.vectors_draw?.length ?? 0;
      if (vectorCount > 0) {
        console.log(`[JSVecX] Frame ${this.frameCounter}: ${vectorCount} vectors generated`);
      }
      
      // POLLING DIRECTO: Verificar si hay nuevo debug output chequeando memoria directamente
      // console.log('[DEBUG-POLL] About to call pollDebugMemory...');
      this.pollDebugMemory();
      // console.log('[DEBUG-POLL] pollDebugMemory completed');
      
      // Extraer vectores del frame actual
      const vectors: Segment[] = [];
      if (this.inst.vectors_draw && Array.isArray(this.inst.vectors_draw)) {
        // Solo log cuando hay vectores significativos
        if (this.inst.vectors_draw.length > 0) {
          console.log(`[JsVecxCore] Processing ${this.inst.vectors_draw.length} raw vectors from JSVecX`);
        }
        
        // Log los primeros vectores solo en frames específicos (1-10, y cada 100)
        if (this.frameCounter <= 10 || this.frameCounter % 100 === 0) {
          this.inst.vectors_draw.slice(0, 3).forEach((v: any, i: number) => {
            console.log(`  Raw Vector ${i}:`, {
              type: typeof v,
              keys: v ? Object.keys(v) : 'null',
              x0: v?.x0, y0: v?.y0, x1: v?.x1, y1: v?.y1, 
              intensity: v?.intensity, color: v?.color,
              hasProps: { x0: 'x0' in v, y0: 'y0' in v, x1: 'x1' in v, y1: 'y1' in v, intensity: 'intensity' in v, color: 'color' in v }
            });
          });
        }
        
        for (const v of this.inst.vectors_draw) {
          if (v && typeof v === 'object') {
            const segment = {
              x0: v.x0 ?? 0,
              y0: v.y0 ?? 0,
              x1: v.x1 ?? 0,
              y1: v.y1 ?? 0,
              intensity: v.color ?? v.intensity ?? 0, // JSVecX usa 'color', no 'intensity'
              frame: this.frameCounter
            };
            vectors.push(segment);
          }
        }
        
        // Solo log detallado en frames específicos
        if (this.frameCounter <= 10 || this.frameCounter % 100 === 0) {
          console.log(`[JsVecxCore] Converted ${vectors.length} valid segments`);
          if (vectors.length > 0) {
            console.log(`  First converted segment:`, vectors[0]);
          }
        }
      } else {
        // Solo log cuando hay problema
        if (this.frameCounter <= 10) {
          console.log(`[JsVecxCore] No vectors_draw available:`, {
            exists: !!this.inst.vectors_draw,
            isArray: Array.isArray(this.inst.vectors_draw),
            length: this.inst.vectors_draw?.length
          });
        }
      }
      
      this.lastFrameSegments = vectors;
      this.frameCounter++;
      
      // Solo log final en frames específicos
      // console.log(`[JsVecxCore] Frame ${this.frameCounter} completed - ${vectors.length} vectors drawn`);
      
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
    
    return {
      total: 0, // No disponible en jsvecx
      unimplemented: 0, // No aplica en jsvecx
      frames: this.frameCounter,
      draw_vl: this.lastFrameSegments.length,
      last_intensity: 0, // No fácilmente disponible
      unique_unimplemented: [], // No aplica
      cycles: this.inst.fcycles || 0,
      top_opcodes: [] // No disponible en jsvecx
    };
  }

  registers(): RegistersSnapshot | null {
    if (!this.inst?.e6809) return null;
    
    const cpu = this.inst.e6809;
    return {
      a: cpu.reg_a || 0,
      b: cpu.reg_b || 0,
      dp: cpu.reg_dp || 0,
      x: cpu.reg_x?.value || 0,
      y: cpu.reg_y?.value || 0,
      u: cpu.reg_u?.value || 0,
      s: cpu.reg_s?.value || 0,
      pc: cpu.reg_pc || 0,
      cycles: this.inst.fcycles || 0,
      frame_count: this.frameCounter,
      last_intensity: 0 // No fácilmente disponible en jsvecx
    };
  }

  getSegmentsShared(): Segment[] { return this.lastFrameSegments; }

  resetStats(){ /* noop */ }
  biosCalls(){ return []; }
  clearBiosCalls(){ /* noop */ }

  // Debug output system methods
  private handleDebugOutput(value: number): void {
    console.log(`[DEBUG] handleDebugOutput called with value=${value} (0x${value.toString(16)})`);
    console.log(`[DEBUG] Label buffer state: high=${this.debugLabelBuffer.high}, low=${this.debugLabelBuffer.low}`);
    
    if (value === 0xFE) {
      // Label marker - next output will be labeled
      console.log(`[DEBUG] Received label marker (0xFE)`);
      return;
    }
    
    // Check if we have a complete label pointer
    if (this.debugLabelBuffer.high !== null && this.debugLabelBuffer.low !== null) {
      // We have a labeled debug output
      const labelPtr = (this.debugLabelBuffer.high << 8) | this.debugLabelBuffer.low;
      console.log(`[DEBUG] Processing labeled output: labelPtr=$${labelPtr.toString(16)}, value=${value}`);
      const label = this.readDebugString(labelPtr);
      const message = `${label} = ${value}`;
      this.debugMessages.push(message);
      this.lastDebugOutput = message;
      console.log(`[DEBUG] Added labeled message: ${message}`);
      
      // Clear label buffer
      this.debugLabelBuffer.high = null;
      this.debugLabelBuffer.low = null;
    } else {
      // Simple debug output (just value)
      const message = `DEBUG: ${value}`;
      this.debugMessages.push(message);
      this.lastDebugOutput = message;
      console.log(`[DEBUG] Added simple message: ${message}`);
    }
    
    console.log(`[DEBUG] Total debug messages now: ${this.debugMessages.length}`);
  }

  private pollDebugMemory(): void {
    console.log('%c[DEBUG-POLL] 🔍 pollDebugMemory called', 'background: #222; color: #0f0; font-weight: bold');
    
    if (!this.inst) {
      console.log('[DEBUG-POLL] ❌ No inst available');
      return;
    }
    
    try {
      // Leer directamente de debugRam porque JSVecx no tiene memoria mapeada en C000
      const debugValue = this.debugRam[0] || 0xFF;  // Debug value
      const debugMarker = this.debugRam[1] || 0;    // Debug marker
      const labelHigh = this.debugRam[2] || 0;      // Label pointer high
      const labelLow = this.debugRam[3] || 0;       // Label pointer low
      
      console.log('%c[DEBUG-POLL] 📊 debugRam contents:', 'color: #0ff', {
        'C000 (value)': `0x${debugValue.toString(16).padStart(2, '0')} (${debugValue})`,
        'C001 (marker)': `0x${debugMarker.toString(16).padStart(2, '0')} (${debugMarker})`,
        'C002 (labelHi)': `0x${labelHigh.toString(16).padStart(2, '0')}`,
        'C003 (labelLo)': `0x${labelLow.toString(16).padStart(2, '0')}`,
        'lastDebugValue': this.lastDebugValue,
        'Full array': Array.from(this.debugRam).map(v => `0x${v.toString(16).padStart(2, '0')}`).join(' ')
      });
      
      // Check if debug marker indicates new output (0x42 = simple, 0xFE = labeled)
      if (debugMarker === 0x42 || debugMarker === 0xFE) {
        if (debugMarker === this.lastDebugValue) {
          console.log('%c[DEBUG-POLL] ⏭️ Skipping - already processed this marker', 'color: #888');
          return;
        }
        
        console.log(`%c[DEBUG-POLL] ✅ Marker detected!`, 'background: #0a0; color: #fff; font-weight: bold', {
          type: debugMarker === 0x42 ? 'SIMPLE' : 'LABELED',
          value: debugValue,
          marker: `0x${debugMarker.toString(16)}`
        });
        
        // Process the debug output
        if (debugMarker === 0xFE && (labelHigh !== 0 || labelLow !== 0)) {
          // Labeled debug output
          const labelPtr = (labelHigh << 8) | labelLow;
          const label = this.readDebugString(labelPtr);
          const message = `${label} = ${debugValue}`;
          this.debugMessages.push(message);
          this.lastDebugOutput = message;
          console.log(`%c[DEBUG-POLL] 📝 Added labeled message: ${message}`, 'color: #0f0');
        } else {
          // Simple debug output
          const message = `DEBUG: ${debugValue}`;
          this.debugMessages.push(message);
          this.lastDebugOutput = message;
          console.log(`%c[DEBUG-POLL] 📝 Added simple message: ${message}`, 'color: #0f0');
        }
        
        this.lastDebugValue = debugMarker;
        
        // Clear the marker to avoid re-processing (write to debugRam directly)
        this.debugRam[1] = 0;
        console.log('%c[DEBUG-POLL] 🧹 Marker cleared', 'color: #fa0');
      } else {
        // No marker detected
        if (debugMarker !== 0) {
          console.log(`%c[DEBUG-POLL] ⚠️ Unknown marker: 0x${debugMarker.toString(16)}`, 'color: #f80');
        }
        // Solo log cada 100 frames para no spamear
        if (!this.pollFrameCount) this.pollFrameCount = 0;
        this.pollFrameCount++;
        if (this.pollFrameCount % 100 === 0) {
          console.log(`%c[DEBUG-POLL] ⏸️ No marker detected (frame ${this.pollFrameCount})`, 'color: #666');
        }
      }
    } catch (error) {
      console.warn('%c[DEBUG-POLL] ❌ Error during polling:', 'color: #f00; font-weight: bold', error);
    }
  }

  private readDebugString(address: number): string {
    if (!this.inst) return 'UNKNOWN';
    
    let result = '';
    let current = address;
    
    // Read string until high bit is set (Vectrex string termination)
    for (let i = 0; i < 32; i++) { // Safety limit
      const byte = this.readMemoryByte(current);
      if (byte === 0) break; // Safety fallback
      
      if (byte & 0x80) {
        // High bit set - last character
        result += String.fromCharCode(byte & 0x7F);
        break;
      } else {
        result += String.fromCharCode(byte);
        current++;
      }
    }
    
    return result || 'EMPTY';
  }

  private readMemoryByte(address: number): number {
    if (!this.inst) return 0;
    
    address = address & 0xFFFF;
    
    if (address < 0x8000 && this.inst.cart) {
      return this.inst.cart[address] || 0;
    } else if (address >= 0xC800 && address < 0xD000 && this.inst.ram) {
      const ramAddr = (address - 0xC800) & 0x3FF;
      return this.inst.ram[ramAddr] || 0;
    } else if (address >= 0xE000 && this.inst.rom) {
      const romAddr = (address - 0xE000) & 0x1FFF;
      return this.inst.rom[romAddr] || 0;
    }
    
    return 0;
  }

  // Public methods to access debug messages
  public getDebugMessages(): string[] {
    return [...this.debugMessages];
  }

  public clearDebugMessages(): void {
    this.debugMessages = [];
    this.lastDebugOutput = '';
  }

  public getLastDebugOutput(): string {
    return this.lastDebugOutput;
  }

  // PSG Write Logging
  public enablePsgLog(enabled: boolean, limit?: number): void {
    const win = window as any;
    win.PSG_LOG_ENABLED = enabled;
    if (limit !== undefined) {
      win.PSG_LOG_LIMIT = limit;
    }
    if (!enabled) {
      this.clearPsgLog();
    }
  }

  public clearPsgLog(): void {
    const win = window as any;
    if (win.PSG_WRITE_LOG) {
      win.PSG_WRITE_LOG.length = 0;
    }
  }

  public getPsgLog(): Array<{reg: number; value: number; frame: number; pc: number}> {
    const win = window as any;
    return win.PSG_WRITE_LOG || [];
  }
}