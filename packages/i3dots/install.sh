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
    print_step "Verificando dependencias del sistema..."
    
    # Obtener paquetes instalados localmente de forma agnóstica y veloz
    INSTALLED_PKGS=""
    if [ -n "$PKG_QUERY_CMD" ]; then
        INSTALLED_PKGS=$(eval "$PKG_QUERY_CMD" 2>/dev/null)
    fi

    # Filtrar paquetes de PKG_LIST que no estén instalados (0 forks dentro del bucle)
    MISSING_PKGS=()
    # Reemplazar saltos de línea por espacios para búsqueda exacta nativa en Bash
    INSTALLED_FLAT=" ${INSTALLED_PKGS//$'\n'/ } "
    for pkg in $PKG_LIST; do
        if [[ "$INSTALLED_FLAT" =~ " $pkg " ]]; then
            continue
        else
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        print_sub_ok "Todas las dependencias ya están instaladas."
    else
        print_sub "Paquetes faltantes a instalar: ${MISSING_PKGS[*]}"
        
        # Generar comando de instalación solo con los paquetes faltantes
        FULL_CMD=""
        if [ -n "$PKG_UPDATE_CMD" ]; then
            FULL_CMD="$PKG_MANAGER $PKG_UPDATE_CMD && "
        fi
        FULL_CMD+="$PKG_MANAGER $PKG_INSTALL_CMD ${MISSING_PKGS[*]}"

        print_sub "Procesando instalación de paquetes faltantes..."
        run_elevated --ticker bash -c "$FULL_CMD"
        
        # Volver a verificar qué paquetes siguen sin estar instalados
        INSTALLED_FLAT_POST=" $(eval "$PKG_QUERY_CMD" 2>/dev/null | tr '\n' ' ') "
        STILL_MISSING=()
        for pkg in "${MISSING_PKGS[@]}"; do
            [[ ! "$INSTALLED_FLAT_POST" =~ " $pkg " ]] && STILL_MISSING+=("$pkg")
        done
        
        if [ ${#STILL_MISSING[@]} -eq 0 ]; then
            print_sub_ok "Paquetes de sistema instalados correctamente."
        else
            print_sub_err "Error: Paquetes no instalados (no encontrados en repositorio o fallo): ${STILL_MISSING[*]}"
        fi
    fi
fi

# 4. Nerd Fonts
print_step "Instalando tipografías (Nerd Fonts)..."
mkdir -p ~/.local/share/fonts

fonts_list=(
    "JetBrainsMonoNerd|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
    "FiraCodeNerd|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
    "SymbolsNerdFont|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"
)

INSTALLED_FONTS=()
MISSING_FONTS=()

check_font_installed() {
    local name="$1"
    for path in "$HOME/.local/share/fonts/$name" "/usr/share/fonts/$name" "/usr/share/fonts/TTF/$name" "/usr/share/fonts/truetype/$name"; do
        [ -d "$path" ] && return 0
    done
    return 1
}

for f in "${fonts_list[@]}"; do
    name="${f%%|*}"
    if check_font_installed "$name"; then
        INSTALLED_FONTS+=("$name")
    else
        MISSING_FONTS+=("$f")
    fi
done

joined_fonts=$(printf ", %s" "${INSTALLED_FONTS[@]}")
if [ ${#INSTALLED_FONTS[@]} -gt 0 ] && [ ${#MISSING_FONTS[@]} -eq 0 ]; then
    print_sub_ok "Tipografías ya instaladas: ${joined_fonts:2}"
else
    [ ${#INSTALLED_FONTS[@]} -gt 0 ] && print_sub_ok "Tipografías ya instaladas: ${joined_fonts:2}"
    for f in "${MISSING_FONTS[@]}"; do
        name="${f%%|*}"
        url="${f##*|}"
        if [ -n "$SKIP_FONTS_DOWNLOAD" ]; then
            print_sub_ok "Fuente $name (omitida)."
            continue
        fi
        print_sub "Instalando tipografía $name..."
        temp=$(mktemp -d)
        if wget -q --show-progress -P "$temp" "$url" &>> "$LOG_FILE" && unzip -q "$temp"/*.zip -d ~/.local/share/fonts/"$name" &>> "$LOG_FILE"; then
            print_sub_ok "Fuente $name lista."
        else
            print_sub_err "Fallo al descargar/extraer $name."
        fi
        rm -rf "$temp"
    done
fi
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

install_matugen_via_cargo() {
    print_sub_warn "Fallo en binario. Intentando vía Cargo (lento)..."
    if ! command -v cargo &>/dev/null; then
        print_sub "Cargo no encontrado. Instalando..."
        run_elevated --ticker bash -c "$PKG_MANAGER $PKG_INSTALL_CMD cargo"
    fi
    if command -v cargo &>/dev/null && cargo install matugen &>> "$LOG_FILE"; then
        print_sub_ok "Matugen instalado vía Cargo."
    else
        print_sub_err "Fallo al instalar Matugen."
    fi
}

if command -v matugen &> /dev/null; then
    print_sub_ok "Matugen ya instalado."
elif [ -n "$SKIP_MATUGEN_DOWNLOAD" ]; then
    print_sub_ok "Matugen (omitido por configuración)."
else
    print_sub "Buscando última versión de Matugen..."
    TEMP_MATUGEN=$(mktemp -d)
    URL=$(curl -s https://api.github.com/repos/InioX/matugen/releases/latest | grep "browser_download_url.*x86_64.tar.gz" | cut -d '"' -f 4)
    
    INSTALLED=false
    if [[ -n "$URL" ]] && wget -q -P "$TEMP_MATUGEN" "$URL" &>> "$LOG_FILE" && tar -xzf "$TEMP_MATUGEN"/*.tar.gz -C "$TEMP_MATUGEN" &>> "$LOG_FILE"; then
        MATUGEN_BIN=$(find "$TEMP_MATUGEN" -type f -executable -name "matugen*" | head -n 1)
        if [[ -n "$MATUGEN_BIN" ]]; then
            DEST="/usr/local/bin"
            [ ! -w "$DEST" ] && DEST="$HOME/.local/bin"
            mkdir -p "$DEST"
            mv "$MATUGEN_BIN" "$DEST/matugen"
            chmod +x "$DEST/matugen"
            print_sub_ok "Matugen instalado correctamente."
            INSTALLED=true
        fi
    fi
    
    if [ "$INSTALLED" = "false" ]; then
        install_matugen_via_cargo
    fi
    rm -rf "$TEMP_MATUGEN"
fi

# 7. Escribir configuraciones y variables locales
print_step "Configurando persistencia de rutas en el sistema..."
export PROJECT_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
export CURRENT_ENV="${CURRENT_ENV:-$(basename "$PACKAGE_DIR")}"
export STATE_DIR="${STATE_DIR:-$PROJECT_ROOT/core/state}"
echo "set \$dots_cmd $PROJECT_ROOT/dots" > "$PACKAGE_DIR/config/i3/conf.d/vars.generated"
echo "set \$current_env $CURRENT_ENV" >> "$PACKAGE_DIR/config/i3/conf.d/vars.generated"

# Bashrc
add_rc() {
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -q "$1" "$rc" && echo "$2" >> "$rc"
    done
}
add_rc ".local/bin" 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'
add_rc "DOTS_PATH" "export PATH=\"$PROJECT_ROOT:\$PATH\""
add_rc "QT_QPA_PLATFORMTHEME" 'export QT_QPA_PLATFORMTHEME=qt6ct'


# Entorno Global (/etc/environment) para soporte de display managers (ej: emptty) y startx
add_env() {
    run_elevated bash -c "grep -q '$1' /etc/environment || echo '$2' >> /etc/environment"
}
add_env "QT_QPA_PLATFORMTHEME" "QT_QPA_PLATFORMTHEME=qt6ct"

print_sub_ok "Rutas y variables persistidas en ~/.bashrc y /etc/environment"

# 8. Crear enlaces simbólicos (Sistema Agnóstico)
print_step "Enlazando archivos de configuración (symlinks)..."

BACKUP_DIR=""
BACKUPS_MADE=()
LINKS_MADE=()

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
    LINKS_MADE+=("${dst##*/}")
}

mkdir -p ~/.config

# Enlazar todo lo que esté en config/ hacia ~/.config/ (Excluyendo Polybar por ser dinámico)
if [ -d "$PACKAGE_DIR/config" ]; then
    for item in "$PACKAGE_DIR/config"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        # Polybar se gestiona vía hook para evitar ensuciar el repo con enlaces dinámicos
        [ "$name" == "polybar" ] && continue
        safe_link "$item" "$HOME/.config/$name"
    done
fi

# Enlazar todo lo que esté en root/ hacia ~/
if [ -d "$PACKAGE_DIR/root" ]; then
    # Usar dotglob para que * incluya archivos ocultos en este loop
    (
        shopt -s dotglob
        for item in "$PACKAGE_DIR/root"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            [[ "$name" == "." || "$name" == ".." ]] && continue
            safe_link "$item" "$HOME/$name"
        done
    )
fi

joined_links=$(printf ", %s" "${LINKS_MADE[@]}")
[ ${#LINKS_MADE[@]} -gt 0 ] && print_sub_ok "Configuraciones enlazadas: ${joined_links:2}"

# 8.5 Configurar GTK para root (opcional)
if run_elevated_nopasswd; then
    print_sub "Configurando tema GTK para root..."
    run_elevated mkdir -p /root/.config /root/.themes
    run_elevated cp -rf "$PACKAGE_DIR/config/gtk-3.0" "$PACKAGE_DIR/config/gtk-4.0" /root/.config/
    [ -f "$PACKAGE_DIR/root/.gtkrc-2.0" ] && run_elevated cp -f "$PACKAGE_DIR/root/.gtkrc-2.0" /root/
    [ -d "$HOME/.themes/adw-gtk3-dark" ] && run_elevated ln -sfn "$HOME/.themes/adw-gtk3-dark" /root/.themes/adw-gtk3-dark
    print_sub_ok "Configuración GTK copiada a /root."
fi

# Permisos de ejecución
print_sub "Asegurando permisos de ejecución en scripts..."
chmod +x "$PACKAGE_DIR/bin/polybar_launch.sh" &>> "$LOG_FILE"
find "$PACKAGE_DIR/config/rofi/bin" -type f -exec chmod +x {} + &>> "$LOG_FILE"
find "$PACKAGE_DIR/config/polybar" -type f -name "*.sh" -exec chmod +x {} + &>> "$LOG_FILE"

# 9. Inicializar Wallpaper y Matugen
print_step "Estableciendo wallpaper e inicializando paleta..."
DEFAULT_WALL="${CLI_WALL:-${DEFAULT_WALLPAPER:-zd.png}}"
WALL_DIR="${CLI_WALL_SRC:-${WALLPAPER_SRC:-$PACKAGE_DIR/assets/wall}}"

mkdir -p "$HOME/wall"
if [ -d "$WALL_DIR" ]; then
    find "$WALL_DIR" -type f -exec ln -sf {} "$HOME/wall/" \;
fi

WALLPAPER_FILE="$HOME/wall/$DEFAULT_WALL"

if [ -f "$WALLPAPER_FILE" ]; then
    mkdir -p "$HOME/.config/i3"
    ln -sf "$WALLPAPER_FILE" "$HOME/.config/i3/current"
    echo "$WALLPAPER_FILE" > "$HOME/.config/i3/wall"
    
    if command -v matugen &> /dev/null; then
        # Pasar la ruta de config de matugen explícitamente
        if matugen --config "$PACKAGE_DIR/config/matugen/config.toml" image "$WALLPAPER_FILE" --prefer saturation &>> "$LOG_FILE"; then
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

# 9.6 Inicializar logo de fastfetch
ln -sf "../envs/${VARIANT_NAME}.logo" "$PACKAGE_DIR/config/fastfetch/logo.txt"

# Preparar carpeta real de Polybar y provisión inicial de colores
mkdir -p ~/.config/polybar
[ ! -f ~/.config/polybar/colors.ini ] && cp "$PACKAGE_DIR/config/polybar/colors.ini" ~/.config/polybar/colors.ini

# Ejecutar hook de Polybar para generar variables iniciales
if [ -f "$PACKAGE_DIR/hooks/components/polybar.sh" ]; then
    print_sub "Ejecutando hook de Polybar..."
    export PACKAGE_DIR
    bash "$PACKAGE_DIR/hooks/components/polybar.sh" &>> "$LOG_FILE"
    print_sub_ok "Configuración de Polybar inicializada."
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

# Resumen de backups realizados
if [ -n "$BACKUP_DIR" ] && [ "${#BACKUPS_MADE[@]}" -gt 0 ]; then
    print_step "Resumen de respaldos realizados..."
    print_sub_warn "Respaldos guardados en: $BACKUP_DIR"
    print_sub "Elementos respaldados: $(IFS=", "; echo "${BACKUPS_MADE[*]}")"
fi

print_success "Instalación completada correctamente para variante: ${VARIANT_NAME}"
