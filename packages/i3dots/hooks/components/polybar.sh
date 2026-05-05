#!/usr/bin/env bash
# hooks/components/polybar.sh

# 1. Leer Estado (Estilo, Posición, Transparencia, Tema)
STYLE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/style" 2>/dev/null || echo "square")
STYLE=$(echo "$STYLE" | tr -d '[:space:]')

POS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/position" 2>/dev/null || echo "$BAR_POSITION")
POS=$(echo "$POS" | tr -d '[:space:]')

TRANS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/transparency" 2>/dev/null || echo "$BAR_TRANSPARENCY")
TRANS=$(echo "$TRANS" | tr -d '[:space:]')

HEIGHT=$(cat "$STATE_DIR/$CURRENT_ENV/bar/height" 2>/dev/null || echo "$BAR_HEIGHT")
HEIGHT=$(echo "$HEIGHT" | tr -d '[:space:]')
[[ -z "$HEIGHT" ]] && HEIGHT="15pt"

TYPE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/type" 2>/dev/null || echo "polybar_antigua")
TYPE=$(echo "$TYPE" | tr -d '[:space:]')

MODE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/mode" 2>/dev/null || echo "solid")
MODE=$(echo "$MODE" | tr -d '[:space:]')

# 2. Desplegar Archivos del Tema (Copia preservando colores de Matugen)
# Si es un enlace simbólico, lo removemos
[ -L "$HOME/.config/polybar" ] && rm "$HOME/.config/polybar"
mkdir -p "$HOME/.config/polybar"

# RESPALDAR colors.ini si existe (para no perder lo que generó Matugen hace un instante)
[ -f "$HOME/.config/polybar/colors.ini" ] && mv "$HOME/.config/polybar/colors.ini" "/tmp/poly_colors.ini"

# Limpiar contenido anterior
rm -rf "$HOME/.config/polybar"/*

# Siempre copiar la base (hardware.ini y scripts)
cp -rf "$PACKAGE_DIR/dotfiles/polybar_base/." "$HOME/.config/polybar/"

# Copiar el tema seleccionado
if [ -d "$PACKAGE_DIR/dotfiles/polybar_configs/$TYPE" ]; then
    cp -rf "$PACKAGE_DIR/dotfiles/polybar_configs/$TYPE/." "$HOME/.config/polybar/"
fi

# RESTAURAR colors.ini de Matugen
if [ -f "/tmp/poly_colors.ini" ]; then
    mv "/tmp/poly_colors.ini" "$HOME/.config/polybar/colors.ini"
fi

# 3. Lógica de Radio, Posición y Escalado de Fuente
if [ "$STYLE" == "round" ]; then
    RADIUS=10
else
    RADIUS=0
fi

if [ "$POS" == "top" ]; then
    IS_BOTTOM="false"
else
    IS_BOTTOM="true"
fi

# Cálculo dinámico de fuentes basado en la altura (HEIGHT)
H_NUM=$(echo "$HEIGHT" | grep -oE '[0-9]+' | head -n 1)
[[ -z "$H_NUM" ]] && H_NUM=15

if [ "$H_NUM" -le 15 ]; then
    F_TEXT=9; F_ICON=12; F_OFFSET=3
elif [ "$H_NUM" -le 18 ]; then
    F_TEXT=10; F_ICON=14; F_OFFSET=4
else
    F_TEXT=11; F_ICON=16; F_OFFSET=4
fi

# 4. Aplicar a config.ini
POLY_CONFIG="$HOME/.config/polybar/config.ini"
POLY_COLORS="$HOME/.config/polybar/colors.ini"
POLY_SYSTEM="$HOME/.config/polybar/system.ini"

if [ -f "$POLY_CONFIG" ]; then
    target_config="$(readlink -f "$POLY_CONFIG")"
    
    # Solo aplicar radio y fuentes dinámicas si NO es la barra antigua
    if [ "$TYPE" != "polybar_antigua" ]; then
        sed -i "s/^radius = .*/radius = $RADIUS/" "$target_config"
        sed -i "s/^font-0 = .*/font-0 = \"JetBrainsMono Nerd Font Mono:style=Bold:size=$F_TEXT;$F_OFFSET\"/" "$target_config"
        sed -i "s/^font-1 = .*/font-1 = \"JetBrainsMono Nerd Font Mono:size=$F_ICON;$F_OFFSET\"/" "$target_config"
        sed -i "s/^font-2 = .*/font-2 = \"JetBrainsMono Nerd Font Mono:size=$F_TEXT:antialias=false;$F_OFFSET\"/" "$target_config"
    fi

    sed -i "s/^bottom = .*/bottom = $IS_BOTTOM/" "$target_config"
    sed -i "s/^height = .*/height = $HEIGHT/" "$target_config"
    
    # Margenes para barra antigua
    if [ "$TYPE" == "polybar_antigua" ]; then
        sed -i "s/^module-margin = .*/module-margin = 0/" "$target_config"
        sed -i "s/^padding-left = .*/padding-left = 0/" "$target_config"
        sed -i "s/^padding-right = .*/padding-right = 0/" "$target_config"
    fi
    
    # Transparencia
    if [ "$TRANS" == "false" ]; then
        sed -i "s/^pseudo-transparency = .*/pseudo-transparency = false/" "$target_config"
    else
        sed -i "s/^pseudo-transparency = .*/pseudo-transparency = true/" "$target_config"
    fi
fi

