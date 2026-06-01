#!/usr/bin/env bash
# hooks/components/polybar.sh - Versión Ultra-Optimizada (RAM + Symlinks + Icons)

# 0. Protocolo de Consulta para el Core
if [ "$1" == "--query" ]; then
    CUR_TYPE="${2:-$(cat "$STATE_DIR/$CURRENT_ENV/bar/type" 2>/dev/null || echo "polybar_antigua")}"
    CUR_TYPE=$(echo "$CUR_TYPE" | tr -d '[:space:]')
    THEME_SRC="$PACKAGE_DIR/dotfiles/polybar_configs/$CUR_TYPE"
    
    # Resolver defaults según entorno
    DEF_HEIGHT="${BAR_HEIGHT:-15pt}"
    DEF_STYLE="${BAR_STYLE:-square}"
    DEF_POS="${BAR_POSITION:-bottom}"
    DEF_TRANS="${BAR_TRANSPARENCY:-true}"
    
    # Formatear opciones con el default al inicio para fallback seguro del motor
    HEIGHT_OPTS="$DEF_HEIGHT"
    for h in 13pt 15pt 18pt 20pt; do
        [[ "$h" != "$DEF_HEIGHT" ]] && HEIGHT_OPTS="$HEIGHT_OPTS,$h"
    done
    HEIGHT_OPTS="$HEIGHT_OPTS,custom"
    
    [[ "$DEF_STYLE" == "round" ]] && STYLE_OPTS="round,square" || STYLE_OPTS="square,round"
    [[ "$DEF_POS" == "top" ]] && POS_OPTS="top,bottom" || POS_OPTS="bottom,top"
    [[ "$DEF_TRANS" == "false" ]] && TRANS_OPTS="false,true" || TRANS_OPTS="true,false"
    
    SUPPORTED="height:Height:$HEIGHT_OPTS|style:Style:$STYLE_OPTS|position:Position:$POS_OPTS|transparency:Transparency:$TRANS_OPTS"
    if [ -f "$THEME_SRC/options.conf" ]; then
        CUSTOM_OPTS=$(grep -v '^#' "$THEME_SRC/options.conf" | grep -v '^$' | paste -sd '|' -)
        if [ -n "$CUSTOM_OPTS" ]; then
            SUPPORTED="$SUPPORTED|$CUSTOM_OPTS"
        fi
    fi

    echo "themes_dir=$PACKAGE_DIR/dotfiles/polybar_configs"
    echo "default_theme=polybar_antigua"
    echo "primary_key=type"
    echo "variant_keys=mode"
    echo "supported_options=$SUPPORTED"
    exit 0
fi

# 1. Leer Estado
STYLE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/style" 2>/dev/null || echo "square")
POS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/position" 2>/dev/null || echo "$BAR_POSITION")
TRANS=$(cat "$STATE_DIR/$CURRENT_ENV/bar/transparency" 2>/dev/null || echo "$BAR_TRANSPARENCY")
HEIGHT=$(cat "$STATE_DIR/$CURRENT_ENV/bar/height" 2>/dev/null || echo "$BAR_HEIGHT")
TYPE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/type" 2>/dev/null || echo "${BAR_DEFAULT_TYPE:-polybar_antigua}")

TYPE=$(echo "$TYPE" | tr -d '[:space:]')
THEME_SRC="$PACKAGE_DIR/dotfiles/polybar_configs/$TYPE"

# Forzar valores por defecto para opciones no soportadas por el tema
if [ -f "$THEME_SRC/options.conf" ] && grep -q '^mode:' "$THEME_SRC/options.conf"; then
    MODE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/mode" 2>/dev/null || echo "solid")
else
    MODE="solid"
fi

if [ -f "$THEME_SRC/options.conf" ] && grep -q '^rofi_style:' "$THEME_SRC/options.conf"; then
    ROFI_STYLE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/rofi_style" 2>/dev/null || echo "solid")
else
    ROFI_STYLE="solid"
fi

if [ -f "$THEME_SRC/options.conf" ] && grep -q '^solid_line:' "$THEME_SRC/options.conf"; then
    SOLID_LINE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/solid_line" 2>/dev/null || echo "true")
else
    SOLID_LINE="false"
fi

if [ -f "$THEME_SRC/options.conf" ] && grep -q '^icon_padding:' "$THEME_SRC/options.conf"; then
    ICON_PADDING=$(cat "$STATE_DIR/$CURRENT_ENV/bar/icon_padding" 2>/dev/null || echo "1")
else
    ICON_PADDING="1"
fi

