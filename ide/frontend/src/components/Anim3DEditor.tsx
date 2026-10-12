/**
 * Anim3DEditor — the 3D Animation editor, for `.vclip` pose/clip libraries and the `.vskel`
 * skeletons they pose (docs/ASSETS.md). The model is ./anim3d/animModel.ts (pure, tested by
 * tools/anim3d-model-test.ts against the SDK's vpybone); the view is ./anim3d/Viewport3D.tsx.
 *
 * A `.vclip`:
 * - Poses: one slider per joint (degrees; the file keeps the skeleton's whole units).
 * - Clips: keys (a pose at a frame) and marks on a timeline; play, scrub, drag a key along
 *   it; the clip's whole-number properties. Between keys the preview moves in straight
 *   lines: how a game eases (Return of the Jedi's springs) is the game's own.
 * - Sets: per character or style, the pose for each stance and the clip for each role.
 * The skeleton is `<assets>/skeletons/<name>.vskel`, the meshes `<assets>/meshes/**`, and
 * the preview character is any of the skeleton's variants.
 *
 * A `.vskel`: bones (parent, offset, mesh, the turns that rotate it, its sockets), joints
 * (with test sliders) and variants (scale, meshes and offsets per bone; extra bones,
 * rotations and sockets are listed, and edited as text).
 *
 * Every edit can be undone; saving keeps the fields the editor does not know.
 */
import React, { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import * as A from './anim3d/animModel';
import { Viewport3D, type ViewOptions } from './anim3d/Viewport3D';
import { collectByExt, dirOf, joinPath, meshStrokes, uriToFsPath, type DirEntry, type MeshStrokes } from './anim3d/meshStrokes';

interface Props {
  resource?: unknown;
  docUri?: string;
  onChange?: (raw: unknown) => void;
}

type ClipTab = 'poses' | 'clips' | 'sets';
type SkelTab = 'bones' | 'joints' | 'variants';
const HISTORY_MAX = 200;
const FPS = 50;
const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
/** A refused clip edit (the model returns the new clip, or why not). */
const refused = (r: A.ClipRaw | { error: string }): r is { error: string } => typeof (r as { error?: unknown }).error === 'string';
type Files = {
  readFile?: (p: string) => Promise<{ content: string } | { error: string }>;
  readDirectory?: (p: string) => Promise<{ files: DirEntry[] } | { error: string }>;
};

export const Anim3DEditor: React.FC<Props> = ({ resource, docUri, onChange }) => {
  const { t } = useTranslation(['editor']);
  const tr = (k: string, d: string, o?: Record<string, unknown>) => t(`anim3d.${k}`, { defaultValue: d, ...(o || {}) }) as string;
  const kind: 'skel' | 'clip' = docUri?.toLowerCase().endsWith('.vskel') ? 'skel' : 'clip';

  // ── document + history ──
  const [raw, setRaw] = useState<Record<string, unknown> | null>(() => (isObj(resource) ? resource : null));
  const lastJson = useRef(JSON.stringify(resource ?? null));
  const hist = useRef<{ stack: Record<string, unknown>[]; index: number }>({ stack: raw ? [raw] : [], index: raw ? 0 : -1 });
  const [, rerender] = useReducer((x: number) => x + 1, 0);
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);
  const flash = useCallback((text: string, error = false) => setMessage({ text, error }), []);
  useEffect(() => {
    if (!message) return;
    const id = window.setTimeout(() => setMessage(null), 4000);
    return () => window.clearTimeout(id);
  }, [message]);
  const emit = useCallback((next: Record<string, unknown>) => { lastJson.current = JSON.stringify(next); onChange?.(next); }, [onChange]);
  const commit = useCallback((next: Record<string, unknown>) => {
    const h = hist.current;
    h.stack = h.stack.slice(0, h.index + 1);
    h.stack.push(next);
    if (h.stack.length > HISTORY_MAX) h.stack.shift();
    h.index = h.stack.length - 1;
    setRaw(next); emit(next); rerender();
  }, [emit]);
  useEffect(() => {
    const j = JSON.stringify(resource ?? null);
    if (j === lastJson.current) return;
    lastJson.current = j;
    const r = isObj(resource) ? resource : null;
    setRaw(r);
    hist.current = { stack: r ? [r] : [], index: r ? 0 : -1 };
    rerender();
  }, [resource]);
  const undo = useCallback(() => { const h = hist.current; if (h.index <= 0) return; h.index--; const r = h.stack[h.index]; setRaw(r); emit(r); rerender(); }, [emit]);
  const redo = useCallback(() => { const h = hist.current; if (h.index >= h.stack.length - 1) return; h.index++; const r = h.stack[h.index]; setRaw(r); emit(r); rerender(); }, [emit]);
  /** Apply an edit that may be refused. */
  const tryEdit = (r: { raw: unknown } | { error: string }) => {
    if ('error' in r) { flash(r.error, true); return false; }
    commit(r.raw as Record<string, unknown>);
    return true;
  };

  // ── the project: assets/skeletons, assets/meshes ──
  const files = (window as unknown as { files?: Files }).files;
  const assetsDir = useMemo(() => (docUri && docUri.startsWith('file://') ? joinPath(dirOf(uriToFsPath(docUri)), '..') : ''), [docUri]);
  const [reloadTick, setReloadTick] = useState(0);
  const [meshPaths, setMeshPaths] = useState<Record<string, string> | null>(null);
  const [skelPaths, setSkelPaths] = useState<Record<string, string> | null>(null);
  useEffect(() => {
    if (!assetsDir || !files?.readDirectory) return;
    let live = true;
    files.readDirectory(joinPath(assetsDir, 'meshes')).then((r) => { if (live) setMeshPaths('error' in r ? {} : collectByExt(r.files, 'vmesh')); }).catch(() => live && setMeshPaths(null));
    files.readDirectory(joinPath(assetsDir, 'skeletons')).then((r) => { if (live) setSkelPaths('error' in r ? {} : collectByExt(r.files, 'vskel')); }).catch(() => live && setSkelPaths(null));
    return () => { live = false; };
  }, [assetsDir, reloadTick]);   // eslint-disable-line react-hooks/exhaustive-deps
  const meshNames = useMemo(() => (meshPaths ? Object.keys(meshPaths).sort() : []), [meshPaths]);
  const meshExists = useCallback((n: string) => (meshPaths ? n in meshPaths : undefined), [meshPaths]);

  // the skeleton: the document itself, or the one a .vclip names
  const clipRaw = kind === 'clip' && raw ? (raw as unknown as A.VclipRaw) : null;
  const skelName = clipRaw && typeof clipRaw.skeleton === 'string' ? clipRaw.skeleton : '';
  const [loadedSkel, setLoadedSkel] = useState<{ name: string; raw: A.VskelRaw | null; error?: string } | null>(null);
  useEffect(() => {
    if (kind !== 'clip' || !skelName || !assetsDir || !files?.readFile || !skelPaths) return;
    const rel = skelPaths[skelName];
    if (!rel) { setLoadedSkel({ name: skelName, raw: null, error: tr('noSkeleton', 'No skeleton "{{n}}" in assets/skeletons', { n: skelName }) }); return; }
    let live = true;
    files.readFile(joinPath(joinPath(assetsDir, 'skeletons'), rel)).then((r) => {
      if (!live) return;
      if ('error' in r) { setLoadedSkel({ name: skelName, raw: null, error: r.error }); return; }
      try {
        const j = JSON.parse(r.content);
        const issues = A.validateVskel(j);
        setLoadedSkel(issues.length ? { name: skelName, raw: null, error: `${skelName}.vskel: ${issues[0].message}` } : { name: skelName, raw: j });
      } catch { setLoadedSkel({ name: skelName, raw: null, error: `${skelName}.vskel: not valid JSON` }); }
    });
    return () => { live = false; };
  }, [kind, skelName, assetsDir, skelPaths, reloadTick]);   // eslint-disable-line react-hooks/exhaustive-deps
  const skelIssues = useMemo(() => (kind === 'skel' && raw ? A.validateVskel(raw, meshExists) : []), [kind, raw, meshExists]);
  // the preview needs a skeleton that holds together; a missing mesh only leaves a bone bare
  const skelSound = useMemo(() => kind === 'skel' && !!raw && !A.validateVskel(raw).length, [kind, raw]);
  const skel: A.VskelRaw | null = kind === 'skel' ? (skelSound ? (raw as unknown as A.VskelRaw) : null) : (loadedSkel?.raw ?? null);
  const joints = useMemo(() => (skel ? skel.joints.map((j) => j.name) : []), [skel]);
  const variants = useMemo(() => (skel ? A.variantNames(skel) : []), [skel]);
  const [variant, setVariant] = useState<string | null>(null);
  useEffect(() => { if (variant !== null && !variants.includes(variant)) setVariant(variants[0] ?? null); else if (variant === null && variants.length) setVariant(variants[0]); }, [variants]);   // eslint-disable-line react-hooks/exhaustive-deps
  const resolved = useMemo(() => (skel ? A.resolve(skel, variant) : null), [skel, variant]);

  // meshes, loaded as the character needs them
  const [meshData, setMeshData] = useState<Record<string, MeshStrokes | undefined>>({});
  const inFlight = useRef(new Set<string>());
  useEffect(() => { setMeshData({}); }, [reloadTick]);
  useEffect(() => {
    if (!resolved || !assetsDir || !files?.readFile || !meshPaths) return;
    for (const b of resolved.bones) {
      const n = b.mesh;
      if (!n || n in meshData || inFlight.current.has(n) || !(n in meshPaths)) continue;
      inFlight.current.add(n);
      files.readFile(joinPath(joinPath(assetsDir, 'meshes'), meshPaths[n])).then((r) => {
        inFlight.current.delete(n);
        let e: MeshStrokes;
        if ('error' in r) e = { error: r.error };
        else { try { e = meshStrokes(JSON.parse(r.content)); } catch { e = { error: 'not valid JSON' }; } }
        setMeshData((m) => ({ ...m, [n]: e }));
      }).catch(() => inFlight.current.delete(n));
    }
  }, [resolved, meshPaths, meshData, assetsDir]);   // eslint-disable-line react-hooks/exhaustive-deps

  // ── view options ──
  const [opts, setOpts] = useState<ViewOptions>({ meshes: true, bones: true, sockets: true, soft: false });
  const [selBone, setSelBone] = useState<number | null>(null);

  if (kind === 'skel') {
    return (
      <SkelPane raw={raw as unknown as A.VskelRaw | null} commit={commit} tryEdit={tryEdit} undo={undo} redo={redo} hist={hist.current}
        issues={skelIssues} resolved={resolved} variant={variant} setVariant={setVariant} variants={variants}
        meshData={meshData} meshNames={meshNames} opts={opts} setOpts={setOpts} selBone={selBone} setSelBone={setSelBone}
        message={message} reload={() => setReloadTick((n) => n + 1)} tr={tr} />
    );
  }
  return (
    <ClipPane raw={clipRaw} commit={commit} tryEdit={tryEdit} undo={undo} redo={redo} hist={hist.current} flash={flash}
      skel={skel} skelError={loadedSkel?.error ?? (skelPaths && skelName && !skelPaths[skelName] ? tr('noSkeleton', 'No skeleton "{{n}}" in assets/skeletons', { n: skelName }) : undefined)}
      joints={joints} resolved={resolved} variant={variant} setVariant={setVariant} variants={variants}
      meshData={meshData} opts={opts} setOpts={setOpts} selBone={selBone} setSelBone={setSelBone}
      message={message} reload={() => setReloadTick((n) => n + 1)} skelNames={skelPaths ? Object.keys(skelPaths).sort() : []} tr={tr} />
  );
};

