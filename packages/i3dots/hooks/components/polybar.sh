#!/usr/bin/env bash
# hooks/components/polybar.sh - Versión Ultra-Optimizada (RAM + Symlinks + Icons)

# 0. Protocolo de Consulta para el Core
if [ "$1" == "--query" ]; then
    echo "themes_dir=$PACKAGE_DIR/dotfiles/polybar_configs"
    echo "default_theme=polybar_antigua"
    echo "height_options=13pt\n15pt\n18pt\n20pt"
    echo "height_unit=pt"
    echo "has_modes=true"
    exit 0
fi

# 1. Leer Estado
STYLE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/style" 2>/dev/null || echo "square")
POS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/position" 2>/dev/null || echo "$BAR_POSITION")
TRANS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/transparency" 2>/dev/null || echo "$BAR_TRANSPARENCY")
HEIGHT=$(cat "$STATE_DIR/$CURRENT_ENV/bar/height" 2>/dev/null || echo "$BAR_HEIGHT")
TYPE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/type" 2>/dev/null || echo "polybar_antigua")
MODE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/mode" 2>/dev/null || echo "solid")

# Limpiar espacios
STYLE=$(echo "$STYLE" | tr -d '[:space:]'); POS=$(echo "$POS" | tr -d '[:space:]')
TRANS=$(echo "$TRANS" | tr -d '[:space:]'); HEIGHT=$(echo "$HEIGHT" | tr -d '[:space:]')
TYPE=$(echo "$TYPE" | tr -d '[:space:]'); MODE=$(echo "$MODE" | tr -d '[:space:]')
[[ -z "$HEIGHT" ]] && HEIGHT="15pt"

# 2. Setup de Directorio con Enlaces Simbólicos
CONF_DIR="$HOME/.config/polybar"
[ -f "$CONF_DIR/colors.ini" ] && cp "$CONF_DIR/colors.ini" "/tmp/poly_colors.ini"
[ -f "$CONF_DIR/user_configs.ini.bak" ] && cp "$CONF_DIR/user_configs.ini.bak" "/tmp/poly_user_configs.ini"
rm -rf "$CONF_DIR"
mkdir -p "$CONF_DIR"

if [ -f "/tmp/poly_colors.ini" ]; then
    mv "/tmp/poly_colors.ini" "$CONF_DIR/colors.ini"
else
    ln -sf "$PACKAGE_DIR/dotfiles/polybar_base/colors.ini" "$CONF_DIR/colors.ini"
fi

if [ -f "/tmp/poly_user_configs.ini" ]; then
    mv "/tmp/poly_user_configs.ini" "$CONF_DIR/user_configs.ini.bak"
fi

ln -sf "$PACKAGE_DIR/dotfiles/polybar_base/hardware.ini" "$CONF_DIR/hardware.ini"
ln -sf "$PACKAGE_DIR/dotfiles/polybar_base/scripts" "$CONF_DIR/scripts"

THEME_SRC="$PACKAGE_DIR/dotfiles/polybar_configs/$TYPE"
if [ -d "$THEME_SRC" ]; then
    ln -sfT "$THEME_SRC" "$CONF_DIR/current_theme"
    ln -sf "current_theme/launch.sh" "$CONF_DIR/launch.sh"
    
    # Ejecutar setup.sh específico del tema si existe (evita hardcodeo)
    [ -f "$THEME_SRC/setup.sh" ] && source "$THEME_SRC/setup.sh"
fi

# 3. Preparar Variables para RAM (/dev/shm)
[ "$STYLE" == "round" ] && RADIUS=10 || RADIUS=0
[ "$POS" == "top" ] && IS_BOTTOM="false" || IS_BOTTOM="true"

# Fuentes (Matriz de escalado con soporte para Rofi y centrado vertical)
H_NUM=$(echo "$HEIGHT" | grep -oE '[0-9]+' | head -n 1)
[[ -z "$H_NUM" ]] && H_NUM=15

