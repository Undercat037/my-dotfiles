#!/bin/bash

# Get RAM info
mem_info=$(free -h | awk '/^Mem:/ {print $3,$2}')
read -r mem_used mem_total <<< "$mem_info"
mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

# Base display text - ALWAYS show RAM
display_text="󰍛 ${mem_percent}%"
tooltip="󰍛 RAM: ${mem_used} / ${mem_total} (${mem_percent}%)"

# Try to get NVIDIA GPU info with error handling
if command -v nvidia-smi &> /dev/null; then
    # Wait a bit for nvidia driver to be ready (only on first run)
    if [ ! -f /tmp/waybar_nvidia_ready ]; then
        sleep 2
        touch /tmp/waybar_nvidia_ready
    fi
    
    # Try to query NVIDIA with timeout
    gpu_info=$(timeout 2 nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit --format=csv,noheader,nounits 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$gpu_info" ]; then
        IFS=',' read -r gpu_util vram_used vram_total temp power_draw power_limit <<< "$gpu_info"
        
        # Trim all whitespace
        gpu_util=$(echo "$gpu_util" | xargs)
        vram_used=$(echo "$vram_used" | xargs)
        vram_total=$(echo "$vram_total" | xargs)
        temp=$(echo "$temp" | xargs)
        power_draw=$(echo "$power_draw" | xargs)
        power_limit=$(echo "$power_limit" | xargs)
        
        # Check if values are valid (not empty and not [N/A])
        if [[ -n "$gpu_util" ]] && [[ "$gpu_util" != "[N/A]" ]] && [[ "$gpu_util" =~ ^[0-9]+$ ]]; then
            # Format VRAM to GB
            vram_used_gb=$(echo "$vram_used" | awk '{printf "%.1f", $1/1024}')
            vram_total_gb=$(echo "$vram_total" | awk '{printf "%.1f", $1/1024}')
            
            # Format power
            if [[ "$power_limit" == "[N/A]" ]] || [[ -z "$power_limit" ]]; then
                power_limit_str="N/A"
            else
                power_limit_str=$(echo "$power_limit" | awk '{printf "%.0f", $1}')
            fi
            
            if [[ "$power_draw" == "[N/A]" ]] || [[ -z "$power_draw" ]]; then
                power_draw_str="N/A"
            else
                power_draw_str=$(echo "$power_draw" | awk '{printf "%.0f", $1}')
            fi
            
            # Update display text to include GPU
            display_text+=" 󰢮 ${gpu_util}%"
            
            # Add GPU info to tooltip
            tooltip+="\n\n󰢮 GPU Utilization: ${gpu_util}%\n"
            tooltip+=" Temperature: ${temp}°C\n"
            tooltip+="󰍛 VRAM: ${vram_used_gb}GB / ${vram_total_gb}GB\n"
            tooltip+="󰚥 Power: ${power_draw_str}W / ${power_limit_str}W"
        else
            # GPU data invalid, show only RAM with note
            display_text+=" 󰢮 N/A"
        fi
    else
        # nvidia-smi failed or timed out, show only RAM
        display_text+=" 󰢮 --"
    fi
else
    # nvidia-smi not found, show only RAM
    display_text+=" 󰢮 N/A"
fi

echo "{\"text\":\"$display_text\",\"tooltip\":\"$tooltip\"}"