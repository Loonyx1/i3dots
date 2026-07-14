#!/usr/bin/env bash

# Engine: feh (para X11/i3)

engine_init() {
    # feh no necesita daemon, asegurar detener daemon de video previo
    pkill -9 -x live_wp_daemon &>/dev/null || true
    pkill -9 -f live_wp_daemon &>/dev/null || true
    return 0
}

engine_set() {
    local wp_path="$1"
    feh --bg-fill "$wp_path" &
}
