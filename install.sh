#!/bin/bash

# =============================================================================
# Script de Instalación para Debian 13 (Trixie)
# Configuración: i3wm, Polybar, Rofi, Kitty, Picom, Matugen
# =============================================================================

set -e

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> Actualizando sistema...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${BLUE}>>> Instalando dependencias de Debian 13...${NC}"
# Lista de paquetes necesarios basados en tu .config
sudo apt install -y \
    i3-wm \
    polybar \
    rofi \
    kitty \
    picom \
    qt6ct \
    feh \
    dex \
    lxpolkit \
    pipewire \
    wireplumber \
    x11-xkb-utils \
    brightnessctl \
    playerctl \
    fonts-jetbrains-mono \
    fonts-font-awesome \
    git \
    curl \
    wget \
    build-essential \
    cargo \
    pkg-config \
    libssl-dev \
    libxcb-randr0-dev \
    libxcb-util-dev \
    libxcb-icccm4-dev \
    libxcb-keysyms1-dev \
    libxcb-cursor-dev \
    libxcb-xkb-dev \
    libxcb-xrm-dev \
    libxcb-shape0-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    python3-pip \
    unzip \
    fontconfig \
    imagemagick

echo -e "${BLUE}>>> Instalando Nerd Fonts (JetBrainsMono y Hack)...${NC}"
mkdir -p ~/.local/share/fonts
TEMP_FONTS=$(mktemp -d)

# Descargar JetBrainsMono
wget -P "$TEMP_FONTS" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip
unzip "$TEMP_FONTS/JetBrainsMono.zip" -d ~/.local/share/fonts/JetBrainsMonoNerd

# Descargar Hack
wget -P "$TEMP_FONTS" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip
unzip "$TEMP_FONTS/Hack.zip" -d ~/.local/share/fonts/HackNerd

# Limpiar y actualizar cache
rm -rf "$TEMP_FONTS"
fc-cache -fv

echo -e "${BLUE}>>> Instalando Matugen (vía Cargo)...${NC}"
if ! command -v matugen &> /dev/null; then
    cargo install matugen
    # Asegurar que el PATH de cargo esté en el bashrc si no está
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
# Copiar todo el contenido de .config del directorio actual al del usuario
cp -r .config/* ~/.config/
[ -d ".cache" ] && cp -r .cache/* ~/.cache/

echo -e "${BLUE}>>> Moviendo carpeta 'wall' a /home/${USER}/...${NC}"
# El usuario pidió que wall estuviera directamente en el home
if [ -d "~/.config/wall" ]; then
    mv ~/.config/wall ~/wall
elif [ -d ".config/wall" ]; then
    # Por si se ejecuta desde el repo sin haber copiado aún
    cp -r .config/wall ~/wall
    rm -rf ~/.config/wall
fi

echo -e "${BLUE}>>> Ajustando permisos de ejecución...${NC}"
find ~/.config -type f -name "*.sh" -exec chmod +x {} +
chmod +x ~/.config/i3/mini-matugen-j 2>/dev/null || true
[ -d ~/.config/rofi/bin ] && chmod +x ~/.config/rofi/bin/*

echo -e "${GREEN}>>> ¡Instalación completada!${NC}"
echo -e "${BLUE}>>> Notas importantes:${NC}"
echo "1. Las fuentes Nerd Fonts (JetBrainsMono y Hack) han sido instaladas en ~/.local/share/fonts."
echo "2. Reinicia la sesión y elige 'i3' en el gestor de login."
echo "3. Los wallpapers se encuentran en ~/wall"
echo "4. Matugen se instaló en ~/.cargo/bin/matugen"
