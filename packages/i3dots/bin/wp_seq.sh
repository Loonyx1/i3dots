#!/usr/bin/env bash
# packages/i3dots/bin/wp_seq.sh - Selector de Wallpapers con temas integrados y optimizado

# 1. Cargar entorno y lógica compartida
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"

# Nombres de las pestañas/botones superiores (Fácil edición aquí)
L_DARK="Modo Oscuro"
L_LIGHT="Claro"
L_CENTER="Centro Oscuro"

# 2. Control de Flujo Rofi
if [[ $# -eq 0 ]]; then
    # Fase 1: Lanzar Rofi (arranque inicial)
    active_mode="dark"
    [[ -f "$WP_STATE_DIR/active_mode" ]] && active_mode=$(<"$WP_STATE_DIR/active_mode")

    show_mode="$L_DARK"
    [[ "$active_mode" == "light" ]] && show_mode="$L_LIGHT"
    [[ "$active_mode" == "center" ]] && show_mode="$L_CENTER"

    export ROFI_LIST_MODE=1
    # Se usa exec directo sin eval para evitar fallos de parsing de espacios en los nombres
    exec rofi -show "$show_mode" \
        -modi "$L_DARK:$0 --mode-dark,$L_LIGHT:$0 --mode-light,$L_CENTER:$0 --mode-center" \
        -theme "$WALL_SEL_THEME" \
        -theme-str 'element-icon{size:450px;} element-text{horizontal-align:0.5;}'

elif [[ $# -eq 1 ]]; then
    # Fase 2: Rofi solicita lista (stdout)
    generate_rofi_list '%f\x00icon\x1f%p'
    exit 0

elif [[ $# -eq 2 ]]; then
    # Fase 3: Rofi devuelve selección ($2) y modo ($1)
    MODE_FLAG="$1"
    SELECTION="$2"
    [[ -z "$SELECTION" ]] && exit 1

    # Registrar el modo seleccionado
    case "$MODE_FLAG" in
        "--mode-dark")   ACTIVE_MODE="dark"   ;;
        "--mode-light")  ACTIVE_MODE="light"  ;;
        "--mode-center") ACTIVE_MODE="center" ;;
        *)               ACTIVE_MODE="dark"   ;;
    esac
    echo "$ACTIVE_MODE" > "$WP_STATE_DIR/active_mode"

    # Resolver ruta absoluta del wallpaper
    [[ -f "$SELECTION" ]] && FINAL_PATH="$SELECTION" || FINAL_PATH="$WALLPAPER_DIR/$SELECTION"
    FINAL_PATH=$(readlink -f "$FINAL_PATH")

    # Guardar color source (con optimización de miniatura si está activa)
    [[ "$THUMB_MODE" == "enabled" && "$MATUGEN_USE_THUMB" == "true" ]] && get_thumb_path "$FINAL_PATH" && color_src="$RET_THUMB" || color_src="$FINAL_PATH"
    ln -sf "$color_src" "$WP_STATE_DIR/color_source"

    # Aplicar wallpaper y recargar secuencia en segundo plano (cierre inmediato de Rofi)
    (
        wp_select.sh -C "$FINAL_PATH"
        (polybar-msg cmd hide ; pkill -u $UID -x polybar) &>/dev/null &
        
        if [[ "$ACTIVE_MODE" == "light" ]]; then
            engine_matugen.sh -m light --source-color-index 0
        elif [[ "$ACTIVE_MODE" == "center" ]]; then
            engine_matugen.sh -m dark --source-color-index 1
        else
            engine_matugen.sh -m dark --source-color-index 0
        fi
        
        apply_dots.sh
    ) &>/dev/null &
    exit 0
fi
