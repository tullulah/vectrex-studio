// Simple event bus for docking actions
// Events: toggle:<component>, resetLayout, dockChanged
// Components: files | editor | emulator | debug | errors | output | memory | trace | psglog | bioscalls | callstack | build-output | compiler-output | playground | terminal
// (memory + trace + bioscalls + psglog added for new panels; unify handling so they can be hidden/pinned like others)
export type DockComponent = 'files' | 'editor' | 'emulator' | 'debug' | 'errors' | 'output' | 'memory' | 'trace' | 'psglog' | 'bioscalls' | 'callstack' | 'ai-assistant' | 'build-output' | 'compiler-output' | 'playground' | 'terminal';
export type DockEvent =
  | { type: 'toggle'; component: DockComponent } // legacy toggle (may remove later)
  | { type: 'ensure'; component: DockComponent } // ensure exists (create if missing)
  | { type: 'focus'; component: DockComponent }  // focus existing (no creation)
  | { type: 'reset' }
  | { type: 'changed' };

export type DockListener = (ev: DockEvent) => void;

class DockBus {
  private listeners: Set<DockListener> = new Set();
  emit(ev: DockEvent) {
    this.listeners.forEach(l => l(ev));
  }
  on(listener: DockListener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export const dockBus = new DockBus();

export function toggleComponent(component: DockComponent) {
  dockBus.emit({ type: 'toggle', component });
}

export function ensureComponent(component: DockComponent) {
  dockBus.emit({ type: 'ensure', component });
}

export function focusComponent(component: DockComponent) {
  dockBus.emit({ type: 'focus', component });
}

export function resetLayout() {
  dockBus.emit({ type: 'reset' });
}

export function notifyDockChanged() {
  dockBus.emit({ type: 'changed' });
}
