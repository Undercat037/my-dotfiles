#!/bin/bash

STATE_FILE="/tmp/waybar-tray-state"

if [ -f "$STATE_FILE" ]; then
    # Показать tray
    rm "$STATE_FILE"
    echo "show" > /tmp/waybar-tray-action
else
    # Скрыть tray
    touch "$STATE_FILE"
    echo "hide" > /tmp/waybar-tray-action
fi

# Перезапустить Waybar для применения
pkill -SIGUSR2 waybar