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
ROFI_STYLE_STATE_FILE="$BAR_STATE_DIR/rofi_style"

# 1.5 Auto-detectar Hook de Barra y Consultar Metadatos
BAR_HOOK=""
for comp in $MANAGED_COMPONENTS; do
    if [[ "$comp" == *bar* ]]; then
        if [ -f "$HOOK_DIR/components/${comp}.sh" ]; then
            BAR_HOOK="$HOOK_DIR/components/${comp}.sh"
            break
        fi
    fi
done

if [ -z "$BAR_HOOK" ]; then
    for file in "$HOOK_DIR/components/"*bar*.sh; do
        if [ -f "$file" ]; then
            BAR_HOOK="$file"
            break
        fi
    done
fi

# Inicializar metadatos (fallbacks seguros)
BAR_THEMES_DIR=""
BAR_DEFAULT_TYPE="standard"
BAR_HEIGHT_OPTIONS="20px\n24px\n28px\n32px"
BAR_HEIGHT_UNIT="px"
BAR_HAS_MODES="false"
BAR_SUPPORTED_OPTIONS=""

# Si existe el hook, consultar capacidades
if [ -n "$BAR_HOOK" ] && [ -f "$BAR_HOOK" ]; then
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        case "$key" in
            themes_dir)      BAR_THEMES_DIR="$val" ;;
            default_theme)   BAR_DEFAULT_TYPE="$val" ;;
            height_options)  BAR_HEIGHT_OPTIONS="$val" ;;
            height_unit)     BAR_HEIGHT_UNIT="$val" ;;
            has_modes)       BAR_HAS_MODES="$val" ;;
            supported_options) BAR_SUPPORTED_OPTIONS="$val" ;;
        esac
    done < <(bash "$BAR_HOOK" --query 2>/dev/null)
fi

# 1.5.5 Helper Genérico para Mapeo de Flags Cortos a Keys Dinámicos
find_key_by_short_flag() {
    local flag="$1"
    if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            if [[ "$opt_key" == "$flag"* ]]; then
                echo "$opt_key"
                return 0
            fi
        done
    fi
    echo "$flag"
}

# 1.6 Configurar Selector de forma Genérica y Agnóstica
BAR_SEL_BIN="${BAR_SEL_BIN:-${WP_SEL_BIN:-rofi}}"

if [ -z "$BAR_SEL_PROMPT_FLAG" ]; then
    if [[ "$BAR_SEL_BIN" == *"wofi"* || "$BAR_SEL_BIN" == *"tofi"* ]]; then
        BAR_SEL_PROMPT_FLAG="--prompt"
    else
        BAR_SEL_PROMPT_FLAG="-p"
    fi
fi

if [ -z "$BAR_SEL_ARGS" ]; then
    if [[ "$BAR_SEL_BIN" == *"wofi"* || "$BAR_SEL_BIN" == *"tofi"* ]]; then
        BAR_SEL_ARGS="--dmenu"
    elif [[ "$BAR_SEL_BIN" == *"dmenu"* ]]; then
        BAR_SEL_ARGS=""
    else
        BAR_SEL_ARGS="-dmenu"
    fi
fi

read -ra BAR_ARGS_ARR <<< "$BAR_SEL_ARGS"

if [[ "$BAR_SEL_BIN" == *"rofi"* ]] && [ -n "$BAR_SEL_THEME" ] && [[ "$BAR_SEL_ARGS" != *"-theme"* ]]; then
    BAR_ARGS_ARR+=("-theme" "$BAR_SEL_THEME")
fi


