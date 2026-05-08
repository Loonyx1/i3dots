#!/usr/bin/env bash

# fix_paths.sh - Corrige rutas del proyecto i3dots
# Detecta ubicación actual y actualiza configs

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_BIN="$PROJECT_ROOT/dots"

echo "Detectada raíz: $PROJECT_ROOT"

# 1. Corregir vars.generated
VARS_FILE="$PROJECT_ROOT/packages/i3dots/dotfiles/i3/conf.d/vars.generated"
echo "Actualizando $VARS_FILE..."
echo "set \$dots_cmd $DOTS_BIN" > "$VARS_FILE"

# 2. Corregir keybinds.conf (usar variable en lugar de ruta hardcoded)
KEYBINDS_FILE="$PROJECT_ROOT/packages/i3dots/dotfiles/i3/conf.d/keybinds.conf"
echo "Actualizando $KEYBINDS_FILE..."
sed -i "s|exec /home/[^/]*/i3dots/dots|exec \$dots_cmd|g" "$KEYBINDS_FILE"

# 3. Forzar reinstalación de enlaces
echo "Re-enlazando configuraciones..."
mkdir -p ~/.config/i3
ln -sf "$PROJECT_ROOT/packages/i3dots/dotfiles/i3/config" ~/.config/i3/config
ln -sfT "$PROJECT_ROOT/packages/i3dots/dotfiles/i3/conf.d" ~/.config/i3/conf.d

# 4. Cargar entorno y aplicar
export CURRENT_ENV="i3dots"
export PACKAGE_DIR="$PROJECT_ROOT/packages/i3dots"
export STATE_DIR="$PROJECT_ROOT/core/state"
export BIN_DIR="$PROJECT_ROOT/core/bin"
export HOOK_DIR="$PACKAGE_DIR/hooks"

source "$PACKAGE_DIR/config.env"
"$BIN_DIR/apply_dots.sh"

echo "Listo. Prueba $mod+w ahora."
