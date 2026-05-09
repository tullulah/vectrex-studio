import React, { useState, useCallback, useMemo } from 'react';
import { useProjectStore } from '../state/projectStore';
import type { FileNode } from '../types/models';

// ============================================
// Types
// ============================================

export interface EnemyAction {
  name: string;
  sprite: string;
  loop: boolean;
}

export interface EnemyStats {
  hp: number;
  speed: number;
  action_duration: number;
}

export type EnemyBehaviorType = 'patrol' | 'chase' | 'flee' | 'static';

export interface EnemyPatrol {
  waypoints: { x: number; y: number }[];
  loop: boolean;
  mirrorOnPatrol: boolean;
  defaultFacing: 'left' | 'right';
  patrolAction: string;  // which action plays while patrolling (e.g. 'walk')
}

export interface EnemyBehavior {
  type: EnemyBehaviorType;
  patrol: EnemyPatrol;
  chase_range: number;
  respawn: boolean;
  wave: number;
}

export interface EnemyResource {
  version: string;
  name: string;
  actions: EnemyAction[];
  stats: EnemyStats;
  behavior: EnemyBehavior;
  state_machine?: EnemyStateMachine;
}

// ── State machine ──────────────────────────────────────────────────────────

/** A transition: when `event` fires, move to state `to` */
export interface EnemyStateTransition {
  event: string;   // e.g. "onSnowHit", "onKick"
  to: string;      // target state name
}

/** One state in the enemy state machine */
export interface EnemyState {
  /** Unique state name, used as identifier in code (e.g. "snow1") */
  name: string;
  /** Which action (from actions[]) to play while in this state */
  action: string;
  /** Frames before auto-returning to decay_to (0 = no decay) */
  decay_frames: number;
  /** State to transition to after decay_frames (empty = stay) */
  decay_to: string;
  /** Event-driven transitions */
  on_event: EnemyStateTransition[];
}

export interface EnemyStateMachine {
  /** Name of the initial state */
  initial_state: string;
  states: EnemyState[];
}

interface EnemyEditorProps {
  resource?: EnemyResource;
  onChange?: (resource: EnemyResource) => void;
}

// ============================================
// Default factory
// ============================================

export function defaultEnemy(name = 'untitled'): EnemyResource {
  return {
    version: '1.0',
    name,
    actions: [
      { name: 'idle', sprite: '', loop: true },
      { name: 'walk', sprite: '', loop: true },
    ],
    stats: { hp: 3, speed: 40, action_duration: 180 },
    behavior: {
      type: 'patrol',
      patrol: { waypoints: [], loop: true, mirrorOnPatrol: false, defaultFacing: 'right', patrolAction: '' },
      chase_range: 80,
      respawn: false,
      wave: 0,
    },
  };
}

// ============================================
// Helpers
// ============================================

function flattenFiles(nodes: FileNode[]): FileNode[] {
  const out: FileNode[] = [];
  for (const n of nodes) {
    if (n.isDir && n.children) out.push(...flattenFiles(n.children));
    else out.push(n);
  }
  return out;
}

function basename(path: string): string {
  return path.split(/[\\/]/).pop() || path;
}

// ============================================
// Styles
// ============================================

const sectionStyle: React.CSSProperties = {
  background: '#1a1a2e',
  border: '1px solid #2a2a4e',
  borderRadius: 6,
  padding: '12px 14px',
  marginBottom: 12,
};

const labelStyle: React.CSSProperties = {
  fontSize: 11,
  color: '#888',
  marginBottom: 3,
  display: 'block',
};

const inputStyle: React.CSSProperties = {
  background: '#0d0d1a',
  color: '#d4d4d4',
  border: '1px solid #3a3a5a',
  borderRadius: 3,
  padding: '4px 6px',
  fontSize: 12,
  boxSizing: 'border-box' as const,
};

const selectStyle: React.CSSProperties = {
  ...inputStyle,
  width: '100%',
  cursor: 'pointer',
};