# 2. Parseo de Argumentos
declare -A CLI_PARAMS
SEL_TYPE=""
SEL_HEIGHT=""
DO_NEXT=0
DO_PREV=0
DO_SELECT=0
DO_MANAGE=0
LIST_ALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
        -H|-h|--height) SEL_HEIGHT="$2"; shift 2 ;;
        --next)      DO_NEXT=1; shift ;;
        --prev)      DO_PREV=1; shift ;;
        --select)    DO_SELECT=1; shift ;;
        --manage)    DO_MANAGE=1; shift ;;
        -L|--list)   LIST_ALL=1; shift ;;
        -*)          
            flag="${1#--}"
            flag="${flag#-}"
            key=$(find_key_by_short_flag "$flag")
            CLI_PARAMS["$key"]="$2"
            shift 2
            ;;
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
        
        choice=$(echo -e "$rofi_options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Select Bar Preset")
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
        CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "$BAR_DEFAULT_TYPE")
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
    SEL_TYPE=""
    SEL_HEIGHT=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
            -H|-h|--height) SEL_HEIGHT="$2"; shift 2 ;;
            -*)
                flag="${1#--}"
                flag="${flag#-}"
                key=$(find_key_by_short_flag "$flag")
                CLI_PARAMS["$key"]="$2"
                shift 2
                ;;
            *) shift ;;
        esac
    done
    notify-send "Bar Style" "Aplicando: $NEW_NAME" -i display -t 1500
fi

