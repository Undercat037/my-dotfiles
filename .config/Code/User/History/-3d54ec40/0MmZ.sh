#!/bin/bash

# Check if WiFi is enabled
wifi_enabled=$(nmcli radio wifi)
monitor_mode=$(iw dev | grep -c "type monitor")

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

# Monitor mode toggle (only if WiFi is enabled and not connected)
if [ "$wifi_enabled" == "enabled" ]; then
    if [ $monitor_mode -gt 0 ]; then
        menu_header+="󰤫 Stop Monitor Mode\n"
    else
        if [ -z "$current" ]; then
            menu_header+="󰤨 Start Monitor Mode\n"
        fi
    fi
fi

# Network manager TUI option
menu_header+=" Open Network Manager TUI\n"

# Disconnect option if connected
if [ -n "$current" ]; then
    menu_header+="󰖪 Disconnect from: $current\n"
fi

# Build WiFi list only if WiFi is enabled and not in monitor mode
display_list=""
if [ "$wifi_enabled" == "enabled" ] && [ $monitor_mode -eq 0 ]; then
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
    
    "󰤨 Start Monitor Mode")
        # Get WiFi interface name
        wifi_interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
        if [ -z "$wifi_interface" ]; then
            notify-send -a "System" -u critical "WiFi Manager" "No WiFi interface found" -i preferences-desktop
            exit 1
        fi
        
        # Start monitor mode
        pkexec airmon-ng start "$wifi_interface" 2>&1 | tee /tmp/airmon.log
        if [ $? -eq 0 ]; then
            notify-send -a "System" "WiFi Manager" "󰤨 Monitor mode enabled on ${wifi_interface}mon" -i preferences-desktop
        else
            notify-send -a "System" -u critical "WiFi Manager" "Failed to enable monitor mode" -i preferences-desktop
        fi
        ;;
    
    "󰤫 Stop Monitor Mode")
        # Get monitor interface name
        mon_interface=$(iw dev | grep -B 1 "type monitor" | grep Interface | awk '{print $2}')
        if [ -z "$mon_interface" ]; then
            notify-send -a "System" -u critical "WiFi Manager" "No monitor interface found" -i preferences-desktop
            exit 1
        fi
        
        # Stop monitor mode
        pkexec airmon-ng stop "$mon_interface" 2>&1 | tee /tmp/airmon.log
        if [ $? -eq 0 ]; then
            notify-send -a "System" "WiFi Manager" "󰤫 Monitor mode disabled" -i preferences-desktop
            # Restart NetworkManager to restore normal operation
            sleep 1
            sudo systemctl restart NetworkManager
        else
            notify-send -a "System" -u critical "WiFi Manager" "Failed to disable monitor mode" -i preferences-desktop
        fi
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