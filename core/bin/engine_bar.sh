#!/usr/bin/env bash

# engine_bar.sh - Motor de gestión de barras genérico (Polybar/Waybar/etc)

# 1. Cargar Estado y Config
[ -z "$CURRENT_ENV" ] && { echo "Error: CURRENT_ENV no definido." >&2; exit 1; }
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
mkdir -p "$BAR_STATE_DIR"

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
BAR_DEFAULT_TYPE="${BAR_DEFAULT_TYPE:-standard}"
BAR_SUPPORTED_OPTIONS=""
PRIMARY_KEY="type" # Fallback por defecto

# Si existe el hook, consultar capacidades
if [ -n "$BAR_HOOK" ] && [ -f "$BAR_HOOK" ]; then
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        case "$key" in
            themes_dir)      BAR_THEMES_DIR="$val" ;;
            default_theme)   BAR_DEFAULT_TYPE="$val" ;;
            primary_key)     PRIMARY_KEY="$val" ;;
            supported_options) BAR_SUPPORTED_OPTIONS="$val" ;;
        esac
    done < <(bash "$BAR_HOOK" --query 2>/dev/null)
    export BAR_DEFAULT_TYPE
fi

TYPE_STATE_FILE="$BAR_STATE_DIR/$PRIMARY_KEY"

