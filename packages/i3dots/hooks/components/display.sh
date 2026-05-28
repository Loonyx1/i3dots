#!/usr/bin/env bash
# hooks/components/display.sh - Backend de pantalla para X11 usando xrandr

action="$1"
shift

case "$action" in
    --query-outputs)
        xrandr | grep " connected" | cut -d' ' -f1
        ;;
    --query-modes)
        output="$1"
        xrandr | awk -v out="$output" '
            $0 ~ "^"out" connected" { flag=1; next }
            $0 ~ "^[A-Za-z]" && $0 !~ "^"out { flag=0 }
            flag && $1 ~ /^[0-9]+x[0-9]+/ { print $1 }
        ' | sort -V -r | uniq
        ;;
    --query-rates)
        output="$1"
        resolution="$2"
        xrandr | awk -v out="$output" -v res="$resolution" '
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
        ;;
    --get-current)
        output="$1"
        xrandr | grep -A12 "^$output connected" | awk '
            /\*/ {
                print $1
            }
        ' | head -n1
        ;;
    --get-current-rate)
        output="$1"
        xrandr | grep -A12 "^$output connected" | awk '
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
        ;;
    --get-current-all)
        output="$1"
        xrandr | grep -A12 "^$output connected" | awk '
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
        ;;
    --query-default)
        xrandr | awk '
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
        ;;
    --get-current-scale)
        output="$1"
        xrandr --verbose | awk -v out="$output" '
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
        ;;
    --apply)
        output="$1"
        resolution="$2"
        rate="$3"
        scale="$4"
        
        args=()
        if [ -n "$resolution" ]; then
            args+=(--mode "$resolution")
        fi
        if [ -n "$rate" ]; then
            args+=(--rate "$rate")
        fi
        if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
            # Calculate inverse scale for xrandr viewport
            xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
            args+=(--scale "${xrandr_scale}x${xrandr_scale}")
        else
            args+=(--transform none)
        fi
        
        xrandr --output "$output" "${args[@]}"
        ;;
    --save)
        if [ -z "$DISPLAY_STATE_DIR" ]; then
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
            STATE_DIR="${STATE_DIR:-$BASE_DIR/core/state}"
            DISPLAY_STATE_DIR="$STATE_DIR/display"
        fi
        
        I3_OUTPUT_CONF="$HOME/.config/i3/conf.d/output.conf"
        mkdir -p "$(dirname "$I3_OUTPUT_CONF")"
        
        echo "# Configuración de Pantalla Generada Dinámicamente" > "$I3_OUTPUT_CONF"
        echo "# NO EDITAR ESTE ARCHIVO DIRECTAMENTE" >> "$I3_OUTPUT_CONF"
        
        if [ -d "$DISPLAY_STATE_DIR" ]; then
            for res_file in "$DISPLAY_STATE_DIR"/*.resolution; do
                [ -f "$res_file" ] || continue
                
                filename=$(basename "$res_file")
                output="${filename%.resolution}"
                
                resolution=$(cat "$res_file")
                rate_file="$DISPLAY_STATE_DIR/${output}.rate"
                scale_file="$DISPLAY_STATE_DIR/${output}.scale"
                
                cmd="xrandr --output $output"
                if [ -n "$resolution" ]; then
                    cmd="$cmd --mode $resolution"
                fi
                if [ -f "$rate_file" ]; then
                    rate=$(cat "$rate_file")
                    [ -n "$rate" ] && cmd="$cmd --rate $rate"
                fi
                if [ -f "$scale_file" ]; then
                    scale=$(cat "$scale_file")
                    if [ -n "$scale" ] && [ "$scale" != "1" ] && [ "$scale" != "1.0" ]; then
                        xrandr_scale=$(awk -v z="$scale" 'BEGIN { printf "%.3f", 1/z }')
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
        ;;
    --post-apply)
        # Ajustar wallpaper
        if command -v feh >/dev/null && [ -f "$HOME/.config/i3/wall" ]; then
            feh --bg-fill "$(cat "$HOME/.config/i3/wall")" &
        fi
        
        # Relanzar Polybar de forma directa
        if [ -x "$HOME/.config/polybar/launch.sh" ]; then
            bash "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 &
        fi
        ;;
    *)
        # Si se invoca sin argumentos tipo --flag, se comporta como disparador de inicialización
        # Esto permite que dots apply_dots.sh corra el init si es necesario
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        bash "$SCRIPT_DIR/../../../core/bin/engine_display.sh" --init
        ;;
esac
