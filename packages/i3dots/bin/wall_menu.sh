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

# 2. Configurar Directorios y Cargar Estado
WP_STATE_DIR="${STATE_DIR:-$HOME/.config/i3dots/core/state}/$CURRENT_ENV/wallpaper"
mkdir -p "$WP_STATE_DIR"

# Cargar configuraciones del estado (optimizando I/O: solo lectura rápida)
THUMB_MODE="enabled"
[[ -f "$WP_STATE_DIR/thumbnail_mode" ]] && THUMB_MODE=$(<"$WP_STATE_DIR/thumbnail_mode")
THUMB_MODE="${THUMB_MODE//[[:space:]]/}"

THUMB_SIZE="450"
[[ -f "$WP_STATE_DIR/thumbnail_size" ]] && THUMB_SIZE=$(<"$WP_STATE_DIR/thumbnail_size")
THUMB_SIZE="${THUMB_SIZE//[[:space:]]/}"

NO_THUMB_MODE="original"
[[ -f "$WP_STATE_DIR/no_thumb_mode" ]] && NO_THUMB_MODE=$(<"$WP_STATE_DIR/no_thumb_mode")
NO_THUMB_MODE="${NO_THUMB_MODE//[[:space:]]/}"

BG_GENERATION="true"
[[ -f "$WP_STATE_DIR/bg_generation" ]] && BG_GENERATION=$(<"$WP_STATE_DIR/bg_generation")
BG_GENERATION="${BG_GENERATION//[[:space:]]/}"

THUMB_DIR="$WP_STATE_DIR/thumbs/$THUMB_SIZE"

# Cargar traducciones e iconos del entorno con fallbacks
PROM_THUMBS="${WP_PROM_THUMBS:-Miniaturas en caché}"
PROM_QUALITY="${WP_PROM_QUALITY:-Calidad de Miniaturas}"
PROM_NO_THUMB="${WP_PROM_NO_THUMB:-Si falta miniatura}"
PROM_BG_GEN="${WP_PROM_BG_GEN:-Pre-caché}"
PROM_CLEAN="${WP_PROM_CLEAN:-Limpiar Caché de Miniaturas}"

# 3. Validar Dependencia Crítica
HAS_VIPS=0
if command -v vipsthumbnail &>/dev/null; then
    HAS_VIPS=1
else
    if [[ "$THUMB_MODE" == "enabled" ]]; then
        THUMB_MODE="disabled"
        if command -v notify-send &>/dev/null; then
            notify-send "Wallpaper" "Advertencia: Instala libvips (vipsthumbnail) para optimización de caché." -i dialog-warning -t 5000
        else
            echo "Advertencia: Comando 'vipsthumbnail' no encontrado. Desactivando caché de miniaturas." >&2
        fi
    fi
fi

# Helpers para persistir estado de forma inteligente (evitando I/O redundantes)
save_state() {
    local key="$1"
    local val="$2"
    local file="$WP_STATE_DIR/$key"
    local cur_val=""
    [[ -f "$file" ]] && cur_val=$(<"$file")
    if [[ "$cur_val" != "$val" ]]; then
        echo -n "$val" > "$file"
    fi
}

# 4. Modo Headless: Cachear Ahora (--cache-now)
if [[ "$CACHE_NOW" -eq 1 ]]; then
    [[ "$HAS_VIPS" -eq 0 ]] && { echo "Error: vipsthumbnail no está disponible." >&2; exit 1; }
    
    wallpapers_found=$(wp_select.sh -L)
    [[ -z "$wallpapers_found" ]] && { echo "No se encontraron wallpapers." >&2; exit 0; }
    
    mkdir -p "$THUMB_DIR"
    
    # Filtrar imágenes pendientes
    mapfile -t files <<< "$wallpapers_found"
    declare -a pending=()
    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue
        safe_name="${file//\//_}"
        thumb="$THUMB_DIR/${safe_name}.jpg"
        if [[ ! -f "$thumb" || "$file" -nt "$thumb" ]]; then
            pending+=("$file")
        fi
    done
    
    total="${#pending[@]}"
    if [[ "$total" -eq 0 ]]; then
        echo "Caché al día. No hay miniaturas pendientes."
        exit 0
    fi
    
    echo "Generando caché de miniaturas (Calidad: ${THUMB_SIZE}px) para $total imágenes..."
    count=0
    for file in "${pending[@]}"; do
        count=$((count+1))
        echo -e "\e[1A\e[K[$count/$total] Procesando: ${file##*/}"
        safe_name="${file//\//_}"
        thumb="$THUMB_DIR/${safe_name}.jpg"
        vipsthumbnail -s "$THUMB_SIZE" -o "$thumb" "$file" 2>/dev/null
    done
    
    if command -v notify-send &>/dev/null; then
        notify-send "Caché de Wallpaper" "Generación de miniaturas completada (${THUMB_SIZE}px)." -i image-x-generic -t 2000
    fi
    echo "Caché de miniaturas completado."
    exit 0
