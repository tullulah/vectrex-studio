// Shell integration for the IDE's terminals: `claude` typed there gets the IDE's MCP server.
//
// Claude Code has no environment variable that adds MCP servers; the one documented way is
// the `--mcp-config <file>` flag. So the terminal's shell defines a `claude` function that
// adds it — AFTER the user's own startup files have run, so their PATH, aliases and prompt
// stay exactly as in any other terminal. This is the same technique VS Code uses for its
// shell integration: zsh through a ZDOTDIR whose files source the user's, bash through
// --init-file, fish through --init-command, PowerShell through -NoExit -Command after its
// profile. Other shells (sh, dash, cmd.exe) run unchanged: plain `claude`, no IDE tools.
//
// Nothing is written into the user's project. The MCP config lives in the app's userData.

import { app } from 'electron';
import { chmodSync, mkdirSync, writeFileSync } from 'fs';
import { basename, join } from 'path';
import * as os from 'os';

/** Subcommands that are not a session: the flag is not added in front of them. */
const SUBCOMMANDS = ['mcp', 'config', 'update', 'upgrade', 'doctor', 'install', 'setup-token',
  'migrate-installer', 'plugin', 'plugins', 'auth'];

function integrationDir(): string {
  return join(app.getPath('userData'), 'shell-integration');
}

/** Where the IDE writes the MCP config `claude` is started with. */
export function claudeMcpConfigPath(): string {
  return join(app.getPath('userData'), 'claude', 'mcp-config.json');
}

const POSIX_CLAUDE_FUNCTION = `
# --- Vectrex Studio: claude gets the IDE's tools (MCP) -----------------------------------
unalias claude 2>/dev/null
claude() {
  if [ -n "$VECTREX_STUDIO_MCP_CONFIG" ] && [ -f "$VECTREX_STUDIO_MCP_CONFIG" ]; then
    case "$1" in
      ${SUBCOMMANDS.join('|')}) command claude "$@" ;;
      *) command claude --mcp-config "$VECTREX_STUDIO_MCP_CONFIG" "$@" ;;
    esac
  else
    command claude "$@"
  fi
}
`;

// zsh: ZDOTDIR points here; each file sources the user's own (from their real ZDOTDIR or
// $HOME) with ZDOTDIR restored while it runs, so `${ZDOTDIR:-$HOME}` in their files still
// means what it always did. After .zlogin, ZDOTDIR is left at the user's value.
function zshFile(name: string, extra = ''): string {
  return `# Vectrex Studio shell integration (generated; do not edit)
VSTUDIO_INTEGRATION_ZDOTDIR="$ZDOTDIR"
ZDOTDIR="\${VECTREX_STUDIO_USER_ZDOTDIR:-$HOME}"
if [ -f "$ZDOTDIR/${name}" ]; then . "$ZDOTDIR/${name}"; fi
VECTREX_STUDIO_USER_ZDOTDIR="$ZDOTDIR"
${extra}ZDOTDIR="$VSTUDIO_INTEGRATION_ZDOTDIR"
`;
}

// /etc/zshrc (macOS) sets HISTFILE from ZDOTDIR before the user's .zshrc runs, which would
// put the history in this folder. Give it back to the user's own location.
const HISTFILE_FIX = `if [ "$HISTFILE" = "$ZDOTDIR/.zsh_history" ]; then
  HISTFILE="\${VECTREX_STUDIO_USER_ZDOTDIR:-$HOME}/.zsh_history"
fi
`;

const ZSH_LOGIN = `# Vectrex Studio shell integration (generated; do not edit)
ZDOTDIR="\${VECTREX_STUDIO_USER_ZDOTDIR:-$HOME}"
if [ -f "$ZDOTDIR/.zlogin" ]; then . "$ZDOTDIR/.zlogin"; fi
`;

// bash: started with --init-file instead of -l, so this reproduces a login shell's startup.
const BASH_INIT = `# Vectrex Studio shell integration (generated; do not edit)
if [ -r /etc/profile ]; then . /etc/profile; fi
if [ -r "$HOME/.bash_profile" ]; then . "$HOME/.bash_profile"
elif [ -r "$HOME/.bash_login" ]; then . "$HOME/.bash_login"
elif [ -r "$HOME/.profile" ]; then . "$HOME/.profile"; fi
${POSIX_CLAUDE_FUNCTION}`;

