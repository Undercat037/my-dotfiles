#!/bin/bash

# Путь к конфигу cava
CAVA_CONFIG="$HOME/.config/cava/config"

# Проверяем наличие цветов pywal
if [ ! -f "$HOME/.cache/wal/colors.sh" ]; then
    echo "Pywal colors not found!"
    exit 1
fi

# Загружаем цвета из pywal
source "$HOME/.cache/wal/colors.sh"

# Функция для очистки цвета (убираем # если есть, потом добавляем обратно)
clean_color() {
    local color="$1"
    color="${color#\#}"  # Убираем # если есть
    echo "#$color"       # Добавляем # обратно
}

# Создаем конфиг cava с градиентом
cat > "$CAVA_CONFIG" << EOF
[general]
framerate = 60
bars = 0
autosens = 1

[input]
method = pulse

[output]
method = ncurses
channels = stereo

[color]
gradient = 1
gradient_count = 6

# Градиент от темного (снизу) к светлому (сверху)
gradient_color_1 = '$(clean_color "$color0")'
gradient_color_2 = '$(clean_color "$color1")'
gradient_color_3 = '$(clean_color "$color2")'
gradient_color_4 = '$(clean_color "$color3")'
gradient_color_5 = '$(clean_color "$color4")'
gradient_color_6 = '$(clean_color "$color7")'

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 77
EOF

echo "Cava config updated with pywal colors!"
