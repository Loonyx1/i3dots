#!/usr/bin/env bash
# launcher.sh - Módulo core "inteligentemente tonto"
# Gestiona el lanzador de aplicaciones inyectando estilo dinámico si se requiere.

# 1. Parámetros del paquete (definidos en config.env)
BIN="${LAUNCHER_BIN:-rofi}"
ARGS=(${LAUNCHER_ARGS}) 
TEMPLATE="${LAUNCHER_STYLE_TEMPLATE}"
FLAG="${LAUNCHER_STYLE_FLAG:--theme-str}"

# 2. Inyectar Estilo Dinámico (ej: Wallpaper)
# Si el paquete define un template y hay un wallpaper activo
if [ -n "$TEMPLATE" ] && [ -n "$CURRENT_WALLPAPER_LINK" ] && [ -f "$CURRENT_WALLPAPER_LINK" ]; then
    IMG=$(readlink -f "$CURRENT_WALLPAPER_LINK")
    printf -v DYNAMIC_STYLE "$TEMPLATE" "$IMG"
    ARGS+=("$FLAG" "$DYNAMIC_STYLE")
fi

# 3. Ejecución
# $@ permite pasar argumentos extras desde el comando 'dots'
exec "$BIN" "${ARGS[@]}" "$@"
