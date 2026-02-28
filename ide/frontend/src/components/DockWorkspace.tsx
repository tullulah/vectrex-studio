import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { WelcomeView, welcomeStyles } from './WelcomeView';
import { Layout, Model, TabNode, IJsonModel, Actions, DockLocation } from 'flexlayout-react';
import { useEditorStore } from '../state/editorStore';
import { dockBus, DockEvent, DockComponent, notifyDockChanged } from '../state/dockBus';
import { logger } from '../utils/logger';
import 'flexlayout-react/style/dark.css';
import { FileTreePanel } from './panels/FileTreePanel';
// Legacy EditorPanel kept for reference; replaced by custom EditorSurface for tab management.
import { EditorSurface } from './EditorSurface';
// Use new WASM-based emulator panel (migrated from root components path)
// Use the demo-capable EmulatorPanel (with demo triangle toggle) from panels path
import { EmulatorPanel } from './panels/EmulatorPanel';
import { DebugPanel } from './panels/DebugPanel';
import { ErrorsPanel } from './panels/ErrorsPanel';
import { OutputPanel } from './panels/OutputPanel';
import { BuildOutputPanel } from './panels/BuildOutputPanel';
import { CompilerOutputPanel } from './panels/CompilerOutputPanel';
import { MemoryPanel } from './panels/MemoryPanel';
import { TracePanel } from './panels/TracePanel';
import { PsgLogPanel } from './panels/PsgLogPanel';
import { BiosCallsPanel } from './panels/BiosCallsPanel';
import { AiAssistantPanel } from './panels/AiAssistantPanel';
import { PlaygroundPanel } from './panels/PlaygroundPanel';

// Bumped to v4 to use new Activity Bar layout (Files/Git in sidebar)
const STORAGE_KEY = 'vpy_dock_model_v4';
const STORAGE_HIDDEN_KEY = 'vpy_hidden_panels_v1';
const STORAGE_PINNED_KEY = 'vpy_pinned_panels_v1';

const defaultJson = {
  "global": {},
  "borders": [],
  "layout": {
    "type": "row",
    "children": [
      {
        "type": "row",
        "weight": 64.71,
        "children": [
          {
            "type": "tabset",
            "id": "editor-host",
            "weight": 76.04,
            "children": [
              { "type": "tab", "name": "Editor", "component": "editor-placeholder", "enableClose": false }
            ]
          },
          {
            "type": "tabset",
            "weight": 23.96,
            "children": [
              { "type": "tab", "name": "Debug", "component": "debug" },
              { "type": "tab", "name": "Errors", "component": "errors" },
              { "type": "tab", "name": "Build Output", "component": "build-output" },
              { "type": "tab", "name": "Compiler Output", "component": "compiler-output" },
              { "type": "tab", "name": "Memory", "component": "memory" },
              { "type": "tab", "name": "Trace", "component": "trace" },
              { "type": "tab", "name": "PSG Log", "component": "psglog" },
              { "type": "tab", "name": "BIOS Calls", "component": "bioscalls" }
            ]
          }
        ]
      },
      {
        "type": "row",
        "weight": 21.48,
        "children": [
          {
            "type": "tabset",
            "weight": 81.30,
            "children": [
              { "type": "tab", "name": "Emulator", "component": "emulator" },
              { "type": "tab", "name": "PyPilot", "component": "ai-assistant" }
            ]
          },
          {
            "type": "tabset",
            "weight": 18.70,
            "children": [
              { "type": "tab", "name": "Emulator Stats", "component": "output" }
            ]
          }
        ]
      }
    ]
  }
};

