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
            if [ -f "$theme_dir/${size}x${size}/apps/${icon_name}.png" ]; then
                echo "$theme_dir/${size}x${size}/apps/${icon_name}.png"
                return
            fi
            if [ -f "$theme_dir/scalable/apps/${icon_name}.svg" ]; then
                echo "$theme_dir/scalable/apps/${icon_name}.svg"
                return
            fi
        done
    done
    
    # Fallback
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
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')
    
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
        local cap_name=$(echo "$process_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
        echo "$cap_name|application-x-executable"
    fi
}

# Get GUI applications with windows from Hyprland
declare -A apps
declare -A app_map

if command -v hyprctl &> /dev/null; then
    # Get windows from Hyprland
    while IFS= read -r line; do
        # Parse JSON output
        address=$(echo "$line" | jq -r '.address')
        class=$(echo "$line" | jq -r '.class')
        title=$(echo "$line" | jq -r '.title')
        pid=$(echo "$line" | jq -r '.pid')
        
        # Skip empty or system windows
        [ -z "$class" ] && continue
        [[ "$class" =~ ^(waybar|rofi|dunst|swaync)$ ]] && continue
        
        # Get process name from PID
        process_name=$(ps -p "$pid" -o comm= 2>/dev/null)
        [ -z "$process_name" ] && continue
        
        # Get app info
        info=$(get_app_info "$process_name")
        display_name=$(echo "$info" | cut -d'|' -f1)
        icon_name=$(echo "$info" | cut -d'|' -f2)
        
        # Use class as fallback if display_name not found
        [ "$display_name" == "$(basename $process_name)" ] && display_name="$class"
        
        # Store unique apps
        if [ -z "${apps[$display_name]}" ]; then
            apps["$display_name"]="$icon_name"
            app_map["$display_name"]="$pid:$address:$class"
        fi
    done < <(hyprctl clients -j | jq -c '.[]')
else
    # Fallback: Get common GUI apps from processes
    GUI_APPS="firefox|chromium|chrome|brave|code|codium|discord|telegram|slack|spotify|steam|gimp|inkscape|blender|obs|vlc|mpv|kitty|alacritty|foot|konsole|nautilus|dolphin|thunar|pcmanfm|thunderbird|geary|evolution"
    
    while IFS= read -r line; do
        pid=$(echo "$line" | awk '{print $1}')
        cmd=$(echo "$line" | awk '{print $2}')
        
        cmd_name=$(basename "$cmd")
        
        # Check if it's a GUI app
        [[ ! "$cmd_name" =~ $GUI_APPS ]] && continue
        
        # Get app info
        info=$(get_app_info "$cmd_name")
        display_name=$(echo "$info" | cut -d'|' -f1)
        icon_name=$(echo "$info" | cut -d'|' -f2)
        
        if [ -z "${apps[$display_name]}" ]; then
            apps["$display_name"]="$icon_name"
            app_map["$display_name"]="$pid::$cmd_name"
        fi
    done < <(ps aux | awk 'NR>1 {print $2, $11}')
fi

# Build menu
> "$TEMP_FILE"

if [ ${#apps[@]} -eq 0 ]; then
    echo "No applications running" >> "$TEMP_FILE"
else
    for display_name in $(printf '%s\n' "${!apps[@]}" | sort); do
        icon_name="${apps[$display_name]}"
        icon_path=$(get_icon_path "$icon_name")
        
        if [ -n "$icon_path" ]; then
            echo -e "$display_name\0icon\x1f$icon_path" >> "$TEMP_FILE"
        else
            echo "$display_name" >> "$TEMP_FILE"
        fi
    done
fi

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
        
        "No applications running")
            exit 0
            ;;
        
        *)
            # Get app info
            info="${app_map[$selected]}"
            if [ -n "$info" ]; then
                pid=$(echo "$info" | cut -d':' -f1)
                address=$(echo "$info" | cut -d':' -f2)
                class=$(echo "$info" | cut -d':' -f3)
                
                # Show action menu
                action=$(printf "󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Application\n View Details" | \
                    rofi -dmenu -i -p "$selected" -theme ~/.config/rofi/quick-actions.rasi)
                
                case "$action" in
                    "󰐥 Focus Window")
                        if [ -n "$address" ] && command -v hyprctl &> /dev/null; then
                            hyprctl dispatch focuswindow "address:$address"
                        elif [ -n "$pid" ]; then
                            if command -v hyprctl &> /dev/null; then
                                hyprctl dispatch focuswindow "pid:$pid"
                            fi
                        fi
                        ;;
                    
                    "󰜺 Minimize")
                        if [ -n "$address" ] && command -v hyprctl &> /dev/null; then
                            hyprctl dispatch movetoworkspacesilent "special:minimized,address:$address"
                            notify-send "Application Manager" "$selected minimized" -i preferences-desktop
                        fi
                        ;;
                    
                    "󰿅 Kill Application")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Kill $selected?" -theme ~/.config/rofi/quick-actions.rasi)
                        if [ "$confirm" == "Yes" ]; then
                            if [ -n "$pid" ]; then
                                kill "$pid" 2>/dev/null
                                sleep 0.5
                                if ps -p "$pid" > /dev/null 2>&1; then
                                    kill -9 "$pid" 2>/dev/null
                                fi
                                notify-send "Application Manager" "$selected terminated" -i preferences-desktop
                            fi
                        fi
                        ;;
                    
                    " View Details")
                        if [ -n "$pid" ]; then
                            mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs)
                            cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs)
                            time=$(ps -p "$pid" -o etime --no-headers 2>/dev/null | xargs)
                            cmd=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
                            
                            info="PID: $pid\nCPU: ${cpu}%\nMemory: ${mem}%\nUptime: $time\nCommand: $cmd"
                            notify-send "Details: $selected" "$info" -i preferences-desktop -t 10000
                        fi
                        ;;
                esac
            fi
            ;;
    esac
fi