# 1.5.5 Helper Genérico para Mapeo de Flags Cortos a Keys Dinámicos
find_key_by_short_flag() {
    local flag="$1"
    
    # Mapeo universal de barra a la clave primaria
    if [[ "$flag" == "b" || "$flag" == "bar" ]]; then
        echo "$PRIMARY_KEY"
        return 0
    fi
    
    # Match dinámico por prefijo
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

get_default_option_val() {
    local target_key="$1"
    local fallback="$2"
    if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            if [ "$opt_key" == "$target_key" ]; then
                echo "$opt_vals" | cut -d',' -f1
                return 0
            fi
        done
    fi
    echo "$fallback"
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
DO_NEXT=0
DO_PREV=0
DO_SELECT=0
DO_MANAGE=0
LIST_ALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
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

# Función genérica de comparación de Preset
check_preset_match() {
    local preset_cmd="$1"
    local -A PRESET_PARAMS
    eval "local args=($preset_cmd)"
    
    local idx=0
    while [ $idx -lt ${#args[@]} ]; do
        local arg="${args[$idx]}"
        local val="${args[$((idx+1))]}"
        local flag="${arg#--}"
        flag="${flag#-}"
        local key=$(find_key_by_short_flag "$flag")
        PRESET_PARAMS["$key"]="$val"
        idx=$((idx+2))
    done
    
    for key in "${!PRESET_PARAMS[@]}"; do
        local expected_val="${PRESET_PARAMS[$key]}"
        local current_val=$(cat "$BAR_STATE_DIR/$key" 2>/dev/null | tr -d '[:space:]')
        if [ -z "$current_val" ]; then
            if [ "$key" == "$PRIMARY_KEY" ]; then
                current_val="$BAR_DEFAULT_TYPE"
            else
                current_val=$(get_default_option_val "$key" "")
            fi
        fi
        if [ "$expected_val" != "$current_val" ]; then
            return 1
        fi
    done
    return 0
}

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

        for i in "${!PRESET_ARRAY[@]}"; do
            preset_cmd=$(echo "${PRESET_ARRAY[$i]}" | cut -d':' -f2)
            if check_preset_match "$preset_cmd"; then
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
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--bar)    SEL_TYPE="$2"; shift 2 ;;
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
    CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null || echo "$BAR_DEFAULT_TYPE")
    CUR_TYPE=$(echo "$CUR_TYPE" | tr -d '[:space:]')
    
    options=""
    
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
            
            options="$options$opt_label: $cur_val\n"
        done
    fi
    
    choice=$(echo -e -n "$options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Manage Bar: $CUR_TYPE")
    [[ -z "$choice" ]] && exit 0
    
    choice_label=$(echo "$choice" | cut -d':' -f1 | xargs)
    for opt_key in "${!OPT_LABELS[@]}"; do
        if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
            val_options=$(echo "${OPT_VALUES[$opt_key]}" | tr ',' '\n')
            NEW_VAL=$(echo -e "$val_options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Select $choice_label")
            if [ -n "$NEW_VAL" ]; then
                if [ "$NEW_VAL" == "custom" ]; then
                    NEW_VAL=$(echo "" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Enter custom value for $choice_label")
                    [[ -z "$NEW_VAL" ]] && exit 0
                fi
                exec "$0" --"$opt_key" "$NEW_VAL"
            fi
        fi
    done
    exit 0
fi

# 4. Listar (si se solicita)
if [ "$LIST_ALL" -eq 1 ]; then
    echo "Temas de Barra:"
    echo "  - $BAR_DEFAULT_TYPE"
    if [ -n "$BAR_THEMES_DIR" ] && [ -d "$BAR_THEMES_DIR" ]; then
        ls -1 "$BAR_THEMES_DIR" | sed 's/^/  - /'
    fi
    echo ""
    echo "Opciones disponibles:"
    if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
        IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
        for opt in "${OPT_ARRAY[@]}"; do
            IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
            echo "  $opt_label ($opt_key): $opt_vals"
        done
    fi
    exit 0
fi

# 4. Selección Interactiva (si no se pasó nada)
ANY_CLI_PARAM=0
for key in "${!CLI_PARAMS[@]}"; do
    ANY_CLI_PARAM=1
    break
done

if [ -z "$SEL_TYPE" ] && [ "$ANY_CLI_PARAM" -eq 0 ]; then
    options=""
    if [ -n "$BAR_THEMES_DIR" ] && [ -d "$BAR_THEMES_DIR" ]; then
        for theme in $(ls -1 "$BAR_THEMES_DIR"); do
            options+="Theme: $theme\n"
        done
    fi
    
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
                options+="$opt_label: $val\n"
            done
        done
    fi
    
    choice=$(echo -e -n "$options" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Bar Config")
    [[ -z "$choice" ]] && exit 0

    if [[ "$choice" == Theme:* ]]; then
        SEL_TYPE="${choice#Theme: }"
    else
        choice_label=$(echo "$choice" | cut -d':' -f1 | xargs)
        choice_val=$(echo "$choice" | cut -d':' -f2 | xargs)
        for opt_key in "${!OPT_LABELS[@]}"; do
            if [ "${OPT_LABELS[$opt_key]}" == "$choice_label" ]; then
                if [ "$choice_val" == "custom" ]; then
                    choice_val=$(echo "" | "$BAR_SEL_BIN" "${BAR_ARGS_ARR[@]}" "$BAR_SEL_PROMPT_FLAG" "Enter custom value for $choice_label")
                    [[ -z "$choice_val" ]] && exit 0
                fi
                CLI_PARAMS["$opt_key"]="$choice_val"
            fi
        done
    fi
fi

# 5. Validar y Guardar con Aislamiento por Tema
if [ -n "$SEL_TYPE" ]; then
    echo "$SEL_TYPE" > "$TYPE_STATE_FILE"
    # Re-consultar capacidades para el nuevo tema inmediatamente
    if [ -n "$BAR_HOOK" ] && [ -f "$BAR_HOOK" ]; then
        while IFS='=' read -r key val; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            case "$key" in
                supported_options) BAR_SUPPORTED_OPTIONS="$val" ;;
            esac
        done < <(bash "$BAR_HOOK" --query 2>/dev/null)
    fi
fi
CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null || echo "$BAR_DEFAULT_TYPE")
CUR_TYPE=$(echo "$CUR_TYPE" | tr -d '[:space:]')

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
                # Aislamiento puro: usar primer valor por defecto en lugar de copiar estado de la barra anterior
                fallback_val=$(echo "$opt_vals" | cut -d',' -f1)
                echo "$fallback_val" > "$THEME_STATE_FILE"
                echo "$fallback_val" > "$STATE_FILE"
            fi
        fi
    done
fi

# 7. Aplicar cambios
"$BIN_DIR/apply_dots.sh"