# Cálculo dinámico de fuentes según altura de la barra (para soporte HDPI/Custom completo)
F_TEXT=$(( H_NUM * 3 / 5 + 1 ))
F_ICON=$(( H_NUM + 1 ))
F_OFFSET=$(( (H_NUM - 6) / 3 ))
R_OFFSET=2
F_ROFI=$(( H_NUM * 6 / 5 ))
F_EXTRA=$(( H_NUM - 1 ))
F_SYM=$(( H_NUM * 4 / 5 + 1 ))
F_CURV=$(( H_NUM * 14 / 10 + 1 ))
F_CURV_OFFSET=$(( F_OFFSET + 1 ))

if [ "$TRANS" == "false" ]; then
    BG_COLOR="\${colors.background-solid}"
    P_TRANS="false"
else
    BG_COLOR="#00000000"
    P_TRANS="true"
fi

if [ "$MODE" == "underline" ]; then
    MOD_FOC_BG="\${colors.background-solid}"
    MOD_FOC_FG="\${colors.primary}"
    MOD_FOC_UND="\${colors.primary}"
    MOD_PRE_BG="\${colors.background-solid}"
    MOD_PRE_FG="\${colors.primary}"
    MOD_ROFI_BG="\${colors.primary}"
    MOD_ROFI_FG="\${colors.background-solid}"
else
    MOD_FOC_BG="\${colors.primary}"
    MOD_FOC_FG="\${colors.background-solid}"
    MOD_FOC_UND="\${colors.primary}"
    MOD_PRE_BG="\${colors.primary}"
    MOD_PRE_FG="\${colors.background-solid}"
    MOD_ROFI_BG="\${colors.primary}"
    MOD_ROFI_FG="\${colors.background-solid}"
fi

LAUNCH_ICON="${OS_ICON:-󰣆}"

# 4. Escribir en RAM
RAM_CONFIG="/dev/shm/user_configs.ini"
cat > "$RAM_CONFIG" <<EOF
[vars]
height = $HEIGHT
radius = $RADIUS
bottom = $IS_BOTTOM
pseudo-transparency = $P_TRANS
background = $BG_COLOR
font-0 = "JetBrainsMono Nerd Font Mono:style=Bold:size=$F_TEXT;$F_OFFSET"
font-1 = "Symbols Nerd Font:size=$F_CURV;$F_CURV_OFFSET"
font-2 = "JetBrainsMono Nerd Font Mono:size=$F_TEXT:antialias=false;$F_OFFSET"
font-rofi = "JetBrainsMono Nerd Font Mono:size=$F_ROFI;$R_OFFSET"
font-extra = "JetBrainsMono Nerd Font Mono:size=$F_EXTRA;$F_OFFSET"
font-firacode = "FiraCode Nerd Font:size=$F_ICON;$F_OFFSET"
font-symbols = "Symbols Nerd Font Mono:size=$F_SYM;$F_OFFSET"
font-large = "JetBrainsMono Nerd Font Mono:size=$((F_ICON + 4));$((F_OFFSET + 3))"
module-padding = 1
label-padding = 1
focused-bg = $MOD_FOC_BG
focused-fg = $MOD_FOC_FG
focused-underline = $MOD_FOC_UND
prefix-bg = $MOD_PRE_BG
prefix-fg = $MOD_PRE_FG
rofi-bg = $MOD_ROFI_BG
rofi-fg = $MOD_ROFI_FG
launcher-icon = $LAUNCH_ICON
dots-cmd = ${BASE_DIR:-$PROJECT_ROOT}/dots

; Icon Library
icon-cpu = 
icon-ram = 󰍛
icon-temp = 
icon-date = 󰃭
icon-disk = 󰋊
icon-vol = 󰕾
icon-light = 󰃠
icon-bat = 󱊣
EOF

cp "$RAM_CONFIG" "$CONF_DIR/user_configs.ini.bak"

# 5. Configuración de entrada única para Polybar
cat > "$CONF_DIR/config.ini" <<EOF
[global/wm]
include-file = \$HOME/.config/polybar/colors.ini
include-file = /dev/shm/user_configs.ini
include-file = \$HOME/.config/polybar/current_theme/config.ini
EOF

# 6. Lanzar
bash "$CONF_DIR/launch.sh" &
