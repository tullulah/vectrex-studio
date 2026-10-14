import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { emuCore } from '../../emulatorCoreSingleton';

export const DebugPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const [debugMessages, setDebugMessages] = useState<string[]>([]);
  const [debugVariables, setDebugVariables] = useState<Record<string, number>>({});
  const [debugStrings, setDebugStrings] = useState<Record<string, string>>({});
  const [lastOutput, setLastOutput] = useState<string>('');

  // Poll for debug messages, variables and strings every 100ms
  useEffect(() => {
    const interval = setInterval(() => {
      // Use global window debug functions (installed in index.html)
      if ((window as any).getDebugMessages) {
        const messages = (window as any).getDebugMessages();
        if (messages.length !== debugMessages.length) {
          setDebugMessages([...messages]);
        }
      }
      
      // Poll tracked variables
      if ((window as any).getDebugVariables) {
        const vars = (window as any).getDebugVariables();
        setDebugVariables({...vars});
      }
      
      // Poll tracked strings
      if ((window as any).getDebugStrings) {
        const strs = (window as any).getDebugStrings();
        setDebugStrings({...strs});
      }
      
      // Keep emuCore fallback for compatibility
      if (emuCore.getLastDebugOutput) {
        const current = emuCore.getLastDebugOutput();
        if (current !== lastOutput) {
          setLastOutput(current);
        }
      }
    }, 100);

    return () => clearInterval(interval);
  }, [debugMessages.length, lastOutput]);

  const clearMessages = () => {
    // Use global window function (installed in index.html)
    if ((window as any).clearDebugMessages) {
      (window as any).clearDebugMessages();
    }
    // Keep emuCore fallback for compatibility
    if (emuCore.clearDebugMessages) {
      emuCore.clearDebugMessages();
    }
    setDebugMessages([]);
    setDebugVariables({});
    setDebugStrings({});
    setLastOutput('');
  };

  // Count of tracked variables and strings
  const varCount = Object.keys(debugVariables).length;
  const strCount = Object.keys(debugStrings).length;

  return (
    <div style={{ padding: 8 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <strong>{t('panel.debug')}</strong>
        <button 
          onClick={clearMessages}
          style={{ 
            padding: '4px 8px', 
            fontSize: '12px',
            backgroundColor: '#444',
            color: 'white',
            border: '1px solid #666',
            borderRadius: '3px',
            cursor: 'pointer'
          }}
        >
          Clear
        </button>
      </div>
      
      {lastOutput && (
        <div style={{ 
          marginBottom: 8, 
          padding: 6, 
          backgroundColor: '#2a2a2a', 
          border: '1px solid #555',
          borderRadius: 3,
          fontFamily: 'monospace',
          fontSize: '13px',
          color: '#90EE90'
        }}>
          <strong>Last:</strong> {lastOutput}
        </div>
      )}
      
      {/* Tracked Variables Section */}
      {varCount > 0 && (
        <>
          <div style={{ 
            fontSize: '11px', 
            color: '#888', 
            marginBottom: 4,
            fontWeight: 'bold'
          }}>
            Variables ({varCount}):
          </div>
          <div style={{ 
            maxHeight: '400px', 
            overflowY: 'auto',
            border: '1px solid #555',
            backgroundColor: '#1a1a1a',
            borderRadius: 3,
            marginBottom: 8
          }}>
            {Object.entries(debugVariables).map(([name, value]) => (
              <div 
                key={name}
                style={{
                  padding: '6px 12px',
                  borderBottom: '1px solid #333',
                  fontFamily: 'monospace',
                  fontSize: '13px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}
              >
                <span style={{ color: '#9CDCFE', fontWeight: 'bold' }}>{name}</span>
                <span style={{ 
                  color: '#B5CEA8', 
                  fontWeight: 'bold',
                  backgroundColor: '#2a2a2a',
                  padding: '2px 8px',
                  borderRadius: 3,
                  minWidth: '40px',
                  textAlign: 'right'
                }}>{value}</span>
              </div>
            ))}
          </div>
        </>
      )}
      
      {/* Tracked Strings Section */}
      {strCount > 0 && (
        <>
          <div style={{ 
            fontSize: '11px', 
            color: '#888', 
            marginBottom: 4,
            fontWeight: 'bold'
          }}>
            Strings ({strCount}):
          </div>
          <div style={{ 
            maxHeight: '300px', 
            overflowY: 'auto',
            border: '1px solid #555',
            backgroundColor: '#1a1a1a',
            borderRadius: 3,
            marginBottom: 8
          }}>
            {Object.entries(debugStrings).map(([name, value]) => (
              <div 
                key={name}
                style={{
                  padding: '6px 12px',
                  borderBottom: '1px solid #333',
                  fontFamily: 'monospace',
                  fontSize: '13px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}
              >
                <span style={{ color: '#9CDCFE', fontWeight: 'bold' }}>{name}</span>
                <span style={{ 
                  color: '#CE9178', 
                  fontWeight: 'normal',
                  backgroundColor: '#2a2a2a',
                  padding: '2px 8px',
                  borderRadius: 3,
                  fontStyle: 'italic'
                }}>"{value}"</span>
              </div>
            ))}
          </div>
        </>
      )}
      
      {/* Simple Messages (non-variable DEBUG_PRINT calls) */}
      {debugMessages.length > 0 && (
        <>
          <div style={{ 
            fontSize: '11px', 
            color: '#888', 
            marginBottom: 4,
            fontWeight: 'bold'
          }}>
            Messages ({debugMessages.length}):
          </div>
          <div style={{ 
            maxHeight: '200px', 
            overflowY: 'auto',
            border: '1px solid #555',
            backgroundColor: '#1a1a1a',
            borderRadius: 3
          }}>
            {debugMessages.map((message, index) => (
              <div 
                key={index} 
                style={{ 
                  padding: '4px 8px',
                  borderBottom: index < debugMessages.length - 1 ? '1px solid #333' : 'none',
                  fontFamily: 'monospace',
                  fontSize: '12px',
                  color: '#E0E0E0'
                }}
              >
                <span style={{ color: '#666', marginRight: 8 }}>
                  [{String(index + 1).padStart(3, '0')}]
                </span>
                {message}
              </div>
            ))}
          </div>
        </>
      )}
      
      {varCount === 0 && strCount === 0 && debugMessages.length === 0 && (
        <div style={{ 
          padding: 16, 
          color: '#888', 
          fontStyle: 'italic',
          textAlign: 'center',
          border: '1px solid #555',
          backgroundColor: '#1a1a1a',
          borderRadius: 3
        }}>
          No debug output yet.<br/>
          Use DEBUG_PRINT(var) or DEBUG_PRINT_STR(str) in your VPy code.
        </div>
      )}
      
      <div style={{ 
        marginTop: 8, 
        fontSize: '11px', 
        color: '#666',
        fontStyle: 'italic'
      }}>
        Debug output from VPy DEBUG_PRINT functions. Variables update in real-time.
      </div>
    </div>
  );
};
