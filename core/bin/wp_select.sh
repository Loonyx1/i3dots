#!/usr/bin/env bash

# wp_select.sh - Gestor de Wallpaper (Backend Core)
# Uso: wp_select.sh -C <ruta_o_nombre> | -L (listar)

W_PATH=""
LIST_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -C) W_PATH="$2"; shift 2 ;;
        -L|--list) LIST_MODE=1; shift ;;
        *) shift ;;
    esac
done

# Acción 1: Listar wallpapers (Agnóstico de UI)
if [[ "$LIST_MODE" -eq 1 ]]; then
    find -L "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort
    exit 0
fi

# Acción 2: Aplicar wallpaper (con resolución inteligente de ruta/nombre)
if [[ -n "$W_PATH" ]]; then
    FOUND_PATH=""
    if [[ -f "$W_PATH" ]]; then
        FOUND_PATH="$W_PATH"
    elif [[ -f "$WALLPAPER_DIR/$W_PATH" ]]; then
        FOUND_PATH="$WALLPAPER_DIR/$W_PATH"
    else
        # Buscar coincidencia exacta por ruta relativa o por basename
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            rel_path="${file#$WALLPAPER_DIR/}"
            base_name="${file##*/}"
            if [[ "$file" == "$W_PATH" || "$rel_path" == "$W_PATH" || "$base_name" == "$W_PATH" ]]; then
                FOUND_PATH="$file"
                break
            fi
        done < <(find -L "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort)
    fi

    if [[ -z "$FOUND_PATH" ]]; then
        echo "Error: Wallpaper '$W_PATH' no encontrado en el sistema." >&2
        exit 1
    fi
    
    # Resolver enlace simbólico a la ruta real de la imagen
    FINAL_PATH=$(readlink -f "$FOUND_PATH")

    # Guardar Estado
    [[ -d "${CURRENT_WALLPAPER_LINK%/*}" ]] || mkdir -p "${CURRENT_WALLPAPER_LINK%/*}"
    ln -sf "$FINAL_PATH" "$CURRENT_WALLPAPER_LINK"
    echo "$FINAL_PATH" > "$LAST_WALLPAPER_PATH_FILE"

    # Aplicar motor de wallpaper
    if [[ -z "$CORE_DIR" ]]; then
        local real_script=$(readlink -f "${BASH_SOURCE[0]}")
        local script_dir=$(dirname "$real_script")
        CORE_DIR=$(dirname "$script_dir")
    fi
    local_engine="$CORE_DIR/engines/${WP_ENGINE}.sh"
    if [[ -f "$local_engine" ]]; then
        source "$local_engine"
        engine_init && engine_set "$FINAL_PATH"
    fi
    exit 0
fi

echo "Error: wp_select.sh requiere -C <ruta> o -L" >&2
exit 1
