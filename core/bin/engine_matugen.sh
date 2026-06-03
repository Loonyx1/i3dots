#!/usr/bin/env bash

# engine_matugen.sh - Motor de colores Matugen para mahogara-dots
# Origen: core/bin/engine_matugen.sh
# Uso: engine_matugen.sh [-L|-D] [-T type] [-I index] [-P preference]

# 0. Asegurar que matugen esté en el PATH (especialmente para ejecuciones desde i3/cron)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# 1. Parseo de argumentos (Modo, Tipo, Indice, Preferencia)
H_MODE="dark"
H_TYPE=""
H_INDEX="1" # Por defecto 0 (más dominante) para evitar el prompt interactivo
H_PREFER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -L|--light) H_MODE="light"; shift ;;
        -D|--dark)  H_MODE="dark"; shift ;;
        -T|--type)  H_TYPE="$2"; shift 2 ;;
        -I|--index) H_INDEX="$2"; H_PREFER=""; shift 2 ;; # Index anula Prefer
        -P|--prefer) H_PREFER="$2"; H_INDEX=""; shift 2 ;; # Prefer anula Index
        *) shift ;;
    esac
done

# 2. Obtener imagen desde el estado del core
IMG_PATH=$(readlink -f "$CURRENT_WALLPAPER_LINK")

if [[ ! -f "$IMG_PATH" ]]; then
    echo "Error [engine_matugen]: No hay wallpaper activo en $CURRENT_WALLPAPER_LINK" >&2
    exit 1
fi

# 3. Localizar configuración de matugen en el paquete
MATUGEN_CONF="$PACKAGE_DIR/dotfiles/matugen/config.toml"
[[ ! -f "$MATUGEN_CONF" ]] && MATUGEN_CONF="$PACKAGE_DIR/matugen/config.toml"

# 4. Ejecución de Matugen
cmd=("matugen")

# Si existe un config.toml en el paquete, lo priorizamos
if [ -f "$MATUGEN_CONF" ]; then
    cmd+=("--config" "$MATUGEN_CONF")
fi

cmd+=("image" "$IMG_PATH" "--mode" "$H_MODE")

# Aplicar Tipo de Esquema
[ -n "$H_TYPE" ] && cmd+=("--type" "$H_TYPE")

# --- EVITAR INTERACTIVIDAD ---
# Si se especificó un índice (0-4), Matugen no pregunta
if [ -n "$H_INDEX" ]; then
    cmd+=("--source-color-index" "$H_INDEX")
    echo "Matugen: Usando color dominante índice $H_INDEX"
# Si se especificó una preferencia (saturation, darkness, etc), Matugen no pregunta
elif [ -n "$H_PREFER" ]; then
    cmd+=("--prefer" "$H_PREFER")
    echo "Matugen: Prefiriendo $H_PREFER"
fi

echo "Matugen: Procesando $IMG_PATH [Modo: $H_MODE, Tipo: ${H_TYPE:-default}]..."

# Ejecución final
exec "${cmd[@]}"
