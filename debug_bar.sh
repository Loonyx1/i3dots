#!/usr/bin/env bash

# Script para cambiar la barra con logs detallados
# Ubicación: ~/i3dots/debug_bar.sh

LOG_FILE="/tmp/i3dots_debug.log"
MAIN_LOG="/tmp/i3dots.log"

# Limpiar logs previos
echo "=== DEBUG BAR SWITCH - $(date) ===" > "$LOG_FILE"
echo "=== INICIO DE SESIÓN DEBUG ===" >> "$MAIN_LOG"

log() {
    local msg="[$(date +%T.%N)] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

# 1. Detectar Entorno
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/packages/i3dots"

if [ -f "$PACKAGE_DIR/.current_variant" ]; then
    ENV_NAME=$(cat "$PACKAGE_DIR/.current_variant")
else
    # Autodetección si no se ha instalado
    if [ -f /etc/void-release ]; then
        ENV_NAME="void"
    else
        ENV_NAME="debian" # Default
    fi
fi

log "Entorno detectado: $ENV_NAME"

# 2. Configurar Variables de Entorno (Simulando el cargador 'dots')
export CURRENT_ENV="$ENV_NAME"
export STATE_DIR="$SCRIPT_DIR/core/state"
export BIN_DIR="$SCRIPT_DIR/core/bin"
export HOOK_DIR="$PACKAGE_DIR/hooks"
export I3_CONFIG_DIR="$HOME/.config/i3"

# Cargar config principal
if [ -f "$PACKAGE_DIR/config.env" ]; then
    source "$PACKAGE_DIR/config.env"
    log "Configuracion cargada de $PACKAGE_DIR/config.env"
else
    log "ERROR: No se encuentra config.env en $PACKAGE_DIR"
    exit 1
fi

# 3. Ejecutar Selector
log "Abriendo selector (rofi)..."
bash "$BIN_DIR/engine_bar.sh" --select

log "engine_bar.sh ha finalizado la ejecucion."
log "Verifica los logs detallados en: $LOG_FILE"
log "Logs internos del sistema en: $MAIN_LOG"

# Mostrar resumen de tiempos si el log principal tiene datos
echo ""
echo "Resumen de tiempos de /tmp/i3dots.log:"
grep -E "engine_bar|apply_dots|polybar.sh|launch.sh" "$MAIN_LOG" | tail -n 15
