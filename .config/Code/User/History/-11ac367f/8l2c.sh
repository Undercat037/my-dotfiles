#!/bin/bash

# Toggle класс через CSS
if grep -q "\.tray-hidden" ~/.config/waybar/style.css; then
    sed -i 's/\.tray-hidden/\.tray-visible/g' ~/.config/waybar/style.css
else
    sed -i 's/\.tray-visible/\.tray-hidden/g' ~/.config/waybar/style.css
fi

# Reload Waybar
pkill -SIGUSR2 waybar