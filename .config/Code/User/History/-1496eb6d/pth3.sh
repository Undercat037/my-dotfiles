#!/bin/bash

killall rofi

icons_dir="$HOME/.config/waybar/icons"

build_menu() {
    echo -en "dwindle\0icon\x1f$icons_dir/dwindle.svg\n"
    echo -en "master\0icon\x1f$icons_dir/master.svg\n"
    echo -en "hy3\0icon\x1f$icons_dir/scrolling.svg\n"
}

selected=$(build_menu | rofi -dmenu -i -p "Select Workspace Layout" -show-icons \
    -columns 1 \
    -theme ~/.config/rofi/grid-layouts.rasi \
    -theme-str 'element-icon { size: 6em; }' \
    -me-select-entry '' -me-accept-entry MousePrimary)

[ -z "$selected" ] && exit 0

# Получаем текущий workspace ID
ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Метод 1: Через wslayout plugin (если работает)
hyprctl dispatch layoutmsg "wslayout-layout $selected"

# Метод 2: Прямая установка layout (если wslayout не работает)
if [ $? -ne 0 ]; then
    hyprctl keyword general:layout "$selected"
fi

notify-send -a "System" -i "$icons_dir/$selected.svg" "Hyprland Layout" "Workspace $ws → $selected"