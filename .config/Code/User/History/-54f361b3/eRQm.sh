#!/bin/bash

# Get current input method from fcitx5
current_ime=$(fcitx5-remote -n 2>/dev/null)

# Map IME names to display format
case "$current_ime" in
    "keyboard-us")
        echo '{"text": "EN", "tooltip": "English (US)", "class": "en"}'
        ;;
    "keyboard-ua")
        echo '{"text": "UA", "tooltip": "Українська (Ukrainian)", "class": "ua"}'
        ;;
    "keyboard-ru")
        echo '{"text": "RU", "tooltip": "Русский (Russian)", "class": "ru"}'
        ;;
    *)
        echo '{"text": "??", "tooltip": "Unknown IME", "class": "unknown"}'
        ;;
esac