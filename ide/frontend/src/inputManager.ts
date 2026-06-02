// Basic input manager mapping keyboard + (future) gamepad to joystick state.
// Joystick range: -128..127. Buttons: bits 0..3.
// Keys: ArrowLeft/Right/Up/Down or WASD. Buttons: Z,X,C,V (bits 0..3) as a starter.

export interface InputSnapshot { x:number; y:number; buttons:number; }

class InputManager {
  private snapshot: InputSnapshot = { x:0, y:0, buttons:0 };
  private keys: Record<string, boolean> = {};
  private gamepadIndex: number | null = null;

  constructor(){
    window.addEventListener('keydown', e=>{ this.keys[e.code]=true; });
    window.addEventListener('keyup', e=>{ this.keys[e.code]=false; });
    window.addEventListener('gamepadconnected', e=>{ if (this.gamepadIndex==null) this.gamepadIndex = (e as GamepadEvent).gamepad.index; });
    window.addEventListener('gamepaddisconnected', e=>{ if ((e as GamepadEvent).gamepad.index === this.gamepadIndex) this.gamepadIndex = null; });
  }

  private pollGamepad(){
    if (this.gamepadIndex==null) return { gx:0, gy:0, gButtons:0 };
    const gp = navigator.getGamepads()[this.gamepadIndex];
    if (!gp) return { gx:0, gy:0, gButtons:0 };
    // Assume axes[0]=x, axes[1]=y analog in -1..1
    const ax = gp.axes[0] || 0; const ay = gp.axes[1] || 0;
    const gx = Math.max(-128, Math.min(127, Math.round(ax * 127)));
    const gy = Math.max(-128, Math.min(127, Math.round(ay * 127)));
    // Map first 4 face buttons (0..3) to bits 0..3
    let gButtons = 0;
    for (let i=0;i<4;i++){ if (gp.buttons[i]?.pressed) gButtons |= (1<<i); }
    return { gx, gy, gButtons };
  }

  update(): InputSnapshot {
    // Keyboard digital -> immediate edges (no smoothing yet)
    let kx = 0, ky = 0;
    if (this.keys['ArrowLeft'] || this.keys['KeyA']) kx -= 127;
    if (this.keys['ArrowRight'] || this.keys['KeyD']) kx += 127;
    if (this.keys['ArrowUp'] || this.keys['KeyW']) ky += 127; // Y positive up in our logical model
    if (this.keys['ArrowDown'] || this.keys['KeyS']) ky -= 127;
    // Buttons: Z,X,C,V
    let kbButtons = 0;
    if (this.keys['KeyZ']) kbButtons |= 0x01;
    if (this.keys['KeyX']) kbButtons |= 0x02;
    if (this.keys['KeyC']) kbButtons |= 0x04;
    if (this.keys['KeyV']) kbButtons |= 0x08;

    const { gx, gy, gButtons } = this.pollGamepad();

    // Prefer analog gamepad if moved; else keyboard
    const useGamepad = (Math.abs(gx)>0 || Math.abs(gy)>0);
    const x = useGamepad ? gx : kx;
    const y = useGamepad ? gy : ky;
    // Always merge gamepad buttons — face buttons work even when axis is centred
    const buttons = gButtons | kbButtons;

    this.snapshot = { x, y, buttons };
    return this.snapshot;
  }

  getSnapshot(){ return this.snapshot; }
}

export const inputManager = new InputManager();
