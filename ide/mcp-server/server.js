#!/usr/bin/env node
/**
 * VPy IDE MCP Server - Model Context Protocol stdio server
 * 
 * This server implements the MCP protocol via stdin/stdout to expose
 * IDE state and operations to AI agents like Copilot, Claude, etc.
 * 
 * Protocol: JSON-RPC 2.0 over stdio with Content-Length headers
 * 
 * Usage:
 *   node server.js
 * 
 * The server communicates with the running Electron IDE via IPC
 * to access editor state, compiler, emulator, debugger, etc.
 */

const net = require('net');
const readline = require('readline');

// Write startup message immediately to stderr (unbuffered)
console.error('[MCP Server] ✅ SERVER STARTING - Args:', process.argv.slice(2));

// Configuration
const IPC_PORT = 9123; // Port where Electron main listens for MCP IPC
const VERBOSE = process.env.MCP_VERBOSE === '1';

function log(...args) {
  if (VERBOSE) {
    console.error('[MCP Server]', ...args);
  }
}

// Connection to Electron IDE
let ipcSocket = null;
let ipcConnected = false;
let ipcCallbacks = new Map();
let ipcCallId = 0;

// Connect to Electron IDE's IPC server with retry logic
async function connectToIDE(retries = 5, delay = 100) {
  // In stdio mode, use fast retries but don't fail if IDE isn't available
  if (process.argv.includes('--stdio')) {
    retries = 2;
    delay = 50;
    log('Using fast retry mode for --stdio (will continue even if IDE not found)');
  }
  
  return new Promise((resolve, reject) => {
    const attemptConnection = (attemptNum) => {
      log(`Attempting to connect to IDE IPC (attempt ${attemptNum}/${retries})...`);
      
      const socket = net.createConnection({ port: IPC_PORT, host: 'localhost' });
      
      socket.on('connect', () => {
        log('Connected to IDE IPC');
        ipcSocket = socket;
        ipcConnected = true;
        
        // Setup data handler
        let buffer = '';
        socket.on('data', (chunk) => {
          buffer += chunk.toString();
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          
          for (const line of lines) {
            if (line.trim()) {
              try {
                const response = JSON.parse(line);
                const callback = ipcCallbacks.get(response.id);
                if (callback) {
                  ipcCallbacks.delete(response.id);
                  callback(response);
                }
              } catch (e) {
                log('Failed to parse IPC response:', e);
              }
            }
          }
        });
        
        // Handle connection close - reconnect automatically
        socket.on('close', () => {
          log('⚠️ IPC connection closed - will attempt reconnection');
          ipcConnected = false;
          ipcSocket = null;
          
          // Attempt to reconnect after 1 second
          setTimeout(() => {
            log('Attempting to reconnect to IDE...');
            connectToIDE(10, 1000).catch(err => {
              log('❌ Failed to reconnect:', err.message);
            });
          }, 1000);
        });
        
        socket.on('end', () => {
          log('⚠️ IPC connection ended');
          ipcConnected = false;
          ipcSocket = null;
        });
        
        resolve();
      });
      
      socket.on('error', (err) => {
        log(`IPC connection attempt ${attemptNum} failed:`, err.message);
        socket.destroy();
        
        if (attemptNum < retries) {
          setTimeout(() => attemptConnection(attemptNum + 1), delay);
        } else {
          // In stdio mode, continue anyway with simulated responses
          if (process.argv.includes('--stdio')) {
            log('⚠️ IDE not available, continuing with simulated responses');
            ipcConnected = false;
            resolve();
          } else {
            reject(new Error(`Failed to connect to IDE IPC after ${retries} attempts`));
          }
        }
      });
    };
    
    attemptConnection(1);
  });
}

// Send request to IDE via IPC
async function sendToIDE(request) {
  // In stdio mode without IDE connection, return simulated data
  if ((!ipcConnected || !ipcSocket) && process.argv.includes('--stdio')) {
    log('⚠️ IDE not connected in --stdio mode, returning simulated data for:', request.method);
    return simulateIDEResponse(request.method, request.params);
  }
  
  if (!ipcConnected || !ipcSocket) {
    throw new Error('Not connected to IDE');
  }
  
  return new Promise((resolve, reject) => {
    const id = ipcCallId++;
    const wrappedRequest = { ...request, id };
    
    ipcCallbacks.set(id, (response) => {
      if (response.error) {
        reject(new Error(response.error.message));
      } else {
        resolve(response.result);
      }
    });
    
    // Send with newline delimiter
    ipcSocket.write(JSON.stringify(wrappedRequest) + '\n');
    
    // Timeout after 30s
    setTimeout(() => {
      if (ipcCallbacks.has(id)) {
        ipcCallbacks.delete(id);
        reject(new Error('IPC request timeout'));
      }
    }, 30000);
  });
}

