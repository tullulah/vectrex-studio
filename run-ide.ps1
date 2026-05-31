param(
  [switch]$NoDevTools,   # deshabilita DevTools (por defecto están habilitados)
  [switch]$StrictCSP,    # ahora la relajación es por defecto; usar -StrictCSP para política estricta
  [switch]$NoRustBuild,
  [switch]$NoWasmBuild,  # omite wasm build
  [switch]$Fast,         # omite npm install si ya existe node_modules
  [switch]$NoClear,      # evita limpiar pantalla (preserva logs)
  [switch]$VerboseLsp,   # más logging sobre ruta/estado LSP
  [switch]$Production    # ejecuta en modo producción (sin hot reload)
)
<#
Script simplificado (con dependencias automáticas):
  1. Verifica npm
  2. Instala (si faltan) dependencias en ide/frontend y ide/electron
  3. Lanza: powershell -NoLogo -NoProfile -Command "Set-Location ide/electron; npm run dev"
  4. DevTools habilitados por defecto (usar -NoDevTools para deshabilitarlos)

Compilación Rust: manual (cargo build --workspace) si la quieres antes del LSP.
Uso:
  .\run-ide.ps1              # normal (con DevTools)
  .\run-ide.ps1 -NoDevTools  # sin DevTools
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if(-not (Get-Command npm -ErrorAction SilentlyContinue)){
  Write-Host '[ERR ] npm no encontrado en PATH' -ForegroundColor Red
  exit 1
}

# DevTools habilitados por defecto (deshabilitar con -NoDevTools)
if(-not $NoDevTools){ $env:VPY_IDE_DEVTOOLS = '1' } else { Remove-Item Env:VPY_IDE_DEVTOOLS -ErrorAction SilentlyContinue | Out-Null }
# Relajado por defecto (para permitir React Fast Refresh y estilos inline de desarrollo). Si se pasa -StrictCSP se limpia.
if(-not $StrictCSP){ $env:VPY_IDE_RELAX_CSP = '1' } else { Remove-Item Env:VPY_IDE_RELAX_CSP -ErrorAction SilentlyContinue | Out-Null }
if($NoClear){ $env:VPY_IDE_NO_CLEAR = '1' } else { Remove-Item Env:VPY_IDE_NO_CLEAR -ErrorAction SilentlyContinue | Out-Null }
if($VerboseLsp){ $env:VPY_IDE_VERBOSE_LSP = '1' } else { Remove-Item Env:VPY_IDE_VERBOSE_LSP -ErrorAction SilentlyContinue | Out-Null }

# Instalación condicional (opcionalmente saltada con -Fast)
function Install-NodeModulesIfMissing($dir){
  if(-not (Test-Path (Join-Path $dir 'package.json'))){ return }
  $nm = Join-Path $dir 'node_modules'
  if($Fast -and (Test-Path $nm)){ return }
  if(-not (Test-Path $nm)){
    Write-Host "[INFO] npm install -> $dir" -ForegroundColor Cyan
    Push-Location $dir
    npm install
    if($LASTEXITCODE -ne 0){ Write-Host '[ERR ] npm install falló' -ForegroundColor Red; exit 1 }
    Pop-Location
  }
}

Install-NodeModulesIfMissing (Join-Path $root 'ide/frontend')
Install-NodeModulesIfMissing (Join-Path $root 'ide/electron')

# Build Rust (LSP + core) salvo -NoRustBuild
if(-not $NoRustBuild){
  if(-not (Get-Command cargo -ErrorAction SilentlyContinue)){
    Write-Host '[WARN] cargo no encontrado; se omite build Rust' -ForegroundColor Yellow
  } else {
    Write-Host '[INFO] cargo build (vpy_lsp + vpy_cli)' -ForegroundColor Cyan
    # Legacy vectrexc dropped — IDE defaults to buildtools (vpy_cli). Build it
    # manually if you still need the deprecated core backend.
    cargo build --bin vpy_lsp --bin vpy_cli
    if($LASTEXITCODE -ne 0){ Write-Host '[ERR ] cargo build falló' -ForegroundColor Red; exit 1 }
  }
}

# Comprobar binario LSP esperado (heursítica) y avisar si falta
$lspExe = Join-Path $root 'target/debug/vpy_lsp.exe'
if(-not (Test-Path $lspExe)){
  Write-Host "[WARN] Binario LSP no encontrado en $lspExe (spawn podría fallar)" -ForegroundColor Yellow
}

# ALWAYS rebuild frontend dist/ — Electron falls back to dist/index.html whenever
# VITE_DEV_SERVER_URL isn't set (production mode, npm run start, packaged app, or
# if the Vite dev server fails to come up). Without this step, every edit to src/
# or public/ is invisible on those paths and the IDE silently runs yesterday's
# bundle. `npm run build` already includes the typecheck.
Write-Host '[INFO] Construyendo frontend (dist/) ...' -ForegroundColor Cyan
& powershell -NoLogo -NoProfile -Command "Set-Location ide/frontend; npm run build"
if($LASTEXITCODE -ne 0){ Write-Host '[ERR ] Frontend build falló' -ForegroundColor Red; exit 1 }
Write-Host '[OK  ] dist/ actualizado' -ForegroundColor Green

Write-Host '[INFO] Lanzando entorno Electron' -ForegroundColor Cyan
if($Production){
  Write-Host '[INFO] Modo producción - sin hot reload' -ForegroundColor Green
  # dist/ ya está fresco arriba; ejecutar en modo producción
  & powershell -NoLogo -NoProfile -Command "Set-Location ide/electron; npm run start"
} else {
  Write-Host '[INFO] Modo desarrollo - con hot reload' -ForegroundColor Yellow
  if($NoClear){
    # Vite normalmente limpia consola; forzamos variable para detectar en plugin (si se implementa) o al menos preservamos scroll buffer
    $env:FORCE_COLOR = '1'
  }
  & powershell -NoLogo -NoProfile -Command "Set-Location ide/electron; if($NoClear){ Write-Host '[INFO] (NoClear) Ejecutando npm run dev'; }; npm run dev"
}
exit $LASTEXITCODE