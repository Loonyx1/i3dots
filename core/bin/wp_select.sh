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
    mapfile -d $'\0' wallpapers_found < <(find -L "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 | sort -z)
    for i in "${!wallpapers_found[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${wallpapers_found[$i]##*/}" >&2
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
    LINE_TMPL="${WP_SEL_LINE_TMPL:-%r\x00icon\x1f%p}"

    wallpapers_found=$(find -L "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort)
    options=""
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        # Calcular ruta relativa a WALLPAPER_DIR
        rel_path="${file#$WALLPAPER_DIR/}"
        # Generar linea segun el template (%f=filename, %r=relative path, %p=path)
        line="$LINE_TMPL"
        line="${line//%f/${file##*/}}"
        line="${line//%r/$rel_path}"
        line="${line//%p/$file}"
        options+="$line\n"
    done <<< "$wallpapers_found"
    
    tmp_choice=$(mktemp)
    tmp_options=$(mktemp)

    # Escribir las opciones con escapes expandidos directamente al archivo temporal en RAM
    # printf es builtin y maneja bytes nulos reales en la redirección sin truncar
    printf "%b" "$options" > "$tmp_options"

    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        # Caso específico Rofi: requiere -format 's'
        # Usamos eval para que las comillas en WP_SEL_STYLE se interpreten correctamente
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE -format 's' < \"\$tmp_options\"" > "$tmp_choice"
    else
        # Caso genérico (Wofi, Fuzzel, etc)
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE < \"\$tmp_options\"" > "$tmp_choice"
    fi

    IFS= read -r FINAL_NAME < "$tmp_choice"
    rm -f "$tmp_choice" "$tmp_options"

    [[ -z "$FINAL_NAME" ]] && exit 1

    # Buscar coincidencia exacta, por ruta relativa o por basename
    FOUND_PATH=""
    if [[ -f "$FINAL_NAME" ]]; then
        FOUND_PATH="$FINAL_NAME"
    elif [[ -f "$WALLPAPER_DIR/$FINAL_NAME" ]]; then
        FOUND_PATH="$WALLPAPER_DIR/$FINAL_NAME"
    else
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            rel_path="${file#$WALLPAPER_DIR/}"
            base_name="${file##*/}"
            if [[ "$file" == "$FINAL_NAME" || "$rel_path" == "$FINAL_NAME" || "$base_name" == "$FINAL_NAME" ]]; then
                FOUND_PATH="$file"
                break
            fi
        done <<< "$wallpapers_found"
    fi

    if [[ -n "$FOUND_PATH" ]]; then
        FINAL_PATH="$FOUND_PATH"
    else
        FINAL_PATH="$WALLPAPER_DIR/$FINAL_NAME"
    fi
fi

# 3. Guardar Estado
if [[ -n "$FINAL_PATH" ]]; then
    # Resolver enlace simbólico a la ruta real de la imagen
    REAL_PATH=$(readlink -f "$FINAL_PATH")
    if [[ -f "$REAL_PATH" ]]; then
        FINAL_PATH="$REAL_PATH"
    fi

    mkdir -p "${CURRENT_WALLPAPER_LINK%/*}"
    ln -sf "$FINAL_PATH" "$CURRENT_WALLPAPER_LINK"
    echo "$FINAL_PATH" > "$LAST_WALLPAPER_PATH_FILE"
fi
