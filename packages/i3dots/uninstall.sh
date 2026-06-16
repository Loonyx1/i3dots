#!/usr/bin/env bash
# i3dots/uninstall.sh

# 0. Cargar biblioteca de utilidades del core
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -f "$PROJECT_ROOT/core/lib/utils.sh" ]; then
    source "$PROJECT_ROOT/core/lib/utils.sh"
else
    # Fallback si no hay utils.sh
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    print_step() { echo -e "${CYAN}>>> $1${NC}"; }
    print_sub() { echo -e "  $1"; }
    print_sub_ok() { echo -e "  ${GREEN}ok:${NC} $1"; }
    print_sub_warn() { echo -e "  ${YELLOW}warn:${NC} $1"; }
    print_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
fi

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="$(basename "$PACKAGE_DIR")"

print_step "Iniciando desinstalación de $PACKAGE_NAME..."

# 1. Eliminar enlaces simbólicos
print_step "Eliminando enlaces simbólicos en ~/.config..."

targets=(
    "$HOME/.config/i3"
    "$HOME/.config/rofi"
    "$HOME/.config/kitty"
    "$HOME/.config/picom"
    "$HOME/.config/gtk-3.0"
    "$HOME/.config/gtk-4.0"
    "$HOME/.config/qt6ct"
    "$HOME/.config/matugen"
    "$HOME/.gtkrc-2.0"
)

for target in "${targets[@]}"; do
    if [ -L "$target" ]; then
        rm "$target"
        print_sub_ok "Eliminado enlace: $target"
    elif [ -e "$target" ]; then
        print_sub_warn "Omitido (no es un enlace): $target"
    fi
done

# 2. Limpiar Wallpapers
print_step "Limpiando directorio de wallpapers (~/wall)..."
if [ -d "$HOME/wall" ]; then
    # Solo eliminar enlaces simbólicos dentro de ~/wall para no borrar archivos reales del usuario
    find "$HOME/wall" -maxdepth 1 -type l -delete
    # Si el directorio queda vacío, lo borramos (opcional)
    [ -z "$(ls -A "$HOME/wall")" ] && rmdir "$HOME/wall" && print_sub_ok "Directorio ~/wall eliminado (estaba vacío)." || print_sub_warn "~/wall contiene archivos reales, se mantiene."
fi

# 3. Limpiar estado y archivos generados
print_step "Limpiando archivos de estado y generados..."
rm -f "$PACKAGE_DIR/dotfiles/i3/conf.d/vars.generated"
rm -f "$PACKAGE_DIR/.current_variant"

# Limpiar estado del paquete (nuevo esquema)
if [ -d "$PROJECT_ROOT/core/state/$PACKAGE_NAME" ]; then
    rm -rf "$PROJECT_ROOT/core/state/$PACKAGE_NAME"
    print_sub_ok "Estado en core/state/$PACKAGE_NAME eliminado."
fi

# Limpiar basura legada (esquema antiguo sin prefijo de paquete)
legacy_states=("bar" "display" "wallpaper" "matugen")
for legacy in "${legacy_states[@]}"; do
    if [ -d "$PROJECT_ROOT/core/state/$legacy" ]; then
        rm -rf "$PROJECT_ROOT/core/state/$legacy"
        print_sub_ok "Basura legada core/state/$legacy eliminada."
    fi
done

# 4. Limpiar entradas en .bashrc (Surgical removal)
print_step "Limpiando ~/.bashrc..."
if [ -f "$HOME/.bashrc" ]; then
    # Eliminar bloques de Mahogara Dots y variables específicas
    sed -i '/# Mahogara Dots/,/export MAHOGARA_DOTS/d' "$HOME/.bashrc"
    sed -i '/export PATH=".*\.local\/bin:.*\.cargo\/bin:\$PATH"/d' "$HOME/.bashrc"
    sed -i '/export QT_QPA_PLATFORMTHEME=qt6ct/d' "$HOME/.bashrc"
    # Limpiar líneas de PATH que apunten al proyecto
    sed -i "s|export PATH=\"$PROJECT_ROOT:\$PATH\"||g" "$HOME/.bashrc"
    print_sub_ok ".bashrc limpio."
fi

# 5. Limpiar root (si se usó)
if [ "$(id -u)" -eq 0 ] || command -v sudo &>/dev/null; then
    print_step "Limpiando configuraciones de root (opcional)..."
    SUDO_CMD=""
    [ "$(id -u)" -ne 0 ] && SUDO_CMD="sudo"
    
    $SUDO_CMD rm -f /root/.gtkrc-2.0
    $SUDO_CMD rm -rf /root/.config/gtk-3.0 /root/.config/gtk-4.0
    $SUDO_CMD rm -f /root/.themes/adw-gtk3-dark
    print_sub_ok "Configuraciones de root eliminadas."
fi

print_success "Desinstalación completada. Se recomienda reiniciar la sesión de i3."