const FISH_INIT = `# Vectrex Studio shell integration (generated; do not edit)
functions -e claude 2>/dev/null
function claude
    if test -n "$VECTREX_STUDIO_MCP_CONFIG"; and test -f "$VECTREX_STUDIO_MCP_CONFIG"
        switch "$argv[1]"
            case ${SUBCOMMANDS.join(' ')}
                command claude $argv
            case '*'
                command claude --mcp-config "$VECTREX_STUDIO_MCP_CONFIG" $argv
        end
    else
        command claude $argv
    end
end
`;

const PWSH_INIT = `# Vectrex Studio shell integration (generated; do not edit)
Remove-Item Alias:claude -ErrorAction SilentlyContinue
function global:claude {
  $real = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $real) { Write-Error 'Claude Code is not installed: irm https://claude.ai/install.ps1 | iex'; return }
  $cfg = $env:VECTREX_STUDIO_MCP_CONFIG
  $sub = @(${SUBCOMMANDS.map(s => `'${s}'`).join(',')})
  if ($cfg -and (Test-Path $cfg) -and -not ($args.Count -gt 0 -and $sub -contains $args[0])) {
    & $real.Source --mcp-config $cfg @args
  } else {
    & $real.Source @args
  }
}
`;

let prepared = false;

/** Writes the integration scripts (once per run; they are regenerated on every start). */
export function prepareShellIntegration(): void {
  if (prepared) return;
  const dir = integrationDir();
  const zdot = join(dir, 'zsh');
  mkdirSync(zdot, { recursive: true });
  writeFileSync(join(zdot, '.zshenv'), zshFile('.zshenv'));
  writeFileSync(join(zdot, '.zprofile'), zshFile('.zprofile'));
  writeFileSync(join(zdot, '.zshrc'), HISTFILE_FIX + zshFile('.zshrc', POSIX_CLAUDE_FUNCTION));
  writeFileSync(join(zdot, '.zlogin'), ZSH_LOGIN);
  writeFileSync(join(dir, 'bash-init.sh'), BASH_INIT);
  writeFileSync(join(dir, 'fish-init.fish'), FISH_INIT);
  writeFileSync(join(dir, 'pwsh-init.ps1'), PWSH_INIT);
  prepared = true;
}

/**
 * The shell to spawn, rewritten to load the integration, plus the env it needs. A shell
 * this does not know is returned unchanged.
 */
export function withShellIntegration(
  file: string, args: string[], env: NodeJS.ProcessEnv,
): { file: string; args: string[]; env: NodeJS.ProcessEnv } {
  try {
    prepareShellIntegration();
  } catch {
    return { file, args, env };       // can't write userData: plain shell, still usable
  }
  const dir = integrationDir();
  const name = basename(file).toLowerCase().replace(/\.exe$/, '');
  const out: NodeJS.ProcessEnv = { ...env, VECTREX_STUDIO_MCP_CONFIG: claudeMcpConfigPath() };
  switch (name) {
    case 'zsh':
      out.VECTREX_STUDIO_USER_ZDOTDIR = env.ZDOTDIR || os.homedir();
      out.ZDOTDIR = join(dir, 'zsh');
      return { file, args, env: out };                       // still `-l`
    case 'bash':
      return { file, args: ['--init-file', join(dir, 'bash-init.sh'), '-i'], env: out };
    case 'fish':
      return { file, args: [...args, '--init-command', `source '${join(dir, 'fish-init.fish')}'`], env: out };
    case 'powershell':
    case 'pwsh':
      return {
        file,
        args: [...args, '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', `. '${join(dir, 'pwsh-init.ps1')}'`],
        env: out,
      };
    default:
      return { file, args, env };
  }
}

/**
 * Writes the MCP config `claude` is started with: one stdio server, the IDE's own, started
 * the way this install can start it. The file holds the session token, so it is private.
 */
export function writeClaudeMcpConfig(spec: { command: string; args: string[]; env: Record<string, string> }): void {
  const path = claudeMcpConfigPath();
  mkdirSync(join(path, '..'), { recursive: true });
  const config = {
    mcpServers: {
      'vectrex-studio': { type: 'stdio', command: spec.command, args: spec.args, env: spec.env },
    },
  };
  writeFileSync(path, JSON.stringify(config, null, 2) + '\n', { mode: 0o600 });
  try { chmodSync(path, 0o600); } catch { /* Windows */ }
}
