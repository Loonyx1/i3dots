#!/usr/bin/env bash
# setup.sh - Hook de tema para polybar_underline

MOD_FILE="modules_${MODE}.ini"
[ ! -f "$THEME_SRC/$MOD_FILE" ] && MOD_FILE="modules_underline.ini"
ln -sf "current_theme/$MOD_FILE" "$CONF_DIR/modules.ini"
