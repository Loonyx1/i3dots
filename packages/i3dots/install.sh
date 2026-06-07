#!/usr/bin/env bash
# i3dots/install.sh

# 0. Cargar biblioteca de utilidades del core
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/core/lib/utils.sh"

LOG_FILE="${LOG_FILE:-/tmp/dots_install.log}"
echo -e "${GRAY}--- Inicio de instalación $(date) ---${NC}" > "$LOG_FILE"

# Mostrar Banner
echo -e "${CYAN}${BOLD}▗▄▄▄▖▄▄▄▄ ▗▄▄▄   ▗▄▖▗▄▄▄▖▗▄▄▖\n  █     █ ▐▌  █ ▐▌ ▐▌ █ ▐▌\n  █  ▀▀▀█ ▐▌  █ ▐▌ ▐▌ █  ▝▀▚▖\n▗▄█▄▖▄▄▄█ ▐▙▄▄▀ ▝▚▄▞▘ █ ▗▄▄▞▘\n          by loonyx${NC}"

# 1. Parseo de argumentos y persistencia de variante
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANT_ARG=""
IS_OFFLINE=false
CLI_WALL=""
CLI_WALL_SRC=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline) IS_OFFLINE=true; shift ;;
        --wallpaper) CLI_WALL="$2"; shift 2 ;;
        --wallpaper-src) CLI_WALL_SRC="$2"; shift 2 ;;
        -*) shift ;;
        *) [ -z "$VARIANT_ARG" ] && VARIANT_ARG="$1"; shift ;;
    esac
done

if [ -n "$OFFLINE" ]; then
    IS_OFFLINE=true
fi

if [ "$IS_OFFLINE" = "true" ]; then
    export SKIP_SYSTEM_PKGS=1
    export SKIP_FONTS_DOWNLOAD=1
    export SKIP_THEMES_DOWNLOAD=1
    export SKIP_MATUGEN_DOWNLOAD=1
fi

if [ -n "$VARIANT_ARG" ]; then
    echo "$VARIANT_ARG" > "$PACKAGE_DIR/.current_variant"
fi

VARIANT_NAME=$(cat "$PACKAGE_DIR/.current_variant" 2>/dev/null || echo "debian")
if [ -f "$PACKAGE_DIR/envs/${VARIANT_NAME}.env" ]; then
    source "$PACKAGE_DIR/envs/${VARIANT_NAME}.env"
else
    print_sub_err "Variante '${VARIANT_NAME}' no soportada."
    exit 1
fi

print_step "Iniciando instalación para variante: ${VARIANT_NAME} (Offline: ${IS_OFFLINE})"

# (Lógica del elevador importada desde utils.sh)
ask_privileges

# 3. Instalar dependencias
if [ -n "$PKG_LIST" ] && [ -z "$SKIP_SYSTEM_PKGS" ]; then
    print_step "Instalando paquetes y dependencias del sistema..."
    
    # Combinar actualización e instalación en una sola llamada para evitar múltiples prompts de contraseña
    FULL_CMD=""
    if [ -n "$PKG_UPDATE_CMD" ]; then
        FULL_CMD="$PKG_MANAGER $PKG_UPDATE_CMD && "
    fi
    FULL_CMD+="$PKG_MANAGER $PKG_INSTALL_CMD $PKG_LIST"

    print_sub "Procesando paquetes (actualización e instalación)..."
    if run_elevated --ticker bash -c "$FULL_CMD"; then
        print_sub_ok "Paquetes de sistema instalados correctamente."
    else
        print_sub_warn "Fallo en gestor de paquetes o cancelación del usuario. Se omiten dependencias."
    fi
fi

# 4. Nerd Fonts
print_step "Instalando tipografías (Nerd Fonts)..."
mkdir -p ~/.local/share/fonts

