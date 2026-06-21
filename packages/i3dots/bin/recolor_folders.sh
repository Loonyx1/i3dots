#!/usr/bin/env bash
set -euo pipefail

PERSIST_COLOR_FILE="${HOME}/.config/i3/last_icon_color"
BASE_FILE="${HOME}/.config/i3/icon_theme.base"

hex_darken() {
    local hex="${1}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "%02x%02x%02x" $(( r*65/100 )) $(( g*65/100 )) $(( b*65/100 ))
}

detect_base_theme() {
    local current_theme=""
    if [[ -f "${HOME}/.config/gtk-3.0/settings.ini" ]]; then
        while read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^gtk-icon-theme-name=(.*) ]]; then
                local val="${BASH_REMATCH[1]}"
                val="${val#\"}"
                val="${val%\"}"
                current_theme="$val"
                break
            fi
        done < "${HOME}/.config/gtk-3.0/settings.ini"
    fi
    [[ -z "$current_theme" ]] && current_theme="Papirus-Dark"
    
    if [[ "$current_theme" != *"-Custom" ]]; then
        echo -n "$current_theme" > "$BASE_FILE"
        echo "$current_theme"
    else
        [[ -f "$BASE_FILE" ]] && cat "$BASE_FILE" || echo "Papirus-Dark"
    fi
}

find_theme_dir() {
    local name=$1
    for path in "${HOME}/.icons/${name}" "${HOME}/.local/share/icons/${name}" "/usr/share/icons/${name}"; do
        [[ -d "$path" ]] && echo "$path" && return 0
    done
    return 1
}

