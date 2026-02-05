#!/usr/bin/env bash

# Temporary file for rofi
TEMP_FILE="/tmp/rofi_apps_$$"
trap "rm -f $TEMP_FILE" EXIT

# Function to get icon path
get_icon_path() {
    local icon_name="$1"
    
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
    
    if [ -f "/usr/share/pixmaps/${icon_name}.png" ]; then
        echo "/usr/share/pixmaps/${icon_name}.png"
    elif [ -f "/usr/share/pixmaps/${icon_name}.svg" ]; then
        echo "/usr/share/pixmaps/${icon_name}.svg"
    fi
}

# Function to check if process has .desktop file (=GUI app)
has_desktop_file() {
    local process_name="$1"
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')
    
    for dir in /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue
        
        # Check exact match
        [ -f "$dir/${clean_name}.desktop" ] && return 0
        [ -f "$dir/$(echo $clean_name | tr '[:upper:]' '[:lower:]').desktop" ] && return 0
        
        # Check if any .desktop file references this process
        grep -q "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null && return 0
    done
    
    return 1
}

# Function to get app info from .desktop file
get_app_info() {
    local process_name="$1"
    local desktop_file=""
    
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')
    
    for dir in /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue
        
        if [ -f "$dir/${clean_name}.desktop" ]; then
            desktop_file="$dir/${clean_name}.desktop"
            break
        fi
        
        if [ -f "$dir/$(echo $clean_name | tr '[:upper:]' '[:lower:]').desktop" ]; then
            desktop_file="$dir/$(echo $clean_name | tr '[:upper:]' '[:lower:]').desktop"
            break
        fi
        
        desktop_file=$(grep -l "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null | head -n1)
        [ -n "$desktop_file" ] && break
    done
    
    if [ -n "$desktop_file" ]; then
        local name=$(grep "^Name=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        local icon=$(grep "^Icon=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        echo "$name|$icon"
    else
        local cap_name=$(echo "$process_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
        echo "$cap_name|application-x-executable"
    fi
}

# Function to check if process is a system/daemon process
is_system_process() {
    local cmd="$1"
    local comm="$2"
    
    # System directories (processes from here are usually daemons)
    [[ "$cmd" =~ ^/usr/lib/systemd ]] && return 0
    [[ "$cmd" =~ ^/usr/lib/polkit ]] && return 0
    [[ "$cmd" =~ ^/usr/lib/gnome-settings-daemon ]] && return 0
    [[ "$cmd" =~ ^/usr/lib/gvfs ]] && return 0
    
    # Common system process names
    case "$comm" in
        systemd|systemd-*|dbus-daemon|dbus-broker|polkitd|rtkit-daemon|\
        pipewire|wireplumber|pulseaudio|gvfsd|gvfsd-*|gvfs-*|\
        at-spi-bus-launcher|at-spi2-*|dconf-service|\
        xdg-*|gnome-keyring-daemon|ssh-agent|gpg-agent|\
        ibus-daemon|ibus-*|fcitx|fcitx5|fcitx5-*|\
        evolution-*|tracker-*|gsd-*|\
        upowerd|udisksd|boltd|switcheroo-control|\
        colord|geoclue|cups-browsed|avahi-daemon|\
        NetworkManager|ModemManager|wpa_supplicant|\
        bluetoothd|obexd|thermald|irqbalance|\
        kded5|kded6|kwin_*|plasmashell|plasma-*|\
        Xwayland|sway|waybar|hyprland|mako|dunst|swaync|\
        bash|zsh|fish|sh|kitty|alacritty|foot|konsole|wezterm)
            return 0
            ;;
    esac
    
    return 1
}

# Get all processes with their full command
declare -A apps
declare -A app_map

while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    user=$(echo "$line" | awk '{print $2}')
    cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
    
    # Skip if not current user
    [ "$user" != "$USER" ] && continue
    
    # Get command name
    cmd_first=$(echo "$cmd" | awk '{print $1}')
    comm=$(basename "$cmd_first")
    
    # Skip system processes
    is_system_process "$cmd_first" "$comm" && continue
    
    # Check if it's a GUI app (has .desktop file)
    has_desktop_file "$comm" || continue
    
    # Get app info
    info=$(get_app_info "$comm")
    display_name=$(echo "$info" | cut -d'|' -f1)
    icon_name=$(echo "$info" | cut -d'|' -f2)
    
    # Check if this app already exists (might have multiple processes)
    if [ -z "${apps[$display_name]}" ]; then
        apps["$display_name"]="$icon_name"
        app_map["$display_name"]="$pid:$comm"
    fi
done < <(ps aux --sort=-%mem)

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
selected=$(cat "$TEMP_FILE" | rofi -dmenu -i -p "Applications (${#apps[@]})" -show-icons -theme ~/.config/rofi/quick-actions.rasi)

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
            info="${app_map[$selected]}"
            if [ -n "$info" ]; then
                pid=$(echo "$info" | cut -d':' -f1)
                comm=$(echo "$info" | cut -d':' -f2)
                
                # Build action menu
                action_menu="󰐥 Focus Window"
                
                # Check if app has window
                if command -v hyprctl &> /dev/null; then
                    if hyprctl clients -j | jq -e ".[] | select(.pid == $pid)" > /dev/null 2>&1; then
                        action_menu="$action_menu\n󰜺 Minimize"
                    fi
                fi
                
                action_menu="$action_menu\n󰿅 Kill Application\n View Details"
                
                action=$(echo -e "$action_menu" | rofi -dmenu -i -p "$selected" -theme ~/.config/rofi/quick-actions.rasi)
                
                case "$action" in
                    "󰐥 Focus Window")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$address" ]; then
                                hyprctl dispatch focuswindow "address:$address"
                            else
                                notify-send "Application Manager" "$selected has no visible window" -i dialog-information
                            fi
                        fi
                        ;;
                    
                    "󰜺 Minimize")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$address" ]; then
                                hyprctl dispatch movetoworkspacesilent "special:minimized,address:$address"
                                notify-send "Application Manager" "$selected minimized" -i preferences-desktop
                            fi
                        fi
                        ;;
                    
                    "󰿅 Kill Application")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Kill $selected?" -theme ~/.config/rofi/quick-actions.rasi)
                        if [ "$confirm" == "Yes" ]; then
                            # Kill all processes with this name
                            pkill -9 "$comm"
                            notify-send "Application Manager" "$selected terminated" -i preferences-desktop
                        fi
                        ;;
                    
                    " View Details")
                        mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs)
                        cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs)
                        time=$(ps -p "$pid" -o etime --no-headers 2>/dev/null | xargs)
                        cmd=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
                        
                        # Count total processes for this app
                        count=$(pgrep -x "$comm" | wc -l)
                        
                        info="PID: $pid\nProcesses: $count\nCPU: ${cpu}%\nMemory: ${mem}%\nUptime: $time\nCommand: $cmd"
                        notify-send "Details: $selected" "$info" -i preferences-desktop -t 10000
                        ;;
                esac
            fi
            ;;
    esac
fi