install_font() {
    local name="$1" url="$2"
    for path in "$HOME/.local/share/fonts/$name" "/usr/share/fonts/$name" "/usr/share/fonts/TTF/$name" "/usr/share/fonts/truetype/$name"; do
        [ -d "$path" ] && { print_sub_ok "Fuente $name ya instalada."; return 0; }
    done
    [ -n "$SKIP_FONTS_DOWNLOAD" ] && { print_sub_ok "Fuente $name (omitida)."; return 0; }
    
    print_sub "Instalando tipografía $name..."
    local temp=$(mktemp -d)
    if wget -q --show-progress -P "$temp" "$url" &>> "$LOG_FILE" && unzip -q "$temp"/*.zip -d ~/.local/share/fonts/"$name" &>> "$LOG_FILE"; then
        print_sub_ok "Fuente $name lista."
    else
        print_sub_err "Fallo al descargar/extraer $name."
    fi
    rm -rf "$temp"
}

fonts_list=(
    "JetBrainsMonoNerd|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
    "FiraCodeNerd|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
    "SymbolsNerdFont|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"
)
for f in "${fonts_list[@]}"; do
    install_font "${f%%|*}" "${f##*|}"
done
fc-cache -fv &>> "$LOG_FILE"

# 5. Temas (adw-gtk3)
print_step "Instalando temas de escritorio..."
mkdir -p ~/.themes
if [ -d "$HOME/.themes/adw-gtk3-dark" ] || [ -d "/usr/share/themes/adw-gtk3-dark" ]; then
    print_sub_ok "Tema adw-gtk3-dark ya instalado."
elif [ -n "$SKIP_THEMES_DOWNLOAD" ]; then
    print_sub_ok "Tema adw-gtk3-dark (omitido por configuración)."
else
    print_sub "Descargando adw-gtk3-dark..."
    if wget -q https://github.com/lassekongo83/adw-gtk3/releases/download/v6.5/adw-gtk3v6.5.tar.xz -O /tmp/adw-gtk3.tar.xz &>> "$LOG_FILE" && \
       tar -xf /tmp/adw-gtk3.tar.xz -C ~/.themes &>> "$LOG_FILE"; then
        rm -f /tmp/adw-gtk3.tar.xz
        print_sub_ok "Tema adw-gtk3-dark instalado."
    else
        print_sub_err "Fallo al instalar tema adw-gtk3-dark."
    fi
fi

# 6. Matugen
print_step "Validando/Instalando Matugen..."
if command -v matugen &> /dev/null; then
    print_sub_ok "Matugen ya instalado."
elif [ -n "$SKIP_MATUGEN_DOWNLOAD" ]; then
    print_sub_ok "Matugen (omitido por configuración)."
else
    print_sub "Buscando última versión de Matugen..."
    TEMP_MATUGEN=$(mktemp -d)
    URL=$(curl -s https://api.github.com/repos/InioX/matugen/releases/latest | grep "browser_download_url.*x86_64.tar.gz" | cut -d '"' -f 4)
    if [[ -n "$URL" ]]; then
        print_sub "Descargando binario de Matugen..."
        if wget -q -P "$TEMP_MATUGEN" "$URL" &>> "$LOG_FILE" && \
           tar -xzf "$TEMP_MATUGEN"/*.tar.gz -C "$TEMP_MATUGEN" &>> "$LOG_FILE"; then
            MATUGEN_BIN=$(find "$TEMP_MATUGEN" -type f -executable -name "matugen*" | head -n 1)
            if [[ -n "$MATUGEN_BIN" ]]; then
                if [ -w /usr/local/bin ]; then
                    mv "$MATUGEN_BIN" /usr/local/bin/matugen
                    chmod +x /usr/local/bin/matugen
                else
                    mkdir -p "$HOME/.local/bin"
                    mv "$MATUGEN_BIN" "$HOME/.local/bin/matugen"
                    chmod +x "$HOME/.local/bin/matugen"
                fi
                print_sub_ok "Matugen instalado correctamente."
            else
                print_sub_warn "No se extrajo binario de Matugen. Intentando vía Cargo (lento)..."
                cargo install matugen &>> "$LOG_FILE" && print_sub_ok "Matugen instalado vía Cargo." || print_sub_err "Fallo en instalación vía Cargo."
            fi
        else
            print_sub_err "Fallo al descargar/extraer Matugen."
        fi
    else
        print_sub_warn "No se localizó binario. Intentando vía Cargo (lento)..."
        cargo install matugen &>> "$LOG_FILE" && print_sub_ok "Matugen instalado vía Cargo." || print_sub_err "Fallo en instalación vía Cargo."
    fi
    rm -rf "$TEMP_MATUGEN"
fi

# Ajustar rutas en entorno
export PROJECT_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PROJECT_ROOT:$PATH"

# 7. Escribir configuraciones y variables locales
print_step "Configurando persistencia de rutas en el sistema..."
export PROJECT_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
export CURRENT_ENV="${CURRENT_ENV:-$(basename "$PACKAGE_DIR")}"
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
echo "set \$dots_cmd $PROJECT_ROOT/dots" > "$PACKAGE_DIR/dotfiles/i3/conf.d/vars.generated"
echo "set \$current_env $CURRENT_ENV" >> "$PACKAGE_DIR/dotfiles/i3/conf.d/vars.generated"



# Bashrc
add_rc() {
    grep -q "$1" "$HOME/.bashrc" || echo "$2" >> "$HOME/.bashrc"
}
add_rc ".local/bin" 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'
add_rc "MAHOGARA_DOTS" $'\n# Mahogara Dots\nexport PATH="'"$PROJECT_ROOT"':$PATH"\nexport MAHOGARA_DOTS="'"$PROJECT_ROOT"'"'
add_rc "QT_QPA_PLATFORMTHEME" 'export QT_QPA_PLATFORMTHEME=qt6ct'
print_sub_ok "Rutas y variables persistidas en ~/.bashrc"

# 8. Crear enlaces simbólicos
print_step "Enlazando archivos de configuración (symlinks)..."

BACKUP_DIR=""
BACKUPS_MADE=()

init_backup_dir() {
    [ -n "$BACKUP_DIR" ] && return
    local t d
    printf -v t '%(%Y%m%d_%H%M%S)T' -1
    printf -v d '%(%Y-%m-%d %H:%M:%S)T' -1
    BACKUP_DIR="$HOME/.config/i3dots_backups/backup_$t"
    mkdir -p "$BACKUP_DIR"
    echo "# Historial de backups - $d" > "$BACKUP_DIR/backup_list.txt"
}

safe_link() {
    local src="$1"
    local dst="$2"
    
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        init_backup_dir
        local name="${dst##*/}"
        
        mv "$dst" "$BACKUP_DIR/$name"
        echo "$dst -> $BACKUP_DIR/$name" >> "$BACKUP_DIR/backup_list.txt"
        BACKUPS_MADE+=("$name")
    fi
    
    ln -s "$src" "$dst"
    print_sub_ok "Enlazado: ${dst##*/}"
}

