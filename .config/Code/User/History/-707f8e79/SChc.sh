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
            if [ -f "$theme_dir/${size}x${size}/apps/${icon_name}.svg" ]; then
                echo "$theme_dir/${size}x${size}/apps/${icon_name}.svg"
                return
            fi
        done
    done
    # Fallback
    if [ -f "/usr/share/icons/hicolor/scalable/apps/${icon_name}.svg" ]; then
        echo "/usr/share/icons/hicolor/scalable/apps/${icon_name}.svg"
    elif [ -f "/usr/share/pixmaps/${icon_name}.png" ]; then
        echo "/usr/share/pixmaps/${icon_name}.png"
    else
        echo "application-x-executable"  # rofi использует тему
    fi
}

# Function to find .desktop file
find_desktop_file() {
    local process_name="$1"
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')
    
    for dir in /usr/share/applications ~/.local/share/applications \
               /var/lib/flatpak/exports/share/applications \
               ~/.local/share/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue
        
        # Exact match
        if [ -f "$dir/${clean_name}.desktop" ]; then
            echo "$dir/${clean_name}.desktop"
            return 0
        fi
        
        # Lowercase match
        local lower=$(echo "$clean_name" | tr '[:upper:]' '[:lower:]')
        if [ -f "$dir/${lower}.desktop" ]; then
            echo "$dir/${lower}.desktop"
            return 0
        fi
        
        # Search by Exec, but exclude PWA
        local found=$(grep -l "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null | head -n1)
        if [ -n "$found" ]; then
            # Exclude PWA: --app-id= or file name starts with chrome-/chromium-/msedge-
            if grep -q "Exec=.*--app-id=" "$found" || [[ "$found" =~ /(chrome|chromium|msedge)- ]]; then
                continue  # skip this one, try next dir
            fi
            echo "$found"
            return 0
        fi
    done
    return 1
}

# Function to get app info
get_app_info() {
    local process_name="$1"
    local desktop_file=$(find_desktop_file "$process_name")
    if [ -n "$desktop_file" ]; then
        local name=$(grep "^Name=" "$desktop_file" | head -n1 | cut -d'=' -f2-)
        local icon=$(grep "^Icon=" "$desktop_file" | head -n1 | cut -d'=' -f2-)
        echo "$name|$icon|yes"
    else
        # Fallback: capitalize name
        local cap_name=$(echo "$process_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
        echo "$cap_name|application-x-executable|no"
    fi
}

# Blacklist
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

should_exclude() {
    local comm="$1"
    for item in "${BLACKLIST[@]}"; do [[ "$comm" == "$item" ]] && return 0; done
    [[ "$comm" =~ ^(systemd|gvfs|ibus|fcitx5|xdg|gsd|evolution|tracker|kwin_|plasma)- ]] && return 0
    return 1
}

# Collect apps
> "$TEMP_FILE"
> "$TEMP_MAP"
declare -A seen_apps

# ps with %mem for sorting
while IFS= read -r user pid mem comm rest; do
    [ "$user" != "$USER" ] && continue
    should_exclude "$comm" && continue
    
    info=$(get_app_info "$comm")
    display_name=$(echo "$info" | cut -d'|' -f1)
    icon_name=$(echo "$info" | cut -d'|' -f2)
    
    [ -n "${seen_apps[$display_name]}" ] && continue
    seen_apps["$display_name"]=1
    
    echo "$display_name|$pid|$comm" >> "$TEMP_MAP"
    
    icon_path=$(get_icon_path "$icon_name")
    if [ -n "$icon_path" ] && [ "$icon_path" != "application-x-executable" ]; then
        printf "%s\0icon\x1f%s\n" "$display_name" "$icon_path" >> "$TEMP_FILE"
    else
        printf "%s\0icon\x1f%s\n" "$display_name" "application-x-executable" >> "$TEMP_FILE"
    fi
done < <(ps -eo user:20,pid:10,%mem:6,comm:50 --sort=-%mem | tail -n +2)

# If empty
app_count=$(wc -l < "$TEMP_FILE")
if [ "$app_count" -eq 0 ]; then
    printf "No applications found\n\0icon\x1f dialog-information\n" > "$TEMP_FILE"
    printf "\n" >> "$TEMP_FILE"
    printf "󰠭 Debug Mode\n" >> "$TEMP_FILE"
fi

# Controls
printf "\n" >> "$TEMP_FILE"
printf "󰚰 Refresh List\n" >> "$TEMP_FILE"
printf "󰗼 Process Manager\n" >> "$TEMP_FILE"

# Show rofi
selected=$(cat "$TEMP_FILE" | rofi -dmenu -i -p "Applications ($app_count)" -show-icons)

# Handle selection (остальное без изменений, только мелкие фиксы)
if [ -n "$selected" ]; then
    case "$selected" in
        "󰚰 Refresh List")
            exec "$0"
            ;;
        "󰗼 Process Manager")
            kitty --class floating --title 'Process Manager' -e btop &
            ;;
        "󰠭 Debug Mode")
            debug_list=$(ps -eo comm --sort=-%mem | tail -n +2 | \
                while read comm; do
                    should_exclude "$comm" || echo "$comm"
                done | sort -u)
            echo "$debug_list" | rofi -dmenu -i -p "All User Processes"
            ;;
        "No applications found")
            notify-send "Application Manager" "No applications running" -i dialog-information
            ;;
        *)
            info=$(grep "^$selected|" "$TEMP_MAP" | head -n1)
            if [ -n "$info" ]; then
                pid=$(echo "$info" | cut -d'|' -f2)
                comm=$(echo "$info" | cut -d'|' -f3)
                
                action_menu="󰐥 Focus Window\n󰿅 Kill Application\nView Details"
                if command -v hyprctl &> /dev/null; then
                    if hyprctl clients -j 2>/dev/null | jq -e ".[] | select(.pid == $pid)" >/dev/null; then
                        action_menu="󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Application\nView Details"
                    fi
                fi
                
                action=$(echo -e "$action_menu" | rofi -dmenu -i -p "$selected")
                case "$action" in
                    "󰐥 Focus Window")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            [ -n "$address" ] && hyprctl dispatch focuswindow "address:$address" || notify-send "Application Manager" "$selected in background"
                        fi
                        ;;
                    "󰜺 Minimize")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            [ -n "$address" ] && {
                                hyprctl dispatch movetoworkspacesilent "special:minimized,address:$address"
                                notify-send "Application Manager" "$selected minimized"
                            }
                        fi
                        ;;
                    "󰿅 Kill Application")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Kill $selected?")
                        [ "$confirm" == "Yes" ] && {
                            pkill -9 "$comm"
                            notify-send "Application Manager" "$selected terminated"
                        }
                        ;;
                    "View Details")
                        mem=$(ps -p "$pid" -o %mem --no-headers | xargs)
                        cpu=$(ps -p "$pid" -o %cpu --no-headers | xargs)
                        time=$(ps -p "$pid" -o etime --no-headers | xargs)
                        cmd=$(ps -p "$pid" -o cmd --no-headers)
                        count=$(pgrep -x "$comm" | wc -l)
                        info="PID: $pid\nProcesses: $count\nCPU: ${cpu}%\nMemory: ${mem}%\nUptime: $time\nCommand: $cmd"
                        notify-send "Details: $selected" "$info" -i preferences-desktop -t 10000
                        ;;
                esac
            fi
            ;;
    esac
fi