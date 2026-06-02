#!/usr/bin/env bash

# Cargar utilidades compartidas y apagar instancias previas
source "$HOME/.config/polybar/scripts/detect.sh"

# Launch bar
echo "---" >> /tmp/polybar1.log
polybar "$BAR_NAME" >> /tmp/polybar1.log 2>&1 &

echo "Bars launched..."

