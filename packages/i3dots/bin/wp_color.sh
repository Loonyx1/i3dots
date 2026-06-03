#!/usr/bin/env bash
# packages/i3dots/bin/wp_color.sh - Helper de origen de color para wallpapers (Backend)

# 1. Parseo de argumentos
W_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update) W_PATH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$W_PATH" ]] && { echo "Uso: wp_color.sh --update <ruta_wallpaper>" >&2; exit 1; }

# 2. Obtener rutas de estado del core y del paquete de forma dinámica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_PARENT="${SCRIPT_DIR%/*}"
PKG_NAME="${PKG_PARENT##*/}"
CUR_ENV="${CURRENT_ENV:-$PKG_NAME}"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR_VAL="${STATE_DIR:-$ROOT_DIR/core/state}"

WP_STATE_DIR="$STATE_DIR_VAL/$CUR_ENV/wallpaper"
mkdir -p "$WP_STATE_DIR"

FINAL_PATH=$(readlink -f "$W_PATH")
[[ ! -f "$FINAL_PATH" ]] && { echo "Error: Imagen '$W_PATH' no existe." >&2; exit 1; }

COLOR_SRC_PATH="$FINAL_PATH"

# 3. Leer configuraciones de estado de wallpapers
THUMB_MODE="enabled"
[[ -f "$WP_STATE_DIR/thumbnail_mode" ]] && THUMB_MODE=$(<"$WP_STATE_DIR/thumbnail_mode")
THUMB_MODE="${THUMB_MODE//[[:space:]]/}"

USE_THUMB="true"
[[ -f "$WP_STATE_DIR/matugen_use_thumb" ]] && USE_THUMB=$(<"$WP_STATE_DIR/matugen_use_thumb")
USE_THUMB="${USE_THUMB//[[:space:]]/}"

if [[ "$THUMB_MODE" == "enabled" && "$USE_THUMB" == "true" ]]; then
    THUMB_SIZE="450"
    [[ -f "$WP_STATE_DIR/thumbnail_size" ]] && THUMB_SIZE=$(<"$WP_STATE_DIR/thumbnail_size")
    THUMB_SIZE="${THUMB_SIZE//[[:space:]]/}"

    safe_name="${FINAL_PATH//\//_}"
    THUMB_PATH="$WP_STATE_DIR/thumbs/$THUMB_SIZE/${safe_name}.jpg"
    if [[ -f "$THUMB_PATH" ]]; then
        COLOR_SRC_PATH="$THUMB_PATH"
    fi
fi

# 4. Crear enlace simbólico de origen de color en el estado del wallpaper
ln -sf "$COLOR_SRC_PATH" "$WP_STATE_DIR/color_source"
exit 0
