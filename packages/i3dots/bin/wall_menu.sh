#!/usr/bin/env bash
# packages/i3dots/bin/wall_menu.sh - Menú interactivo de selección de Wallpapers (Frontend)

# 1. Parseo de argumentos
USE_CLI=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -CT) USE_CLI=1; shift ;;
        *) shift ;;
    esac
done

# 2. Buscar wallpapers disponibles llamando al backend
wallpapers_found=$(wp_select.sh -L)

if [[ -z "$wallpapers_found" ]]; then
    echo "Error: No se obtuvieron wallpapers desde wp_select.sh" >&2
    exit 1
fi

SELECTION=""

# 3. Presentar Menú interactivo
if [[ "$USE_CLI" -eq 1 ]]; then
    # Modo Consola (CLI)
    mapfile -t wallpapers <<< "$wallpapers_found"
    for i in "${!wallpapers[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${wallpapers[$i]##*/}" >&2
    done
    while true; do
        read -p "Numero (q salir): " choice >&2
        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then exit 1; fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#wallpapers[@]}" ]; then
            SELECTION="${wallpapers[$((choice-1))]}"
            break
        fi
    done
else
    # Modo Gráfico (GUI - Rofi)
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Wallpaper" -theme "${ROFI_THEME}"})
    LINE_TMPL="${WP_SEL_LINE_TMPL:-%f\x00icon\x1f%p}"

    tmp_rofi_opts=$(mktemp)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        rel_path="${file#$WALLPAPER_DIR/}"
        line="$LINE_TMPL"
        line="${line//%f/${file##*/}}"
        line="${line//%r/$rel_path}"
        line="${line//%p/$file}"
        printf "%b\n" "$line"
    done <<< "$wallpapers_found" > "$tmp_rofi_opts"

    tmp_choice=$(mktemp)
    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE -format 's' < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    else
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    fi

    IFS= read -r FINAL_NAME < "$tmp_choice"
    rm -f "$tmp_choice" "$tmp_rofi_opts"

    [[ -z "$FINAL_NAME" ]] && exit 1
    SELECTION="$FINAL_NAME"
fi

# 4. Invocar Backend para aplicar y guardar estado
if [[ -n "$SELECTION" ]]; then
    wp_select.sh -C "$SELECTION"
    exit $?
else
    exit 1
fi
