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

# Устанавливаем layout через wslayout
hyprctl dispatch layoutmsg "wslayout-layout $selected"

# Альтернативно, если не работает через layoutmsg:
# hyprctl keyword "workspace[${ws}]:layoutopt:wslayout-layout" "$selected"

notify-send -a "System" -i "$icons_dir/$selected.svg" "Hyprland Layout" "Workspace $ws set to: $selected"