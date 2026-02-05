# ============================================================================
# FISH SHELL CONFIGURATION
# ============================================================================
#
# KEYBIND CHEATSHEET:
# -------------------
# Ctrl+F - Accept autosuggestion
# Ctrl+U - Delete from cursor to beginning of line
# Ctrl+W - Delete word backward
# Alt+→ or Alt+F - Move forward one word
# Alt+← or Alt+B - Move backward one word
# Home - Move to beginning of line
# End - Move to end of line
# Ctrl+R - Search history
# Ctrl+L - Clear screen
#
# ALIASES & SHORTCUTS:
# --------------------
# Navigation: .., ..., ...., ..... (go up 1-4 directories)
# Shortcuts: dl (Downloads), doc (Documents), dt (Desktop)
# ls variants: ls, la, ll, lt, l., lsz
# git: g (git shorthand)
# System: reload, backup, installer
# Tools: icat (kitty image cat), snvim (sudo nvim)
# ============================================================================

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
set fish_greeting
set VIRTUAL_ENV_DISABLE_PROMPT "1"
set -x SHELL /usr/bin/fish
set -x LC_ALL "en_US.UTF-8"

# PATH configuration
set -x PATH $HOME/bin $PATH
set -x PATH $HOME/.local/bin $PATH
set -x PATH /opt/nvim $PATH

# Add depot_tools to PATH if exists
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end

# NVM directory
set -x NVM_DIR "$HOME/.config/nvm"

# Man pages with bat
set -xU MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -xU MANROFFOPT "-c"

# Paru pager hint
set -x PARU_PAGER "less -P \"Press 'q' to exit the PKGBUILD review.\""

# QT theme
if type -q qtile
   set -x QT_QPA_PLATFORMTHEME "qt5ct"
end

# Done notification settings
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# ============================================================================
# FISH PROFILE
# ============================================================================
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# ============================================================================
# STARSHIP PROMPT
# ============================================================================
if status --is-interactive
   source ("/usr/bin/starship" init fish --print-full-init | psub)
end

# ============================================================================
# ADVANCED COMMAND-NOT-FOUND HOOK
# ============================================================================
if test -f /usr/share/doc/find-the-command/ftc.fish
    source /usr/share/doc/find-the-command/ftc.fish
end

# ============================================================================
# FUNCTIONS
# ============================================================================

# Bang-bang support (!! and !$)
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history with timestamps
function history
    builtin history --show-time='%F %T '
end

# Backup function
function backup --argument filename
    cp $filename $filename.bak
end

# Enhanced copy function
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | string trim --right --chars=/)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

# Cleanup local orphaned packages
function cleanup
    while pacman -Qdtq
        sudo pacman -R (pacman -Qdtq)
        if test "$status" -eq 1
           break
        end
    end
end

# Reload fish configuration
function reload
    source ~/.config/fish/config.fish
    echo "Fish configuration reloaded!"
end

# ============================================================================
# ALIASES - NAVIGATION
# ============================================================================
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'
alias ...... 'cd ../../../../..'

# Directory shortcuts
alias dl 'cd ~/Downloads'
alias doc 'cd ~/Documents'
alias dt 'cd ~/Desktop'

# ============================================================================
# ALIASES - FILE LISTING (EZA)
# ============================================================================
alias ls 'eza -al --color=always --group-directories-first --icons' # preferred listing
alias lsz 'eza -al --color=always --total-size --group-directories-first --icons' # include file size
alias la 'eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias ll 'eza -l --color=always --group-directories-first --icons'  # long format
alias lt 'eza -aT --color=always --group-directories-first --icons' # tree listing
alias l. 'eza -ald --color=always --group-directories-first --icons .*' # show only dotfiles

# ============================================================================
# ALIASES - BETTER REPLACEMENTS
# ============================================================================
abbr cat 'bat --style header,snip,changes'

# Use paru as yay if available
if not test -x /usr/bin/yay; and test -x /usr/bin/paru
    alias yay 'paru'
end

# ============================================================================
# ALIASES - GIT & DEVELOPMENT
# ============================================================================
alias g 'git'

# ============================================================================
# ALIASES - SYSTEM UTILITIES
# ============================================================================
alias dir 'dir --color=auto'
alias vdir 'vdir --color=auto'
alias grep 'ugrep --color=auto'
alias egrep 'ugrep -E --color=auto'
alias fgrep 'ugrep -F --color=auto'
alias ip 'ip -color'
alias wget 'wget -c'

# ============================================================================
# ALIASES - PACKAGE MANAGEMENT (ARCH LINUX)
# ============================================================================
alias big 'expac -H M "%m\t%n" | sort -h | nl'     # Sort installed packages by size
alias gitpkg 'pacman -Q | grep -i "\-git" | wc -l' # Count -git packages
alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
alias rmpkg 'sudo pacman -Rdd'
alias upd '/usr/bin/garuda-update'

# Mirror management
alias mirror 'sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'
alias mirrora 'sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist'
alias mirrord 'sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist'
alias mirrors 'sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist'