apply_theme_config() {
    local theme=$1
    local mode=${2:-"full"}
    
    # GTK2 (.gtkrc-2.0) - con comillas
    [[ -f "${HOME}/.gtkrc-2.0" ]] && sed -i -E "s/^(gtk-icon-theme-name=).*/\1\"${theme}\"/" "${HOME}/.gtkrc-2.0" 2>/dev/null || true
    
    # GTK3/4 (settings.ini) - sin comillas
    local gtk_settings=()
    [[ -f "${HOME}/.config/gtk-3.0/settings.ini" ]] && gtk_settings+=("${HOME}/.config/gtk-3.0/settings.ini")
    [[ "$mode" == "full" && -f "${HOME}/.config/gtk-4.0/settings.ini" ]] && gtk_settings+=("${HOME}/.config/gtk-4.0/settings.ini")
    [[ ${#gtk_settings[@]} -gt 0 ]] && sed -i -E "s/^(gtk-icon-theme-name=).*/\1${theme}/" "${gtk_settings[@]}" 2>/dev/null || true
    
    # QT (qtct.conf) - sin comillas
    if [[ "$mode" == "full" ]]; then
        local qt_targets=()
        for conf in "${HOME}/.config/qt"{5,6}"ct/qt"{5,6}"ct.conf"; do
            [[ -f "$conf" ]] && qt_targets+=("$conf")
        done
        [[ ${#qt_targets[@]} -gt 0 ]] && sed -i -E "s/^(icon_theme=).*/\1${theme}/" "${qt_targets[@]}" 2>/dev/null || true
    fi
}

cleanup_old_themes() {
    local keep="${1:-}"
    for dir in "/dev/shm" "${HOME}/.icons"; do
        [[ ! -d "$dir" ]] && continue
        for path in "${dir}"/*-Custom; do
            [[ ! -e "$path" ]] && continue
            if [[ -z "$keep" || "$(basename "$path")" != "$keep" ]]; then
                rm -rf "$path"
            fi
        done
    done
}

main() {
    local color="${1:-}"
    if [[ "$color" == "--restore" ]]; then
        [[ ! -f "${PERSIST_COLOR_FILE}" ]] && exit 0
        color=$(<"${PERSIST_COLOR_FILE}")
    else
        [[ ! "$color" =~ ^[0-9a-fA-F]{6}$ ]] && echo "Color hex inválido" >&2 && exit 1
        echo -n "$color" > "${PERSIST_COLOR_FILE}"
    fi

    local base_theme
    base_theme=$(detect_base_theme)
    
    local original_dir
    original_dir=$(find_theme_dir "$base_theme" || echo "")
    if [[ -z "$original_dir" ]]; then
        cleanup_old_themes ""
        exit 0
    fi

    local custom_theme="${base_theme}-Custom"
    local ram_dir="/dev/shm/${custom_theme}"
    local backup_dir="${ram_dir}/places_backup"
    
    local sed_expr=""
    local color_regex=""
    case "$base_theme" in
        *Papirus*)
            local dark_color
            dark_color=$(hex_darken "$color")
            sed_expr="-e s/#5294e2/#${color}/gI -e s/#4877b1/#${dark_color}/gI -e s/#1d344f/#${dark_color}/gI"
            color_regex="#5294e2|#4877b1|#1d344f"
            ;;
        *Colloid*)
            local dark_color
            dark_color=$(hex_darken "$color")
            sed_expr="-e s/#5294e2/#${color}/gI -e s/#60c0f0/#${color}/gI -e s/#357ec7/#${dark_color}/gI"
            color_regex="#5294e2|#60c0f0|#357ec7"
            ;;
        *)
            cleanup_old_themes ""
            apply_theme_config "$base_theme" "full"
            exit 0
            ;;
    esac

    cleanup_old_themes "$custom_theme"

    if [[ -d "${backup_dir}" ]]; then
        if [[ "$base_theme" == *Papirus* && -n "$(find "${backup_dir}" -name "*green*" -print -quit 2>/dev/null)" ]] || \
           [[ "$base_theme" == *Colloid* && -n "$(find "${backup_dir}" -name "*pink*" -print -quit 2>/dev/null)" ]]; then
            rm -rf "${ram_dir}"
        fi
    fi

    if [[ ! -d "${backup_dir}" ]]; then
        mkdir -p "${backup_dir}" "${HOME}/.icons"
        ln -sfn "${ram_dir}" "${HOME}/.icons/${custom_theme}"
        
        cp "${original_dir}/index.theme" "${ram_dir}/"
        sed -i -E "s/^(Name=).*/\1${custom_theme}/; s/^(Inherits=).*/\1${base_theme},hicolor/" "${ram_dir}/index.theme"
        
        cd "$original_dir"
        local find_args=( -L . -type f -path "*/places/*" )
        if [[ "$base_theme" == *Papirus* ]]; then
            find_args+=(
                ! -path "*@2x*" ! -path "*16x16*" ! -path "*22x22*" ! -path "*24x24*" ! -path "*symbolic*"
                ! -name "*green*" ! -name "*grey*" ! -name "*orange*" ! -name "*red*" ! -name "*violet*"
                ! -name "*yellow*" ! -name "*nord*" ! -name "*indigo*" ! -name "*magenta*" ! -name "*cyan*"
                ! -name "*brown*" ! -name "*black*" ! -name "*white*" ! -name "*teal*"
                ! -name "*carmine*" ! -name "*pink*"
                ! -name "*adwaita*" ! -name "*breeze*" ! -name "*yaru*" ! -name "*elementary*" ! -name "*custom*"
                ! -name "*crash*"
            )
        elif [[ "$base_theme" == *Colloid* ]]; then
            find_args+=(
                ! -path "*@2x*" ! -path "*/16/*" ! -path "*/22/*" ! -path "*/24/*" ! -path "*symbolic*"
                ! -name "*green*" ! -name "*grey*" ! -name "*orange*" ! -name "*red*" ! -name "*violet*"
                ! -name "*yellow*" ! -name "*nord*" ! -name "*indigo*" ! -name "*magenta*" ! -name "*cyan*"
                ! -name "*brown*" ! -name "*black*" ! -name "*white*" ! -name "*teal*"
                ! -name "*pink*" ! -name "*purple*" ! -name "*blue*"
                ! -name "*crash*"
            )
        fi
        find "${find_args[@]}" -print0 2>/dev/null | xargs -0 grep -lE "$color_regex" 2>/dev/null | xargs cp -a --parents -t "${backup_dir}/" 2>/dev/null || true
    fi

    for item in "${ram_dir}"/*; do
        [[ ! -e "$item" ]] && continue
        local name
        name=$(basename "$item")
        if [[ "$name" != "places_backup" && "$name" != "index.theme" ]]; then
            rm -rf "$item"
        fi
    done
    cp -a "${backup_dir}/." "${ram_dir}/"
    
    find "${ram_dir}" -path "${backup_dir}" -prune -o -type f -name "*.svg" -print0 2>/dev/null | xargs -0 sed -i -E $sed_expr 2>/dev/null || true
    gtk-update-icon-cache -f -q -t "${ram_dir}" 2>/dev/null || true

    apply_theme_config "hicolor" "quick"
    sleep 0.1
    apply_theme_config "$custom_theme" "full"
}

main "$@"
