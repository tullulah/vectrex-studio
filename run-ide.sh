#!/bin/bash
set -e

# Script de ejecución IDE para macOS/Linux

# Traducción de run-ide.ps1 compatible con Bash/Zsh

# Parse de argumentos
NO_DEV_TOOLS=false
STRICT_CSP=false
NO_RUST_BUILD=false
NO_WASM_BUILD=false
FAST=false
NO_CLEAR=false
VERBOSE_LSP=false
PRODUCTION=false
ENABLE_TRACEBIN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-devtools)
      NO_DEV_TOOLS=true
      shift
      ;;
    --strict-csp)
      STRICT_CSP=true
      shift
      ;;
    --no-rust-build)
      NO_RUST_BUILD=true
      shift
      ;;
    --no-wasm-build)
      NO_WASM_BUILD=true
      shift
      ;;
    --fast)
      FAST=true
      shift
      ;;
    --no-clear)
      NO_CLEAR=true
      shift
      ;;
    --verbose-lsp)
      VERBOSE_LSP=true
      shift
      ;;
    --enable-tracebin)
      ENABLE_TRACEBIN=true
      shift
      ;;
    --production)
      PRODUCTION=true
      shift
      ;;
    --help)
      echo "Uso: ./run-ide.sh [opciones]"
      echo ""
      echo "Opciones:"
      echo "  --no-devtools      Deshabilita DevTools (habilitados por defecto)"
      echo "  --strict-csp       Política CSP estricta (relajada por defecto)"
      echo "  --no-rust-build    Omite compilación Rust"
      echo "  --no-wasm-build    Omite compilación WASM"
      echo "  --fast             Omite npm install si ya existe node_modules"
      echo "  --no-clear         Preserva logs (no limpia pantalla)"
      echo "  --verbose-lsp      Más logging sobre ruta/estado LSP"
      echo "  --enable-tracebin  Habilita generación de archivos .tracebin (deshabilitado por defecto)"
      echo "  --production       Ejecuta en modo producción (sin hot reload)"
      echo "  --help             Muestra esta ayuda"
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1"
      echo "Usa --help para ver opciones disponibles"
      exit 1
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Verificar npm
if ! command -v npm &> /dev/null; then
  echo '[ERR ] npm no encontrado en PATH'
  exit 1
fi

# Verificar lwasm (ensamblador externo para modo dual)
if ! command -v lwasm &> /dev/null; then
  echo '[INFO] lwasm no encontrado - instalando lwtools...'
  
  # Detectar sistema operativo
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - usar Homebrew
    if command -v brew &> /dev/null; then
      echo '[INFO] Instalando lwtools via Homebrew...'
      brew install lwtools
      if [ $? -eq 0 ]; then
        echo '[OK  ] lwtools instalado correctamente'
      else
        echo '[WARN] No se pudo instalar lwtools automáticamente'
        echo '       Instala manualmente: brew install lwtools'
        echo '       El modo --dual no estará disponible hasta instalar lwasm'
      fi
    else
      echo '[WARN] Homebrew no encontrado - no se puede instalar lwtools'
      echo '       Instala Homebrew desde: https://brew.sh'
      echo '       Luego ejecuta: brew install lwtools'
      echo '       El modo --dual no estará disponible hasta instalar lwasm'
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux - intentar con apt-get o yum
    if command -v apt-get &> /dev/null; then
      echo '[INFO] Instalando lwtools via apt-get...'
      sudo apt-get update && sudo apt-get install -y lwtools
    elif command -v yum &> /dev/null; then
      echo '[INFO] Instalando lwtools via yum...'
      sudo yum install -y lwtools
    else
      echo '[WARN] No se encontró gestor de paquetes compatible'
      echo '       Instala lwtools manualmente desde: http://www.lwtools.ca/'
      echo '       El modo --dual no estará disponible hasta instalar lwasm'
    fi
  else
    echo '[WARN] Sistema operativo no reconocido para instalación automática'
    echo '       Instala lwtools manualmente desde: http://www.lwtools.ca/'
    echo '       El modo --dual no estará disponible hasta instalar lwasm'
  fi
else
  echo '[OK  ] lwasm encontrado en PATH'
fi

# Configurar variables de entorno
if [ "$NO_DEV_TOOLS" = false ]; then
  export VPY_IDE_DEVTOOLS=1
else
  unset VPY_IDE_DEVTOOLS
fi

if [ "$STRICT_CSP" = false ]; then
  export VPY_IDE_RELAX_CSP=1
else
  unset VPY_IDE_RELAX_CSP
fi

if [ "$NO_CLEAR" = true ]; then
  export VPY_IDE_NO_CLEAR=1
else
  unset VPY_IDE_NO_CLEAR
fi

if [ "$VERBOSE_LSP" = true ]; then
  export VPY_IDE_VERBOSE_LSP=1
else
  unset VPY_IDE_VERBOSE_LSP
fi

if [ "$ENABLE_TRACEBIN" = true ]; then
  export VPY_IDE_ENABLE_TRACEBIN=1
else
  unset VPY_IDE_VERBOSE_LSP
fi

# Función para instalar node_modules si es necesario
install_node_modules_if_missing() {
  local dir="$1"
  
  if [ ! -f "$dir/package.json" ]; then
    return
  fi
  
  if [ "$FAST" = true ] && [ -d "$dir/node_modules" ]; then
    return
  fi
  
  if [ ! -d "$dir/node_modules" ]; then
    echo "[INFO] npm install -> $dir"
    (cd "$dir" && npm install)
    if [ $? -ne 0 ]; then
      echo '[ERR ] npm install falló'
      exit 1
    fi
  fi
}

