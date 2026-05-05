#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Detectar sensor de temperatura (hwmon)
for i in /sys/class/hwmon/hwmon*/name; do
    if grep -qE "coretemp|fam15h_power|k10temp" "$i" >/dev/null 2>&1; then
        export HWMON_PATH="$(dirname $i)/temp1_input"
        break
    fi
done
[ -z "$HWMON_PATH" ] && export HWMON_PATH=$(ls -1 /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1)

# Launch bar1 and bar2
echo "---" | tee -a /tmp/polybar1.log /tmp/polybar2.log
polybar i3_bar 2>&1 | tee -a /tmp/polybar1.log & disown

echo "Bars launched..."
