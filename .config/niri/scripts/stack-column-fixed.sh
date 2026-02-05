#!/bin/bash
ws=$(hyprctl activeworkspace -j | jq '.id')
window_count=$(hyprctl activeworkspace -j | jq '.windows')
[ "$window_count" -eq 0 ] && exit

direction=$1
if [ "$direction" == "left" ]; then
    hyprctl dispatch layoutmsg movewindowto l
elif [ "$direction" == "right" ]; then
    hyprctl dispatch layoutmsg movewindowto r
fi