// Simulate IDE responses for testing in --stdio mode
function simulateIDEResponse(method, params) {
  log('Simulating IDE response for:', method);
  
  switch (method) {
    case 'editor/list_documents':
      return { documents: [] };
    
    case 'editor/read_document':
      return { uri: params?.uri, content: '# Empty document' };
    
    case 'editor/write_document':
      return { success: true, uri: params?.uri };
    
    case 'editor/replace_range':
      return { success: true };
    
    case 'editor/insert_at':
      return { success: true };
    
    case 'editor/delete_range':
      return { success: true };
    
    case 'editor/get_diagnostics':
      return { diagnostics: [] };
    
    case 'compiler/build':
      return { success: true, message: 'Build would run (IDE not connected)' };
    
    case 'compiler/get_errors':
      return { errors: [] };
    
    case 'emulator/run':
      return { success: true, message: 'Emulator would run (IDE not connected)' };
    
    case 'emulator/get_state':
      return { pc: 0, cycles: 0, registers: {} };
    
    case 'emulator/stop':
      return { success: true };
    
    case 'debugger/add_breakpoint':
      return { success: true };
    
    case 'debugger/get_callstack':
      return { stack: [] };
    
    case 'project/get_structure':
      return { root: '/project', files: [], folders: [] };
    
    case 'project/read_file':
      return { content: '# File content unavailable' };
    
    case 'project/write_file':
      return { success: true };
    
    case 'project/create':
      return { success: true };
    
    case 'project/close':
      return { success: true };
    
    case 'project/open':
      return { success: true };
    
    case 'project/create_vector':
      return { success: true, message: 'Vector asset would be created' };
    
    case 'project/create_music':
      return { success: true, message: 'Music asset would be created' };
    
    default:
      return { error: `Unknown method: ${method}` };
  }
}