# 5. Aplicar Color de Fondo a colors.ini
if [ -f "$POLY_COLORS" ]; then
    target_colors="$(readlink -f "$POLY_COLORS")"
    if [ "$TRANS" == "false" ]; then
        SOLID_BG=$(grep "^background-solid =" "$target_colors" | cut -d' ' -f3)
        [[ -z "$SOLID_BG" ]] && SOLID_BG="#1a1b1e"
        sed -i "s/^background = .*/background = $SOLID_BG/" "$target_colors"
    else
        sed -i "s/^background = .*/background = #00000000/" "$target_colors"
    fi
fi

# 6. Ajustar Padding Interno
POLY_MODULES="$HOME/.config/polybar/modules.ini"
if [ -f "$POLY_SYSTEM" ] || [ -f "$POLY_MODULES" ]; then
    if [ "$TYPE" == "polybar_antigua" ]; then
        TARGET_FILE="$(readlink -f "$POLY_SYSTEM")"
    else
        TARGET_FILE="$(readlink -f "$POLY_MODULES")"
    fi
    
    if [ -f "$TARGET_FILE" ] && [ "$TYPE" != "polybar_antigua" ]; then
        sed -i "s/format-padding = .*/format-padding = 1/g" "$TARGET_FILE"
        sed -i "s/format-volume-padding = .*/format-volume-padding = 1/g" "$TARGET_FILE"
        sed -i "s/format-muted-padding = .*/format-muted-padding = 1/g" "$TARGET_FILE"
        sed -i "s/format-charging-padding = .*/format-charging-padding = 1/g" "$TARGET_FILE"
        sed -i "s/format-discharging-padding = .*/format-discharging-padding = 1/g" "$TARGET_FILE"
        sed -i "s/format-full-padding = .*/format-full-padding = 1/g" "$TARGET_FILE"

        if [ -n "$OS_ICON" ]; then
            sed -i "/\[module\/launcher\]/,/format=/ s|format=.*|format=$OS_ICON|" "$TARGET_FILE"
            sed -i "/\[module\/rofi\]/,/\[/ { /format-margin =/ d; /format-font =/ d; /format-padding =/ d }" "$TARGET_FILE"
            sed -i "/\[module\/rofi\]/,/format=/ s|format=.*|format=\"$OS_ICON\"\nformat-font = 2\nformat-padding = 10px\nformat-margin-right = -7px|" "$TARGET_FILE"
        fi
    fi
fi

# 7. Ajustar i3-workspaces
if [ -f "$POLY_CONFIG" ] && [ "$TYPE" != "polybar_antigua" ]; then
    target_config="$(readlink -f "$POLY_CONFIG")"
    sed -i "s/label-focused-padding = .*/label-focused-padding = 1/g" "$target_config"
    sed -i "s/label-visible-padding = .*/label-visible-padding = 1/g" "$target_config"
    sed -i "s/label-urgent-padding = .*/label-urgent-padding = 1/g" "$target_config"
    sed -i "s/label-unfocused-padding = .*/label-unfocused-padding = 1/g" "$target_config"
fi

# 8. Transformación Underline (Solo si aplica)
if [ "$TYPE" == "polybar_underline" ] && [ -f "$POLY_MODULES" ]; then
    target_modules="$(readlink -f "$POLY_MODULES")"
    if [ "$MODE" == "underline" ]; then
        sed -i '/\[module\/i3\]/,/\[/ { /label-focused-background/d; s/label-focused-foreground.*/label-focused-foreground = ${colors.primary}/; s/label-focused-underline.*/label-focused-underline = ${colors.primary}/; /label-urgent-background/d; s/label-urgent-foreground.*/label-urgent-foreground = ${colors.white0}/; s/label-urgent-underline.*/label-urgent-underline = ${colors.red}/ }' "$target_modules"
        sed -i '/\[module\/xwindow\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.green}/ }' "$target_modules"
        sed -i '/\[module\/time\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.primary}/ }' "$target_modules"
        sed -i '/\[module\/cpu\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.green}/ }' "$target_modules"
        sed -i '/\[module\/temp\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.green}/ }' "$target_modules"
        sed -i '/\[module\/memory\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.green}/ }' "$target_modules"
        sed -i '/\[module\/filesystem\]/,/\[/ { /format-mounted-prefix-background/d; s/format-mounted-prefix-foreground.*/format-mounted-prefix-foreground = ${colors.green}/ }' "$target_modules"
        sed -i '/\[module\/pulseaudio\]/,/\[/ { /format-volume-prefix-background/d; s/format-volume-prefix-foreground.*/format-volume-prefix-foreground = ${colors.secondary}/ }' "$target_modules"
        sed -i '/\[module\/backlight\]/,/\[/ { /format-prefix-background/d; s/format-prefix-foreground.*/format-prefix-foreground = ${colors.yellow}/ }' "$target_modules"
        sed -i '/\[module\/battery\]/,/\[/ { /format-full-prefix-background/d; s/format-full-prefix-foreground.*/format-full-prefix-foreground = ${colors.green}/; /ramp-capacity-background/d; s/ramp-capacity-foreground.*/ramp-capacity-foreground = ${colors.green}/; /animation-charging-background/d; s/animation-charging-foreground.*/animation-charging-foreground = ${colors.green}/ }' "$target_modules"
    fi
fi

# 9. Lanzar
[ -f "$HOME/.config/polybar/launch.sh" ] && bash "$HOME/.config/polybar/launch.sh" &
