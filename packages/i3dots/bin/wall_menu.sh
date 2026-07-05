#!/usr/bin/env bash
# packages/i3dots/bin/wall_menu.sh - Menú interactivo y gestor de Wallpapers (Frontend)

# 1. Parseo de argumentos
USE_CLI=0
CACHE_NOW=0
CLEAN_CACHE=0
CLEAN_ARG=""
MANAGE_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -CT) USE_CLI=1; shift ;;
        -CN|--cache-now) CACHE_NOW=1; shift ;;
        -CC|--clean-cache) 
            CLEAN_CACHE=1
            CLEAN_ARG="$2"
            shift; [[ $# -gt 0 ]] && shift
            ;;
        -M|--manage) MANAGE_MODE=1; shift ;;
        *) shift ;;
    esac
done

# 2. Cargar entorno y lógica compartida
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wp_shared.sh"

# Si habilitado, pero no hay vips, desactivar
if [[ "$THUMB_MODE" == "enabled" && "$HAS_VIPS" -eq 0 ]]; then
    THUMB_MODE="disabled"
    if command -v notify-send &>/dev/null; then
        notify-send "Wallpaper" "Advertencia: Instala libvips (vipsthumbnail) para optimización de caché." -i dialog-warning -t 5000
    else
        echo "Advertencia: Comando 'vipsthumbnail' no encontrado. Desactivando caché de miniaturas." >&2
    fi
fi

# Cargar traducciones e iconos del entorno con fallbacks
PROM_THUMBS="${WP_PROM_THUMBS:-Miniaturas en caché}"
PROM_QUALITY="${WP_PROM_QUALITY:-Calidad de Miniaturas}"
PROM_NO_THUMB="${WP_PROM_NO_THUMB:-Si falta miniatura}"
PROM_BG_GEN="${WP_PROM_BG_GEN:-Pre-caché}"
PROM_CLEAN="${WP_PROM_CLEAN:-Limpiar Caché de Miniaturas}"

# La función save_state ahora es provista por wp_shared.sh

# 4. Modo Headless: Delegar a wp_cache.sh
if [[ "$CACHE_NOW" -eq 1 ]]; then
    wp_cache.sh --cache-now
    exit $?
fi

if [[ "$CLEAN_CACHE" -eq 1 ]]; then
    wp_cache.sh --clean-cache "$CLEAN_ARG"
    exit $?
fi

