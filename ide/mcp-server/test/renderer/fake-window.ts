// Fake browser globals, installed BEFORE mcpBridge.ts loads (it subscribes to run:// output at load).
const listeners: Record<string, (c: string) => void> = {};
(globalThis as any).window = globalThis;
(globalThis as any).localStorage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
(globalThis as any).electronAPI = {
  onRunStdout: (cb: any) => { listeners.out = cb; },
  onRunStderr: (cb: any) => { listeners.err = cb; },
  onRunStatus: (cb: any) => { listeners.status = cb; },
};
(globalThis as any).CustomEvent = class { constructor(public type: string, public init: any) {} };
(globalThis as any).dispatchEvent = () => true;
export { listeners };
