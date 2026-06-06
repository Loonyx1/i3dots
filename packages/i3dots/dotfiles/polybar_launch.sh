#!/usr/bin/env bash
# packages/i3dots/dotfiles/polybar_launch.sh - Lanzador universal de Polybar
# Copiado a ~/.config/polybar/system_launch.sh durante instalación.

# 1. Resolver Directorios de Estado de Forma Dinámica
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
    export PROJECT_ROOT=$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)
fi
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
export CURRENT_ENV="${CURRENT_ENV:-i3dots}"
BAR_STATE_DIR="$STATE_DIR/$CURRENT_ENV/bar"
STATE_FILE="$BAR_STATE_DIR/state.env"

# 2. Apagado Limpio y Rápido
polybar-msg cmd hide 2>/dev/null &
pkill -u $UID -x polybar 2>/dev/null

# 3. Detección de Hardware para Módulos Dinámicos
BACKLIGHT_CARDS=(/sys/class/backlight/*)
if [ -e "${BACKLIGHT_CARDS[0]}" ]; then
    export BACKLIGHT_CARD="${BACKLIGHT_CARDS[0]##*/}"
else
    export BACKLIGHT_CARD=""
fi

BATTERIES=(/sys/class/power_supply/*BAT*)
if [ -e "${BATTERIES[0]}" ]; then
    export HAS_BATTERY="yes"
    export BAR_BATTERY="${BATTERIES[0]##*/}"
    # Detectar cargador
    ADAPTERS=(/sys/class/power_supply/*AC*)
    [ -e "${ADAPTERS[0]}" ] && export BAR_ADAPTER="${ADAPTERS[0]##*/}"
else
    export HAS_BATTERY=""
    export BAR_BATTERY="BAT0"
    export BAR_ADAPTER="AC"
fi

export HAS_AUDIO=$(pactl info >/dev/null 2>&1 && echo "yes")

# Detectar sensor de temperatura (hwmon)
export HWMON_PATH=""
for i in /sys/class/hwmon/hwmon*/name; do
    if [ -f "$i" ]; then
        read -r name < "$i"
        if [[ "$name" =~ coretemp|fam15h_power|k10temp ]]; then
            export HWMON_PATH="${i%/*}/temp1_input"
            break
        fi
    fi
done

if [ -z "$HWMON_PATH" ]; then
    HWMONS=(/sys/class/hwmon/hwmon*/temp1_input)
    if [ -e "${HWMONS[0]}" ]; then
        export HWMON_PATH="${HWMONS[0]}"
    fi
fi

# 4. Construir Listas de Módulos (Prevención de Islas/Píldoras Vacías)
export POLY_LEFT="space left launcher right space left help-keys right space left cpu-usage space-alt cpu-memory right space left i3-workspaces right"
[ -n "$BACKLIGHT_CARD" ] && POLY_LEFT="$POLY_LEFT space left backlight right"

export POLY_CENTER="left date right"

export POLY_RIGHT="left cpu-temperature right"
[ -n "$HAS_AUDIO" ] && POLY_RIGHT="$POLY_RIGHT space space left volume right"
[ -n "$HAS_BATTERY" ] && POLY_RIGHT="$POLY_RIGHT space left battery right"
export POLY_RIGHT="$POLY_RIGHT space left tray right space"

# 5. Cargar Estado de Estilo y Exportar a Entorno
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    # Exportar variables de estado plano al entorno para uso directo de Polybar
    export BAR_HEIGHT="${height:-15pt}"
    export BAR_POSITION="${position:-bottom}"
    export BAR_STYLE="${style:-square}"
    export BAR_TRANSPARENCY="${transparency:-true}"
    export BAR_MODE="${mode:-solid}"
    export BAR_ROFI_STYLE="${rofi_style:-solid}"
    export BAR_SOLID_LINE="${solid_line:-false}"
    export BAR_ICON_PADDING="${icon_padding:-1}"
fi

# 6. Lanzar barras declaradas en config.ini
CONFIG_FILE="$HOME/.config/polybar/config.ini"
if [ -f "$CONFIG_FILE" ]; then
    # Leer todos los nombres de barra definidos en config.ini
    BARS=$(grep -oP '^\[bar/\K[^\]]+' "$CONFIG_FILE")
    
    if [ -z "$BARS" ]; then
        BARS="bottom"
    fi
    
    for bar in $BARS; do
        polybar -q "$bar" -c "$CONFIG_FILE" &
    done
fi