fi

# 5. Modo Headless: Limpiar Caché (--clean-cache)
if [[ "$CLEAN_CACHE" -eq 1 ]]; then
    root_thumbs="$WP_STATE_DIR/thumbs"
    [[ ! -d "$root_thumbs" ]] && { echo "Caché vacía. Nada que limpiar." >&2; exit 0; }
    
    case "$CLEAN_ARG" in
        orphans)
            echo "Buscando miniaturas huérfanas en todas las calidades..."
            wallpapers_found=$(wp_select.sh -L)
            
            declare -A active_walls
            while IFS= read -r file; do
                [[ -n "$file" ]] && active_walls["$file"]=1
            done <<< "$wallpapers_found"
            
            declare -A active_safes
            for w in "${!active_walls[@]}"; do
                safe="${w//\//_}"
                active_safes["$safe"]=1
            done
            
            deleted_count=0
            while IFS= read -r -d '' thumb_file; do
                [[ -z "$thumb_file" ]] && continue
                t_name="${thumb_file##*/}"
                t_name="${t_name%.jpg}"
                if [[ -z "${active_safes[$t_name]}" ]]; then
                    rm -f "$thumb_file"
                    deleted_count=$((deleted_count+1))
                fi
            done < <(find "$root_thumbs" -type f -name "*.jpg" -print0 2>/dev/null)
            
            echo "Limpieza completada. Borradas $deleted_count miniaturas huérfanas."
            ;;
        300|450|600|[0-9]*)
            size_dir="$root_thumbs/$CLEAN_ARG"
            if [[ -d "$size_dir" ]]; then
                rm -rf "$size_dir"
                echo "Caché de calidad $CLEAN_ARG px eliminada."
            else
                echo "No existe caché para la calidad $CLEAN_ARG px."
            fi
            ;;
        keep-active)
            echo "Eliminando todas las calidades excepto la activa (${THUMB_SIZE}px)..."
            while IFS= read -r -d '' dir; do
                [[ -z "$dir" ]] && continue
                dir_name="${dir##*/}"
                if [[ "$dir_name" != "$THUMB_SIZE" ]]; then
                    rm -rf "$dir"
                    echo "Eliminada calidad residual: ${dir_name}px"
                fi
            done < <(find "$root_thumbs" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
            ;;
        full)
            echo "Vaciando toda la caché de miniaturas..."
            rm -rf "$root_thumbs"
            echo "Caché completa eliminada."
            ;;
        *)
            echo "Opción de limpieza no válida. Opciones: orphans, Baja (300), Media (450), Alta (600), entero, keep-active, full" >&2
            exit 1
            ;;
    esac
    exit 0
fi

