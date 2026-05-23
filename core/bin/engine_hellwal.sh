#!/usr/bin/env bash

# engine_hellwal.sh - Motor de colores Hellwal inteligente
# Consume: -L (light), -D (dark), -N (m-16), -T (skip-term)

# 1. Parseo
H_MODE="dark"
H_M=0
H_SKIP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -L) H_MODE="light"; shift ;;
        -D) H_MODE="dark"; shift ;;
        -N) H_M=1; shift ;;
        -T) H_SKIP=1; shift ;;
        *) shift ;;
    esac
done

# 2. Obtener Imagen del Estado (si no se paso por argumento)
IMG_PATH=$(readlink -f "$CURRENT_WALLPAPER_LINK")
[[ ! -f "$IMG_PATH" ]] && { echo "Error: No hay wallpaper activo." >&2; exit 1; }

# 3. Motor de transicion (si existe engine_init)
# Los motores son compartidos y viven en core/engines/
local_engine="$CORE_DIR/engines/${WP_ENGINE}.sh"
if [[ -f "$local_engine" ]]; then
    source "$local_engine"
    engine_init && engine_set "$IMG_PATH"
fi

# 4. Hellwal
cmd=("hellwal" "-i" "$IMG_PATH")
[[ "$H_MODE" == "light" ]] && cmd+=("-l")
[[ "$H_M" -eq 1 ]] && cmd+=("-m")
[[ "$H_SKIP" -eq 1 ]] && cmd+=("--skip-term-colors")

if [ -d "$HELLWAL_TEMPLATES_DIR" ] && [ "$(ls -A "$HELLWAL_TEMPLATES_DIR")" ]; then
    mkdir -p "$HELLWAL_CACHE_DIR"
    cmd+=("-f" "$HELLWAL_TEMPLATES_DIR" "-o" "$HELLWAL_CACHE_DIR")
fi

"${cmd[@]}"
