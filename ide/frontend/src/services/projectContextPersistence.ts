/**
 * Project Context Persistence Service
 * 
 * Stores and retrieves project context so PyPilot AI Assistant can maintain
 * awareness of:
 * - Current project (name, path)
 * - Created files (main.vpy, modules, etc.)
 * - Created assets (vector files, music files)
 * 
 * This prevents PyPilot from losing context when switching between queries.
 */

export interface ProjectContext {
  projectName: string;
  projectPath: string;
  createdFiles: string[]; // e.g., ['main.vpy', 'sprites.vpy', 'sounds.vpy']
  assets: {
    vectors: string[]; // e.g., ['player.vec', 'enemy.vec']
    music: string[]; // e.g., ['theme.vmus', 'boss_music.vmus']
  };
  lastUpdated: number; // timestamp
}

const STORAGE_KEY = 'pypilot_project_context';

export class ProjectContextPersistence {
  /**
   * Save project context to localStorage
   */
  static saveProjectContext(context: ProjectContext): void {
    try {
      const data = {
        ...context,
        lastUpdated: Date.now()
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      console.log('[ProjectContext] Saved:', data);
    } catch (error) {
      console.error('[ProjectContext] Error saving:', error);
    }
  }

  /**
   * Load project context from localStorage
   */
  static loadProjectContext(): ProjectContext | null {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (!saved) return null;

      const data = JSON.parse(saved) as ProjectContext;
      console.log('[ProjectContext] Loaded:', data);
      return data;
    } catch (error) {
      console.error('[ProjectContext] Error loading:', error);
      return null;
    }
  }

  /**
   * Clear project context (when closing project)
   */
  static clearProjectContext(): void {
    try {
      localStorage.removeItem(STORAGE_KEY);
      console.log('[ProjectContext] Cleared');
    } catch (error) {
      console.error('[ProjectContext] Error clearing:', error);
    }
  }

  /**
   * Add created file to project context
   */
  static addCreatedFile(fileName: string): void {
    const context = this.loadProjectContext();
    if (!context) return;

    if (!context.createdFiles.includes(fileName)) {
      context.createdFiles.push(fileName);
      this.saveProjectContext(context);
      console.log('[ProjectContext] Added file:', fileName);
    }
  }

  /**
   * Add vector asset to project context
   */
  static addVectorAsset(vectorName: string): void {
    const context = this.loadProjectContext();
    if (!context) return;

    if (!context.assets.vectors.includes(vectorName)) {
      context.assets.vectors.push(vectorName);
      this.saveProjectContext(context);
      console.log('[ProjectContext] Added vector asset:', vectorName);
    }
  }

  /**
   * Add music asset to project context
   */
  static addMusicAsset(musicName: string): void {
    const context = this.loadProjectContext();
    if (!context) return;

    if (!context.assets.music.includes(musicName)) {
      context.assets.music.push(musicName);
      this.saveProjectContext(context);
      console.log('[ProjectContext] Added music asset:', musicName);
    }
  }

  /**
   * Generate context string for PyPilot to include in system prompt
   */
  static getContextString(): string {
    const context = this.loadProjectContext();
    if (!context) return '';

    let contextStr = `\n## Current Project:
- **Name**: ${context.projectName}
- **Path**: ${context.projectPath}

## Created Files:
${context.createdFiles.length > 0 
  ? context.createdFiles.map(f => `- ${f}`).join('\n')
  : 'None'}

## Assets:
### Vectors:
${context.assets.vectors.length > 0
  ? context.assets.vectors.map(v => `- ${v}`).join('\n')
  : 'None'}

### Music:
${context.assets.music.length > 0
  ? context.assets.music.map(m => `- ${m}`).join('\n')
  : 'None'}
`;

    return contextStr;
  }

  /**
   * Create initial project context
   */
  static createProjectContext(projectName: string, projectPath: string): ProjectContext {
    return {
      projectName,
      projectPath,
      createdFiles: [],
      assets: {
        vectors: [],
        music: []
      },
      lastUpdated: Date.now()
    };
  }

  /**
   * Check if context is stale (older than 1 hour)
   */
  static isContextStale(): boolean {
    const context = this.loadProjectContext();
    if (!context) return true;

    const oneHourAgo = Date.now() - (60 * 60 * 1000);
    return context.lastUpdated < oneHourAgo;
  }
}