type Tr = (k: string, d: string, o?: Record<string, unknown>) => string;
interface Common {
  commit: (r: Record<string, unknown>) => void;
  tryEdit: (r: { raw: unknown } | { error: string }) => boolean;
  undo: () => void;
  redo: () => void;
  hist: { stack: unknown[]; index: number };
  resolved: A.Resolved | null;
  variant: string | null;
  setVariant: (v: string | null) => void;
  variants: string[];
  meshData: Record<string, MeshStrokes | undefined>;
  opts: ViewOptions;
  setOpts: (o: ViewOptions) => void;
  selBone: number | null;
  setSelBone: (i: number | null) => void;
  message: { text: string; error: boolean } | null;
  reload: () => void;
  tr: Tr;
}

// ── the toolbar both panes share ─────────────────────────────────────────────
const Toolbar: React.FC<Common & { tabs: [string, string][]; tab: string; setTab: (t: string) => void; extra?: React.ReactNode }> = (p) => {
  const { tr } = p;
  return (
    <div style={ST.toolbar}>
      {p.tabs.map(([k, label]) => <button key={k} style={p.tab === k ? ST.btnOn : ST.btn} onClick={() => p.setTab(k)}>{label}</button>)}
      <span style={ST.sep} />
      <span style={ST.dim}>{tr('character', 'Character')}</span>
      <select style={ST.input} value={p.variant ?? ''} onChange={(e) => p.setVariant(e.target.value || null)}>
        <option value="">{tr('asModelled', '(as modelled)')}</option>
        {p.variants.map((v) => <option key={v} value={v}>{v}</option>)}
      </select>
      <span style={ST.sep} />
      {([['meshes', tr('meshes', 'Meshes')], ['bones', tr('bones', 'Bones')], ['sockets', tr('sockets', 'Sockets')], ['soft', tr('smooth', 'Smooth edges')]] as const).map(([k, label]) => (
        <label key={k} style={ST.check}><input type="checkbox" checked={p.opts[k]} onChange={(e) => p.setOpts({ ...p.opts, [k]: e.target.checked })} />{label}</label>
      ))}
      <span style={ST.sep} />
      <button style={ST.btn} disabled={p.hist.index <= 0} onClick={p.undo} title="Ctrl+Z">↶</button>
      <button style={ST.btn} disabled={p.hist.index >= p.hist.stack.length - 1} onClick={p.redo} title="Ctrl+Y">↷</button>
      <button style={ST.btn} onClick={p.reload} title={tr('reloadTip', 'Read the skeleton and the meshes again from disk')}>⟳</button>
      {p.extra}
      {p.message && <span style={{ color: p.message.error ? '#ff8080' : '#9fd89f', marginLeft: 8 }}>{p.message.text}</span>}
    </div>
  );
};

const keysFor = (undo: () => void, redo: () => void) => (e: React.KeyboardEvent) => {
  if (!(e.ctrlKey || e.metaKey) || (e.target as HTMLElement).tagName === 'INPUT') return;
  if (e.key === 'z' && !e.shiftKey) { e.preventDefault(); undo(); }
  else if (e.key === 'y' || (e.key === 'z' && e.shiftKey)) { e.preventDefault(); redo(); }
};