// ============================================================
// PROJECT DOCUMENTATION - served by get_project_docs tool
// ============================================================
function getProjectDocs(topic) {
  const docs = {

    compiler: `## VPy Compiler - Critical Rules
- NEVER write WAIT_RECAL() manually - compiler auto-injects at start of loop()
- NEVER write MUSIC_UPDATE() or AUDIO_UPDATE() - auto-injected at END of loop()
- Variables in main() are NOT accessible in loop() - separate scopes
- Declare variables inside loop() where they are used
- Build: cargo run --bin vectrexc -- build program.vpy --bin
- Single-bank: fits in 32KB. Multibank needs META ROM_TOTAL_SIZE + ROM_BANK_SIZE
- Architecture: loop() compiles to LOOP_BODY subroutine, called via JSR from main loop
- Source: core/src/backend/m6809/mod.rs (main codegen), core/src/backend/m6809/builtins.rs`,

    bios: `## BIOS Usage Rules
- NEVER use synthetic BIOS - always use real bios.bin
- Primary path: ide/frontend/src/assets/bios.bin
- Legacy path: ide/frontend/dist/bios.bin  
- BIOS boots automatically to Minestorm (no button press needed)
- BIOS always jumps to $0000 (Bank #0) - NEVER uses RESET vector at $FFFE
- record_bios_call: only registers JSR/BSR toward >= 0xF000, no fake side effects
- Key BIOS addresses: Wait_Recal=0xF192, Draw_Line_d=0xF2B2, Print_Str_d=0xF373
- DP must be set to $D0 before most BIOS calls (compiler handles this)`,

    tests: `## Tests Structure & Rules
- tests/opcodes/ - MC6809 opcode tests (arithmetic, branch, comparison, data_transfer, logic, register, stack)
- tests/components/ - emulator component tests (integration, hardware, engine, memory, cpu)
- RAM in tests: 0xC800-0xCFFF. Stack: 0xCFFF. One file per opcode.
- NEVER use synthetic BIOS in tests
- Always verify: registers, flags, cycles after each opcode
- cargo test -p vectrex_emulator after any CPU/WASM API changes`,

    assets: `## Asset System (Vectors & Music)
- .vec files: assets/vectors/*.vec  - .vmus files: assets/music/*.vmus
- Auto-discovered at compile time (Phase 0), auto-embedded in ROM (Phase 5)
- In code: DRAW_VECTOR("name") and PLAY_MUSIC("name")
- NEVER invent asset names - verify with project/get_structure first

### .vec format (JSON only):
{"version":"1.0","name":"player","canvas":{"width":256,"height":256,"origin":"center"},
 "layers":[{"name":"default","visible":true,"paths":[{
   "name":"ship","intensity":127,"closed":true,
   "points":[{"x":0,"y":20},{"x":-15,"y":-10},{"x":15,"y":-10}]
 }]}]}

### .vmus format (JSON only):
{"version":"1.0","name":"theme","author":"Composer","tempo":120,"ticksPerBeat":24,
 "totalTicks":384,"notes":[{"id":"n1","note":60,"start":0,"duration":48,"velocity":12,"channel":0}],
 "noise":[{"id":"noise1","start":0,"duration":24,"period":15,"channels":1,"velocity":12}],
 "loopStart":0,"loopEnd":384}
- note: MIDI (60=C4, 69=A4). velocity: 0-15. channel: 0-2 (PSG A/B/C). period: 0-31 (noise pitch)
- Use project/create_vector and project/create_music tools (they validate JSON)`,

    joystick: `## Joystick Input System
- J1_X() returns -1 (left), 0 (center), +1 (right)
- J1_Y() returns -1 (down), 0 (center), +1 (up)
- RAM addresses: $CF00=Joy_1_X, $CF01=Joy_1_Y (unsigned 0-255)
- Frontend writes these addresses every frame (browser Gamepad API)
- Thresholds: 0-107=-1, 108-148=0, 149-255=+1 (deadzone ±20 around 128)
- Source: core/src/backend/m6809/builtins.rs lines ~213-276`,

    buttons: `## Button System (J1_BUTTON_1-4) - Auto-injected
- NEVER call UPDATE_BUTTONS() - compiler auto-injects Read_Btns at start of loop()
- J1_BUTTON_1() through J1_BUTTON_4() return 0=released, 1=pressed
- Auto-injection sequence at loop start: JSR DP_to_D0 → JSR Read_Btns → JSR DP_to_C8
- Buttons read cached $C80F (Vec_Btn_State) - set once per frame, no auto-fire
- Why one Read_Btns per frame: multiple calls break Vec_Prev_Btns debounce
- Source: core/src/backend/m6809/mod.rs line ~748 (auto-injection)
         core/src/backend/m6809/emission.rs lines 105-160 (builtin handlers)`,

    const_arrays: `## Const Arrays - ROM-Only Data
- const keyword: allocates in ROM, zero RAM overhead
- Syntax: const player_x = [10, 20, 30]  (NOT let)
- Indexing: val = player_x[0] or val = player_x[index]  (both work)
- Const string arrays: const names = ["HELLO", "WORLD"] - indexing returns pointer
  - Use with PRINT_TEXT: PRINT_TEXT(x, y, names[i])
- Regular arrays (let) allocate RAM pointer + init code in main()
- Const arrays emit CONST_ARRAY_N labels in ROM, no VAR_* defined
- Source: core/src/backend/m6809/mod.rs lines 246-273 (collection), 997-1039 (emission)
         core/src/backend/m6809/expressions.rs lines 239-267 (indexing)`,

    modules: `## Module System (Phase 6.3 Complete)
- Import: import input  then call input.get_input() or access input.var_name[i]
- Unifier transforms dot notation: input.get_input() → INPUT_GET_INPUT()
- Helpers auto-deduplicated (unifier merges all imports into one module before codegen)
- Build: cargo run --bin vectrexc -- build main.vpy --bin (auto-resolves imports)
- Example: examples/multi-module/
- Source: core/src/unifier.rs (dot notation rewriting)
         core/src/backend/m6809/mod.rs lines 820-838 (collision-free array labels)`,

    banking: `## Multibank ROM Architecture
- Meta required: META ROM_TOTAL_SIZE = 524288 and META ROM_BANK_SIZE = 16384
- 32 banks × 16KB = 512KB max. Bank #31 fixed at $4000-$7FFF (always visible)
- Bank switch register: $DF00 (write bank ID 0-31). NEVER $4000 or $D000.
- Boot sequence: BIOS → $0000 (Bank #0) → STA $DF00 #31 → JMP MAIN (Bank #31)
- CRITICAL: BIOS always jumps to $0000, NEVER to RESET vector. Bank switch MUST be in Bank #0.
- Cross-bank calls auto-wrapped (save bank → switch → call → restore)
- CURRENT_ROM_BANK RAM tracker at $C880
- Phase 6.7: multibank linker. Phase 6.8: PDB with correct bank addresses
- Known issue: VAR_ARG2 undefined in bank_31 if PRINT_TEXT not used in code
- Source: core/src/backend/m6809/mod.rs lines 839-851 (boot), bank_wrappers.rs`,

    draw_line: `## DRAW_LINE Optimization
- DRAW_LINE(x0, y0, x1, y1, intensity)
- Inline optimization: when all args constant AND |dx|,|dy| <= 127
- Wrapper (DRAW_LINE_WRAPPER): auto-emitted only when segmentation needed
- Segmentation: segment1=±127, segment2=remainder (for lines > 127px)
- Variable args always use wrapper (safe fallback)
- Source: core/src/backend/m6809/analysis.rs lines 259-283 (detection)
         core/src/backend/m6809/emission.rs lines 260-368 (wrapper code)`,

    music: `## Music System
- PLAY_MUSIC("name") - plays .vmus file embedded in ROM
- AUDIO_UPDATE auto-injected at END of loop() by compiler
- PSG player updates every frame (50Hz)
- MIDI to PSG: period = 1_500_000 / (16 * freq). freq = 440 * 2^((note-69)/12)
- note 60 (C4) → PSG period 358, note 69 (A4) → period 213 (= Freq_Table[26] de la BIOS)
- PSG channels: 0=A, 1=B, 2=C. Velocity: 0-15. Noise period: 0-31.
- Source: core/src/musres.rs (MusicResource), core/src/backend/m6809/mod.rs (injection)`,

    meta: `## VPy META Configuration
- META TITLE = "Game Name"      - Cartridge title
- META MUSIC = 1                - Enable music system
- META ROM_TOTAL_SIZE = 524288  - Enable multibank (512KB = 32×16KB)
- META ROM_BANK_SIZE = 16384    - Bank size (always 16384 for Vectrex)
- Single bank (no ROM_TOTAL_SIZE): code must fit in 32KB
- Multibank: code auto-distributed across banks, cross-bank calls auto-wrapped`,

  };

  if (topic === 'all') {
    return Object.values(docs).join('\n\n---\n\n');
  }
  return docs[topic] || `Unknown topic '${topic}'. Available: ${Object.keys(docs).join(', ')}`;
}