# 5. Menú Dedicado de Ajustes de Rofi (--manage)
if [[ "$MANAGE_MODE" -eq 1 ]]; then
    # Cargar variables de visualización de Rofi para configuración
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    LAUNCHER_THEME="${WP_MANAGE_THEME:-${ROFI_THEME:-$HOME/.config/rofi/themes/launcher.rasi}}"
    SEL_ARGS_ARR=("-dmenu" "-theme" "$LAUNCHER_THEME")

    # Función genérica para solicitar selección en Rofi/dmenu
    ask_selection() {
        local prompt="$1"
        local options="$2"
        local choice_tmp="/dev/shm/wall_menu_ask_${UID}.choice"
        if [[ "$SEL_BIN" == *"rofi"* ]]; then
            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$prompt\" -format 's' <<< \"\$options\"" > "$choice_tmp"
        else
            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$prompt\" <<< \"\$options\"" > "$choice_tmp"
        fi
        local choice=""
        [[ -f "$choice_tmp" ]] && read -r choice < "$choice_tmp"
        rm -f "$choice_tmp"
        echo "$choice"
    }

    # Variables de estado compartidas localmente entre las funciones del submenú
    local cur_show_names_mode="all"
    local cur_card_style="false"
    local cur_join_text="false"
    local cur_ind_text="true"
    local cur_ind_block="false"
    local cur_ind_border="false"
    local cur_ind_underline="false"
    local cur_ind_halo="false"
    local cur_thumb_mode=""
    local cur_thumb_size=""
    local cur_no_thumb=""
    local cur_bg_gen=""
    local cur_matugen_thumb=""
    local cur_thumb_crop_mode=""
    local cur_matugen_clean_temp=""
    local cur_matugen_use_fit=""

    menu_indicadores() {
        while true; do
            local ind_text_lbl="desactivado"
            [[ "$cur_ind_text" == "true" ]] && ind_text_lbl="activado"
            local ind_block_lbl="desactivado"
            [[ "$cur_ind_block" == "true" ]] && ind_block_lbl="activado"
            local ind_border_lbl="desactivado"
            [[ "$cur_ind_border" == "true" ]] && ind_border_lbl="activado"
            local ind_under_lbl="desactivado"
            [[ "$cur_ind_underline" == "true" ]] && ind_under_lbl="activado"
            local ind_halo_lbl="desactivado"
            [[ "$cur_ind_halo" == "true" ]] && ind_halo_lbl="activado"

            local sub_opts=""
            sub_opts+="Texto coloreado: $ind_text_lbl"$'\n'
            sub_opts+="Bloque de texto: $ind_block_lbl"$'\n'
            sub_opts+="Borde de imagen: $ind_border_lbl"$'\n'
            sub_opts+="Subrayado de imagen: $ind_under_lbl"$'\n'
            sub_opts+="Halo de fondo: $ind_halo_lbl"$'\n'
            sub_opts+="Atrás"

            local sub_choice=$(ask_selection "Indicadores" "$sub_opts")
            [[ -z "$sub_choice" || "$sub_choice" == "Atrás" ]] && break

            local key=""
            local val=""
            case "$sub_choice" in
                "Texto coloreado"*) key="ind_text"; val="$cur_ind_text" ;;
                "Bloque de texto"*) key="ind_block"; val="$cur_ind_block" ;;
                "Borde de imagen"*) key="ind_border"; val="$cur_ind_border" ;;
                "Subrayado de imagen"*) key="ind_underline"; val="$cur_ind_underline" ;;
                "Halo de fondo"*) key="ind_halo"; val="$cur_ind_halo" ;;
            esac

            if [[ -n "$key" ]]; then
                if [[ "$val" == "true" ]]; then val="false"; else val="true"; fi
                save_state "$key" "$val"
                case "$key" in
                    "ind_text") cur_ind_text="$val" ;;
                    "ind_block") cur_ind_block="$val" ;;
                    "ind_border") cur_ind_border="$val" ;;
                    "ind_underline") cur_ind_underline="$val" ;;
                    "ind_halo") cur_ind_halo="$val" ;;
                esac
            fi
        done
    }

    menu_visualizacion() {
        while true; do
            local mode_lbl="Todos"
            case "$cur_show_names_mode" in
                "selected") mode_lbl="Solo en seleccionada" ;;
                "disabled") mode_lbl="Desactivados" ;;
            esac
            
            local card_lbl="desactivado"
            [[ "$cur_card_style" == "true" ]] && card_lbl="activado"
            local join_lbl="desactivado"
            [[ "$cur_join_text" == "true" ]] && join_lbl="activado"
            
            local vis_opts=""
            vis_opts+="Nombres de wallpapers: $mode_lbl"$'\n'
            vis_opts+="Estilo tarjeta (Card): $card_lbl"$'\n'
            vis_opts+="Unir texto a tarjeta: $join_lbl"$'\n'
            vis_opts+="Personalizar indicador de selección..."$'\n'
            vis_opts+="Atrás"

            local vis_choice=$(ask_selection "Visualización" "$vis_opts")
            [[ -z "$vis_choice" || "$vis_choice" == "Atrás" ]] && break

            if [[ "$vis_choice" == "Nombres de wallpapers"* ]]; then
                local modes=$'Todos\nSolo en seleccionada\nDesactivados'
                local selected_mode=$(ask_selection "Nombres" "$modes")
                if [[ -n "$selected_mode" ]]; then
                    case "$selected_mode" in
                        "Todos") cur_show_names_mode="all" ;;
                        "Solo en seleccionada") cur_show_names_mode="selected" ;;
                        "Desactivados") cur_show_names_mode="disabled" ;;
                    esac
                    save_state "show_names_mode" "$cur_show_names_mode"
                fi

            elif [[ "$vis_choice" == "Estilo tarjeta (Card)"* ]]; then
                if [[ "$cur_card_style" == "true" ]]; then
                    cur_card_style="false"
                else
                    cur_card_style="true"
                fi
                save_state "card_style" "$cur_card_style"

            elif [[ "$vis_choice" == "Unir texto a tarjeta"* ]]; then
                if [[ "$cur_join_text" == "true" ]]; then
                    cur_join_text="false"
                else
                    cur_join_text="true"
                fi
                save_state "join_text" "$cur_join_text"

            elif [[ "$vis_choice" == "Personalizar indicador de selección..." ]]; then
                menu_indicadores
            fi
        done
    }

    menu_miniaturas() {
        while true; do
            local mode_lbl="desactivado"
            [[ "$cur_thumb_mode" == "enabled" ]] && mode_lbl="activado"

            local fallback_lbl="Usar icono genérico"
            [[ "$cur_no_thumb" == "original" ]] && fallback_lbl="Cargar imagen original"

            local size_lbl="$cur_thumb_size px"
            case "$cur_thumb_size" in
                300) size_lbl="Baja (300px)" ;;
                450) size_lbl="Media (450px)" ;;
                600) size_lbl="Alta (600px)" ;;
            esac

            local crop_lbl="Completo (Fit)"
            [[ "$cur_thumb_crop_mode" == "crop" ]] && crop_lbl="Cuadrado (Crop)"

            local thumb_opts=""
            thumb_opts+="$PROM_THUMBS: $mode_lbl"$'\n'
            if [[ "$cur_thumb_mode" == "enabled" ]]; then
                thumb_opts+="$PROM_QUALITY: $size_lbl"$'\n'
                thumb_opts+="Recorte de miniatura: $crop_lbl"$'\n'
                thumb_opts+="$PROM_NO_THUMB: $fallback_lbl"$'\n'
            fi
            thumb_opts+="Atrás"

            local thumb_choice=$(ask_selection "Miniaturas" "$thumb_opts")
            [[ -z "$thumb_choice" || "$thumb_choice" == "Atrás" ]] && break

            if [[ "$thumb_choice" == "$PROM_THUMBS"* ]]; then
                if [[ "$cur_thumb_mode" == "enabled" ]]; then
                    cur_thumb_mode="disabled"
                else
                    cur_thumb_mode="enabled"
                fi
                save_state "thumbnail_mode" "$cur_thumb_mode"
                if [[ "$cur_thumb_mode" == "enabled" ]] && [[ "$HAS_VIPS" -eq 0 ]]; then
                    cur_thumb_mode="disabled"
                fi

            elif [[ "$thumb_choice" == "$PROM_QUALITY"* ]]; then
                local sizes=$'Baja (300px)\nMedia (450px)\nAlta (600px)'
                local custom_sizes_file="$WP_STATE_DIR/custom_sizes"
                if [[ -f "$custom_sizes_file" ]]; then
                    while IFS= read -r custom_sz; do
                        [[ -z "$custom_sz" ]] && continue
                        if [[ "$custom_sz" != "300" && "$custom_sz" != "450" && "$custom_sz" != "600" ]]; then
                            sizes+=$'\n'"${custom_sz}px"
                        fi
                    done < "$custom_sizes_file"
                fi
                sizes+=$'\n'"Nueva calidad personalizada..."

                local selected_sz=$(ask_selection "$PROM_QUALITY" "$sizes")
                if [[ -n "$selected_sz" ]]; then
                    if [[ "$selected_sz" == "Nueva calidad personalizada..." ]]; then
                        local custom_sz=$(ask_selection "Resolución (px)" "")
                        custom_sz="${custom_sz//[[:space:]]/}"
                        if [[ "$custom_sz" =~ ^[0-9]+$ ]] && [ "$custom_sz" -gt 0 ]; then
                            cur_thumb_size="$custom_sz"
                            save_state "thumbnail_size" "$cur_thumb_size"
                            echo "$custom_sz" >> "$custom_sizes_file"
                            mapfile -t history < <(sort -u "$custom_sizes_file" 2>/dev/null)
                            printf "%s\n" "${history[@]}" > "$custom_sizes_file"
                        fi
                    else
                        local size_num="${selected_sz//[!0-9]/}"
                        if [[ -n "$size_num" ]]; then
                            cur_thumb_size="$size_num"
                            save_state "thumbnail_size" "$cur_thumb_size"
                        fi
                    fi
                fi

            elif [[ "$thumb_choice" == "Recorte de miniatura"* ]]; then
                if [[ "$cur_thumb_crop_mode" == "crop" ]]; then
                    cur_thumb_crop_mode="fit"
                else
                    cur_thumb_crop_mode="crop"
                fi
                save_state "thumbnail_crop_mode" "$cur_thumb_crop_mode"

            elif [[ "$thumb_choice" == "$PROM_NO_THUMB"* ]]; then
                local fallbacks=$'Cargar imagen original\nUsar icono genérico'
                local selected_fb=$(ask_selection "$PROM_NO_THUMB" "$fallbacks")
                if [[ -n "$selected_fb" ]]; then
                    if [[ "$selected_fb" == "Cargar imagen original" ]]; then
                        cur_no_thumb="original"
                    else
                        cur_no_thumb="generic"
                    fi
                    save_state "no_thumb_mode" "$cur_no_thumb"
                fi
            fi
        done
    }

    menu_color() {
        while true; do
            local bg_lbl="desactivado"
            [[ "$cur_bg_gen" == "true" ]] && bg_lbl="activado"

            local matugen_lbl="desactivado"
            [[ "$cur_matugen_thumb" == "true" ]] && matugen_lbl="activado"

            local fit_lbl="desactivado"
            [[ "$cur_matugen_use_fit" == "true" ]] && fit_lbl="activado"

            local clean_lbl="desactivado"
            [[ "$cur_matugen_clean_temp" == "true" ]] && clean_lbl="activado"

            local color_opts=""
            color_opts+="$PROM_BG_GEN: $bg_lbl"$'\n'
            color_opts+="Generación de color rápida: $matugen_lbl"$'\n'
            if [[ "$cur_thumb_crop_mode" == "crop" ]]; then
                color_opts+="Usar imagen completa para color: $fit_lbl"$'\n'
                color_opts+="Limpieza temporal Matugen: $clean_lbl"$'\n'
            fi
            color_opts+="Atrás"

            local color_choice=$(ask_selection "Colores" "$color_opts")
            [[ -z "$color_choice" || "$color_choice" == "Atrás" ]] && break

            if [[ "$color_choice" == "$PROM_BG_GEN"* ]]; then
                if [[ "$cur_bg_gen" == "true" ]]; then
                    cur_bg_gen="false"
                else
                    cur_bg_gen="true"
                fi
                save_state "bg_generation" "$cur_bg_gen"

            elif [[ "$color_choice" == "Generación de color rápida"* ]]; then
                if [[ "$cur_matugen_thumb" == "true" ]]; then
                    cur_matugen_thumb="false"
                else
                    cur_matugen_thumb="true"
                fi
                save_state "matugen_use_thumb" "$cur_matugen_thumb"

            elif [[ "$color_choice" == "Usar imagen completa para color"* ]]; then
                if [[ "$cur_matugen_use_fit" == "true" ]]; then
                    cur_matugen_use_fit="false"
                else
                    cur_matugen_use_fit="true"
                fi
                save_state "matugen_use_fit" "$cur_matugen_use_fit"

            elif [[ "$color_choice" == "Limpieza temporal Matugen"* ]]; then
                if [[ "$cur_matugen_clean_temp" == "true" ]]; then
                    cur_matugen_clean_temp="false"
                else
                    cur_matugen_clean_temp="true"
                fi
                save_state "matugen_clean_temp" "$cur_matugen_clean_temp"
            fi
        done
    }

    menu_cache() {
        while true; do
            local cache_opts=""
            cache_opts+="Generar Caché de Miniaturas Ahora"$'\n'
            cache_opts+="$PROM_CLEAN"$'\n'
            cache_opts+="Atrás"

            local cache_choice=$(ask_selection "Caché" "$cache_opts")
            [[ -z "$cache_choice" || "$cache_choice" == "Atrás" ]] && break

            if [[ "$cache_choice" == "Generar Caché de Miniaturas Ahora" ]]; then
                if command -v notify-send &>/dev/null; then
                    notify-send "Caché de Wallpaper" "Generando miniaturas en background..." -i image-x-generic -t 1500
                fi
                wp_cache.sh --cache-now &

            elif [[ "$cache_choice" == "$PROM_CLEAN"* ]]; then
                local cleans=$'Borrar huérfanos\nActiva actual ('"${cur_thumb_size}"$'px)\nBaja (300px)\nMedia (450px)\nAlta (600px)\nTodo excepto la calidad activa\nToda la caché\nAtrás'
                local selected_cl=$(ask_selection "$PROM_CLEAN" "$cleans")
                if [[ -n "$selected_cl" && "$selected_cl" != "Atrás" ]]; then
                    local clean_opt="orphans"
                    case "$selected_cl" in
                        "Borrar huérfanos") clean_opt="orphans" ;;
                        "Baja (300px)") clean_opt="300" ;;
                        "Media (450px)") clean_opt="450" ;;
                        "Alta (600px)") clean_opt="600" ;;
                        "Activa actual"*) clean_opt="$cur_thumb_size" ;;
                        "Todo excepto la calidad activa") clean_opt="keep-active" ;;
                        "Toda la caché") clean_opt="full" ;;
                    esac
                    
                    wp_cache.sh --clean-cache "$clean_opt"
                    if command -v notify-send &>/dev/null; then
                        notify-send "Limpieza de Caché" "Operación completada: $selected_cl" -i system-file-manager -t 2000
                    fi
                fi
            fi
        done
    }

    # Función interna de submenú interactivo (Rofi de texto limpio)
    configure_wallpaper() {
        # Carga dinámica en RAM del estado actualizado usando helper compartido
        load_wp_config
        cur_show_names_mode=$(get_state "show_names_mode" "all")
        cur_card_style=$(get_state "card_style" "false")
        cur_join_text=$(get_state "join_text" "false")
        
        cur_ind_text=$(get_state "ind_text" "true")
        cur_ind_block=$(get_state "ind_block" "false")
        cur_ind_border=$(get_state "ind_border" "false")
        cur_ind_underline=$(get_state "ind_underline" "false")
        cur_ind_halo=$(get_state "ind_halo" "false")

        cur_thumb_mode="$THUMB_MODE"
        cur_thumb_size="$THUMB_SIZE"
        cur_no_thumb="$NO_THUMB_MODE"
        cur_bg_gen="$BG_GENERATION"
        cur_matugen_thumb="$MATUGEN_USE_THUMB"
        cur_thumb_crop_mode="$THUMB_CROP_MODE"
        cur_matugen_clean_temp="$MATUGEN_CLEAN_TEMP"
        cur_matugen_use_fit="$MATUGEN_USE_FIT"

        while true; do
            local main_opts=""
            main_opts+="Personalizar visualización..."$'\n'
            main_opts+="Ajustes de miniaturas..."$'\n'
            main_opts+="Ajustes de color (Matugen)..."$'\n'
            main_opts+="Mantenimiento de caché..."$'\n'
            main_opts+="Salir"

            local choice=$(ask_selection "Ajustes de Wallpaper" "$main_opts")
            [[ -z "$choice" || "$choice" == "Salir" || "$choice" == "Atrás" ]] && break

            case "$choice" in
                "Personalizar visualización...") menu_visualizacion ;;
                "Ajustes de miniaturas...") menu_miniaturas ;;
                "Ajustes de color (Matugen)...") menu_color ;;
                "Mantenimiento de caché...") menu_cache ;;
            esac
        done
    }

    configure_wallpaper
    exit 0
