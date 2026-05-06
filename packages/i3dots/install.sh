#!/usr/bin/env bash
# i3dotsbyloonyx/install.sh

# 1. Persistencia de variante
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "$1" ]]; then
    echo "$1" > "$PACKAGE_DIR/.current_variant"
fi

# Cargar variante para tener las variables de paquetes
VARIANT_NAME=$(cat "$PACKAGE_DIR/.current_variant" 2>/dev/null || echo "debian")
source "$PACKAGE_DIR/envs/${VARIANT_NAME}.env"

echo "Instalando i3dotsbyloonyx (Variante: $VARIANT_NAME)..."

# 0. Detección de Hardware (Batería, Adaptador, Red, Backlight)
echo "Detectando hardware..."
SYS_BAT=$(ls -1 /sys/class/power_supply/ | grep -E '^BAT' | head -n 1 || echo "BAT0")
SYS_ADAPTER=$(ls -1 /sys/class/power_supply/ | grep -E '^AC|^AD' | head -n 1 || echo "ACAD")
SYS_INTERFACE=$(ip link | awk '/state UP/ {print $2}' | tr -d ':' | head -n 1 || echo "wlan0")
SYS_BACKLIGHT=$(ls -1 /sys/class/backlight/ | head -n 1 || echo "intel_backlight")

# Actualizar hardware.ini con el hardware detectado
HARDWARE_INI="$PACKAGE_DIR/dotfiles/polybar_base/hardware.ini"
if [ -f "$HARDWARE_INI" ]; then
    sed -i "s/sys_battery = .*/sys_battery = $SYS_BAT/" "$HARDWARE_INI"
    sed -i "s/sys_adapter = .*/sys_adapter = $SYS_ADAPTER/" "$HARDWARE_INI"
    sed -i "s/sys_network_interface = .*/sys_network_interface = $SYS_INTERFACE/" "$HARDWARE_INI"
    sed -i "s/sys_graphics_card = .*/sys_graphics_card = $SYS_BACKLIGHT/" "$HARDWARE_INI"
fi

# 2. Instalar dependencias
if [ -n "$PKG_LIST" ]; then
    eval "$PKG_MANAGER $PKG_INSTALL_CMD $PKG_LIST"
fi

