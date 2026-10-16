/**
 * InputDialog - Simple input dialog for requesting text from user
 */

import React, { useState, useEffect, useRef } from 'react';

interface InputDialogProps {
  isOpen: boolean;
  title: string;
  message?: string;
  placeholder?: string;
  defaultValue?: string;
  validateFn?: (value: string) => string | null; // Returns error message or null if valid
  onCancel: () => void;
  onConfirm: (value: string) => void;
}

export const InputDialog: React.FC<InputDialogProps> = ({
  isOpen,
  title,
  message,
  placeholder,
  defaultValue = '',
  validateFn,
  onCancel,
  onConfirm,
}) => {
  const [value, setValue] = useState(defaultValue);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setValue(defaultValue);
      setError(null);
      // Focus input after dialog opens
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen, defaultValue]);

  // Opened from the macOS menu bar, the page may not have the keyboard yet when the
  // timeout above runs: take the input's focus back as soon as the window gets it.
  useEffect(() => {
    if (!isOpen) return;
    const refocus = () => {
      if (document.activeElement !== inputRef.current) inputRef.current?.focus();
    };
    window.addEventListener('focus', refocus);
    return () => window.removeEventListener('focus', refocus);
  }, [isOpen]);

  const handleConfirm = () => {
    if (validateFn) {
      const validationError = validateFn(value);
      if (validationError) {
        setError(validationError);
        return;
      }
    }
    onConfirm(value);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onCancel();
    } else if (e.key === 'Enter') {
      handleConfirm();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="input-dialog-overlay" onClick={onCancel} onKeyDown={handleKeyDown}>
      <div className="input-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="input-dialog-header">
          <h3>{title}</h3>
        </div>
        
        {message && <p className="input-dialog-message">{message}</p>}
        
        <div className="input-dialog-body">
          <input
            ref={inputRef}
            type="text"
            value={value}
            onChange={(e) => {
              setValue(e.target.value);
              setError(null);
            }}
            placeholder={placeholder}
            className={error ? 'error' : ''}
          />
          {error && <div className="input-dialog-error">{error}</div>}
        </div>

        <div className="input-dialog-footer">
          <button className="btn-secondary" onClick={onCancel}>Cancel</button>
          <button className="btn-primary" onClick={handleConfirm}>OK</button>
        </div>
      </div>
      
      <style>{`
        .input-dialog-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 10000;
        }
        
        .input-dialog {
          background: #252526;
          border: 1px solid #3c3c3c;
          border-radius: 6px;
          min-width: 350px;
          max-width: 450px;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
        }
        
        .input-dialog-header {
          padding: 16px 20px 8px;
          border-bottom: 1px solid #3c3c3c;
        }
        
        .input-dialog-header h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 500;
          color: #cccccc;
        }
        
        .input-dialog-message {
          margin: 0;
          padding: 12px 20px;
          font-size: 13px;
          color: #999999;
        }
        
        .input-dialog-body {
          padding: 12px 20px;
        }
        
        .input-dialog-body input {
          width: 100%;
          padding: 8px 12px;
          background: #3c3c3c;
          border: 1px solid #555555;
          border-radius: 4px;
          color: #cccccc;
          font-size: 13px;
          outline: none;
          box-sizing: border-box;
        }
        
        .input-dialog-body input:focus {
          border-color: #0078d4;
        }
        
        .input-dialog-body input.error {
          border-color: #f14c4c;
        }
        
        .input-dialog-error {
          color: #f14c4c;
          font-size: 12px;
          margin-top: 6px;
        }
        
        .input-dialog-footer {
          display: flex;
          justify-content: flex-end;
          gap: 8px;
          padding: 12px 20px;
          border-top: 1px solid #3c3c3c;
        }
        
        .input-dialog-footer button {
          padding: 6px 16px;
          border: none;
          border-radius: 4px;
          font-size: 13px;
          cursor: pointer;
        }
        
        .input-dialog-footer .btn-primary {
          background: #0078d4;
          color: white;
        }
        
        .input-dialog-footer .btn-primary:hover {
          background: #1084d8;
        }
        
        .input-dialog-footer .btn-secondary {
          background: #3c3c3c;
          color: #cccccc;
        }
        
        .input-dialog-footer .btn-secondary:hover {
          background: #4c4c4c;
        }
      `}</style>
    </div>
  );
};

export default InputDialog;