// ── a .vclip ────────────────────────────────────────────────────────────────
const ClipPane: React.FC<Common & {
  raw: A.VclipRaw | null; flash: (s: string, e?: boolean) => void; skel: A.VskelRaw | null; skelError?: string;
  joints: string[]; skelNames: string[];
}> = (p) => {
  const { raw, tr, joints, resolved, commit, tryEdit } = p;
  const [tab, setTab] = useState<ClipTab>('clips');
  const poseNames = useMemo(() => (raw && isObj(raw.poses) ? Object.keys(raw.poses) : []), [raw]);
  const clipNames = useMemo(() => (raw && isObj(raw.clips) ? Object.keys(raw.clips) : []), [raw]);
  const setNames = useMemo(() => (raw && isObj(raw.sets) ? Object.keys(raw.sets) : []), [raw]);
  const [selPose, setSelPose] = useState<string | null>(null);
  const [selClip, setSelClip] = useState<string | null>(null);
  const [selSet, setSelSet] = useState<string | null>(null);
  useEffect(() => { if (!selPose || !poseNames.includes(selPose)) setSelPose(poseNames[0] ?? null); }, [poseNames]);   // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (!selClip || !clipNames.includes(selClip)) setSelClip(clipNames[0] ?? null); }, [clipNames]);   // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (!selSet || !setNames.includes(selSet)) setSelSet(setNames[0] ?? null); }, [setNames]);   // eslint-disable-line react-hooks/exhaustive-deps
  const issues = useMemo(() => (raw ? A.validateVclip(raw, joints.length ? joints : undefined) : []), [raw, joints]);
  const unit = p.skel?.angle_unit ?? 4096;

  // playback: the clip under the playhead (the selected clip, or a set's role being tried)
  const [playClip, setPlayClip] = useState<string | null>(null);
  const shownClip = tab === 'sets' ? playClip : selClip;
  const clip = raw && shownClip ? raw.clips[shownClip] : undefined;
  const len = clip ? A.clipLength(clip) : 0;
  const [tHead, setTHead] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [selKey, setSelKey] = useState<number | null>(null);
  useEffect(() => { setTHead(0); setSelKey(null); }, [shownClip]);
  useEffect(() => {
    if (!playing || !clip) return;
    let last = performance.now(), id = 0;
    const step = (now: number) => {
      const dt = (now - last) / 1000; last = now;
      setTHead((t) => { const n = t + dt * FPS * speed; return len > 0 ? (n > len ? (clip.loop ? n % len : (n % (len + 12))) : n) : 0; });
      id = requestAnimationFrame(step);
    };
    id = requestAnimationFrame(step);
    return () => cancelAnimationFrame(id);
  }, [playing, clip, len, speed]);

  // what the view shows
  const shownPose: A.Pose | null = useMemo(() => {
    if (!raw || !joints.length) return null;
    if (tab === 'poses') return selPose ? { ...A.restPose(joints), ...raw.poses[selPose] } : A.restPose(joints);
    if (clip) return A.sampleClip(raw, clip, Math.min(tHead, len), joints);
    if (tab === 'sets' && selSet) { const g = raw.sets[selSet]?.poses?.guard ?? Object.values(raw.sets[selSet]?.poses ?? {})[0]; if (g && raw.poses[g]) return { ...A.restPose(joints), ...raw.poses[g] }; }
    return A.restPose(joints);
  }, [raw, joints, tab, selPose, clip, tHead, len, selSet]);
  const posed = useMemo(() => (resolved && shownPose ? A.pose(resolved, shownPose) : null), [resolved, shownPose]);
  const [showGhost, setShowGhost] = useState(false);
  const ghost = useMemo(() => {
    if (!showGhost || !raw || !clip || !resolved || tab === 'poses') return null;
    const prev = [...clip.keys].reverse().find((k) => k.frame < tHead);
    return prev && raw.poses[prev.pose] ? A.pose(resolved, { ...A.restPose(joints), ...raw.poses[prev.pose] }) : null;
  }, [showGhost, raw, clip, resolved, tab, tHead, joints]);

  // ── edits ──
  const ask = (q: string, d: string) => { const s = window.prompt(q, d); return s === null ? null : s.trim(); };
  const addPose = () => {
    if (!raw) return;
    const name = ask(tr('newPoseQ', 'Name of the new pose'), A.freshName(selPose ? `${selPose}_copy` : 'pose', poseNames));
    if (!name) return;
    const from = selPose ? raw.poses[selPose] : A.restPose(joints);
    if (tryEdit(A.addPose(raw, name, shownPose && tab !== 'poses' ? roundPose(shownPose) : from))) { setSelPose(name); setTab('poses'); }
  };
  const roundPose = (q: A.Pose): A.Pose => Object.fromEntries(Object.entries(q).map(([k, v]) => [k, Math.round(v)]));
  const renamePose = () => { if (!raw || !selPose) return; const n = ask(tr('renameQ', 'New name'), selPose); if (n && tryEdit(A.renamePose(raw, selPose, n))) setSelPose(n); };
  const deletePose = () => { if (raw && selPose) tryEdit(A.deletePose(raw, selPose)); };
  const addClip = () => {
    if (!raw) return;
    const name = ask(tr('newClipQ', 'Name of the new clip'), A.freshName('clip', clipNames));
    if (name && tryEdit(A.addClip(raw, name, selPose ?? poseNames[0] ?? ''))) setSelClip(name);
  };
  const dupClip = () => {
    if (!raw || !selClip) return;
    const name = ask(tr('newClipQ', 'Name of the new clip'), A.freshName(`${selClip}_copy`, clipNames));
    if (!name) return;
    if (name in raw.clips) { p.flash(tr('exists', 'That name is taken'), true); return; }
    commit({ ...raw, clips: { ...raw.clips, [name]: structuredClone(raw.clips[selClip]) } } as unknown as Record<string, unknown>);
    setSelClip(name);
  };
  const renameClip = () => { if (!raw || !selClip) return; const n = ask(tr('renameQ', 'New name'), selClip); if (n && tryEdit(A.renameClip(raw, selClip, n))) setSelClip(n); };
  const deleteClip = () => { if (raw && selClip) tryEdit(A.deleteClip(raw, selClip)); };
  const setClip = (c: A.ClipRaw) => { if (raw && selClip) commit(A.setClip(raw, selClip, c) as unknown as Record<string, unknown>); };
  const editSet = (name: string, f: (s: A.SetRaw) => A.SetRaw) => { if (raw) commit({ ...raw, sets: { ...raw.sets, [name]: f(raw.sets[name] ?? {}) } } as unknown as Record<string, unknown>); };
  const addSet = () => {
    if (!raw) return;
    const name = ask(tr('newSetQ', 'Name of the new set (a character or a style)'), A.freshName('set', setNames));
    if (!name) return;
    if (name in raw.sets) { p.flash(tr('exists', 'That name is taken'), true); return; }
    commit({ ...raw, sets: { ...raw.sets, [name]: { poses: {}, clips: {}, props: {} } } } as unknown as Record<string, unknown>);
    setSelSet(name);
  };
  const renameSet = () => {
    if (!raw || !selSet) return;
    const n = ask(tr('renameQ', 'New name'), selSet);
    if (!n || n === selSet) return;
    if (n in raw.sets) { p.flash(tr('exists', 'That name is taken'), true); return; }
    commit({ ...raw, sets: Object.fromEntries(Object.entries(raw.sets).map(([k, v]) => [k === selSet ? n : k, v])) } as unknown as Record<string, unknown>);
    setSelSet(n);
  };
  const deleteSet = () => { if (!raw || !selSet) return; const s = { ...raw.sets }; delete s[selSet]; commit({ ...raw, sets: s } as unknown as Record<string, unknown>); };

  const startNew = () => {
    const sk = p.skelNames[0] ?? 'skeleton';
    commit(A.newVclip(sk, joints) as unknown as Record<string, unknown>);
  };

  // ── panels ──
  const listButtons = (add: () => void, extra: [string, () => void, boolean][]) => (
    <div style={ST.btnGrid}>
      <button style={ST.btnSmall} onClick={add} disabled={!raw}>{tr('add', '+ Add')}</button>
      {extra.map(([label, f, dis]) => <button key={label} style={ST.btnSmall} onClick={f} disabled={dis}>{label}</button>)}
    </div>
  );
  const left = (
    <div style={ST.panelLeft}>
      {tab === 'poses' && (
        <Section title={tr('posesN', 'Poses ({{n}})', { n: poseNames.length })}>
          <div style={ST.listTall}>
            {poseNames.map((n) => <div key={n} style={{ ...ST.listItem, ...(n === selPose ? ST.listOn : {}) }} onClick={() => setSelPose(n)}>{n}</div>)}
          </div>
          {listButtons(addPose, [[tr('rename', 'Rename'), renamePose, !selPose], [tr('delete', 'Delete'), deletePose, !selPose]])}
        </Section>
      )}
      {tab === 'clips' && (
        <Section title={tr('clipsN', 'Clips ({{n}})', { n: clipNames.length })}>
          <div style={ST.listTall}>
            {clipNames.map((n) => <div key={n} style={{ ...ST.listItem, ...(n === selClip ? ST.listOn : {}) }} onClick={() => setSelClip(n)}>{n} <span style={ST.dim}>{raw ? A.clipLength(raw.clips[n]) : ''}f</span></div>)}
          </div>
          {listButtons(addClip, [[tr('duplicate', 'Duplicate'), dupClip, !selClip], [tr('rename', 'Rename'), renameClip, !selClip], [tr('delete', 'Delete'), deleteClip, !selClip]])}
        </Section>
      )}
      {tab === 'sets' && (
        <Section title={tr('setsN', 'Sets ({{n}})', { n: setNames.length })}>
          <div style={ST.listTall}>
            {setNames.map((n) => <div key={n} style={{ ...ST.listItem, ...(n === selSet ? ST.listOn : {}) }} onClick={() => setSelSet(n)}>{n}</div>)}
          </div>
          {listButtons(addSet, [[tr('rename', 'Rename'), renameSet, !selSet], [tr('delete', 'Delete'), deleteSet, !selSet]])}
        </Section>
      )}
      <Section title={issues.length ? tr('problems', 'Problems: {{n}}', { n: issues.length }) : tr('checks', 'Checks')}>
        {!issues.length ? <div style={{ color: '#9fd89f' }}>{tr('valid', 'No errors.')}</div> : (
          <div style={ST.list}>
            {issues.slice(0, 100).map((is, k) => (
              <div key={k} style={{ ...ST.listItem, color: '#ff8080' }} title={is.message}
                onClick={() => { if (is.pose) { setTab('poses'); setSelPose(is.pose); } else if (is.clip) { setTab('clips'); setSelClip(is.clip); } else if (is.set) { setTab('sets'); setSelSet(is.set); } }}>✖ {is.message}</div>
            ))}
          </div>
        )}
      </Section>
      <Section title={tr('library', 'Library')}>
        <Row label={tr('skeleton', 'Skeleton')}>
          <select style={{ ...ST.input, maxWidth: 140 }} value={raw?.skeleton ?? ''} disabled={!raw}
            onChange={(e) => raw && commit({ ...raw, skeleton: e.target.value } as unknown as Record<string, unknown>)}>
            {raw && !p.skelNames.includes(raw.skeleton) && <option value={raw.skeleton}>{raw.skeleton} ({tr('missing', 'missing')})</option>}
            {p.skelNames.map((n) => <option key={n} value={n}>{n}</option>)}
          </select>
        </Row>
      </Section>
    </div>
  );

  // the pose being edited: the Poses tab's, or (Clips) the selected key's
  const editPose = tab === 'poses' ? selPose : tab === 'clips' && clip && selKey !== null ? clip.keys[selKey]?.pose ?? null : null;
  const jointPanel = editPose && raw && raw.poses[editPose] ? (
    <JointSliders pose={raw.poses[editPose]} joints={joints} skel={p.skel} unit={unit} resolved={resolved} selBone={p.selBone}
      onPickJoint={(j) => { const i = resolved?.bones.findIndex((b) => b.rotate.some((t) => t.joint === j)); if (i !== undefined && i >= 0) p.setSelBone(i); }}
      onSet={(j, a) => commit(A.setPoseJoint(raw, editPose, j, a) as unknown as Record<string, unknown>)}
      title={tr('poseOf', 'Pose "{{n}}"', { n: editPose })} users={A.poseUsers(raw, editPose)} tr={tr} />
  ) : null;

  const right = (
    <div style={ST.panel}>
      {tab === 'poses' && (jointPanel ?? <div style={ST.dim}>{tr('noPose', 'Select a pose, or add one.')}</div>)}
      {tab === 'clips' && (!clip || !selClip ? <div style={ST.dim}>{tr('noClip', 'Select a clip, or add one.')}</div> : (
        <>
          <Section title={tr('clipN', 'Clip "{{n}}"', { n: selClip })}>
            <Row label={tr('loop', 'Loop')}><input type="checkbox" checked={!!clip.loop} onChange={(e) => setClip({ ...clip, loop: e.target.checked })} /></Row>
            <PropsEditor props={clip.props ?? {}} onChange={(pr) => setClip({ ...clip, props: pr })} tr={tr} />
            {A.clipUsers(raw!, selClip).length > 0 && <div style={ST.note}>{tr('usedBy', 'Used by: {{u}}', { u: A.clipUsers(raw!, selClip).join(', ') })}</div>}
          </Section>
          <Section title={tr('keys', 'Keys')}>
            {clip.keys.map((k, i) => (
              <div key={i} style={{ ...ST.row, ...(i === selKey ? { background: '#26264a' } : {}) }} onClick={() => { setSelKey(i); setTHead(k.frame); setPlaying(false); }}>
                <NumIn value={k.frame} width={46} onCommit={(n) => { const r = A.moveKey(clip, i, n); if (refused(r)) p.flash(r.error, true); else setClip(r); }} />
                <select style={{ ...ST.input, flex: 1, minWidth: 0 }} value={k.pose} onChange={(e) => setClip({ ...clip, keys: clip.keys.map((x, j) => (j === i ? { ...x, pose: e.target.value } : x)) })}>
                  {!poseNames.includes(k.pose) && <option value={k.pose}>{k.pose} ?</option>}
                  {poseNames.map((n) => <option key={n} value={n}>{n}</option>)}
                </select>
                <button style={ST.btnSmall} title={tr('delKey', 'Delete this key')} onClick={(e) => { e.stopPropagation(); const r = A.deleteKey(clip, i); if (refused(r)) p.flash(r.error, true); else { setClip(r); setSelKey(null); } }}>✕</button>
              </div>
            ))}
            <div style={ST.btnGrid}>
              <button style={ST.btnSmall} onClick={() => { const f = Math.round(tHead); const at = clip.keys.find((k) => k.frame === f); setClip(A.putKey(clip, f, at?.pose ?? [...clip.keys].reverse().find((k) => k.frame <= f)?.pose ?? clip.keys[0].pose)); }}>
                {tr('keyHere', '+ Key at frame {{f}}', { f: Math.round(tHead) })}
              </button>
              <button style={ST.btnSmall} title={tr('keyNewPoseTip', 'A new pose from what the view shows now, keyed at the playhead')} onClick={() => {
                if (!raw || !shownPose) return;
                const name = ask(tr('newPoseQ', 'Name of the new pose'), A.freshName(`${selClip}_${Math.round(tHead)}`, poseNames));
                if (!name) return;
                const r = A.addPose(raw, name, roundPose(shownPose));
                if ('error' in r) { p.flash(r.error, true); return; }
                commit(A.setClip(r.raw, selClip, A.putKey(clip, Math.round(tHead), name)) as unknown as Record<string, unknown>);
              }}>{tr('keyNewPose', '+ New pose here')}</button>
            </div>
          </Section>
          <Section title={tr('marks', 'Marks')}>
            {(clip.marks ?? []).map((m, i) => (
              <div key={i} style={ST.row}>
                <NumIn value={m.frame} width={42} onCommit={(n) => setClip({ ...clip, marks: clip.marks!.map((x, j) => (j === i ? { ...x, frame: Math.round(n) } : x)) })} />
                <TextIn value={m.name} width={86} onCommit={(s) => s && setClip({ ...clip, marks: clip.marks!.map((x, j) => (j === i ? { ...x, name: s } : x)) })} />
                <OptNumIn value={m.value ?? null} width={46} placeholder={tr('value', 'value')} onCommit={(n) => setClip({ ...clip, marks: clip.marks!.map((x, j) => { if (j !== i) return x; const y = { ...x }; if (n === undefined) delete y.value; else y.value = Math.round(n); return y; }) })} />
                <button style={ST.btnSmall} onClick={() => setClip({ ...clip, marks: clip.marks!.filter((_, j) => j !== i) })}>✕</button>
              </div>
            ))}
            <button style={ST.btnSmall} onClick={() => setClip({ ...clip, marks: [...(clip.marks ?? []), { frame: Math.min(Math.round(tHead), len), name: 'mark' }].sort((a, b) => a.frame - b.frame) })}>
              {tr('markHere', '+ Mark at frame {{f}}', { f: Math.min(Math.round(tHead), len) })}
            </button>
          </Section>
          {jointPanel}
        </>
      ))}
      {tab === 'sets' && (!selSet || !raw ? <div style={ST.dim}>{tr('noSet', 'Select a set, or add one.')}</div> : (
        <>
          <RoleTable title={tr('setPoses', 'Poses (stance → pose)')} roles={raw.sets[selSet].poses ?? {}} names={poseNames} tr={tr}
            onChange={(r) => editSet(selSet, (s) => ({ ...s, poses: r }))} />
          <RoleTable title={tr('setClips', 'Clips (role → clip)')} roles={raw.sets[selSet].clips ?? {}} names={clipNames} tr={tr}
            onChange={(r) => editSet(selSet, (s) => ({ ...s, clips: r }))} play={(c) => { setPlayClip(c); setTHead(0); setPlaying(true); }} playing={playClip} />
          <Section title={tr('setProps', 'Properties')}>
            <PropsEditor props={raw.sets[selSet].props ?? {}} onChange={(pr) => editSet(selSet, (s) => ({ ...s, props: pr }))} tr={tr} />
          </Section>
        </>
      ))}
      <div style={ST.help}>{tr('help', 'Click a joint in the view to find its sliders · drag: orbit (3D) or pan · middle drag: pan · wheel: zoom · Space: play · Ctrl+Z / Ctrl+Y')}</div>
    </div>
  );

  const timeline = clip && tab !== 'poses' ? (
    <Timeline clip={clip} t={tHead} setT={(x) => { setTHead(x); setPlaying(false); }} selKey={selKey}
      onSelKey={(i) => { setSelKey(i); if (i !== null) setTHead(clip.keys[i].frame); }}
      onMoveKey={tab === 'clips' ? (i, f) => { const r = A.moveKey(clip, i, f); if (!refused(r)) setClip(r); } : undefined}
      playing={playing} setPlaying={setPlaying} speed={speed} setSpeed={setSpeed} ghost={showGhost} setGhost={setShowGhost} tr={tr} />
  ) : null;

  return (
    <div style={ST.root} tabIndex={0} onKeyDown={(e) => {
      keysFor(p.undo, p.redo)(e);
      if (e.key === ' ' && (e.target as HTMLElement).tagName !== 'INPUT' && clip) { e.preventDefault(); setPlaying((x) => !x); }
    }}>
      <Toolbar {...p} tabs={[['poses', tr('tabPoses', 'Poses')], ['clips', tr('tabClips', 'Clips')], ['sets', tr('tabSets', 'Sets')]]} tab={tab} setTab={(x) => setTab(x as ClipTab)} />
      <div style={ST.body}>
        {left}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <Viewport3D viewLabels={{ '3D': tr('view3d', '3D'), Front: tr('viewFront', 'Front'), Side: tr('viewSide', 'Side'), Top: tr('viewTop', 'Top') }} resolved={resolved} posed={posed} ghost={ghost} meshes={p.meshData} options={p.opts} selBone={p.selBone} onPickBone={p.setSelBone}
            overlay={!raw ? (<>{tr('notJson', 'This document is not a .vclip JSON object.')} <button style={ST.btn} onClick={startNew}>{tr('startNew', 'Start a new library (replaces the text)')}</button></>)
              : p.skelError ? p.skelError : !p.skel ? tr('loadingSkel', 'Reading the skeleton…') : undefined}
            status={<>
              <span>{p.variant ?? tr('asModelled', '(as modelled)')}</span>
              {resolved && <span>{tr('bonesN', '{{n}} bones', { n: resolved.bones.length })}</span>}
              {clip && <span>{tr('frameOf', 'frame {{t}} / {{n}}', { t: Math.min(tHead, len).toFixed(1), n: len })}</span>}
              {p.selBone !== null && resolved?.bones[p.selBone] && <span>{resolved.bones[p.selBone].name}</span>}
            </>} />
          {timeline}
        </div>
        {right}
      </div>
    </div>
  );
};

