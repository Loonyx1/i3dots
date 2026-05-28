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

# Ruta del hook de pantalla
DISPLAY_HOOK="$HOOK_DIR/components/display.sh"
DISPLAY_STATE_DIR="${DISPLAY_STATE_DIR:-$STATE_DIR/display}"

# Verificar existencia del hook
if [ ! -f "$DISPLAY_HOOK" ]; then
    echo "Error: Hook de pantalla no encontrado en $DISPLAY_HOOK" >&2
    exit 1
fi

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
        bash "$DISPLAY_HOOK" --post-apply
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
        bash "$DISPLAY_HOOK" --apply "$output" "$resolution" "$rate" "$scale"
        applied=1
    done
    
    bash "$DISPLAY_HOOK" --post-apply
}

select_display_interactive() {
    local tmp_sel_file="/tmp/display_sel_${USER}"
    
    if [ ! -f "$tmp_sel_file" ]; then
        read -r default_output default_res default_rate <<< $(bash "$DISPLAY_HOOK" --query-default)
        if [ -z "$default_output" ]; then
            echo "Error: No se detectaron salidas de pantalla activas." >&2
            exit 1
        fi
        
        local default_scale=$(bash "$DISPLAY_HOOK" --get-current-scale "$default_output")
        default_scale="${default_scale:-1.0}"
        
        local saved_timeout="15"
        if [ -f "$DISPLAY_STATE_DIR/timeout" ]; then
            saved_timeout=$(cat "$DISPLAY_STATE_DIR/timeout" | tr -d '[:space:]')
            if ! [[ "$saved_timeout" =~ ^[0-9]+$ ]]; then
                saved_timeout="15"
            fi
        fi
        
        echo "SEL_OUTPUT=\"$default_output\"" > "$tmp_sel_file"
        echo "SEL_RES=\"$default_res\"" >> "$tmp_sel_file"
        echo "SEL_RATE=\"$default_rate\"" >> "$tmp_sel_file"
        echo "SEL_SCALE=\"$default_scale\"" >> "$tmp_sel_file"
        echo "SEL_TIMEOUT=\"$saved_timeout\"" >> "$tmp_sel_file"
    fi
    
    source "$tmp_sel_file"
    
    SEL_OUTPUT="${SEL_OUTPUT:-}"
    SEL_RES="${SEL_RES:-}"
    SEL_RATE="${SEL_RATE:-}"
    
    local saved_timeout="15"
    if [ -f "$DISPLAY_STATE_DIR/timeout" ]; then
        saved_timeout=$(cat "$DISPLAY_STATE_DIR/timeout" | tr -d '[:space:]')
        if ! [[ "$saved_timeout" =~ ^[0-9]+$ ]]; then
            saved_timeout="15"
        fi
    fi
    SEL_TIMEOUT="${SEL_TIMEOUT:-$saved_timeout}"
    SEL_SCALE="${SEL_SCALE:-1.0}"
    
    local menu_options=""
    menu_options+="${PROM_MENU_OUTPUT}: $SEL_OUTPUT\n"
    menu_options+="${PROM_MENU_RES}: ${SEL_RES:-$PROM_VAL_NONE}\n"
    menu_options+="${PROM_MENU_RATE}: ${SEL_RATE:-$PROM_VAL_AUTO}\n"
    menu_options+="${PROM_MENU_SCALE}: ${SEL_SCALE}\n"
    menu_options+="${PROM_MENU_TIME}: ${SEL_TIMEOUT}s\n"
    menu_options+="${PROM_MENU_APPLY}\n"
    menu_options+="${PROM_MENU_CANCEL}"
    
    local choice=$(echo -e "$menu_options" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_MAIN")
    [ -z "$choice" ] && { rm -f "$tmp_sel_file"; exit 0; }
    
    local script_path="$(realpath "${BASH_SOURCE[0]}")"
    
    case "$choice" in
        *"$PROM_MENU_OUTPUT"*)
            local outputs=$(bash "$DISPLAY_HOOK" --query-outputs)
            local op_list=""
            while IFS= read -r op; do
                [ -z "$op" ] && continue
                op_list+="${GLYPH_MONITOR}${op}\n"
            done <<< "$outputs"
            
            local new_out=$(echo -e "$op_list" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_MONITOR}${PROM_MONITOR}")
            if [ -n "$new_out" ]; then
                new_out="${new_out#$GLYPH_MONITOR}"
                new_out=$(echo "$new_out" | tr -d '[:space:]')
                
                read -r new_res new_rate <<< $(bash "$DISPLAY_HOOK" --get-current-all "$new_out")
                local new_scale=$(bash "$DISPLAY_HOOK" --get-current-scale "$new_out")
                new_scale="${new_scale:-1.0}"
                
                echo "SEL_OUTPUT=\"$new_out\"" > "$tmp_sel_file"
                echo "SEL_RES=\"$new_res\"" >> "$tmp_sel_file"
                echo "SEL_RATE=\"$new_rate\"" >> "$tmp_sel_file"
                echo "SEL_SCALE=\"$new_scale\"" >> "$tmp_sel_file"
                echo "SEL_TIMEOUT=\"$SEL_TIMEOUT\"" >> "$tmp_sel_file"
            fi
            exec "$script_path"
            ;;
            
        *"$PROM_MENU_RES"*)
            if [ -z "$SEL_OUTPUT" ]; then
                exec "$script_path"
            fi
            local modes=$(bash "$DISPLAY_HOOK" --query-modes "$SEL_OUTPUT")
            local res_list=""
            while IFS= read -r res; do
                [ -z "$res" ] && continue
                res_list+="${GLYPH_RESOLUTION}${res}\n"
            done <<< "$modes"
            
            local new_res=$(echo -e "$res_list" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "${GLYPH_RESOLUTION}${PROM_RESOLUTION}")
            if [ -n "$new_res" ]; then
                new_res="${new_res#$GLYPH_RESOLUTION}"
                new_res=$(echo "$new_res" | tr -d '[:space:]')
                
                local new_rate=""
                
                echo "SEL_OUTPUT=\"$SEL_OUTPUT\"" > "$tmp_sel_file"
                echo "SEL_RES=\"$new_res\"" >> "$tmp_sel_file"
                echo "SEL_RATE=\"$new_rate\"" >> "$tmp_sel_file"
                echo "SEL_SCALE=\"$SEL_SCALE\"" >> "$tmp_sel_file"
                echo "SEL_TIMEOUT=\"$SEL_TIMEOUT\"" >> "$tmp_sel_file"
            fi
            exec "$script_path"
            ;;
            
        *"$PROM_MENU_RATE"*)
            if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                exec "$script_path"
            fi
            local rates=$(bash "$DISPLAY_HOOK" --query-rates "$SEL_OUTPUT" "$SEL_RES")
            if [ -z "$rates" ]; then
                exec "$script_path"
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
                
                echo "SEL_OUTPUT=\"$SEL_OUTPUT\"" > "$tmp_sel_file"
                echo "SEL_RES=\"$SEL_RES\"" >> "$tmp_sel_file"
                echo "SEL_RATE=\"$new_rate\"" >> "$tmp_sel_file"
                echo "SEL_SCALE=\"$SEL_SCALE\"" >> "$tmp_sel_file"
                echo "SEL_TIMEOUT=\"$SEL_TIMEOUT\"" >> "$tmp_sel_file"
            fi
            exec "$script_path"
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
                        exec "$script_path"
                    fi
                fi
                
                echo "SEL_OUTPUT=\"$SEL_OUTPUT\"" > "$tmp_sel_file"
                echo "SEL_RES=\"$SEL_RES\"" >> "$tmp_sel_file"
                echo "SEL_RATE=\"$SEL_RATE\"" >> "$tmp_sel_file"
                echo "SEL_SCALE=\"$new_scale\"" >> "$tmp_sel_file"
                echo "SEL_TIMEOUT=\"$SEL_TIMEOUT\"" >> "$tmp_sel_file"
            fi
            exec "$script_path"
            ;;
            
        *"$PROM_MENU_TIME"*)
            local new_time=$(echo -e "$PROM_TIMES" | "$DISP_SEL_BIN" "${DISP_SEL_ARGS_ARR[@]}" -p "$PROM_TIMEOUT")
            if [ -n "$new_time" ]; then
                new_time="${new_time%s}"
                new_time=$(echo "$new_time" | tr -d '[:space:]')
                
                mkdir -p "$DISPLAY_STATE_DIR"
                echo "$new_time" > "$DISPLAY_STATE_DIR/timeout"
                
                echo "SEL_OUTPUT=\"$SEL_OUTPUT\"" > "$tmp_sel_file"
                echo "SEL_RES=\"$SEL_RES\"" >> "$tmp_sel_file"
                echo "SEL_RATE=\"$SEL_RATE\"" >> "$tmp_sel_file"
                echo "SEL_SCALE=\"$SEL_SCALE\"" >> "$tmp_sel_file"
                echo "SEL_TIMEOUT=\"$new_time\"" >> "$tmp_sel_file"
            fi
            exec "$script_path"
            ;;
            
        *"$PROM_MENU_APPLY"*)
            if [ -z "$SEL_OUTPUT" ] || [ -z "$SEL_RES" ]; then
                rm -f "$tmp_sel_file"
                exit 1
            fi
            
            local old_res=$(bash "$DISPLAY_HOOK" --get-current "$SEL_OUTPUT" | tr -d '[:space:]')
            local old_rate=$(bash "$DISPLAY_HOOK" --get-current-rate "$SEL_OUTPUT" | tr -d '[:space:]')
            local old_scale=$(bash "$DISPLAY_HOOK" --get-current-scale "$SEL_OUTPUT" | tr -d '[:space:]')
            old_scale="${old_scale:-1.0}"
            
            echo "Aplicando previsualización: $SEL_OUTPUT -> $SEL_RES ${SEL_RATE:+@ $SEL_RATE} ${SEL_SCALE:+[x$SEL_SCALE]}"
            bash "$DISPLAY_HOOK" --apply "$SEL_OUTPUT" "$SEL_RES" "$SEL_RATE" "$SEL_SCALE"
            bash "$DISPLAY_HOOK" --post-apply
            
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
                echo "Resolución guardada permanentemente."
            else
                echo "Acción cancelada o expirada. Revirtiendo a $old_res ${old_rate:+@ $old_rate} ${old_scale:+[x$old_scale]}..."
                bash "$DISPLAY_HOOK" --apply "$SEL_OUTPUT" "$old_res" "$old_rate" "$old_scale"
                bash "$DISPLAY_HOOK" --post-apply
            fi
            
            rm -f "$tmp_sel_file"
            exit 0
            ;;
            
        *)
            rm -f "$tmp_sel_file"
            exit 0
            ;;
    esac
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