# Limpiar espacios
STYLE=$(echo "$STYLE" | tr -d '[:space:]'); POS=$(echo "$POS" | tr -d '[:space:]')
TRANS=$(echo "$TRANS" | tr -d '[:space:]'); HEIGHT=$(echo "$HEIGHT" | tr -d '[:space:]')
MODE=$(echo "$MODE" | tr -d '[:space:]')
ROFI_STYLE=$(echo "$ROFI_STYLE" | tr -d '[:space:]')
SOLID_LINE=$(echo "$SOLID_LINE" | tr -d '[:space:]')
ICON_PADDING=$(echo "$ICON_PADDING" | tr -d '[:space:]')
[[ -z "$HEIGHT" ]] && HEIGHT="15pt"
[[ -z "$ICON_PADDING" ]] && ICON_PADDING="1"

# 2. Setup de Directorio con Enlaces Simbólicos
CONF_DIR="$HOME/.config/polybar"
[ -f "$CONF_DIR/colors.ini" ] && cp "$CONF_DIR/colors.ini" "/tmp/poly_colors.ini"
[ -f "$CONF_DIR/user_configs.ini.bak" ] && cp "$CONF_DIR/user_configs.ini.bak" "/tmp/poly_user_configs.ini"

# Borrado selectivo para preservar configuraciones propias del usuario
rm -f "$CONF_DIR/hardware.ini" "$CONF_DIR/launch.sh" "$CONF_DIR/current_theme" "$CONF_DIR/config.ini" "$CONF_DIR/colors.ini"
rm -rf "$CONF_DIR/scripts"
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
H_NUM="${HEIGHT//[!0-9]/}"
[[ -z "$H_NUM" ]] && H_NUM=15

# Cálculo dinámico de fuentes según altura de la barra (para soporte HDPI/Custom completo)
F_TEXT=$(( H_NUM * 3 / 5 + 1 ))
F_ICON=$(( H_NUM + 1 ))
F_OFFSET=$(( (H_NUM - 6) / 3 ))
F_EXTRA=$(( H_NUM - 1 ))
F_SYM=$(( H_NUM * 4 / 5 + 1 ))
F_CURV=$(( H_NUM * 14 / 10 + 1 ))
F_CURV_OFFSET=$(( F_OFFSET + 1 ))

# Valores por defecto para Rofi (font-rofi)
F_ROFI_SIZE=$(( H_NUM * 4 / 5 + 1 ))
R_ROFI_OFFSET=$F_OFFSET
F_ROFI_NAME="Symbols Nerd Font Mono"

if [ "$MODE" == "underline" ] || [ "$SOLID_LINE" == "true" ]; then
    LINE_SIZE=$(( H_NUM / 6 ))
    [[ $LINE_SIZE -lt 2 ]] && LINE_SIZE=2
else
    LINE_SIZE=0
fi



if [ "$MODE" == "underline" ]; then
    F_SYM=$(( H_NUM * 11 / 20 + 1 ))
    F_ICON=$(( H_NUM * 3 / 4 ))
    F_LARGE_SIZE=$(( F_SYM + 2 ))
    
    F_OFFSET_TEXT=$(( (H_NUM - LINE_SIZE - F_TEXT) / 2 ))
    [[ $F_OFFSET_TEXT -lt 0 ]] && F_OFFSET_TEXT=0
    
    F_OFFSET_SYM=$(( (H_NUM - LINE_SIZE - F_SYM) / 2 - LINE_SIZE ))
    
    F_OFFSET_LARGE=$(( (H_NUM - LINE_SIZE - F_LARGE_SIZE) / 2 ))
    [[ $F_OFFSET_LARGE -lt 0 ]] && F_OFFSET_LARGE=0
    
    F_CURV_OFFSET=$F_OFFSET_TEXT
    [[ $F_CURV_OFFSET -lt 1 ]] && F_CURV_OFFSET=1
else
    F_SYM=$(( H_NUM * 13 / 20 + 1 ))
    F_OFFSET_SYM=$(( (H_NUM - F_SYM) / 2 ))
    [[ $F_OFFSET_SYM -lt 0 ]] && F_OFFSET_SYM=0
    F_LARGE_SIZE=$(( F_ICON + 4 ))
    F_OFFSET_TEXT=$(( (H_NUM - LINE_SIZE - F_TEXT) / 2 ))
    [[ $F_OFFSET_TEXT -lt 0 ]] && F_OFFSET_TEXT=0
    F_OFFSET_LARGE=$(( F_OFFSET_TEXT + 2 ))
fi

if [ "$TRANS" == "false" ]; then
    BG_COLOR="\${colors.background-solid}"
    P_TRANS="false"