mkdir -p ~/.config
safe_link "$PACKAGE_DIR/dotfiles/i3" "$HOME/.config/i3"

safe_link "$PACKAGE_DIR/dotfiles/rofi" "$HOME/.config/rofi"
safe_link "$PACKAGE_DIR/dotfiles/kitty" "$HOME/.config/kitty"
safe_link "$PACKAGE_DIR/dotfiles/picom" "$HOME/.config/picom"
safe_link "$PACKAGE_DIR/dotfiles/gtk-3.0" "$HOME/.config/gtk-3.0"
safe_link "$PACKAGE_DIR/dotfiles/gtk-4.0" "$HOME/.config/gtk-4.0"
safe_link "$PACKAGE_DIR/dotfiles/qt6ct" "$HOME/.config/qt6ct"
safe_link "$PACKAGE_DIR/dotfiles/matugen" "$HOME/.config/matugen"
safe_link "$PACKAGE_DIR/dotfiles/.gtkrc-2.0" "$HOME/.gtkrc-2.0"

# 8.5 Configurar GTK para root (opcional, si se tienen privilegios sin contraseña)
if run_elevated_nopasswd; then
    print_sub "Configurando tema GTK para root..."
    run_elevated mkdir -p /root/.config /root/.themes
    run_elevated cp -rf "$PACKAGE_DIR/dotfiles/gtk-3.0" "$PACKAGE_DIR/dotfiles/gtk-4.0" /root/.config/
    run_elevated cp -f "$PACKAGE_DIR/dotfiles/.gtkrc-2.0" /root/
    [ -d "$HOME/.themes/adw-gtk3-dark" ] && run_elevated ln -sfn "$HOME/.themes/adw-gtk3-dark" /root/.themes/adw-gtk3-dark
    print_sub_ok "Configuración GTK copiada a /root."