export const DockWorkspace: React.FC = () => {
  const { t } = useTranslation(['common','editor']);
  const documents = useEditorStore((s:any)=>s.documents);
  const setActive = useEditorStore((s:any)=>s.setActive);
  
  // Initialize stored layout ONCE from localStorage (not on every render)
  const [stored] = useState(() => 
    typeof window !== 'undefined' ? window.localStorage.getItem(STORAGE_KEY) : null
  );
  
  const model = useMemo(() => Model.fromJson((stored ? JSON.parse(stored) : defaultJson) as IJsonModel), [stored]);
  const layoutRef = useRef<Layout | null>(null);
  const dragStateRef = useRef<{ active: boolean; tabId?: string; startX: number; startY: number; currentIndex?: number; targetIndex?: number; tabsetId?: string; marker?: HTMLDivElement; container?: HTMLElement; overlay?: HTMLDivElement; targetTabsetId?: string } | null>(null);
  // Saved layouts for hidden single-instance panels (files/emulator/debug/errors) + placeholder
  type PanelKey = DockComponent | 'editor-placeholder' | 'build-output' | 'compiler-output';
  const savedRef = useRef<Record<PanelKey, { json: any; parentTabsetId?: string; index?: number; tabsetWeight?: number }>>({
    files: { json: null as any },
    editor: { json: null as any },
    'editor-placeholder': { json: null as any },
    emulator: { json: null as any },
    debug: { json: null as any },
  errors: { json: null as any },
  memory: { json: null as any },
  trace: { json: null as any },
  psglog: { json: null as any },
  bioscalls: { json: null as any },
  output: { json: null as any },
  'build-output': { json: null as any },
  'compiler-output': { json: null as any },
  'ai-assistant': { json: null as any },
  playground: { json: null as any }
  });
  // Extra metadata to preserve docking edge for panels so re-pin restores original side
  const panelMetaRef = useRef<Partial<Record<DockComponent | 'build-output' | 'compiler-output', { edge: 'left'|'right'|'bottom'|'top'; parentTabsetId?: string }>>>({ files:{edge:'left'}, emulator:{edge:'right'}, debug:{edge:'bottom'}, errors:{edge:'bottom'}, output:{edge:'bottom'}, memory:{edge:'right'}, trace:{edge:'right'}, psglog:{edge:'right'}, bioscalls:{edge:'right'}, playground:{edge:'right'}, 'build-output':{edge:'bottom'}, 'compiler-output':{edge:'bottom'} });
  const hiddenSetRef = useRef<Set<DockComponent>>(new Set());
  const pinnedSetRef = useRef<Set<DockComponent | 'build-output' | 'compiler-output'>>(new Set(['files','emulator','memory','trace','psglog','bioscalls','playground','debug','errors','output','build-output','compiler-output']));
  const [, forceRerender] = useState(0); // for pin UI updates
  (window as any).__pinnedPanelsRef = pinnedSetRef;
  // Expose globally so static handlers can reach
  (window as any).__vpyDragStateRef = dragStateRef;
  (window as any).__vpyDockModel = model;
  //

  const factory = useCallback((node: TabNode) => {
    const comp = node.getComponent();
    // Remove doc:* dynamic tabs; single host now handles tabs internally.
    switch (comp) {
      case 'files': return <FileTreePanel key="files-panel" />;
      case 'editor': return <EditorSurface key="editor-surface" />; // fallback if persisted layout uses 'editor'
      case 'editor-host': return <EditorSurface key="editor-host-surface" />;
      case 'editor-placeholder': return <div key="editor-placeholder" className="vpy-welcome-host" style={{position:'relative',height:'100%',width:'100%'}}><EditorSurface /></div>;
      case 'emulator': return <EmulatorPanel key="emulator-panel-singleton" />;
  case 'debug': return <DebugPanel key="debug-panel" />;
  case 'errors': return <ErrorsPanel key="errors-panel" />;
  case 'memory': return <MemoryPanel key="memory-panel" />;
  case 'trace': return <TracePanel key="trace-panel" />;
  case 'psglog': return <PsgLogPanel key="psglog-panel" />;
  case 'bioscalls': return <BiosCallsPanel key="bioscalls-panel" />;
  case 'output': return <OutputPanel key="output-panel" />;
  case 'build-output': return <BuildOutputPanel key="build-output-panel" />;
  case 'compiler-output': return <CompilerOutputPanel key="compiler-output-panel" />;
  case 'ai-assistant': return <AiAssistantPanel key="ai-assistant-panel-singleton" />;
  case 'playground': return <PlaygroundPanel key="playground-panel" />;
      default: return <div>Unknown: {comp}</div>;
    }
  }, []);


  // Renderizador custom de tabs para añadir botón de cierre confiable incluso si flexlayout oculta el suyo en WebView2
  const onRenderTab = useCallback((node: TabNode, renderValues: any) => {
    const comp: string | undefined = (node as any)?._attributes?.component;
  const isDoc = !!(comp && comp.startsWith('doc:'));
  if (isDoc) {
      const uri = comp!.slice(4);
      const doc = (useEditorStore as any).getState().documents.find((d:any)=>d.uri===uri);
      if (doc && doc.dirty) {
        if (!renderValues.name.endsWith('*')) renderValues.name = renderValues.name + ' *';
      }
    }
  const canClose = isDoc; // solo doc:* cerrable; ni placeholder ni legacy editor
    if (canClose) {
      // Asegurar array buttons existe
      renderValues.buttons = renderValues.buttons || [];
      // Evitar duplicados si el renderizador se invoca múltiples veces: filtrar previos con nuestra marca
      renderValues.buttons = renderValues.buttons.filter((b:any) => !(b?.key && (""+b.key).startsWith('close-')));
      renderValues.buttons.push(
        <button
          key={`close-${node.getId()}`}
          className="vpy-tab-close"
          title="Close"
          onClick={(e) => {
            e.stopPropagation();
            try {
              model.doAction(Actions.deleteTab(node.getId()));
            } catch (err) {
              logger.warn('Dock', 'close failed', err);
            }
          }}
          style={{
            background:'transparent', border:'none', color:'#aaa', cursor:'pointer', padding:0,
            fontSize:12, lineHeight:1, width:16, height:16, display:'flex', alignItems:'center', justifyContent:'center'
          }}
        >×</button>
      );
    }
  }, [model]);

  // Tabset-level pin button (mueve pin junto al botón de maximizar del grupo)
  // (tabset-level pin button moved below after helper callbacks are declared)

  // Persist changes
  const onModelChange = useCallback(() => {
    const json = model.toJson();
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(json));
    persistPinnedPanels();
    // schedule DOM tagging refresh shortly after React commit
    requestAnimationFrame(() => tagTabsetsWithIds(model));
  }, [model]);

  // Force relayout of Monaco when editor tab becomes visible
  const onAction = useCallback((action: any) => {
    // Document tabs removed; no special delete handling needed now.
    if (action.type === 'FlexLayout_SelectTab') {
      const nodeId = action?.data?.tabNode || action.tabNode;
      let targetNode: any = undefined;
      model.visitNodes((n:any) => { if (!targetNode && n.getId && n.getId() === nodeId) targetNode = n; });
      if (targetNode) {
        const compName = (typeof targetNode.getComponent === 'function') ? targetNode.getComponent() : targetNode?._attributes?.component;
        if (compName && typeof compName === 'string' && compName.startsWith('doc:')) {
          const uri = compName.slice(4);
          try { setActive(uri); } catch {}
        }
      }
    }
    setTimeout(() => notifyDockChanged(), 0);
    return action;
  }, [documents, model, setActive]);

  // Helper to find if a component tab exists
  const hasComponent = useCallback((comp: DockComponent | 'editor-placeholder' | string) => {
    let found = false;
    model.visitNodes((n:any) => {
      try {
        if (typeof n.getComponent === 'function') {
          if (n.getComponent() === comp) found = true;
        } else if ((n as any)?._attributes?.component === comp) { // fallback legacy
          found = true;
        }
      } catch {}
    });
    return found;
  }, [model]);

  // Ensure a dedicated editor host tabset exists (with placeholder) if user layout lost it.
  const ensureEditorHost = useCallback(() => {
    let editorTabsetExists = false;
    model.visitNodes((n:any) => {
      if (n.getType && n.getType()==='tabset') {
        const id = n.getId?.();
        const children: any[] = n.getChildren?.() || [];
        const hasEditorChild = children.some(c => {
          const compName = c?._attributes?.component; return compName==='editor-placeholder' || compName==='editor' || (typeof compName==='string' && compName.startsWith('doc:'));
        });
        if (hasEditorChild || id==='editor-host') editorTabsetExists = true;
      }
    });
    if (editorTabsetExists) return;
    // Insert a new tabset in the root layout (heuristic: before first right-side panel or at end)
    try {
      const json = model.toJson();
      const root = json.layout;
      if (root && root.type==='row' && Array.isArray(root.children)) {
        // Add tabset with placeholder in middle-ish position
        const newTabset = { type:'tabset', id:'editor-host', weight:60, children:[ { type:'tab', component:'editor-placeholder', name:'Editor', enableClose:false } ] };
        // Try to place it approximately central: after first child if only side panel exists
        if (root.children.length >= 1) {
          root.children.splice(1, 0, newTabset as any);
        } else {
          root.children.push(newTabset as any);
        }
        const fresh = Model.fromJson(json as any);
        // @ts-ignore internal swap
        model._root = fresh._root;
        requestAnimationFrame(()=>tagTabsetsWithIds(model));
      }
    } catch (e) { logger.warn('Dock', 'ensureEditorHost failed', e); }
  }, [model]);

  const addComponent = useCallback((comp: DockComponent | 'editor-placeholder' | string, customName?: string) => {
    if (hasComponent(comp)) return;
    // console.debug('[Dock] addComponent', comp);

    // Map internal component name to display title
    const nameMap: Record<string,string> = {
      files: t('panel.files', 'Files'),
      editor: t('panel.editor', 'Editor'),
      'editor-placeholder': t('panel.editor', 'Editor'),
      emulator: t('panel.emulator', 'Emulator'),
      debug: t('panel.debug', 'Debug'),
      errors: t('panel.errors', 'Errors'),
      output: t('panel.output', 'Output'),
      'build-output': 'Build Output',
      'compiler-output': 'Compiler Output',
      memory: t('panel.memory', 'Memory'),
      trace: t('panel.trace', 'Trace'),
      bioscalls: t('panel.bioscalls', 'BIOS Calls'),
      'ai-assistant': t('panel.ai', 'PyPilot'),
      playground: t('panel.playground', 'Playground')
    };
    if (customName) nameMap[comp] = customName;

    // Find anchor tabset (editor) for spatial placement
    let editorTabset: string | undefined;
    model.visitNodes(n => {
      if ((n as any).getType && (n as any).getType() === 'tabset') {
        const children: any[] = (n as any).getChildren?.() || [];
        if (children.some(c => c?._attributes?.component === 'editor')) {
          editorTabset = (n as any).getId?.();
        }
      }
      // Persist hidden set + saved layouts snapshot after each toggle/ensure/focus/reset change
      try {
        const snapshot: Array<{component: DockComponent; saved?: { json: any; parentTabsetId?: string; index?: number; tabsetWeight?: number }}> = [];
        hiddenSetRef.current.forEach(c => {
          const saved = savedRef.current[c];
          snapshot.push({ component: c, saved: saved?.json ? { json: saved.json, parentTabsetId: saved.parentTabsetId, index: saved.index, tabsetWeight: saved.tabsetWeight } : undefined });
        });
        window.localStorage.setItem(STORAGE_HIDDEN_KEY, JSON.stringify(snapshot));
      } catch (e) { logger.warn('Dock', 'persist hidden panels failed', e); }
    });

    // Fallback: first tabset id if editor not found
    if (!editorTabset) {
      model.visitNodes(n => { if (!editorTabset && (n as any).getType && (n as any).getType()==='tabset') editorTabset = (n as any).getId?.(); });
    }

    // Decide desired docking relative to editor for each component
    let location: typeof DockLocation.CENTER = DockLocation.CENTER; // default center (same tabset)
  if (comp === 'files') location = DockLocation.LEFT; else if (comp === 'emulator' || comp === 'playground') location = DockLocation.RIGHT; else if (comp === 'memory' || comp === 'trace' || comp === 'bioscalls') location = DockLocation.RIGHT; else if (comp === 'debug' || comp === 'errors' || comp === 'output') location = DockLocation.BOTTOM; else if (comp === 'editor-placeholder') location = DockLocation.CENTER; else if ((comp as string).startsWith('doc:')) location = DockLocation.CENTER;
      // If we have meta specifying parent tabset and it still exists, attempt to restore directly there instead of relative add
      const meta = panelMetaRef.current[comp as DockComponent];
      if (meta?.parentTabsetId) {
        let exists = false;
        model.visitNodes(n=>{ if (!exists && (n as any).getId && (n as any).getId()===meta.parentTabsetId) exists = true; });
        if (exists) {
          try {
            model.doAction(Actions.addNode({ type:'tab', component: comp, name: nameMap[comp] } as any, meta.parentTabsetId, DockLocation.CENTER, -1));
            persistPinnedPanels();
            return;
          } catch { /* fallback below */ }
        }
      }

    try {
      if (editorTabset) {
        model.doAction(
          Actions.addNode({ type: 'tab', component: comp, name: nameMap[comp] } as any, editorTabset, location, -1)
        );
      }
      else {
        // Ultimate fallback: append to any (center) if no tabset found
        logger.warn('Dock', 'editorTabset not found; appending component in first tabset');
        let first: string | undefined; model.visitNodes(n=>{ if (!first && (n as any).getType && (n as any).getType()==='tabset') first = (n as any).getId?.(); });
        if (first) model.doAction(Actions.addNode({ type: 'tab', component: comp, name: nameMap[comp] } as any, first, DockLocation.CENTER, -1));
      }
    } catch (e) {
      logger.warn('Dock', 'addComponent failed', e);
    }
    persistPinnedPanels();
  }, [hasComponent, model]);

  const removeComponent = useCallback((comp: DockComponent) => {
    // console.debug('[Dock] removeComponent', comp);
    const toRemove: string[] = [];
    model.visitNodes((n:any) => {
      try {
        let compName: string | undefined;
        if (typeof n.getComponent === 'function') compName = n.getComponent();
        else if (n._attributes?.component) compName = n._attributes.component;
        if (compName === comp && n.getType && n.getType()==='tab') {
          const id = n.getId && n.getId();
          if (id) toRemove.push(id);
        }
      } catch {}
    });
    if (toRemove.length === 0) {
      console.debug('[Dock] removeComponent none-found', comp);
    }
    toRemove.forEach(id => {
      try { model.doAction(Actions.deleteTab(id)); logger.debug('Dock', 'removed tab id', id); } catch(e) { logger.warn('Dock', 'deleteTab failed', e); }
    });
    persistPinnedPanels();
  }, [model]);

  // Now that addComponent / hasComponent / removeComponent exist, define tabset-level pin renderer
  const onRenderTabSet = useCallback((tabsetNode: any, renderValues: any) => {
    try {
      const children: any[] = tabsetNode.getChildren?.() || [];
  const panelChildren: DockComponent[] = children.map(c => (typeof c.getComponent === 'function' ? c.getComponent() : c?._attributes?.component)).filter((n: any) => ['files','emulator','debug','errors','output','memory','trace','bioscalls','playground'].includes(n));
      if (panelChildren.length === 0) return; // not a pure panel tabset
      const hasMixed = children.some(c => {
        const compName = (typeof c.getComponent === 'function' ? c.getComponent() : c?._attributes?.component);
        return compName && (compName.startsWith?.('doc:') || compName === 'editor' || compName === 'editor-placeholder');
      });
      if (hasMixed) return; // don't show pin button on mixed sets
      // Detect orientation/edge: inspect first panel child component to infer its last saved location
      // We'll treat debug/errors as bottom, files as left, emulator as right.
      let edge: 'left' | 'right' | 'bottom' | 'top' = 'top';
  if (panelChildren.every(pc => pc === 'debug' || pc === 'errors' || pc === 'output')) edge = 'bottom';
      else if (panelChildren.every(pc => pc === 'files')) edge = 'left';
  else if (panelChildren.every(pc => pc === 'emulator' || pc === 'memory' || pc === 'trace' || pc === 'bioscalls' || pc === 'playground')) edge = 'right';
      // top currently unused but reserved if future top docking added
      const allPinned = panelChildren.every(pc => pinnedSetRef.current.has(pc));
      // Record parent tabset id for each panel child so re-pin returns here
      const parentId = tabsetNode.getId?.();
      panelChildren.forEach(pc => {
        if (parentId) {
          // edge inference again
          let edge: 'left'|'right'|'bottom'|'top' = 'top';
          if (pc === 'files') edge='left'; else if (pc==='emulator' || pc==='memory' || pc==='trace' || pc==='bioscalls' || pc==='playground') edge='right'; else if (pc==='debug' || pc==='errors' || pc==='output') edge='bottom';
          panelMetaRef.current[pc] = { edge, parentTabsetId: parentId };
        }
      });
      renderValues.buttons = renderValues.buttons || [];
      renderValues.buttons = renderValues.buttons.filter((b:any)=>!(b?.key && (""+b.key).startsWith('tabset-pin-')));
      const orientationClass = edge === 'left' || edge === 'right' ? 'vertical' : 'horizontal';
      // Include a compact label list when on side edges so the tabset header still shows context even if tabs collapse visually
      const label = (edge === 'left' || edge === 'right') ? panelChildren.map(pc=>pc.charAt(0).toUpperCase()+pc.slice(1)).join(' / ') : '';
      renderValues.buttons.unshift(
        <div key={`tabset-pin-${tabsetNode.getId?.()}`} style={{display:'flex', alignItems:'center', gap:4}}>
          <button
            className={"vpy-tabset-pin-btn" + (allPinned?" pinned":"")}
            title={allPinned? t('action.unpinPanels','Unpin panels (auto-hide)'): t('action.pinPanels','Pin panels')}
            onClick={(e) => {
              e.stopPropagation();
              if (allPinned) {
                panelChildren.forEach(pc => { pinnedSetRef.current.delete(pc); removeComponent(pc); });
              } else {
                panelChildren.forEach(pc => { pinnedSetRef.current.add(pc); if (!hasComponent(pc)) addComponent(pc); });
              }
              persistPinnedPanels();
              forceRerender(n=>n+1);
              // console.debug('[PinClick] tabset pin toggle', { tabset: tabsetNode.getId?.(), panelChildren, nowPinned: panelChildren.every(pc=>pinnedSetRef.current.has(pc)) });
            }}
            style={{ background:'transparent', border:'none', cursor:'pointer', padding:0, width:16, height:16, display:'flex', alignItems:'center', justifyContent:'center' }}
          >
            <span className={"pin-icon " + orientationClass + (allPinned?" pinned":"")}>📌</span>
          </button>
          {label && <span className="vpy-panel-label" style={{fontSize:12, color:'#bbb', userSelect:'none', fontWeight:500}}>{label}</span>}
        </div>
      )
    } catch (e) { logger.warn('Dock', 'onRenderTabSet pin failed', e); }
  }, [addComponent, hasComponent, removeComponent]);

  useEffect(() => {
    const focusExisting = (comp: DockComponent) => {
      let targetTabId: string | undefined;
      model.visitNodes((n:any) => {
        if (targetTabId) return;
        if (n.getType && n.getType()==='tab') {
          try {
            if (typeof n.getComponent === 'function') {
              if (n.getComponent() === comp) targetTabId = n.getId();
            } else if (n._attributes?.component === comp) {
              targetTabId = n.getId();
            }
          } catch {}
        }
      });
      if (targetTabId) {
        try { model.doAction(Actions.selectTab(targetTabId)); } catch {}
      }
    };
    const unsub = dockBus.on((ev: DockEvent) => {
      if (ev.type === 'toggle') {
        const comp = ev.component;
  if (hasComponent(comp) && ['files','editor','emulator','debug','errors','output','memory','trace','bioscalls','editor-placeholder'].includes(comp)) {
          // Capture existing node before removal for restoration later
          let targetNode: any | undefined; let parentId: string | undefined; let index: number | undefined; let parentWeight: number | undefined;
          model.visitNodes((n:any) => {
            if (targetNode) return;
            if (n.getType && n.getType()==='tab') {
              let compName: string | undefined;
              try { compName = typeof n.getComponent === 'function' ? n.getComponent() : n._attributes?.component; } catch {}
              if (compName === comp) {
                targetNode = n;
                const parent: any = n.getParent && n.getParent();
                if (parent && parent.getId) {
                  parentId = parent.getId();
                  const children = parent.getChildren();
                  index = children.indexOf(n);
                  try { parentWeight = (typeof parent.getWeight === 'function') ? parent.getWeight() : (parent._attributes?.weight); } catch {}
                }
              }
            }
          });
          if (targetNode) {
            try {
              const j = (targetNode as any).toJson ? (targetNode as any).toJson() : { type:'tab', component: comp, name: comp };
              const normalized = { type:'tab', component: comp, name: j.name || comp };
              savedRef.current[comp] = { json: normalized, parentTabsetId: parentId, index, tabsetWeight: parentWeight };
              console.debug('[Dock] save panel', comp, 'tabset=', parentId, 'index=', index, 'weight=', parentWeight);
            } catch (e) {
              savedRef.current[comp] = { json: { type:'tab', component: comp, name: comp }, parentTabsetId: parentId, index, tabsetWeight: parentWeight };
              console.debug('[Dock] save panel (fallback)', comp, 'tabset=', parentId, 'index=', index, 'weight=', parentWeight);
            }
          }
          removeComponent(comp);
        } else {
          const saved = savedRef.current[comp];
          let restored = false;
          if (saved && saved.parentTabsetId && saved.json) {
            // Verify parent tabset still exists
            let parentExists = false;
            model.visitNodes((n:any) => { if (!parentExists && n.getId && n.getId() === saved.parentTabsetId) parentExists = true; });
            if (parentExists) {
              try {
                model.doAction(Actions.addNode(saved.json as any, saved.parentTabsetId, DockLocation.CENTER, (typeof saved.index === 'number' ? saved.index : -1)));
                restored = true;
                console.debug('[Dock] restore panel', comp, 'at saved', saved.parentTabsetId, 'index', saved.index);
                // Re-apply weight if captured
                if (typeof saved.tabsetWeight === 'number') {
                  // Find the parent tabset and set weight (internal API but stable enough)
                  model.visitNodes((n:any) => {
                    if (n.getId && n.getId() === saved.parentTabsetId) {
                      try {
                        if (typeof n.setWeight === 'function') n.setWeight(saved.tabsetWeight);
                        else if (n._attributes) n._attributes.weight = saved.tabsetWeight; // fallback
                        console.debug('[Dock] restored tabset weight', saved.tabsetWeight, 'for', comp);
                      } catch (e) {
                        logger.warn('Dock', 'failed to restore tabset weight', e);
                      }
                    }
                  });
                  // Force layout to recompute (using private call via model._root? fallback to no-op)
                  try { (layoutRef.current as any)?.forceUpdate?.(); } catch {}
                }
              } catch (e) { logger.warn('Dock', 'restore addNode failed, fallback to generic add', e); }
            }
          }
          if (!restored) {
            addComponent(comp);
            console.debug('[Dock] restore panel fallback add', comp);
            // If we have a saved weight, apply it to the newly created tabset
            if (saved && typeof saved.tabsetWeight === 'number') {
              let applied = false;
              model.visitNodes((n:any) => {
                if (applied) return;
                if (n.getType && n.getType()==='tabset') {
                  const children: any[] = n.getChildren?.() || [];
                  if (children.some(c => {
                    try { return (typeof c.getComponent === 'function' ? c.getComponent() : c._attributes?.component) === comp; } catch { return false; }
                  })) {
                    try {
                      if (typeof n.setWeight === 'function') n.setWeight(saved.tabsetWeight); else if (n._attributes) n._attributes.weight = saved.tabsetWeight;
                      applied = true;
                      console.debug('[Dock] applied saved weight (fallback)', saved.tabsetWeight, 'for', comp);
                    } catch (e) {
                      logger.warn('Dock', 'failed to apply saved weight (fallback)', e);
                    }
                  }
                }
              });
              try { (layoutRef.current as any)?.forceUpdate?.(); } catch {}
            }
          }
          // Focus it
          setTimeout(() => {
            let newId: string | undefined;
            model.visitNodes((n:any) => {
              if (newId) return;
              if (n.getType && n.getType()==='tab') {
                const isMatch = (typeof n.getComponent === 'function' ? n.getComponent() : n._attributes?.component) === comp;
                if (isMatch) newId = n.getId();
              }
            });
            if (newId) { try { model.doAction(Actions.selectTab(newId)); } catch {} }
          }, 10);
        }
        notifyDockChanged();
        persistPinnedPanels();
        requestAnimationFrame(()=>tagTabsetsWithIds(model));
      } else if (ev.type === 'ensure') {
        if (!hasComponent(ev.component)) addComponent(ev.component);
        focusExisting(ev.component);
        notifyDockChanged();
        persistPinnedPanels();
        requestAnimationFrame(()=>tagTabsetsWithIds(model));
      } else if (ev.type === 'focus') {
        focusExisting(ev.component);
      } else if (ev.type === 'reset') {
        try {
          const fresh = Model.fromJson(defaultJson as IJsonModel);
          // @ts-ignore internal API to swap, fallback recreation if needed
          model._root = fresh._root;
          onModelChange();
          notifyDockChanged();
          console.info('[Dock] Layout reset to defaults');
          requestAnimationFrame(()=>tagTabsetsWithIds(model));
        } catch (e) {
          logger.warn('Dock', 'reset failed', e);
        }
      }
    });
    return () => { unsub(); };
  }, [addComponent, hasComponent, model, removeComponent, onModelChange]);

  // Removed document sync effects (handled internally by EditorSurface now)

  // On mount, ensure editor host exists in case of pathological persisted layout missing it entirely.
  useEffect(() => { ensureEditorHost(); }, [ensureEditorHost]);

  // Migration: if layout persisted antes de existir 'Errors', añadir la pestaña automáticamente
  useEffect(() => {
    // slight defer until model stable
    setTimeout(() => {
      if (!hasComponent('errors')) {
        let debugTabset: string | undefined;
        model.visitNodes((n) => {
          // @ts-ignore inspect children for debug component
          if (n.getType && n.getType() === 'tabset') {
            const children: any[] = (n as any).getChildren?.() || [];
            if (children.some(c => c?._attributes?.component === 'debug')) {
              debugTabset = (n as any).getId?.();
            }
          }
        });
        if (debugTabset) {
          try {
            model.doAction(Actions.addNode({ type: 'tab', component: 'errors', name: 'Errors' } as any, debugTabset, DockLocation.CENTER, -1));
            notifyDockChanged();
            console.info('[Dock] Migrated layout: added missing Errors tab');
          } catch (e) {
            logger.warn('Dock', 'Failed to auto-add Errors tab', e);
          }
        }
      }
      // Auto-inject memory panel if missing (new feature). We place it similar to emulator (right) by calling addComponent.
      // This corresponds to the user-observed log: "[Dock] restore panel fallback add memory" when toggled manually.
      try {
  if (!hasComponent('memory')) { try { addComponent('memory'); logger.info('Dock', 'Migrated layout: added missing Memory tab'); } catch(e) { logger.warn('Dock', 'Failed to auto-add Memory tab', e); } }
  if (!hasComponent('trace')) { try { addComponent('trace'); logger.info('Dock', 'Migrated layout: added missing Trace tab'); } catch(e) { logger.warn('Dock', 'Failed to auto-add Trace tab', e); } }
  if (!hasComponent('bioscalls')) { try { addComponent('bioscalls'); logger.info('Dock', 'Migrated layout: added missing BIOS Calls tab'); } catch(e) { logger.warn('Dock', 'Failed to auto-add BIOS Calls tab', e); } }
  if (!hasComponent('ai-assistant')) { try { addComponent('ai-assistant'); logger.info('Dock', 'Migrated layout: added missing AI Assistant tab'); } catch(e) { logger.warn('Dock', 'Failed to auto-add AI Assistant tab', e); } }
      } catch (e) { logger.warn('Dock', 'Failed to auto-add Memory tab', e); }
    }, 50);
  }, [hasComponent, model]);

  useEffect(() => {
    // Restore hidden panels (persisted) after model constructed
    try {
      const raw = window.localStorage.getItem(STORAGE_HIDDEN_KEY);
      if (raw) {
        const parsed: Array<{component: DockComponent; saved?: { json: any; parentTabsetId?: string; index?: number; tabsetWeight?: number }}> = JSON.parse(raw);
        parsed.forEach(entry => {
          hiddenSetRef.current.add(entry.component);
          if (entry.saved) {
            savedRef.current[entry.component] = {
              json: entry.saved.json,
              parentTabsetId: entry.saved.parentTabsetId,
              index: entry.saved.index,
              tabsetWeight: entry.saved.tabsetWeight
            };
          }
        });
        // Remove any panel that should start hidden
        const toHide = Array.from(hiddenSetRef.current.values());
        if (toHide.length) {
          requestAnimationFrame(() => {
            toHide.forEach(c => {
              if (hasComponent(c)) removeComponent(c);
            });
            notifyDockChanged();
          });
        }
      }
    } catch (e) {
      logger.warn('Dock', 'failed to restore hidden panels', e);
    }
    // Restore pinned panels
    try {
      const rawPin = window.localStorage.getItem(STORAGE_PINNED_KEY);
      if (rawPin) {
        const arr: DockComponent[] = JSON.parse(rawPin);
        pinnedSetRef.current = new Set(arr);
      }
    } catch (e) { logger.warn('Dock', 'failed to restore pinned panels', e); }
    // Example: add future dynamic tabs via layoutRef.current?.addTabWithDragAndDrop
    tagTabsetsWithIds(model);
  }, []);

  // Tauri-specific drag workaround removed (runtime is Electron + standard web now).

  return (
    <div style={{position:'absolute', inset:0}} onMouseDown={(e) => {
      const target = e.target as HTMLElement;
      if (!target.classList.contains('flexlayout__tab_button')) return;
      // Identify tab id by traversing React-resolved data attributes (fallback to text)
      // flexlayout-react stores an internal id on the tab button element's parent sometimes via dataset. We fallback to node name match.
      let tabName = target.textContent?.trim() || '';
      if (!tabName) return;
      // Find tab node by name (unique enough for demo) and its tabset
      let foundNode: TabNode | undefined; let tabsetId: string | undefined; let indexInSet: number | undefined;
      model.visitNodes((n) => {
        if ((n as any).getName && (n as any).getName() === tabName) {
          foundNode = n as TabNode;
          const parent: any = (n as any).getParent && (n as any).getParent();
          if (parent && parent.getId) {
            tabsetId = parent.getId();
            const children = parent.getChildren();
            indexInSet = children.indexOf(n);
          }
        }
      });
      if (!foundNode || tabsetId===undefined || indexInSet===undefined) return;
      const container = target.closest('.flexlayout__tabset_tabbar_outer') as HTMLElement | null;
      dragStateRef.current = { active: true, tabId: (foundNode as any).getId(), startX: e.clientX, startY: e.clientY, currentIndex: indexInSet, targetIndex: indexInSet, tabsetId, container: container || undefined };
      // Create marker
      const marker = document.createElement('div');
      marker.style.position='absolute';
      marker.style.top='0';
      marker.style.width='2px';
      marker.style.background='#4FC1FF';
      marker.style.zIndex='999';
      marker.style.pointerEvents='none';
      dragStateRef.current.marker = marker;
      document.body.appendChild(marker);
      // Create overlay highlight (for cross-tabset)
      const overlay = document.createElement('div');
      overlay.style.position='absolute';
      overlay.style.border='2px dashed #4FC1FF';
      overlay.style.pointerEvents='none';
      overlay.style.zIndex='998';
      overlay.style.display='none';
      dragStateRef.current.overlay = overlay;
      document.body.appendChild(overlay);
      document.addEventListener('mousemove', handleDragMove, true);
      document.addEventListener('mouseup', handleDragEnd, true);
    }}>
      <Layout
        ref={r => { layoutRef.current = r; }}
        model={model}
        factory={factory}
        onRenderTab={onRenderTab}
        onRenderTabSet={onRenderTabSet}
        onModelChange={onModelChange}
        onAction={onAction}
      />
      {/* Rails for unpinned panels (simple icons to re-pin) */}
      <div className="vpy-rail left">
        {(['files'] as DockComponent[]).filter(p=>!pinnedSetRef.current.has(p)).map(p=> (
          <div key={p} className="rail-icon" title={t('action.showPanel','Show panel')+': '+t(`panel.${p}`, p)} onClick={()=>{ pinnedSetRef.current.add(p); persistPinnedPanels(); addComponent(p); forceRerender(n=>n+1); }}>
            <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:2}}>
              <span>📌</span>
              <span style={{writingMode:'vertical-rl', transform:'rotate(180deg)', fontSize:13, fontWeight:600, letterSpacing:'0.5px'}}>{p}</span>
            </div>
          </div>
        ))}
      </div>
      <div className="vpy-rail right">
        {(['emulator','playground'] as DockComponent[]).filter(p=>!pinnedSetRef.current.has(p)).map(p=> (
          <div key={p} className="rail-icon" title={t('action.showPanel','Show panel')+': '+t(`panel.${p}`, p)} onClick={()=>{ pinnedSetRef.current.add(p); persistPinnedPanels(); addComponent(p); forceRerender(n=>n+1); }}>
            <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:2}}>
              <span>📌</span>
              <span style={{writingMode:'vertical-rl', transform:'rotate(180deg)', fontSize:13, fontWeight:600, letterSpacing:'0.5px'}}>{p}</span>
            </div>
          </div>
        ))}
      </div>
      <div className="vpy-rail bottom">
  {(['debug','errors','output'] as DockComponent[]).filter(p=>!pinnedSetRef.current.has(p)).map(p=> (
          <div key={p} className="rail-icon" title={t('action.showPanel','Show panel')+': '+t(`panel.${p}`, p)} onClick={()=>{ pinnedSetRef.current.add(p); persistPinnedPanels(); addComponent(p); forceRerender(n=>n+1); }}>📌 {t(`panel.${p}`, p)}</div>
        ))}
      </div>
      <style>{`
        .vpy-editor-placeholder-only .flexlayout__tabset_tabbar_outer { display:none; }
        .vpy-btn { background:#1e1e1e; border:1px solid #333; color:#ddd; padding:6px 14px; border-radius:4px; cursor:pointer; font-size:13px; }
        .vpy-btn:hover { background:#2a2a2a; border-color:#444; }
        .vpy-tabset-pin-btn .pin-icon { display:inline-block; transition: transform 0.15s ease; font-size:12px; }
        .vpy-tabset-pin-btn .pin-icon.vertical { transform: rotate(0deg); }
        .vpy-tabset-pin-btn .pin-icon.horizontal { transform: rotate(90deg); }
        .vpy-tabset-pin-btn { color:#999; }
        .vpy-tabset-pin-btn:hover { color:#fff; }
        .vpy-rail { position:absolute; display:flex; gap:6px; z-index:800; }
        .vpy-rail.left { top:50%; left:0; transform:translateY(-50%); flex-direction:column; }
        .vpy-rail.right { top:50%; right:0; transform:translateY(-50%); flex-direction:column; }
        .vpy-rail.bottom { left:50%; bottom:0; transform:translateX(-50%); flex-direction:row; }
        .vpy-rail .rail-icon { background:#222; border:1px solid #444; color:#bbb; padding:4px 6px; font-size:12px; cursor:pointer; writing-mode:horizontal-tb; }
        .vpy-rail .rail-icon:hover { background:#2d2d2d; color:#fff; }
        ${welcomeStyles}
      `}</style>
    </div>
  );
};