else
    BG_COLOR="#00000000"
    P_TRANS="true"
fi

if [ "$MODE" == "underline" ]; then
    MOD_FOC_BG="$BG_COLOR"
    MOD_FOC_FG="\${colors.primary}"
    MOD_FOC_UND="\${colors.primary}"
    MOD_PRE_BG="$BG_COLOR"
    MOD_PRE_FG="\${colors.primary}"
    
    if [ "$ROFI_STYLE" == "underline" ]; then
        MOD_ROFI_BG="$BG_COLOR"
        MOD_ROFI_FG="\${colors.primary}"
        MOD_ROFI_UND="\${colors.primary}"
        MOD_ROFI_FONT=5
        LAUNCH_ICON=$'\u00a0'"${OS_ICON:-󰣆}"$'\u00a0'
    else
        MOD_ROFI_BG="\${colors.primary}"
        MOD_ROFI_FG="\${colors.background-solid}"
        MOD_ROFI_UND=""
        MOD_ROFI_FONT=4
        LAUNCH_ICON=$'\u00a0\u00a0'"${OS_ICON:-󰣆}"$'\u00a0\u00a0'
        # Rofi solid en barra underline: usar métricas del estilo solid normal
        F_ROFI_SIZE=$(( H_NUM * 13 / 20 + 1 ))
        R_ROFI_OFFSET=$(( (H_NUM - F_ROFI_SIZE) / 2 ))
        [[ $R_ROFI_OFFSET -lt 0 ]] && R_ROFI_OFFSET=0
    fi
else
    MOD_FOC_BG="\${colors.primary}"
    MOD_FOC_FG="\${colors.background-solid}"
    MOD_FOC_UND=""
    MOD_PRE_BG="\${colors.primary}"
    MOD_PRE_FG="\${colors.background-solid}"
    
    MOD_ROFI_BG="\${colors.primary}"
    MOD_ROFI_FG="\${colors.background-solid}"
    MOD_ROFI_UND=""
    MOD_ROFI_FONT=5
    LAUNCH_ICON=$'\u00a0\u00a0'"${OS_ICON:-󰣆}"$'\u00a0\u00a0'
fi

# 4. Escribir en RAM
RAM_CONFIG="/dev/shm/user_configs.ini"
cat > "$RAM_CONFIG" <<EOF
[vars]
height = $HEIGHT
radius = $RADIUS
bottom = $IS_BOTTOM
pseudo-transparency = $P_TRANS
background = $BG_COLOR
line-size = ${LINE_SIZE}pt
font-0 = "JetBrainsMono Nerd Font Mono:style=Bold:size=$F_TEXT;$F_OFFSET_TEXT"
font-1 = "Symbols Nerd Font:size=$F_CURV;$F_CURV_OFFSET"
font-2 = "JetBrainsMono Nerd Font Mono:size=$F_TEXT:antialias=false;$F_OFFSET_TEXT"
font-rofi = "$F_ROFI_NAME:size=$F_ROFI_SIZE;$R_ROFI_OFFSET"
font-extra = "JetBrainsMono Nerd Font Mono:size=$F_EXTRA;$F_OFFSET_TEXT"
font-firacode = "FiraCode Nerd Font:size=$F_ICON;$F_OFFSET_TEXT"
font-symbols = "Symbols Nerd Font Mono:size=$F_SYM;$F_OFFSET_SYM"
font-large = "JetBrainsMono Nerd Font Mono:size=$F_LARGE_SIZE;$F_OFFSET_LARGE"
module-padding = 1
label-padding = 1
icon-padding = $ICON_PADDING
focused-bg = $MOD_FOC_BG
focused-fg = $MOD_FOC_FG
focused-underline = $MOD_FOC_UND
prefix-bg = $MOD_PRE_BG
prefix-fg = $MOD_PRE_FG
rofi-bg = $MOD_ROFI_BG
rofi-fg = $MOD_ROFI_FG
rofi-underline = $MOD_ROFI_UND
rofi-font = $MOD_ROFI_FONT
launcher-icon = $LAUNCH_ICON
launcher-icon-raw = ${OS_ICON:-󰣆}
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

[module/help-keys]
type = custom/text
format = "  Atajos "
format-foreground = \${colors.primary}
format-background = \${colors.background-alt}
click-left = \${vars.dots-cmd} i3dots show_cheatsheet.sh
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
if [ -x "$CONF_DIR/launch.sh" ] && [ -n "$DISPLAY" ]; then
    bash "$CONF_DIR/launch.sh" >/tmp/polybar.log 2>&1 &
fi
