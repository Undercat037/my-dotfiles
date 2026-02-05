#!/bin/bash

STATE_FILE="/tmp/waybar-tray-drawer"
TRAY_PID=$(pgrep -f "waybar.*tray")

if [ -f "$STATE_FILE" ]; then
    # Скрыть tray
    rm "$STATE_FILE"
    pkill -f "waybar.*modules-right.*tray"
else
    # Показать tray
    touch "$STATE_FILE"
    # Запустить отдельный Waybar только с tray
    waybar -c ~/.config/waybar/tray-only.jsonc -s ~/.config/waybar/tray-style.css &
fi