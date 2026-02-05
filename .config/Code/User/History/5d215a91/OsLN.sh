#!/bin/bash

# Переключиться на воркспейс 4
hyprctl dispatch workspace 4
sleep 0.2

# Запустить верхнее окно (peaclock) - 720x400
kitty --class=kitty-peaclock peaclock &
PEACLOCK_PID=$!
sleep 0.3

# Настроить верхнее окно
hyprctl dispatch focuswindow class:kitty-peaclock
hyprctl dispatch togglefloating
hyprctl dispatch resizeactive exact 720 400
hyprctl dispatch moveactive exact 0 0

sleep 0.2

# Запустить нижнее окно (cava) - 720x400
kitty --class=kitty-cava cava &
CAVA_PID=$!
sleep 0.3

# Настроить нижнее окно (получаем размер монитора для правильного позиционирования)
MONITOR_WIDTH=$(hyprctl monitors -j | jq '.[0].width')
MONITOR_HEIGHT=$(hyprctl monitors -j | jq '.[0].height')
BOTTOM_X=$((MONITOR_WIDTH - 720))
BOTTOM_Y=$((MONITOR_HEIGHT - 400))

hyprctl dispatch focuswindow class:kitty-cava
hyprctl dispatch togglefloating
hyprctl dispatch resizeactive exact 720 400
hyprctl dispatch moveactive exact $BOTTOM_X $BOTTOM_Y

sleep 0.2

# Запустить центральное окно (fastfetch) - 720x480
kitty --class=kitty-fastfetch sh -c "fastfetch; exec zsh" &
FASTFETCH_PID=$!
sleep 0.3

# Настроить центральное окно
hyprctl dispatch focuswindow class:kitty-fastfetch
hyprctl dispatch togglefloating
hyprctl dispatch resizeactive exact 720 480
hyprctl dispatch centerwindow

# Поднять центральное окно наверх (чтобы оно перекрывало остальные)
sleep 0.1
hyprctl dispatch bringactivetotop

echo "Rice mode activated!"