# 6. Menú Dedicado de Ajustes de Rofi (--manage)
if [[ "$MANAGE_MODE" -eq 1 ]]; then
    # Cargar variables de visualización de Rofi para configuración
    SEL_BIN="${WP_SEL_BIN:-rofi}"
    LAUNCHER_THEME="${WP_MANAGE_THEME:-${ROFI_THEME:-$HOME/.config/rofi/themes/launcher.rasi}}"
    SEL_ARGS_ARR=("-dmenu" "-theme" "$LAUNCHER_THEME")

    # Función interna de submenú interactivo (Rofi de texto limpio)
    configure_wallpaper() {
        # Carga dinámica en RAM del estado actualizado
        local cur_thumb_mode="enabled"
        [[ -f "$WP_STATE_DIR/thumbnail_mode" ]] && cur_thumb_mode=$(<"$WP_STATE_DIR/thumbnail_mode")
        cur_thumb_mode="${cur_thumb_mode//[[:space:]]/}"

        local cur_thumb_size="450"
        [[ -f "$WP_STATE_DIR/thumbnail_size" ]] && cur_thumb_size=$(<"$WP_STATE_DIR/thumbnail_size")
        cur_thumb_size="${cur_thumb_size//[[:space:]]/}"

        local cur_no_thumb="original"
        [[ -f "$WP_STATE_DIR/no_thumb_mode" ]] && cur_no_thumb=$(<"$WP_STATE_DIR/no_thumb_mode")
        cur_no_thumb="${cur_no_thumb//[[:space:]]/}"

        local cur_bg_gen="true"
        [[ -f "$WP_STATE_DIR/bg_generation" ]] && cur_bg_gen=$(<"$WP_STATE_DIR/bg_generation")
        cur_bg_gen="${cur_bg_gen//[[:space:]]/}"

        # Mapeo a etiquetas en español para Rofi
        local mode_lbl="desactivado"
        [[ "$cur_thumb_mode" == "enabled" ]] && mode_lbl="activado"

        local bg_lbl="desactivado"
        [[ "$cur_bg_gen" == "true" ]] && bg_lbl="activado"

        local fallback_lbl="Usar icono genérico"
        [[ "$cur_no_thumb" == "original" ]] && fallback_lbl="Cargar imagen original"

        local size_lbl="$cur_thumb_size px"
        case "$cur_thumb_size" in
            300) size_lbl="Baja (300px)" ;;
            450) size_lbl="Media (450px)" ;;
            600) size_lbl="Alta (600px)" ;;
        esac

        while true; do
            local opts=""
            if [[ "$cur_thumb_mode" == "disabled" ]]; then
                opts+="$PROM_THUMBS: desactivado"$'\n'
                opts+="$PROM_CLEAN"$'\n'
                opts+="Salir"$'\n'
            else
                opts+="$PROM_THUMBS: activado"$'\n'
                opts+="$PROM_QUALITY: $size_lbl"$'\n'
                opts+="$PROM_NO_THUMB: $fallback_lbl"$'\n'
                opts+="$PROM_BG_GEN: $bg_lbl"$'\n'
                opts+="Generar Caché de Miniaturas Ahora"$'\n'
                opts+="$PROM_CLEAN"$'\n'
                opts+="Salir"$'\n'
            fi

            # Captura de selección optimizada en RAM
            local choice_tmp="/dev/shm/wall_menu_manage_${UID}.choice"
            if [[ "$SEL_BIN" == *"rofi"* ]]; then
                eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"Ajustes de Wallpaper\" -format 's' <<< \"\$opts\"" > "$choice_tmp"
            else
                eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"Ajustes de Wallpaper\" <<< \"\$opts\"" > "$choice_tmp"
            fi
            
            local choice=""
            [[ -f "$choice_tmp" ]] && read -r choice < "$choice_tmp"
            rm -f "$choice_tmp"

            [[ -z "$choice" || "$choice" == "Salir" || "$choice" == "Atrás" ]] && break

            # Acciones del Submenú
            if [[ "$choice" == "$PROM_THUMBS"* ]]; then
                local modes=$'activado\ndesactivado'
                local choice_mode_tmp="/dev/shm/wall_menu_mode_${UID}.choice"
                if [[ "$SEL_BIN" == *"rofi"* ]]; then
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_THUMBS\" -format 's' <<< \"\$modes\"" > "$choice_mode_tmp"
                else
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_THUMBS\" <<< \"\$modes\"" > "$choice_mode_tmp"
                fi
                local selected_mode=""
                [[ -f "$choice_mode_tmp" ]] && read -r selected_mode < "$choice_mode_tmp"
                rm -f "$choice_mode_tmp"
                
                if [[ -n "$selected_mode" ]]; then
                    if [[ "$selected_mode" == "activado" ]]; then
                        cur_thumb_mode="enabled"
                    else
                        cur_thumb_mode="disabled"
                    fi
                    save_state "thumbnail_mode" "$cur_thumb_mode"
                    if [[ "$cur_thumb_mode" == "enabled" ]] && [[ "$HAS_VIPS" -eq 0 ]]; then
                        cur_thumb_mode="disabled"
                    fi
                    # Auto-reproducir cambios para actualizar la vista en caliente
                    mode_lbl="desactivado"
                    [[ "$cur_thumb_mode" == "enabled" ]] && mode_lbl="activado"
                fi

            elif [[ "$choice" == "$PROM_QUALITY"* ]]; then
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

                local choice_sz_tmp="/dev/shm/wall_menu_sz_${UID}.choice"
                if [[ "$SEL_BIN" == *"rofi"* ]]; then
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_QUALITY\" -format 's' <<< \"\$sizes\"" > "$choice_sz_tmp"
                else
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_QUALITY\" <<< \"\$sizes\"" > "$choice_sz_tmp"
                fi
                local selected_sz=""
                [[ -f "$choice_sz_tmp" ]] && read -r selected_sz < "$choice_sz_tmp"
                rm -f "$choice_sz_tmp"

                if [[ -n "$selected_sz" ]]; then
                    if [[ "$selected_sz" == "Nueva calidad personalizada..." ]]; then
                        local custom_input_tmp="/dev/shm/wall_menu_custom_${UID}.choice"
                        if [[ "$SEL_BIN" == *"rofi"* ]]; then
                            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"Escribe resolución (píxeles)\" -format 's' <<< \"\"" > "$custom_input_tmp"
                        else
                            eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"Escribe resolución (píxeles)\" <<< \"\"" > "$custom_input_tmp"
                        fi
                        local custom_sz=""
                        [[ -f "$custom_input_tmp" ]] && read -r custom_sz < "$custom_input_tmp"
                        rm -f "$custom_input_tmp"

                        custom_sz="${custom_sz//[[:space:]]/}"
                        if [[ "$custom_sz" =~ ^[0-9]+$ ]] && [ "$custom_sz" -gt 0 ]; then
                            cur_thumb_size="$custom_sz"
                            save_state "thumbnail_size" "$cur_thumb_size"
                            echo "$custom_sz" >> "$custom_sizes_file"
                            mapfile -t history < <(sort -u "$custom_sizes_file" 2>/dev/null)
                            printf "%s\n" "${history[@]}" > "$custom_sizes_file"
                            size_lbl="${custom_sz}px"
                        fi
                    else
                        local size_num="${selected_sz//[!0-9]/}"
                        if [[ -n "$size_num" ]]; then
                            cur_thumb_size="$size_num"
                            save_state "thumbnail_size" "$cur_thumb_size"
                            size_lbl="$selected_sz"
                        fi
                    fi
                fi

            elif [[ "$choice" == "$PROM_NO_THUMB"* ]]; then
                local fallbacks=$'Cargar imagen original\nUsar icono genérico'
                local choice_fb_tmp="/dev/shm/wall_menu_fb_${UID}.choice"
                if [[ "$SEL_BIN" == *"rofi"* ]]; then
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_NO_THUMB\" -format 's' <<< \"\$fallbacks\"" > "$choice_fb_tmp"
                else
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_NO_THUMB\" <<< \"\$fallbacks\"" > "$choice_fb_tmp"
                fi
                local selected_fb=""
                [[ -f "$choice_fb_tmp" ]] && read -r selected_fb < "$choice_fb_tmp"
                rm -f "$choice_fb_tmp"

                if [[ -n "$selected_fb" ]]; then
                    if [[ "$selected_fb" == "Cargar imagen original" ]]; then
                        cur_no_thumb="original"
                    else
                        cur_no_thumb="generic"
                    fi
                    save_state "no_thumb_mode" "$cur_no_thumb"
                    fallback_lbl="$selected_fb"
                fi

            elif [[ "$choice" == "$PROM_BG_GEN"* ]]; then
                local bgs=$'activado\ndesactivado'
                local choice_bg_tmp="/dev/shm/wall_menu_bg_${UID}.choice"
                if [[ "$SEL_BIN" == *"rofi"* ]]; then
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_BG_GEN\" -format 's' <<< \"\$bgs\"" > "$choice_bg_tmp"
                else
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_BG_GEN\" <<< \"\$bgs\"" > "$choice_bg_tmp"
                fi
                local selected_bg=""
                [[ -f "$choice_bg_tmp" ]] && read -r selected_bg < "$choice_bg_tmp"
                rm -f "$choice_bg_tmp"

                if [[ -n "$selected_bg" ]]; then
                    if [[ "$selected_bg" == "activado" ]]; then
                        cur_bg_gen="true"
                    else
                        cur_bg_gen="false"
                    fi
                    save_state "bg_generation" "$cur_bg_gen"
                    bg_lbl="$selected_bg"
                fi

            elif [[ "$choice" == "Generar Caché de Miniaturas Ahora" ]]; then
                if command -v notify-send &>/dev/null; then
                    notify-send "Caché de Wallpaper" "Generando miniaturas en background..." -i image-x-generic -t 1500
                fi
                "$0" --cache-now &

            elif [[ "$choice" == "$PROM_CLEAN"* ]]; then
                local cleans=$'Borrar huérfanos\nActiva actual ('"${cur_thumb_size}"$'px)\nBaja (300px)\nMedia (450px)\nAlta (600px)\nTodo excepto la calidad activa\nToda la caché\nAtrás'
                local choice_cl_tmp="/dev/shm/wall_menu_clean_${UID}.choice"
                if [[ "$SEL_BIN" == *"rofi"* ]]; then
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_CLEAN\" -format 's' <<< \"\$cleans\"" > "$choice_cl_tmp"
                else
                    eval "\"\$SEL_BIN\" \"\${SEL_ARGS_ARR[@]}\" -p \"$PROM_CLEAN\" <<< \"\$cleans\"" > "$choice_cl_tmp"
                fi
                local selected_cl=""
                [[ -f "$choice_cl_tmp" ]] && read -r selected_cl < "$choice_cl_tmp"
                rm -f "$choice_cl_tmp"

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
                    
                    "$0" --clean-cache "$clean_opt"
                    if command -v notify-send &>/dev/null; then
                        notify-send "Limpieza de Caché" "Operación completada: $selected_cl" -i system-file-manager -t 2000
                    fi
                fi
            fi
        done
    }

    configure_wallpaper
    exit 0
