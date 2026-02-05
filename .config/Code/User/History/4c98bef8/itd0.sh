#!/bin/bash

STATE_FILE="/tmp/waybar-tray-drawer"

if [ -f "$STATE_FILE" ]; then
    echo '{"text":"","tooltip":"Hide tray","class":"active"}'
else
    echo '{"text":"","tooltip":"Show tray","class":"inactive"}'
fi