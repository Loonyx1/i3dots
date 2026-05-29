#!/usr/bin/env bash

# engine_display.sh - Motor de gestión de resoluciones universal
# Desacoplado de backends (xrandr/wlr-randr) y frontends (rofi/wofi/dmenu)

# 1. Resolver Directorios y Fallbacks
if [ -z "$HOOK_DIR" ] || [ -z "$STATE_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    export CORE_DIR="$BASE_DIR/core"
    export STATE_DIR="$CORE_DIR/state"
    export PACKAGES_DIR="$BASE_DIR/packages"
    
    # Intentar detectar dinámicamente cualquier paquete activo que contenga config.env
    if [ -d "$PACKAGES_DIR" ]; then
        for dir in "$PACKAGES_DIR"/*; do
            if [ -f "$dir/config.env" ]; then
                export CURRENT_ENV="$(basename "$dir")"
                export PACKAGE_DIR="$dir"
                source "$dir/config.env"
                break
            fi
        done
    fi
fi

# Ruta del hook de pantalla e importación
DISPLAY_HOOK="$HOOK_DIR/components/display.sh"
DISPLAY_STATE_DIR="${DISPLAY_STATE_DIR:-$STATE_DIR/display}"

# Verificar existencia del hook e importarlo
if [ ! -f "$DISPLAY_HOOK" ]; then
    echo "Error: Hook de pantalla no encontrado en $DISPLAY_HOOK" >&2
    exit 1
fi
source "$DISPLAY_HOOK"

# Configuración de UI, Glifos y Prompts
if [ -z "$DISP_SEL_BIN" ]; then
    echo "Error: DISP_SEL_BIN no configurado en entorno." >&2
    exit 1
fi

DISP_SEL_ARGS_ARR=($DISP_SEL_ARGS)
if [ -n "$DISP_CONF_ARGS" ]; then
    DISP_CONF_ARGS_ARR=($DISP_CONF_ARGS)
else
    DISP_CONF_ARGS_ARR=("${DISP_SEL_ARGS_ARR[@]}")
fi

GLYPH_MONITOR="${DISP_GLYPH_MONITOR:-}"
GLYPH_RESOLUTION="${DISP_GLYPH_RESOLUTION:-}"
GLYPH_RATE="${DISP_GLYPH_RATE:-}"
GLYPH_SCALE="${DISP_GLYPH_SCALE:-}"
GLYPH_CONFIRM="${DISP_GLYPH_CONFIRM:-}"

PROM_MAIN="${DISP_PROM_MAIN:-Configuración de Pantalla}"
PROM_TIMEOUT="${DISP_PROM_TIMEOUT:-Tiempo de Confirmación}"
PROM_MONITOR="${DISP_PROM_MONITOR:-Pantalla}"
PROM_RESOLUTION="${DISP_PROM_RESOLUTION:-Resolución}"
PROM_RATE="${DISP_PROM_RATE:-Frecuencia}"
PROM_SCALE="${DISP_PROM_SCALE:-Escala}"
PROM_CONFIRM="${DISP_PROM_CONFIRM:-¿Mantener resolución?}"
PROM_MSG="${DISP_PROM_MSG:-Se revertirá automáticamente tras %s segundos de inactividad.}"

PROM_MENU_OUTPUT="${DISP_PROM_MENU_OUTPUT:-1. Pantalla}"
PROM_MENU_RES="${DISP_PROM_MENU_RES:-2. Resolución}"
PROM_MENU_RATE="${DISP_PROM_MENU_RATE:-3. Frecuencia}"
PROM_MENU_SCALE="${DISP_PROM_MENU_SCALE:-4. Escala}"
PROM_MENU_TIME="${DISP_PROM_MENU_TIME:-5. Tiempo Confirmación}"
PROM_MENU_APPLY="${DISP_PROM_MENU_APPLY:-6. [ Aplicar y Probar ]}"
PROM_MENU_CANCEL="${DISP_PROM_MENU_CANCEL:-7. [ Cancelar y Salir ]}"

PROM_VAL_NONE="${DISP_PROM_VAL_NONE:-No seleccionada}"
PROM_VAL_AUTO="${DISP_PROM_VAL_AUTO:-Auto}"

VAL_CONFIRM="${DISP_VAL_CONFIRM:-Confirmar}"
VAL_REVERT="${DISP_VAL_REVERT:-Revertir}"

PROM_TIMES="${DISP_PROM_TIMES:-5s\n10s\n15s\n30s\n60s}"
PROM_SCALES="${DISP_PROM_SCALES:-0.5\n0.75\n1.0\n1.25\n1.5\n1.75\n2.0\n2.5\n3.0\npersonalizada}"
UNIT_RATE="${DISP_UNIT_RATE:- Hz}"

# 2. Funciones de Flujo
init_display() {
    if [ ! -d "$DISPLAY_STATE_DIR" ]; then
        echo "Aviso: No hay estados de pantalla guardados."
        if [ "${DISP_INIT_POST_APPLY:-true}" = "true" ]; then
            hook_post_apply
        fi
        exit 0
    fi
    
    applied=0
    for res_file in "$DISPLAY_STATE_DIR"/*.resolution; do
        [ -f "$res_file" ] || continue
        
        filename=$(basename "$res_file")
        output="${filename%.resolution}"
        
        resolution=$(cat "$res_file")
        rate_file="$DISPLAY_STATE_DIR/${output}.rate"
        scale_file="$DISPLAY_STATE_DIR/${output}.scale"
        
        rate=""
        if [ -f "$rate_file" ]; then
            rate=$(cat "$rate_file")
        fi
        
        scale=""
        if [ -f "$scale_file" ]; then
            scale=$(cat "$scale_file")
        fi
        
        echo "Inicializando $output -> $resolution ${rate:+@ $rate} ${scale:+[x$scale]}"
        hook_apply "$output" "$resolution" "$rate" "$scale"
        applied=1
    done
    
    if [ "${DISP_INIT_POST_APPLY:-true}" = "true" ]; then
        hook_post_apply
    fi
}

select_display_interactive() {
    # Cargar caché al inicio en el mismo proceso (evita ejecuciones redundantes de xrandr)
    hook_load_cache
    
    read -r default_output default_res default_rate < <(hook_query_default)
    if [ -z "$default_output" ]; then
        echo "Error: No se detectaron salidas de pantalla activas." >&2
        exit 1
    fi
    
    local SEL_OUTPUT="$default_output"
    local SEL_RES="$default_res"
    local SEL_RATE="$default_rate"
    local SEL_SCALE=$(hook_get_current_scale "$default_output")
    SEL_SCALE="${SEL_SCALE:-1.0}"
    
    local SEL_TIMEOUT="15"
    if [ -f "$DISPLAY_STATE_DIR/timeout" ]; then
        local saved_timeout=$(cat "$DISPLAY_STATE_DIR/timeout" | tr -d '[:space:]')
        if [[ "$saved_timeout" =~ ^[0-9]+$ ]]; then
            SEL_TIMEOUT="$saved_timeout"
        fi
    fi
    
    while true; do
        local menu_options=""
        menu_options+="${PROM_MENU_OUTPUT}: $SEL_OUTPUT\n"
        menu_options+="${PROM_MENU_RES}: ${SEL_RES:-$PROM_VAL_NONE}\n"
        menu_options+="${PROM_MENU_RATE}: ${SEL_RATE:-$PROM_VAL_AUTO}\n"
        menu_options+="${PROM_MENU_SCALE}: ${SEL_SCALE}\n"
        menu_options+="${PROM_MENU_TIME}: ${SEL_TIMEOUT}s\n"
        menu_options+="${PROM_MENU_APPLY}\n"
        menu_options+="${PROM_MENU_CANCEL}"
        
        local choice=$(echo -e "$menu_options" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_MAIN")
        [ -z "$choice" ] && exit 0
        
        case "$choice" in
            *"$PROM_MENU_OUTPUT"*)
                local outputs=$(hook_query_outputs)
                local op_list=""
                while IFS= read -r op; do
                    [ -z "$op" ] && continue
                    op_list+="${GLYPH_MONITOR}${op}\n"
                done <<< "$outputs"
                
                local new_out=$(echo -e "$op_list" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_MONITOR}${PROM_MONITOR}")
                if [ -n "$new_out" ]; then
                    new_out="${new_out#$GLYPH_MONITOR}"
                    new_out=$(echo "$new_out" | tr -d '[:space:]')
                    SEL_OUTPUT="$new_out"
                    
                    read -r SEL_RES SEL_RATE < <(hook_get_current_all "$new_out")
                    SEL_SCALE=$(hook_get_current_scale "$new_out")
                    SEL_SCALE="${SEL_SCALE:-1.0}"
                fi
                ;;
                
            *"$PROM_MENU_RES"*)
                if [ -z "$SEL_OUTPUT" ]; then
                    continue
                fi
                local modes=$(hook_query_modes "$SEL_OUTPUT")
                local res_list=""
                while IFS= read -r res; do
                    [ -z "$res" ] && continue
                    res_list+="${GLYPH_RESOLUTION}${res}\n"
                done <<< "$modes"
                
                local new_res=$(echo -e "$res_list" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RESOLUTION}${PROM_RESOLUTION}")
                if [ -n "$new_res" ]; then
                    new_res="${new_res#$GLYPH_RESOLUTION}"
                    new_res=$(echo "$new_res" | tr -d '[:space:]')
                    SEL_RES="$new_res"
                    SEL_RATE=""
                fi
                ;;
                
            *"$PROM_MENU_RATE"*)
                if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                    continue
                fi
                local rates=$(hook_query_rates "$SEL_OUTPUT" "$SEL_RES")
                if [ -z "$rates" ]; then
                    continue
                fi
                local rate_list=""
                while IFS= read -r r; do
                    [ -z "$r" ] && continue
                    rate_list+="${GLYPH_RATE}${r}${UNIT_RATE}\n"
                done <<< "$rates"
                
                local new_rate=$(echo -e "$rate_list" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RATE}${PROM_RATE}")
                if [ -n "$new_rate" ]; then
                    new_rate="${new_rate#$GLYPH_RATE}"
                    new_rate="${new_rate%${UNIT_RATE}}"
                    new_rate=$(echo "$new_rate" | tr -d '[:space:]')
                    SEL_RATE="$new_rate"
                fi
                ;;
                
            *"$PROM_MENU_SCALE"*)
                local new_scale=$(echo -e "$PROM_SCALES" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_SCALE}${PROM_SCALE}")
                if [ -n "$new_scale" ]; then
                    new_scale=$(echo "$new_scale" | tr -d '[:space:]')
                    
                    if [ "$new_scale" = "personalizada" ] || [ "$new_scale" = "custom" ]; then
                        local custom_scale=$(echo "" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "Escala (ej: 1.3)")
                        custom_scale=$(echo "$custom_scale" | tr -d '[:space:]')
                        custom_scale="${custom_scale//,/.}"
                        if [[ "$custom_scale" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ $(awk -v cs="$custom_scale" 'BEGIN { print (cs > 0) }') -eq 1 ]; then
                            new_scale="$custom_scale"
                        else
                            continue
                        fi
                    fi
                    SEL_SCALE="$new_scale"
                fi
                ;;
                
            *"$PROM_MENU_TIME"*)
                local new_time=$(echo -e "$PROM_TIMES" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_TIMEOUT")
                if [ -n "$new_time" ]; then
                    new_time="${new_time%s}"
                    new_time=$(echo "$new_time" | tr -d '[:space:]')
                    SEL_TIMEOUT="$new_time"
                    
                    mkdir -p "$DISPLAY_STATE_DIR"
                    echo "$new_time" > "$DISPLAY_STATE_DIR/timeout"
                fi
                ;;
                
            *"$PROM_MENU_APPLY"*)
                if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                    exit 1
                fi
                
                local old_res=$(hook_get_current "$SEL_OUTPUT" | tr -d '[:space:]')
                local old_rate=$(hook_get_current_rate "$SEL_OUTPUT" | tr -d '[:space:]')
                local old_scale=$(hook_get_current_scale "$SEL_OUTPUT" | tr -d '[:space:]')
                old_scale="${old_scale:-1.0}"
                
                echo "Aplicando previsualización: $SEL_OUTPUT -> $SEL_RES ${SEL_RATE:+@ $SEL_RATE} ${SEL_SCALE:+[x$SEL_SCALE]}"
                hook_apply "$SEL_OUTPUT" "$SEL_RES" "$SEL_RATE" "$SEL_SCALE"
                hook_post_apply
                
                sleep 0.5
                
                local tmp_confirm=$(mktemp)
                local confirmed=""
                local prom_msg=$(printf "$PROM_MSG" "$SEL_TIMEOUT")
                
                echo -e "${VAL_CONFIRM}\n${VAL_REVERT}" | "$DISP_SEL_BIN" "${DISP_CONF_ARGS_ARR[@]}" \
                    -p "${GLYPH_CONFIRM}${PROM_CONFIRM}" \
                    -mesg "$prom_msg" > "$tmp_confirm" &
                local dialog_pid=$!
                
                local dialog_exited=0
                for ((i=SEL_TIMEOUT; i>0; i--)); do
                    for ((s=1; s<=10; s++)); do
                        if ! kill -0 $dialog_pid 2>/dev/null; then
                            dialog_exited=1
                            break 2
                        fi
                        sleep 0.1
                    done
                done
                
                if [ "$dialog_exited" -eq 1 ]; then
                    local choice_confirm=$(cat "$tmp_confirm" | tr -d '[:space:]')
                    if [ "$choice_confirm" = "$VAL_CONFIRM" ]; then
                        confirmed="yes"
                    else
                        confirmed="no"
                    fi
                else
                    kill $dialog_pid 2>/dev/null
                    wait $dialog_pid 2>/dev/null
                    confirmed="no"
                fi
                rm -f "$tmp_confirm"
                
                if [ "$confirmed" = "yes" ]; then
                    mkdir -p "$DISPLAY_STATE_DIR"
                    echo "$SEL_RES" > "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.resolution"
                    if [ -n "$SEL_RATE" ]; then
                        echo "$SEL_RATE" > "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.rate"
                    else
                        rm -f "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.rate"
                    fi
                    if [ -n "$SEL_SCALE" ]; then
                        echo "$SEL_SCALE" > "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.scale"
                    else
                        rm -f "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.scale"
                    fi
                    hook_save
                    echo "Resolución guardada permanentemente."
                else
                    echo "Acción cancelada o expirada. Revirtiendo a $old_res ${old_rate:+@ $old_rate} ${old_scale:+[x$old_scale]}..."
                    hook_apply "$SEL_OUTPUT" "$old_res" "$old_rate" "$old_scale"
                    hook_post_apply
                fi
                exit 0
                ;;
                
            *)
                exit 0
                ;;
        esac
    done
}

# 3. Parseo de Argumentos principales
case "$1" in
    --init|--apply)
        init_display
        ;;
    *)
        select_display_interactive
        ;;
esac
