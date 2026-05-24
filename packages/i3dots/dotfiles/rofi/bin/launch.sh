#!/usr/bin/env bash
# launch.sh - Lanzador de aplicaciones (Type-3 Style-3)

# 1. Obtener la ruta del wallpaper actual
IMAGE_PATH="$HOME/.local/share/i3dots/core/state/i3/current"
[ ! -f "$IMAGE_PATH" ] && IMAGE_PATH="$HOME/wall/wall.png"

# 2. Definir el tema
THEME="$HOME/.config/rofi/themes/style-3.rasi"

# 3. Ejecutar Rofi con la imagen de fondo dinámica en el inputbar
rofi -show drun -theme "$THEME" -theme-str "inputbar { background-image: url(\"$IMAGE_PATH\", width); }"
