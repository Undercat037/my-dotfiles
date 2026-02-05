#!/bin/bash

# Показать историю буфера обмена через rofi
#cliphist list | rofi -dmenu -p "Clipboard History" -theme ~/.config/rofi/grid.rasi | cliphist decode | wl-copy
cliphist list | rofi -dmenu -p "Clipboard History" | cliphist decode | wl-copy
