#!/bin/bash

# Get RAM info
mem_info=$(free -h | awk '/^Mem:/ {print $3,$2}')
read -r mem_used mem_total <<< "$mem_info"
mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

# Base display text - ALWAYS show RAM
display_text="󰍛 ${mem_percent}%"
tooltip="󰍛 RAM: ${mem_used} / ${mem_total} (${mem_percent}%)"

# Try to get NVIDIA GPU info
if command -v nvidia-smi &> /dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit --format=csv,noheader,nounits 2>/dev/null)

    if [ -n "$gpu_info" ]; then
        IFS=',' read -r gpu_util vram_used vram_total temp power_draw power_limit <<< "$gpu_info"

        # Handle [N/A] values
        power_draw=$(echo "$power_draw" | xargs)
        power_limit=$(echo "$power_limit" | xargs)
        if [[ "$power_limit" == "[N/A]" ]]; then
            power_limit="N/A"
        else
            power_limit=$(echo "$power_limit" | awk '{printf "%.0f", $1}')
        fi

        # Format VRAM to GB
        vram_used=$(echo "$vram_used" | awk '{printf "%.1f", $1/1024}')
        vram_total=$(echo "$vram_total" | awk '{printf "%.1f", $1/1024}')

        # Trim whitespace
        gpu_util=$(echo "$gpu_util" | xargs)
        temp=$(echo "$temp" | xargs)
        power_draw=$(echo "$power_draw" | awk '{printf "%.0f", $1}')

        # Update display text to include GPU
        display_text+=" 󰢮 ${gpu_util}%"

        # Add GPU info to tooltip
        tooltip+="\n\n󰢮 GPU Utilization: ${gpu_util}%\n"
        tooltip+=" Temperature: ${temp}°C\n"
        tooltip+="󰍛 VRAM: ${vram_used}GB / ${vram_total}GB\n"
        tooltip+="󰚥 Power: ${power_draw}W / ${power_limit}W"
    fi
fi
# DEBUG: покажем hex-коды каждого символа
echo "$display_text" | od -c >&2

echo "{\"text\":\"$display_text\",\"tooltip\":\"$tooltip\"}"