fi

# Permisos de ejecución
print_sub "Asegurando permisos de ejecución en scripts..."
find "$PACKAGE_DIR/dotfiles/rofi/bin" -type f -name "*.sh" -o -not -name "*.*" -exec chmod +x {} + &>> "$LOG_FILE"
chmod +x "$PACKAGE_DIR/dotfiles/polybar_launch.sh" &>> "$LOG_FILE"
find "$PACKAGE_DIR/dotfiles/polybar_configs" -type f -name "*.sh" -exec chmod +x {} + &>> "$LOG_FILE"

# 9. Inicializar Wallpaper y Matugen
print_step "Estableciendo wallpaper e inicializando paleta..."
DEFAULT_WALL="${CLI_WALL:-${DEFAULT_WALLPAPER:-zd.png}}"
WALL_DIR="${CLI_WALL_SRC:-${WALLPAPER_SRC:-$PACKAGE_DIR/dotfiles/wall}}"

mkdir -p "$HOME/wall"
if [ -d "$WALL_DIR" ]; then
    # Crear enlaces simbólicos individuales de forma robusta (soporta espacios y subcarpetas)
    find "$WALL_DIR" -type f -exec ln -sf {} "$HOME/wall/" \;
fi

WALLPAPER_FILE="$HOME/wall/$DEFAULT_WALL"

if [ -f "$WALLPAPER_FILE" ]; then
    # Guardar estado del wallpaper
    mkdir -p "$HOME/.config/i3"
    ln -sf "$WALLPAPER_FILE" "$HOME/.config/i3/current"
    echo "$WALLPAPER_FILE" > "$HOME/.config/i3/wall"
    
    if command -v matugen &> /dev/null; then
        if matugen image "$WALLPAPER_FILE" --prefer saturation &>> "$LOG_FILE"; then
            print_sub_ok "Paleta de colores Matugen generada ($DEFAULT_WALL)."
        else
            print_sub_err "Fallo al ejecutar Matugen."
        fi
    fi
    if command -v feh &> /dev/null; then
        feh --bg-fill "$WALLPAPER_FILE" &>> "$LOG_FILE"
        print_sub_ok "Wallpaper fijado en pantalla."
    fi
else
    print_sub_err "No se pudo encontrar el wallpaper '$DEFAULT_WALL' en $HOME/wall/."
fi

# 9.5 Inicializar estado de la barra por defecto
print_step "Inicializando estado de la barra en disco..."
mkdir -p "$STATE_DIR/i3dots/bar"
echo "type=\"${BAR_DEFAULT_TYPE:-polybar_antigua}\"" > "$STATE_DIR/i3dots/bar/state.env"

# 10. Aplicar gsettings (GTK)
if command -v gsettings &> /dev/null; then
    print_step "Aplicando configuraciones GTK..."
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" &>> "$LOG_FILE"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" &>> "$LOG_FILE"
    gsettings set org.gnome.desktop.interface icon-theme "Inverse-pink-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "Layan-border-cursors" 2>/dev/null || true
    print_sub_ok "Tema oscuro y cursores establecidos."
fi

# Resumen de backups realizados (si los hubo)
if [ -n "$BACKUP_DIR" ] && [ "${#BACKUPS_MADE[@]}" -gt 0 ]; then
    print_step "Resumen de respaldos realizados..."
    print_sub_warn "Respaldos guardados en: $BACKUP_DIR"
    print_sub "Elementos respaldados: $(IFS=", "; echo "${BACKUPS_MADE[*]}")"
fi

print_success "Instalación completada correctamente para variante: ${VARIANT_NAME}"
