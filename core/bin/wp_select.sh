#!/usr/bin/env bash

# wp_select.sh - Selector de Wallpaper inteligente
# Consume: -C <ruta>, -CT (terminal), -U (rofi)

# 1. Parseo
W_PATH=""
USE_ROFI=0
USE_CLI=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -C) W_PATH="$2"; shift 2 ;;
        -CT) USE_CLI=1; shift ;;
        -U) USE_ROFI=1; shift ;;
        *) shift ;;
    esac
done

# 2. Seleccion
if [[ -n "$W_PATH" ]]; then
    [[ ! -f "$W_PATH" ]] && { echo "Error: $W_PATH no existe." >&2; exit 1; }
    FINAL_PATH="$W_PATH"
elif [[ "$USE_CLI" -eq 1 ]]; then
    mapfile -d $'\0' wallpapers_found < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 | sort -z)
    for i in "${!wallpapers_found[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "$(basename "${wallpapers_found[$i]}")" >&2
    done
    while true; do
        read -p "Numero (q salir): " choice >&2
        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then exit 0; fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#wallpapers_found[@]}" ]; then
            FINAL_PATH="${wallpapers_found[$((choice-1))]}"
            break
        fi
    done
else
    # Por defecto usamos el selector configurado (Rofi/Wofi/etc)
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Wallpaper" -theme "${ROFI_THEME}"})
    LINE_TMPL="${WP_SEL_LINE_TMPL:-%f\x00icon\x1f%p}"

    wallpapers_found=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort)
    options=""
    while IFS= read -r file; do
        # Generar linea segun el template (%f=filename, %p=path)
        line="$LINE_TMPL"
        line="${line//%f/$(basename "$file")}"
        line="${line//%p/$file}"
        options+="$line\n"
    done <<< "$wallpapers_found"
    
    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        # Caso específico Rofi: requiere -format 's'
        # Usamos eval para que las comillas en WP_SEL_STYLE se interpreten correctamente
        eval "FINAL_NAME=\$(echo -e \"\$options\" | \"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE -format 's')"
    else
        # Caso genérico (Wofi, Fuzzel, etc)
        eval "FINAL_NAME=\$(echo -e \"\$options\" | \"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE)"
    fi

    [[ -z "$FINAL_NAME" ]] && exit 0
    FINAL_PATH="$WALLPAPER_DIR/$FINAL_NAME"
fi

# 3. Guardar Estado
if [[ -n "$FINAL_PATH" ]]; then
    mkdir -p "$(dirname "$CURRENT_WALLPAPER_LINK")"
    ln -srf "$FINAL_PATH" "$CURRENT_WALLPAPER_LINK"
    echo "${FINAL_PATH/#$HOME/\~}" > "$LAST_WALLPAPER_PATH_FILE"
fi