// ── a pose's joints ──────────────────────────────────────────────────────────
const JointSliders: React.FC<{
  pose: A.Pose; joints: string[]; skel: A.VskelRaw | null; unit: number; resolved: A.Resolved | null; selBone: number | null;
  onSet: (j: string, a: number) => void; onPickJoint: (j: string) => void; title: string; users: string[]; tr: Tr;
}> = ({ pose, joints, skel, unit, resolved, selBone, onSet, onPickJoint, title, users, tr }) => {
  const hot = new Set(selBone !== null && resolved?.bones[selBone] ? resolved.bones[selBone].rotate.map((t) => t.joint).filter(Boolean) as string[] : []);
  return (
    <Section title={title}>
      {users.length > 1 && <div style={ST.note}>{tr('sharedPose', 'Shared by {{n}}: {{u}}', { n: users.length, u: users.slice(0, 6).join(', ') + (users.length > 6 ? '…' : '') })}</div>}
      {joints.map((j) => {
        const a = pose[j] ?? 0;
        const def = skel?.joints.find((x) => x.name === j);
        const lo = typeof def?.min === 'number' ? def.min : -unit / 2, hi = typeof def?.max === 'number' ? def.max : unit / 2;
        return (
          <div key={j} style={{ margin: '4px 0', ...(hot.has(j) ? { background: '#2a2a4a', borderRadius: 3 } : {}) }}>
            <div style={{ ...ST.row, margin: 0 }}>
              <span style={{ ...ST.label, cursor: 'pointer' }} onClick={() => onPickJoint(j)} title={tr('jointTip', 'Show the bone it turns')}>{j}</span>
              <span style={{ display: 'flex', gap: 3, alignItems: 'center' }}>
                <NumIn value={Math.round(A.toDeg(a, unit) * 10) / 10} width={52} step={1} onCommit={(d) => onSet(j, A.fromDeg(d, unit))} />
                <span style={ST.dim}>°</span>
                <NumIn value={a} width={52} onCommit={(n) => onSet(j, Math.round(n))} />
              </span>
            </div>
            <input type="range" min={lo} max={hi} step={1} value={Math.max(lo, Math.min(hi, a))} style={{ width: '100%' }}
              onChange={(e) => onSet(j, Number(e.target.value))} />
          </div>
        );
      })}
      <div style={ST.help}>{tr('unitsHelp', 'Degrees, and the file\'s own units ({{u}} per turn)', { u: unit })}</div>
    </Section>
  );
};

