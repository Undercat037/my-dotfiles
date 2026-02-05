#!/usr/bin/env bash

# Temporary files
TEMP_FILE="/tmp/rofi_apps_$$"
TEMP_MAP="/tmp/rofi_map_$$"
trap "rm -f $TEMP_FILE $TEMP_MAP" EXIT

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

# Function to find .desktop file
find_desktop_file() {
    local process_name="$1"
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')
    
    for dir in /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications ~/.local/share/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue
        
        # Try exact match
        [ -f "$dir/${clean_name}.desktop" ] && echo "$dir/${clean_name}.desktop" && return 0
        
        # Try lowercase
        local lower=$(echo "$clean_name" | tr '[:upper:]' '[:lower:]')
        [ -f "$dir/${lower}.desktop" ] && echo "$dir/${lower}.desktop" && return 0
        
        # Try finding by Exec field
        local found=$(grep -l "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null | head -n1)
        [ -n "$found" ] && echo "$found" && return 0
    done
    
    return 1
}

# Function to get app info
get_app_info() {
    local process_name="$1"
    local desktop_file=$(find_desktop_file "$process_name")
    
    if [ -n "$desktop_file" ]; then
        local name=$(grep "^Name=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        local icon=$(grep "^Icon=" "$desktop_file" | head -n1 | cut -d'=' -f2)
        echo "$name|$icon|yes"
    else
        local cap_name=$(echo "$process_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
        echo "$cap_name|application-x-executable|no"
    fi
}

# Blacklist of system processes
BLACKLIST=(
    "systemd" "dbus-daemon" "dbus-broker" "polkitd" "rtkit-daemon"
    "pipewire" "wireplumber" "pulseaudio"
    "gvfsd" "gvfsd-fuse" "gvfsd-trash" "gvfsd-metadata" "gvfs-udisks2-volume-monitor"
    "at-spi-bus-launcher" "at-spi2-registryd"
    "dconf-service" "xdg-desktop-portal" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "gnome-keyring-daemon" "ssh-agent" "gpg-agent"
    "ibus-daemon" "ibus-engine-simple" "fcitx" "fcitx5" "fcitx5-config-qt"
    "evolution-source-registry" "evolution-addressbook-factory" "evolution-calendar-factory"
    "tracker-miner-fs" "tracker-extract" "tracker-store"
    "gsd-color" "gsd-datetime" "gsd-housekeeping" "gsd-keyboard" "gsd-media-keys"
    "gsd-power" "gsd-print-notifications" "gsd-rfkill" "gsd-screensaver-proxy"
    "gsd-sharing" "gsd-smartcard" "gsd-sound" "gsd-wacom" "gsd-xsettings"
    "NetworkManager" "ModemManager" "wpa_supplicant" "bluetoothd" "obexd"
    "upowerd" "udisksd" "boltd" "switcheroo-control" "thermald"
    "colord" "geoclue" "cups-browsed" "avahi-daemon"
    "kded5" "kded6" "kwin_wayland" "kwin_x11" "plasmashell" "plasma-browser-integration-host"
    "Xwayland" "sway" "waybar" "hyprland" "hyprpaper" "hypridle" "hyprlock"
    "mako" "dunst" "swaync"
    "bash" "zsh" "fish" "sh"
)

# Function to check if process should be excluded
should_exclude() {
    local comm="$1"
    
    for item in "${BLACKLIST[@]}"; do
        [[ "$comm" == "$item" ]] && return 0
    done
    
    [[ "$comm" =~ ^systemd- ]] && return 0
    [[ "$comm" =~ ^gvfs- ]] && return 0
    [[ "$comm" =~ ^ibus- ]] && return 0
    [[ "$comm" =~ ^fcitx5- ]] && return 0
    [[ "$comm" =~ ^xdg- ]] && return 0
    [[ "$comm" =~ ^gsd- ]] && return 0
    [[ "$comm" =~ ^evolution- ]] && return 0
    [[ "$comm" =~ ^tracker- ]] && return 0
    [[ "$comm" =~ ^kwin_ ]] && return 0
    [[ "$comm" =~ ^plasma- ]] && return 0
    
    return 1
}

# Collect apps - write directly to files
> "$TEMP_FILE"
> "$TEMP_MAP"

declare -A seen_apps

while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $2}')
    user=$(echo "$line" | awk '{print $1}')
    cmd=$(echo "$line" | awk '{print $11}')
    
    [ "$user" != "$USER" ] && continue
    
    comm=$(basename "$cmd")
    should_exclude "$comm" && continue
    
    info=$(get_app_info "$comm")
    display_name=$(echo "$info" | cut -d'|' -f1)
    icon_name=$(echo "$info" | cut -d'|' -f2)
    has_desktop=$(echo "$info" | cut -d'|' -f3)
    
    [ "$has_desktop" != "yes" ] && continue
    
    # Skip if already seen
    [ -n "${seen_apps[$display_name]}" ] && continue
    seen_apps["$display_name"]=1
    
    # Write to map file (display_name -> pid:comm)
    echo "$display_name|$pid|$comm" >> "$TEMP_MAP"
    
    # Write to display file with icon
    icon_path=$(get_icon_path "$icon_name")
    if [ -n "$icon_path" ]; then
        printf "%s\0icon\x1f%s\n" "$display_name" "$icon_path" >> "$TEMP_FILE"
    else
        printf "%s\n" "$display_name" >> "$TEMP_FILE"
    fi
done < <(ps aux --sort=-%mem)

# Sort the display file
sort -o "$TEMP_FILE" "$TEMP_FILE"

# Check if empty
app_count=$(wc -l < "$TEMP_FILE")

if [ "$app_count" -eq 0 ]; then
    printf "No GUI applications found\n" > "$TEMP_FILE"
    printf "\n" >> "$TEMP_FILE"
    printf "󰠭 Debug Mode\n" >> "$TEMP_FILE"
fi

# Add control options
printf "\n" >> "$TEMP_FILE"
printf "󰚰 Refresh List\n" >> "$TEMP_FILE"
printf "󰗼 Process Manager\n" >> "$TEMP_FILE"

# Show rofi menu
selected=$(cat "$TEMP_FILE" | rofi -dmenu -i -p "Applications ($app_count)" -show-icons)

# Handle selection
if [ -n "$selected" ]; then
    case "$selected" in
        "󰚰 Refresh List")
            exec "$0"
            ;;
        
        "󰗼 Process Manager")
            kitty --class floating --title 'Process Manager' -e btop &
            ;;
        
        "󰠭 Debug Mode")
            debug_list=$(ps aux --sort=-%mem | awk -v user="$USER" '$1==user {print $11}' | \
                while read cmd; do
                    comm=$(basename "$cmd")
                    should_exclude "$comm" || echo "$comm"
                done | sort -u)
            
            echo "$debug_list" | rofi -dmenu -i -p "All User Processes"
            ;;
        
        "No GUI applications found")
            notify-send "Application Manager" "No applications running" -i dialog-information
            ;;
        
        *)
            # Find app info from map file
            info=$(grep "^$selected|" "$TEMP_MAP" | head -n1)
            
            if [ -n "$info" ]; then
                pid=$(echo "$info" | cut -d'|' -f2)
                comm=$(echo "$info" | cut -d'|' -f3)
                
                # Build action menu
                action_menu="󰐥 Focus Window\n󰿅 Kill Application\n View Details"
                
                if command -v hyprctl &> /dev/null; then
                    if hyprctl clients -j 2>/dev/null | jq -e ".[] | select(.pid == $pid)" > /dev/null 2>&1; then
                        action_menu="󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Application\n View Details"
                    fi
                fi
                
                action=$(echo -e "$action_menu" | rofi -dmenu -i -p "$selected")
                
                case "$action" in
                    "󰐥 Focus Window")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$address" ]; then
                                hyprctl dispatch focuswindow "address:$address"
                            else
                                notify-send "Application Manager" "$selected running in background" -i dialog-information
                            fi
                        fi
                        ;;
                    
                    "󰜺 Minimize")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            if [ -n "$address" ]; then
                                hyprctl dispatch movetoworkspacesilent "special:minimized,address:$address"
                                notify-send "Application Manager" "$selected minimized" -i preferences-desktop
                            fi
                        fi
                        ;;
                    
                    "󰿅 Kill Application")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Kill $selected?")
                        if [ "$confirm" == "Yes" ]; then
                            pkill -9 "$comm"
                            notify-send "Application Manager" "$selected terminated" -i preferences-desktop
                        fi
                        ;;
                    
                    " View Details")
                        mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs)
                        cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs)
                        time=$(ps -p "$pid" -o etime --no-headers 2>/dev/null | xargs)
                        cmd=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
                        count=$(pgrep -x "$comm" | wc -l)
                        
                        info="PID: $pid\nProcesses: $count\nCPU: ${cpu}%\nMemory: ${mem}%\nUptime: $time\nCommand: $cmd"
                        notify-send "Details: $selected" "$info" -i preferences-desktop -t 10000
                        ;;
                esac
            fi
            ;;
    esac
fi