# ============================================================================
# ALIASES - SYSTEM INFO & MONITORING
# ============================================================================
alias hw 'hwinfo --short'                          # Hardware Info
alias psmem 'ps auxf | sort -nr -k 4'
alias psmem10 'ps auxf | sort -nr -k 4 | head -10'
alias jctl 'journalctl -p 3 -xb'                   # Error messages from journalctl
alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl' # Recent installed packages

# ============================================================================
# ALIASES - GRUB
# ============================================================================
alias grubup 'sudo update-grub'

# ============================================================================
# ALIASES - ARCHIVE MANAGEMENT
# ============================================================================
alias tarnow 'tar -acf'
alias untar 'tar -zxvf'

# ============================================================================
# ALIASES - CUSTOM TOOLS & SCRIPTS
# ============================================================================
alias installer '~/Scripts/packages.sh'
alias icat 'kitty +kitten icat'
alias snvim 'sudo nvim'

# ============================================================================
# ALIASES - FUN COMMANDS
# ============================================================================
alias neo 'neo-matrix --speed=13'
alias bonsai 'cbonsai -li'
alias fishes 'asciiquarium'
alias rick 'curl ascii.live/rick'
alias map 'telnet mapscii.me'
alias pipes.sh 'pipes-rs'
alias tty-clock 'peaclock'

# ============================================================================
# ALIASES - FASTFETCH VARIANTS
# ============================================================================
alias ff 'fastfetch'
alias ffh 'fastfetch --logo ~/.config/fastfetch/hypr.png --logo-type kitty --logo-width 45 --logo-height 35'
alias ffm 'fastfetch --logo ~/.config/fastfetch/myst.png --logo-type kitty --logo-width 50 --logo-height 25'
alias ffnya 'fastfetch --logo ~/.config/fastfetch/nyarch.png --logo-type kitty --logo-width 50 --logo-height 25'
alias fastfetch-hypr 'fastfetch --logo ~/.config/fastfetch/hypr.png --logo-type kitty --logo-width 45 --logo-height 35'
alias fastfetch-myst 'fastfetch --logo ~/.config/fastfetch/myst.png --logo-type kitty --logo-width 50 --logo-height 25'
alias fastfetch-nyarch 'fastfetch --logo ~/.config/fastfetch/nyarch.png --logo-type kitty --logo-width 50 --logo-height 25'

# ============================================================================
# ALIASES - HELPER & MISC
# ============================================================================
alias please 'sudo'
alias tb 'nc termbin.com 9999'
alias helpme 'echo "To print basic information about a command use tldr <command>"'
alias pacdiff 'sudo -H DIFFPROG=meld pacdiff'

# Help for new Arch users
alias apt 'man pacman'
alias apt-get 'man pacman'

# ============================================================================
# DELTACAT SCRIPTS BLOCK
# ============================================================================
alias dcs-health-analize 'echo "=== БАТАРЕЯ ===" && upower -i /org/freedesktop/UPower/devices/battery_BAT1 | grep -E "capacity|energy-full" && echo "=== SSD ===" && sudo smartctl -a /dev/nvme0n1 | grep -E "Percentage Used|Available Spare|Data Units Written"'
alias dcs-clear-pkg 'sudo rm -rf /var/cache/pacman/pkg/*'
alias dcs-grub-edit 'sudo nano /etc/default/grub'
alias dcs-grub-upgrade 'sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias dcs-cmdline 'cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX_DEFAULT"'
alias dcs-pacman-edit 'sudo nano /etc/pacman.conf'
alias dcs-dracut-rebuild 'sudo dracut-rebuild'

# ============================================================================
# EXTERNAL TOOLS & INTEGRATIONS
# ============================================================================

# Python environment tools (skip if bass not installed)
# if test -f ~/Scripts/py_env_tools.sh
#     bass source ~/Scripts/py_env_tools.sh
# end

# NVM (Node Version Manager) - Fish native support
# if test -f $NVM_DIR/nvm.sh
#     bass source $NVM_DIR/nvm.sh
# end

# Zoxide (smarter cd)
if type -q zoxide
    zoxide init fish | source
end

# Dart CLI completion
if test -f ~/.config/.dart-cli-completion/fish-config.fish
    source ~/.config/.dart-cli-completion/fish-config.fish
end

# TheFuck (command correction)
if type -q thefuck
    thefuck --alias | source
end

# ============================================================================
# WELCOME MESSAGE
# ============================================================================
if status --is-interactive
    if test "$TERM" = "xterm-kitty"
        echo -e "\e[34m"(figlet -f ansi-shadow "Hi! $USER")"\e[0m"
        fastfetch --logo ~/.config/fastfetch/hypr.png --logo-type kitty --logo-width 45 --logo-height 35
    else if type -q fastfetch
        fastfetch --config neofetch.jsonc
    end
end

# ============================================================================
# END OF CONFIGURATION
# ============================================================================