// ── the timeline under the view ──────────────────────────────────────────────
const Timeline: React.FC<{
  clip: A.ClipRaw; t: number; setT: (t: number) => void; selKey: number | null; onSelKey: (i: number | null) => void;
  onMoveKey?: (i: number, f: number) => void; playing: boolean; setPlaying: (b: boolean) => void; speed: number; setSpeed: (s: number) => void;
  ghost: boolean; setGhost: (b: boolean) => void; tr: Tr;
}> = ({ clip, t, setT, selKey, onSelKey, onMoveKey, playing, setPlaying, speed, setSpeed, ghost, setGhost, tr }) => {
  const ref = useRef<HTMLDivElement>(null);
  const len = Math.max(1, A.clipLength(clip));
  const span = len + 2;
  const xOf = (f: number) => `${(f / span) * 100}%`;
  const frameAt = (clientX: number) => {
    const r = ref.current!.getBoundingClientRect();
    return Math.max(0, Math.min(span, ((clientX - r.left) / r.width) * span));
  };
  const drag = useRef<{ key: number | null } | null>(null);
  useEffect(() => {
    const move = (e: MouseEvent) => {
      const d = drag.current;
      if (!d) return;
      const f = frameAt(e.clientX);
      if (d.key !== null && onMoveKey) onMoveKey(d.key, Math.round(f));
      else setT(Math.min(f, len));
    };
    const up = () => { drag.current = null; };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
    return () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
  });
  return (
    <div style={ST.timelineBar}>
      <button style={playing ? ST.btnOn : ST.btn} onClick={() => setPlaying(!playing)} title={tr('playTip', 'Play at the game\'s 50 frames a second (Space)')}>{playing ? '❚❚' : '▶'}</button>
      <select style={ST.input} value={speed} onChange={(e) => setSpeed(Number(e.target.value))} title={tr('speedTip', 'Playback speed')}>
        {[0.1, 0.25, 0.5, 1].map((s) => <option key={s} value={s}>{s}×</option>)}
      </select>
      <label style={ST.check} title={tr('ghostTip', 'Draw the last key passed, faintly')}><input type="checkbox" checked={ghost} onChange={(e) => setGhost(e.target.checked)} />{tr('ghost', 'Ghost')}</label>
      <div ref={ref} style={ST.track} onMouseDown={(e) => { drag.current = { key: null }; setT(Math.min(frameAt(e.clientX), len)); onSelKey(null); }}>
        {Array.from({ length: Math.floor(span) + 1 }, (_, f) => (
          <div key={f} style={{ position: 'absolute', left: xOf(f), top: f % 5 ? 20 : 14, bottom: 0, width: 1, background: f <= len ? '#33334d' : '#222233' }}>
            {f % 5 === 0 && <span style={{ position: 'absolute', top: -13, left: 2, fontSize: 9, color: '#667' }}>{f}</span>}
          </div>
        ))}
        {(clip.marks ?? []).map((m, i) => (
          <div key={`m${i}`} title={`${m.name}${m.value !== undefined ? ` = ${m.value}` : ''} @ ${m.frame}`}
            style={{ position: 'absolute', left: xOf(m.frame), top: 0, bottom: 0, borderLeft: '1px dashed #e6c07a' }}>
            <span style={{ position: 'absolute', top: 1, left: 3, fontSize: 9, color: '#e6c07a', whiteSpace: 'nowrap' }}>{m.name}</span>
          </div>
        ))}
        {clip.keys.map((k, i) => (
          <div key={`k${i}`} title={`${k.pose} @ ${k.frame}`}
            onMouseDown={(e) => { e.stopPropagation(); onSelKey(i); drag.current = { key: onMoveKey ? i : null }; }}
            style={{ position: 'absolute', left: xOf(k.frame), top: 26, width: 11, height: 11, marginLeft: -5.5, transform: 'rotate(45deg)',
              background: i === selKey ? '#ffd27a' : '#7a8fd8', border: '1px solid #0b0b12', cursor: onMoveKey ? 'ew-resize' : 'pointer' }} />
        ))}
        <div style={{ position: 'absolute', left: xOf(Math.min(t, len)), top: 0, bottom: 0, width: 2, marginLeft: -1, background: '#ff6b6b', pointerEvents: 'none' }} />
      </div>
    </div>
  );
};

// ── role → name tables (a set's stances and clips) ───────────────────────────
const RoleTable: React.FC<{ title: string; roles: Record<string, string>; names: string[]; onChange: (r: Record<string, string>) => void; play?: (c: string) => void; playing?: string | null; tr: Tr }> = ({ title, roles, names, onChange, play, playing, tr }) => (
  <Section title={title}>
    {Object.entries(roles).map(([role, v]) => (
      <div key={role} style={ST.row}>
        <TextIn value={role} width={70} onCommit={(s) => { if (s && s !== role && !(s in roles)) onChange(Object.fromEntries(Object.entries(roles).map(([k, x]) => [k === role ? s : k, x]))); }} />
        <select style={{ ...ST.input, flex: 1, minWidth: 0 }} value={v} onChange={(e) => onChange({ ...roles, [role]: e.target.value })}>
          {!names.includes(v) && <option value={v}>{v} ?</option>}
          {names.map((n) => <option key={n} value={n}>{n}</option>)}
        </select>
        {play && <button style={playing === v ? ST.btnOnSmall : ST.btnSmall} onClick={() => play(v)} title={tr('tryRole', 'Play it')}>▶</button>}
        <button style={ST.btnSmall} onClick={() => { const r = { ...roles }; delete r[role]; onChange(r); }}>✕</button>
      </div>
    ))}
    <button style={ST.btnSmall} disabled={!names.length} onClick={() => onChange({ ...roles, [A.freshName('role', Object.keys(roles))]: names[0] })}>{tr('addRole', '+ Role')}</button>
  </Section>
);

