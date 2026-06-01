#!/usr/bin/env bash
# core/bin/engine_bar.sh - Motor de gestión de barras genérico (Headless CLI)

# 1. Cargar Estado y Config
[ -z "$CURRENT_ENV" ] && { echo "Error: CURRENT_ENV no definido." >&2; exit 1; }
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
mkdir -p "$BAR_STATE_DIR"

# 1.1 Auto-detectar Hook de Barra
BAR_HOOK=""
if [ -n "$BAR_HOOK_NAME" ] && [ -f "$HOOK_DIR/components/$BAR_HOOK_NAME" ]; then
    BAR_HOOK="$HOOK_DIR/components/$BAR_HOOK_NAME"
fi

if [ -z "$BAR_HOOK" ]; then
    for comp in $MANAGED_COMPONENTS; do
        if [[ "$comp" == *bar* ]] && [ -f "$HOOK_DIR/components/${comp}.sh" ]; then
            BAR_HOOK="$HOOK_DIR/components/${comp}.sh"
            break
        fi
    done
fi

if [ -z "$BAR_HOOK" ]; then
    for file in "$HOOK_DIR/components/"*bar*.sh; do
        if [ -f "$file" ]; then
            BAR_HOOK="$file"
            break
        fi
    done
fi

# 1.2 Función para consultar capacidades de la barra
query_hook_capabilities() {
    local target_type="$1"
    BAR_THEMES_DIR=""
    BAR_SUPPORTED_OPTIONS=""
    VARIANT_KEYS=""
    PRIMARY_KEY="type"
    BAR_DEFAULT_TYPE="standard"
    
    if [ -n "$BAR_HOOK" ] && [ -f "$BAR_HOOK" ]; then
        local query_output
        query_output=$(bash "$BAR_HOOK" --query "$target_type" 2>/dev/null)
        while IFS='=' read -r key val; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            case "$key" in
                themes_dir)      BAR_THEMES_DIR="$val" ;;
                default_theme)   BAR_DEFAULT_TYPE="$val" ;;
                primary_key)     PRIMARY_KEY="$val" ;;
                variant_keys)    VARIANT_KEYS="$val" ;;
                supported_options) BAR_SUPPORTED_OPTIONS="$val" ;;
            esac
        done <<< "$query_output"
    fi
}

# Inicializar capacidades dinámicas con el tipo activo actual
CUR_TYPE_INIT=$(cat "$BAR_STATE_DIR/type" 2>/dev/null)
CUR_TYPE_INIT="${CUR_TYPE_INIT//[[:space:]]/}"
if [ -z "$CUR_TYPE_INIT" ]; then
    # Primer inicio: consultar hook sin tipo para obtener BAR_DEFAULT_TYPE
    query_hook_capabilities ""
    CUR_TYPE_INIT="${BAR_DEFAULT_TYPE:-standard}"
else
    query_hook_capabilities "$CUR_TYPE_INIT"
fi
TYPE_STATE_FILE="$BAR_STATE_DIR/$PRIMARY_KEY"

# Helper Mapeo de Flags Cortos a Keys
find_key_by_short_flag() {
    local flag="$1"
    if [[ "$flag" == "b" || "$flag" == "bar" ]]; then
        echo "type"
        return 0
    fi
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
    [ -n "$BAR_SUPPORTED_OPTIONS" ] && echo "$BAR_SUPPORTED_OPTIONS" | awk -F'|' -v key="$1" '{ for(i=1;i<=NF;i++) { split($i, a, ":"); if(a[1]==key) { split(a[3], b, ","); print b[1]; exit } } }'
}

# --- Parser de Argumentos Universal ---
# $1 = nombre del mapa asociativo de destino
parse_args_to_map() {
    local -n dest_map="$1"; shift
    local args=("$@")
    local idx=0
    while [ $idx -lt ${#args[@]} ]; do
        local arg="${args[$idx]}"
        case "$arg" in
            -b|--bar)
                dest_map["type"]="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
            --next|--prev|--list-themes|--list-options|--list-presets|-L|--list|--get|--set|--apply-preset)
                # Opciones de control directo (se guardan como flags especiales en el mapa)
                dest_map["_cmd_${arg#--}"]="${args[$((idx+1))]:-1}"
                if [[ "$arg" == "--set" ]]; then
                    dest_map["_set_val"]="${args[$((idx+2))]}"
                    idx=$((idx+3))
                elif [[ "$arg" == "--get" || "$arg" == "--apply-preset" ]]; then
                    idx=$((idx+2))
                else
                    idx=$((idx+1))
                fi
                ;;
            -*)
                local flag="${arg#--}"
                flag="${flag#-}"
                local key=$(find_key_by_short_flag "$flag")
                dest_map["$key"]="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
            *)
                idx=$((idx+1))
                ;;
        esac
    done
}

