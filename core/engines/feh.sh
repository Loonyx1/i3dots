#!/usr/bin/env bash

# Engine: feh (para X11/i3)

engine_init() {
    # feh no necesita daemon
    return 0
}

engine_set() {
    local wp_path="$1"
    feh --bg-fill "$wp_path"
}