# 3. Nerd Fonts (JetBrainsMono, FiraCode y Symbols Only)
mkdir -p ~/.local/share/fonts
install_font() {
    local name="$1"
    local url="$2"
    if [ ! -d ~/.local/share/fonts/"$name" ]; then
        echo "Instalando fuente $name..."
        local TEMP_F=$(mktemp -d)
        wget -q --show-progress -P "$TEMP_F" "$url"
        unzip -q "$TEMP_F"/*.zip -d ~/.local/share/fonts/"$name"
        rm -rf "$TEMP_F"
        fc-cache -fv
    fi
}

install_font "JetBrainsMonoNerd" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
install_font "FiraCodeNerd" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
install_font "SymbolsNerdFont" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"

# 3.5. Temas (adw-gtk3)
mkdir -p ~/.themes
if [ ! -d ~/.themes/adw-gtk3-dark ]; then
    echo "Instalando adw-gtk3..."
    wget https://github.com/lassekongo83/adw-gtk3/releases/download/v6.5/adw-gtk3v6.5.tar.xz -O /tmp/adw-gtk3.tar.xz
    tar -xf /tmp/adw-gtk3.tar.xz -C ~/.themes
    rm /tmp/adw-gtk3.tar.xz
fi

# 4. Matugen (Binario precompilado)
if ! command -v matugen &> /dev/null; then
    echo "Instalando Matugen (Binario)..."
    TEMP_MATUGEN=$(mktemp -d)
    URL=$(curl -s https://api.github.com/repos/InioX/matugen/releases/latest | grep "browser_download_url.*x86_64.tar.gz" | cut -d '"' -f 4)
    if [[ -n "$URL" ]]; then
        wget -P "$TEMP_MATUGEN" "$URL"
        tar -xzf "$TEMP_MATUGEN"/*.tar.gz -C "$TEMP_MATUGEN"
        
        # El binario puede tener el nombre completo o solo 'matugen'
        # Buscamos el ejecutable que se extrajo
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
        else
            echo "No se encontró el binario extraído, intentando vía Cargo..."
            cargo install matugen
        fi
    else
        echo "No se pudo encontrar binario, instalando vía Cargo (lento)..."
        cargo install matugen
    fi
    rm -rf "$TEMP_MATUGEN"
fi

# Asegurar que las rutas locales estén en el PATH para el resto del script
export PROJECT_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PROJECT_ROOT:$PATH"

# Configurar variables de i3 con rutas absolutas
echo "set \$dots_cmd $PROJECT_ROOT/dots" > "$PACKAGE_DIR/dotfiles/i3/conf.d/vars.generated"

# Añadir a .bashrc para persistencia futura
if ! grep -q ".local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi

if ! grep -q "MAHOGARA_DOTS" "$HOME/.bashrc"; then
    echo "# Mahogara Dots" >> "$HOME/.bashrc"
    echo "export PATH=\"$PROJECT_ROOT:\$PATH\"" >> "$HOME/.bashrc"
    echo "export MAHOGARA_DOTS=\"$PROJECT_ROOT\"" >> "$HOME/.bashrc"
fi

# 5. Variables de entorno (QT)
if ! grep -q "QT_QPA_PLATFORMTHEME" "$HOME/.bashrc"; then
    echo 'export QT_QPA_PLATFORMTHEME=qt6ct' >> "$HOME/.bashrc"
fi

# 6. Crear Symlinks (Función Robusta)
safe_link() {
    local src="$1"
    local dst="$2"
    
    # Si el destino existe y es un enlace simbólico, lo quitamos
    if [ -L "$dst" ]; then
        rm "$dst"
    # Si el destino es un directorio real, lo respaldamos
    elif [ -d "$dst" ]; then
        echo "Aviso: '$dst' es un directorio real. Haciendo backup a '${dst}.bak'..."
        mv "$dst" "${dst}.bak"
    fi
    
    ln -s "$src" "$dst"
    echo "Enlazado: $dst -> $src"
}

mkdir -p ~/.config
safe_link "$PACKAGE_DIR/dotfiles/i3" "$HOME/.config/i3"
# Inicialización de Polybar (Base + Antigua por defecto)
mkdir -p "$HOME/.config/polybar"
cp -rf "$PACKAGE_DIR/dotfiles/polybar_base/." "$HOME/.config/polybar/"
cp -rf "$PACKAGE_DIR/dotfiles/polybar_configs/polybar_antigua/." "$HOME/.config/polybar/"

safe_link "$PACKAGE_DIR/dotfiles/rofi" "$HOME/.config/rofi"
safe_link "$PACKAGE_DIR/dotfiles/kitty" "$HOME/.config/kitty"
safe_link "$PACKAGE_DIR/dotfiles/picom" "$HOME/.config/picom"
safe_link "$PACKAGE_DIR/dotfiles/gtk-3.0" "$HOME/.config/gtk-3.0"
safe_link "$PACKAGE_DIR/dotfiles/gtk-4.0" "$HOME/.config/gtk-4.0"
safe_link "$PACKAGE_DIR/dotfiles/qt6ct" "$HOME/.config/qt6ct"
safe_link "$PACKAGE_DIR/dotfiles/matugen" "$HOME/.config/matugen"

# 7. Permisos de ejecución
find "$PACKAGE_DIR/dotfiles/rofi/bin" -type f -name "*.sh" -o -not -name "*.*" -exec chmod +x {} +
find "$PACKAGE_DIR/dotfiles/polybar_base/scripts" -type f -name "*.sh" -exec chmod +x {} +
find "$PACKAGE_DIR/dotfiles/polybar_configs" -type f -name "*.sh" -exec chmod +x {} +

# 8. Copiar Wallpaper inicial si no existe
[ ! -d "$HOME/wall" ] && cp -r "$PACKAGE_DIR/dotfiles/wall" "$HOME/wall"

# 9. Matugen inicial (Colores por defecto)
if command -v matugen &> /dev/null; then
    matugen image "$HOME/wall/wall.png"
fi

# 10. Aplicar Tema GTK (gsettings)
if command -v gsettings &> /dev/null; then
    echo "Aplicando Tema GTK via gsettings..."
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    # Opcionales si el usuario tiene los iconos/cursores (basado en settings.ini)
    gsettings set org.gnome.desktop.interface icon-theme "Inverse-pink-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "Layan-border-cursors" 2>/dev/null || true
fi

echo "Instalación completada para $VARIANT_NAME."