# Parsear argumentos principales de CLI
declare -A CLI_PARAMS
parse_args_to_map CLI_PARAMS "$@"

# Cargar comandos y tipos seleccionados
SEL_TYPE="${CLI_PARAMS[type]}"
DO_NEXT="${CLI_PARAMS[_cmd_next]:-0}"
DO_PREV="${CLI_PARAMS[_cmd_prev]:-0}"
LIST_THEMES="${CLI_PARAMS[_cmd_list-themes]:-0}"
LIST_OPTIONS="${CLI_PARAMS[_cmd_list-options]:-0}"
LIST_PRESETS="${CLI_PARAMS[_cmd_list-presets]:-0}"
GET_KEY="${CLI_PARAMS[_cmd_get]:-}"
SET_KEY="${CLI_PARAMS[_cmd_set]:-}"
SET_VAL="${CLI_PARAMS[_set_val]:-}"
APPLY_PRESET="${CLI_PARAMS[_cmd_apply-preset]:-}"

# Si se usa el atajo -L / --list
if [ "${CLI_PARAMS[_cmd_list]:-0}" -eq 1 ]; then
    LIST_THEMES=1
    LIST_OPTIONS=1
fi

# Re-consultar capacidades si el tipo final cambió vía CLI antes de ejecutar acciones
if [ -n "$SEL_TYPE" ] && [ "$SEL_TYPE" != "$CUR_TYPE_INIT" ]; then
    query_hook_capabilities "$SEL_TYPE"
fi

# Comparación de Preset
check_preset_match() {
    local preset_cmd="$1"
    local -A PRESET_PARAMS
    local -a args
    local key
    read -r -a args <<< "$preset_cmd"
    parse_args_to_map PRESET_PARAMS "${args[@]}"
    
    for key in "${!PRESET_PARAMS[@]}"; do
        [[ "$key" == _* ]] && continue # Ignorar meta-comandos
        local expected_val="${PRESET_PARAMS[$key]}"
        local current_val
        if [ "$key" == "type" ]; then
            current_val=$(cat "$BAR_STATE_DIR/type" 2>/dev/null)
            current_val="${current_val//[[:space:]]/}"
            [[ -z "$current_val" ]] && current_val="$CUR_TYPE_INIT"
        else
            current_val=$(cat "$BAR_STATE_DIR/$key" 2>/dev/null)
            current_val="${current_val//[[:space:]]/}"
            [[ -z "$current_val" ]] && current_val=$(get_default_option_val "$key")
        fi
        if [ "$expected_val" != "$current_val" ]; then
            return 1
        fi
    done
    return 0
}

# --- Ejecución de Acciones Headless ---

# 1. Listar Temas
if [ "$LIST_THEMES" -eq 1 ]; then
    if [ -n "$BAR_THEMES_DIR" ] && [ -d "$BAR_THEMES_DIR" ]; then
        ls -1 "$BAR_THEMES_DIR"
    else
        echo "$BAR_DEFAULT_TYPE"
    fi
    [ "$LIST_OPTIONS" -eq 0 ] && exit 0
fi

# 2. Listar Opciones
if [ "$LIST_OPTIONS" -eq 1 ]; then
    [ -n "$BAR_SUPPORTED_OPTIONS" ] && echo "$BAR_SUPPORTED_OPTIONS"
    exit 0
fi

# 3. Listar Presets
if [ "$LIST_PRESETS" -eq 1 ]; then
    if [ -n "$BAR_PRESETS" ]; then
        IFS='|' read -ra PRESET_ARRAY <<< "$BAR_PRESETS"
        for preset in "${PRESET_ARRAY[@]}"; do
            name="${preset%%:*}"
            name="${name##[[:space:]]}"
            name="${name%%[[:space:]]}"
            echo "$name"
        done
    fi
    exit 0
fi

# 4. Obtener clave (con fallbacks robustos de solo lectura)
if [ -n "$GET_KEY" ]; then
    if [ "$GET_KEY" == "$PRIMARY_KEY" ] || [ "$GET_KEY" == "type" ]; then
        if [ -f "$BAR_STATE_DIR/type" ]; then
            local val_type=$(cat "$BAR_STATE_DIR/type" 2>/dev/null)
            echo -n "${val_type//[[:space:]]/}"
        else
            echo -n "${BAR_DEFAULT_TYPE:-standard}"
        fi
    else
        if [ -f "$BAR_STATE_DIR/$GET_KEY" ]; then
            local val_opt=$(cat "$BAR_STATE_DIR/$GET_KEY" 2>/dev/null)
            echo -n "${val_opt//[[:space:]]/}"
        else
            echo -n "$(get_default_option_val "$GET_KEY")"
        fi
    fi
    echo ""
    exit 0
fi

