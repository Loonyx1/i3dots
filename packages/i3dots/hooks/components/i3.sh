#!/usr/bin/env bash
# hooks/components/i3.sh

if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi
STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
PACKAGE_DIR="${PACKAGE_DIR:-$PROJECT_ROOT/packages/i3dots}"

# Leer estado de servicios
polkit="true"
xsettingsd="true"
dex="true"

SERVICES_STATE_FILE="$STATE_DIR/i3dots/services/state.env"
if [ -f "$SERVICES_STATE_FILE" ]; then
    source "$SERVICES_STATE_FILE"
fi

AUTOSTART_FILE="$PACKAGE_DIR/config/i3/conf.d/autostart.generated"

echo "# Archivo autogenerado - NO EDITAR" > "$AUTOSTART_FILE"

if [ "$dex" = "true" ]; then
    echo "exec --no-startup-id dex --autostart --environment i3" >> "$AUTOSTART_FILE"
fi

if [ "$xsettingsd" = "true" ]; then
    echo "exec --no-startup-id xsettingsd -c \$HOME/.config/xsettingsd/xsettingsd.conf" >> "$AUTOSTART_FILE"
fi

if [ "$polkit" = "true" ]; then
    echo "exec_always --no-startup-id \$polkit_agent &" >> "$AUTOSTART_FILE"
fi

# Recargar i3 para aplicar cambios de colores y config
i3-msg reload >/dev/null 2>&1
