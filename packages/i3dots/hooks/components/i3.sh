#!/usr/bin/env bash
# hooks/components/i3.sh

# 1. Ajustes de configuración de i3
I3_AUTOSTART="$I3_CONFIG_DIR/conf.d/autostart.conf"
I3_APPEARANCE="$I3_CONFIG_DIR/conf.d/appearance.conf"

if [ -f "$I3_AUTOSTART" ] && [ -n "$POLKIT_AGENT" ]; then
    if ! grep -q "exec_always --no-startup-id $POLKIT_AGENT &" "$I3_AUTOSTART"; then
        sed -i "s|exec_always --no-startup-id .*polkit.*|exec_always --no-startup-id $POLKIT_AGENT \&|g" "$I3_AUTOSTART"
    fi
fi

if [ -f "$I3_APPEARANCE" ] && [ -n "$I3_FONT" ]; then
    if ! grep -q "font pango:$I3_FONT 9" "$I3_APPEARANCE"; then
        sed -i "s|font pango:.*|font pango:$I3_FONT 9|g" "$I3_APPEARANCE"
    fi
fi

# 2. Recargar i3 para aplicar cambios de colores y config
i3-msg reload >/dev/null 2>&1
