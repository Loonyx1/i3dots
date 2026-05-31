#!/usr/bin/env bash
# i3dots/install.sh

# 0. Definición de colores y helpers visuales
NC="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
GRAY="\e[90m"

LOG_FILE="${LOG_FILE:-/tmp/dots_install.log}"
echo -e "${GRAY}--- Inicio de instalación $(date) ---${NC}" > "$LOG_FILE"

print_step() {
    echo -e "${BLUE}•${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}•${NC} ${GREEN}${BOLD}$1${NC}"
}

print_sub() {
    echo -e "  ${GRAY}•${NC} $1"
}

print_sub_ok() {
    echo -e "  ${GREEN}•${NC} $1"
}

print_sub_warn() {
    echo -e "  ${YELLOW}•${NC} ${YELLOW}$1${NC}"
}

print_sub_err() {
    echo -e "  ${RED}•${NC} ${RED}$1${NC}" >&2
}

# Mostrar Banner
echo -e "${CYAN}${BOLD}"
cat << "EOF"
▗▄▄▄▖▄▄▄▄ ▗▄▄▄   ▗▄▖▗▄▄▄▖▗▄▄▖
  █     █ ▐▌  █ ▐▌ ▐▌ █ ▐▌
  █  ▀▀▀█ ▐▌  █ ▐▌ ▐▌ █  ▝▀▚▖
▗▄█▄▖▄▄▄█ ▐▙▄▄▀ ▝▚▄▞▘ █ ▗▄▄▞▘
          by loonyx
EOF
echo -e "${NC}"

# 1. Parseo de argumentos y persistencia de variante
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANT_ARG=""
IS_OFFLINE=false
CLI_WALL=""
CLI_WALL_SRC=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline)
            IS_OFFLINE=true
            shift
            ;;
        --wallpaper)
            CLI_WALL="$2"
            shift 2
            ;;
        --wallpaper-src)
            CLI_WALL_SRC="$2"
            shift 2
            ;;
        -*)
            shift
            ;;
        *)
            if [ -z "$VARIANT_ARG" ]; then
                VARIANT_ARG="$1"
            fi
            shift
            ;;
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

# 2. Detección de Hardware
print_sub "Detectando componentes de hardware..."
SYS_BAT=$(ls -1 /sys/class/power_supply/ | grep -E '^BAT' | head -n 1 || echo "BAT0")
SYS_ADAPTER=$(ls -1 /sys/class/power_supply/ | grep -E '^AC|^AD' | head -n 1 || echo "ACAD")
SYS_INTERFACE=$(ip link | awk '/state UP/ {print $2}' | tr -d ':' | head -n 1 || echo "wlan0")
SYS_BACKLIGHT=$(ls -1 /sys/class/backlight/ | head -n 1 || echo "intel_backlight")

HARDWARE_INI="$PACKAGE_DIR/dotfiles/polybar_base/hardware.ini"
if [ -f "$HARDWARE_INI" ]; then
    sed -i "s/sys_battery = .*/sys_battery = $SYS_BAT/" "$HARDWARE_INI"
    sed -i "s/sys_adapter = .*/sys_adapter = $SYS_ADAPTER/" "$HARDWARE_INI"
    sed -i "s/sys_network_interface = .*/sys_network_interface = $SYS_INTERFACE/" "$HARDWARE_INI"
    sed -i "s/sys_graphics_card = .*/sys_graphics_card = $SYS_BACKLIGHT/" "$HARDWARE_INI"
    print_sub_ok "Hardware configurado en hardware.ini ($SYS_BAT, $SYS_ADAPTER, $SYS_INTERFACE, $SYS_BACKLIGHT)"
else
    print_sub_warn "No se encontró hardware.ini para actualizar"
fi

# 3. Instalar dependencias
if [ -n "$PKG_LIST" ] && [ -z "$SKIP_SYSTEM_PKGS" ]; then
    print_step "Instalando paquetes y dependencias del sistema..."
    print_sub "Ejecutando gestor de paquetes (puede requerir sudo)..."
    if eval "$PKG_MANAGER $PKG_INSTALL_CMD $PKG_LIST" &>> "$LOG_FILE"; then
        print_sub_ok "Paquetes de sistema instalados correctamente."
    else
        print_sub_err "Fallo en gestor de paquetes. Detalles en $LOG_FILE"
        exit 1
    fi
fi

# 4. Nerd Fonts
print_step "Instalando tipografías (Nerd Fonts)..."
mkdir -p ~/.local/share/fonts

