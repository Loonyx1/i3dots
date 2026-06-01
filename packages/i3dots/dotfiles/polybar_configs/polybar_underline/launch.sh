#!/usr/bin/env bash

# Cargar utilidades compartidas y apagar instancias previas
source "$HOME/.config/polybar/scripts/detect.sh"

# 2. Construir listas de modulos (Evita "islas" vacias si no hay hardware)
export POLY_LEFT="space left launcher right space left help-keys right space left cpu-usage space-alt cpu-memory right space left i3-workspaces right"
[ -n "$BACKLIGHT_CARD" ] && POLY_LEFT="$POLY_LEFT space left backlight right"


export POLY_CENTER="left date right"

export POLY_RIGHT="left cpu-temperature right"
[ -n "$HAS_AUDIO" ] && POLY_RIGHT="$POLY_RIGHT space space left volume right"
[ -n "$HAS_BATTERY" ] && POLY_RIGHT="$POLY_RIGHT space left battery right"
export POLY_RIGHT="$POLY_RIGHT space left tray right space"

# 3. Iniciar las nuevas instancias de forma silenciosa
polybar -q "$BAR_NAME" &
sleep 0.1

