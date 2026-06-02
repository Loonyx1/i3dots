#!/usr/bin/env bash
# Biblioteca compartida de utilidades de dots (core/lib/utils.sh)

# Definición de colores ANSI
NC="\e[0m" BOLD="\e[1m" GRAY="\e[90m"
RED="\e[31m" GREEN="\e[32m" YELLOW="\e[33m"
BLUE="\e[34m" CYAN="\e[36m"

# Logger unificado
log_msg() {
    local indent="$1" color="$2" prefix="$3" msg="$4" fd="${5:-1}"
    echo -e "${indent}${color}${prefix}${NC} ${color}${msg}${NC}" >&"$fd"
}
print_step()     { log_msg ""     "$BLUE"   "•" "$1"; }
print_success()  { log_msg ""     "$GREEN"  "•" "$1"; }
print_sub()      { log_msg "  "   "$GRAY"   "•" "$1"; }
print_sub_ok()   { log_msg "  "   "$GREEN"  "•" "$1"; }
print_sub_warn() { log_msg "  "   "$YELLOW" "•" "$1"; }
print_sub_err()  { log_msg "  "   "$RED"    "•" "$1" 2; }

# Detección del elevador de privilegios (SUDO_CMD o ELEVATOR)
ELEVATOR="${ELEVATOR:-$SUDO_CMD}"
[ -z "$ELEVATOR" ] && [ "$EUID" -ne 0 ] && {
    command -v sudo &>/dev/null && ELEVATOR="sudo" || { command -v doas &>/dev/null && ELEVATOR="doas" || ELEVATOR=""; }
}

run_elevated() {
    if [ "$EUID" -ne 0 ] && [ -n "$ELEVATOR" ]; then
        "$ELEVATOR" "$@" &>> "${LOG_FILE:-/dev/null}"
    else
        "$@" &>> "${LOG_FILE:-/dev/null}"
    fi
}

run_elevated_nopasswd() {
    [ "$EUID" -eq 0 ] && return 0
    [ -n "$ELEVATOR" ] && "$ELEVATOR" -n true 2>/dev/null
}