// MCP Protocol - stdio transport
class StdioTransport {
  constructor() {
    this.buffer = '';
    this.expectedLength = null;
    this.setupStdio();
  }
  
  setupStdio() {
    // Read from stdin
    process.stdin.setEncoding('utf-8');
    
    process.stdin.on('data', (chunk) => {
      log('📥 stdin data received:', chunk.length, 'bytes');
      this.buffer += chunk.toString();
      this.processBuffer();
    });
    
    process.stdin.on('end', () => {
      log('stdin closed');
      process.exit(0);
    });
    
    process.stdin.on('error', (err) => {
      log('stdin error:', err);
    });
    
    log('✅ stdin setup complete');
  }
  
  processBuffer() {
    log(`📊 processBuffer - buffer: ${this.buffer.length} bytes, expectedLength: ${this.expectedLength}`);
    
    while (true) {
      if (this.expectedLength === null) {
        // Try MCP standard format first: Content-Length header
        const headerEnd = this.buffer.indexOf('\r\n\r\n');
        
        if (headerEnd !== -1) {
          // Standard MCP format with Content-Length header
          log('✅ MCP standard format detected (has \\r\\n\\r\\n)');
          
          const headers = this.buffer.slice(0, headerEnd);
          const match = /Content-Length: *(\d+)/i.exec(headers);
          
          if (match) {
            this.expectedLength = parseInt(match[1], 10);
            log(`📦 Expecting ${this.expectedLength} bytes`);
            this.buffer = this.buffer.slice(headerEnd + 4);
          } else {
            log('No Content-Length header found, skipping');
            this.buffer = this.buffer.slice(headerEnd + 4);
            continue;
          }
        } else {
          // Try alternative format: just JSON with \n or newline
          const newlineIndex = this.buffer.indexOf('\n');
          
          if (newlineIndex !== -1) {
            log('📝 Simplified format detected (newline-delimited JSON)');
            
            // Try to parse as complete JSON object
            const potentialMessage = this.buffer.slice(0, newlineIndex);
            
            try {
              // Test if it's valid JSON
              const testParse = JSON.parse(potentialMessage);
              log('✅ Valid JSON found at newline boundary');
              
              this.handleRequest(testParse).catch(err => {
                log('Error handling request:', err);
              });
              
              this.buffer = this.buffer.slice(newlineIndex + 1);
              continue;
            } catch (e) {
              log('⚠️ Not valid JSON at newline, waiting for more data...');
              break;
            }
          } else {
            log('⏳ Waiting for complete message (no newline found)...');
            break;
          }
        }
      }
      
      if (this.expectedLength !== null && this.buffer.length >= this.expectedLength) {
        const message = this.buffer.slice(0, this.expectedLength);
        this.buffer = this.buffer.slice(this.expectedLength);
        this.expectedLength = null;
        
        try {
          const request = JSON.parse(message);
          this.handleRequest(request).catch(err => {
            log('Error handling request:', err);
          });
        } catch (e) {
          log('Failed to parse message:', e.message);
        }
        
        continue;
      }
      
      break;
    }
  }
  
