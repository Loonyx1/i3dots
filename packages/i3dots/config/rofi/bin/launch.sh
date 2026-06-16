#!/usr/bin/env bash
# launch.sh - Lanzador de aplicaciones (Type-3 Style-3)

# 1. Obtener la ruta del wallpaper actual
IMAGE_PATH=""
if [[ -f "$HOME/.config/i3/wall" ]]; then
    read -r IMAGE_PATH < "$HOME/.config/i3/wall"
fi

# 2. Definir el tema
THEME="$HOME/.config/rofi/themes/style-3.rasi"

# 3. Ejecutar Rofi con la imagen de fondo dinámica en el inputbar
exec rofi -show drun -theme "$THEME" -theme-str "inputbar { background-image: url(\"$IMAGE_PATH\", width); }"
