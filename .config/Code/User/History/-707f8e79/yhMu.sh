#!/usr/bin/env bash

# Temporary file for rofi
TEMP_FILE="/tmp/rofi_apps_$$"
trap "rm -f $TEMP_FILE" EXIT

# Function to get icon path
get_icon_path() {
    local icon_name="$1"
    
    # Try to find icon in theme
    for size in 48 32 24 16; do
        for theme_dir in ~/.local/share/icons /usr/share/icons/hicolor /usr/share/pixmaps; do
            # PNG
            if [ -f "$theme_dir/${size}x${size}/apps/${icon_name}.png" ]; then
                echo "$theme_dir/${size}x${size}/apps/${icon_name}.png"
                return
            fi
            # SVG
            if [ -f "$theme_dir/scalable/apps/${icon_name}.svg" ]; then
                echo "$theme_dir/scalable/apps/${icon_name}.svg"
                return
            fi
        done
    done
    
    # Fallback to pixmaps
    if [ -f "/usr/share/pixmaps/${icon_name}.png" ]; then
        echo "/usr/share/pixmaps/${icon_name}.png"
    elif [ -f "/usr/share/pixmaps/${icon_name}.svg" ]; then
        echo "/usr/share/pixmaps/${icon_name}.svg"
    fi
}

# Function to get app info from .desktop file
get_app_info() {
    local process_name="$1"
    local desktop_file=""
    
    # Clean up process name
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//')
    
    # Search for .desktop file
    for dir in /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue
        
        # Try exact match
        if [ -f "$dir/${clean_name}.desktop" ]; then
            desktop_file="$dir/${clean_name}.desktop"
            break
        fi
        
        # Try lowercase
        if [ -f "$dir/$(echo $clean_name | tr '[:upper:]' '[:lower:]').desktop" ]; then
            desktop_file="$dir/$(echo $clean_name | tr '[:upper:]' '[:lower:]').desktop"
            break
        fi
        
        # Try finding by exec field
        desktop_file=$(grep -l "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null | head -n1)
        [ -n "$desktop_file" ] && break
    done
    
    if [ -n "$desktop_file" ]; then
        local name=$(grep "^Name=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        local icon=$(grep "^Icon=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        echo "$name|$icon"
    else
        # Return capitalized process name
        local cap_name=$(echo "$process_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
        echo "$cap_name|application-x-executable"
    fi
}

# Exclude patterns for system processes
EXCLUDE_PATTERN="(^systemd|^dbus|^polkit|^gvfs|^at-spi|^ibus|^fcitx|^pipewire|^wireplumber|^xdg-|^gnome-|^kded|^plasma|^waybar|^hyprland|^sway|^Xwayland|^kwin|bash$|zsh$|fish$|sh$|^ssh-agent|^gpg-agent|^dconf|^gsd-|^evolution-|^tracker-|^gvfsd)"

# Get running processes
declare -A apps
while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    cmd=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
    
    # Get just the command name
    cmd_name=$(echo "$cmd" | awk '{print $1}')
    cmd_name=$(basename "$cmd_name")
    
    # Skip if matches exclude pattern
    [[ "$cmd_name" =~ $EXCLUDE_PATTERN ]] && continue
    
    # Store unique apps
    if [ -z "${apps[$cmd_name]}" ]; then
        apps["$cmd_name"]="$pid"
    fi
done < <(ps aux --sort=-%mem | awk 'NR>1 {print $2, $11, $12, $13, $14, $15}')

# Build menu with icons
> "$TEMP_FILE"
declare -A app_map

for process_name in "${!apps[@]}"; do
    pid="${apps[$process_name]}"
    
    # Get app name and icon
    info=$(get_app_info "$process_name")
    display_name=$(echo "$info" | cut -d'|' -f1)
    icon_name=$(echo "$info" | cut -d'|' -f2)
    
    # Get icon path
    icon_path=$(get_icon_path "$icon_name")
    
    # Store in map
    app_map["$display_name"]="$process_name:$pid"
    
    # Add to rofi menu
    if [ -n "$icon_path" ]; then
        echo -e "$display_name\0icon\x1f$icon_path" >> "$TEMP_FILE"
    else
        echo "$display_name" >> "$TEMP_FILE"
    fi
done

# Add control options
echo "" >> "$TEMP_FILE"
echo -e "󰚰 Refresh List\0icon\x1fview-refresh" >> "$TEMP_FILE"
echo -e "󰗼 Process Manager\0icon\x1futilities-system-monitor" >> "$TEMP_FILE"

# Show rofi menu
selected=$(cat "$TEMP_FILE" | rofi -dmenu -i -p "Running Apps (${#apps[@]})" -show-icons -theme ~/.config/rofi/quick-actions.rasi)

# Handle selection
if [ -n "$selected" ]; then
    case "$selected" in
        "󰚰 Refresh List")
            exec "$0"
            ;;
        
        "󰗼 Process Manager")
            kitty --class floating --title 'Process Manager' -e btop &
            ;;
        
        *)
            # Get app info
            app_info="${app_map[$selected]}"
            if [ -n "$app_info" ]; then
                process_name=$(echo "$app_info" | cut -d':' -f1)
                pid=$(echo "$app_info" | cut -d':' -f2)
                
                # Show action menu
                action=$(printf "󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Process\n View Details" | \
                    rofi -dmenu -i -p "$selected" -theme ~/.config/rofi/quick-actions.rasi)
                
                case "$action" in
                    "󰐥 Focus Window")
                        if command -v hyprctl &> /dev/null; then
                            # Get window address
                            window=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$window" ]; then
                                hyprctl dispatch focuswindow "address:$window"
                            fi
                        fi
                        ;;
                    
                    "󰜺 Minimize")
                        if command -v hyprctl &> /dev/null; then
                            window=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$window" ]; then
                                hyprctl dispatch movetoworkspacesilent "special:minimized,address:$window"
                                notify-send "Application Manager" "$selected minimized" -i preferences-desktop
                            fi
                        fi
                        ;;
                    
                    "󰿅 Kill Process")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Kill $selected?" -theme ~/.config/rofi/quick-actions.rasi)
                        if [ "$confirm" == "Yes" ]; then
                            kill "$pid" 2>/dev/null
                            sleep 0.5
                            if ps -p "$pid" > /dev/null 2>&1; then
                                kill -9 "$pid" 2>/dev/null
                            fi
                            notify-send "Application Manager" "$selected terminated" -i preferences-desktop
                        fi
                        ;;
                    
                    " View Details")
                        mem=$(ps -p "$pid" -o %mem --no-headers | xargs)
                        cpu=$(ps -p "$pid" -o %cpu --no-headers | xargs)
                        time=$(ps -p "$pid" -o etime --no-headers | xargs)
                        cmd=$(ps -p "$pid" -o cmd --no-headers)
                        
                        info="PID: $pid\nCPU: ${cpu}%\nMemory: ${mem}%\nUptime: $time\nCommand: $cmd"
                        notify-send "Process Details: $selected" "$info" -i preferences-desktop -t 10000
                        ;;
                esac
            fi
            ;;
    esac
fi