const PropsEditor: React.FC<{ props: Record<string, number>; onChange: (p: Record<string, number>) => void; tr: Tr }> = ({ props, onChange, tr }) => (
  <div>
    <div style={ST.subTitle}>{tr('props', 'Properties (whole numbers the game reads)')}</div>
    {Object.entries(props).map(([k, v]) => (
      <div key={k} style={ST.row}>
        <TextIn value={k} width={90} onCommit={(s) => { if (s && s !== k && !(s in props)) onChange(Object.fromEntries(Object.entries(props).map(([a, b]) => [a === k ? s : a, b]))); }} />
        <NumIn value={v} width={60} onCommit={(n) => onChange({ ...props, [k]: Math.round(n) })} />
        <button style={ST.btnSmall} onClick={() => { const r = { ...props }; delete r[k]; onChange(r); }}>✕</button>
      </div>
    ))}
    <button style={ST.btnSmall} onClick={() => onChange({ ...props, [A.freshName('prop', Object.keys(props))]: 0 })}>{tr('addProp', '+ Property')}</button>
  </div>
);

// ── a .vskel ────────────────────────────────────────────────────────────────
const SkelPane: React.FC<Common & { raw: A.VskelRaw | null; issues: A.Issue[]; meshNames: string[] }> = (p) => {
  const { raw, tr, commit, tryEdit, resolved } = p;
  const [tab, setTab] = useState<SkelTab>('bones');
  const [selJoint, setSelJoint] = useState<string | null>(null);
  const [selVariant, setSelVariant] = useState<string | null>(null);
  const [test, setTest] = useState<A.Pose>({});
  const unit = raw?.angle_unit ?? 4096;
  const bones = raw?.bones ?? [];
  const jointList = raw?.joints ?? [];
  const sel = p.selBone !== null && resolved ? resolved.bones[p.selBone]?.name : null;
  const selShared = sel ? bones.find((b) => b.name === sel) : undefined;
  const posed = useMemo(() => (resolved ? A.pose(resolved, { ...A.restPose(resolved.joints), ...test }) : null), [resolved, test]);
  const set = (r: A.VskelRaw) => commit(r as unknown as Record<string, unknown>);
  const ask = (q: string, d: string) => { const s = window.prompt(q, d); return s === null ? null : s.trim(); };
  const editBone = (name: string, f: (b: A.BoneRaw) => A.BoneRaw) => raw && set({ ...raw, bones: raw.bones.map((b) => (b.name === name ? f(b) : b)) });
  const depth = (b: A.BoneRaw): number => { let d = 0, q = b; while (q.parent && d < 30) { const pb = bones.find((x) => x.name === q.parent); if (!pb) break; q = pb; d++; } return d; };
  const meshSelect = (value: string | null, onPick: (m: string | null) => void, inherit?: string) => (
    <select style={{ ...ST.input, maxWidth: 150 }} value={value === undefined ? '\u0001' : value ?? ''} onChange={(e) => onPick(e.target.value === '' ? null : e.target.value)}>
      {inherit !== undefined && <option value={'\u0001'}>{tr('inherit', '(shared: {{m}})', { m: inherit || tr('none', 'none') })}</option>}
      <option value="">{tr('none', 'none')}</option>
      {value && !p.meshNames.includes(value) && <option value={value}>{value} ({tr('missing', 'missing')})</option>}
      {p.meshNames.map((n) => <option key={n} value={n}>{n}</option>)}
    </select>
  );

  const left = (
    <div style={ST.panelLeft}>
      {tab === 'bones' && (
        <Section title={tr('bonesN', '{{n}} bones', { n: bones.length })}>
          <div style={ST.listTall}>
            {(resolved?.bones ?? []).map((b, i) => (
              <div key={b.name} style={{ ...ST.listItem, ...(i === p.selBone ? ST.listOn : {}), paddingLeft: 3 + (bones.find((x) => x.name === b.name) ? depth(bones.find((x) => x.name === b.name)!) : 1) * 10 }}
                onClick={() => p.setSelBone(i)}>{b.name}{!bones.some((x) => x.name === b.name) && <span style={ST.dim}> ({p.variant})</span>}</div>
            ))}
          </div>
          <div style={ST.btnGrid}>
            <button style={ST.btnSmall} disabled={!raw} onClick={() => {
              if (!raw) return;
              const name = ask(tr('newBoneQ', 'Name of the new bone'), A.freshName('bone', A.allBoneNames(raw)));
              if (!name) return;
              if (A.allBoneNames(raw).has(name)) { tryEdit({ error: tr('exists', 'That name is taken') }); return; }
              set({ ...raw, bones: [...raw.bones, { name, parent: selShared?.name ?? raw.bones[0].name, offset: [0, -400, 0], mesh: null, rotate: [] }] });
            }}>{tr('addChild', '+ Child bone')}</button>
            <button style={ST.btnSmall} disabled={!selShared} onClick={() => { if (raw && selShared) { const n = ask(tr('renameQ', 'New name'), selShared.name); if (n) tryEdit(A.renameBone(raw, selShared.name, n)); } }}>{tr('rename', 'Rename')}</button>
            <button style={ST.btnSmall} disabled={!selShared} onClick={() => { if (raw && selShared && tryEdit(A.deleteBone(raw, selShared.name))) p.setSelBone(null); }}>{tr('delete', 'Delete')}</button>
          </div>
        </Section>
      )}
      {tab === 'joints' && (
        <Section title={tr('jointsN', '{{n}} joints', { n: jointList.length })}>
          <div style={ST.listTall}>
            {jointList.map((j) => <div key={j.name} style={{ ...ST.listItem, ...(j.name === selJoint ? ST.listOn : {}) }} onClick={() => setSelJoint(j.name)}>{j.name}</div>)}
          </div>
          <div style={ST.btnGrid}>
            <button style={ST.btnSmall} disabled={!raw} onClick={() => { if (!raw) return; const n = ask(tr('newJointQ', 'Name of the new joint'), A.freshName('joint', jointList.map((j) => j.name))); if (n) { if (jointList.some((j) => j.name === n)) tryEdit({ error: tr('exists', 'That name is taken') }); else { set({ ...raw, joints: [...raw.joints, { name: n }] }); setSelJoint(n); } } }}>{tr('add', '+ Add')}</button>
            <button style={ST.btnSmall} disabled={!selJoint} onClick={() => { if (raw && selJoint) { const n = ask(tr('renameQ', 'New name'), selJoint); if (n && tryEdit(A.renameJoint(raw, selJoint, n))) setSelJoint(n); } }}>{tr('rename', 'Rename')}</button>
            <button style={ST.btnSmall} disabled={!selJoint} onClick={() => { if (raw && selJoint) tryEdit(A.deleteJoint(raw, selJoint)); }}>{tr('delete', 'Delete')}</button>
          </div>
          <div style={ST.note}>{tr('jointRenameNote', 'Renaming a joint does not rename it in the .vclip files that pose it: edit those too.')}</div>
        </Section>
      )}
      {tab === 'variants' && (
        <Section title={tr('variantsN', '{{n}} variants', { n: p.variants.length })}>
          <div style={ST.listTall}>
            {p.variants.map((v) => <div key={v} style={{ ...ST.listItem, ...(v === selVariant ? ST.listOn : {}) }} onClick={() => { setSelVariant(v); p.setVariant(v); }}>{v}</div>)}
          </div>
          <div style={ST.btnGrid}>
            <button style={ST.btnSmall} disabled={!raw} onClick={() => { if (!raw) return; const n = ask(tr('newVariantQ', 'Name of the new variant (a character)'), A.freshName('character', p.variants)); if (!n) return; if (p.variants.includes(n)) { tryEdit({ error: tr('exists', 'That name is taken') }); return; } set({ ...raw, variants: { ...(raw.variants ?? {}), [n]: { scale: 256, meshes: {} } } }); setSelVariant(n); p.setVariant(n); }}>{tr('add', '+ Add')}</button>
            <button style={ST.btnSmall} disabled={!selVariant} onClick={() => { if (!raw || !selVariant) return; const n = ask(tr('renameQ', 'New name'), selVariant); if (!n || n === selVariant) return; if (p.variants.includes(n)) { tryEdit({ error: tr('exists', 'That name is taken') }); return; } set({ ...raw, variants: Object.fromEntries(Object.entries(raw.variants ?? {}).map(([k, v]) => [k === selVariant ? n : k, v])) }); setSelVariant(n); p.setVariant(n); }}>{tr('rename', 'Rename')}</button>
            <button style={ST.btnSmall} disabled={!selVariant} onClick={() => { if (!raw || !selVariant) return; const v = { ...(raw.variants ?? {}) }; delete v[selVariant]; set({ ...raw, variants: v }); setSelVariant(null); }}>{tr('delete', 'Delete')}</button>
          </div>
        </Section>
      )}
      <Section title={p.issues.length ? tr('problems', 'Problems: {{n}}', { n: p.issues.length }) : tr('checks', 'Checks')}>
        {!p.issues.length ? <div style={{ color: '#9fd89f' }}>{tr('valid', 'No errors.')}</div> : (
          <div style={ST.list}>{p.issues.slice(0, 100).map((is, k) => <div key={k} style={{ ...ST.listItem, color: '#ff8080' }} title={is.message}>✖ {is.message}</div>)}</div>
        )}
      </Section>
    </div>
  );

  const vr = selVariant && raw?.variants?.[selVariant];
  const right = (
    <div style={ST.panel}>
      {tab === 'bones' && (!selShared ? <div style={ST.dim}>{sel ? tr('variantBone', '"{{b}}" belongs to the variant: edit it as text.', { b: sel }) : tr('noBone', 'Select a bone (here or in the view).')}</div> : (
        <>
          <Section title={tr('boneN', 'Bone "{{n}}"', { n: selShared.name })}>
            <Row label={tr('parent', 'Hangs from')}>
              {selShared.parent === null ? <span style={ST.dim}>{tr('root', '(the root)')}</span> : (
                <select style={ST.input} value={selShared.parent} onChange={(e) => editBone(selShared.name, (b) => ({ ...b, parent: e.target.value }))}>
                  {bones.slice(0, bones.indexOf(selShared)).map((b) => <option key={b.name} value={b.name}>{b.name}</option>)}
                </select>
              )}
            </Row>
            <Row label={tr('offset', 'Offset')} tip={tr('offsetTip', 'Where its joint is, in the parent\'s frame (x right, y up, z ahead)')}>
              {[0, 1, 2].map((k) => <NumIn key={k} value={selShared.offset[k]} width={52} onCommit={(n) => editBone(selShared.name, (b) => { const o = [...b.offset] as A.Vec3; o[k] = Math.round(n); return { ...b, offset: o }; })} />)}
            </Row>
            <Row label={tr('mesh', 'Mesh')}>{meshSelect(selShared.mesh, (m) => editBone(selShared.name, (b) => ({ ...b, mesh: m })))}</Row>
          </Section>
          <Section title={tr('turns', 'Turns (first outermost)')}>
            {(selShared.rotate ?? []).map((tn, i) => (
              <div key={i} style={ST.row}>
                <select style={ST.input} value={tn.axis} onChange={(e) => editBone(selShared.name, (b) => ({ ...b, rotate: b.rotate!.map((x, j) => (j === i ? { ...x, axis: e.target.value as A.Axis } : x)) }))}>
                  {(['x', 'y', 'z'] as const).map((a) => <option key={a} value={a}>{a}</option>)}
                </select>
                <select style={{ ...ST.input, maxWidth: 96 }} value={tn.joint ?? ''} onChange={(e) => editBone(selShared.name, (b) => ({ ...b, rotate: b.rotate!.map((x, j) => { if (j !== i) return x; const y = { ...x }; if (e.target.value) y.joint = e.target.value; else delete y.joint; return y; }) }))}>
                  <option value="">{tr('constant', '(constant)')}</option>
                  {jointList.map((j) => <option key={j.name} value={j.name}>{j.name}</option>)}
                </select>
                {(['mul', 'div', 'add'] as const).map((f) => (
                  <NumIn key={f} value={tn[f] ?? (f === 'add' ? 0 : 1)} width={38} title={f} onCommit={(n) => editBone(selShared.name, (b) => ({ ...b, rotate: b.rotate!.map((x, j) => { if (j !== i) return x; const y = { ...x }; const v = Math.round(n); if (v === (f === 'add' ? 0 : 1)) delete y[f]; else y[f] = v; return y; }) }))} />
                ))}
                <button style={ST.btnSmall} onClick={() => editBone(selShared.name, (b) => ({ ...b, rotate: b.rotate!.filter((_, j) => j !== i) }))}>✕</button>
              </div>
            ))}
            <button style={ST.btnSmall} disabled={!jointList.length} onClick={() => editBone(selShared.name, (b) => ({ ...b, rotate: [...(b.rotate ?? []), { axis: 'x', joint: jointList[0].name }] }))}>{tr('addTurn', '+ Turn')}</button>
            <div style={ST.help}>{tr('turnHelp', 'Each turn: joint × mul ÷ div + add (whole numbers, as C computes it). x swings a hanging limb forward, y turns +z towards +x, z turns +x towards +y.')}</div>
          </Section>
          <Section title={tr('socketsOn', 'Sockets on this bone')}>
            {(raw!.sockets ?? []).map((s, i) => s.bone !== selShared.name ? null : (
              <div key={i}>
                <Row label={s.name}><button style={ST.btnSmall} onClick={() => set({ ...raw!, sockets: raw!.sockets!.filter((_, j) => j !== i) })}>✕</button></Row>
                {(['from', 'to'] as const).map((f) => (
                  <Row key={f} label={f}>{[0, 1, 2].map((k) => <NumIn key={k} value={s[f][k]} width={50} onCommit={(n) => set({ ...raw!, sockets: raw!.sockets!.map((x, j) => { if (j !== i) return x; const v = [...x[f]] as A.Vec3; v[k] = Math.round(n); return { ...x, [f]: v }; }) })} />)}</Row>
                ))}
              </div>
            ))}
            <button style={ST.btnSmall} onClick={() => { const n = ask(tr('newSocketQ', 'Name of the socket'), A.freshName('socket', (raw!.sockets ?? []).map((s) => s.name))); if (n) set({ ...raw!, sockets: [...(raw!.sockets ?? []), { name: n, bone: selShared.name, from: [0, 0, 0], to: [0, -500, 0] }] }); }}>{tr('addSocket', '+ Socket')}</button>
          </Section>
        </>
      ))}
      {tab === 'joints' && (
        <>
          {selJoint && raw && (() => {
            const j = raw.joints.find((x) => x.name === selJoint);
            if (!j) return null;
            const setJ = (f: (x: A.JointRaw) => A.JointRaw) => set({ ...raw, joints: raw.joints.map((x) => (x.name === selJoint ? f(x) : x)) });
            return (
              <Section title={tr('jointN', 'Joint "{{n}}"', { n: selJoint })}>
                {(['min', 'max'] as const).map((f) => (
                  <Row key={f} label={f === 'min' ? tr('min', 'Lowest') : tr('max', 'Highest')} tip={tr('limitTip', 'Optional: the slider\'s range, in the file\'s units')}>
                    <OptNumIn value={typeof j[f] === 'number' ? j[f] as number : null} width={70} onCommit={(n) => setJ((x) => { const y = { ...x }; if (n === undefined) delete y[f]; else y[f] = Math.round(n); return y; })} />
                  </Row>
                ))}
                <div style={ST.note}>{tr('turnsBones', 'Turns: {{u}}', { u: A.jointUsers(raw, selJoint).join(', ') || tr('nothing', 'nothing') })}</div>
              </Section>
            );
          })()}
          <Section title={tr('tryJoints', 'Try the joints (not saved)')}>
            {jointList.map((j) => (
              <div key={j.name}>
                <div style={ST.row}><span style={ST.label}>{j.name}</span><span style={ST.dim}>{Math.round(A.toDeg(test[j.name] ?? 0, unit))}°</span></div>
                <input type="range" min={typeof j.min === 'number' ? j.min : -unit / 2} max={typeof j.max === 'number' ? j.max : unit / 2} value={test[j.name] ?? 0} style={{ width: '100%' }}
                  onChange={(e) => setTest({ ...test, [j.name]: Number(e.target.value) })} />
              </div>
            ))}
            <button style={ST.btnSmall} onClick={() => setTest({})}>{tr('resetTry', 'All at 0')}</button>
          </Section>
        </>
      )}
      {tab === 'variants' && (!vr || !selVariant ? <div style={ST.dim}>{tr('noVariant', 'Select a variant, or add one.')}</div> : (
        <>
          <Section title={tr('variantN', 'Variant "{{n}}"', { n: selVariant })}>
            <Row label={tr('scale', 'Scale')} tip={tr('scaleTip', 'Q8: 256 = as modelled. Scales the offsets, the meshes and the sockets.')}>
              <NumIn value={vr.scale ?? 256} width={60} onCommit={(n) => set({ ...raw!, variants: { ...raw!.variants, [selVariant]: { ...vr, scale: Math.max(1, Math.round(n)) } } })} />
              <span style={ST.dim}>{(((vr.scale ?? 256) / 256) * 100).toFixed(0)}%</span>
            </Row>
            {(vr.bones?.length || (vr.rotate && Object.keys(vr.rotate).length) || vr.sockets?.length) ? (
              <div style={ST.note}>{tr('variantText', 'Also, edited as text: {{w}}', { w: [vr.bones?.length ? tr('extraBones', '{{n}} extra bones', { n: vr.bones.length }) : '', vr.rotate && Object.keys(vr.rotate).length ? tr('ownTurns', 'its own turns for {{b}}', { b: Object.keys(vr.rotate).join(', ') }) : '', vr.sockets?.length ? tr('ownSockets', 'its own sockets') : ''].filter(Boolean).join('; ') })}</div>
            ) : null}
          </Section>
          <Section title={tr('perBone', 'Per bone')}>
            {bones.map((b) => {
              const has = vr.meshes && b.name in vr.meshes;
              const off = vr.offsets?.[b.name];
              const setV = (nv: A.VariantRaw) => set({ ...raw!, variants: { ...raw!.variants, [selVariant]: nv } });
              return (
                <div key={b.name} style={{ borderBottom: '1px solid #20203a', padding: '2px 0' }}>
                  <div style={ST.row}>
                    <span style={ST.label}>{b.name}</span>
                    {meshSelect(has ? vr.meshes![b.name] : (undefined as unknown as string | null), (m) => {
                      const meshes = { ...(vr.meshes ?? {}) };
                      if ((m as unknown) === '\u0001') delete meshes[b.name]; else meshes[b.name] = m;
                      setV({ ...vr, meshes });
                    }, b.mesh ?? '')}
                  </div>
                  <div style={ST.row}>
                    <label style={ST.check}><input type="checkbox" checked={!!off} onChange={(e) => { const offsets = { ...(vr.offsets ?? {}) }; if (e.target.checked) offsets[b.name] = [...b.offset] as A.Vec3; else delete offsets[b.name]; setV({ ...vr, offsets }); }} />{tr('ownOffset', 'own offset')}</label>
                    {off && [0, 1, 2].map((k) => <NumIn key={k} value={off[k]} width={46} onCommit={(n) => { const o = [...off] as A.Vec3; o[k] = Math.round(n); setV({ ...vr, offsets: { ...vr.offsets, [b.name]: o } }); }} />)}
                  </div>
                </div>
              );
            })}
          </Section>
        </>
      ))}
    </div>
  );

  return (
    <div style={ST.root} tabIndex={0} onKeyDown={keysFor(p.undo, p.redo)}>
      <Toolbar {...p} tabs={[['bones', tr('tabBones', 'Bones')], ['joints', tr('tabJoints', 'Joints')], ['variants', tr('tabVariants', 'Variants')]]} tab={tab} setTab={(x) => setTab(x as SkelTab)} />
      <div style={ST.body}>
        {left}
        <Viewport3D viewLabels={{ '3D': tr('view3d', '3D'), Front: tr('viewFront', 'Front'), Side: tr('viewSide', 'Side'), Top: tr('viewTop', 'Top') }} resolved={resolved} posed={posed} meshes={p.meshData} options={p.opts} selBone={p.selBone} onPickBone={p.setSelBone}
          overlay={!raw ? (<>{tr('notJsonSkel', 'This document is not a .vskel JSON object.')} <button style={ST.btn} onClick={() => commit(A.newVskel() as unknown as Record<string, unknown>)}>{tr('startNewSkel', 'Start a new skeleton (replaces the text)')}</button></>)
            : !resolved ? tr('fixFirst', 'Fix the problems listed on the left to see it.') : undefined}
          status={<>
            <span>{p.variant ?? tr('asModelled', '(as modelled)')}</span>
            {resolved && <span>{tr('bonesN', '{{n}} bones', { n: resolved.bones.length })}</span>}
            {sel && <span>{sel}</span>}
          </>} />
        {right}
      </div>
    </div>
  );
};

