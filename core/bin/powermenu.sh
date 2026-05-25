#!/usr/bin/env bash
# powermenu.sh - Módulo core "inteligentemente tonto"
# Gestiona las opciones de apagado/reinicio de forma agnóstica.

# 1. Configuración del paquete (config.env)
BIN="${POWERMENU_BIN:-rofi}"
ARGS=(${POWERMENU_ARGS})
UPTIME=$(uptime -p | sed -e 's/up //g')

# Etiquetas (Labels) - El paquete decide si usa iconos o texto
L_SHUTDOWN="${POWERMENU_LABEL_SHUTDOWN:-Shutdown}"
L_REBOOT="${POWERMENU_LABEL_REBOOT:-Reboot}"
L_SUSPEND="${POWERMENU_LABEL_SUSPEND:-Suspend}"
L_LOGOUT="${POWERMENU_LABEL_LOGOUT:-Logout}"

# 2. Ejecutar Selector
OPTIONS="$L_SUSPEND\n$L_LOGOUT\n$L_REBOOT\n$L_SHUTDOWN"
CHOSEN=$(echo -e "$OPTIONS" | "$BIN" "${ARGS[@]}" -p "UP - $UPTIME" -dmenu -selected-row 0)

[[ -z "$CHOSEN" ]] && exit 0

# 3. Ejecutar Acción
# Se usan variables para los comandos por si el paquete necesita algo específico
case "$CHOSEN" in
    "$L_SHUTDOWN") eval "${POWERMENU_CMD_SHUTDOWN:-systemctl poweroff}" ;;
    "$L_REBOOT")   eval "${POWERMENU_CMD_REBOOT:-systemctl reboot}" ;;
    "$L_SUSPEND")  eval "${POWERMENU_CMD_SUSPEND:-systemctl suspend}" ;;
    "$L_LOGOUT")
        if [ -n "$POWERMENU_CMD_LOGOUT" ]; then
            eval "$POWERMENU_CMD_LOGOUT"
        else
            loginctl terminate-session "${XDG_SESSION_ID:-}"
        fi
        ;;
esac