//

function handleDragMove(e: MouseEvent) {
  const ref = (window as any).__vpyDragStateRef as React.MutableRefObject<any> | undefined;
  if (!ref) return;
  const st = ref.current; if (!st || !st.active) return;
  // Detect potential tabset under cursor
  const elUnder = document.elementFromPoint(e.clientX, e.clientY) as HTMLElement | null;
  let tabsetBar = elUnder?.closest('.flexlayout__tabset_tabbar_outer') as HTMLElement | null;
  if (!tabsetBar) {
    // Hide marker & overlay if outside any tab bar
    if (st.marker) st.marker.style.display='none';
    if (st.overlay) st.overlay.style.display='none';
    return;
  }
  const model = (window as any).__vpyDockModel as Model | undefined;
  let targetTabsetId: string | undefined = undefined;
  if (model) {
    // Heuristic: match tabset by comparing child tab button count & positions; fallback: reuse origin tabset if same bar
    // We can embed data-layout-path attribute; if not present rely on identity of DOM node references.
    // For now, store text of first tab as key to locate node set; approximate.
  }
  const buttons = Array.from(tabsetBar.querySelectorAll('.flexlayout__tab_button')) as HTMLElement[];
  if (!buttons.length) return;
  // Compute index inside this tabset
  const x = e.clientX;
  let targetIndex = buttons.length - 1;
  for (let i=0;i<buttons.length;i++) {
    const r = buttons[i].getBoundingClientRect();
    const center = r.left + r.width/2;
    if (x < center) { targetIndex = i; break; }
  }
  st.targetIndex = targetIndex;
  st.targetTabsetId = deriveTabsetId(tabsetBar);
  if (st.marker) {
    const refBtn = buttons[targetIndex];
    const r = refBtn.getBoundingClientRect();
    st.marker.style.display='block';
    st.marker.style.left = `${r.left - 1}px`;
    st.marker.style.height = `${r.height}px`;
    st.marker.style.top = `${r.top + window.scrollY}px`;
  }
  if (st.overlay) {
    const barRect = tabsetBar.getBoundingClientRect();
    st.overlay.style.display='block';
    st.overlay.style.left = `${barRect.left}px`;
    st.overlay.style.top = `${barRect.top + window.scrollY}px`;
    st.overlay.style.width = `${barRect.width}px`;
    st.overlay.style.height = `${barRect.height}px`;
  }
}

