#!/usr/bin/env bash

# Cargar utilidades compartidas y apagar instancias previas
source "$HOME/.config/polybar/scripts/detect.sh"

# Launch bar
echo "---" | tee -a /tmp/polybar1.log
polybar "$BAR_NAME" 2>&1 | tee -a /tmp/polybar1.log & disown

echo "Bars launched..."