fi

# 7. Selector Principal de Wallpapers (Grid de Imágenes o Consola)
# Buscar wallpapers disponibles llamando al backend
wallpapers_found=$(wp_select.sh -L)

if [[ -z "$wallpapers_found" ]]; then
    echo "Error: No se obtuvieron wallpapers desde wp_select.sh" >&2
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

    # Crear subcarpeta de calidad si no existe
    mkdir -p "$THUMB_DIR"

    tmp_rofi_opts=$(mktemp)
    wallpapers_to_gen=""

    # 1. Preparar opciones de Rofi de forma instantánea (en memoria, 0 subprocesos)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        if [[ "$THUMB_MODE" == "enabled" ]]; then
            safe_name="${file//\//_}"
            thumb="$THUMB_DIR/${safe_name}.jpg"
            
            # Comparación rápida en filesystem
            if [[ -f "$thumb" && "$file" -ot "$thumb" ]]; then
                thumb_to_use="$thumb"
            else
                wallpapers_to_gen+="$file"$'\n'
                if [[ "$NO_THUMB_MODE" == "original" ]]; then
                    thumb_to_use="$file"
                else
                    thumb_to_use="image-x-generic"
                fi
            fi
        else
            thumb_to_use="$file"
        fi

        rel_path="${file#$WALLPAPER_DIR/}"
        line="$LINE_TMPL"
        line="${line//%f/${file##*/}}"
        line="${line//%r/$rel_path}"
        line="${line//%p/$thumb_to_use}"
        printf "%b\n" "$line"
    done <<< "$wallpapers_found" > "$tmp_rofi_opts"

    # 2. Daemon Asíncrono Bajo Demanda (Ejecución Finita)
    if [[ "$THUMB_MODE" == "enabled" ]] && [[ "$BG_GENERATION" == "true" ]] && [[ -n "$wallpapers_to_gen" ]]; then
        (
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                safe_name="${file//\//_}"
                thumb="$THUMB_DIR/${safe_name}.jpg"
                nice -n 19 vipsthumbnail -s "$THUMB_SIZE" -o "$thumb" "$file" 2>/dev/null
            done <<< "$wallpapers_to_gen"
        ) >/dev/null 2>&1 &
    fi

    # 3. Lanzar Rofi de selección principal
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

# 4. Invocar Backend para aplicar y guardar estado
if [[ -n "$SELECTION" ]]; then
    wp_select.sh -C "$SELECTION"
    exit $?
else
    exit 1
fi
