#!/usr/bin/env bash
# detect.sh - Utilidades compartidas para lanzamiento de Polybar

CONF_DIR="$HOME/.config/polybar"

# 0. Regenerar configuración en RAM si no existe (ej. tras reinicio)
if [ ! -f "/dev/shm/user_configs.ini" ]; then
    if [ -f "$CONF_DIR/user_configs.ini.bak" ]; then
        cp "$CONF_DIR/user_configs.ini.bak" "/dev/shm/user_configs.ini"
    fi
fi

# 1. Matar instancias existentes de forma robusta
polybar-msg cmd quit 2>/dev/null
pkill polybar 2>/dev/null
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

# 2. Detectar Hardware y entorno para modulos dinamicos
export BACKLIGHT_CARD=$(ls -1 /sys/class/backlight/ | head -n 1)
export HAS_BATTERY=$(ls -1 /sys/class/power_supply/ | grep -i "BAT")
export HAS_AUDIO=$(pactl info >/dev/null 2>&1 && echo "yes")

# Detectar sensor de temperatura (hwmon)
for i in /sys/class/hwmon/hwmon*/name; do
    if grep -qE "coretemp|fam15h_power|k10temp" "$i" >/dev/null 2>&1; then
        export HWMON_PATH="$(dirname $i)/temp1_input"
        break
    fi
done
[ -z "$HWMON_PATH" ] && export HWMON_PATH=$(ls -1 /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1)

# Autodetectar nombre de la barra desde config.ini si existe
if [ -f "$CONF_DIR/current_theme/config.ini" ]; then
    export BAR_NAME=$(grep -oE '^\[bar/[a-zA-Z0-9_-]+\]' "$CONF_DIR/current_theme/config.ini" | head -n 1 | cut -d'/' -f2 | tr -d ']')
fi
[ -z "$BAR_NAME" ] && export BAR_NAME="bottom"
