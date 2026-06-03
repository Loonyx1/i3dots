#!/usr/bin/env bash

# Cargar utilidades compartidas y apagar instancias previas
source "$HOME/.config/polybar/scripts/detect.sh"

# Launch bar
exec polybar "$BAR_NAME" >> /tmp/polybar1.log 2>&1

