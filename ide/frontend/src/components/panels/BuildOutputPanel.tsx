import React, { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';

interface Line { id: number; text: string; kind: 'info' | 'warn' | 'error' | 'stdout' | 'stderr' | 'diagnostic' | 'success' | 'phase' | 'critical'; }

export const BuildOutputPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const [lines, setLines] = useState<Line[]>([]);
  const nextId = useRef(1);
  const scrollerRef = useRef<HTMLDivElement|null>(null);
  const autoScrollRef = useRef(true);

  const append = (text: string, kind: Line['kind']) => {
    setLines(l => [...l, { id: nextId.current++, text, kind }]);
  };

  const smartAppend = (text: string) => {
    // Smart classification based on content
    const lower = text.toLowerCase();
    let kind: Line['kind'] = 'stdout';
    
    if (text.startsWith('=== ') || text.startsWith('Phase ')) kind = 'phase';
    else if (text.includes('✓') || text.includes('SUCCESS')) kind = 'success';
    else if (text.includes('❌') || text.includes('FAILED') || text.includes('ERROR')) kind = 'error';
    else if (text.includes('CRITICAL')) kind = 'critical';
    else if (lower.includes('warning') || lower.includes('warn')) kind = 'warn';
    else if (lower.includes('error') || lower.includes('failed') || lower.includes('fallo')) kind = 'error';
    
    append(text, kind);
  };

  useEffect(() => {
    const w:any = window as any;
    w?.electronAPI?.onRunStdout?.((chunk: string) => {
      chunk.split(/\r?\n/).filter(Boolean).forEach(l => smartAppend(l));
    });
    w?.electronAPI?.onRunStderr?.((chunk: string) => {
      chunk.split(/\r?\n/).filter(Boolean).forEach(l => smartAppend(l));
    });
    w?.electronAPI?.onRunDiagnostics?.((diags: Array<{file:string; line:number; col:number; message:string}>) => {
      diags.forEach(d => append(`${d.file}:${d.line+1}:${d.col+1}: ${d.message}`, 'diagnostic'));
    });
    w?.electronAPI?.onRunStatus?.((msg: string) => append(msg, 'info'));
  }, []);

  useEffect(() => {
    if (!autoScrollRef.current) return;
    const el = scrollerRef.current; if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [lines]);

  const clear = () => setLines([]);

  return (
    <div style={{display:'flex', flexDirection:'column', height:'100%', fontSize:12, fontFamily:'monospace'}}>
      <div style={{padding:'4px 8px', borderBottom:'1px solid #333', display:'flex', gap:12, alignItems:'center'}}>
        <strong>{t('panel.buildOutput', 'Build Output')}</strong>
        <button onClick={clear} style={btn}>{t('action.clear', 'Clear')}</button>
        <label style={{display:'flex', alignItems:'center', gap:4}}>
          <input type='checkbox' defaultChecked onChange={e=>{autoScrollRef.current=e.target.checked;}} /> {t('status.autoScroll', 'Auto-scroll')}
        </label>
        <span style={{marginLeft:'auto', opacity:0.6, fontSize:10}}>
          {lines.length} lines | 
          <span style={{color:'#66ff66'}}> ✓{lines.filter(l => l.kind === 'success').length}</span> |
          <span style={{color:'#ff6666'}}> ❌{lines.filter(l => l.kind === 'error' || l.kind === 'critical').length}</span> |
          <span style={{color:'#ffcc33'}}> ⚠{lines.filter(l => l.kind === 'warn').length}</span>
        </span>
      </div>
      <div ref={scrollerRef} className="build-output-scroll" style={{flex:1, overflow:'auto', padding:8, background:'#111'}}>
        {lines.map(l => (
          <div key={l.id} style={{whiteSpace:'pre', color: colorFor(l.kind)}}>{l.text}</div>
        ))}
        {lines.length===0 && <div style={{opacity:0.5}}>{t('message.noBuildOutput', 'No build output yet. Press Run.')}</div>}
      </div>
    </div>
  );
};

const btn: React.CSSProperties = { background:'#1e1e1e', color:'#ddd', border:'1px solid #333', padding:'2px 6px', cursor:'pointer', fontSize:11 };
function colorFor(kind: Line['kind']): string {
  switch(kind){
    case 'error': return '#ff6666';
    case 'critical': return '#ff4444';
    case 'warn': return '#ffcc33';
    case 'success': return '#66ff66';
    case 'phase': return '#4499ff';
    case 'stderr': return '#ff8888';
    case 'stdout': return '#88ccff';
    case 'diagnostic': return '#ffaaff';
    default: return '#cccccc';
  }
}