// ── small inputs and pieces ──────────────────────────────────────────────────
const NumIn: React.FC<{ value: number; onCommit: (n: number) => void; width?: number; step?: number; title?: string }> = ({ value, onCommit, width, step, title }) => (
  <input type="number" key={`${value}`} defaultValue={Number.isFinite(value) ? value : 0} step={step ?? 1} title={title}
    style={{ ...ST.input, width: width ?? 60 }} onWheel={(e) => e.currentTarget.blur()} onClick={(e) => e.stopPropagation()}
    onBlur={(e) => { const n = Number(e.currentTarget.value); if (e.currentTarget.value.trim() === '' || !Number.isFinite(n)) { e.currentTarget.value = String(value); return; } if (n !== value) onCommit(n); }}
    onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') { e.currentTarget.value = String(value); e.currentTarget.blur(); } }} />
);
const OptNumIn: React.FC<{ value: number | null; onCommit: (n: number | undefined) => void; width?: number; placeholder?: string }> = ({ value, onCommit, width, placeholder }) => (
  <input type="number" key={`${value}`} defaultValue={value ?? ''} placeholder={placeholder} style={{ ...ST.input, width: width ?? 60 }}
    onWheel={(e) => e.currentTarget.blur()}
    onBlur={(e) => { const s = e.currentTarget.value.trim(); if (s === '') { if (value !== null) onCommit(undefined); return; } const n = Number(s); if (!Number.isFinite(n)) { e.currentTarget.value = value === null ? '' : String(value); return; } if (n !== value) onCommit(n); }}
    onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur(); }} />
);
const TextIn: React.FC<{ value: string; onCommit: (s: string) => void; width?: number }> = ({ value, onCommit, width }) => (
  <input key={value} defaultValue={value} style={{ ...ST.input, width: width ?? 120 }}
    onBlur={(e) => { const s = e.currentTarget.value.trim(); if (s !== value) onCommit(s); }}
    onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') { e.currentTarget.value = value; e.currentTarget.blur(); } }} />
);
const Section: React.FC<{ title: string; children?: React.ReactNode }> = ({ title, children }) => (
  <div style={ST.section}><div style={ST.sectionTitle}>{title}</div>{children}</div>
);
const Row: React.FC<{ label: string; tip?: string; children?: React.ReactNode }> = ({ label, tip, children }) => (
  <div style={ST.row} title={tip}><span style={ST.label}>{label}</span><span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>{children}</span></div>
);

