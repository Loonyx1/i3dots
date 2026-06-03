#!/usr/bin/env bash
# packages/i3dots/bin/wp_cache.sh - Helper de administración de caché de wallpapers (Backend)

# 1. Parseo de argumentos
CACHE_NOW=0
CLEAN_CACHE=0
CLEAN_ARG=""
BG_GEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -CN|--cache-now) CACHE_NOW=1; shift ;;
        -CC|--clean-cache)
            CLEAN_CACHE=1
            CLEAN_ARG="$2"
            shift; [[ $# -gt 0 ]] && shift
            ;;
        --bg-gen) BG_GEN=1; shift ;;
        *) shift ;;
    esac
done

# 2. Configurar Directorios y Cargar Estado de forma dinámica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_PARENT="${SCRIPT_DIR%/*}"
PKG_NAME="${PKG_PARENT##*/}"
CUR_ENV="${CURRENT_ENV:-$PKG_NAME}"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR_VAL="${STATE_DIR:-$ROOT_DIR/core/state}"

WP_STATE_DIR="$STATE_DIR_VAL/$CUR_ENV/wallpaper"
mkdir -p "$WP_STATE_DIR"

THUMB_SIZE="450"
[[ -f "$WP_STATE_DIR/thumbnail_size" ]] && THUMB_SIZE=$(<"$WP_STATE_DIR/thumbnail_size")
THUMB_SIZE="${THUMB_SIZE//[[:space:]]/}"

THUMB_DIR="$WP_STATE_DIR/thumbs/$THUMB_SIZE"

# Cargar variables del entorno con fallbacks
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wall}"

# Validar dependencia de vipsthumbnail
HAS_VIPS=0
command -v vipsthumbnail &>/dev/null && HAS_VIPS=1

# 3. Modo: Pre-caché en background (--bg-gen)
if [[ "$BG_GEN" -eq 1 ]]; then
    [[ "$HAS_VIPS" -eq 0 ]] && exit 1
    
    wallpapers_found=$(wp_select.sh -L)
    [[ -z "$wallpapers_found" ]] && exit 0
    
    mkdir -p "$THUMB_DIR"
    
    # Bucle secuencial de baja prioridad para wallpapers faltantes
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        real_file=$(readlink -f "$file")
        safe_name="${real_file//\//_}"
        thumb="$THUMB_DIR/${safe_name}.jpg"
        if [[ ! -f "$thumb" || "$real_file" -nt "$thumb" ]]; then
            nice -n 19 vipsthumbnail -s "$THUMB_SIZE" -o "$thumb" "$real_file" 2>/dev/null
        fi
    done <<< "$wallpapers_found"
    exit 0
fi

# 4. Modo: Cachear Ahora (--cache-now)
if [[ "$CACHE_NOW" -eq 1 ]]; then
    [[ "$HAS_VIPS" -eq 0 ]] && { echo "Error: vipsthumbnail no disponible. Instala libvips." >&2; exit 1; }
    
    wallpapers_found=$(wp_select.sh -L)
    [[ -z "$wallpapers_found" ]] && { echo "No se encontraron wallpapers." >&2; exit 0; }
    
    mkdir -p "$THUMB_DIR"
    
    # Filtrar imágenes pendientes
    mapfile -t files <<< "$wallpapers_found"
    declare -a pending=()
    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue
        real_file=$(readlink -f "$file")
        safe_name="${real_file//\//_}"
        thumb="$THUMB_DIR/${safe_name}.jpg"
        if [[ ! -f "$thumb" || "$real_file" -nt "$thumb" ]]; then
            pending+=("$real_file")
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

# 5. Modo: Limpiar Caché (--clean-cache)
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

echo "Error: wp_cache.sh requiere --cache-now, --clean-cache o --bg-gen" >&2
exit 1
