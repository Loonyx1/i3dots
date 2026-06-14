#!/usr/bin/env bash
# packages/i3dots/bin/wp_seq.sh - Rofi Script Mode sin standby de Bash para Wallpaper y Secuencia

# 1. Cargar entorno y lógica compartida
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"
source "$ROOT_DIR/packages/i3dots/config.env"

# Exportar variables necesarias para el core/bin
export CURRENT_ENV="$CUR_ENV"
export PACKAGE_DIR="$ROOT_DIR/packages/$CURRENT_ENV"
export PATH="$PACKAGE_DIR/bin:$ROOT_DIR/core/bin:$PATH"

# Rofi options
SEL_BIN="${WP_SEL_BIN:-rofi}"
LAUNCHER_THEME="$WALL_SEL_THEME"
SEL_STYLE="$WP_SEL_STYLE"

# 2. Control de Flujo Rofi
if [[ -z "$ROFI_LIST_MODE" && $# -eq 0 ]]; then
    # Fase 1: Lanzar Rofi (reemplaza proceso actual)
    export ROFI_LIST_MODE=1
    eval exec "\"$SEL_BIN\"" -show Wallpaper -modi "\"Wallpaper:$SCRIPT_DIR/wp_seq.sh\"" -theme "\"$LAUNCHER_THEME\"" "$SEL_STYLE"

elif [[ "$ROFI_LIST_MODE" -eq 1 && $# -eq 0 ]]; then
    # Fase 2: Rofi solicita lista (stdout)
    wallpapers_found=$(list_wallpapers)
    [[ -z "$wallpapers_found" ]] && exit 0

    out=""
    wallpapers_to_gen=""
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        real_file=$(readlink -f "$file")
        
        if [[ "$THUMB_MODE" == "enabled" ]]; then
            get_thumb_path "$real_file"
            thumb="$RET_THUMB"
            if [[ -f "$thumb" && "$real_file" -ot "$thumb" ]]; then
                thumb_to_use="$thumb"
            else
                wallpapers_to_gen+="$real_file"$'\n'
                if [[ "$NO_THUMB_MODE" == "original" ]]; then
                    thumb_to_use="$real_file"
                else
                    thumb_to_use="image-x-generic"
                fi
            fi
        else
            thumb_to_use="$real_file"
        fi
        out+="${file##*/}\x00icon\x1f${thumb_to_use}"$'\n'
    done <<< "$wallpapers_found"

    # Lanzar pre-caché async de fondo si es necesario
    if [[ "$THUMB_MODE" == "enabled" ]] && [[ "$BG_GENERATION" == "true" ]] && [[ -n "$wallpapers_to_gen" ]]; then
        (echo -ne "$wallpapers_to_gen" | wp_cache.sh --bg-gen >/dev/null 2>&1) &
    fi

    echo -ne "$out"
    exit 0
else
    # Fase 3: Rofi devuelve selección ($1)
    SELECTION="$1"
    [[ -z "$SELECTION" ]] && exit 1

    # Resolver ruta
    FINAL_PATH=""
    if [[ -f "$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$SELECTION")
    elif [[ -f "$WALLPAPER_DIR/$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$WALLPAPER_DIR/$SELECTION")
    else
        FINAL_PATH="$SELECTION"
    fi

    # Guardar color source
    color_src="$FINAL_PATH"
    if [[ "$THUMB_MODE" == "enabled" && "$MATUGEN_USE_THUMB" == "true" ]]; then
        get_thumb_path "$FINAL_PATH"
        [[ -f "$RET_THUMB" ]] && color_src="$RET_THUMB"
    fi
    ln -sf "$color_src" "$WP_STATE_DIR/color_source"

    # Aplicar wallpaper y recargar secuencia en segundo plano (cierre inmediato de Rofi)
    (
        wp_select.sh -C "$FINAL_PATH"
        (polybar-msg cmd hide ; pkill -u $UID -x polybar) &>/dev/null &
        engine_matugen.sh -D -T scheme-fidelity -P saturation
        apply_dots.sh
    ) &>/dev/null &
    exit 0
fi
