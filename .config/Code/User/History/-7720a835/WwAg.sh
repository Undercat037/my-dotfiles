#!/bin/bash

# Cycle through input methods: EN → UA → RU → EN
current_ime=$(fcitx5-remote -n 2>/dev/null)

case "$current_ime" in
    "keyboard-us")
        fcitx5-remote -s keyboard-ua
        ;;
    "keyboard-ua")
        fcitx5-remote -s keyboard-ru
        ;;
    "keyboard-ru")
        fcitx5-remote -s keyboard-us
        ;;
    *)
        # Default to English if unknown
        fcitx5-remote -s keyboard-us
        ;;
esac