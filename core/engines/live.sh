#!/usr/bin/env bash
# core/engines/live.sh - Motor de Wallpaper Dinámico (xwinwrap + mpv)

engine_init() {
    # Detener de forma incondicional cualquier instancia previa de video y control
    pkill -9 -f 'xwinwrap.*mpv' &>/dev/null || true
    pkill -9 -f 'mpv.*--wid' &>/dev/null || true
    pkill -9 -f 'live_wp_daemon' &>/dev/null || true
    
    # Esperar de forma activa a que todos los procesos mueran por completo
    local count=0
    while pgrep -f 'mpv.*--wid' &>/dev/null || pgrep -f 'xwinwrap.*mpv' &>/dev/null || pgrep -f 'live_wp_daemon' &>/dev/null; do
        sleep 0.1
        count=$((count+1))
        [[ $count -ge 20 ]] && break
    done
    
    rm -f /tmp/mpv-live-wp.sock
    sleep 0.15
    return 0

}

engine_set() {
    local wp_path="$1"
    
    # 1. Asegurar que las instancias previas de video se limpien al cambiar
    engine_init
    
    # 2. Detectar si el archivo es un video
    local mime_type=""
    if command -v file &>/dev/null; then
        mime_type=$(file -b --mime-type "$wp_path" 2>/dev/null)
    fi
    
    local is_video=false
    if [[ "$mime_type" =~ ^video/ || "$wp_path" =~ \.(mp4|webm|mkv|gif)$ ]]; then
        is_video=true
    fi
    
    # 3. Si no es video o faltan dependencias, usar feh como fallback
    if [ "$is_video" = "false" ] || ! command -v xwinwrap &>/dev/null || ! command -v mpv &>/dev/null; then
        if command -v feh &>/dev/null; then
            feh --bg-fill "$wp_path" &
        else
            echo "Error [live_engine]: feh no está instalado para el fallback estático." >&2
        fi
        return 0
    fi
    
    # 4. Resolver la resolución del monitor principal
    local geom=""
    if command -v xrandr &>/dev/null; then
        geom=$(xrandr | grep -w connected | grep -oP '\d+x\d+\+\d+\+\d+' | head -n 1)
    fi
    [[ -z "$geom" ]] && geom="1920x1080+0+0"
    
    # 4.5 Levantar el daemon de control de estado
    if [[ -z "$CORE_DIR" ]]; then
        local real_script=$(readlink -f "${BASH_SOURCE[0]}")
        local script_dir=$(dirname "$real_script")
        CORE_DIR=$(dirname "$script_dir")
    fi
    local repo_root=$(dirname "$CORE_DIR")
    local daemon_path="${PACKAGE_DIR:-$repo_root/packages/i3dots}/bin/live_wp_daemon"
    chmod +x "$daemon_path" &>/dev/null || true
    # Iniciar daemon solo si no está corriendo actualmente (redireccionando a log en /tmp)
    pgrep -x live_wp_daemon &>/dev/null || nohup "$daemon_path" < /dev/null &>/tmp/live_wp_daemon.log 2>&1 &
    
    # 5. Lanzar xwinwrap + mpv en segundo plano con socket IPC y logs en /tmp/mpv-live-wp.log
    echo "--- Lanzando nuevo Wallpaper Dinámico ---" > /tmp/mpv-live-wp.log
    nohup xwinwrap -g "$geom" -ov -ni -b -nf -s -st -sp -- \
        mpv -wid %WID --x11-name=mpv-wallpaper --really-quiet --vo=gpu,xv,x11 --hwdec=auto --cache=no \
        --demuxer-max-bytes=512KiB --demuxer-max-back-bytes=0 \
        --vd-queue-max-bytes=1MiB --vd-queue-max-secs=0.1 \
        --vf=fps=30 --terminal=no --no-config --no-border --loop --no-audio \
        --input-ipc-server=/tmp/mpv-live-wp.sock \
        --no-window-dragging --no-input-default-bindings --no-osd-bar --no-sub \
        "$wp_path" < /dev/null >>/tmp/mpv-live-wp.log 2>&1 &
}