# Instalar dependencias
install_node_modules_if_missing "$ROOT/ide/frontend"
install_node_modules_if_missing "$ROOT/ide/electron"

# Build Rust compilers salvo --no-rust-build
# Siempre compilar en --release y copiar a ide/electron/resources/
# para garantizar que el IDE usa el binario más reciente del código fuente.
if [ "$NO_RUST_BUILD" = false ]; then
  if ! command -v cargo &> /dev/null; then
    echo '[WARN] cargo no encontrado; se omite build Rust'
  else
    RESOURCES_DIR="$ROOT/ide/electron/resources"

    # El workspace raíz incluye buildtools/* y core, por lo que ambos
    # binarios se generan en $ROOT/target/release/

    # 1. Build buildtools compiler (vpy_cli) — compilador principal
    echo '[INFO] cargo build --release (vpy_cli)'
    (cd "$ROOT" && cargo build --release --bin vpy_cli)
    if [ $? -ne 0 ]; then
      echo '[ERR ] cargo build (vpy_cli) falló'
      exit 1
    fi
    cp "$ROOT/target/release/vpy_cli" "$RESOURCES_DIR/vpy_cli"
    echo "[OK  ] vpy_cli copiado a $RESOURCES_DIR/"

    # 2. Build core compiler (vectrexc) — compilador legacy usado por el IDE
    echo '[INFO] cargo build --release (vectrexc)'
    (cd "$ROOT" && cargo build --release --bin vectrexc)
    if [ $? -ne 0 ]; then
      echo '[ERR ] cargo build (vectrexc) falló'
      exit 1
    fi
    cp "$ROOT/target/release/vectrexc" "$RESOURCES_DIR/vectrexc"
    echo "[OK  ] vectrexc copiado a $RESOURCES_DIR/"
  fi
fi

# Comprobar binario LSP esperado (heurística) y avisar si falta
LSP_BIN="$ROOT/target/debug/vpy_lsp"
if [ ! -f "$LSP_BIN" ]; then
  echo "[WARN] Binario LSP no encontrado en $LSP_BIN (spawn podría fallar)"
fi

echo '[INFO] Lanzando entorno Electron'

# Función helper para esperar a que el puerto esté abierto
wait_for_port() {
  local port=$1
  local max_attempts=60
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if lsof -i :$port >/dev/null 2>&1; then
      echo "[OK  ] Puerto $port está abierto"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.5
  done
  
  echo "[WARN] Puerto $port nunca se abrió (timeout después de $max_attempts intentos)"
  return 1
}

if [ "$PRODUCTION" = true ]; then
  echo '[INFO] Modo producción - sin hot reload'
  
  # Verificación de tipos TypeScript
  echo '[INFO] Verificando tipos TypeScript...'
  (cd "$ROOT/ide/frontend" && npm run typecheck)
  if [ $? -ne 0 ]; then
    echo '[ERR ] TypeScript typecheck falló - el código tiene errores de tipos'
    exit 1
  fi
  echo '[OK  ] TypeScript typecheck exitoso'
  
  # Asegurar que el frontend esté construido
  echo '[INFO] Construyendo frontend...'
  (cd "$ROOT/ide/frontend" && npm run build)
  if [ $? -ne 0 ]; then
    echo '[ERR ] Frontend build falló'
    exit 1
  fi
  # Ejecutar en modo producción
  (cd "$ROOT/ide/electron" && npm run start)
else
  echo '[INFO] Modo desarrollo - con hot reload'
  
  # Verificación de tipos TypeScript
  echo '[INFO] Verificando tipos TypeScript...'
  (cd "$ROOT/ide/frontend" && npm run typecheck)
  if [ $? -ne 0 ]; then
    echo '[ERR ] TypeScript typecheck falló - el código tiene errores de tipos'
    exit 1
  fi
  echo '[OK  ] TypeScript typecheck exitoso'
  
  if [ "$NO_CLEAR" = true ]; then
    export FORCE_COLOR=1
  fi
  
  # Arrancar Electron en background
  (cd "$ROOT/ide/electron" && npm run dev) &
  ELECTRON_PID=$!
  echo "[OK  ] Electron iniciado (PID: $ELECTRON_PID)"
  
  # Esperar a que el puerto 9123 esté abierto (IDE listo)
  echo '[INFO] Esperando a que el IDE esté listo...'
  wait_for_port 9123
  if [ $? -ne 0 ]; then
    echo '[ERR ] El IDE no se inició correctamente'
    kill $ELECTRON_PID 2>/dev/null || true
    exit 1
  fi
  
  # MCP server is now launched by VS Code extension, not by IDE
  # (Old auto-start disabled to avoid conflicts)
  # echo '[INFO] Iniciando servidor MCP...'
  # MCP_LOG_FILE="$ROOT/.mcp-server.log"
  # MCP_VERBOSE=1 node "$ROOT/ide/mcp-server/server.js" 2>&1 | tee -a "$MCP_LOG_FILE" | sed 's/^/[MCP Server] /' &
  # MCP_PID=$!
  # echo "[OK  ] Servidor MCP iniciado (PID: $MCP_PID)"
  # echo "[OK  ] Logs MCP escritos a: $MCP_LOG_FILE"
  
  # Trap para limpiar Electron al salir
  trap "kill $ELECTRON_PID 2>/dev/null || true" EXIT INT TERM
  
  # Esperar a que Electron termine
  wait $ELECTRON_PID
fi

exit $?
