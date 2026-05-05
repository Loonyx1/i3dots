#!/usr/bin/env bash

# engine_bar.sh - Motor de gestión de barras (Polybar/Waybar)
# Permite cambiar entre tipos de barra y estilos (bordes)

# 1. Cargar Estado y Config
[ -z "$CURRENT_ENV" ] && { echo "Error: CURRENT_ENV no definido." >&2; exit 1; }
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
mkdir -p "$BAR_STATE_DIR"
STYLE_STATE_FILE="$BAR_STATE_DIR/style"
TYPE_STATE_FILE="$BAR_STATE_DIR/type"
POS_STATE_FILE="$BAR_STATE_DIR/position"
TRANS_STATE_FILE="$BAR_STATE_DIR/transparency"
HEIGHT_STATE_FILE="$BAR_STATE_DIR/height"
MODE_STATE_FILE="$BAR_STATE_DIR/mode"

# 2. Parseo de Argumentos
SEL_STYLE=""
SEL_TYPE=""
SEL_POS=""
SEL_TRANS=""
SEL_HEIGHT=""
SEL_MODE=""
DO_NEXT=0
DO_PREV=0
DO_SELECT=0
LIST_ALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--style)  SEL_STYLE="$2"; shift 2 ;;
        -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
        -p|--pos)    SEL_POS="$2"; shift 2 ;;
        -t|--trans)  SEL_TRANS="$2"; shift 2 ;;
        -H|--height) SEL_HEIGHT="$2"; shift 2 ;;
        -m|--mode)   SEL_MODE="$2"; shift 2 ;;
        --next)      DO_NEXT=1; shift ;;
        --prev)      DO_PREV=1; shift ;;
        --select)    DO_SELECT=1; shift ;;
        -L|--list)   LIST_ALL=1; shift ;;
        *) shift ;;
    esac
done

# 3. Lógica de Selección (Next/Prev/Select)
if [ "$DO_NEXT" -eq 1 ] || [ "$DO_PREV" -eq 1 ] || [ "$DO_SELECT" -eq 1 ]; then
    if [ -z "$BAR_PRESETS" ]; then
        echo "Error: BAR_PRESETS no definido en config.env" >&2
        exit 1
    fi

    IFS='|' read -ra PRESET_ARRAY <<< "$BAR_PRESETS"
    TOTAL_PRESETS=${#PRESET_ARRAY[@]}
    
    SELECTED_PRESET=""

    if [ "$DO_SELECT" -eq 1 ]; then
        # Generar lista para Rofi
        rofi_options=""
        for preset in "${PRESET_ARRAY[@]}"; do
            name=$(echo "$preset" | cut -d':' -f1 | xargs)
            rofi_options+="$name\n"
        done
        
        SEL_BIN="${WP_SEL_BIN:-rofi}"
        if [[ "$SEL_BIN" == *"rofi"* ]]; then
            # Usar el tema específico si está definido, sino caer en dmenu genérico
            if [ -n "$BAR_SEL_THEME" ]; then
                SEL_ARGS=("-dmenu" "-p" "Select Bar Preset" "-theme" "$BAR_SEL_THEME")
            else
                SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Select Bar Preset"})
            fi
        else
            SEL_ARGS=("-dmenu" "-p" "Select Bar Preset")
        fi
        
        choice=$(echo -e "$rofi_options" | "$SEL_BIN" "${SEL_ARGS[@]}")
        [[ -z "$choice" ]] && exit 0
        
        # Encontrar el preset que coincide con la elección
        for preset in "${PRESET_ARRAY[@]}"; do
            name=$(echo "$preset" | cut -d':' -f1 | xargs)
            if [ "$name" == "$choice" ]; then
                SELECTED_PRESET="$preset"
                break
            fi
        done
    else
        # Lógica de Ciclo (Next/Prev)
        CURRENT_INDEX=-1
        CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "polybar_antigua")
        CUR_MODE=$(cat "$MODE_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "solid")

        for i in "${!PRESET_ARRAY[@]}"; do
            preset_cmd=$(echo "${PRESET_ARRAY[$i]}" | cut -d':' -f2)
            if [[ "$preset_cmd" == *"$CUR_TYPE"* ]] && [[ "$preset_cmd" == *"$CUR_MODE"* ]]; then
                CURRENT_INDEX=$i
                break
            fi
        done

        if [ "$DO_NEXT" -eq 1 ]; then
            NEW_INDEX=$(( (CURRENT_INDEX + 1) % TOTAL_PRESETS ))
        else
            NEW_INDEX=$(( (CURRENT_INDEX - 1 + TOTAL_PRESETS) % TOTAL_PRESETS ))
        fi
        SELECTED_PRESET="${PRESET_ARRAY[$NEW_INDEX]}"
    fi

    [[ -z "$SELECTED_PRESET" ]] && exit 0

    # Extraer flags y re-parsear
    NEW_PRESET_CMD=$(echo "$SELECTED_PRESET" | cut -d':' -f2)
    NEW_NAME=$(echo "$SELECTED_PRESET" | cut -d':' -f1 | xargs)

    set -- $NEW_PRESET_CMD
    SEL_STYLE=""; SEL_TYPE=""; SEL_POS=""; SEL_TRANS=""; SEL_HEIGHT=""; SEL_MODE=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--style)  SEL_STYLE="$2"; shift 2 ;;
            -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
            -p|--pos)    SEL_POS="$2"; shift 2 ;;
            -t|--trans)  SEL_TRANS="$2"; shift 2 ;;
            -H|--height) SEL_HEIGHT="$2"; shift 2 ;;
            -m|--mode)   SEL_MODE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    notify-send "Bar Style" "Aplicando: $NEW_NAME" -i display -t 1500
