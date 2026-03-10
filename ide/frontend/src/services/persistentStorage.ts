/**
 * Persistent Storage Service
 * 
 * Wraps Electron's filesystem-based storage to provide a localStorage-like API
 * that persists across sessions and won't be cleared by browser dev tools.
 * 
 * Automatically falls back to localStorage in browser environments (development).
 */

declare global {
  interface Window {
    storage?: {
      get: (key: string) => Promise<any>;
      set: (key: string, value: any) => Promise<boolean>;
      delete: (key: string) => Promise<boolean>;
      keys: () => Promise<string[]>;
      clear: () => Promise<boolean>;
      getPath: () => Promise<string>;
      getKeys: () => Promise<Record<string, string>>;
    };
  }
}

const isElectron = typeof window !== 'undefined' && window.storage !== undefined;

/**
 * Storage Keys - Use these constants to avoid typos
 */
export const StorageKey = {
  // AI Assistant
  PYPILOT_CONVERSATION: 'pypilot_conversation.json',
  PYPILOT_PROVIDER: 'pypilot_provider.json',
  PYPILOT_CONCISE: 'pypilot_concise.json',
  pypilotConfig: (provider: string) => `pypilot_config_${provider}.json`,
  
  // Editor state
  EDITOR_PERSISTENCE: 'editor_state.json',
  DOCK_LAYOUT: 'dock_layout.json',
  DOCK_HIDDEN_PANELS: 'dock_hidden.json',
  DOCK_PINNED_PANELS: 'dock_pinned.json',
  
  // Emulator
  EMU_BACKEND: 'emu_backend.json',
  
  // EPROM programmer
  EPROM_CHIP_CONFIGS: 'eprom_chip_configs.json',
  
  // Logging
  LOG_CONFIG: 'log_config.json',
} as const;

/**
 * Get a value from persistent storage
 */
export async function storageGet<T = any>(key: string): Promise<T | null> {
  if (isElectron) {
    try {
      return await window.storage!.get(key);
    } catch (error) {
      console.error(`[Storage] Error reading ${key}:`, error);
      return null;
    }
  } else {
    // Fallback to localStorage (development/browser)
    try {
      const value = localStorage.getItem(key.replace('.json', ''));
      return value ? JSON.parse(value) : null;
    } catch (error) {
      console.error(`[Storage] localStorage error reading ${key}:`, error);
      return null;
    }
  }
}

/**
 * Set a value in persistent storage
 */
export async function storageSet(key: string, value: any): Promise<boolean> {
  if (isElectron) {
    try {
      return await window.storage!.set(key, value);
    } catch (error) {
      console.error(`[Storage] Error writing ${key}:`, error);
      return false;
    }
  } else {
    // Fallback to localStorage (development/browser)
    try {
      localStorage.setItem(key.replace('.json', ''), JSON.stringify(value));
      return true;
    } catch (error) {
      console.error(`[Storage] localStorage error writing ${key}:`, error);
      return false;
    }
  }
}

/**
 * Delete a value from persistent storage
 */
export async function storageDelete(key: string): Promise<boolean> {
  if (isElectron) {
    try {
      return await window.storage!.delete(key);
    } catch (error) {
      console.error(`[Storage] Error deleting ${key}:`, error);
      return false;
    }
  } else {
    // Fallback to localStorage (development/browser)
    try {
      localStorage.removeItem(key.replace('.json', ''));
      return true;
    } catch (error) {
      console.error(`[Storage] localStorage error deleting ${key}:`, error);
      return false;
    }
  }
}

/**
 * Get storage location (for debugging)
 */
export async function getStoragePath(): Promise<string> {
  if (isElectron) {
    try {
      return await window.storage!.getPath();
    } catch (error) {
      return 'Error getting storage path';
    }
  } else {
    return 'localStorage (browser)';
  }
}

/**
 * Migrate data from localStorage to persistent storage
 * Call this once on app startup
 */
export async function migrateFromLocalStorage(): Promise<void> {
  if (!isElectron) {
    console.log('[Storage] Running in browser, no migration needed');
    return;
  }
  
  console.log('[Storage] Starting migration from localStorage...');
  
  const migrations: Record<string, string> = {
    'pypilot_conversation': StorageKey.PYPILOT_CONVERSATION,
    'pypilot_provider': StorageKey.PYPILOT_PROVIDER,
    'pypilot_concise': StorageKey.PYPILOT_CONCISE,
    'vpy_editor_docs': StorageKey.EDITOR_PERSISTENCE,
    'vpy_dock_layout': StorageKey.DOCK_LAYOUT,
    'vpy_dock_hidden': StorageKey.DOCK_HIDDEN_PANELS,
    'vpy_pinned_panels_v1': StorageKey.DOCK_PINNED_PANELS,
    'emu_backend': StorageKey.EMU_BACKEND,
    'vpy_log_config': StorageKey.LOG_CONFIG,
  };
  
  let migrated = 0;
  let errors = 0;
  
  for (const [oldKey, newKey] of Object.entries(migrations)) {
    const value = localStorage.getItem(oldKey);
    if (value) {
      try {
        const parsed = JSON.parse(value);
        const success = await storageSet(newKey, parsed);
        if (success) {
          migrated++;
          // Clear from localStorage after successful migration
          localStorage.removeItem(oldKey);
          console.log(`[Storage] Migrated: ${oldKey} → ${newKey}`);
        } else {
          errors++;
          console.error(`[Storage] Failed to migrate ${oldKey}`);
        }
      } catch (error) {
        errors++;
        console.error(`[Storage] Error migrating ${oldKey}:`, error);
      }
    }
  }
  
  // Migrate provider-specific configs
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (key && key.startsWith('pypilot_config_')) {
      const value = localStorage.getItem(key);
      if (value) {
        const provider = key.replace('pypilot_config_', '');
        const newKey = StorageKey.pypilotConfig(provider);
        try {
          const parsed = JSON.parse(value);
          const success = await storageSet(newKey, parsed);
          if (success) {
            migrated++;
            localStorage.removeItem(key);
            console.log(`[Storage] Migrated: ${key} → ${newKey}`);
          } else {
            errors++;
          }
        } catch (error) {
          errors++;
          console.error(`[Storage] Error migrating ${key}:`, error);
        }
      }
    }
  }
  
  console.log(`[Storage] Migration complete: ${migrated} items migrated, ${errors} errors`);
  
  // Log storage path for debugging
  const path = await getStoragePath();
  console.log(`[Storage] Data saved to: ${path}`);
}

/**
 * Hook to use persistent storage with React state
 * Similar to useState but persists across sessions
 */
export function usePersistentState<T>(
  key: string,
  defaultValue: T
): [T, (value: T) => Promise<void>, boolean] {
  const [value, setValue] = React.useState<T>(defaultValue);
  const [loading, setLoading] = React.useState(true);
  
  // Load initial value
  React.useEffect(() => {
    storageGet<T>(key).then(stored => {
      if (stored !== null) {
        setValue(stored);
      }
      setLoading(false);
    });
  }, [key]);
  
  // Update function that persists
  const updateValue = React.useCallback(async (newValue: T) => {
    setValue(newValue);
    await storageSet(key, newValue);
  }, [key]);
  
  return [value, updateValue, loading];
}

// Export namespace for React
import * as React from 'react';
