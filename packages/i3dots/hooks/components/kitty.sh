#!/usr/bin/env bash
# hooks/components/kitty.sh
# Origen: packages/i3dots/hooks/components/kitty.sh

# Recargar terminales Kitty activas para actualizar colores al instante
pkill -USR1 kitty 2>/dev/null || true
