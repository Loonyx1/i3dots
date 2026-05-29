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
GLYPH_ROTATION="${DISP_GLYPH_ROTATION:-}"
GLYPH_BRIGHTNESS="${DISP_GLYPH_BRIGHTNESS:-}"
GLYPH_CONFIRM="${DISP_GLYPH_CONFIRM:-}"

PROM_MAIN="${DISP_PROM_MAIN:-Configuración de Pantalla}"
PROM_TIMEOUT="${DISP_PROM_TIMEOUT:-Tiempo de Confirmación}"
PROM_MONITOR="${DISP_PROM_MONITOR:-Pantalla}"
PROM_RESOLUTION="${DISP_PROM_RESOLUTION:-Resolución}"
PROM_RATE="${DISP_PROM_RATE:-Frecuencia}"
PROM_SCALE="${DISP_PROM_SCALE:-Escala}"
PROM_ROTATION="${DISP_PROM_ROTATION:-Rotación}"
PROM_BRIGHTNESS="${DISP_PROM_BRIGHTNESS:-Brillo}"
PROM_CONFIRM="${DISP_PROM_CONFIRM:-¿Mantener resolución?}"
PROM_MSG="${DISP_PROM_MSG:-Se revertirá automáticamente tras %s segundos de inactividad.}"

PROM_MENU_OUTPUT="${DISP_PROM_MENU_OUTPUT:-1. Pantalla}"
PROM_MENU_RES="${DISP_PROM_MENU_RES:-2. Resolución}"
PROM_MENU_RATE="${DISP_PROM_MENU_RATE:-3. Frecuencia}"
PROM_MENU_SCALE="${DISP_PROM_MENU_SCALE:-4. Escala}"
PROM_MENU_ROTATION="${DISP_PROM_MENU_ROTATION:-5. Rotación}"
PROM_MENU_BRIGHTNESS="${DISP_PROM_MENU_BRIGHTNESS:-6. Brillo}"
PROM_MENU_TIME="${DISP_PROM_MENU_TIME:-7. Tiempo Confirmación}"
PROM_MENU_APPLY="${DISP_PROM_MENU_APPLY:-8. [ Aplicar y Probar ]}"
PROM_MENU_CANCEL="${DISP_PROM_MENU_CANCEL:-9. [ Cancelar y Salir ]}"

PROM_VAL_NONE="${DISP_PROM_VAL_NONE:-No seleccionada}"
PROM_VAL_AUTO="${DISP_PROM_VAL_AUTO:-Auto}"

VAL_CONFIRM="${DISP_VAL_CONFIRM:-Confirmar}"
VAL_REVERT="${DISP_VAL_REVERT:-Revertir}"

PROM_TIMES="${DISP_PROM_TIMES:-}"
PROM_SCALES="${DISP_PROM_SCALES:-}"
PROM_ROTATIONS="${DISP_PROM_ROTATIONS:-}"
PROM_BRIGHTNESSES="${DISP_PROM_BRIGHTNESSES:-}"
UNIT_RATE="${DISP_UNIT_RATE:-}"
VAL_CUSTOM="${DISP_VAL_CUSTOM:-}"
VAL_CUSTOM_SCALE="${DISP_VAL_CUSTOM_SCALE:-}"

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
        rot_file="$DISPLAY_STATE_DIR/${output}.rotation"
        bri_file="$DISPLAY_STATE_DIR/${output}.brightness"
        
        rate=""
        [ -f "$rate_file" ] && rate=$(cat "$rate_file")
        
        scale=""
        [ -f "$scale_file" ] && scale=$(cat "$scale_file")
        
        rotation=""
        [ -f "$rot_file" ] && rotation=$(cat "$rot_file")
        
        brightness=""
        [ -f "$bri_file" ] && brightness=$(cat "$bri_file")
        
        echo "Inicializando $output -> $resolution ${rate:+@ $rate} ${scale:+[x$scale]} ${rotation:+[$rotation]} ${brightness:+[brightness $brightness]}"
        hook_apply "$output" "$resolution" "$rate" "$scale" "$rotation" "$brightness"
        applied=1
    done
    
    if [ "${DISP_INIT_POST_APPLY:-true}" = "true" ]; then
        hook_post_apply
    fi
}

