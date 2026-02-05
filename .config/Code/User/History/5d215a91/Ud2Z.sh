#!/bin/bash

# Переключиться на воркспейс 4
hyprctl dispatch workspace 4

# Небольшая задержка для переключения воркспейса
sleep 0.1

# Запустить верхнее окно (peaclock) - 720x400, слева сверху
hyprctl dispatch exec "[float;size 720 400;move 0 0;class:kitty-peaclock]" kitty --class=kitty-peaclock peaclock &
sleep 0.2

# Запустить нижнее окно (cava) - 720x400, справа снизу
# Вычисляем позицию: если экран 1920x1080, то x = 1920-720 = 1200, y = 1080-400 = 680
hyprctl dispatch exec "[float;size 720 400;move 100%-720 100%-400;class:kitty-cava]" kitty --class=kitty-cava cava &
sleep 0.2

# Запустить центральное окно (fastfetch) - 720x480, по центру
hyprctl dispatch exec "[float;size 720 480;center;class:kitty-fastfetch]" kitty --class=kitty-fastfetch fastfetch &
sleep 0.2

# Поднять центральное окно наверх
sleep 0.3
hyprctl dispatch focuswindow class:kitty-fastfetch
hyprctl dispatch bringactivetotop