#!/bin/bash

# Check if WiFi is enabled
wifi_enabled=$(nmcli radio wifi)

# Get current connection
current=$(nmcli -t -f NAME connection show --active | grep -v "lo" | head -n 1)

# Build menu header
menu_header=""

# WiFi toggle option
if [ "$wifi_enabled" == "enabled" ]; then
    menu_header+="󰖪 Disable WiFi\n"
else
    menu_header+="󰖩 Enable WiFi\n"
fi

# Network manager TUI option
menu_header+=" Open Network Manager TUI\n"

# Disconnect option if connected
if [ -n "$current" ]; then
    menu_header+="󰖪 Disconnect from: $current\n"
fi

# Build WiFi list only if WiFi is enabled
display_list=""
if [ "$wifi_enabled" == "enabled" ]; then
    nmcli device wifi rescan --wait 8 2>/dev/null
    wifi_list=$(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list 2>/dev/null | \
    sort -t: -k3 -rn | \
    awk -F: '!seen[$1]++')
    
    display_list=$(echo "$wifi_list" | awk -F: '{
        ssid = $1
        security = $2
        signal = $3
        if (security == "--") {
            icon = ""
            sec_text = "Open"
        } else {
            icon = ""
            sec_text = security
        }
        printf "%s %-35s %3s%%\n", icon, ssid " (" sec_text ")", signal
    }')
fi

# Combine header and WiFi list
full_menu="${menu_header}${display_list}"

# Show menu
selected_display=$(echo -e "$full_menu" | rofi -dmenu -i -p "WiFi Manager")

if [ -z "$selected_display" ]; then
    exit 0
fi

# Handle menu selections
case "$selected_display" in
    "󰖪 Disable WiFi")
        nmcli radio wifi off
        notify-send -a "System" "WiFi Manager" "󰖪 WiFi disabled" -i preferences-desktop
        ;;
    
    "󰖩 Enable WiFi")
        nmcli radio wifi on
        notify-send -a "System" "WiFi Manager" "󰖩 WiFi enabled" -i preferences-desktop
        ;;
    
    " Open Network Manager TUI")
        kitty --class floating --title 'nmtui' -e nmtui
        ;;
    
    "󰖪 Disconnect from:"*)
        nmcli connection down "$current"
        if [ $? -eq 0 ]; then
            notify-send -a "System" "WiFi Manager" "󰖪 Disconnected from $current" -i preferences-desktop
        else
            notify-send -a "System" "WiFi Manager" " Failed to disconnect" -i preferences-desktop
        fi
        ;;
    
    *)
        # Handle WiFi network selection
        ssid=$(echo "$selected_display" | sed 's/^. //' | sed -E 's/\s+\(.*\)\s+[0-9]+%?$//')
        security=$(echo "$wifi_list" | grep -F "^$ssid:" | cut -d: -f2)
        
        if [ -z "$security" ] || [ "$security" == "--" ]; then
            nmcli device wifi connect "$ssid"
        elif [[ "$security" == *"EAP"* ]]; then
            if nmcli -t -f NAME connection show | grep -q "^$ssid$"; then
                nmcli connection up id "$ssid"
            else
                notify-send -a "System" -u critical "WiFi" "No profile for '$ssid'. Please create one first." -i preferences-desktop
                exit 1
            fi
        else
            if nmcli -t -f NAME connection show | grep -q "^$ssid$"; then
                nmcli connection up id "$ssid"
            else
                password=$(rofi -dmenu -password -p "Password for $ssid")
                if [ -n "$password" ]; then
                    nmcli device wifi connect "$ssid" password "$password"
                else
                    exit 0
                fi
            fi
        fi
        
        if [ $? -eq 0 ]; then
            sleep 4
            connectivity=$(nmcli -t -f CONNECTIVITY general | cut -d: -f2)
            if [ "$connectivity" == "portal" ]; then
                notify-send -a "System" "WiFi Manager" "󰖩 Connected to $ssid\nPortal detected, please log in." -i preferences-desktop
            else
                notify-send -a "System" "WiFi Manager" "󰖩 Connected to $ssid" -i preferences-desktop
            fi
        else
            notify-send -a "System" "WiFi Manager" " Failed to connect to $ssid" -i preferences-desktop
        fi
        ;;
esac