select_display_interactive() {
    # Cargar caché al inicio en el mismo proceso (evita ejecuciones redundantes de xrandr)
    hook_load_cache
    
    hook_query_default
    local SEL_OUTPUT="$RET_OUT"
    local SEL_RES="$RET_RES"
    local SEL_RATE="$RET_RATE"
    
    if [ -z "$SEL_OUTPUT" ]; then
        echo "Error: No se detectaron salidas de pantalla activas." >&2
        exit 1
    fi
    
    hook_get_current_scale "$SEL_OUTPUT"
    local SEL_SCALE="$RET_SCALE"
    SEL_SCALE="${SEL_SCALE:-1.0}"
    
    hook_get_current_rotation "$SEL_OUTPUT"
    local SEL_ROTATION="$RET_ROTATION"
    SEL_ROTATION="${SEL_ROTATION:-normal}"
    
    hook_get_current_brightness "$SEL_OUTPUT"
    local SEL_BRIGHTNESS="$RET_BRIGHTNESS"
    SEL_BRIGHTNESS="${SEL_BRIGHTNESS:-1.0}"
    
    local SEL_TIMEOUT="15"
    if [ -f "$DISPLAY_STATE_DIR/timeout" ]; then
        local saved_timeout=$(cat "$DISPLAY_STATE_DIR/timeout" | tr -d '[:space:]')
        if [[ "$saved_timeout" =~ ^[0-9]+$ ]]; then
            SEL_TIMEOUT="$saved_timeout"
        fi
    fi
    
    # Crear archivo temporal único de selección para evitar forks de subshells Bash $(...)
    local tmp_choice=$(mktemp)
    
    while true; do
        local menu_options=""
        menu_options+="${PROM_MENU_OUTPUT}: $SEL_OUTPUT"$'\n'
        menu_options+="${PROM_MENU_RES}: ${SEL_RES:-$PROM_VAL_NONE}"$'\n'
        menu_options+="${PROM_MENU_RATE}: ${SEL_RATE:-$PROM_VAL_AUTO}"$'\n'
        menu_options+="${PROM_MENU_SCALE}: ${SEL_SCALE}"$'\n'
        menu_options+="${PROM_MENU_ROTATION}: ${SEL_ROTATION}"$'\n'
        menu_options+="${PROM_MENU_BRIGHTNESS}: ${SEL_BRIGHTNESS}"$'\n'
        menu_options+="${PROM_MENU_TIME}: ${SEL_TIMEOUT}s"$'\n'
        menu_options+="${PROM_MENU_APPLY}"$'\n'
        menu_options+="${PROM_MENU_CANCEL}"
        
        # Redirección directa sin tuberías ni subshells
        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_MAIN" <<< "$menu_options" > "$tmp_choice"
        IFS= read -r choice < "$tmp_choice"
        [ -z "$choice" ] && break
        
        case "$choice" in
            *"$PROM_MENU_OUTPUT"*)
                hook_query_outputs
                local outputs="$RET_LIST"
                local op_list=""
                while IFS= read -r op; do
                    [ -z "$op" ] && continue
                    op_list+="${GLYPH_MONITOR}${op}"$'\n'
                done <<< "$outputs"
                
                op_list="${op_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_MONITOR}${PROM_MONITOR}" <<< "$op_list" > "$tmp_choice"
                IFS= read -r new_out < "$tmp_choice"
                
                if [ -n "$new_out" ]; then
                    new_out="${new_out#$GLYPH_MONITOR}"
                    new_out="${new_out//[[:space:]]/}"
                    SEL_OUTPUT="$new_out"
                    
                    hook_get_current_all "$new_out"
                    SEL_RES="$RET_RES"
                    SEL_RATE="$RET_RATE"
                    
                    hook_get_current_scale "$new_out"
                    SEL_SCALE="$RET_SCALE"
                    SEL_SCALE="${SEL_SCALE:-1.0}"
                    
                    hook_get_current_rotation "$new_out"
                    SEL_ROTATION="$RET_ROTATION"
                    SEL_ROTATION="${SEL_ROTATION:-normal}"
                    
                    hook_get_current_brightness "$new_out"
                    SEL_BRIGHTNESS="$RET_BRIGHTNESS"
                    SEL_BRIGHTNESS="${SEL_BRIGHTNESS:-1.0}"
                fi
                ;;
                
            *"$PROM_MENU_RES"*)
                if [ -z "$SEL_OUTPUT" ]; then
                    continue
                fi
                hook_query_modes "$SEL_OUTPUT"
                local modes="$RET_LIST"
                local res_list=""
                while IFS= read -r res; do
                    [ -z "$res" ] && continue
                    res_list+="${GLYPH_RESOLUTION}${res}"$'\n'
                done <<< "$modes"
                
                res_list="${res_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RESOLUTION}${PROM_RESOLUTION}" <<< "$res_list" > "$tmp_choice"
                IFS= read -r new_res < "$tmp_choice"
                
                if [ -n "$new_res" ]; then
                    new_res="${new_res#$GLYPH_RESOLUTION}"
                    new_res="${new_res//[[:space:]]/}"
                    SEL_RES="$new_res"
                    SEL_RATE=""
                fi
                ;;
                
            *"$PROM_MENU_RATE"*)
                if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                    continue
                fi
                hook_query_rates "$SEL_OUTPUT" "$SEL_RES"
                local rates="$RET_LIST"
                if [ -z "$rates" ]; then
                    continue
                fi
                local rate_list=""
                while IFS= read -r r; do
                    [ -z "$r" ] && continue
                    rate_list+="${GLYPH_RATE}${r}${UNIT_RATE}"$'\n'
                done <<< "$rates"
                
                rate_list="${rate_list%$'\n'}"
                
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RATE}${PROM_RATE}" <<< "$rate_list" > "$tmp_choice"
                IFS= read -r new_rate < "$tmp_choice"
                
                if [ -n "$new_rate" ]; then
                    new_rate="${new_rate#$GLYPH_RATE}"
                    new_rate="${new_rate%${UNIT_RATE}}"
                    new_rate="${new_rate//[[:space:]]/}"
                    SEL_RATE="$new_rate"
                fi
                ;;
                
            *"$PROM_MENU_SCALE"*)
                local scales_list
                printf -v scales_list "%b" "$PROM_SCALES"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_SCALE}${PROM_SCALE}" <<< "$scales_list" > "$tmp_choice"
                IFS= read -r new_scale < "$tmp_choice"
                
                if [ -n "$new_scale" ]; then
                    new_scale="${new_scale//[[:space:]]/}"
                    
                    if [ "$new_scale" = "$VAL_CUSTOM_SCALE" ] || [ "$new_scale" = "personalizada" ] || [ "$new_scale" = "custom" ]; then
                        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "Escala (ej: 1.3)" <<< "" > "$tmp_choice"
                        IFS= read -r custom_scale < "$tmp_choice"
                        custom_scale="${custom_scale//[[:space:]]/}"
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
                
            *"$PROM_MENU_ROTATION"*)
                local rotations_list
                printf -v rotations_list "%b" "$PROM_ROTATIONS"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_ROTATION}${PROM_ROTATION}" <<< "$rotations_list" > "$tmp_choice"
                IFS= read -r new_rot < "$tmp_choice"
                
                if [ -n "$new_rot" ]; then
                    new_rot="${new_rot//[[:space:]]/}"
                    SEL_ROTATION="$new_rot"
                fi
                ;;
                
            *"$PROM_MENU_BRIGHTNESS"*)
                local brightnesses_list
                printf -v brightnesses_list "%b" "$PROM_BRIGHTNESSES"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_BRIGHTNESS}${PROM_BRIGHTNESS}" <<< "$brightnesses_list" > "$tmp_choice"
                IFS= read -r new_bri < "$tmp_choice"
                
                if [ -n "$new_bri" ]; then
                    new_bri="${new_bri//[[:space:]]/}"
                    
                    if [ "$new_bri" = "$VAL_CUSTOM" ] || [ "$new_bri" = "personalizado" ] || [ "$new_bri" = "custom" ]; then
                        "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "Brillo (ej: 0.85)" <<< "" > "$tmp_choice"
                        IFS= read -r custom_bri < "$tmp_choice"
                        custom_bri="${custom_bri//[[:space:]]/}"
                        custom_bri="${custom_bri//,/.}"
                        if [[ "$custom_bri" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            new_bri="$custom_bri"
                        else
                            continue
                        fi
                    fi
                    SEL_BRIGHTNESS="$new_bri"
                fi
                ;;
                
            *"$PROM_MENU_TIME"*)
                local times_list
                printf -v times_list "%b" "$PROM_TIMES"
                "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_TIMEOUT" <<< "$times_list" > "$tmp_choice"
                IFS= read -r new_time < "$tmp_choice"
                
                if [ -n "$new_time" ]; then
                    new_time="${new_time%s}"
                    new_time="${new_time//[[:space:]]/}"
                    SEL_TIMEOUT="$new_time"
                    
                    mkdir -p "$DISPLAY_STATE_DIR"
                    echo "$new_time" > "$DISPLAY_STATE_DIR/timeout"
                fi
                ;;
                
            *"$PROM_MENU_APPLY"*)
                if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                    rm -f "$tmp_choice"
                    exit 1
                fi
                
                hook_get_current "$SEL_OUTPUT"
                local old_res="${RET_RES//[[:space:]]/}"
                
                hook_get_current_rate "$SEL_OUTPUT"
                local old_rate="${RET_RATE//[[:space:]]/}"
                
                hook_get_current_scale "$SEL_OUTPUT"
                local old_scale="${RET_SCALE//[[:space:]]/}"
                old_scale="${old_scale:-1.0}"
                
                hook_get_current_rotation "$SEL_OUTPUT"
                local old_rotation="${RET_ROTATION//[[:space:]]/}"
                old_rotation="${old_rotation:-normal}"
                
                hook_get_current_brightness "$SEL_OUTPUT"
                local old_brightness="${RET_BRIGHTNESS//[[:space:]]/}"
                old_brightness="${old_brightness:-1.0}"
                
                echo "Aplicando previsualización: $SEL_OUTPUT -> $SEL_RES ${SEL_RATE:+@ $SEL_RATE} ${SEL_SCALE:+[x$SEL_SCALE]} ${SEL_ROTATION:+[$SEL_ROTATION]} ${SEL_BRIGHTNESS:+[brightness $SEL_BRIGHTNESS]}"
                hook_apply "$SEL_OUTPUT" "$SEL_RES" "$SEL_RATE" "$SEL_SCALE" "$SEL_ROTATION" "$SEL_BRIGHTNESS"
                hook_post_apply
                
                sleep 0.5
                
                local tmp_confirm=$(mktemp)
                local confirmed=""
                local prom_msg=$(printf "$PROM_MSG" "$SEL_TIMEOUT")
                
                # Ejecutar Rofi en segundo plano sin usar pipelines de subshell
                "$DISP_SEL_BIN" "${DISP_CONF_ARGS_ARR[@]}" \
                    -p "${GLYPH_CONFIRM}${PROM_CONFIRM}" \
                    -mesg "$prom_msg" <<< "${VAL_CONFIRM}"$'\n'"${VAL_REVERT}" > "$tmp_confirm" &
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
                    if [ -n "$SEL_ROTATION" ]; then
                        echo "$SEL_ROTATION" > "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.rotation"
                    else
                        rm -f "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.rotation"
                    fi
                    if [ -n "$SEL_BRIGHTNESS" ]; then
                        echo "$SEL_BRIGHTNESS" > "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.brightness"
                    else
                        rm -f "$DISPLAY_STATE_DIR/${SEL_OUTPUT}.brightness"
                    fi
                    hook_save
                    echo "Resolución guardada permanentemente."
                else
                    echo "Acción cancelada o expirada. Revirtiendo a $old_res ${old_rate:+@ $old_rate} ${old_scale:+[x$old_scale]} ${old_rotation:+[$old_rotation]} ${old_brightness:+[brightness $old_brightness]}..."
                    hook_apply "$SEL_OUTPUT" "$old_res" "$old_rate" "$old_scale" "$old_rotation" "$old_brightness"
                    hook_post_apply
                fi
                break
                ;;
                
            *)
                break
                ;;
        esac
    done
    
    rm -f "$tmp_choice"
    exit 0
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