install_font() {
    local name="$1"
    local url="$2"
    if [ -d "$HOME/.local/share/fonts/$name" ] || [ -d "/usr/share/fonts/$name" ] || [ -d "/usr/share/fonts/TTF/$name" ] || [ -d "/usr/share/fonts/truetype/$name" ]; then
        print_sub_ok "Fuente $name ya instalada."
    elif [ -n "$SKIP_FONTS_DOWNLOAD" ]; then
        print_sub_ok "Fuente $name (omitida por configuración)."
    else
        print_sub "Instalando tipografía $name..."
        local TEMP_F=$(mktemp -d)
        if wget -q --show-progress -P "$TEMP_F" "$url" &>> "$LOG_FILE" && \
           unzip -q "$TEMP_F"/*.zip -d ~/.local/share/fonts/"$name" &>> "$LOG_FILE"; then
            rm -rf "$TEMP_F"
            print_sub_ok "Fuente $name lista."
        else
            rm -rf "$TEMP_F"
            print_sub_err "Fallo al descargar/extraer $name."
            return 1
        fi
    fi
}

install_font "JetBrainsMonoNerd" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
install_font "FiraCodeNerd" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
install_font "SymbolsNerdFont" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"
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
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
echo "set \$dots_cmd $PROJECT_ROOT/dots" > "$PACKAGE_DIR/dotfiles/i3/conf.d/vars.generated"

# Bashrc
if ! grep -q ".local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi
if ! grep -q "MAHOGARA_DOTS" "$HOME/.bashrc"; then
    echo -e "\n# Mahogara Dots" >> "$HOME/.bashrc"
    echo "export PATH=\"$PROJECT_ROOT:\$PATH\"" >> "$HOME/.bashrc"
    echo "export MAHOGARA_DOTS=\"$PROJECT_ROOT\"" >> "$HOME/.bashrc"
fi
if ! grep -q "QT_QPA_PLATFORMTHEME" "$HOME/.bashrc"; then
    echo 'export QT_QPA_PLATFORMTHEME=qt6ct' >> "$HOME/.bashrc"
fi
print_sub_ok "Rutas y variables persistidas en ~/.bashrc"

# 8. Crear enlaces simbólicos
print_step "Enlazando archivos de configuración (symlinks)..."
safe_link() {
    local src="$1"
    local dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -d "$dst" ]; then
        print_sub_warn "Directorio real '$dst' detectado. Guardando copia en '${dst}.bak'."
        mv "$dst" "${dst}.bak"
    elif [ -f "$dst" ]; then
        print_sub_warn "Archivo real '$dst' detectado. Guardando copia en '${dst}.bak'."
        mv "$dst" "${dst}.bak"
    fi
    ln -s "$src" "$dst"
    print_sub_ok "Enlazado: $(basename "$dst")"
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

# Permisos de ejecución
print_sub "Asegurando permisos de ejecución en scripts..."
find "$PACKAGE_DIR/dotfiles/rofi/bin" -type f -name "*.sh" -o -not -name "*.*" -exec chmod +x {} + &>> "$LOG_FILE"
find "$PACKAGE_DIR/dotfiles/polybar_base/scripts" -type f -name "*.sh" -exec chmod +x {} + &>> "$LOG_FILE"
find "$PACKAGE_DIR/dotfiles/polybar_configs" -type f -name "*.sh" -exec chmod +x {} + &>> "$LOG_FILE"

# 9. Inicializar Wallpaper y Matugen
print_step "Estableciendo wallpaper e inicializando paleta..."
DEFAULT_WALL="${CLI_WALL:-${DEFAULT_WALLPAPER:-zd.png}}"
WALL_DIR="${CLI_WALL_SRC:-${WALLPAPER_SRC:-$PACKAGE_DIR/dotfiles/wall}}"

mkdir -p "$HOME/wall"
if [ -d "$WALL_DIR" ]; then
    # Crear enlaces simbólicos individuales para no duplicar espacio en disco
    for f in "$WALL_DIR"/*; do
        if [ -f "$f" ]; then
            ln -sf "$f" "$HOME/wall/$(basename "$f")"
        fi
    done
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

# 10. Aplicar gsettings (GTK)
if command -v gsettings &> /dev/null; then
    print_step "Aplicando configuraciones GTK..."
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" &>> "$LOG_FILE"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" &>> "$LOG_FILE"
    gsettings set org.gnome.desktop.interface icon-theme "Inverse-pink-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "Layan-border-cursors" 2>/dev/null || true
    print_sub_ok "Tema oscuro y cursores establecidos."
fi

print_success "Instalación completada correctamente para variante: ${VARIANT_NAME}"