  async handleRequest(request) {
    log(`🔵 handleRequest START - Method: ${request.method}, ID: ${request.id}`);
    
    try {
      let result;
      
      // Handle MCP protocol methods
      if (request.method === 'initialize') {
        log('🟦 Calling handleInitialize...');
        result = await this.handleInitialize(request.params);
        log('🟩 handleInitialize returned:', JSON.stringify(result));
      } else if (request.method === 'tools/list') {
        log('🟦 Calling handleToolsList...');
        result = await this.handleToolsList();
      } else if (request.method === 'tools/call') {
        log('🟦 Calling handleToolCall...');
        result = await this.handleToolCall(request.params);
      } else if (request.method?.startsWith('notifications/')) {
        // Handle notifications (no response needed)
        log(`📢 Received notification: ${request.method}`);
        return;
      } else {
        // Unknown method
        log('⚠️ Unknown method:', request.method);
        this.sendResponse({
          jsonrpc: '2.0',
          id: request.id,
          error: {
            code: -32601,
            message: `Method not found: ${request.method}`
          }
        });
        return;
      }
      
      log(`🟩 Calling sendResponse for request ID ${request.id}`);
      this.sendResponse({
        jsonrpc: '2.0',
        id: request.id,
        result
      });
      log('🟩 sendResponse completed');
    } catch (error) {
      log('❌ Error:', error);
      this.sendResponse({
        jsonrpc: '2.0',
        id: request.id,
        error: {
          code: -32603,
          message: error.message
        }
      });
    }
  }
  
