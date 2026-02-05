#!/bin/bash
direction=$1

ws=$(hyprctl activeworkspace -j | jq '.id')
window_count=$(hyprctl activeworkspace -j | jq '.windows')
[ "$window_count" -eq 0 ] && exit 0

active=$(hyprctl activewindow -j)
active_x=$(echo "$active" | jq '.at[0]')

all_windows=$(hyprctl clients -j | jq --arg ws "$ws" \
    '[.[] | select(.workspace.id == ($ws | tonumber)) | {x: .at[0], addr: .address}]')
windows=$(echo "$all_windows" | jq '[.[].x] | sort | map(tonumber)')
count=$(echo "$windows" | jq 'length')
[ "$count" -le 1 ] && exit 0

if [ "$direction" == "left" ]; then
    leftmost=$(echo "$windows" | jq '.[0]')
    if [ "$active_x" -le "$leftmost" ]; then
        rightmost=$(echo "$windows" | jq '.[-1]')
        target_addr=$(echo "$all_windows" | jq -r --arg x "$rightmost" \
            '.[] | select(.x == ($x | tonumber)) | .addr')
        distance=$((-rightmost+active_x))
        hyprctl dispatch layoutmsg move $distance
        hyprctl dispatch focuswindow address:$target_addr
    else
        hyprctl dispatch layoutmsg 'move -col'
    fi
elif [ "$direction" == "right" ]; then
    rightmost=$(echo "$windows" | jq '.[-1]')
    if [ "$active_x" -ge "$rightmost" ]; then
        leftmost=$(echo "$windows" | jq '.[0]')
        target_addr=$(echo "$all_windows" | jq -r --arg x "$leftmost" \
            '.[] | select(.x == ($x | tonumber)) | .addr')
        distance=$((-leftmost+active_x))
        hyprctl dispatch layoutmsg move $distance
        hyprctl dispatch focuswindow address:$target_addr
    else
        hyprctl dispatch layoutmsg 'move +col'
    fi
fi