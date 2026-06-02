#!/usr/bin/env bash
# detect.sh - Utilidades compartidas para lanzamiento de Polybar

CONF_DIR="$HOME/.config/polybar"

# 0. Regenerar configuración en RAM si no existe (ej. tras reinicio)
if [ ! -f "/dev/shm/user_configs.ini" ]; then
    if [ -f "$CONF_DIR/user_configs.ini.bak" ]; then
        cp "$CONF_DIR/user_configs.ini.bak" "/dev/shm/user_configs.ini"
    fi
fi

# 1. Ocultar instancias existentes de forma instantánea
polybar-msg cmd hide 2>/dev/null &

# 2. Matar instancias existentes de forma limpia
pkill -u $UID -x polybar 2>/dev/null

# 2. Detectar Hardware y entorno para modulos dinamicos
BACKLIGHT_CARDS=(/sys/class/backlight/*)
if [ -e "${BACKLIGHT_CARDS[0]}" ]; then
    export BACKLIGHT_CARD="${BACKLIGHT_CARDS[0]##*/}"
else
    export BACKLIGHT_CARD=""
fi

BATTERIES=(/sys/class/power_supply/*BAT*)
if [ -e "${BATTERIES[0]}" ]; then
    export HAS_BATTERY="yes"
else
    export HAS_BATTERY=""
fi

export HAS_AUDIO=$(pactl info >/dev/null 2>&1 && echo "yes")

# Detectar sensor de temperatura (hwmon)
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
    else
        export HWMON_PATH=""
    fi
fi

# Autodetectar nombre de la barra desde config.ini si existe
if [ -f "$CONF_DIR/current_theme/config.ini" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[bar/([a-zA-Z0-9_-]+)\] ]]; then
            export BAR_NAME="${BASH_REMATCH[1]}"
            break
        fi
    done < "$CONF_DIR/current_theme/config.ini"
fi
[ -z "$BAR_NAME" ] && export BAR_NAME="bottom"