  async handleInitialize(params) {
    log('Initialize with params:', params);
    return {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: 'vpy-ide-mcp',
        version: '0.1.0'
      }
    };
  }
  
  async handleToolsList() {
    return {
      tools: [
        {
          name: 'editor_list_documents',
          description: 'List all open documents in the IDE',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'editor_read_document',
          description: 'Read content of a specific document',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' }
            },
            required: ['uri']
          }
        },
        {
          name: 'editor_write_document',
          description: 'Create OR update a document (automatically opens in editor if new). Use this to create any text file. For .vec and .vmus files, prefer project_create_vector/project_create_music which validate JSON format. CRITICAL VPy RULES: 1) Variables in main() are NOT accessible in loop() - each function has separate scope. Declare variables inside loop() where they are used, NOT in main(). 2) ALWAYS call WAIT_RECAL() at the START of loop() function - this is MANDATORY for proper frame synchronization. 3) Each DRAW_LINE call repositions the beam (creates gaps) - for connected shapes use vector assets (project_create_vector) or coordinate multiple calls carefully. Example: def loop():\n    WAIT_RECAL()  # MANDATORY FIRST\n    # your drawing code',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI or relative path (e.g., "src/game.vpy", "README.md")' },
              content: { type: 'string', description: 'Complete file content' }
            },
            required: ['uri', 'content']
          }
        },
        {
          name: 'editor_save_document',
          description: 'Save an open document to disk and mark as clean. CRITICAL: Use this after editor_write_document before compilation to ensure compiler reads latest content.',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI (file must be open in editor)' }
            },
            required: ['uri']
          }
        },
        {
          name: 'editor_replace_range',
          description: 'Replace text in a specific range of a document',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' },
              startLine: { type: 'number', description: 'Start line (1-indexed)' },
              startColumn: { type: 'number', description: 'Start column (1-indexed)' },
              endLine: { type: 'number', description: 'End line (1-indexed)' },
              endColumn: { type: 'number', description: 'End column (1-indexed)' },
              newText: { type: 'string', description: 'New text to insert' }
            },
            required: ['uri', 'startLine', 'startColumn', 'endLine', 'endColumn', 'newText']
          }
        },
        {
          name: 'editor_insert_at',
          description: 'Insert text at a specific position',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' },
              line: { type: 'number', description: 'Line number (1-indexed)' },
              column: { type: 'number', description: 'Column number (1-indexed)' },
              text: { type: 'string', description: 'Text to insert' }
            },
            required: ['uri', 'line', 'column', 'text']
          }
        },
        {
          name: 'editor_delete_range',
          description: 'Delete text in a specific range',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' },
              startLine: { type: 'number', description: 'Start line (1-indexed)' },
              startColumn: { type: 'number', description: 'Start column (1-indexed)' },
              endLine: { type: 'number', description: 'End line (1-indexed)' },
              endColumn: { type: 'number', description: 'End column (1-indexed)' }
            },
            required: ['uri', 'startLine', 'startColumn', 'endLine', 'endColumn']
          }
        },
        {
          name: 'editor_get_diagnostics',
          description: 'Get compilation/lint diagnostics',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI (optional)' }
            }
          }
        },
        {
          name: 'compiler_build',
          description: 'Build the current project (equivalent to pressing F7). Compiles the project entry file automatically. No parameters needed.',
          inputSchema: {
            type: 'object',
            properties: {},
            required: []
          }
        },
        {
          name: 'compiler_get_errors',
          description: 'Get latest compilation errors',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'compiler_build_and_run',
          description: 'Build current project and run it in emulator (combines compiler_build + emulator_run). Use this for quick testing. Returns compilation errors if build fails.',
          inputSchema: {
            type: 'object',
            properties: {
              breakOnEntry: { type: 'boolean', description: 'Pause at entry point (optional)' }
            },
            required: []
          }
        },
        {
          name: 'emulator_run',
          description: 'Run a compiled ROM in the emulator',
          inputSchema: {
            type: 'object',
            properties: {
              romPath: { type: 'string', description: 'Path to .bin ROM file' },
              breakOnEntry: { type: 'boolean', description: 'Pause at entry point' }
            },
            required: ['romPath']
          }
        },
        {
          name: 'emulator_get_state',
          description: 'Get current emulator state (PC, registers, cycles)',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'emulator_stop',
          description: 'Stop emulator execution',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'memory_dump',
          description: 'Get memory snapshot from emulator RAM. Returns hex dump of specified region. Useful for debugging and analyzing program state.',
          inputSchema: {
            type: 'object',
            properties: {
              start: { type: 'number', description: 'Start address (hex or decimal, default: 0xC800 = RAM start)' },
              end: { type: 'number', description: 'End address (hex or decimal, default: 0xCFFF = RAM end)' },
              format: { type: 'string', description: 'Output format: "hex" (default) or "decimal"', enum: ['hex', 'decimal'] }
            }
          }
        },
        {
          name: 'memory_list_variables',
          description: 'Get all variables from PDB with addresses, sizes, and types. Sorted by size (largest first). Useful for identifying which variables consume most RAM and which ones could be converted to const arrays to save space.',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'memory_read_variable',
          description: 'Read current value of a specific variable from emulator RAM. Returns value in both hex and decimal formats.',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Variable name (without VAR_ prefix, e.g., "player_x")' }
            },
            required: ['name']
          }
        },
        {
          name: 'debugger_add_breakpoint',
          description: 'Add a breakpoint at a specific line',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' },
              line: { type: 'number', description: 'Line number (1-indexed)' }
            },
            required: ['uri', 'line']
          }
        },
        {
          name: 'debugger_get_callstack',
          description: 'Get current call stack',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'project_get_structure',
          description: 'Get project structure and files',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'project_read_file',
          description: 'Read any file from the project',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'File path relative to project root' }
            },
            required: ['path']
          }
        },
        {
          name: 'project_write_file',
          description: 'Write any file in the project (VPy code, config, text files, etc.). For .vec or .vmus files, prefer project_create_vector/project_create_music which validate JSON format and provide templates. Automatically opens file in editor.',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'File path relative to project root (e.g., "src/main.vpy", "README.md", "config.json")' },
              content: { type: 'string', description: 'Complete file content' }
            },
            required: ['path', 'content']
          }
        },
        {
          name: 'project_create',
          description: 'Create a new VPy project. If path is not provided, a folder selection dialog will be shown to the user.',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Project name' },
              path: { type: 'string', description: 'Project directory path (optional, will prompt user if not provided)' }
            },
            required: ['name']
          }
        },
        {
          name: 'project_close',
          description: 'Close the current project',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'project_open',
          description: 'Open an existing VPy project',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Project directory path' }
            },
            required: ['path']
          }
        },
        {
          name: 'project_create_vector',
          description: 'Create .vec vector graphics file for VPy games (JSON format ONLY). Assets are auto-discovered in assets/vectors/ and embedded in ROM at compile time. Use in code: DRAW_VECTOR("name"). Structure: {"version":"1.0","name":"shape","canvas":{"width":256,"height":256,"origin":"center"},"layers":[{"name":"default","visible":true,"paths":[{"name":"line1","intensity":127,"closed":false,"points":[{"x":0,"y":0},{"x":10,"y":10}]}]}]}. Each path has points array with x,y coordinates (-127 to 127). Triangle example: points:[{"x":0,"y":20},{"x":-15,"y":-10},{"x":15,"y":-10}], closed:true. NO text format - JSON only.',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Vector file name (without .vec extension)' },
              content: { type: 'string', description: 'Valid JSON string matching exact format: {"version":"1.0","name":"...","canvas":{...},"layers":[{"paths":[{"points":[...]}]}]}. Leave empty for template.' }
            },
            required: ['name']
          }
        },
        {
          name: 'project_create_music',
          description: 'Create .vmus music file for VPy games (JSON format ONLY). Assets are auto-discovered in assets/music/ and embedded in ROM at compile time. Use in code: PLAY_MUSIC("name"). Structure: {"version":"1.0","name":"Song","author":"Composer","tempo":120,"ticksPerBeat":24,"totalTicks":384,"notes":[{"id":"note1","note":60,"start":0,"duration":48,"velocity":12,"channel":0}],"noise":[{"id":"noise1","start":0,"duration":24,"period":15,"channels":1}],"loopStart":0,"loopEnd":384}. note: MIDI number (60=C4), velocity: 0-15 (volume), channel: 0-2 (PSG A/B/C), period: 0-31 (noise pitch). NO text format - JSON only.',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Music file name (without .vmus extension)' },
              content: { type: 'string', description: 'Valid JSON string matching exact format: {"version":"1.0","tempo":120,"notes":[...],"noise":[...]}. Leave empty for template.' }
            },
            required: ['name']
          }
        },
        {
          name: 'debugger_start',
          description: 'Start debugging session (Ctrl+F5) - compiles and loads with breakpoints',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_remove_breakpoint',
          description: 'Remove a breakpoint at a specific line',
          inputSchema: {
            type: 'object',
            properties: {
              uri: { type: 'string', description: 'Document URI' },
              line: { type: 'number', description: 'Line number (1-indexed)' }
            },
            required: ['uri', 'line']
          }
        },
        {
          name: 'debugger_list_breakpoints',
          description: 'List all active breakpoints',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_clear_breakpoints',
          description: 'Clear all breakpoints',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_step_into',
          description: 'Step Into (F11) - enter functions',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_step_over',
          description: 'Step Over (F10) - execute without entering functions',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_step_out',
          description: 'Step Out (Shift+F11) - exit current function',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_continue',
          description: 'Continue execution (F5) until next breakpoint',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_pause',
          description: 'Pause execution',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'debugger_get_registers',
          description: 'Get current CPU register values (A, B, X, Y, U, S, PC, DP, CC)',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'memory_dump',
          description: 'Get memory snapshot (hex dump of RAM region)',
          inputSchema: {
            type: 'object',
            properties: {
              address: { type: 'number', description: 'Start address (decimal or 0xHEX)' },
              size: { type: 'number', description: 'Number of bytes to read (default: 256, max: 4096)' }
            },
            required: ['address']
          }
        },
        {
          name: 'memory_list_variables',
          description: 'Get all variables from PDB with sizes and types (sorted by size, largest first)',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'memory_read_variable',
          description: 'Read current value of specific variable from emulator',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Variable name (e.g., "LEVEL_GP_COUNT", "player_x")' }
            },
            required: ['name']
          }
        },
        {
          name: 'memory_write',
          description: 'Write value to memory address for testing/debugging',
          inputSchema: {
            type: 'object',
            properties: {
              address: { type: 'number', description: 'Memory address (hex or decimal, 0xC800-0xCFFF for RAM)' },
              value: { type: 'number', description: 'Value to write (0-255 for 8-bit, 0-65535 for 16-bit)' },
              size: { type: 'number', description: '1 or 2 bytes (default: 1)' }
            },
            required: ['address', 'value']
          }
        },
        {
          name: 'get_project_docs',
          description: 'Get detailed project documentation for a specific topic. Call this WHENEVER you need technical details about this VPy/Vectrex project. Available topics: assets, joystick, buttons, const_arrays, modules, banking, draw_line, music, compiler, bios, tests, meta',
          inputSchema: {
            type: 'object',
            properties: {
              topic: {
                type: 'string',
                description: 'Topic name. One of: assets, joystick, buttons, const_arrays, modules, banking, draw_line, music, compiler, bios, tests, meta, all',
                enum: ['assets', 'joystick', 'buttons', 'const_arrays', 'modules', 'banking', 'draw_line', 'music', 'compiler', 'bios', 'tests', 'meta', 'all']
              }
            },
            required: ['topic']
          }
        }
      ]
    };
  }
  
  async handleToolCall(params) {
    const { name, arguments: args } = params;
    log('Tool call:', name, 'Arguments:', JSON.stringify(args));

    // Handle get_project_docs locally (no IPC needed)
    if (name === 'get_project_docs') {
      const topic = (args && args.topic) ? args.topic : 'all';
      const docs = getProjectDocs(topic);
      return { content: [{ type: 'text', text: docs }] };
    }
    
    // Convert tool name to method (editor_list_documents -> editor/list_documents)
    // Only replace first underscore with slash to match Electron server naming
    const method = name.replace('_', '/');
    
    // Ensure args is an object (MCP spec may send undefined for no arguments)
    const toolParams = args || {};
    log('Forwarding to IDE - Method:', method, 'Params:', JSON.stringify(toolParams));
    
    // Forward to IDE via IPC
    const result = await sendToIDE({
      jsonrpc: '2.0',
      method,
      params: toolParams
    });
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(result, null, 2)
        }
      ]
    };
  }
  
  sendResponse(response) {
    const message = JSON.stringify(response);
    
    log('📤 Sending response to stdout:');
    log('  - ID:', response.id);
    log('  - Has result:', !!response.result);
    log('  - Has error:', !!response.error);
    log('  - Message length:', message.length);
    
    // Send as newline-delimited JSON (compatible with Copilot's simplified format)
    // No Content-Length headers needed
    process.stdout.write(message + '\n');
    log('✅ Response written to stdout');
  }
}

// Main
async function main() {
  log('VPy IDE MCP Server starting...');
  
  try {
    // Connect to IDE (skipped if --stdio mode)
    await connectToIDE();
    log('Connected to IDE');
    
    // Start stdio transport
    const transport = new StdioTransport();
    log('MCP server ready on stdio');
    
    // Keep process alive - listen for signals
    process.on('SIGINT', () => {
      log('Received SIGINT, exiting gracefully...');
      process.exit(0);
    });
    
    process.on('SIGTERM', () => {
      log('Received SIGTERM, exiting gracefully...');
      process.exit(0);
    });
    
    log('MCP server is now listening on stdio (waiting for requests from Copilot)');
    
    // Prevent process from exiting immediately
    await new Promise(() => {
      // This promise never resolves, keeping the process alive
    });
    
  } catch (error) {
    console.error('Failed to start MCP server:', error.message);
    if (!process.argv.includes('--stdio')) {
      console.error('Make sure the VPy IDE is running with MCP IPC enabled');
    }
    process.exit(1);
  }
}

main();