fi

# 4. Listar (si se solicita)
if [ "$LIST_ALL" -eq 1 ]; then
    echo "Estilos disponibles: round, square"
    echo "Posiciones: top, bottom"
    echo "Transparencia: true, false"
    echo "Altura: (ej: 15pt, 20px)"
    echo "Modos: solid, underline"
    echo "Temas de Barra:"
    echo "  - polybar_antigua"
    if [ -d "$PACKAGE_DIR/dotfiles/polybar_configs" ]; then
        ls -1 "$PACKAGE_DIR/dotfiles/polybar_configs" | sed 's/^/  - /'
    fi
    exit 0
fi

# 4. Selección Interactiva (si no se pasó nada)
if [ -z "$SEL_STYLE" ] && [ -z "$SEL_TYPE" ] && [ -z "$SEL_POS" ] && [ -z "$SEL_TRANS" ] && [ -z "$SEL_HEIGHT" ]; then
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Bar Config"})
    elif [[ "$SEL_BIN" == *"wofi"* ]]; then
        SEL_ARGS=("--dmenu" "--prompt" "Bar Config")
    else
        SEL_ARGS=("-dmenu")
    fi
    
    # Generar opciones dinámicas
    options="Style: round\nStyle: square\nPos: top\nPos: bottom\nTrans: true\nTrans: false\nMode: solid\nMode: underline\nHeight: custom"
    if [ -d "$PACKAGE_DIR/dotfiles/polybar_configs" ]; then
        for theme in $(ls -1 "$PACKAGE_DIR/dotfiles/polybar_configs"); do
            options+="\nTheme: $theme"
        done
    fi
    
    # Menú Principal de Configuración de Barra
    choice=$(echo -e "$options" | "$SEL_BIN" "${SEL_ARGS[@]}")
    
    [[ -z "$choice" ]] && exit 0

    if [[ "$choice" == Style:* ]]; then
        SEL_STYLE="${choice#Style: }"
    elif [[ "$choice" == Pos:* ]]; then
        SEL_POS="${choice#Pos: }"
    elif [[ "$choice" == Trans:* ]]; then
        SEL_TRANS="${choice#Trans: }"
    elif [[ "$choice" == Mode:* ]]; then
        SEL_MODE="${choice#Mode: }"
    elif [[ "$choice" == Theme:* ]]; then
        SEL_TYPE="${choice#Theme: }"
    elif [[ "$choice" == "Height: custom" ]]; then
        # Pedir altura personalizada
        if [[ "$SEL_BIN" == *"rofi"* ]]; then
            SEL_HEIGHT=$(echo "" | rofi -dmenu -p "Enter Height (eg: 15pt)")
        else
            SEL_HEIGHT=$(echo "" | "$SEL_BIN" -dmenu -p "Enter Height")
        fi
        [[ -z "$SEL_HEIGHT" ]] && exit 0
    fi
fi

# 5. Validar y Guardar
[ -n "$SEL_STYLE" ] && echo "$SEL_STYLE" > "$STYLE_STATE_FILE"
[ -n "$SEL_TYPE" ] && echo "$SEL_TYPE" > "$TYPE_STATE_FILE"
[ -n "$SEL_POS" ] && echo "$SEL_POS" > "$POS_STATE_FILE"
[ -n "$SEL_TRANS" ] && echo "$SEL_TRANS" > "$TRANS_STATE_FILE"
[ -n "$SEL_HEIGHT" ] && echo "$SEL_HEIGHT" > "$HEIGHT_STATE_FILE"
[ -n "$SEL_MODE" ] && echo "$SEL_MODE" > "$MODE_STATE_FILE"

# 7. Aplicar cambios
"$BIN_DIR/apply_dots.sh"
