#!/usr/bin/env bash
# hooks/components/display.sh - Backend de pantalla para X11 usando xrandr

# Variables de caché globales
XRANDR_CACHE=""
XRANDR_VERBOSE_CACHE=""

# Variables de retorno globales (para evitar subshells)
RET_OUT=""
RET_RES=""
RET_RATE=""
RET_SCALE=""
RET_ROTATION=""
RET_BRIGHTNESS=""
RET_LIST=""

hook_load_cache() {
    XRANDR_CACHE=$(xrandr --current 2>/dev/null)
    XRANDR_VERBOSE_CACHE=$(xrandr --current --verbose 2>/dev/null)
}

ensure_cache() {
    if [ -z "$XRANDR_CACHE" ]; then
        XRANDR_CACHE=$(xrandr --current 2>/dev/null)
    fi
}

ensure_verbose_cache() {
    if [ -z "$XRANDR_VERBOSE_CACHE" ]; then
        XRANDR_VERBOSE_CACHE=$(xrandr --current --verbose 2>/dev/null)
    fi
}

hook_query_outputs() {
    ensure_cache
    RET_LIST=""
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            RET_LIST+="${BASH_REMATCH[1]}"$'\n'
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_query_modes() {
    local output="$1"
    ensure_cache
    RET_LIST=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [ -n "$res_name" ]; then
                    RET_LIST+="$res_name"$'\n'
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_query_rates() {
    local output="$1"
    local resolution="$2"
    ensure_cache
    RET_LIST=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [ "$res_name" = "$resolution" ]; then
                    local rate
                    for rate in $rates_str; do
                        rate="${rate//[*+]/}"
                        RET_LIST+="$rate"$'\n'
                    done
                    break
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
    RET_LIST="${RET_LIST%$'\n'}"
}

hook_get_current() {
    local output="$1"
    ensure_cache
    RET_RES=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                if [[ "$rates_str" == *"*"* ]]; then
                    RET_RES="$res_name"
                    break
                fi
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_rate() {
    local output="$1"
    ensure_cache
    RET_RATE=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_all() {
    local output="$1"
    ensure_cache
    RET_RES=""
    RET_RATE=""
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_RES="$res_name"
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_query_default() {
    ensure_cache
    RET_OUT=""
    RET_RES=""
    RET_RATE=""
    local line current_out=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            current_out="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            current_out=""
        fi
        
        if [ -n "$current_out" ]; then
            if [[ "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
                read -r res_name rates_str <<< "$line"
                local rate
                for rate in $rates_str; do
                    if [[ "$rate" == *"*"* ]]; then
                        RET_OUT="$current_out"
                        RET_RES="$res_name"
                        RET_RATE="${rate//[*+]/}"
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_scale() {
    local output="$1"
    ensure_verbose_cache
    RET_SCALE="1.0"
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ [[:space:]]*Transform:[[:space:]]+([^[:space:]]+) ]]; then
                local scale="${BASH_REMATCH[1]}"
                if [ "$scale" = "1.000000" ] || [ -z "$scale" ]; then
                    RET_SCALE="1.0"
                else
                    RET_SCALE=$(awk -v s="$scale" 'BEGIN { printf "%.2f", 1/s }' 2>/dev/null)
                    RET_SCALE="${RET_SCALE%0}"
                    RET_SCALE="${RET_SCALE%.}"
                fi
                break
            fi
        fi
    done <<< "$XRANDR_VERBOSE_CACHE"
}

hook_get_current_rotation() {
    local output="$1"
    ensure_cache
    RET_ROTATION="normal"
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                if [[ "$line" =~ [[:space:]]+(normal|left|right|inverted)[[:space:]]+\( ]]; then
                    RET_ROTATION="${BASH_REMATCH[1]}"
                fi
                break
            fi
        fi
    done <<< "$XRANDR_CACHE"
}

hook_get_current_brightness() {
    local output="$1"
    ensure_verbose_cache
    RET_BRIGHTNESS="1.0"
    local line flag=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+connected ]]; then
            if [ "${BASH_REMATCH[1]}" = "$output" ]; then
                flag=1
            else
                flag=0
            fi
            continue
        elif [[ "$line" =~ ^[A-Za-z] ]]; then
            flag=0
        fi
        
        if [ "$flag" -eq 1 ]; then
            if [[ "$line" =~ [[:space:]]*Brightness:[[:space:]]+([^[:space:]]+) ]]; then
                RET_BRIGHTNESS="${BASH_REMATCH[1]}"
                break
            fi
        fi
    done <<< "$XRANDR_VERBOSE_CACHE"
}

hook_apply() {
    local output="$1"
    local resolution="$2"
    local rate="$3"
    local scale="$4"
    local rotation="$5"
    local brightness="$6"
    
    local args=()
    if [ -n "$resolution" ]; then
        args+=(--mode "$resolution")
    fi
    if [ -n "$rate" ]; then
        args+=(--rate "$rate")
    fi
    if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
        xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
        args+=(--scale "${xrandr_scale}x${xrandr_scale}")
    else
        args+=(--transform none)
    fi
    if [ -n "$rotation" ]; then
        args+=(--rotate "$rotation")
    fi
    if [ -n "$brightness" ]; then
        args+=(--brightness "$brightness")
    fi
    
    xrandr --output "$output" "${args[@]}"
}

hook_save() {
    if [ -z "$DISPLAY_STATE_DIR" ]; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
        local STATE_DIR="${STATE_DIR:-$BASE_DIR/core/state}"
        DISPLAY_STATE_DIR="$STATE_DIR/display"
    fi
    
    local I3_OUTPUT_CONF="$HOME/.config/i3/conf.d/output.conf"
    mkdir -p "$(dirname "$I3_OUTPUT_CONF")"
    
    echo "# Configuración de Pantalla Generada Dinámicamente" > "$I3_OUTPUT_CONF"
    echo "# NO EDITAR ESTE ARCHIVO DIRECTAMENTE" >> "$I3_OUTPUT_CONF"
    
    if [ -d "$DISPLAY_STATE_DIR" ]; then
        for res_file in "$DISPLAY_STATE_DIR"/*.resolution; do
            [ -f "$res_file" ] || continue
            
            local filename=$(basename "$res_file")
            local output="${filename%.resolution}"
            
            local resolution=$(cat "$res_file")
            local rate_file="$DISPLAY_STATE_DIR/${output}.rate"
            local scale_file="$DISPLAY_STATE_DIR/${output}.scale"
            local rot_file="$DISPLAY_STATE_DIR/${output}.rotation"
            local bri_file="$DISPLAY_STATE_DIR/${output}.brightness"
            
            local cmd="xrandr --output $output"
            if [ -n "$resolution" ]; then
                cmd="$cmd --mode $resolution"
            fi
            if [ -f "$rate_file" ]; then
                local rate=$(cat "$rate_file")
                [ -n "$rate" ] && cmd="$cmd --rate $rate"
            fi
            if [ -f "$scale_file" ]; then
                local scale=$(cat "$scale_file")
                if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
                    local xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
                    cmd="$cmd --scale ${xrandr_scale}x${xrandr_scale}"
                else
                    cmd="$cmd --transform none"
                fi
            else
                cmd="$cmd --transform none"
            fi
            if [ -f "$rot_file" ]; then
                local rotation=$(cat "$rot_file")
                [ -n "$rotation" ] && cmd="$cmd --rotate $rotation"
            fi
            if [ -f "$bri_file" ]; then
                local brightness=$(cat "$bri_file")
                [ -n "$brightness" ] && cmd="$cmd --brightness $brightness"
            fi
            
            echo "exec_always --no-startup-id $cmd" >> "$I3_OUTPUT_CONF"
        done
    fi
}

hook_post_apply() {
    # Ajustar wallpaper
    if command -v feh >/dev/null && [ -f "$HOME/.config/i3/wall" ]; then
        feh --bg-fill "$(cat "$HOME/.config/i3/wall")" &
    fi
    
    # Relanzar Polybar de forma directa
    if [ -x "$HOME/.config/polybar/launch.sh" ]; then
        bash "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 &
    fi
}

hook_init() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/../../../core/bin/engine_display.sh" --init
}

# Ejecución directa si no se está importando (sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="$1"
    shift
    case "$action" in
        --query-outputs)
            hook_query_outputs "$@"
            echo "$RET_LIST"
            ;;
        --query-modes)
            hook_query_modes "$@"
            echo "$RET_LIST"
            ;;
        --query-rates)
            hook_query_rates "$@"
            echo "$RET_LIST"
            ;;
        --get-current)
            hook_get_current "$@"
            echo "$RET_RES"
            ;;
        --get-current-rate)
            hook_get_current_rate "$@"
            echo "$RET_RATE"
            ;;
        --get-current-all)
            hook_get_current_all "$@"
            echo "$RET_RES $RET_RATE"
            ;;
        --query-default)
            hook_query_default "$@"
            echo "$RET_OUT $RET_RES $RET_RATE"
            ;;
        --get-current-scale)
            hook_get_current_scale "$@"
            echo "$RET_SCALE"
            ;;
        --get-current-rotation)
            hook_get_current_rotation "$@"
            echo "$RET_ROTATION"
            ;;
        --get-current-brightness)
            hook_get_current_brightness "$@"
            echo "$RET_BRIGHTNESS"
            ;;
        --apply) hook_apply "$@" ;;
        --save) hook_save "$@" ;;
        --post-apply) hook_post_apply "$@" ;;
        *) hook_init "$@" ;;
    esac
fi
