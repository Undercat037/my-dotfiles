#!/bin/bash

MODE=${1:-1}

TEMP_FILE="$HOME/.cache/temp-screenshot.png"
TIMESTAMP=$(date +"%Y:%m:%d-%H:%M:%S:%3N")
SAVE_PATH="$HOME/Pictures/rice-screenshots/hyprland-rice-${TIMESTAMP}.png"

grim -t png "$SAVE_PATH"

notify-send -a "Screenshot" "Screenshot Saved" "Saved to $SAVE_PATH" --icon="$SAVE_PATH"