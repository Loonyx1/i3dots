#!/usr/bin/env bash
# packages/i3dots/bin/wp_shared.sh - Entorno y funciones compartidas para Wallpaper Helpers

# 1. Configurar Directorios Base de forma dinámica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_PARENT="${SCRIPT_DIR%/*}"
PKG_NAME="${PKG_PARENT##*/}"
CUR_ENV="${CURRENT_ENV:-$PKG_NAME}"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR_VAL="${STATE_DIR:-$ROOT_DIR/core/state}"
WP_STATE_DIR="$STATE_DIR_VAL/$CUR_ENV/wallpaper"
[[ -d "$WP_STATE_DIR" ]] || mkdir -p "$WP_STATE_DIR"

# Directorio de origen de wallpapers
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wall}"

# 2. Cargar/Recargar variables de configuración
load_wp_config() {
    THUMB_MODE="enabled"
    [[ -f "$WP_STATE_DIR/thumbnail_mode" ]] && THUMB_MODE=$(<"$WP_STATE_DIR/thumbnail_mode")
    THUMB_MODE="${THUMB_MODE//[[:space:]]/}"

    THUMB_SIZE="450"
    [[ -f "$WP_STATE_DIR/thumbnail_size" ]] && THUMB_SIZE=$(<"$WP_STATE_DIR/thumbnail_size")
    THUMB_SIZE="${THUMB_SIZE//[[:space:]]/}"

    NO_THUMB_MODE="original"
    [[ -f "$WP_STATE_DIR/no_thumb_mode" ]] && NO_THUMB_MODE=$(<"$WP_STATE_DIR/no_thumb_mode")
    NO_THUMB_MODE="${NO_THUMB_MODE//[[:space:]]/}"

    BG_GENERATION="true"
    [[ -f "$WP_STATE_DIR/bg_generation" ]] && BG_GENERATION=$(<"$WP_STATE_DIR/bg_generation")
    BG_GENERATION="${BG_GENERATION//[[:space:]]/}"

    MATUGEN_USE_THUMB="true"
    [[ -f "$WP_STATE_DIR/matugen_use_thumb" ]] && MATUGEN_USE_THUMB=$(<"$WP_STATE_DIR/matugen_use_thumb")
    MATUGEN_USE_THUMB="${MATUGEN_USE_THUMB//[[:space:]]/}"

    THUMB_DIR="$WP_STATE_DIR/thumbs/$THUMB_SIZE"
}

# Inicializar configuración
load_wp_config

# 3. Detectar Dependencia de libvips
HAS_VIPS=0
command -v vipsthumbnail &>/dev/null && HAS_VIPS=1

# 4. Helper para obtener ruta física de miniatura
# Retorna en variable global RET_THUMB para evitar subshells $(...)
get_thumb_path() {
    local real_file="$1"
    local safe_name="${real_file//\//_}"
    RET_THUMB="$WP_STATE_DIR/thumbs/$THUMB_SIZE/${safe_name}.jpg"
}

list_wallpapers() {
    find -L "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort
}

