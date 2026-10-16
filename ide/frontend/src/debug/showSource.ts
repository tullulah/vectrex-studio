import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';
import { baseName } from './pdbSource';

/**
 * Show `fileName` (a .vpy base name from the .pdb) at `line` (1-based): this project's
 * open tab of that name — not another project's main.vpy — or the file read from the
 * project's src/.
 */
export function showProjectSource(fileName: string, line: number): void {
  const root = useProjectStore.getState().vpyProject?.rootDir?.replace(/\\/g, '/');
  const editorStore = useEditorStore.getState();
  const fsOf = (uri: string) => uri.replace(/^file:\/\//, '');
  const doc = editorStore.documents.find(d =>
    baseName(d.uri) === fileName && (!root || fsOf(d.uri).startsWith(root + '/')));
  if (doc) {
    if (editorStore.active !== doc.uri) editorStore.setActive(doc.uri);
    editorStore.gotoLocation(doc.uri, line - 1, 0);
    return;
  }
  if (!root) { console.warn(`[debug] ⚠️ No project open: cannot show ${fileName}`); return; }
  const fsPath = `${root}/src/${fileName}`;
  const uri = `file://${fsPath}`;
  (window as any).files?.readFile?.(fsPath).then((res: { content?: string; error?: string }) => {
    if (!res || res.error || res.content === undefined) {
      console.warn(`[debug] ⚠️ Could not open ${fsPath}: ${res?.error}`);
      return;
    }
    useEditorStore.getState().openDocument({ uri, content: res.content, language: 'vpy', dirty: false, mtime: Date.now(), diagnostics: [] });
    useEditorStore.getState().gotoLocation(uri, line - 1, 0);
  });
}