const btnBase: React.CSSProperties = { background: '#2c2c44', color: '#ccd', border: '1px solid #3d3d5c', borderRadius: 3, padding: '3px 8px', fontSize: 12, cursor: 'pointer' };
const ST: Record<string, React.CSSProperties> = {
  root: { display: 'flex', flexDirection: 'column', height: '100%', width: '100%', background: '#12121c', color: '#ccd', fontSize: 12, outline: 'none' },
  toolbar: { display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 4, padding: '4px 6px', borderBottom: '1px solid #2a2a3e', background: '#181826' },
  timelineBar: { display: 'flex', alignItems: 'center', gap: 6, padding: '4px 6px', borderTop: '1px solid #2a2a3e', background: '#181826' },
  track: { position: 'relative', flex: 1, height: 42, background: '#0f0f18', border: '1px solid #2a2a3e', borderRadius: 3, cursor: 'pointer', overflow: 'hidden' },
  sep: { width: 1, height: 18, background: '#33334d', margin: '0 4px' },
  btn: btnBase,
  btnOn: { ...btnBase, background: '#4a4a8e', color: '#fff', border: '1px solid #7a7abf' },
  btnSmall: { ...btnBase, padding: '1px 6px', fontSize: 11 },
  btnOnSmall: { ...btnBase, padding: '1px 6px', fontSize: 11, background: '#4a4a8e', color: '#fff' },
  check: { display: 'flex', alignItems: 'center', gap: 3, color: '#aab', cursor: 'pointer' },
  body: { flex: 1, display: 'flex', minHeight: 0 },
  panel: { width: 290, flexShrink: 0, overflowY: 'auto', borderLeft: '1px solid #2a2a3e', background: '#151522', padding: 6 },
  panelLeft: { width: 210, flexShrink: 0, overflowY: 'auto', borderRight: '1px solid #2a2a3e', background: '#151522', padding: 6 },
  section: { marginBottom: 10, paddingBottom: 6, borderBottom: '1px solid #24243a' },
  sectionTitle: { fontWeight: 600, color: '#dde', marginBottom: 4 },
  subTitle: { color: '#aab', marginTop: 6 },
  row: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 4, margin: '3px 0', cursor: 'default' },
  label: { color: '#99a' },
  input: { background: '#0f0f18', color: '#dde', border: '1px solid #3d3d5c', borderRadius: 3, padding: '2px 4px', fontSize: 12 },
  dim: { color: '#889' },
  note: { color: '#b9a', fontSize: 11, margin: '4px 0' },
  btnGrid: { display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 6 },
  list: { maxHeight: 160, overflowY: 'auto', fontFamily: 'monospace', fontSize: 11 },
  listTall: { maxHeight: 420, overflowY: 'auto', fontFamily: 'monospace', fontSize: 11.5 },
  listItem: { padding: '1px 3px', cursor: 'pointer', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' },
  listOn: { background: '#3a3a6e', color: '#fff' },
  help: { color: '#667', fontSize: 10.5, lineHeight: 1.4, marginTop: 6 },
};

export default Anim3DEditor;
