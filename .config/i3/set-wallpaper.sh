#!/bin/bash
# set-wallpaper.sh - Applies wallpaper + dynamic colors in i3 with mini-matugen-j

WALLPAPER="$HOME/default.png"
CONFIG_DIR="$HOME/.config/i3"
COLORS_FILE="$CONFIG_DIR/colors.generated"
CONFIG_FILE="$CONFIG_DIR/config"
MATUGEN="$CONFIG_DIR/mini-matugen-j"

# 🔹 Validate that the binary exists
if [[ ! -x "$MATUGEN" ]]; then
    echo "❌ Error: mini-matugen-j not found or not executable at $MATUGEN"
    exit 1
fi

# 🔹 Validate that the image exists
if [[ ! -f "$WALLPAPER" ]]; then
    echo "❌ Error: Image not found: $WALLPAPER"
    exit 1
fi

# 🔹 Extract colors from wallpaper
OUTPUT=$($MATUGEN "$WALLPAPER" 6 2>/dev/null)

# 🔹 Extract HEX colors (with fallback if parsing fails)
C1=$(echo "$OUTPUT" | grep "Color # 1:" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)
C2=$(echo "$OUTPUT" | grep "Color # 2:" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)
C3=$(echo "$OUTPUT" | grep "Color # 3:" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)
C4=$(echo "$OUTPUT" | grep "Color # 4:" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)

# 🔹 Fallback to default colors if something fails
C1=${C1:-#1A1C27}
C2=${C2:-#FB9172}
C3=${C3:-#CCC7C3}
C4=${C4:-#434A6B}

# 🔹 Generate color file for i3 (ONLY window variables)
cat > "$COLORS_FILE" << EOF
# colors.generated - AUTO-GENERATED
set \$bg $C1
set \$accent $C2
set \$text $C3
set \$secondary $C4

# Windows
client.focused \$accent \$accent \$bg #FFFFFF \$accent
client.focused_inactive \$bg \$bg #FFFFFF \$secondary \$bg
client.unfocused \$bg \$bg #FFFFFF \$secondary \$bg
client.urgent #f44336 #f44336 #ffffff #ffffff #f44336
EOF

# 🔹 If nobar=true, do NOT configure i3bar
if [[ "$1" == "nobar=true" ]]; then
    echo "Nobar mode enabled - i3bar NOT configured"
else
    # 🔹 Inject HARDCODED colors directly into bar block in config
    # (i3bar CANNOT read variables defined with set)

    # Create temporary backup
    TEMP_CONFIG=$(mktemp)

    # Use sed to replace only color lines in the bar block
    sed -e "s|background \$bar_bg|background $C1|" \
        -e "s|statusline \$bar_fg|statusline #FFFFFF|" \
        -e "s|separator \$bar_sep|separator $C4|" \
        -e "s|focused_workspace \$bar_ws_active \$bar_ws_active \$bg|focused_workspace $C2 $C2 $C1|" \
        -e "s|active_workspace \$secondary \$secondary \$text|active_workspace $C4 $C4 $C3|" \
        -e "s|inactive_workspace \$bar_bg \$bar_bg \$text|inactive_workspace $C1 $C1 $C3|" \
        -e "s|binding_mode \$bar_ws_active \$bar_ws_active \$bg|binding_mode $C2 $C2 $C1|" \
        "$CONFIG_FILE" > "$TEMP_CONFIG"

    # Only replace if sed was successful
    if [[ $? -eq 0 ]] && [[ -s "$TEMP_CONFIG" ]]; then
        mv "$TEMP_CONFIG" "$CONFIG_FILE"
        echo "i3bar configured with hardcoded colors in config"
    else
        echo "⚠️ Error generating config, using original"
        rm -f "$TEMP_CONFIG"
    fi
fi

# 🔹 Apply wallpaper with feh
feh --bg-fill "$WALLPAPER"

# 🔹 Reload i3 to apply new colors (silent)
i3-msg reload 2>/dev/null || true

echo "Wallpaper applied: $WALLPAPER"
echo "Colors: $COLORS_FILE"
echo "   • Background: $C1  • Accent: $C2  • Text: $C3  • Secondary: $C4"
