#!/usr/bin/env bash
# hooks/components/display.sh - Backend de pantalla para X11 usando xrandr

# Variables de caché globales
XRANDR_CACHE=""
XRANDR_VERBOSE_CACHE=""

hook_load_cache() {
    XRANDR_CACHE=$(xrandr 2>/dev/null)
    XRANDR_VERBOSE_CACHE=$(xrandr --verbose 2>/dev/null)
}

ensure_cache() {
    if [ -z "$XRANDR_CACHE" ]; then
        XRANDR_CACHE=$(xrandr 2>/dev/null)
    fi
}

ensure_verbose_cache() {
    if [ -z "$XRANDR_VERBOSE_CACHE" ]; then
        XRANDR_VERBOSE_CACHE=$(xrandr --verbose 2>/dev/null)
    fi
}

hook_query_outputs() {
    ensure_cache
    echo "$XRANDR_CACHE" | grep " connected" | cut -d' ' -f1
}

hook_query_modes() {
    local output="$1"
    ensure_cache
    echo "$XRANDR_CACHE" | awk -v out="$output" '
        $0 ~ "^"out" connected" { flag=1; next }
        $0 ~ "^[A-Za-z]" && $0 !~ "^"out { flag=0 }
        flag && $1 ~ /^[0-9]+x[0-9]+/ { print $1 }
    ' | sort -V -r | uniq
}

hook_query_rates() {
    local output="$1"
    local resolution="$2"
    ensure_cache
    echo "$XRANDR_CACHE" | awk -v out="$output" -v res="$resolution" '
        $0 ~ "^"out" connected" { flag=1; next }
        $0 ~ "^[A-Za-z]" && $0 !~ "^"out { flag=0 }
        flag && $1 == res {
            for(i=2; i<=NF; i++) {
                rate=$i
                gsub(/[*+]/, "", rate)
                print rate
            }
        }
    ' | sort -n -r | uniq
}

hook_get_current() {
    local output="$1"
    ensure_cache
    echo "$XRANDR_CACHE" | grep -A12 "^$output connected" | awk '
        /\*/ {
            print $1
        }
    ' | head -n1
}

hook_get_current_rate() {
    local output="$1"
    ensure_cache
    echo "$XRANDR_CACHE" | grep -A12 "^$output connected" | awk '
        /\*/ {
            for(i=2; i<=NF; i++) {
                if($i ~ /\*/) {
                    rate=$i
                    gsub(/[*+]/, "", rate)
                    print rate
                }
            }
        }
    ' | head -n1
}

hook_get_current_all() {
    local output="$1"
    ensure_cache
    echo "$XRANDR_CACHE" | grep -A12 "^$output connected" | awk '
        /\*/ {
            res=$1
            for(i=2; i<=NF; i++) {
                if($i ~ /\*/) {
                    rate=$i
                    gsub(/[*+]/, "", rate)
                    print res, rate
                    exit
                }
            }
        }
    ' | head -n1
}

hook_query_default() {
    ensure_cache
    echo "$XRANDR_CACHE" | awk '
        /^[^ ]+ connected/ {
            out=$1
        }
        out && /\*/ {
            res=$1
            for(i=2; i<=NF; i++) {
                if($i ~ /\*/) {
                    rate=$i
                    gsub(/[*+]/, "", rate)
                    print out, res, rate
                    exit
                }
            }
        }
    '
}

hook_get_current_scale() {
    local output="$1"
    ensure_verbose_cache
    echo "$XRANDR_VERBOSE_CACHE" | awk -v out="$output" '
        $0 ~ "^"out" connected" { flag=1; next }
        $0 ~ "^[A-Za-z]" && $0 !~ "^"out { flag=0 }
        flag && /Transform:/ {
            scale=$2
            if (scale == "" || scale == "1.000000") {
                print "1.0"
                exit
            }
            ui_scale = 1 / scale
            val = sprintf("%.2f", ui_scale)
            sub(/0+$/, "", val)
            sub(/\.$/, "", val)
            print val
            exit
        }
    '
}

hook_apply() {
    local output="$1"
    local resolution="$2"
    local rate="$3"
    local scale="$4"
    
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
        --query-outputs) hook_query_outputs "$@" ;;
        --query-modes) hook_query_modes "$@" ;;
        --query-rates) hook_query_rates "$@" ;;
        --get-current) hook_get_current "$@" ;;
        --get-current-rate) hook_get_current_rate "$@" ;;
        --get-current-all) hook_get_current_all "$@" ;;
        --query-default) hook_query_default "$@" ;;
        --get-current-scale) hook_get_current_scale "$@" ;;
        --apply) hook_apply "$@" ;;
        --save) hook_save "$@" ;;
        --post-apply) hook_post_apply "$@" ;;
        *) hook_init "$@" ;;
    esac
fi
