#!/usr/bin/env bash

# Temporary files
TEMP_FILE="/tmp/rofi_apps_$$"
TEMP_MAP="/tmp/rofi_map_$$"
trap "rm -f $TEMP_FILE $TEMP_MAP" EXIT

# Папка для логов strace
LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# get_icon_path
# ──────────────────────────────────────────────────────────────────────────────
get_icon_path() {
    local icon_name="$1"
    for size in 48 32 24 16; do
        for theme_dir in ~/.local/share/icons /usr/share/icons/hicolor /usr/share/pixmaps /usr/share/icons/Adwaita /usr/share/icons/gnome; do
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
    if [ -f "/usr/share/icons/hicolor/scalable/apps/${icon_name}.svg" ]; then
        echo "/usr/share/icons/hicolor/scalable/apps/${icon_name}.svg"
    elif [ -f "/usr/share/pixmaps/${icon_name}.png" ]; then
        echo "/usr/share/pixmaps/${icon_name}.png"
    elif [ -f "/usr/share/pixmaps/${icon_name}.svg" ]; then
        echo "/usr/share/pixmaps/${icon_name}.svg"
    else
        echo "$icon_name"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# find_desktop_file
# ──────────────────────────────────────────────────────────────────────────────
find_desktop_file() {
    local process_name="$1"
    local clean_name=$(echo "$process_name" | sed 's/-bin$//' | sed 's/-git$//' | sed 's/-wrapped$//')

    for dir in /usr/share/applications ~/.local/share/applications \
               /var/lib/flatpak/exports/share/applications \
               ~/.local/share/flatpak/exports/share/applications; do
        [ ! -d "$dir" ] && continue

        [ -f "$dir/${clean_name}.desktop" ] && { echo "$dir/${clean_name}.desktop"; return 0; }

        local lower=$(echo "$clean_name" | tr '[:upper:]' '[:lower:]')
        [ -f "$dir/${lower}.desktop" ] && { echo "$dir/${lower}.desktop"; return 0; }

        local found=$(grep -l "Exec=.*$clean_name" "$dir"/*.desktop 2>/dev/null | head -n1)
        if [ -n "$found" ]; then
            if grep -q "Exec=.*--app-id=" "$found" || [[ "$found" =~ /(chrome|chromium|msedge|brave)- ]]; then
                continue
            fi
            echo "$found"
            return 0
        fi
    done
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# get_app_info
# ──────────────────────────────────────────────────────────────────────────────
get_app_info() {
    local process_name="$1"
    local desktop_file=$(find_desktop_file "$process_name")
    if [ -n "$desktop_file" ]; then
        local name=$(grep "^Name=" "$desktop_file" | head -n1 | cut -d'=' -f2-)
        local icon=$(grep "^Icon=" "$desktop_file" | head -n1 | cut -d'=' -f2-)
        [ -z "$icon" ] && icon="application-x-executable"
        echo "$name|$icon|yes"
    else
        local cap_name=$(echo "$process_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
        echo "$cap_name|application-x-executable|no"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Минимальный фильтр на бесполезные обрезанные имена (можно полностью убрать)
# ──────────────────────────────────────────────────────────────────────────────
should_skip_comm() {
    local comm="$1"
    # Только самые мусорные, которые никогда не бывают GUI-приложениями
    [[ "$comm" =~ ^(sd-pam|dbus-broker-lau|waitpid|bwrap|wl-paste|crashpad) ]] && return 0
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Сбор приложений
# ──────────────────────────────────────────────────────────────────────────────
> "$TEMP_FILE"
> "$TEMP_MAP"
declare -A seen_apps

while IFS= read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    pid=$(echo "$line" | awk '{print $2}')
    mem=$(echo "$line" | awk '{print $3}')
    comm=$(echo "$line" | awk '{print $4}')
    [ "$user" != "$USER" ] && continue
    should_skip_comm "$comm" && continue

    info=$(get_app_info "$comm")
    display_name=$(echo "$info" | cut -d'|' -f1)
    icon_name=$(echo "$info" | cut -d'|' -f2)

    [ -z "$display_name" ] && continue
    [ -n "${seen_apps[$display_name]}" ] && continue
    seen_apps["$display_name"]=1

    echo "$display_name|$pid|$comm" >> "$TEMP_MAP"

    icon_path=$(get_icon_path "$icon_name")
    printf "%s\0icon\x1f%s\n" "$display_name" "$icon_path" >> "$TEMP_FILE"
done < <(ps -eo user:20,pid:10,%mem:6,comm:50 --sort=-%mem | tail -n +2)

# Если пусто
app_count=$(wc -l < "$TEMP_FILE")
if [ "$app_count" -eq 0 ]; then
    printf "No applications found\0icon\x1fdialog-information\n" > "$TEMP_FILE"
    printf "\n" >> "$TEMP_FILE"
    printf "󰠭 Debug Mode\0icon\x1fsystem-help\n" >> "$TEMP_FILE"
fi

# Контрольные пункты
printf "\n" >> "$TEMP_FILE"
printf "🛠 Debug Tools\0icon\x1futilities-system-monitor\n" >> "$TEMP_FILE"
printf "󰚰 Refresh List\0icon\x1fview-refresh\n" >> "$TEMP_FILE"
printf "󰗼 Process Manager\0icon\x1fsystem-software-install\n" >> "$TEMP_FILE"

# Показ rofi
selected=$(cat "$TEMP_FILE" | rofi -dmenu -i -p "Applications ($app_count)" -show-icons)

# ──────────────────────────────────────────────────────────────────────────────
# Обработка выбора
# ──────────────────────────────────────────────────────────────────────────────
if [ -n "$selected" ]; then
    case "$selected" in
        "󰚰 Refresh List")
            exec "$0"
            ;;
        "󰗼 Process Manager")
            kitty --class floating --title 'Process Manager' -e btop &
            ;;
        "󰠭 Debug Mode")
            debug_list=$(ps -eo comm,pid,user --sort=-%mem | tail -n +2 | \
                awk -v u="$USER" '$3 == u {printf "[%s] [%s] [%s]\n", $1, $2, $3}' | sort -u)
            echo "$debug_list" | rofi -dmenu -i -p "All User Processes"
            ;;
        "No applications found")
            notify-send "Application Manager" "No applications running" -i dialog-information
            ;;
        "🛠 Debug Tools")
            debug_tool=$(printf "All Processes (nice format)\nhtop\nbtop\nRecent Logs (journalctl -xe)\n" | rofi -dmenu -i -p "System Debug Tools")
            case "$debug_tool" in
                "All Processes (nice format)")
                    ps -eo comm,pid,user,%cpu,%mem --sort=-%mem | \
                        awk '
                            NR==1 {
                                printf "%-22s %-8s %-12s %6s %6s\n", "[COMM]", "[PID]", "[USER]", "%CPU", "%MEM"
                                printf "%-22s %-8s %-12s %6s %6s\n", "----------------------", "--------", "------------", "------", "------"
                            }
                            NR>1 {
                                printf "[%-20s] [%-6s] [%-10s] %5s%% %5s%%\n", $1, $2, $3, $4, $5
                            }
                        ' | \
                        rofi -dmenu -i -p "Все процессы (сортировка по памяти)"
                    ;;
                "htop") kitty -e htop & ;;
                "btop") kitty -e btop & ;;
                "Recent Logs (journalctl -xe)") journalctl -xe | rofi -dmenu -i -p "Последние логи" ;;
            esac
            ;;
        *)
            info=$(grep "^$selected|" "$TEMP_MAP" | head -n1)
            if [ -n "$info" ]; then
                pid=$(echo "$info" | cut -d'|' -f2)
                comm=$(echo "$info" | cut -d'|' -f3)

                if ! kill -0 "$pid" 2>/dev/null; then
                    notify-send "Ошибка" "Процесс $pid ($comm) не найден" -i dialog-error
                    continue
                fi

                action_menu="󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Application\n❄️ Freeze\n🔥 Unfreeze\n🔍 Trace (strace)\n🛠 Debug Tools\nView Details"

                if command -v hyprctl &> /dev/null; then
                    if hyprctl clients -j 2>/dev/null | jq -e ".[] | select(.pid == $pid)" >/dev/null; then
                        action_menu="󰐥 Focus Window\n󰜺 Minimize\n󰿅 Kill Application\n❄️ Freeze\n🔥 Unfreeze\n🔍 Trace (strace)\n🛠 Debug Tools\nView Details"
                    fi
                fi

                action=$(echo -e "$action_menu" | rofi -dmenu -i -p "$selected (PID $pid)")

                case "$action" in
                    "󰐥 Focus Window")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            [ -n "$address" ] && hyprctl dispatch focuswindow "address:$address" || notify-send "Application Manager" "$selected в фоне" -i dialog-information
                        fi
                        ;;
                    "󰜺 Minimize")
                        if command -v hyprctl &> /dev/null; then
                            address=$(hyprctl clients -j | jq -r ".[] | select(.pid == $pid) | .address" | head -n1)
                            [ -n "$address" ] && {
                                hyprctl dispatch movetoworkspacesilent "special:minimized,address:$address"
                                notify-send "Application Manager" "$selected minimized" -i preferences-desktop
                            }
                        fi
                        ;;
                    "󰿅 Kill Application")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Убить $selected?")
                        [ "$confirm" == "Yes" ] && {
                            pkill -9 "$comm"
                            notify-send "Application Manager" "$selected terminated" -i preferences-desktop
                        }
                        ;;
                    "❄️ Freeze")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Заморозить $selected (PID $pid)?")
                        [ "$confirm" == "Yes" ] && {
                            kill -STOP "$pid"
                            notify-send "Process Manager" "$selected заморожен (SIGSTOP)" -i process-stop
                        }
                        ;;
                    "🔥 Unfreeze")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Разморозить $selected (PID $pid)?")
                        [ "$confirm" == "Yes" ] && {
                            kill -CONT "$pid"
                            notify-send "Process Manager" "$selected разморожен (SIGCONT)" -i process-start
                        }
                        ;;
                    "🔍 Trace (strace)")
                        confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Запустить strace на $selected (PID $pid)? (sudo)")
                        if [ "$confirm" == "Yes" ]; then
                            timestamp=$(date +%Y%m%d_%H%M%S)
                            log_file="$LOG_DIR/strace_${pid}_${timestamp}.log"

                            kitty --title "strace $comm (PID $pid)" -e bash -c "
                                echo 'Запуск strace на PID $pid...'
                                echo 'Если процесс умрёт быстро — окно закроется после лога.'
                                echo 'Лог сохраняется в: $log_file'
                                echo '----------------------------------------'
                                sudo strace -p $pid -s 128 -f -tt -T -o '$log_file' 2>&1 | tee '$log_file'
                                echo '----------------------------------------'
                                echo 'strace завершён. Лог сохранён в $log_file'
                                echo 'Нажмите Enter для закрытия окна...'
                                read
                            " &
                            notify-send "Trace" "strace запущен (sudo). Лог: $log_file" -i utilities-terminal
                        fi
                        ;;
                    "🛠 Debug Tools")
                        debug_action=$(printf "lsof (открытые файлы)\nss -tulp (сеть)\ntop -p PID\nhtop filtered\nperf top\ngdb attach\n" | rofi -dmenu -i -p "Debug $selected (PID $pid)")
                        case "$debug_action" in
                            "lsof (открытые файлы)") lsof -p "$pid" | rofi -dmenu -i -p "Открытые файлы" ;;
                            "ss -tulp (сеть)") ss -tulp | grep "$pid" | rofi -dmenu -i -p "Сетевые соединения" ;;
                            "top -p PID") kitty -e top -p "$pid" & ;;
                            "htop filtered") kitty -e htop -p "$pid" & ;;
                            "perf top")
                                if command -v perf >/dev/null; then
                                    sudo perf top -p "$pid" &
                                else
                                    notify-send "Ошибка" "perf не установлен" -i dialog-error
                                fi
                                ;;
                            "gdb attach")
                                if command -v gdb >/dev/null; then
                                    kitty -e gdb -p "$pid" &
                                else
                                    notify-send "Ошибка" "gdb не установлен" -i dialog-error
                                fi
                                ;;
                        esac
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