import React, { useEffect, useState } from 'react';
import { useJoystickStore } from '../../state/joystickStore';

export const JoystickConfigDialog: React.FC = () => {
  const {
    isConfigOpen,
    setConfigOpen,
    connectedGamepads,
    gamepadIndex2, gamepadName2, selectGamepad2,
    updateGamepads,
    gamepadIndex,
    gamepadName,
    selectGamepad,
    axisXIndex,
    axisYIndex,
    axisXInverted,
    axisYInverted,
    deadzone,
    dpadUpButton,
    dpadDownButton,
    dpadLeftButton,
    dpadRightButton,
    buttonMappings,
    setAxisXIndex,
    setAxisYIndex,
    setAxisXInverted,
    setAxisYInverted,
    setDeadzone,
    setDpadUpButton,
    setDpadDownButton,
    setDpadLeftButton,
    setDpadRightButton,
    setButtonMapping,
    resetConfig,
  } = useJoystickStore();

  const [listeningForButton, setListeningForButton] = useState<string | null>(null); // Changed to string to support 'dpad_up', 'button_1', etc.
  const [currentAxisValues, setCurrentAxisValues] = useState<number[]>([]);
  const [pressedButtons, setPressedButtons] = useState<boolean[]>([]);

  // Poll gamepads
  useEffect(() => {
    if (!isConfigOpen) return;

    const interval = setInterval(() => {
      const gamepads = navigator.getGamepads();
      const connected = Array.from(gamepads).filter((g): g is Gamepad => g !== null);
      updateGamepads(connected);

      // Update axis values and button states for visualization
      if (gamepadIndex !== null && connected[gamepadIndex]) {
        const gp = connected[gamepadIndex];
        setCurrentAxisValues(Array.from(gp.axes));
        setPressedButtons(gp.buttons.map(b => b.pressed));
      }
    }, 100);

    return () => clearInterval(interval);
  }, [isConfigOpen, gamepadIndex, updateGamepads]);

  // Listen for button presses when mapping
  useEffect(() => {
    if (listeningForButton === null || !isConfigOpen) return;

    const interval = setInterval(() => {
      const gamepads = navigator.getGamepads();
      if (gamepadIndex !== null && gamepads[gamepadIndex]) {
        const gamepad = gamepads[gamepadIndex];
        const pressedButton = gamepad.buttons.findIndex(b => b.pressed);
        if (pressedButton !== -1) {
          // Handle different button types
          if (listeningForButton === 'dpad_up') {
            setDpadUpButton(pressedButton);
          } else if (listeningForButton === 'dpad_down') {
            setDpadDownButton(pressedButton);
          } else if (listeningForButton === 'dpad_left') {
            setDpadLeftButton(pressedButton);
          } else if (listeningForButton === 'dpad_right') {
            setDpadRightButton(pressedButton);
          } else if (listeningForButton.startsWith('button_')) {
            const vectrexBtn = parseInt(listeningForButton.split('_')[1]);
            setButtonMapping(vectrexBtn, pressedButton);
          }
          setListeningForButton(null);
        }
      }
    }, 50);

    return () => clearInterval(interval);
  }, [listeningForButton, gamepadIndex, isConfigOpen, setDpadUpButton, setDpadDownButton, setDpadLeftButton, setDpadRightButton, setButtonMapping]);

  if (!isConfigOpen) return null;

  const vectrexButtonNames = ['Button 1', 'Button 2', 'Button 3', 'Button 4'];

  const getButtonName = (index: number) => {
    // Common gamepad button names
    const names: Record<number, string> = {
      0: 'A / Cross',
      1: 'B / Circle',
      2: 'X / Square',
      3: 'Y / Triangle',
      4: 'LB / L1',
      5: 'RB / R1',
      6: 'LT / L2',
      7: 'RT / R2',
      8: 'Select / Share',
      9: 'Start / Options',
      10: 'L3 (Left Stick)',
      11: 'R3 (Right Stick)',
      12: 'D-Pad Up',
      13: 'D-Pad Down',
      14: 'D-Pad Left',
      15: 'D-Pad Right',
    };
    return names[index] || `Button ${index}`;
  };

  const applyDeadzone = (value: number, dz: number) => {
    return Math.abs(value) < dz ? 0 : value;
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(0,0,0,0.7)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 10000,
    }}>
      <div style={{
        background: '#1e1e1e',
        border: '1px solid #3c3c3c',
        borderRadius: 8,
        width: '90%',
        maxWidth: 700,
        maxHeight: '90vh',
        overflow: 'auto',
        padding: 20,
        color: '#cccccc',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <h2 style={{ margin: 0 }}>🎮 Joystick Configuration</h2>
          <button
            onClick={() => setConfigOpen(false)}
            style={{
              background: 'transparent',
              border: 'none',
              color: '#cccccc',
              fontSize: 24,
              cursor: 'pointer',
              padding: 0,
            }}
          >
            ×
          </button>
        </div>

        {/* Gamepad Selection */}
        <div style={{ marginBottom: 20 }}>
          <h3 style={{ fontSize: 14, marginBottom: 10, color: '#ffffff' }}>Select Gamepad</h3>
          {connectedGamepads.length === 0 ? (
            <p style={{ color: '#ff6b6b', fontSize: 13 }}>
              ⚠️ No gamepads detected. Connect a gamepad and press any button.
            </p>
          ) : (
            <select
              value={gamepadIndex ?? ''}
              onChange={(e) => {
                const idx = parseInt(e.target.value);
                const gp = connectedGamepads[idx];
                if (gp) selectGamepad(idx, gp.id);
              }}
              style={{
                width: '100%',
                padding: 8,
                background: '#252526',
                border: '1px solid #3c3c3c',
                color: '#cccccc',
                borderRadius: 4,
              }}
            >
              <option value="">-- Select Gamepad --</option>
              {connectedGamepads.map((gp, idx) => (
                <option key={idx} value={idx}>
                  {gp.id} (Index {idx})
                </option>
              ))}
            </select>
          )}
          {gamepadName && (
            <p style={{ fontSize: 12, color: '#888', marginTop: 5 }}>
              Selected: {gamepadName}
            </p>
          )}
        </div>

        {/* Player 2 — second gamepad (optional, for J2_* builtins). Reuses
            the axis / button mappings configured above (same controller
            model assumed). Select "None" to disable J2 reads. */}
        <div style={{ marginBottom: 20 }}>
          <h3 style={{ fontSize: 14, marginBottom: 10, color: '#ffffff' }}>Select Player 2 Gamepad (optional)</h3>
          {connectedGamepads.length < 2 ? (
            <p style={{ color: '#888', fontSize: 12 }}>
              Connect a second gamepad to enable J2_* reads.
            </p>
          ) : (
            <select
              value={gamepadIndex2 ?? ''}
              onChange={(e) => {
                if (e.target.value === '') {
                  selectGamepad2(null, null);
                } else {
                  const idx = parseInt(e.target.value);
                  const gp = connectedGamepads[idx];
                  if (gp) selectGamepad2(idx, gp.id);
                }
              }}
              style={{
                width: '100%',
                padding: 8,
                background: '#252526',
                border: '1px solid #3c3c3c',
                color: '#cccccc',
                borderRadius: 4,
              }}
            >
              <option value="">-- None (J2 disabled) --</option>
              {connectedGamepads.map((gp, idx) => (
                <option key={idx} value={idx} disabled={idx === gamepadIndex}>
                  {gp.id} (Index {idx}){idx === gamepadIndex ? ' — already P1' : ''}
                </option>
              ))}
            </select>
          )}
          {gamepadName2 && (
            <p style={{ fontSize: 12, color: '#888', marginTop: 5 }}>
              Selected: {gamepadName2}
            </p>
          )}
        </div>

        {gamepadIndex !== null && connectedGamepads[gamepadIndex] && (
          <>
            {/* D-Pad Configuration (Digital Input) */}
            <div style={{ marginBottom: 20, padding: 15, background: '#2a2a3e', borderRadius: 6, border: '2px solid #4a4a6e' }}>
              <h3 style={{ fontSize: 14, marginBottom: 10, color: '#ffffff' }}>
                ⬆️ D-Pad (Digital Input for J1_X / J1_Y)
              </h3>
              <p style={{ fontSize: 11, color: '#888', marginBottom: 15 }}>
                Click on D-Pad buttons to map them. Games using J1_X() / J1_Y() will use these.
              </p>
              
              {/* D-Pad Visual */}
              <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 30 }}>
                <div style={{ position: 'relative', width: 120, height: 120 }}>
                  {/* Center circle */}
                  <div style={{
                    position: 'absolute',
                    top: '50%',
                    left: '50%',
                    width: 40,
                    height: 40,
                    transform: 'translate(-50%, -50%)',
                    background: '#1e1e1e',
                    borderRadius: '50%',
                    border: '2px solid #3c3c3c',
                  }} />
                  
                  {/* Up */}
                  <button
                    onClick={() => setListeningForButton('dpad_up')}
                    style={{
                      position: 'absolute',
                      top: 0,
                      left: '50%',
                      transform: 'translateX(-50%)',
                      width: 36,
                      height: 36,
                      background: listeningForButton === 'dpad_up' ? '#4ec94e' : (pressedButtons[dpadUpButton] ? '#ffcc00' : '#252526'),
                      border: listeningForButton === 'dpad_up' ? '3px solid #4ec94e' : '2px solid #3c3c3c',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 16,
                      fontWeight: 'bold',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: pressedButtons[dpadUpButton] ? '0 0 10px #ffcc00' : 'none',
                    }}
                  >
                    ▲
                  </button>
                  
                  {/* Down */}
                  <button
                    onClick={() => setListeningForButton('dpad_down')}
                    style={{
                      position: 'absolute',
                      bottom: 0,
                      left: '50%',
                      transform: 'translateX(-50%)',
                      width: 36,
                      height: 36,
                      background: listeningForButton === 'dpad_down' ? '#4ec94e' : (pressedButtons[dpadDownButton] ? '#ffcc00' : '#252526'),
                      border: listeningForButton === 'dpad_down' ? '3px solid #4ec94e' : '2px solid #3c3c3c',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 16,
                      fontWeight: 'bold',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: pressedButtons[dpadDownButton] ? '0 0 10px #ffcc00' : 'none',
                    }}
                  >
                    ▼
                  </button>
                  
                  {/* Left */}
                  <button
                    onClick={() => setListeningForButton('dpad_left')}
                    style={{
                      position: 'absolute',
                      left: 0,
                      top: '50%',
                      transform: 'translateY(-50%)',
                      width: 36,
                      height: 36,
                      background: listeningForButton === 'dpad_left' ? '#4ec94e' : (pressedButtons[dpadLeftButton] ? '#ffcc00' : '#252526'),
                      border: listeningForButton === 'dpad_left' ? '3px solid #4ec94e' : '2px solid #3c3c3c',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 16,
                      fontWeight: 'bold',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: pressedButtons[dpadLeftButton] ? '0 0 10px #ffcc00' : 'none',
                    }}
                  >
                    ◀
                  </button>
                  
                  {/* Right */}
                  <button
                    onClick={() => setListeningForButton('dpad_right')}
                    style={{
                      position: 'absolute',
                      right: 0,
                      top: '50%',
                      transform: 'translateY(-50%)',
                      width: 36,
                      height: 36,
                      background: listeningForButton === 'dpad_right' ? '#4ec94e' : (pressedButtons[dpadRightButton] ? '#ffcc00' : '#252526'),
                      border: listeningForButton === 'dpad_right' ? '3px solid #4ec94e' : '2px solid #3c3c3c',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 16,
                      fontWeight: 'bold',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: pressedButtons[dpadRightButton] ? '0 0 10px #ffcc00' : 'none',
                    }}
                  >
                    ▶
                  </button>
                </div>
                
                {/* Current mappings */}
                <div style={{ fontSize: 12, fontFamily: 'monospace', color: '#cccccc' }}>
                  <div><strong>Current Mapping:</strong></div>
                  <div style={{ marginTop: 8, lineHeight: '1.8' }}>
                    <div>▲ Up: {getButtonName(dpadUpButton)}</div>
                    <div>▼ Down: {getButtonName(dpadDownButton)}</div>
                    <div>◀ Left: {getButtonName(dpadLeftButton)}</div>
                    <div>▶ Right: {getButtonName(dpadRightButton)}</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Analog Stick Configuration */}
            <div style={{ marginBottom: 20, padding: 15, background: '#252526', borderRadius: 6 }}>
              <h3 style={{ fontSize: 14, marginBottom: 10, color: '#ffffff' }}>
                🎮 Analog Stick (Analog Input for J1_X_ANALOG / J1_Y_ANALOG)
              </h3>
              <p style={{ fontSize: 11, color: '#888', marginBottom: 10 }}>
                Configure analog axes. Games using J1_X_ANALOG() / J1_Y_ANALOG() will use these.
              </p>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 15 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 12, marginBottom: 5 }}>X Axis:</label>
                  <select
                    value={axisXIndex}
                    onChange={(e) => setAxisXIndex(parseInt(e.target.value))}
                    style={{
                      width: '100%',
                      padding: 6,
                      background: '#1e1e1e',
                      border: '1px solid #3c3c3c',
                      color: '#cccccc',
                      borderRadius: 4,
                      fontSize: 12,
                    }}
                  >
                    {connectedGamepads[gamepadIndex].axes.map((_, idx) => (
                      <option key={idx} value={idx}>Axis {idx}</option>
                    ))}
                  </select>
                  <label style={{ display: 'flex', alignItems: 'center', marginTop: 5, fontSize: 12 }}>
                    <input
                      type="checkbox"
                      checked={axisXInverted}
                      onChange={(e) => setAxisXInverted(e.target.checked)}
                      style={{ marginRight: 5 }}
                    />
                    Invert X
                  </label>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: 12, marginBottom: 5 }}>Y Axis:</label>
                  <select
                    value={axisYIndex}
                    onChange={(e) => setAxisYIndex(parseInt(e.target.value))}
                    style={{
                      width: '100%',
                      padding: 6,
                      background: '#1e1e1e',
                      border: '1px solid #3c3c3c',
                      color: '#cccccc',
                      borderRadius: 4,
                      fontSize: 12,
                    }}
                  >
                    {connectedGamepads[gamepadIndex].axes.map((_, idx) => (
                      <option key={idx} value={idx}>Axis {idx}</option>
                    ))}
                  </select>
                  <label style={{ display: 'flex', alignItems: 'center', marginTop: 5, fontSize: 12 }}>
                    <input
                      type="checkbox"
                      checked={axisYInverted}
                      onChange={(e) => setAxisYInverted(e.target.checked)}
                      style={{ marginRight: 5 }}
                    />
                    Invert Y
                  </label>
                </div>
              </div>

              {/* Deadzone */}
              <div style={{ marginTop: 15 }}>
                <label style={{ display: 'block', fontSize: 12, marginBottom: 5 }}>
                  Deadzone: {(deadzone * 100).toFixed(0)}%
                </label>
                <input
                  type="range"
                  min="0"
                  max="0.5"
                  step="0.01"
                  value={deadzone}
                  onChange={(e) => setDeadzone(parseFloat(e.target.value))}
                  style={{ width: '100%' }}
                />
              </div>

              {/* Axis Visualizer - Graphical + Numeric */}
              {currentAxisValues.length > 0 && (
                <div style={{ marginTop: 15, padding: 15, background: '#1e1e1e', borderRadius: 4 }}>
                  <div style={{ fontSize: 12, marginBottom: 10, fontWeight: 'bold' }}>Live Preview</div>
                  <div style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
                    {/* 2D Joystick Visualizer */}
                    <div style={{ flex: '0 0 auto' }}>
                      <div style={{ fontSize: 10, marginBottom: 5, color: '#888' }}>Position:</div>
                      <div style={{
                        position: 'relative',
                        width: 120,
                        height: 120,
                        background: '#252526',
                        borderRadius: '50%',
                        border: '2px solid #3c3c3c',
                      }}>
                        {/* Crosshair */}
                        <div style={{
                          position: 'absolute',
                          top: '50%',
                          left: 0,
                          right: 0,
                          height: 1,
                          background: '#555',
                        }} />
                        <div style={{
                          position: 'absolute',
                          left: '50%',
                          top: 0,
                          bottom: 0,
                          width: 1,
                          background: '#555',
                        }} />
                        {/* Deadzone circle */}
                        <div style={{
                          position: 'absolute',
                          top: '50%',
                          left: '50%',
                          width: `${deadzone * 200}%`,
                          height: `${deadzone * 200}%`,
                          transform: 'translate(-50%, -50%)',
                          borderRadius: '50%',
                          border: '1px dashed #666',
                        }} />
                        {/* Stick position indicator */}
                        {(() => {
                          const rawX = (currentAxisValues[axisXIndex] || 0) * (axisXInverted ? -1 : 1);
                          const rawY = (currentAxisValues[axisYIndex] || 0) * (axisYInverted ? -1 : 1);
                          const x = applyDeadzone(rawX, deadzone);
                          const y = applyDeadzone(rawY, deadzone);
                          const left = 50 + (x * 40); // 40% = max range from center
                          const top = 50 + (y * 40);
                          const isInDeadzone = Math.abs(rawX) < deadzone && Math.abs(rawY) < deadzone;
                          
                          return (
                            <div style={{
                              position: 'absolute',
                              left: `${left}%`,
                              top: `${top}%`,
                              width: 16,
                              height: 16,
                              borderRadius: '50%',
                              background: isInDeadzone ? '#666' : '#4ec94e',
                              border: '2px solid #fff',
                              transform: 'translate(-50%, -50%)',
                              transition: 'background 0.1s',
                              boxShadow: isInDeadzone ? 'none' : '0 0 10px #4ec94e',
                            }} />
                          );
                        })()}
                      </div>
                    </div>
                    
                    {/* Numeric values */}
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 10, marginBottom: 5, color: '#888' }}>Values:</div>
                      <div style={{ fontSize: 13, fontFamily: 'monospace', lineHeight: '1.6' }}>
                        <div>
                          <span style={{ color: '#888' }}>X:</span>{' '}
                          <span style={{ color: '#4ec94e', fontWeight: 'bold' }}>
                            {applyDeadzone(
                              (axisXInverted ? -1 : 1) * (currentAxisValues[axisXIndex] || 0),
                              deadzone
                            ).toFixed(2)}
                          </span>
                        </div>
                        <div>
                          <span style={{ color: '#888' }}>Y:</span>{' '}
                          <span style={{ color: '#4ec94e', fontWeight: 'bold' }}>
                            {applyDeadzone(
                              (axisYInverted ? -1 : 1) * (currentAxisValues[axisYIndex] || 0),
                              deadzone
                            ).toFixed(2)}
                          </span>
                        </div>
                        <div style={{ fontSize: 9, color: '#666', marginTop: 5 }}>
                          {Math.abs(currentAxisValues[axisXIndex] || 0) < deadzone && 
                           Math.abs(currentAxisValues[axisYIndex] || 0) < deadzone
                            ? '⚪ In deadzone'
                            : '🟢 Active'}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Button Mappings */}
            <div style={{ marginBottom: 20 }}>
              <h3 style={{ fontSize: 14, marginBottom: 10, color: '#ffffff' }}>Button Mapping (Vectrex: 4 buttons)</h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                {vectrexButtonNames.map((name, idx) => {
                  const vectrexBtn = idx + 1;
                  const mapping = buttonMappings.find(m => m.vectrexButton === vectrexBtn);
                  const isListening = listeningForButton === `button_${vectrexBtn}`;
                  const gamepadBtn = mapping?.gamepadButton;
                  const isPressed = gamepadBtn !== undefined && pressedButtons[gamepadBtn];

                  return (
                    <div
                      key={vectrexBtn}
                      style={{
                        padding: 10,
                        background: isListening ? '#2a4a2a' : '#252526',
                        border: isListening ? '2px solid #4ec94e' : '1px solid #3c3c3c',
                        borderRadius: 4,
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
                        {/* Visual button indicator */}
                        <div style={{
                          width: 26,
                          height: 26,
                          borderRadius: '50%',
                          background: isPressed ? '#4ec94e' : '#3c3c3c',
                          border: `2px solid ${isPressed ? '#6edc6e' : '#555'}`,
                          transition: 'all 0.1s',
                          boxShadow: isPressed ? '0 0 12px #4ec94e' : 'none',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: 11,
                          fontWeight: 'bold',
                          color: isPressed ? '#000' : '#666',
                        }}>
                          {vectrexBtn}
                        </div>
                        <div style={{ fontSize: 12, fontWeight: 'bold' }}>{name}</div>
                      </div>
                      <div style={{ fontSize: 11, color: '#888', marginBottom: 8 }}>
                        {mapping
                          ? `Mapped to: ${getButtonName(mapping.gamepadButton)}`
                          : 'Not mapped'}
                      </div>
                      <button
                        onClick={() => setListeningForButton(`button_${vectrexBtn}`)}
                        disabled={isListening}
                        style={{
                          padding: '4px 10px',
                          background: isListening ? '#4ec94e' : '#0e639c',
                          border: 'none',
                          color: '#fff',
                          borderRadius: 3,
                          cursor: isListening ? 'default' : 'pointer',
                          fontSize: 11,
                          width: '100%',
                        }}
                      >
                        {isListening ? 'Press gamepad button...' : 'Set Button'}
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
            
            {/* Button Test Area - All Gamepad Buttons */}
            {pressedButtons.length > 0 && (
              <div style={{ marginTop: 15, marginBottom: 20, padding: 15, background: '#1e1e1e', borderRadius: 4 }}>
                <div style={{ fontSize: 12, marginBottom: 10, fontWeight: 'bold' }}>Button Test (All Gamepad Buttons)</div>
                <div style={{ fontSize: 10, color: '#888', marginBottom: 10 }}>
                  Press any gamepad button to test - shows all detected buttons
                </div>
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(65px, 1fr))',
                  gap: 8,
                }}>
                  {pressedButtons.map((pressed, idx) => (
                    <div
                      key={idx}
                      style={{
                        padding: 10,
                        background: pressed ? '#4ec94e' : '#252526',
                        borderRadius: 4,
                        border: `2px solid ${pressed ? '#6edc6e' : '#3c3c3c'}`,
                        textAlign: 'center',
                        fontSize: 12,
                        fontWeight: pressed ? 'bold' : 'normal',
                        color: pressed ? '#000' : '#888',
                        transition: 'all 0.1s',
                        boxShadow: pressed ? '0 0 10px #4ec94e' : 'none',
                      }}
                    >
                      <div style={{ fontSize: 9, marginBottom: 2 }}>BTN</div>
                      <div style={{ fontSize: 14, fontWeight: 'bold' }}>{idx}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}

        {/* Actions */}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', paddingTop: 15, borderTop: '1px solid #3c3c3c' }}>
          <button
            onClick={resetConfig}
            style={{
              padding: '8px 16px',
              background: '#e74c3c',
              border: 'none',
              color: '#fff',
              borderRadius: 4,
              cursor: 'pointer',
              fontSize: 13,
            }}
          >
            Reset to Default
          </button>
          <button
            onClick={() => setConfigOpen(false)}
            style={{
              padding: '8px 16px',
              background: '#0e639c',
              border: 'none',
              color: '#fff',
              borderRadius: 4,
              cursor: 'pointer',
              fontSize: 13,
            }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
