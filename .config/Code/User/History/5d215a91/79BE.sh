#!/bin/bash

# Переключиться на воркспейс 4
hyprctl dispatch workspace 4

sleep 0.6

# Запустить все окна сразу
kitty --class=kitty-peaclock -o background_opacity=0.55 peaclock &
kitty --class=kitty-cava -o background_opacity=0.55 cava &
kitty --class=kitty-fastfetch -o background_opacity=0.55 sh -c "fastfetch; exec zsh" &

# Дать время окнам появиться
sleep 0.2

# Получить размеры монитора один раз
MONITOR_WIDTH=$(hyprctl monitors -j | jq '.[0].width')
MONITOR_HEIGHT=$(hyprctl monitors -j | jq '.[0].height')
BOTTOM_X=$((MONITOR_WIDTH - 720))
BOTTOM_Y=$((MONITOR_HEIGHT - 400))

# Настроить все окна через batch команды (быстрее)
hyprctl --batch "\
dispatch focuswindow class:kitty-peaclock; \
dispatch togglefloating; \
dispatch resizeactive exact 720 400; \
dispatch moveactive exact 3 55; \
dispatch focuswindow class:kitty-cava; \
dispatch togglefloating; \
dispatch resizeactive exact 720 400; \
dispatch moveactive exact $BOTTOM_X $BOTTOM_Y; \
dispatch focuswindow class:kitty-fastfetch; \
dispatch togglefloating; \
dispatch resizeactive exact 730 490; \
dispatch centerwindow; \
dispatch bringactivetotop"

echo "Rice mode activated!"