fi

# 6. Selector Principal de Wallpapers (Grid de Imágenes o Consola)
wallpapers_found=$(list_wallpapers)

if [[ -z "$wallpapers_found" ]]; then
    echo "Error: No se encontraron wallpapers en $WALLPAPER_DIR" >&2
    exit 1
fi

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
    # Modo Gráfico (GUI - Rofi con Grid de Imágenes)
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    SEL_ARGS=(${WP_SEL_ARGS:--dmenu -p "Wallpaper" -theme "${ROFI_THEME}"})
    LINE_TMPL="${WP_SEL_LINE_TMPL:-%f\x00icon\x1f%p}"

    [[ -d "$THUMB_DIR" ]] || mkdir -p "$THUMB_DIR"

    tmp_rofi_opts=$(mktemp)
    generate_rofi_list "$LINE_TMPL" > "$tmp_rofi_opts"

    # Lanzar Rofi de selección principal
    tmp_choice="/dev/shm/wall_menu_choice_${UID}.choice"
    if [[ "$SEL_BIN" == *"rofi"* ]]; then
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE -format 's' < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    else
        eval "\"\$SEL_BIN\" \"\${SEL_ARGS[@]}\" $WP_SEL_STYLE < \"\$tmp_rofi_opts\"" > "$tmp_choice"
    fi

    FINAL_NAME=""
    [[ -f "$tmp_choice" ]] && read -r FINAL_NAME < "$tmp_choice"
    rm -f "$tmp_choice" "$tmp_rofi_opts"

    [[ -z "$FINAL_NAME" ]] && exit 1
    SELECTION="$FINAL_NAME"
fi

# 7. Invocar Backend y Helpers para aplicar y guardar estado
if [[ -n "$SELECTION" ]]; then
    FINAL_PATH=""
    if [[ -f "$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$SELECTION")
    elif [[ -f "$WALLPAPER_DIR/$SELECTION" ]]; then
        FINAL_PATH=$(readlink -f "$WALLPAPER_DIR/$SELECTION")
    else
        FINAL_PATH="$SELECTION"
    fi
    
    # Actualizar origen de color para Matugen de forma local (evita fork de wp_color.sh)
    color_src="$FINAL_PATH"
    if [[ "$THUMB_MODE" == "enabled" && "$MATUGEN_USE_THUMB" == "true" ]]; then
        get_thumb_path "$FINAL_PATH"
        [[ -f "$RET_THUMB" ]] && color_src="$RET_THUMB"
    fi
    ln -sf "$color_src" "$WP_STATE_DIR/color_source"
    
    # Aplicar wallpaper en pantalla
    wp_select.sh -C "$FINAL_PATH"
    exit $?
else
    exit 1
fi
