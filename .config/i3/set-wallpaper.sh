#!/bin/bash
# set-wallpaper.sh - Applies wallpaper + dynamic colors in i3

WALLPAPER="$HOME/default.png"
CONFIG_DIR="$HOME/.config/i3"
CONFIG_FILE="$CONFIG_DIR/config"

# 🔹 Validate that the image exists
if [[ ! -f "$WALLPAPER" ]]; then
    echo "❌ Error: Image not found: $WALLPAPER"
    exit 1
fi

# 🔹 Apply wallpaper with feh
feh --bg-fill "$WALLPAPER"

# 🔹 Update app themes with real matugen
if command -v matugen &> /dev/null; then
    echo "🎨 Generando colores con Matugen..."
    matugen image "$WALLPAPER"
else
    echo "⚠️ Matugen no encontrado, saltando generación de colores"
fi

# 🔹 Reload i3 to apply new colors (silent)
i3-msg reload 2>/dev/null || true

echo "Wallpaper applied: $WALLPAPER"
