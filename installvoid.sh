#!/bin/bash

# =============================================================================
# Script de Instalación para Void Linux
# Configuración: i3wm, Polybar, Rofi, Kitty, Picom, Matugen
# =============================================================================

set -e

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> Actualizando sistema...${NC}"
sudo xbps-install -Syu

echo -e "${BLUE}>>> Instalando dependencias de Void Linux...${NC}"
# Mapeo de paquetes para Void Linux
PACKAGES=(
    i3
    polybar
    rofi
    kitty
    picom
    qt6ct
    feh
    dex
    polkit-gnome
    pipewire
    wireplumber
    pulseaudio-utils
    setxkbmap
    brightnessctl
    playerctl
    maim
    xclip
    xdotool
    nemo
    dmenu
    git
    curl
    wget
    unzip
    base-devel
    cargo
    pkg-config
    openssl-devel
    libxcb-devel
    xcb-util-devel
    xcb-util-image-devel
    xcb-util-keysyms-devel
    xcb-util-renderutil-devel
    xcb-util-wm-devel
    libxkbcommon-devel
    font-awesome6
    fontconfig
    ImageMagick
)

# Instalamos uno por uno para ignorar los ya instalados sin que el script se detenga
for pkg in "${PACKAGES[@]}"; do
    echo -e "${BLUE}>>> Intentando instalar: $pkg...${NC}"
    sudo xbps-install -y "$pkg" || echo -e "${GREEN}>>> $pkg ya instalado o no disponible.${NC}"
done

echo -e "${BLUE}>>> Instalando Nerd Fonts adicionales (JetBrainsMono y Hack)...${NC}"
mkdir -p ~/.local/share/fonts
if [ ! -d ~/.local/share/fonts/JetBrainsMonoNerd ] || [ ! -d ~/.local/share/fonts/HackNerd ]; then
    TEMP_FONTS=$(mktemp -d)

    if [ ! -d ~/.local/share/fonts/JetBrainsMonoNerd ]; then
        echo -e "${BLUE}>>> Descargando JetBrainsMono...${NC}"
        wget -P "$TEMP_FONTS" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip
        unzip "$TEMP_FONTS/JetBrainsMono.zip" -d ~/.local/share/fonts/JetBrainsMonoNerd
    fi

    if [ ! -d ~/.local/share/fonts/HackNerd ]; then
        echo -e "${BLUE}>>> Descargando Hack...${NC}"
        wget -P "$TEMP_FONTS" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip
        unzip "$TEMP_FONTS/Hack.zip" -d ~/.local/share/fonts/HackNerd
    fi

    # Limpiar y actualizar cache
    rm -rf "$TEMP_FONTS"
    fc-cache -fv
else
    echo -e "${GREEN}>>> Las fuentes ya están instaladas.${NC}"
fi

echo -e "${BLUE}>>> Instalando Matugen (vía Cargo)...${NC}"
if ! command -v matugen &> /dev/null; then
    cargo install matugen
    if ! grep -q 'cargo/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
else
    echo "Matugen ya está instalado."
fi

echo -e "${BLUE}>>> Configurando directorios...${NC}"
mkdir -p ~/.config

echo -e "${BLUE}>>> Copiando archivos de configuración...${NC}"
[ -d ".cache" ] && cp -r .cache/* ~/.cache/
for item in .configvoid/*; do
    name=$(basename "$item")
    if [ -d "$HOME/.config/$name" ] || [ -f "$HOME/.config/$name" ]; then
        echo -e "${GREEN}>>> ~/.config/$name ya existe. Saltando...${NC}"
    else
        echo -e "${BLUE}>>> Copiando $name a ~/.config/...${NC}"
        cp -r "$item" ~/.config/
    fi
done

echo -e "${BLUE}>>> Instalando wallpapers en ~/wall...${NC}"
if [ -d "$HOME/wall" ]; then
    echo -e "${GREEN}>>> ~/wall ya existe. Saltando...${NC}"
else
    if [ -d "wall" ]; then
        cp -r wall ~/wall
    elif [ -d ".configvoid/wall" ]; then
        cp -r .configvoid/wall ~/wall
    fi
fi

echo -e "${BLUE}>>> Ajustando permisos de ejecución...${NC}"
find ~/.config -type f -name "*.sh" -exec chmod +x {} +
chmod +x ~/.config/i3/mini-matugen-j 2>/dev/null || true
[ -d ~/.config/rofi/bin ] && chmod +x ~/.config/rofi/bin/*

echo -e "${GREEN}>>> ¡Instalación completada!${NC}"
echo -e "${BLUE}>>> Notas importantes para Void Linux:${NC}"
echo "1. Asegúrate de que los servicios dbus y elogind estén activos."
echo "2. Usa 'exec i3' en tu ~/.xinitrc si no usas gestor de login."
echo "3. Los wallpapers se encuentran en ~/wall"
echo "4. Matugen se instaló en ~/.cargo/bin/matugen"