function handleDragEnd(_e: MouseEvent) {
  const ref = (window as any).__vpyDragStateRef as React.MutableRefObject<any> | undefined;
  if (!ref) return;
  const st = ref.current; if (!st || !st.active) return;
  if (st.marker && st.marker.parentElement) st.marker.parentElement.removeChild(st.marker);
  if (st.overlay && st.overlay.parentElement) st.overlay.parentElement.removeChild(st.overlay);
  const { tabId, currentIndex, targetIndex, tabsetId, targetTabsetId } = st;
  ref.current = null;
  document.removeEventListener('mousemove', handleDragMove, true);
  document.removeEventListener('mouseup', handleDragEnd, true);
  if (!tabId || targetIndex===undefined) return;
  const destTabset = targetTabsetId || tabsetId;
  if (!destTabset) return;
  const model = (window as any).__vpyDockModel as Model | undefined;
  if (!model) return;
  try {
    // Use official moveNode API (DockLocation.CENTER keeps in same tabset region)
    model.doAction(Actions.moveNode(tabId, destTabset, DockLocation.CENTER, targetIndex));
    console.debug('[Dock] Moved tab', tabId, 'to tabset', destTabset, 'index', targetIndex);
  } catch (err) {
    logger.warn('Dock', 'move failed, fallback not applied', err);
  }
}