# 5. Aplicar preset, ciclo de presets o modo interactivo
if [ "$DO_NEXT" -eq 1 ] || [ "$DO_PREV" -eq 1 ] || [ -n "$APPLY_PRESET" ]; then
    if [ -z "$BAR_PRESETS" ]; then
        echo "Error: BAR_PRESETS no definido en config.env" >&2
        exit 1
    fi

    IFS='|' read -ra PRESET_ARRAY <<< "$BAR_PRESETS"
    TOTAL_PRESETS=${#PRESET_ARRAY[@]}
    SELECTED_PRESET=""

    if [ -n "$APPLY_PRESET" ]; then
        for preset in "${PRESET_ARRAY[@]}"; do
            name="${preset%%:*}"
            name="${name##[[:space:]]}"
            name="${name%%[[:space:]]}"
            if [ "$name" == "$APPLY_PRESET" ]; then
                SELECTED_PRESET="$preset"
                break
            fi
        done
    else
        CURRENT_INDEX=-1
        for i in "${!PRESET_ARRAY[@]}"; do
            preset_cmd="${PRESET_ARRAY[$i]#*:}"
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

    if [ -n "$SELECTED_PRESET" ]; then
        NEW_PRESET_CMD="${SELECTED_PRESET#*:}"
        declare -a preset_args
        read -r -a preset_args <<< "$NEW_PRESET_CMD"
        
        # Limpiar parámetros previos y parsear preset
        unset CLI_PARAMS
        declare -A CLI_PARAMS
        parse_args_to_map CLI_PARAMS "${preset_args[@]}"
        
        SEL_TYPE="${CLI_PARAMS[type]}"
        if [ -n "$SEL_TYPE" ]; then
            query_hook_capabilities "$SEL_TYPE"
        fi
    else
        echo "Error: Preset no encontrado." >&2
        exit 1
    fi
fi

# Si se pasó --set por CLI
if [ -n "$SET_KEY" ]; then
    CLI_PARAMS["$SET_KEY"]="$SET_VAL"
    [[ "$SET_KEY" == "$PRIMARY_KEY" || "$SET_KEY" == "type" ]] && SEL_TYPE="$SET_VAL"
fi

# 6. Validar y Guardar
if [ -n "$SEL_TYPE" ]; then
    echo "$SEL_TYPE" > "$TYPE_STATE_FILE"
fi
CUR_TYPE=$(cat "$TYPE_STATE_FILE" 2>/dev/null)
[[ -z "$CUR_TYPE" ]] && CUR_TYPE="$BAR_DEFAULT_TYPE"
CUR_TYPE="${CUR_TYPE//[[:space:]]/}"

# Calcular sufijo de variante dinámico si aplica
variant_suffix=""
if [ -n "$VARIANT_KEYS" ]; then
    IFS=',' read -ra V_KEYS_ARR <<< "$VARIANT_KEYS"
    for v_key in "${V_KEYS_ARR[@]}"; do
        if [[ "$BAR_SUPPORTED_OPTIONS" == *"${v_key}:"* ]]; then
            v_val="${CLI_PARAMS[$v_key]}"
            if [[ -z "$v_val" ]]; then
                v_val=$(cat "$BAR_STATE_DIR/$v_key" 2>/dev/null)
                v_val="${v_val//[[:space:]]/}"
            fi
            [[ -z "$v_val" ]] && v_val=$(get_default_option_val "$v_key")
            [ -n "$v_val" ] && variant_suffix="${variant_suffix}_$v_val"
        fi
    done
fi

# Guardar y sincronizar todas las opciones dinámicas declaradas en disco
if [ -n "$BAR_SUPPORTED_OPTIONS" ]; then
    IFS='|' read -ra OPT_ARRAY <<< "$BAR_SUPPORTED_OPTIONS"
    for opt in "${OPT_ARRAY[@]}"; do
        IFS=':' read -r opt_key opt_label opt_vals <<< "$opt"
        
        STATE_FILE="$BAR_STATE_DIR/$opt_key"
        THEME_STATE_FILE="$BAR_STATE_DIR/${opt_key}_${CUR_TYPE}${variant_suffix}"
        
        if [ -n "${CLI_PARAMS[$opt_key]}" ]; then
            val="${CLI_PARAMS[$opt_key]}"
            echo "$val" > "$THEME_STATE_FILE"
            echo "$val" > "$STATE_FILE"
        else
            saved_theme_val=$(cat "$THEME_STATE_FILE" 2>/dev/null)
            saved_theme_val="${saved_theme_val//[[:space:]]/}"
            if [ -n "$saved_theme_val" ]; then
                echo "$saved_theme_val" > "$STATE_FILE"
            else
                fallback_val="${opt_vals%%,*}"
                echo "$fallback_val" > "$THEME_STATE_FILE"
                echo "$fallback_val" > "$STATE_FILE"
            fi
        fi
    done
fi

# 7. Aplicar cambios
"$BIN_DIR/apply_dots.sh"