const headingStyle: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 700,
  color: '#7a7aff',
  letterSpacing: '0.08em',
  marginBottom: 10,
  textTransform: 'uppercase' as const,
};

// ============================================
// Sub-components
// ============================================

interface NumberFieldProps {
  label: string;
  value: number;
  min?: number;
  max?: number;
  step?: number;
  onChange: (v: number) => void;
  hint?: string;
}

const NumberField: React.FC<NumberFieldProps> = ({ label, value, min, max, step = 1, onChange, hint }) => (
  <div style={{ marginBottom: 8 }}>
    <label style={labelStyle}>
      {label}
      {hint && <span style={{ color: '#555', marginLeft: 4 }}>{hint}</span>}
    </label>
    <input
      type="number"
      value={value}
      min={min}
      max={max}
      step={step}
      onChange={e => onChange(Number(e.target.value))}
      style={{ ...inputStyle, width: '100%' }}
    />
  </div>
);

interface ActionRowProps {
  action: EnemyAction;
  index: number;
  vecFiles: string[];
  animFiles: string[];
  onChange: (patch: Partial<EnemyAction>) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  isFirst: boolean;
  isLast: boolean;
}

const ActionRow: React.FC<ActionRowProps> = ({
  action, index, vecFiles, animFiles, onChange, onRemove, onMoveUp, onMoveDown, isFirst, isLast
}) => {
  const spriteLabel = action.sprite ? basename(action.sprite) : '— none —';
  const isAnim = action.sprite.endsWith('.vanim');

  return (
    <div style={{
      background: '#0d0d1a',
      border: '1px solid #2a2a4e',
      borderRadius: 4,
      padding: '8px 10px',
      marginBottom: 6,
    }}>
      {/* Row 1: index + name + reorder + delete */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
        <span style={{ fontSize: 10, color: '#444', minWidth: 16, textAlign: 'right' }}>{index + 1}</span>
        <input
          value={action.name}
          onChange={e => onChange({ name: e.target.value })}
          placeholder="action name"
          style={{
            ...inputStyle,
            flex: 1,
            fontWeight: 600,
            color: '#aad4ff',
            borderColor: '#2a4a6a',
          }}
        />
        <button
          onClick={onMoveUp}
          disabled={isFirst}
          title="Move up"
          style={{
            background: 'transparent',
            border: 'none',
            color: isFirst ? '#333' : '#666',
            cursor: isFirst ? 'default' : 'pointer',
            fontSize: 12,
            padding: '0 2px',
          }}
        >▲</button>
        <button
          onClick={onMoveDown}
          disabled={isLast}
          title="Move down"
          style={{
            background: 'transparent',
            border: 'none',
            color: isLast ? '#333' : '#666',
            cursor: isLast ? 'default' : 'pointer',
            fontSize: 12,
            padding: '0 2px',
          }}
        >▼</button>
        <button
          onClick={onRemove}
          title="Remove action"
          style={{
            background: 'transparent',
            border: 'none',
            color: '#883333',
            cursor: 'pointer',
            fontSize: 14,
            padding: '0 2px',
            lineHeight: 1,
          }}
        >×</button>
      </div>

      {/* Row 2: sprite picker */}
      <select
        value={action.sprite}
        onChange={e => onChange({ sprite: e.target.value })}
        style={{
          ...selectStyle,
          marginBottom: 6,
          color: action.sprite ? (isAnim ? '#ffcc44' : '#88ddaa') : '#555',
        }}
      >
        <option value="">— no sprite —</option>
        {vecFiles.length > 0 && (
          <optgroup label="Vectors (.vec)">
            {vecFiles.map(f => <option key={f} value={f}>{basename(f)}</option>)}
          </optgroup>
        )}
        {animFiles.length > 0 && (
          <optgroup label="Animations (.vanim)">
            {animFiles.map(f => <option key={f} value={f}>{basename(f)}</option>)}
          </optgroup>
        )}
      </select>

      {/* Row 3: loop toggle + sprite type badge */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <label style={{
          display: 'flex',
          alignItems: 'center',
          gap: 5,
          fontSize: 11,
          color: '#888',
          cursor: 'pointer',
          userSelect: 'none',
        }}>
          <input
            type="checkbox"
            checked={action.loop}
            onChange={e => onChange({ loop: e.target.checked })}
            style={{ cursor: 'pointer' }}
          />
          loop
        </label>
        {action.sprite && (
          <span style={{
            fontSize: 10,
            padding: '1px 6px',
            borderRadius: 8,
            background: isAnim ? '#332200' : '#002211',
            color: isAnim ? '#ffcc44' : '#44cc88',
            border: `1px solid ${isAnim ? '#ffcc4466' : '#44cc8866'}`,
          }}>
            {isAnim ? '.vanim' : '.vec'}
          </span>
        )}
        {action.sprite && (
          <span style={{ fontSize: 10, color: '#555', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {spriteLabel}
          </span>
        )}
      </div>
    </div>
  );
};

// ============================================
// Main component
// ============================================

export const EnemyEditor: React.FC<EnemyEditorProps> = ({ resource, onChange }) => {
  const { project } = useProjectStore();
  const [newActionName, setNewActionName] = useState('');

  const res: EnemyResource = useMemo(() => {
    const base: any = resource ? { ...resource } : defaultEnemy();
    // Migrate old format: sprites object → actions array
    if (!base.actions && base.sprites) {
      base.actions = Object.entries(base.sprites as Record<string, string>)
        .map(([name, sprite]) => ({ name, sprite: sprite ?? '', loop: true }));
      delete base.sprites;
    }
    if (!base.actions) base.actions = [];
    // Migrate freeze_frames → action_duration
    if (base.stats && base.stats.freeze_frames !== undefined && base.stats.action_duration === undefined) {
      base.stats.action_duration = base.stats.freeze_frames;
      delete base.stats.freeze_frames;
    }
    // Ensure patrol fields exist (old files may omit them)
    if (!base.behavior) base.behavior = defaultEnemy().behavior;
    if (!base.behavior.patrol) base.behavior.patrol = defaultEnemy().behavior.patrol;
    if (base.behavior.patrol.mirrorOnPatrol === undefined) base.behavior.patrol.mirrorOnPatrol = false;
    if (base.behavior.patrol.defaultFacing === undefined) base.behavior.patrol.defaultFacing = 'right';
    if (base.behavior.patrol.patrolAction === undefined) base.behavior.patrol.patrolAction = '';
    return base as EnemyResource;
  }, [resource]);

  const update = useCallback((patch: Partial<EnemyResource>) => {
    onChange?.({ ...res, ...patch });
  }, [res, onChange]);

  const updateStats = useCallback((patch: Partial<EnemyStats>) => {
    update({ stats: { ...res.stats, ...patch } });
  }, [res.stats, update]);

  const updateBehavior = useCallback((patch: Partial<EnemyBehavior>) => {
    update({ behavior: { ...res.behavior, ...patch } });
  }, [res.behavior, update]);

  const updatePatrol = useCallback((patch: Partial<EnemyPatrol>) => {
    updateBehavior({ patrol: { ...res.behavior.patrol, ...patch } });
  }, [res.behavior.patrol, updateBehavior]);

  // Actions helpers
  const updateAction = useCallback((i: number, patch: Partial<EnemyAction>) => {
    const next = res.actions.map((a, idx) => idx === i ? { ...a, ...patch } : a);
    update({ actions: next });
  }, [res.actions, update]);

  const removeAction = useCallback((i: number) => {
    update({ actions: res.actions.filter((_, idx) => idx !== i) });
  }, [res.actions, update]);

  const moveAction = useCallback((i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= res.actions.length) return;
    const next = [...res.actions];
    [next[i], next[j]] = [next[j], next[i]];
    update({ actions: next });
  }, [res.actions, update]);

  const addAction = useCallback(() => {
    const name = newActionName.trim();
    if (!name) return;
    update({ actions: [...res.actions, { name, sprite: '', loop: true }] });
    setNewActionName('');
  }, [newActionName, res.actions, update]);

  // Collect .vec and .vanim files from project
  const { vecFiles, animFiles } = useMemo(() => {
    if (!project?.files) return { vecFiles: [], animFiles: [] };
    const all = flattenFiles(project.files);
    return {
      vecFiles: all.filter(f => f.name.endsWith('.vec')).map(f => f.path),
      animFiles: all.filter(f => f.name.endsWith('.vanim')).map(f => f.path),
    };
  }, [project?.files]);

  const [waypointInput, setWaypointInput] = useState('0, 0');

  const addWaypoint = () => {
    const parts = waypointInput.split(',').map(s => parseInt(s.trim(), 10));
    if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
      updatePatrol({
        waypoints: [...res.behavior.patrol.waypoints, { x: parts[0], y: parts[1] }],
      });
      setWaypointInput('0, 0');
    }
  };

  // ── State machine helpers ──────────────────────────────────────────────────

  const sm = res.state_machine;

  const updateSM = useCallback((patch: Partial<EnemyStateMachine>) => {
    update({ state_machine: { ...(res.state_machine ?? { initial_state: '', states: [] }), ...patch } });
  }, [res.state_machine, update]);

  const updateSMState = useCallback((i: number, patch: Partial<EnemyState>) => {
    if (!res.state_machine) return;
    const next = res.state_machine.states.map((s, idx) => idx === i ? { ...s, ...patch } : s);
    updateSM({ states: next });
  }, [res.state_machine, updateSM]);

  const addSMState = useCallback(() => {
    const existing = res.state_machine ?? { initial_state: 'normal', states: [] };
    const newState: EnemyState = {
      name: `state${existing.states.length + 1}`,
      action: '',
      decay_frames: 0,
      decay_to: '',
      on_event: [],
    };
    updateSM({ states: [...existing.states, newState] });
  }, [res.state_machine, updateSM]);

  const removeSMState = useCallback((i: number) => {
    if (!res.state_machine) return;
    updateSM({ states: res.state_machine.states.filter((_, idx) => idx !== i) });
  }, [res.state_machine, updateSM]);

  const addSMTransition = useCallback((stateIdx: number) => {
    if (!res.state_machine) return;
    updateSMState(stateIdx, {
      on_event: [...res.state_machine.states[stateIdx].on_event, { event: '', to: '' }],
    });
  }, [res.state_machine, updateSMState]);

  const updateSMTransition = useCallback((stateIdx: number, evtIdx: number, patch: Partial<EnemyStateTransition>) => {
    if (!res.state_machine) return;
    const transitions = res.state_machine.states[stateIdx].on_event.map((t, i) =>
      i === evtIdx ? { ...t, ...patch } : t
    );
    updateSMState(stateIdx, { on_event: transitions });
  }, [res.state_machine, updateSMState]);

  const removeSMTransition = useCallback((stateIdx: number, evtIdx: number) => {
    if (!res.state_machine) return;
    const transitions = res.state_machine.states[stateIdx].on_event.filter((_, i) => i !== evtIdx);
    updateSMState(stateIdx, { on_event: transitions });
  }, [res.state_machine, updateSMState]);

  const enableSM = useCallback(() => {
    update({
      state_machine: {
        initial_state: 'normal',
        states: [
          { name: 'normal', action: res.behavior.patrol.patrolAction || 'walk', decay_frames: 0, decay_to: '', on_event: [] },
        ],
      },
    });
  }, [res.behavior.patrol.patrolAction, update]);

  const disableSM = useCallback(() => {
    update({ state_machine: undefined });
  }, [update]);

  const BEHAVIOR_COLORS: Record<EnemyBehaviorType, string> = {
    patrol: '#4488ff',
    chase: '#ff4444',
    flee: '#44ff88',
    static: '#888888',
  };

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      background: '#12121e',
      color: '#d4d4d4',
      fontFamily: 'monospace',
      overflowY: 'auto',
    }}>
      {/* Header */}
      <div style={{
        padding: '14px 16px 10px',
        borderBottom: '1px solid #2a2a4e',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        flexShrink: 0,
      }}>
        <span style={{ fontSize: 20 }}>👾</span>
        <div style={{ flex: 1 }}>
          <input
            value={res.name}
            onChange={e => update({ name: e.target.value })}
            placeholder="enemy name"
            style={{
              background: 'transparent',
              border: 'none',
              borderBottom: '1px solid #3a3a5a',
              color: '#fff',
              fontSize: 16,
              fontWeight: 700,
              fontFamily: 'monospace',
              width: '100%',
              outline: 'none',
              padding: '2px 0',
            }}
          />
          <div style={{ fontSize: 10, color: '#555', marginTop: 2 }}>
            v{res.version} · {res.actions.length} action{res.actions.length !== 1 ? 's' : ''} · enemy type definition (.venemy)
          </div>
        </div>
        <div style={{
          padding: '3px 10px',
          background: BEHAVIOR_COLORS[res.behavior.type] + '22',
          border: `1px solid ${BEHAVIOR_COLORS[res.behavior.type]}`,
          borderRadius: 12,
          color: BEHAVIOR_COLORS[res.behavior.type],
          fontSize: 11,
          fontWeight: 600,
        }}>
          {res.behavior.type.toUpperCase()}
        </div>
      </div>

      <div style={{ padding: '14px 16px', flex: 1 }}>

        {/* ACTIONS */}
        <div style={sectionStyle}>
          <div style={headingStyle}>Actions</div>

          {res.actions.length === 0 && (
            <div style={{ fontSize: 11, color: '#555', fontStyle: 'italic', marginBottom: 10 }}>
              No actions defined yet — add one below.
            </div>
          )}

          {res.actions.map((action, i) => (
            <ActionRow
              key={i}
              action={action}
              index={i}
              vecFiles={vecFiles}
              animFiles={animFiles}
              onChange={patch => updateAction(i, patch)}
              onRemove={() => removeAction(i)}
              onMoveUp={() => moveAction(i, -1)}
              onMoveDown={() => moveAction(i, 1)}
              isFirst={i === 0}
              isLast={i === res.actions.length - 1}
            />
          ))}

          {/* Add new action */}
          <div style={{ display: 'flex', gap: 6, marginTop: 4 }}>
            <input
              value={newActionName}
              onChange={e => setNewActionName(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') addAction(); }}
              placeholder="action name (e.g. idle, walk, die…)"
              style={{ ...inputStyle, flex: 1 }}
            />
            <button
              onClick={addAction}
              disabled={!newActionName.trim()}
              style={{
                background: newActionName.trim() ? '#1a3a6a' : '#111',
                border: `1px solid ${newActionName.trim() ? '#4488ff' : '#333'}`,
                color: newActionName.trim() ? '#4488ff' : '#444',
                borderRadius: 3,
                padding: '4px 10px',
                cursor: newActionName.trim() ? 'pointer' : 'default',
                fontSize: 12,
                flexShrink: 0,
                whiteSpace: 'nowrap',
              }}
            >
              + New Action
            </button>
          </div>
        </div>

        {/* STATS */}
        <div style={sectionStyle}>
          <div style={headingStyle}>Stats</div>
          <NumberField
            label="HP"
            value={res.stats.hp}
            min={1}
            max={99}
            onChange={v => updateStats({ hp: v })}
            hint="hits to defeat"
          />
          <NumberField
            label="Speed"
            value={res.stats.speed}
            min={1}
            max={255}
            onChange={v => updateStats({ speed: v })}
            hint="VPy units/sec"
          />
          <NumberField
            label="Action Duration"
            value={res.stats.action_duration}
            min={1}
            max={9999}
            onChange={v => updateStats({ action_duration: v })}
            hint="frames @50fps"
          />
        </div>

        {/* BEHAVIOR */}
        <div style={sectionStyle}>
          <div style={headingStyle}>Behavior</div>

          <div style={{ marginBottom: 8 }}>
            <label style={labelStyle}>Type</label>
            <select
              value={res.behavior.type}
              onChange={e => updateBehavior({ type: e.target.value as EnemyBehaviorType })}
              style={{ ...selectStyle, color: BEHAVIOR_COLORS[res.behavior.type] }}
            >
              <option value="patrol">patrol — follows waypoints</option>
              <option value="chase">chase — pursues player</option>
              <option value="flee">flee — runs from player</option>
              <option value="static">static — stays in place</option>
            </select>
          </div>

          {(res.behavior.type === 'chase' || res.behavior.type === 'flee') && (
            <NumberField
              label="Chase Range"
              value={res.behavior.chase_range}
              min={0}
              max={500}
              onChange={v => updateBehavior({ chase_range: v })}
              hint="VPy units"
            />
          )}

          {res.behavior.type === 'patrol' && (
            <div style={{ marginBottom: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
              <label style={{
                ...labelStyle,
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                cursor: 'pointer',
                userSelect: 'none',
                marginBottom: 0,
              }}>
                <input
                  type="checkbox"
                  checked={res.behavior.patrol.loop}
                  onChange={e => updatePatrol({ loop: e.target.checked })}
                  style={{ cursor: 'pointer' }}
                />
                Loop patrol
              </label>
              <label style={{
                ...labelStyle,
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                cursor: 'pointer',
                userSelect: 'none',
                marginBottom: 0,
              }}>
                <input
                  type="checkbox"
                  checked={res.behavior.patrol.mirrorOnPatrol ?? false}
                  onChange={e => updatePatrol({ mirrorOnPatrol: e.target.checked })}
                  style={{ cursor: 'pointer' }}
                />
                Mirror on turn
              </label>
              {res.behavior.patrol.mirrorOnPatrol && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingLeft: 22 }}>
                  <label style={{ ...labelStyle, marginBottom: 0, whiteSpace: 'nowrap' }}>Default facing</label>
                  <select
                    value={res.behavior.patrol.defaultFacing ?? 'right'}
                    onChange={e => updatePatrol({ defaultFacing: e.target.value as 'left' | 'right' })}
                    style={{ ...selectStyle, flex: 1 }}
                  >
                    <option value="right">→ Right</option>
                    <option value="left">← Left</option>
                  </select>
                </div>
              )}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <label style={{ ...labelStyle, marginBottom: 0, whiteSpace: 'nowrap' }}>Patrol action</label>
                <select
                  value={res.behavior.patrol.patrolAction ?? ''}
                  onChange={e => updatePatrol({ patrolAction: e.target.value })}
                  style={{ ...selectStyle, flex: 1, color: res.behavior.patrol.patrolAction ? '#aad4ff' : '#555' }}
                >
                  <option value="">— use first action —</option>
                  {res.actions.map(a => (
                    <option key={a.name} value={a.name}>{a.name}</option>
                  ))}
                </select>
              </div>
            </div>
          )}

          <div style={{ marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <label style={{
              ...labelStyle,
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              cursor: 'pointer',
              userSelect: 'none',
              marginBottom: 0,
            }}>
              <input
                type="checkbox"
                checked={res.behavior.respawn}
                onChange={e => updateBehavior({ respawn: e.target.checked })}
                style={{ cursor: 'pointer' }}
              />
              Respawn
            </label>
          </div>

          <NumberField
            label="Wave"
            value={res.behavior.wave}
            min={0}
            max={99}
            onChange={v => updateBehavior({ wave: v })}
            hint="0 = always present"
          />
        </div>

        {/* PATROL WAYPOINTS */}
        {res.behavior.type === 'patrol' && (
          <div style={sectionStyle}>
            <div style={headingStyle}>Patrol Waypoints</div>
            <div style={{ fontSize: 11, color: '#666', marginBottom: 8 }}>
              You can also draw waypoints visually in the Playground editor.
            </div>

            {res.behavior.patrol.waypoints.length === 0 ? (
              <div style={{ fontSize: 11, color: '#555', fontStyle: 'italic', marginBottom: 8 }}>
                No waypoints — enemy will stand idle.
              </div>
            ) : (
              <div style={{ marginBottom: 8 }}>
                {res.behavior.patrol.waypoints.map((wp, i) => (
                  <div key={i} style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    marginBottom: 4,
                    background: '#0d0d1a',
                    borderRadius: 3,
                    padding: '3px 6px',
                    fontSize: 11,
                    color: '#4488ff',
                  }}>
                    <span style={{ color: '#555', minWidth: 18 }}>{i + 1}.</span>
                    <span style={{ flex: 1 }}>({wp.x}, {wp.y})</span>
                    <button
                      onClick={() => updatePatrol({ waypoints: res.behavior.patrol.waypoints.filter((_, j) => j !== i) })}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        color: '#883333',
                        cursor: 'pointer',
                        fontSize: 12,
                        padding: '0 2px',
                      }}
                    >×</button>
                  </div>
                ))}
              </div>
            )}

            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <input
                value={waypointInput}
                onChange={e => setWaypointInput(e.target.value)}
                placeholder="x, y"
                onKeyDown={e => { if (e.key === 'Enter') addWaypoint(); }}
                style={{ ...inputStyle, flex: 1 }}
              />
              <button
                onClick={addWaypoint}
                style={{
                  background: '#1a3a6a',
                  border: '1px solid #4488ff',
                  color: '#4488ff',
                  borderRadius: 3,
                  padding: '4px 10px',
                  cursor: 'pointer',
                  fontSize: 12,
                  flexShrink: 0,
                }}
              >
                + Add
              </button>
            </div>
          </div>
        )}

        {/* ── STATE MACHINE ── */}
        <div style={sectionStyle}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={headingStyle}>State Machine</div>
            {sm
              ? <button onClick={disableSM} style={{ background: 'transparent', border: '1px solid #553333', color: '#aa5555', borderRadius: 3, padding: '2px 8px', cursor: 'pointer', fontSize: 11 }}>Disable</button>
              : <button onClick={enableSM} style={{ background: '#1a2a1a', border: '1px solid #44aa44', color: '#44aa44', borderRadius: 3, padding: '2px 8px', cursor: 'pointer', fontSize: 11 }}>Enable</button>
            }
          </div>
          {!sm && (
            <div style={{ fontSize: 11, color: '#555', fontStyle: 'italic' }}>
              No state machine — enemy uses a single action. Enable to add snow/hit states, death sequences, etc.
            </div>
          )}
          {sm && (
            <>
              <div style={{ marginBottom: 10 }}>
                <label style={labelStyle}>Initial state</label>
                <select value={sm.initial_state} onChange={e => updateSM({ initial_state: e.target.value })} style={selectStyle}>
                  {sm.states.map(s => <option key={s.name} value={s.name}>{s.name}</option>)}
                </select>
              </div>

              {sm.states.map((st, si) => (
                <div key={si} style={{ background: '#0d0d1a', border: '1px solid #2a2a4e', borderRadius: 4, padding: '8px 10px', marginBottom: 8 }}>
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 6 }}>
                    <input value={st.name} onChange={e => updateSMState(si, { name: e.target.value })}
                      style={{ ...inputStyle, flex: 1, fontWeight: 700, color: '#ffcc44' }} placeholder="state name" />
                    <select value={st.action} onChange={e => updateSMState(si, { action: e.target.value })} style={{ ...selectStyle, flex: 1 }}>
                      <option value="">— action —</option>
                      {res.actions.map(a => <option key={a.name} value={a.name}>{a.name}</option>)}
                    </select>
                    <button onClick={() => removeSMState(si)} style={{ background: 'transparent', border: 'none', color: '#883333', cursor: 'pointer', fontSize: 14 }}>×</button>
                  </div>
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 6 }}>
                    <div style={{ flex: 1 }}>
                      <label style={labelStyle}>Decay frames (0=none)</label>
                      <input type="number" value={st.decay_frames} min={0} step={10}
                        onChange={e => updateSMState(si, { decay_frames: Number(e.target.value) })}
                        style={{ ...inputStyle, width: '100%' }} />
                    </div>
                    <div style={{ flex: 1 }}>
                      <label style={labelStyle}>Decay to</label>
                      <select value={st.decay_to} onChange={e => updateSMState(si, { decay_to: e.target.value })} style={selectStyle}>
                        <option value="">— stay —</option>
                        {sm.states.map(s => <option key={s.name} value={s.name}>{s.name}</option>)}
                      </select>
                    </div>
                  </div>
                  <div style={{ fontSize: 10, color: '#4466aa', marginBottom: 4, letterSpacing: '0.06em' }}>EVENT TRANSITIONS</div>
                  {st.on_event.map((t, ti) => (
                    <div key={ti} style={{ display: 'flex', gap: 4, alignItems: 'center', marginBottom: 4 }}>
                      <input value={t.event} onChange={e => updateSMTransition(si, ti, { event: e.target.value })}
                        placeholder="event (e.g. onSnowHit)" style={{ ...inputStyle, flex: 1, fontSize: 11 }} />
                      <span style={{ color: '#555', fontSize: 11 }}>→</span>
                      <select value={t.to} onChange={e => updateSMTransition(si, ti, { to: e.target.value })} style={{ ...selectStyle, flex: 1, fontSize: 11 }}>
                        <option value="">— state —</option>
                        {sm.states.map(s => <option key={s.name} value={s.name}>{s.name}</option>)}
                      </select>
                      <button onClick={() => removeSMTransition(si, ti)} style={{ background: 'transparent', border: 'none', color: '#883333', cursor: 'pointer', fontSize: 12 }}>×</button>
                    </div>
                  ))}
                  <button onClick={() => addSMTransition(si)}
                    style={{ background: 'transparent', border: '1px solid #2a3a5a', color: '#4466aa', borderRadius: 3, padding: '2px 8px', cursor: 'pointer', fontSize: 11 }}>
                    + event
                  </button>
                </div>
              ))}

              <button onClick={addSMState}
                style={{ background: '#1a2a1a', border: '1px solid #44aa44', color: '#44aa44', borderRadius: 3, padding: '4px 12px', cursor: 'pointer', fontSize: 12, width: '100%' }}>
                + Add State
              </button>

              {sm.states.some(s => s.on_event.length > 0) && (
                <div style={{ marginTop: 10, background: '#0a0a16', borderRadius: 4, padding: '8px 10px', fontSize: 10 }}>
                  <div style={{ color: '#4466aa', marginBottom: 4, letterSpacing: '0.06em' }}>GENERATED HANDLERS (implement in .vpy)</div>
                  {sm.states.flatMap(s => s.on_event.map(t => t.event)).filter((e, i, a) => e && a.indexOf(e) === i).map(evt => (
                    <div key={evt} style={{ color: '#66aa66', fontFamily: 'monospace', marginBottom: 2 }}>
                      def {res.name}_{evt}(idx):
                    </div>
                  ))}
                  {sm.states.map(s => (
                    <div key={s.name} style={{ color: '#aa6644', fontFamily: 'monospace', marginBottom: 2 }}>
                      def {res.name}_on_enter_{s.name}(idx):
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};
