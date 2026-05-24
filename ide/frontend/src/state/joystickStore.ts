import { create } from 'zustand';

export interface ButtonMapping {
  vectrexButton: number; // 1-4 (Vectrex buttons)
  gamepadButton: number; // Gamepad button index
}

export interface JoystickConfig {
  gamepadIndex: number | null;
  gamepadName: string | null;
  // Player 2 — pick a second gamepad. Axis indices / button mappings are
  // shared with P1 for simplicity (same controller model usually). Null
  // means "no second controller wired" and J2_* reads return zero.
  gamepadIndex2: number | null;
  gamepadName2: string | null;
  // Analog stick configuration
  axisXIndex: number; // Default 0 (left stick horizontal)
  axisYIndex: number; // Default 1 (left stick vertical)
  axisXInverted: boolean;
  axisYInverted: boolean;
  deadzone: number; // 0-1, default 0.15
  // D-Pad configuration (for digital input)
  dpadUpButton: number;    // Default 12
  dpadDownButton: number;  // Default 13
  dpadLeftButton: number;  // Default 14
  dpadRightButton: number; // Default 15
  buttonMappings: ButtonMapping[];
}

interface JoystickStore extends JoystickConfig {
  isConfigOpen: boolean;
  connectedGamepads: Gamepad[];
  setConfigOpen: (open: boolean) => void;
  updateGamepads: (gamepads: Gamepad[]) => void;
  selectGamepad: (index: number, name: string) => void;
  selectGamepad2: (index: number | null, name: string | null) => void;
  setAxisXIndex: (index: number) => void;
  setAxisYIndex: (index: number) => void;
  setAxisXInverted: (inverted: boolean) => void;
  setAxisYInverted: (inverted: boolean) => void;
  setDeadzone: (deadzone: number) => void;
  setDpadUpButton: (button: number) => void;
  setDpadDownButton: (button: number) => void;
  setDpadLeftButton: (button: number) => void;
  setDpadRightButton: (button: number) => void;
  setButtonMapping: (vectrexButton: number, gamepadButton: number) => void;
  clearButtonMapping: (vectrexButton: number) => void;
  resetConfig: () => void;
  loadConfig: () => void;
  saveConfig: () => void;
}

const defaultConfig: JoystickConfig = {
  gamepadIndex: null,
  gamepadName: null,
  gamepadIndex2: null,
  gamepadName2: null,
  axisXIndex: 0,
  axisYIndex: 1,
  axisXInverted: false,
  axisYInverted: false,
  deadzone: 0.15,
  dpadUpButton: 12,    // Standard D-Pad Up
  dpadDownButton: 13,  // Standard D-Pad Down
  dpadLeftButton: 14,  // Standard D-Pad Left
  dpadRightButton: 15, // Standard D-Pad Right
  buttonMappings: [
    { vectrexButton: 1, gamepadButton: 0 }, // A/Cross
    { vectrexButton: 2, gamepadButton: 1 }, // B/Circle
    { vectrexButton: 3, gamepadButton: 2 }, // X/Square
    { vectrexButton: 4, gamepadButton: 3 }, // Y/Triangle
  ],
};

const STORAGE_KEY = 'vectrex_joystick_config';

export const useJoystickStore = create<JoystickStore>((set, get) => ({
  ...defaultConfig,
  isConfigOpen: false,
  connectedGamepads: [],

  setConfigOpen: (open) => set({ isConfigOpen: open }),

  updateGamepads: (gamepads) => set({ connectedGamepads: gamepads }),

  selectGamepad: (index, name) => {
    set({ gamepadIndex: index, gamepadName: name });
    get().saveConfig();
  },

  selectGamepad2: (index, name) => {
    set({ gamepadIndex2: index, gamepadName2: name });
    get().saveConfig();
  },

  setAxisXIndex: (index) => {
    set({ axisXIndex: index });
    get().saveConfig();
  },

  setAxisYIndex: (index) => {
    set({ axisYIndex: index });
    get().saveConfig();
  },

  setAxisXInverted: (inverted) => {
    set({ axisXInverted: inverted });
    get().saveConfig();
  },

  setAxisYInverted: (inverted) => {
    set({ axisYInverted: inverted });
    get().saveConfig();
  },

  setDeadzone: (deadzone) => {
    set({ deadzone });
    get().saveConfig();
  },

  setDpadUpButton: (button) => {
    set({ dpadUpButton: button });
    get().saveConfig();
  },

  setDpadDownButton: (button) => {
    set({ dpadDownButton: button });
    get().saveConfig();
  },

  setDpadLeftButton: (button) => {
    set({ dpadLeftButton: button });
    get().saveConfig();
  },

  setDpadRightButton: (button) => {
    set({ dpadRightButton: button });
    get().saveConfig();
  },

  setButtonMapping: (vectrexButton, gamepadButton) => {
    const state = get();
    const newMappings = [...state.buttonMappings];
    const existing = newMappings.findIndex(m => m.vectrexButton === vectrexButton);
    
    if (existing !== -1) {
      newMappings[existing] = { vectrexButton, gamepadButton };
    } else {
      newMappings.push({ vectrexButton, gamepadButton });
    }
    
    set({ buttonMappings: newMappings });
    get().saveConfig();
  },

  clearButtonMapping: (vectrexButton) => {
    const state = get();
    const newMappings = state.buttonMappings.filter(m => m.vectrexButton !== vectrexButton);
    set({ buttonMappings: newMappings });
    get().saveConfig();
  },

  resetConfig: () => {
    set(defaultConfig);
    get().saveConfig();
  },

  loadConfig: () => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const config = JSON.parse(saved) as JoystickConfig;
        set(config);
      }
    } catch (error) {
      console.error('[JoystickStore] Failed to load config:', error);
    }
  },

  saveConfig: () => {
    try {
      const state = get();
      const config: JoystickConfig = {
        gamepadIndex: state.gamepadIndex,
        gamepadName: state.gamepadName,
        gamepadIndex2: state.gamepadIndex2,
        gamepadName2: state.gamepadName2,
        axisXIndex: state.axisXIndex,
        axisYIndex: state.axisYIndex,
        axisXInverted: state.axisXInverted,
        axisYInverted: state.axisYInverted,
        deadzone: state.deadzone,
        dpadUpButton: state.dpadUpButton,
        dpadDownButton: state.dpadDownButton,
        dpadLeftButton: state.dpadLeftButton,
        dpadRightButton: state.dpadRightButton,
        buttonMappings: state.buttonMappings,
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
    } catch (error) {
      console.error('[JoystickStore] Failed to save config:', error);
    }
  },
}));
