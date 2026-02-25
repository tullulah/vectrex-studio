import React, { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useEditorStore } from '../../state/editorStore';

// Simple severity badge styling
const sevColor: Record<string,string> = { error: '#F14C4C', warning: '#CCA700', info: '#3794FF' };

export const ErrorsPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  // Access raw documents once; derive diagnostics locally to keep selector stable
  const documents = useEditorStore(s => s.documents); // retained if we need deeper info later
  const allDiagnostics = useEditorStore(s => s.allDiagnostics);
  const goto = useEditorStore(s => s.gotoLocation);

  // Prefer deterministic derivation here to avoid recreating array each store emit that is unrelated
  const diagnostics = useMemo(() => allDiagnostics, [allDiagnostics]);

  return (
    <div style={{fontSize:12, height:'100%', display:'flex', flexDirection:'column'}}>
      <div style={{padding:'4px 8px', borderBottom:'1px solid #333', display:'flex', gap:12}}>
        <span><strong>{t('label.errors', 'Errors')}:</strong> {diagnostics.filter(d=>d.severity==='error').length}</span>
        <span><strong>{t('label.warnings', 'Warnings')}:</strong> {diagnostics.filter(d=>d.severity==='warning').length}</span>
        <span><strong>{t('label.info', 'Info')}:</strong> {diagnostics.filter(d=>d.severity==='info').length}</span>
        <button onClick={() => {
          console.log('[ErrorsPanel] DEBUG - documents:', documents);
          console.log('[ErrorsPanel] DEBUG - allDiagnostics:', allDiagnostics);
          console.log('[ErrorsPanel] DEBUG - diagnostics:', diagnostics);
        }} style={{marginLeft: 'auto', padding: '2px 6px', fontSize: '10px'}}>
          Debug
        </button>
      </div>
      <div style={{overflow:'auto', flex:1}}>
        <table style={{width:'100%', borderCollapse:'collapse'}}>
          <thead>
            <tr style={{textAlign:'left', background:'#222'}}>
              <th style={{padding:'4px 6px'}}>{t('label.severity', 'Severity')}</th>
              <th style={{padding:'4px 6px'}}>{t('label.file', 'File')}</th>
              <th style={{padding:'4px 6px'}}>{t('label.line', 'Line')}</th>
              <th style={{padding:'4px 6px'}}>{t('label.message', 'Message')}</th>
            </tr>
          </thead>
          <tbody>
            {diagnostics.map((d, i) => (
              <tr key={i}
                onDoubleClick={() => goto(d.uri, d.line, d.column)}
                style={{cursor:'pointer', background: i%2? '#1e1e1e':'#252526'}}
                title={t('message.doubleClickNav', 'Double click to navigate')}>
                <td style={{padding:'2px 6px'}}>
                  <span style={{background: sevColor[d.severity]||'#444', color:'#fff', padding:'1px 4px', borderRadius:3, fontSize:10}}>{d.severity}</span>
                </td>
                <td style={{padding:'2px 6px'}}>{d.file}</td>
                <td style={{padding:'2px 6px'}}>{d.line+1}:{d.column+1}</td>
                <td style={{padding:'2px 6px', whiteSpace:'pre-wrap'}}>{d.message}</td>
              </tr>
            ))}
            {diagnostics.length === 0 && (
              <tr><td colSpan={4} style={{padding:8, color:'#666'}}>{t('message.noDiagnostics', 'No diagnostics')}</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