# 3.5 Lógica de Gestión (Manage)
if [ "$DO_MANAGE" -eq 1 ]; then
    CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "$BAR_DEFAULT_TYPE")
    CUR_H=$(cat "$HEIGHT_STATE_FILE" 2>/dev/null || echo "$BAR_HEIGHT")
    
    options="Height: $CUR_H"
    
    # Parsear opciones dinámicas
    declare -A OPT_LABELS
    declare -A OPT_VALUES
    
    if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            OPT_LABELS["$opt_key"]="$opt_label"
            OPT_VALUES["$opt_key"]="$opt_vals"
            
            cur_val=$(cat "$BAR_STATE_DIR/$opt_key" 2>/dev/null | tr -d '[:space:]')
            if [ -z "$cur_val" ]; then
                cur_val=$(echo "$opt_vals" | cut -d',' -f1)
                echo "$cur_val" > "$BAR_STATE_DIR/$opt_key"
            fi
            
            options="$options\n$opt_label: $cur_val"
        done
    fi
    

    
    choice=$(echo -e "$options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Manage Bar: $CUR_TYPE")
    [[ -z "$choice" ]] && exit 0
    
    case "$choice" in
        Height:*)
            NEW_H=$(echo -e "$BAR_HEIGHT_OPTIONS\ncustom" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Select Height")
            if [ "$NEW_H" == "custom" ]; then
                NEW_H=$(echo "" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Enter Height (eg: 24$BAR_HEIGHT_UNIT)")
            fi
            [[ -n "$NEW_H" ]] && exec "$0" -h "$NEW_H"
            ;;

        *)
            choice_label=$(echo "$choice" | cut -d':' -f1 | xargs)
            for opt_key in "${!OPT_LABELS[@]}"; do
                if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
                    val_options=$(echo "${OPT_VALUES[$opt_key]}" | tr ',' '\n')
                    NEW_VAL=$(echo -e "$val_options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Select $choice_label")
                    if [ -n "$NEW_VAL" ]; then
                        exec "$0" --"$opt_key" "$NEW_VAL"
                    fi
                fi
            done
            ;;
    esac
    exit 0
fi

# 4. Listar (si se solicita)
if [ "$LIST_ALL" -eq 1 ]; then
    echo "Altura: (ej: 15pt, 20px)"
    echo "Modos: solid, underline"
    echo "Temas de Barra:"
    echo "  - $BAR_DEFAULT_TYPE"
    if [ -n "$BAR_THEMES_DIR" ] && [ -d "$BAR_THEMES_DIR" ]; then
        ls -1 "$BAR_THEMES_DIR" | sed 's/^/  - /'
    fi
    exit 0
fi

# 4. Selección Interactiva (si no se pasó nada)
ANY_CLI_PARAM=0
for key in "${!CLI_PARAMS[@]}"; do
    ANY_CLI_PARAM=1
    break
done

if [ -z "$SEL_TYPE" ] && [ -z "$SEL_HEIGHT" ] && [ "$ANY_CLI_PARAM" -eq 0 ]; then
    options="Height: custom"
    
    declare -A OPT_LABELS
    declare -A OPT_VALUES
    if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            OPT_LABELS["$opt_key"]="$opt_label"
            OPT_VALUES["$opt_key"]="$opt_vals"
            
            IFS=',' read -ra VALS_ARR <<< "$opt_vals"
            for val in "${VALS_ARR[@]}"; do
                options="$options\n$opt_label: $val"
            done
        done
    fi
    

    
    if [ -n "$BAR_THEMES_DIR" ] && [ -d "$BAR_THEMES_DIR" ]; then
        for theme in $(ls -1 "$BAR_THEMES_DIR"); do
            options+="\nTheme: $theme"
        done
    fi
    
    choice=$(echo -e "$options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Bar Config")
    [[ -z "$choice" ]] && exit 0

    if [[ "$choice" == Theme:* ]]; then
        SEL_TYPE="${choice#Theme: }"
    elif [[ "$choice" == "Height: custom" ]]; then
        SEL_HEIGHT=$(echo "" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Enter Height (eg: 24$BAR_HEIGHT_UNIT)")
        [[ -z "$SEL_HEIGHT" ]] && exit 0

    else
        choice_label=$(echo "$choice" | cut -d':' -f1 | xargs)
        choice_val=$(echo "$choice" | cut -d':' -f2 | xargs)
        for opt_key in "${!OPT_LABELS[@]}"; do
            if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
                CLI_PARAMS["$opt_key"]="$choice_val"
            fi
        done
    fi
fi

# 5. Validar y Guardar con Aislamiento por Tema
[ -n "$SEL_TYPE" ] && echo "$SEL_TYPE" > "$TYPE_STATE_FILE"
CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "$BAR_DEFAULT_TYPE")

THEME_HEIGHT_FILE="$BAR_STATE_DIR/height_$CUR_TYPE"
if [ -n "$SEL_HEIGHT" ]; then
    echo "$SEL_HEIGHT" > "$THEME_HEIGHT_FILE"
    echo "$SEL_HEIGHT" > "$HEIGHT_STATE_FILE"
else
    SAVED_HEIGHT=$(cat "$THEME_HEIGHT_FILE" 2>/dev/null)
    if [ -n "$SAVED_HEIGHT" ]; then
        echo "$SAVED_HEIGHT" > "$HEIGHT_STATE_FILE"
    else
        echo "${BAR_HEIGHT:-15pt}" > "$THEME_HEIGHT_FILE"
        echo "${BAR_HEIGHT:-15pt}" > "$HEIGHT_STATE_FILE"
    fi
fi

# Guardar y sincronizar todas las opciones dinámicas declaradas
if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
    IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
    for opt in "${OPT_ARRAY[@]}"; do
        IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
        
        STATE_FILE="$BAR_STATE_DIR/$opt_key"
        THEME_STATE_FILE="$BAR_STATE_DIR/${opt_key}_$CUR_TYPE"
        
        if [ -n "${CLI_PARAMS[$opt_key]}" ]; then
            val="${CLI_PARAMS[$opt_key]}"
            echo "$val" > "$THEME_STATE_FILE"
            echo "$val" > "$STATE_FILE"
        else
            saved_theme_val=$(cat "$THEME_STATE_FILE" 2>/dev/null | tr -d '[:space:]')
            if [ -n "$saved_theme_val" ]; then
                echo "$saved_theme_val" > "$STATE_FILE"
            else
                saved_gen_val=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')
                if [ -n "$saved_gen_val" ]; then
                    echo "$saved_gen_val" > "$THEME_STATE_FILE"
                else
                    fallback_val=$(echo "$opt_vals" | cut -d',' -f1)
                    echo "$fallback_val" > "$THEME_STATE_FILE"
                    echo "$fallback_val" > "$STATE_FILE"
                fi
            fi
        fi
    done
fi



# 7. Aplicar cambios
"$BIN_DIR/apply_dots.sh"

