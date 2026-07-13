#!/usr/bin/env bash
# packages/i3dots/bin/wp_context_menu.sh - Wrapper seguro para el menú contextual del gestor de archivos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Cargar el modo activo del estado de i3dots
active_mode=$(source "$HOME/.config/i3dots/state.env" 2>/dev/null && echo "$active_mode" || echo "dark")

# Ejecutar dots preservando el escape de espacios y caracteres en la ruta
exec "$PROJECT_ROOT/dots" i3dots wp_seq.sh --mode-"$active_mode" "$1"
