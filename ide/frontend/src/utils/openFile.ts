import { useEditorStore } from '../state/editorStore';
import type { DocumentModel } from '../types/models';

/** The editor language of a file, by its extension. */
export function languageOfFile(filename: string): DocumentModel['language'] {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  switch (ext) {
    case 'vpy': return 'vpy';
    case 'c': return 'c';
    case 'cpp': case 'cc': case 'cxx': return 'cpp';
    case 'h': case 'hpp': return 'cpp';
    case 'asm': case 's': return 'asm';
    case 'json': case 'vec': case 'vmus': case 'vmesh': case 'vscene': case 'vskel': case 'vclip': return 'json';
    case 'js': return 'javascript';
    case 'ts': return 'typescript';
    case 'md': return 'markdown';
    default: return 'plaintext';
  }
}

/** A disk path as the editor's document uri (same form as File > Open). */
export function fileUri(path: string): string {
  const p = path.replace(/\\/g, '/');
  return /^[A-Za-z]:\//.test(p) ? `file:///${p}` : `file://${p}`;
}

/**
 * Open the file at `path` in the editor (its tab when already open, else read from
 * disk) and, given a 0-based `line`, put the cursor there.
 */
export async function openFileAt(path: string, line?: number, column = 0): Promise<boolean> {
  const uri = fileUri(path);
  const store = useEditorStore.getState();
  const open = store.documents.find(d => d.uri === uri || d.diskPath === path);
  if (open) {
    if (store.active !== open.uri) store.setActive(open.uri);
    if (line !== undefined) store.gotoLocation(open.uri, line, column);
    return true;
  }
  const res = await (window as any).files?.readFile?.(path);
  if (!res || res.error || res.content === undefined) {
    console.warn(`[openFile] could not open ${path}: ${res?.error}`);
    return false;
  }
  const name = path.split(/[\\/]/).pop() || path;
  store.openDocument({
    uri, language: languageOfFile(name), content: res.content, dirty: false, diagnostics: [],
    diskPath: path, mtime: res.mtime, lastSavedContent: res.content,
  });
  if (line !== undefined) useEditorStore.getState().gotoLocation(uri, line, column);
  return true;
}
