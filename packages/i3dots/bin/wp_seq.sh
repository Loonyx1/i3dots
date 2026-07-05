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

    show_names_mode=$(get_state "show_names_mode" "all")
    card_style=$(get_state "card_style" "false")
    join_text=$(get_state "join_text" "false")
    
    ind_text=$(get_state "ind_text" "true")
    ind_block=$(get_state "ind_block" "false")
    ind_border=$(get_state "ind_border" "false")
    ind_underline=$(get_state "ind_underline" "false")
    ind_halo=$(get_state "ind_halo" "false")

    # Mapear los indicadores visuales activos a estilos CSS para Rofi
    icon_size_css="element-icon{size:450px;}"
    indicator_css=""

    if [[ "$ind_text" == "true" ]]; then
        indicator_css+="element selected{text-color:var(selected);} element-text selected{background-color:transparent;text-color:var(selected);} "
    fi
    if [[ "$ind_block" == "true" ]]; then
        indicator_css+="element-text selected{background-color:var(selected);text-color:var(background);border-radius:0px;padding:4px 8px;} "
    fi
    # Combinación inteligente de bordes (para evitar colisión de propiedades CSS)
    border_width=""
    if [[ "$ind_border" == "true" && "$ind_underline" == "true" ]]; then
        border_width="3px 3px 6px 3px"
    elif [[ "$ind_border" == "true" ]]; then
        border_width="3px"
    elif [[ "$ind_underline" == "true" ]]; then
        border_width="0px 0px 6px 0px"
    fi

    if [[ -n "$border_width" ]]; then
        indicator_css+="element selected{border:$border_width;border-color:var(selected);"
        if [[ "$ind_underline" == "true" ]]; then
            indicator_css+="text-color:var(selected);"
        fi
        indicator_css+="} "
    fi

    if [[ "$ind_halo" == "true" ]]; then
        indicator_css+="element selected{background-color:var(selected-neutral);text-color:var(selected);} "
    fi

    names_css=""
    case "$show_names_mode" in
        "all")
            names_css="element-text{enabled:true;text-color:inherit;} "
            ;;
        "selected")
            names_css="element-text{enabled:true;text-color:transparent;} element-text selected{enabled:true;} "
            ;;
        "disabled")
            names_css="element-text{enabled:false;} element-text selected{enabled:false;} "
            ;;
    esac

    card_css=""
    if [[ "$card_style" == "true" ]]; then
        card_css="element{background-color:rgba(255,255,255,0.02);border:1px;border-color:rgba(255,255,255,0.05);border-radius:12px;padding:12px;} element normal.normal{background-color:rgba(255,255,255,0.02);} element alternate.normal{background-color:rgba(255,255,255,0.02);} element selected{background-color:rgba(255,255,255,0.08);border-radius:12px;} element selected.normal{background-color:rgba(255,255,255,0.08);} "
    fi

    join_css=""
    if [[ "$join_text" == "true" ]]; then
        join_css="element{spacing:0px;padding:0px;} element-text{padding:8px 4px;margin:0px;} "
        if [[ "$card_style" == "true" ]]; then
            join_css+="element-text selected{background-color:rgba(255,255,255,0.08);text-color:var(selected);} "
        else
            join_css+="element-text selected{background-color:rgba(255,255,255,0.05);text-color:var(selected);} "
        fi
    fi

    export ROFI_LIST_MODE=1
    # Se usa exec directo sin eval para evitar fallos de parsing de espacios en los nombres
    exec rofi -show "$show_mode" \
        -modi "$L_DARK:$0 --mode-dark,$L_LIGHT:$0 --mode-light,$L_CENTER:$0 --mode-center" \
        -theme "$WALL_SEL_THEME" \
        -theme-str "$icon_size_css element-text{horizontal-align:0.5;} $card_css $join_css $names_css $indicator_css"

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
    save_state "active_mode" "$ACTIVE_MODE"

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