function deriveTabsetId(bar: HTMLElement): string | undefined {
  return bar.getAttribute('data-tabsetid') || undefined;
}

function tagTabsetsWithIds(model: Model) {
  try {
    const tabsetBars = document.querySelectorAll('.flexlayout__tabset_tabbar_outer');
    // Build mapping of first tab button text -> tabset id; but better: iterate model
    const idByFirstName: Record<string,string> = {};
    model.visitNodes((n:any) => {
      if (n.getType && n.getType()==='tabset') {
        const children = n.getChildren?.() || [];
        if (children.length>0) {
          const first = children[0];
          const name = first?.getName?.();
          if (name) idByFirstName[name] = n.getId();
        }
      }
    });
    tabsetBars.forEach(bar => {
      const firstBtn = bar.querySelector('.flexlayout__tab_button');
      const label = firstBtn?.textContent?.trim();
      if (label && idByFirstName[label]) {
        (bar as HTMLElement).setAttribute('data-tabsetid', idByFirstName[label]);
      }
    });
  } catch (e) {
    logger.warn('Dock', 'tagTabsetsWithIds failed', e);
  }
}

function persistPinnedPanels() {
  try {
    const arr = Array.from(((window as any).__pinnedPanelsRef as React.MutableRefObject<Set<DockComponent>> | undefined)?.current || []);
    if (arr.length) localStorage.setItem(STORAGE_PINNED_KEY, JSON.stringify(arr)); else localStorage.removeItem(STORAGE_PINNED_KEY);
  } catch (e) { logger.warn('Dock', 'persistPinned failed', e); }
}
