#!/usr/bin/env bash
# live.sh - Motor de wallpaper dinámico (xwinwrap + mpv)

MPV_SOCKET="/tmp/mpv-live-wp.sock"

_resolve_daemon_path() {
    local script_dir repo_root path
    script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"   # .../core/engines
    repo_root="$(dirname "$(dirname "$script_dir")")"               # .../i3dots
    
    # 1. Validar PACKAGE_DIR del entorno
    if [[ -n "$PACKAGE_DIR" && -x "$PACKAGE_DIR/bin/live_wp_daemon" ]]; then
        echo "$PACKAGE_DIR/bin/live_wp_daemon"
        return
    fi
    
    # 2. Validar ruta estándar en la raíz del repositorio
    path="$repo_root/packages/i3dots/bin/live_wp_daemon"
    if [[ -x "$path" ]]; then
        echo "$path"
        return
    fi
    
    # Fallback por defecto
    echo "$path"
}

engine_init() {
    pkill -9 -f 'xwinwrap' &>/dev/null || true
    pkill -9 -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null || true
    pkill -9 -f 'live_wp_daemon' &>/dev/null || true
    
    # Esperar de forma activa a que todos los procesos mueran por completo antes de continuar
    local count=0
    while pgrep -f 'xwinwrap' &>/dev/null || pgrep -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null; do
        sleep 0.05
        count=$((count+1))
        [[ $count -ge 20 ]] && break
    done
    
    rm -f "$MPV_SOCKET"
}

engine_set() {
    local wp_path="$1"

    # Detectar tipo de archivo
    local mime_type is_video=false
    mime_type=$(file -b --mime-type "$wp_path" 2>/dev/null)
    [[ "$mime_type" =~ ^video/ || "$wp_path" =~ \.(mp4|webm|mkv|gif)$ ]] && is_video=true

    # Fallback estático
    if [[ "$is_video" == false ]] || ! command -v xwinwrap &>/dev/null; then
        engine_init
        command -v feh &>/dev/null && feh --bg-fill "$wp_path" &
        return 0
    fi

    # Hot-reload: mpv ya activo → cambiar archivo instantáneamente vía socket IPC
    local daemon_path
    daemon_path="$(_resolve_daemon_path)"
    if [[ -S "$MPV_SOCKET" ]] && pgrep -f 'mpv.*--x11-name=mpv-wallpaper' &>/dev/null; then
        if [[ -x "$daemon_path" ]] && "$daemon_path" --loadfile "$wp_path" 2>/dev/null; then
            return 0
        fi
    fi

    # Inicio frío: limpiar procesos y lanzar nueva sesión desvinculada
    engine_init

    local geom
    geom=$(xrandr | grep " connected" | grep -oP '\d+x\d+\+\d+\+\d+' | head -1)
    [[ -z "$geom" ]] && geom="1920x1080+0+0"

    # Lanzar xwinwrap+mpv en segundo plano de forma desvinculada usando setsid -f (fork)
    # Se pasan las variables de entorno de X11 de forma explícita para evitar fallas de conexión al display.
    # sleep 0.3 previene errores BadWindow en X11/picom al liberar la ventana anterior.
    setsid -f bash -c '
        export DISPLAY="$1"
        export XAUTHORITY="$2"
        geom="$3"
        socket="$4"
        path="$5"
        sleep 0.3
        exec xwinwrap -g "$geom" -ov -ni -b -nf -s -st -sp -- \
            mpv -wid %WID \
                --x11-name=mpv-wallpaper \
                --really-quiet \
                --vo=gpu,xv,x11 \
                --hwdec=auto-safe \
                --cache=no \
                --demuxer-max-bytes=256KiB \
                --demuxer-max-back-bytes=0 \
                --vd-queue-max-bytes=512KiB \
                --vd-queue-max-secs=0.05 \
                --loop \
                --no-audio \
                --no-border \
                --no-config \
                --no-osc \
                --no-terminal \
                --x11-bypass-compositor=yes \
                --input-ipc-server="$socket" \
                "$path"
    ' bash "${DISPLAY:-:0}" "${XAUTHORITY:-$HOME/.Xauthority}" "$geom" "$MPV_SOCKET" "$wp_path" >/tmp/xwinwrap.log 2>&1

    # Lanzar daemon si no está corriendo de forma desvinculada con nohup
    if ! pgrep -x live_wp_daemon &>/dev/null && [[ -x "$daemon_path" ]]; then
        nohup "$daemon_path" < /dev/null > /dev/null 2>&1 &
        disown $! 2>/dev/null || true
    fi
}
