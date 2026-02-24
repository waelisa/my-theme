#!/usr/bin/env bash
#############################################################################################################################
# my-theme.sh - Dynamic Wallpaper & System Theme Engine
# Version: v1.1.2
# Build Date: 02/25/2026
# Author: Wael Isa
# Website: https://www.wael.name
# GitHub: https://github.com/waelisa
#
# ███╗   ███╗██╗   ██╗    ████████╗██╗  ██╗███████╗███╗   ███╗███████╗
# ████╗ ████║╚██╗ ██╔╝    ╚══██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝
# ██╔████╔██║ ╚████╔╝        ██║   ███████║█████╗  ██╔████╔██║█████╗
# ██║╚██╔╝██║  ╚██╔╝         ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝
# ██║ ╚═╝ ██║   ██║          ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗
# ╚═╝     ╚═╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝
#
#                        Version v1.1.2 - Wael Isa
#                 PATH FIXED & WALLHAVEN WORKING
#
# Description: Dynamic wallpaper and system theme engine with WallHaven integration,
#              lockscreen synchronization, and full Gum-based TUI.
#              COMPLETE SINGLE-FILE VERSION - No external modules needed!
#
# Features:
#   • FIXED: Now uses ~/Pictures/my-theme/wallpapers/ correctly
#   • FIXED: WallHaven downloads now work properly
#   • FIXED: Reset now updates wallpaper path
#   • MULTI-MONITOR SUPPORT - Sets wallpaper on ALL connected screens
#   • AUTO-INSTALLS EVERYTHING - All dependencies installed automatically
#   • Interactive menu by default (just run ./my-theme.sh)
#   • 100% self-contained - everything in one file
#   • REMOVED set -e - No more silent exits!
#   • ABSOLUTE PATHS - Works with GNOME 45+, KDE 6, Wayland
#   • TERMINAL COLOR SYNC - Terminal colors match wallpaper
#   • NOTIFICATION SYSTEM - Shows wallpaper preview on theme change
#   • AUTO-RESCUE - Downloads wallpapers when folder is empty
#   • AUTO-CREATES all missing folders
#   • AUTO-INSTALLS all dependencies on first run
#   • AUTO-CREATES default profiles and rules
#   • Lockscreen synchronization (betterlockscreen & hyprlock)
#   • WallHaven API integration with secure key storage
#   • Professional error handling with notifications
#   • Auto-profile switching based on running apps
#   • Snapshot gallery with thumbnails
#   • Debounced folder watcher
#
# Changelog:
#   v1.1.2 - FIXED: Wallpaper path now correctly uses ~/Pictures/my-theme/wallpapers/
#            FIXED: WallHaven downloads now work properly
#            FIXED: Reset function updates wallpaper path
#            IMPROVED: Better error messages for missing directories
#   v1.1.1 - SLIM: Removed all battery-related options
#   v1.1.0 - MULTI-MONITOR: Wallpaper sets on ALL screens
#   v1.0.9 - FIXED: All array syntax errors
#   v1.0.8 - SAFE MODE: All wallpapers in ~/Pictures/my-theme
#
#############################################################################################################################

# ==================== CONFIGURATION ====================
set -uo pipefail

# Version
SCRIPT_VERSION="v1.1.2"
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enable nullglob to prevent literal * when no files match
shopt -s nullglob

# Directories - SAFE MODE: All in ~/Pictures/my-theme
MY_THEME_PICTURES="${HOME}/Pictures/my-theme"
WALLPAPER_DIR="${MY_THEME_PICTURES}/wallpapers"
WALLHAVEN_DIR="${MY_THEME_PICTURES}/wallhaven"
CONFIG_DIR="${HOME}/.config/my-theme"
CACHE_DIR="${HOME}/.cache/my-theme"
PROFILES_DIR="${CONFIG_DIR}/profiles"
PROFILE_RULES_DIR="${CONFIG_DIR}/profile-rules"
SNAPSHOTS_DIR="${CONFIG_DIR}/snapshots"
HOOKS_DIR="${CONFIG_DIR}/hooks"
GRADIENCE_DIR="${CONFIG_DIR}/gradience"
THUMBNAILS_DIR="${CACHE_DIR}/thumbnails"
WALLHAVEN_IMAGE_CACHE="${CACHE_DIR}/wallhaven_images"
DESKTOP_ENTRY_DIR="${HOME}/.local/share/applications"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Files
WEATHER_CACHE="${CACHE_DIR}/weather.cache"
COLOR_CACHE="${CACHE_DIR}/current_colors"
COLOR_CACHE_SH="${CACHE_DIR}/current_colors.sh"
LOG_FILE="${CACHE_DIR}/my-theme.log"
SETTINGS_FILE="${CONFIG_DIR}/settings.conf"
WATCH_PID_FILE="${CACHE_DIR}/watch.pid"
DAEMON_PID_FILE="${CACHE_DIR}/daemon.pid"
CURRENT_PROFILE="${CACHE_DIR}/current_profile"
BROWSER_CSS="${CACHE_DIR}/browser_shared.css"
LAST_ACTIVE_PROFILE="${CACHE_DIR}/last_active_profile"
WALLHAVEN_CONFIG="${CONFIG_DIR}/wallhaven.conf"
API_KEY_FILE="${CONFIG_DIR}/api.key"
FIRST_RUN_FILE="${CACHE_DIR}/first_run_complete"
NO_WALLPAPER_NOTICE="${CACHE_DIR}/no_wallpaper_notice_shown"

# Cache settings
WEATHER_CACHE_AGE=900  # 15 minutes
WATCH_DEBOUNCE=2       # Seconds

# Default settings
CITY="${CITY:-}"
MONITOR_RESOLUTION=""
NIGHT_OVERRIDE="20"                    # 8 PM
SATURATION_BOOST="120"                 # 20% saturation boost
CONTRAST_STRETCH="2%x2%"               # Discard extreme pixels
ASPECT_RATIO_TOLERANCE="0.1"           # 10% tolerance
FORCE_MODE=false
NOTIFY_ERRORS=true
CURRENT_THEME_PROFILE="default"
AUTO_PROFILE_SWITCHING=true
PROFILE_CHECK_INTERVAL=60
TEMP_MONITORING=true
HIGH_TEMP_THRESHOLD=80                   # Celsius
USE_SIXEL=false
WALLHAVEN_API_KEY=""
WALLHAVEN_CATEGORIES="111"               # general:1, anime:1, people:1
WALLHAVEN_PURITY="100"                   # sfw:1, sketchy:0, nsfw:0
WALLHAVEN_RESOLUTION="1920x1080"
WALLHAVEN_LIMIT=10
WALLHAVEN_AUTO_CLEAN=false
WALLHAVEN_CLEAN_DAYS=30

# Default color palette (fallback)
declare -a DEFAULT_COLORS=("#2E3440" "#88C0D0" "#A3BE8C" "#EBCB8B" "#D08770" "#B48EAD" "#8FBCBB" "#5E81AC")

# Terminal detection
IS_TERMINAL=false
if [[ -t 0 ]] && [[ -t 1 ]]; then
    IS_TERMINAL=true
fi

# Debug mode
DEBUG="${DEBUG:-false}"

# Colors for output
if [[ "$IS_TERMINAL" == true ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''; BOLD=''
fi

# ==================== IMMEDIATE FEEDBACK ====================
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     My Theme Engine ${SCRIPT_VERSION} - Initializing...           ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"

# Create directories immediately
mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${GRADIENCE_DIR}" "${HOOKS_DIR}" \
         "${PROFILES_DIR}" "${PROFILE_RULES_DIR}" "${SNAPSHOTS_DIR}" \
         "${THUMBNAILS_DIR}" "${WALLHAVEN_IMAGE_CACHE}" \
         "${DESKTOP_ENTRY_DIR}" "${SYSTEMD_USER_DIR}" 2>/dev/null || true

# ==================== NOTIFICATION FUNCTIONS ====================

send_theme_notification() {
    local wall="$1"
    local profile="${CURRENT_THEME_PROFILE:-Default}"

    if command -v notify-send >/dev/null 2>&1 && [[ -f "$wall" ]]; then
        notify-send -a "My Theme Engine" \
            -i "$wall" \
            "🎨 Theme Updated: $profile" \
            "Wallpaper: $(basename "$wall")" 2>/dev/null || true
        log "Sent notification for theme update"
    fi
}

# ==================== TERMINAL COLOR SYNC ====================

sync_terminal_colors() {
    local wall="$1"
    local -a colors=()

    if [[ $# -lt 2 ]]; then
        mapfile -t colors < <(extract_colors "$wall" 8)
    else
        colors=("${@:2}")
    fi

    {
        echo "export COLOR0='${colors[0]}'"
        echo "export COLOR1='${colors[1]}'"
        echo "export COLOR2='${colors[2]}'"
        echo "export COLOR3='${colors[3]}'"
        echo "export COLOR4='${colors[4]}'"
        echo "export COLOR5='${colors[5]}'"
        echo "export COLOR6='${colors[6]}'"
        echo "export COLOR7='${colors[7]}'"
        echo "export ACCENT='${colors[2]}'"
        echo "export BACKGROUND='${colors[0]}'"
        echo "export FOREGROUND='$(get_contrast_color "${colors[0]}")'"
    } > "${COLOR_CACHE_SH}" 2>/dev/null || true

    local tty_count=0
    for tty in /dev/pts/[0-9]*; do
        if [[ -w "$tty" ]]; then
            printf "\033]11;${colors[0]}\007" > "$tty" 2>/dev/null || continue
            printf "\033]10;$(get_contrast_color "${colors[0]}")\007" > "$tty" 2>/dev/null || continue
            for i in {0..7}; do
                [[ $i -lt ${#colors[@]} ]] && printf "\033]4;$i;${colors[$i]}\007" > "$tty" 2>/dev/null || continue
            done
            ((tty_count++))
        fi
    done

    update_terminal_colors "${colors[@]}"
}

# ==================== AUTO-INSTALL FUNCTION ====================
auto_install() {
    if [[ -f "$FIRST_RUN_FILE" ]]; then
        return 0
    fi

    echo -e "${CYAN}ℹ️  First run detected - Setting up everything...${NC}"

    local deps_installed=false
    local pkgs=()
    local mgr=""

    if command -v apt >/dev/null 2>&1; then
        mgr="apt"
        pkgs=(imagemagick feh bc curl jq inotify-tools x11-utils lm-sensors chafa)
    elif command -v dnf >/dev/null 2>&1; then
        mgr="dnf"
        pkgs=(ImageMagick feh bc curl jq inotify-tools xrandr lm_sensors chafa)
    elif command -v pacman >/dev/null 2>&1; then
        mgr="pacman"
        pkgs=(imagemagick feh bc curl jq inotify-tools xorg-xrandr lm_sensors chafa)
    elif command -v zypper >/dev/null 2>&1; then
        mgr="zypper"
        pkgs=(imagemagick feh bc curl jq inotify-tools xrandr lm_sensors chafa)
    fi

    # Install gum
    if ! command -v gum >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Gum not found - installing...${NC}"
        if [[ "$mgr" == "apt" ]]; then
            echo "deb [trusted=yes] https://repo.charm.sh/apt/ /" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null 2>&1
            sudo apt update && sudo apt install -y gum
            deps_installed=true
        elif [[ "$mgr" == "pacman" ]]; then
            sudo pacman -S --noconfirm gum
            deps_installed=true
        elif [[ "$mgr" == "dnf" ]]; then
            sudo dnf install -y gum
            deps_installed=true
        else
            curl -L https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_linux_x86_64.tar.gz | tar xz
            sudo mv gum_*/gum /usr/local/bin/ 2>/dev/null || true
            rm -rf gum_*
            deps_installed=true
        fi
    fi

    # Install jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  jq not found - installing...${NC}"
        if [[ "$mgr" == "apt" ]]; then
            sudo apt install -y jq
        elif [[ "$mgr" == "pacman" ]]; then
            sudo pacman -S --noconfirm jq
        elif [[ "$mgr" == "dnf" ]]; then
            sudo dnf install -y jq
        fi
        deps_installed=true
    fi

    # Install feh
    if ! command -v feh >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  feh not found - installing...${NC}"
        if [[ "$mgr" == "apt" ]]; then
            sudo apt install -y feh
        elif [[ "$mgr" == "pacman" ]]; then
            sudo pacman -S --noconfirm feh
        elif [[ "$mgr" == "dnf" ]]; then
            sudo dnf install -y feh
        fi
        deps_installed=true
    fi

    # Install inotify-tools
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  inotify-tools not found - installing...${NC}"
        if [[ "$mgr" == "apt" ]]; then
            sudo apt install -y inotify-tools
        elif [[ "$mgr" == "pacman" ]]; then
            sudo pacman -S --noconfirm inotify-tools
        elif [[ "$mgr" == "dnf" ]]; then
            sudo dnf install -y inotify-tools
        fi
        deps_installed=true
    fi

    # Install swww for Wayland
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        if ! command -v swww >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  swww not found - installing...${NC}"
            if command -v cargo >/dev/null 2>&1; then
                cargo install swww
            elif [[ "$mgr" == "apt" ]]; then
                sudo apt install -y swww
            elif [[ "$mgr" == "pacman" ]]; then
                sudo pacman -S --noconfirm swww
            fi
            deps_installed=true
        fi
    fi

    # Create SAFE wallpaper directories
    mkdir -p "${MY_THEME_PICTURES}" 2>/dev/null
    mkdir -p "${WALLPAPER_DIR}"/{clear,rainy,cloudy,snowy,foggy,stormy,night,general,morning,day,evening} 2>/dev/null
    mkdir -p "${WALLHAVEN_DIR}" 2>/dev/null

    # Create README
    cat > "${MY_THEME_PICTURES}/README.txt" << EOF
MY THEME ENGINE - WALLPAPER DIRECTORY

All wallpapers should be placed in:
  ${WALLPAPER_DIR}

Folder Structure:
  wallpapers/clear/      - Sunny/clear weather wallpapers
  wallpapers/rainy/      - Rainy weather wallpapers
  wallpapers/cloudy/     - Cloudy weather wallpapers
  wallpapers/snowy/      - Snowy weather wallpapers
  wallpapers/foggy/      - Foggy weather wallpapers
  wallpapers/stormy/     - Stormy weather wallpapers
  wallpapers/night/      - Night time wallpapers
  wallpapers/general/    - General/default wallpapers
  wallhaven/             - WallHaven downloads

Happy theming! 🎨
EOF

    # Create default profiles
    for profile in work gaming relax web; do
        if [[ ! -d "${PROFILES_DIR}/${profile}" ]]; then
            mkdir -p "${PROFILES_DIR}/${profile}"
            echo "$WALLPAPER_DIR" > "${PROFILES_DIR}/${profile}/wallpaper_dir.txt"
            echo "NIGHT_OVERRIDE=20" > "${PROFILES_DIR}/${profile}/settings.conf"
        fi
    done

    # Create default profile rules
    [[ ! -f "${PROFILE_RULES_DIR}/work.conf" ]] && cat > "${PROFILE_RULES_DIR}/work.conf" << EOF
APP_PATTERN="code|idea|pycharm|eclipse"
PROFILE_NAME="work"
EOF

    [[ ! -f "${PROFILE_RULES_DIR}/gaming.conf" ]] && cat > "${PROFILE_RULES_DIR}/gaming.conf" << EOF
APP_PATTERN="steam|hl2_linux|dota2|cstrike|teamspeak"
PROFILE_NAME="gaming"
EOF

    [[ ! -f "${PROFILE_RULES_DIR}/web.conf" ]] && cat > "${PROFILE_RULES_DIR}/web.conf" << EOF
APP_PATTERN="firefox|chrome|chromium|brave|opera"
PROFILE_NAME="web"
EOF

    create_terminal_color_hook
    create_lockscreen_hook
    create_terminal_preview_hook
    create_spicetify_hook

    date > "$FIRST_RUN_FILE"

    echo -e "${GREEN}✅ First-time setup complete!${NC}"
    echo -e "${CYAN}📁 Wallpapers directory: ${WALLPAPER_DIR}${NC}"

    if [[ "$deps_installed" == true ]]; then
        echo -e "${YELLOW}⚠️  Some dependencies were installed. Please restart the script.${NC}"
        exit 0
    fi
}

# ==================== CREATE HOOKS ====================

create_terminal_color_hook() {
    local hook="${HOOKS_DIR}/01-terminal-colors.sh"
    [[ -f "$hook" ]] && return

    cat > "$hook" << 'EOF'
#!/usr/bin/env bash
WALLPAPER="$1"
CACHE_DIR="$HOME/.cache/my-theme"
mkdir -p "$CACHE_DIR"

if [[ -f "$CACHE_DIR/current_colors.sh" ]]; then
    source "$CACHE_DIR/current_colors.sh"
else
    mapfile -t colors < <(magick "$WALLPAPER" -colors 8 -unique-colors txt:- 2>/dev/null | grep -oh "#[0-9A-F]\{6\}" | head -n 8)
    {
        echo "export COLOR0='${colors[0]}'"
        echo "export COLOR1='${colors[1]}'"
        echo "export COLOR2='${colors[2]}'"
        echo "export COLOR3='${colors[3]}'"
        echo "export COLOR4='${colors[4]}'"
        echo "export COLOR5='${colors[5]}'"
        echo "export COLOR6='${colors[6]}'"
        echo "export COLOR7='${colors[7]}'"
        echo "export ACCENT='${colors[2]}'"
    } > "$CACHE_DIR/current_colors.sh"
    source "$CACHE_DIR/current_colors.sh"
fi

for tty in /dev/pts/[0-9]*; do
    [[ -w "$tty" ]] || continue
    printf "\033]11;${COLOR0}\007" > "$tty" 2>/dev/null || continue
    r=$((16#${COLOR0:1:2}))
    g=$((16#${COLOR0:3:2}))
    b=$((16#${COLOR0:5:2}))
    luminance=$(( (r*299 + g*587 + b*114) / 1000 ))
    [[ $luminance -gt 128 ]] && FG="#000000" || FG="#FFFFFF"
    printf "\033]10;${FG}\007" > "$tty" 2>/dev/null
    printf "\033]4;0;${COLOR0}\007\033]4;1;${COLOR1}\007\033]4;2;${COLOR2}\007\033]4;3;${COLOR3}\007" > "$tty" 2>/dev/null
    printf "\033]4;4;${COLOR4}\007\033]4;5;${COLOR5}\007\033]4;6;${COLOR6}\007\033]4;7;${COLOR7}\007" > "$tty" 2>/dev/null
done
echo "Terminal colors synchronized"
EOF
    chmod +x "$hook"
}

create_lockscreen_hook() {
    local hook="${HOOKS_DIR}/99-lockscreen.sh"
    [[ -f "$hook" ]] && return

    cat > "$hook" << 'EOF'
#!/usr/bin/env bash
WALLPAPER="$1"
CACHE="$HOME/.cache/my-theme/current_colors"
[[ -f "$CACHE" ]] && source "$CACHE"

if command -v betterlockscreen >/dev/null 2>&1 && [[ -f "$WALLPAPER" ]]; then
    betterlockscreen -u "$WALLPAPER" --blur 0.5 &
fi

if [[ -d "$HOME/.config/hypr" ]] && [[ -f "$WALLPAPER" ]]; then
    HYPR_VARS="$HOME/.config/hypr/theme_vars.conf"
    mkdir -p "$(dirname "$HYPR_VARS")"
    {
        echo "# Generated by my-theme.sh - $(date)"
        echo "\$wallpaper = $WALLPAPER"
        [[ -n "$COLOR2" ]] && echo "\$accent = rgb(${COLOR2#\#})"
        [[ -n "$BG" ]] && echo "\$bg = rgb(${BG#\#})"
        [[ -n "$FG" ]] && echo "\$fg = rgb(${FG#\#})"
    } > "$HYPR_VARS"
fi
EOF
    chmod +x "$hook"
}

create_terminal_preview_hook() {
    local hook="${HOOKS_DIR}/98-terminal-preview.sh"
    [[ -f "$hook" ]] || ! command -v chafa >/dev/null 2>&1 && return

    cat > "$hook" << 'EOF'
#!/usr/bin/env bash
WALLPAPER="$1"
if [[ "$TERM" == *"kitty"* ]] || [[ "$TERM" == *"sixel"* ]] && [[ -f "$WALLPAPER" ]]; then
    echo
    echo "📸 Wallpaper Preview:"
    chafa "$WALLPAPER" --size=40x20 2>/dev/null || true
    echo
fi
EOF
    chmod +x "$hook"
}

create_spicetify_hook() {
    local hook="${HOOKS_DIR}/update_spotify.sh"
    [[ -f "$hook" ]] && return

    cat > "$hook" << 'EOF'
#!/usr/bin/env bash
CACHE="$HOME/.cache/my-theme/current_colors"
[[ -f "$CACHE" ]] && source "$CACHE"
SPOTIFY_THEME="$HOME/.config/spicetify/Themes/MyTheme"

if command -v spicetify >/dev/null 2>&1; then
    mkdir -p "$SPOTIFY_THEME"
    cat > "$SPOTIFY_THEME/color.ini" << INNER
[Base]
main_bg = ${BG#\#}
main_fg = ${FG#\#}
accent = ${COLOR2#\#}
text = ${COLOR3#\#}
button = ${COLOR4#\#}
button_active = ${COLOR5#\#}
tab_active = ${COLOR2#\#}
notification = ${COLOR1#\#}
playback_bar = ${COLOR2#\#}
INNER
    spicetify config current_theme MyTheme
    spicetify apply -quiet
fi
EOF
    chmod +x "$hook"
}

run_hooks() {
    [[ ! -d "$HOOKS_DIR" ]] && return
    local count=0
    local wallpaper="$1"

    for hook in "$HOOKS_DIR"/*; do
        if [[ -x "$hook" ]] && [[ ! -d "$hook" ]]; then
            "$hook" "$wallpaper" > "${CACHE_DIR}/hook_$(basename "$hook").log" 2>&1 &
            ((count++))
        fi
    done
}

# ==================== CHECK FOR WALLPAPERS ====================
has_wallpapers() {
    local dir="$1"
    if [[ -d "$dir" ]] && find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" \) 2>/dev/null | head -1 | grep -q .; then
        return 0
    else
        return 1
    fi
}

check_for_wallpapers() {
    local dir="${1:-$WALLPAPER_DIR}"

    if ! has_wallpapers "$dir" && [[ ! -f "$NO_WALLPAPER_NOTICE" ]]; then
        touch "$NO_WALLPAPER_NOTICE"

        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                    NO WALLPAPERS FOUND!                        ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Your wallpaper directory is empty:${NC}"
        echo -e "  ${BOLD}${WALLPAPER_DIR}${NC}"
        echo
        echo -e "${GREEN}Options:${NC}"
        echo -e "  1. ${BOLD}Add your own wallpapers${NC} to the folders above"
        echo -e "  2. ${BOLD}Use WallHaven${NC} to download wallpapers automatically"
        echo

        if command -v gum >/dev/null 2>&1 && [[ "$IS_TERMINAL" == true ]]; then
            if gum confirm "Download starter wallpapers from WallHaven?" --affirmative="Yes" --negative="No"; then
                print_info "Downloading starter wallpapers..."
                local count=0
                for i in {1..3}; do
                    local url
                    url=$(fetch_wallhaven_wallpaper "general") && {
                        download_wallhaven_wallpaper "$url" >/dev/null 2>&1 && ((count++))
                    } || true
                done
                print_success "Downloaded $count starter wallpapers!"
            fi
        fi
    fi

    return 0
}

# ==================== CORE FUNCTIONS ====================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}" 2>/dev/null || true
    if [[ -f "${LOG_FILE}" ]] && [[ $(wc -l < "${LOG_FILE}" 2>/dev/null || echo "0") -gt 1000 ]]; then
        tail -n 1000 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null || true
    fi
}

print_error() { echo -e "${RED}❌ ERROR:${NC} $*" >&2; log "ERROR: $*"; }
print_warning() { echo -e "${YELLOW}⚠️  WARNING:${NC} $*"; log "WARNING: $*"; }
print_info() { echo -e "${CYAN}ℹ️  INFO:${NC} $*"; log "INFO: $*"; }
print_success() { echo -e "${GREEN}✅ SUCCESS:${NC} $*"; log "SUCCESS: $*"; }
print_debug() { [[ "$DEBUG" == "true" ]] && echo -e "${MAGENTA}🔍 DEBUG:${NC} $*"; }

error_exit() {
    print_error "$1"
    if [[ "$NOTIFY_ERRORS" == true ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -t 5000 "Theme Engine Error" "$1" 2>/dev/null || true
    fi
    exit 1
}

notify() {
    log "NOTIFY: $1 - $2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "${3:-normal}" -t 3000 "$1" "$2" 2>/dev/null || true
    fi
}

# ==================== UTILITY FUNCTIONS ====================

get_cpu_temperature() {
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        cat "/sys/class/thermal/thermal_zone0/temp" 2>/dev/null | cut -c1-2 || echo "0"
    elif command -v sensors >/dev/null 2>&1; then
        sensors | grep -i "core 0" | awk '{print $3}' | tr -d '+°C' | cut -d. -f1 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_monitor_resolution() {
    if command -v xrandr >/dev/null 2>&1; then
        xrandr --current | grep '*' | head -1 | awk '{print $1}' 2>/dev/null || echo "1920x1080"
    elif command -v sway >/dev/null 2>&1; then
        swaymsg -t get_outputs | jq -r '.[0].current_mode | "\(.width)x\(.height)"' 2>/dev/null || echo "1920x1080"
    else
        echo "1920x1080"
    fi
}

calculate_aspect_ratio() {
    local dims="$1"
    if [[ "$dims" =~ ([0-9]+)x([0-9]+) ]]; then
        local w="${BASH_REMATCH[1]}" h="${BASH_REMATCH[2]}"
        echo "scale=4; $w / $h" | bc 2>/dev/null || echo "1.7778"
    else
        echo "1.7778"
    fi
}

check_aspect_ratio() {
    local img="$1"
    local img_dims img_ratio mon_ratio diff

    img_dims=$(magick identify -format "%wx%h" "$img" 2>/dev/null || echo "1920x1080")
    img_ratio=$(calculate_aspect_ratio "$img_dims")
    mon_ratio=$(calculate_aspect_ratio "$MONITOR_RESOLUTION")
    diff=$(echo "scale=4; ($img_ratio - $mon_ratio) / $mon_ratio" | bc 2>/dev/null || echo "0")
    diff="${diff#-}"

    (( $(echo "$diff <= $ASPECT_RATIO_TOLERANCE" | bc -l 2>/dev/null || echo "0") ))
}

get_contrast_color() {
    local hex=${1#\#}
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    local lum=$(( (r * 212) + (g * 715) + (b * 72) ))
    [[ $lum -gt 128000 ]] && echo "#282a36" || echo "#f8f8f2"
}

darken_color() {
    local color="$1" pct="${2:-20}"
    if command -v magick >/dev/null 2>&1; then
        magick xc:"$color" -fill black -colorize "${pct}%" -format "%[pixel:u.p{0,0}]" info: 2>/dev/null || echo "$color"
    else
        blend_color "$color" "black" "$((100 - pct))"
    fi
}

lighten_color() {
    local color="$1" pct="${2:-20}"
    if command -v magick >/dev/null 2>&1; then
        magick xc:"$color" -fill white -colorize "${pct}%" -format "%[pixel:u.p{0,0}]" info: 2>/dev/null || echo "$color"
    else
        blend_color "$color" "white" "$((100 - pct))"
    fi
}

blend_color() {
    local hex="${1#\#}" blend="$2" ratio="${3:-80}"
    local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))

    if [[ "$blend" == "black" ]]; then
        r=$(( (r * ratio) / 100 ))
        g=$(( (g * ratio) / 100 ))
        b=$(( (b * ratio) / 100 ))
    else
        r=$(( (r * ratio + 255 * (100 - ratio)) / 100 ))
        g=$(( (g * ratio + 255 * (100 - ratio)) / 100 ))
        b=$(( (b * ratio + 255 * (100 - ratio)) / 100 ))
    fi

    printf "#%02x%02x%02x" "$r" "$g" "$b"
}

# ==================== CONFIGURATION FUNCTIONS ====================

load_settings() {
    [[ -f "$SETTINGS_FILE" ]] && source "$SETTINGS_FILE" 2>/dev/null

    # CRITICAL FIX: Always ensure WALLPAPER_DIR points to the correct location
    WALLPAPER_DIR="${MY_THEME_PICTURES}/wallpapers"

    [[ -f "$CURRENT_PROFILE" ]] && CURRENT_THEME_PROFILE=$(cat "$CURRENT_PROFILE" 2>/dev/null || echo "default")
    [[ -f "$WALLHAVEN_CONFIG" ]] && source "$WALLHAVEN_CONFIG" 2>/dev/null
    [[ -f "$API_KEY_FILE" ]] && WALLHAVEN_API_KEY=$(cat "$API_KEY_FILE" 2>/dev/null || echo "")
    print_debug "Settings loaded - Wallpaper dir: $WALLPAPER_DIR"
}

save_settings() {
    cat > "$SETTINGS_FILE" << EOF
# My Theme Settings - Generated $(date)
CITY="$CITY"
WALLPAPER_DIR="$WALLPAPER_DIR"
NIGHT_OVERRIDE="$NIGHT_OVERRIDE"
SATURATION_BOOST="$SATURATION_BOOST"
CONTRAST_STRETCH="$CONTRAST_STRETCH"
FORCE_MODE="$FORCE_MODE"
NOTIFY_ERRORS="$NOTIFY_ERRORS"
CURRENT_THEME_PROFILE="$CURRENT_THEME_PROFILE"
AUTO_PROFILE_SWITCHING="$AUTO_PROFILE_SWITCHING"
PROFILE_CHECK_INTERVAL="$PROFILE_CHECK_INTERVAL"
TEMP_MONITORING="$TEMP_MONITORING"
HIGH_TEMP_THRESHOLD="$HIGH_TEMP_THRESHOLD"
EOF
    print_debug "Settings saved"
}

save_wallhaven_config() {
    cat > "$WALLHAVEN_CONFIG" << EOF
# WallHaven Config - Generated $(date)
WALLHAVEN_CATEGORIES="$WALLHAVEN_CATEGORIES"
WALLHAVEN_PURITY="$WALLHAVEN_PURITY"
WALLHAVEN_RESOLUTION="$WALLHAVEN_RESOLUTION"
WALLHAVEN_LIMIT="$WALLHAVEN_LIMIT"
WALLHAVEN_AUTO_CLEAN="$WALLHAVEN_AUTO_CLEAN"
WALLHAVEN_CLEAN_DAYS="$WALLHAVEN_CLEAN_DAYS"
EOF
}

save_api_key() {
    echo "$1" > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
    WALLHAVEN_API_KEY="$1"
    print_success "API key saved securely"
    notify "API Key" "WallHaven API key saved"
}

stop_daemon() {
    if [[ -f "$DAEMON_PID_FILE" ]]; then
        local pid
        pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            rm -f "$DAEMON_PID_FILE"
            print_success "Daemon stopped (PID: $pid)"
            notify "Theme Daemon" "Stopped"
        else
            rm -f "$DAEMON_PID_FILE"
            print_warning "Stale PID file removed"
        fi
    else
        print_info "No daemon running"
    fi
}

# ==================== WEATHER FUNCTIONS ====================

detect_city() {
    if command -v curl >/dev/null 2>&1; then
        curl -s --max-time 3 ipinfo.io/city 2>/dev/null || \
        curl -s --max-time 3 "ipapi.co/json" 2>/dev/null | jq -r '.city // empty' 2>/dev/null || \
        echo "London"
    else
        echo "London"
    fi
}

fetch_weather_condition() {
    local city="${1:-$CITY}"
    local data="" cache_age=0 cond="general"

    if [[ -z "$city" ]]; then
        city=$(detect_city)
        CITY="$city"
        save_settings
        print_info "Auto-detected city: $city"
    fi

    if [[ -f "$WEATHER_CACHE" ]] && [[ "$FORCE_MODE" == false ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            cache_age=$(($(date +%s) - $(stat -f %m "$WEATHER_CACHE" 2>/dev/null || echo "0")))
        else
            cache_age=$(($(date +%s) - $(stat -c %Y "$WEATHER_CACHE" 2>/dev/null || echo "0")))
        fi
    fi

    if [[ $cache_age -lt $WEATHER_CACHE_AGE ]] && [[ -f "$WEATHER_CACHE" ]]; then
        data=$(cat "$WEATHER_CACHE")
        print_debug "Using cached weather (${cache_age}s old)"
    else
        print_info "Fetching weather for $city..."
        data=$(curl -s --max-time 5 "wttr.in/${city}?format=%C" 2>/dev/null || echo "")
        [[ -n "$data" ]] && ! [[ "$data" =~ Unknown ]] && echo "$data" > "$WEATHER_CACHE"
        [[ -z "$data" && -f "$WEATHER_CACHE" ]] && data=$(cat "$WEATHER_CACHE")
    fi

    if [[ "$FORCE_MODE" == false ]]; then
        local hour
        hour=$(date +%H)
        if [[ $hour -ge $NIGHT_OVERRIDE ]] || [[ $hour -lt 6 ]]; then
            print_debug "Night override active"
            echo "night"
            return
        fi
    fi

    if [[ -n "$data" ]]; then
        cond=$(echo "$data" | tr '[:upper:]' '[:lower:]' | awk '{print $NF}')
    fi

    case "$cond" in
        sunny|clear)          echo "clear" ;;
        rain|drizzle|shower)  echo "rainy" ;;
        cloudy|overcast)      echo "cloudy" ;;
        snow|blizzard|sleet)  echo "snowy" ;;
        fog|mist|haze)        echo "foggy" ;;
        thunder*|storm)        echo "stormy" ;;
        *)                    echo "general" ;;
    esac
}

# ==================== WALLPAPER FUNCTIONS ====================

get_profile_wallpaper_dir() {
    local profile="$1"
    local dir="${PROFILES_DIR}/${profile}"
    if [[ -f "${dir}/wallpaper_dir.txt" ]]; then
        cat "${dir}/wallpaper_dir.txt"
    else
        echo "$WALLPAPER_DIR"
    fi
}

select_wallpaper() {
    local condition="$1"
    local dir="$WALLPAPER_DIR"
    local target selected=""

    [[ "$CURRENT_THEME_PROFILE" != "default" ]] && dir=$(get_profile_wallpaper_dir "$CURRENT_THEME_PROFILE")

    print_debug "Selecting wallpaper for: $condition in $dir"

    if [[ "$FORCE_MODE" == true ]]; then
        if has_wallpapers "$dir"; then
            local -a files=("$dir"/*.{jpg,jpeg,png,bmp,gif})
            local -a valid_files=()
            for f in "${files[@]}"; do
                [[ -f "$f" ]] && valid_files+=("$f")
            done
            if [[ ${#valid_files[@]} -gt 0 ]]; then
                selected="${valid_files[$RANDOM % ${#valid_files[@]}]}"
            fi
        fi
        if [[ -n "$selected" ]]; then
            echo "$selected"
        else
            print_warning "No wallpapers found in $dir"
            echo ""
        fi
        return
    fi

    target="${dir}/${condition}"
    if [[ -d "$target" ]] && has_wallpapers "$target"; then
        local -a files=("$target"/*.{jpg,jpeg,png,bmp,gif})
        local -a valid_files=()
        for f in "${files[@]}"; do
            [[ -f "$f" ]] && valid_files+=("$f")
        done

        for img in "${valid_files[@]}"; do
            if check_aspect_ratio "$img"; then
                selected="$img"
                print_debug "Found aspect-ratio match: $img"
                break
            fi
        done

        if [[ -z "$selected" && ${#valid_files[@]} -gt 0 ]]; then
            selected="${valid_files[$RANDOM % ${#valid_files[@]}]}"
        fi
    fi

    if [[ -z "$selected" ]]; then
        if [[ -d "$dir" ]] && has_wallpapers "$dir"; then
            print_warning "No wallpapers in '${condition}' folder, using main directory"
            local -a files=("$dir"/*.{jpg,jpeg,png,bmp,gif})
            local -a valid_files=()
            for f in "${files[@]}"; do
                [[ -f "$f" ]] && valid_files+=("$f")
            done
            if [[ ${#valid_files[@]} -gt 0 ]]; then
                selected="${valid_files[$RANDOM % ${#valid_files[@]}]}"
            fi
        fi
    fi

    if [[ -z "$selected" ]]; then
        print_warning "No wallpapers found anywhere in ${dir}"
    fi

    echo "$selected"
}

extract_colors() {
    local wallpaper="$1" num="${2:-8}"
    local -a colors=()

    [[ ! -f "$wallpaper" ]] && { printf '%s\n' "${DEFAULT_COLORS[@]}"; return; }

    print_debug "Extracting colors from $wallpaper"

    mapfile -t colors < <(magick "$wallpaper" \
        -contrast-stretch "${CONTRAST_STRETCH}" \
        -modulate 100,${SATURATION_BOOST} \
        +dither -colors "$num" -unique-colors txt: 2>/dev/null | \
        grep -E -o "#[0-9A-Fa-f]{6}")

    if [[ ${#colors[@]} -lt 3 ]]; then
        print_warning "Color extraction failed, using defaults"
        printf '%s\n' "${DEFAULT_COLORS[@]}"
    else
        printf '%s\n' "${colors[@]}"
    fi
}

# ==================== WALLPAPER SETTER ====================
set_wallpaper() {
    local wall="$1"

    if [[ -z "$wall" || ! -f "$wall" ]]; then
        log "Error: Wallpaper path invalid or file missing: $wall"
        print_error "Wallpaper not found: $wall"
        return 1
    fi

    local wall_abs
    wall_abs=$(readlink -f "$wall")
    log "Applying wallpaper to ALL monitors: $wall_abs"

    send_theme_notification "$wall_abs" 2>/dev/null || true

    if [[ $# -gt 1 ]]; then
        sync_terminal_colors "$wall_abs" "${@:2}"
    else
        local -a colors
        mapfile -t colors < <(extract_colors "$wall_abs" 8)
        sync_terminal_colors "$wall_abs" "${colors[@]}"
    fi

    local de="${XDG_CURRENT_DESKTOP:-}"
    local session_type="${XDG_SESSION_TYPE:-}"

    print_debug "Setting wallpaper: DE=$de, Session=$session_type"

    if [[ "$session_type" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        if command -v swww >/dev/null 2>&1; then
            if ! pgrep -x "swww-daemon" >/dev/null; then
                swww-daemon &
                sleep 0.5
            fi
            swww img "$wall_abs" \
                --transition-type grow \
                --transition-pos 0.85,0.85 \
                --transition-step 90 \
                --transition-fps 60 \
                --transition-duration 2 2>/dev/null || true
            log "Wallpaper set via swww on all monitors"
            run_hooks "$wall_abs"
            return 0

        elif command -v hyprctl >/dev/null 2>&1 && command -v hyprpaper >/dev/null 2>&1; then
            hyprctl hyprpaper preload "$wall_abs" 2>/dev/null || true
            if command -v jq >/dev/null 2>&1; then
                local monitors
                monitors=$(hyprctl monitors -j | jq -r '.[] | .name' 2>/dev/null)
                for mon in $monitors; do
                    hyprctl hyprpaper wallpaper "$mon, $wall_abs" 2>/dev/null || true
                done
            else
                local monitor
                monitor=$(hyprctl monitors | grep "Monitor" | awk '{print $2}' | head -n1)
                [[ -n "$monitor" ]] && hyprctl hyprpaper wallpaper "$monitor, $wall_abs" 2>/dev/null || true
            fi
            log "Wallpaper set via hyprpaper"
            run_hooks "$wall_abs"
            return 0
        fi
    fi

    if [[ "$de" == *"GNOME"* ]] || [[ "$de" == *"Unity"* ]] || [[ "$de" == *"Cinnamon"* ]]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$wall_abs" 2>/dev/null || true
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$wall_abs" 2>/dev/null || true
        log "Wallpaper set via GNOME gsettings"
        run_hooks "$wall_abs"
        return 0

    elif [[ "$de" == *"KDE"* ]] || [[ "$de" == *"Plasma"* ]]; then
        if command -v qdbus >/dev/null 2>&1; then
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
                "var allDesktops = desktops(); for (var i=0; i<allDesktops.length; i++) { d = allDesktops[i]; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$wall_abs'); }" 2>/dev/null || true
            log "Wallpaper set via KDE qdbus"
            run_hooks "$wall_abs"
            return 0
        fi
    fi

    if [[ "$session_type" != "wayland" ]]; then
        if command -v feh >/dev/null 2>&1; then
            feh --bg-fill "$wall_abs" 2>/dev/null || true
            log "Wallpaper set via feh on all X11 monitors"
            run_hooks "$wall_abs"
            return 0
        elif command -v nitrogen >/dev/null 2>&1; then
            nitrogen --set-zoom-fill "$wall_abs" 2>/dev/null || true
            log "Wallpaper set via nitrogen"
            run_hooks "$wall_abs"
            return 0
        fi
    fi

    print_error "No compatible wallpaper setter found!"
    print_info "Please install one of: feh (X11), swww (Wayland)"
    return 1
}

# ==================== TERMINAL/BROWSER THEMES ====================

update_terminal_colors() {
    local -a colors=("$@")
    local bg="${colors[0]}" fg muted

    fg=$(get_contrast_color "$bg")
    muted=$(darken_color "$bg" 20)

    {
        echo "BG=$bg"
        echo "FG=$fg"
        echo "MUTED_BG=$muted"
        echo "SELECTED_WALL=$CURRENT_WALLPAPER"
        for i in "${!colors[@]}"; do echo "COLOR$i=${colors[$i]}"; done
        echo "TIMESTAMP=$(date +%s)"
        echo "PROFILE=$CURRENT_THEME_PROFILE"
    } > "$COLOR_CACHE" 2>/dev/null || true

    if [[ -f "${HOME}/.Xresources" ]]; then
        cp "${HOME}/.Xresources" "${HOME}/.Xresources.bak" 2>/dev/null || true
        sed -i "s/^.*foreground:.*/*.foreground: ${fg}/g" "${HOME}/.Xresources" 2>/dev/null || true
        sed -i "s/^.*background:.*/*.background: ${muted}/g" "${HOME}/.Xresources" 2>/dev/null || true
        for i in {0..15}; do
            [[ $i -lt ${#colors[@]} ]] && sed -i "s/^.*color${i}:.*/*.color${i}: ${colors[$i]}/g" "${HOME}/.Xresources" 2>/dev/null || true
        done
        command -v xrdb >/dev/null 2>&1 && xrdb -merge "${HOME}/.Xresources" 2>/dev/null || true
    fi

    if [[ -d "${HOME}/.config/kitty" ]]; then
        {
            echo "# Generated by my-theme.sh on $(date)"
            echo "background $muted"
            echo "foreground $fg"
            for i in {0..15}; do
                [[ $i -lt ${#colors[@]} ]] && echo "color$i ${colors[$i]}"
            done
        } > "${HOME}/.config/kitty/theme.conf" 2>/dev/null || true
        pgrep -x "kitty" >/dev/null && kill -SIGUSR1 $(pgrep -x "kitty") 2>/dev/null || true
    fi
}

update_browser_themes() {
    local -a colors=("$@")
    local bg="${colors[0]}" fg muted accent="${colors[2]}"

    fg=$(get_contrast_color "$bg")
    muted=$(darken_color "$bg" 15)

    cat > "$BROWSER_CSS" << EOF
/* Generated by my-theme.sh v${SCRIPT_VERSION} */
:root {
    --theme-bg: ${bg};
    --theme-fg: ${fg};
    --theme-accent: ${accent};
    --theme-surface: ${muted};
    --theme-color0: ${colors[0]};
    --theme-color1: ${colors[1]};
    --theme-color2: ${colors[2]};
    --theme-color3: ${colors[3]};
    --theme-color4: ${colors[4]};
    --theme-color5: ${colors[5]};
    --theme-timestamp: $(date +%s);
}
EOF

    if [[ -d "${HOME}/.mozilla/firefox" ]]; then
        for profile in "${HOME}"/.mozilla/firefox/*.default*; do
            [[ -d "$profile/chrome" ]] && echo "@import \"${BROWSER_CSS}\";" > "$profile/chrome/colors.css" 2>/dev/null || true
        done
    fi
}

generate_gradience_preset() {
    local -a colors=("$@")
    local bg="${colors[0]}" muted

    muted=$(darken_color "$bg" 15)

    cat > "${GRADIENCE_DIR}/my-theme.json" << EOF
{
  "name": "My Theme",
  "variables": {
    "accent_color": "${colors[2]}",
    "accent_bg_color": "${colors[2]}",
    "accent_fg_color": "$(get_contrast_color "${colors[2]}")",
    "destructive_color": "${colors[1]}",
    "destructive_bg_color": "${colors[1]}",
    "destructive_fg_color": "$(get_contrast_color "${colors[1]}")",
    "success_color": "${colors[3]}",
    "success_bg_color": "${colors[3]}",
    "success_fg_color": "$(get_contrast_color "${colors[3]}")",
    "warning_color": "${colors[4]}",
    "warning_bg_color": "${colors[4]}",
    "warning_fg_color": "$(get_contrast_color "${colors[4]}")",
    "error_color": "${colors[5]}",
    "error_bg_color": "${colors[5]}",
    "error_fg_color": "$(get_contrast_color "${colors[5]}")",
    "window_bg_color": "${muted}",
    "view_bg_color": "${muted}"
  }
}
EOF

    command -v gradience-cli >/dev/null 2>&1 && gradience-cli apply -p "${GRADIENCE_DIR}/my-theme.json" 2>/dev/null || true
}

# ==================== WALLHAVEN ====================

fetch_wallhaven_wallpaper() {
    local cat="${1:-random}"
    local url="https://wallhaven.cc/api/v1/search"
    local params=""

    case "$cat" in
        general) params="categories=111&purity=100" ;;
        anime)   params="categories=010&purity=100" ;;
        people)  params="categories=001&purity=100" ;;
        *)       params="categories=${WALLHAVEN_CATEGORIES}&purity=${WALLHAVEN_PURITY}" ;;
    esac

    [[ -n "$WALLHAVEN_API_KEY" ]] && params="${params}&apikey=${WALLHAVEN_API_KEY}"
    [[ -n "$WALLHAVEN_RESOLUTION" ]] && params="${params}&resolutions=${WALLHAVEN_RESOLUTION}"
    params="${params}&sorting=random&limit=${WALLHAVEN_LIMIT}"

    print_debug "Fetching WallHaven: $params"

    local resp
    resp=$(curl -s "${url}?${params}" 2>/dev/null)

    if [[ -z "$resp" ]]; then
        print_warning "No response from WallHaven API"
        return 1
    fi

    local urls
    mapfile -t urls < <(echo "$resp" | jq -r '.data[].path // empty' 2>/dev/null)

    if [[ ${#urls[@]} -eq 0 ]]; then
        print_warning "No wallpapers found from WallHaven"
        return 1
    fi

    echo "${urls[$RANDOM % ${#urls[@]}]}"
}

download_wallhaven_wallpaper() {
    local url="$1"
    local fname=$(basename "$url")
    local local_path="${WALLHAVEN_DIR}/${fname}"
    local tmp_path="${WALLHAVEN_IMAGE_CACHE}/${fname}"

    [[ -f "$local_path" ]] && { echo "$local_path"; return 0; }

    print_info "Downloading: $fname"

    # Create directory if it doesn't exist
    mkdir -p "${WALLHAVEN_DIR}" "${WALLHAVEN_IMAGE_CACHE}" 2>/dev/null

    if curl -L -s --max-time 30 "$url" -o "$tmp_path"; then
        if [[ -f "$tmp_path" ]] && magick identify "$tmp_path" >/dev/null 2>&1; then
            mv "$tmp_path" "$local_path"
            print_success "Downloaded: $fname"
            echo "$local_path"
            return 0
        else
            print_error "Downloaded file is not a valid image"
            rm -f "$tmp_path"
        fi
    else
        print_error "Download failed - curl error"
    fi

    return 1
}

clean_wallhaven_folder() {
    local days="${1:-$WALLHAVEN_CLEAN_DAYS}"
    [[ ! -d "$WALLHAVEN_DIR" ]] && return

    print_info "Cleaning wallpapers older than $days days"

    local count=0
    while IFS= read -r file; do
        rm -f "$file"
        ((count++))
    done < <(find "$WALLHAVEN_DIR" -type f -mtime +"$days" 2>/dev/null)

    [[ $count -gt 0 ]] && print_success "Removed $count old wallpapers"
}

# ==================== PROFILE MANAGEMENT ====================

detect_profile_from_apps() {
    declare -A profiles=()
    local detected=""

    if [[ -d "$PROFILE_RULES_DIR" ]]; then
        for rule in "$PROFILE_RULES_DIR"/*.conf; do
            [[ -f "$rule" ]] && source "$rule" && [[ -n "$APP_PATTERN" ]] && [[ -n "$PROFILE_NAME" ]] && \
                profiles["$APP_PATTERN"]="$PROFILE_NAME"
        done
    fi

    profiles["code"]="work"
    profiles["idea"]="work"
    profiles["steam"]="gaming"
    profiles["spotify"]="relax"
    profiles["firefox"]="web"
    profiles["chrome"]="web"

    if [[ "$TEMP_MONITORING" == true ]]; then
        local temp
        temp=$(get_cpu_temperature)
        [[ $temp -gt $HIGH_TEMP_THRESHOLD ]] && { echo "gaming"; return; }
    fi

    for pattern in "${!profiles[@]}"; do
        pgrep -f "$pattern" >/dev/null 2>&1 && { detected="${profiles[$pattern]}"; break; }
    done

    echo "${detected:-default}"
}

check_and_switch_profile() {
    [[ "$AUTO_PROFILE_SWITCHING" != true ]] && return

    local detected
    detected=$(detect_profile_from_apps)

    [[ -f "$LAST_ACTIVE_PROFILE" ]] && [[ "$(cat "$LAST_ACTIVE_PROFILE" 2>/dev/null)" == "$detected" ]] && return

    if [[ "$detected" != "default" ]] && [[ "$detected" != "$CURRENT_THEME_PROFILE" ]]; then
        print_info "Auto-switching to profile: $detected"
        notify "Profile Switch" "Auto-switched to $detected profile"
        switch_profile "$detected" "no-update"
        echo "$detected" > "$LAST_ACTIVE_PROFILE"
        update_theme "random"
    fi
}

ensure_profile_exists() {
    local profile="$1"

    if [[ "$profile" == "default" ]]; then
        return 0
    fi

    local dir="${PROFILES_DIR}/${profile}"

    if [[ ! -d "$dir" ]]; then
        print_info "Creating missing profile: $profile"
        mkdir -p "$dir"

        echo "$WALLPAPER_DIR" > "${dir}/wallpaper_dir.txt"
        echo "NIGHT_OVERRIDE=$NIGHT_OVERRIDE" > "${dir}/settings.conf"

        print_success "Created profile: $profile"
    fi
}

create_profile() {
    local name="$1"
    local dir="${PROFILES_DIR}/${name}"

    [[ -d "$dir" ]] && ! gum confirm "Overwrite profile '$name'?" && return
    rm -rf "$dir" 2>/dev/null
    mkdir -p "$dir"

    local wall_dir
    wall_dir=$(gum input --placeholder "Wallpaper directory" --value "$WALLPAPER_DIR")
    echo "$wall_dir" > "${dir}/wallpaper_dir.txt"

    local night
    night=$(gum input --placeholder "Night override hour" --value "$NIGHT_OVERRIDE")
    echo "NIGHT_OVERRIDE=$night" > "${dir}/settings.conf"

    print_success "Created profile: $name"
    notify "Theme Profile" "Created: $name"
}

create_profile_rule() {
    local name="$1"
    local file="${PROFILE_RULES_DIR}/${name}.conf"

    [[ -f "$file" ]] && ! gum confirm "Overwrite rule?" && return

    local pattern profile
    pattern=$(gum input --placeholder "App pattern (e.g., 'code')")
    profile=$(gum input --placeholder "Profile name")

    cat > "$file" << EOF
APP_PATTERN="$pattern"
PROFILE_NAME="$profile"
EOF

    print_success "Created rule: $name"
}

switch_profile() {
    local profile="$1" skip="${2:-}"

    ensure_profile_exists "$profile"

    local dir="${PROFILES_DIR}/${profile}"

    if [[ "$profile" == "default" ]]; then
        rm -f "$CURRENT_PROFILE"
        CURRENT_THEME_PROFILE="default"
        WALLPAPER_DIR="${MY_THEME_PICTURES}/wallpapers"
    else
        echo "$profile" > "$CURRENT_PROFILE"
        CURRENT_THEME_PROFILE="$profile"
        [[ -f "$dir/settings.conf" ]] && source "$dir/settings.conf"
        [[ -f "$dir/wallpaper_dir.txt" ]] && WALLPAPER_DIR=$(cat "$dir/wallpaper_dir.txt")
    fi

    save_settings
    print_success "Switched to profile: $profile"
    notify "Theme Profile" "Switched to: $profile"
}

# ==================== SNAPSHOTS ====================

save_snapshot() {
    local name="${1:-snapshot_$(date +%Y%m%d_%H%M%S)}"
    local dir="${SNAPSHOTS_DIR}/${name}"

    mkdir -p "$dir"

    [[ -f "$COLOR_CACHE" ]] && cp "$COLOR_CACHE" "$dir/colors.txt"
    [[ -f "$SETTINGS_FILE" ]] && cp "$SETTINGS_FILE" "$dir/settings.conf" 2>/dev/null || true

    if [[ -n "${CURRENT_WALLPAPER:-}" ]] && [[ -f "$CURRENT_WALLPAPER" ]]; then
        cp "$CURRENT_WALLPAPER" "$dir/wallpaper.jpg" 2>/dev/null || true
        echo "$CURRENT_WALLPAPER" > "$dir/wallpaper_path.txt"
    fi

    print_success "Saved snapshot: $name"
    notify "Theme Snapshot" "Saved as: $name"
}

load_snapshot() {
    local name="$1"
    local dir="${SNAPSHOTS_DIR}/${name}"

    [[ ! -d "$dir" ]] && error_exit "Snapshot not found: $name"

    [[ -f "$dir/colors.txt" ]] && cp "$dir/colors.txt" "$COLOR_CACHE" && source "$COLOR_CACHE"
    [[ -f "$dir/settings.conf" ]] && cp "$dir/settings.conf" "$SETTINGS_FILE" && load_settings

    if [[ -f "$dir/wallpaper.jpg" ]]; then
        CURRENT_WALLPAPER="$dir/wallpaper.jpg"
    elif [[ -f "$dir/wallpaper_path.txt" ]]; then
        CURRENT_WALLPAPER=$(cat "$dir/wallpaper_path.txt")
    fi

    print_success "Loaded snapshot: $name"
    notify "Theme Snapshot" "Loaded: $name"
}

# ==================== WATCHER ====================

start_watcher() {
    ! command -v inotifywait >/dev/null 2>&1 && { print_error "inotifywait not found"; return 1; }

    stop_watcher

    (
        local last=0
        while true; do
            inotifywait -q -e create -e delete -e move -e modify "$WALLPAPER_DIR" 2>/dev/null
            local now=$(date +%s)
            if [[ $((now - last)) -gt $WATCH_DEBOUNCE ]]; then
                print_debug "Directory changed, updating..."
                (
                    OLD_FORCE="$FORCE_MODE"
                    FORCE_MODE=true
                    update_theme "random"
                    FORCE_MODE="$OLD_FORCE"
                ) &
                last=$now
            fi
        done
    ) &

    echo $! > "$WATCH_PID_FILE"
    print_success "Watcher started (PID: $!)"
    notify "Folder Watcher" "Started monitoring $WALLPAPER_DIR"
}

stop_watcher() {
    [[ -f "$WATCH_PID_FILE" ]] && {
        kill "$(cat "$WATCH_PID_FILE")" 2>/dev/null || true
        rm -f "$WATCH_PID_FILE"
        print_success "Watcher stopped"
        notify "Folder Watcher" "Stopped"
    }
}

# ==================== UPDATE THEME ====================

update_theme() {
    local mode="$1"
    local condition="" wallpaper=""

    print_info "Theme update started (mode: $mode)"

    MONITOR_RESOLUTION=$(get_monitor_resolution)
    print_debug "Monitor: $MONITOR_RESOLUTION"

    case "$mode" in
        weather)  condition=$(fetch_weather_condition) ;;
        time)
            local h=$(date +%H)
            [[ $h -ge 5 && $h -lt 9 ]] && condition="morning"
            [[ $h -ge 9 && $h -lt 17 ]] && condition="day"
            [[ $h -ge 17 && $h -lt 20 ]] && condition="evening"
            [[ $h -ge 20 || $h -lt 5 ]] && condition="night"
            ;;
        specific) [[ -n "${SPECIFIC_WALLPAPER:-}" ]] && wallpaper="$SPECIFIC_WALLPAPER" ;;
        *)        condition="random" ;;
    esac

    if [[ -z "$wallpaper" ]]; then
        wallpaper=$(select_wallpaper "$condition")
    fi

    if [[ -z "$wallpaper" ]]; then
        print_warning "No wallpaper found! Attempting to download from WallHaven..."
        local url
        url=$(fetch_wallhaven_wallpaper "general")
        if [[ -n "$url" ]]; then
            wallpaper=$(download_wallhaven_wallpaper "$url")
        fi
    fi

    if [[ -z "$wallpaper" ]]; then
        print_error "No wallpaper found! Please add wallpapers to:"
        print_error "  ${WALLPAPER_DIR}/${condition}"
        notify "No Wallpaper" "Please add wallpapers or use WallHaven" "normal"
        return 1
    fi

    CURRENT_WALLPAPER="$wallpaper"
    print_success "Selected: $(basename "$wallpaper")"

    local -a colors
    mapfile -t colors < <(extract_colors "$wallpaper" 8)

    set_wallpaper "$wallpaper" "${colors[@]}"

    update_browser_themes "${colors[@]}"

    command -v gradience-cli >/dev/null 2>&1 && generate_gradience_preset "${colors[@]}"

    [[ "$WALLHAVEN_AUTO_CLEAN" == true ]] && clean_wallhaven_folder "$WALLHAVEN_CLEAN_DAYS" >/dev/null 2>&1 &

    print_success "Theme updated!"
    notify "Theme Updated" "Mode: $mode | Profile: $CURRENT_THEME_PROFILE" "low"
    save_settings
}

# ==================== DAEMON ====================

run_daemon() {
    local interval="${1:-30}" mode="${2:-random}"

    echo $$ > "$DAEMON_PID_FILE"
    print_info "Daemon started (interval: ${interval}min, mode: ${mode})"
    notify "Theme Daemon" "Started with ${interval}min interval"

    start_watcher
    trap stop_watcher EXIT INT TERM

    update_theme "$mode"

    local secs=$((interval * 60))

    while true; do
        if [[ "$AUTO_PROFILE_SWITCHING" == true ]]; then
            check_and_switch_profile
        fi

        print_debug "Sleeping for $((secs / 60)) minutes"
        sleep "$secs"
        update_theme "$mode"
    done
}

# ==================== INSTALLATION ====================

install_dependencies() {
    print_info "Installing dependencies..."
    auto_install
}

create_desktop_entry() {
    local file="${DESKTOP_ENTRY_DIR}/my-theme.desktop"
    local term="${TERMINAL:-xterm}"

    cat > "$file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=My Theme Engine
Comment=Dynamic Wallpaper & System Theme Manager
Exec=$term -e $0 --interactive
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Settings;System;
Keywords=theme;wallpaper;dynamic;
EOF

    chmod +x "$file"
    print_success "Desktop entry created"
}

create_systemd_service() {
    local file="${SYSTEMD_USER_DIR}/my-theme.service"

    cat > "$file" << EOF
[Unit]
Description=My Theme Engine - Dynamic Wallpaper & Theme Manager
After=graphical-session.target

[Service]
Type=simple
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%i/bus
ExecStart=$0 --daemon --mode random --interval 30
Restart=on-failure
RestartSec=10
PIDFile=${DAEMON_PID_FILE}

[Install]
WantedBy=graphical-session.target
EOF

    print_success "Systemd service created"
    print_info "Enable with: systemctl --user enable my-theme.service"
}

reset_config() {
    print_warning "Resetting configuration..."
    stop_watcher 2>/dev/null || true
    stop_daemon 2>/dev/null || true
    rm -rf "${CACHE_DIR:?}"/* 2>/dev/null
    rm -f "$SETTINGS_FILE" "$CURRENT_PROFILE" "$LAST_ACTIVE_PROFILE" "$WALLHAVEN_CONFIG" "$API_KEY_FILE"
    rm -f "$NO_WALLPAPER_NOTICE"
    rm -f "$FIRST_RUN_FILE"
    mkdir -p "$CACHE_DIR" "$HOOKS_DIR"
    CURRENT_THEME_PROFILE="default"

    # CRITICAL FIX: Reset wallpaper directory to correct path
    WALLPAPER_DIR="${MY_THEME_PICTURES}/wallpapers"

    print_success "Configuration reset - Wallpaper dir: $WALLPAPER_DIR"
    notify "Theme Engine" "Configuration reset"
}

# ==================== SELF TEST ====================

self_test() {
    echo -e "\n${BOLD}🔍 My Theme Engine v${SCRIPT_VERSION} Self-Test${NC}"
    echo "========================================"

    echo -n "• Script location: "
    echo -e "${GREEN}✓${NC} $0"

    echo -n "• Terminal: "
    if [[ "$IS_TERMINAL" == true ]]; then
        echo -e "${GREEN}✓ Interactive${NC}"
    else
        echo -e "${YELLOW}⚠ Non-interactive${NC}"
    fi

    echo "• Dependencies:"
    for dep in bash grep sed curl magick feh xrandr notify-send inotifywait swww jq; do
        echo -n "  $dep... "
        if command -v "$dep" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        elif command -v "${dep/imagemagick/magick}" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} (as magick)"
        else
            echo -e "${YELLOW}⚠ Not found${NC}"
        fi
    done

    echo -n "• Gum TUI: "
    if command -v gum >/dev/null 2>&1; then
        echo -e "${GREEN}✓$(gum --version 2>/dev/null | head -1 | sed 's/.*/ &/')${NC}"
    else
        echo -e "${YELLOW}⚠ Not installed${NC}"
    fi

    echo "• Config directories:"
    for dir in "$CONFIG_DIR" "$CACHE_DIR" "$MY_THEME_PICTURES"; do
        echo -n "  $dir... "
        if [[ -d "$dir" ]]; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${CYAN}ℹ Will be created${NC}"
        fi
    done

    echo -n "• Wallpaper directory: "
    echo -e "${CYAN}${WALLPAPER_DIR}${NC}"

    echo -n "• Wallpapers found: "
    if has_wallpapers "$WALLPAPER_DIR"; then
        echo -e "${GREEN}✓ Yes${NC}"
    else
        echo -e "${YELLOW}⚠ None (use WallHaven to download)${NC}"
    fi

    echo "========================================"
    echo -e "${GREEN}✅ Self-test complete${NC}"
}

# ==================== MENUS ====================

wallhaven_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            --header="🌌 WallHaven Manager" \
            --cursor="👉 " \
            --height=10 \
            "🔑 Configure API Key" \
            "🎲 Fetch Random" \
            "🖼️  Fetch General" \
            "🌸 Fetch Anime" \
            "👥 Fetch People" \
            "⚙️  Settings" \
            "🧹 Clean Old" \
            "📁 Open Folder" \
            "↩️  Back")

        case "$choice" in
            *"API Key"*)
                local key
                key=$(gum input --placeholder "Enter WallHaven API Key" --password)
                [[ -n "$key" ]] && save_api_key "$key"
                ;;
            *"Random"*)
                [[ -z "$WALLHAVEN_API_KEY" ]] && ! gum confirm "No API key. Continue?" && continue
                gum spin --spinner globe --title "Fetching..." -- sleep 1
                local url=$(fetch_wallhaven_wallpaper "random")
                if [[ -n "$url" ]]; then
                    local path=$(download_wallhaven_wallpaper "$url")
                    if [[ -n "$path" ]] && gum confirm "Apply now?"; then
                        SPECIFIC_WALLPAPER="$path" update_theme "specific"
                    fi
                else
                    gum style --foreground 196 "❌ Failed to fetch wallpaper"
                fi
                ;;
            *"General"*)
                gum spin --spinner globe --title "Fetching..." -- sleep 1
                local url=$(fetch_wallhaven_wallpaper "general")
                [[ -n "$url" ]] && download_wallhaven_wallpaper "$url" >/dev/null
                ;;
            *"Anime"*)
                gum spin --spinner globe --title "Fetching..." -- sleep 1
                local url=$(fetch_wallhaven_wallpaper "anime")
                [[ -n "$url" ]] && download_wallhaven_wallpaper "$url" >/dev/null
                ;;
            *"People"*)
                gum spin --spinner globe --title "Fetching..." -- sleep 1
                local url=$(fetch_wallhaven_wallpaper "people")
                [[ -n "$url" ]] && download_wallhaven_wallpaper "$url" >/dev/null
                ;;
            *"Settings"*)
                local cats
                cats=$(gum choose --no-limit "General" "Anime" "People")
                local c="000"
                [[ "$cats" == *"General"* ]] && c="${c:0:0}1${c:1:2}"
                [[ "$cats" == *"Anime"* ]] && c="${c:0:1}1${c:2:1}"
                [[ "$cats" == *"People"* ]] && c="${c:0:2}1"
                WALLHAVEN_CATEGORIES="$c"

                local res
                res=$(gum input --placeholder "Resolution" --value "$WALLHAVEN_RESOLUTION")
                [[ -n "$res" ]] && WALLHAVEN_RESOLUTION="$res"

                save_wallhaven_config
                ;;
            *"Clean"*)
                local days
                days=$(gum input --placeholder "Days" --value "$WALLHAVEN_CLEAN_DAYS")
                [[ -n "$days" ]] && clean_wallhaven_folder "$days"
                ;;
            *"Open Folder"*)
                xdg-open "$WALLHAVEN_DIR" 2>/dev/null || open "$WALLHAVEN_DIR" 2>/dev/null || true
                ;;
            *"Back"*)
                break
                ;;
        esac
    done
}

snapshot_gallery() {
    [[ ! -d "$SNAPSHOTS_DIR" ]] || [[ -z "$(ls -A "$SNAPSHOTS_DIR")" ]] && { print_warning "No snapshots"; return; }

    local snaps=()
    while IFS= read -r snap; do
        snaps+=("$(basename "$snap")")
    done < <(find "$SNAPSHOTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    while true; do
        local sel
        sel=$(gum choose --height=15 "${snaps[@]}" "↩️  Back")
        [[ "$sel" == "↩️  Back" ]] && break

        clear
        gum style --border double --margin "1" "Snapshot: $sel"

        local action
        action=$(gum choose "Load" "Delete" "Back")

        case "$action" in
            "Load")
                load_snapshot "$sel"
                gum confirm "Update now?" && update_theme "random"
                break
                ;;
            "Delete")
                gum confirm "Delete?" && {
                    rm -rf "${SNAPSHOTS_DIR:?}/${sel}"
                    snaps=("${snaps[@]/$sel}")
                }
                ;;
        esac
    done
}

# ==================== MAIN MENU FUNCTION ====================
gum_main_menu() {
    print_banner

    while true; do
        [[ "$AUTO_PROFILE_SWITCHING" == true ]] && check_and_switch_profile

        local prof_ind=""
        [[ "$CURRENT_THEME_PROFILE" != "default" ]] && prof_ind=" [Profile: ${CURRENT_THEME_PROFILE}]"

        local choice
        choice=$(gum choose \
            --header="🎨 My Theme Engine ${SCRIPT_VERSION}${prof_ind}" \
            --cursor="👉 " \
            --height=20 \
            "🌤️  Weather-based" \
            "⏰ Time-based" \
            "🎲 Random" \
            "🖼️  Select wallpaper" \
            "🌌 WallHaven" \
            "📸 Snapshots" \
            "👤 Profiles" \
            "🤖 Auto-rules" \
            "⚙️  Settings" \
            "👁️  Start watcher" \
            "🛑 Stop watcher" \
            "🔄 Run daemon" \
            "🛑 Stop daemon" \
            "🔧 Hooks" \
            "📦 Install deps" \
            "🎨 Show colors" \
            "🚀 Desktop entry" \
            "⚙️  Systemd service" \
            "🔄 Reset" \
            "🔍 Diagnostics" \
            "❌ Exit")

        case "$choice" in
            *"Weather"*)
                CITY=$(gum input --placeholder "City" --value "$CITY")
                FORCE_MODE=$(gum confirm "Force?" && echo true || echo false)
                update_theme "weather"
                ;;
            *"Time"*)
                FORCE_MODE=$(gum confirm "Force?" && echo true || echo false)
                update_theme "time"
                ;;
            *"Random"*)
                FORCE_MODE=$(gum confirm "Force?" && echo true || echo false)
                update_theme "random"
                ;;
            *"Select wallpaper"*)
                local dir="$WALLPAPER_DIR"
                [[ "$CURRENT_THEME_PROFILE" != "default" ]] && dir=$(get_profile_wallpaper_dir "$CURRENT_THEME_PROFILE")
                if ! has_wallpapers "$dir"; then
                    print_warning "No wallpapers found in $dir"
                    print_info "Use WallHaven to download some, or add your own!"
                    sleep 2
                    continue
                fi

                local -a files=("$dir"/*.{jpg,jpeg,png,bmp,gif})
                local -a valid_files=()
                for f in "${files[@]}"; do
                    [[ -f "$f" ]] && valid_files+=("$f")
                done

                if [[ ${#valid_files[@]} -eq 0 ]]; then
                    print_warning "No image files found in $dir"
                    continue
                fi

                local choices=()
                for f in "${valid_files[@]}"; do
                    choices+=("$(basename "$f")")
                done

                local selected_name
                selected_name=$(printf '%s\n' "${choices[@]}" | gum choose --height=20 --header="Select wallpaper:")
                if [[ -n "$selected_name" ]]; then
                    SPECIFIC_WALLPAPER="$dir/$selected_name" update_theme "specific"
                fi
                ;;
            *"WallHaven"*)
                wallhaven_menu
                ;;
            *"Snapshots"*)
                snapshot_gallery
                ;;
            *"Profiles"*)
                local act
                act=$(gum choose "Create" "Switch" "List" "Delete")
                case "$act" in
                    "Create")
                        local name=$(gum input --placeholder "Profile name")
                        [[ -n "$name" ]] && create_profile "$name"
                        ;;
                    "Switch")
                        local profs=("default")
                        [[ -d "$PROFILES_DIR" ]] && while IFS= read -r p; do profs+=("$(basename "$p")"); done < <(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d)
                        local to=$(printf '%s\n' "${profs[@]}" | gum choose)
                        [[ -n "$to" ]] && switch_profile "$to"
                        ;;
                    "List")
                        gum style "Current profile: $CURRENT_THEME_PROFILE"
                        [[ -d "$PROFILES_DIR" ]] && ls -1 "$PROFILES_DIR"
                        ;;
                    "Delete")
                        local to_del=$(ls -1 "$PROFILES_DIR" 2>/dev/null | gum choose)
                        [[ -n "$to_del" ]] && gum confirm "Delete?" && rm -rf "${PROFILES_DIR:?}/${to_del}"
                        ;;
                esac
                ;;
            *"Auto-rules"*)
                local act
                act=$(gum choose "Create rule" "List rules" "Delete rule" "Toggle auto")
                case "$act" in
                    "Create rule")
                        local name=$(gum input --placeholder "Rule name")
                        [[ -n "$name" ]] && create_profile_rule "$name"
                        ;;
                    "List rules")
                        [[ -d "$PROFILE_RULES_DIR" ]] && ls -1 "$PROFILE_RULES_DIR"
                        ;;
                    "Delete rule")
                        local to_del=$(ls -1 "$PROFILE_RULES_DIR" 2>/dev/null | gum choose)
                        [[ -n "$to_del" ]] && gum confirm "Delete?" && rm "${PROFILE_RULES_DIR:?}/${to_del}"
                        ;;
                    "Toggle auto")
                        AUTO_PROFILE_SWITCHING=$([[ "$AUTO_PROFILE_SWITCHING" == true ]] && echo false || echo true)
                        save_settings
                        ;;
                esac
                ;;
            *"Settings"*)
                CITY=$(gum input --placeholder "City" --value "$CITY")
                NIGHT_OVERRIDE=$(gum input --placeholder "Night hour" --value "$NIGHT_OVERRIDE")
                SATURATION_BOOST=$(gum input --placeholder "Saturation %" --value "$SATURATION_BOOST")
                NOTIFY_ERRORS=$(gum confirm "Notifications?" && echo true || echo false)
                TEMP_MONITORING=$(gum confirm "Temperature monitoring?" && echo true || echo false)
                save_settings
                ;;
            *"Start watcher"*)
                start_watcher
                read -n 1 -p "Press any key to stop..."
                stop_watcher
                ;;
            *"Stop watcher"*)
                stop_watcher
                ;;
            *"Run daemon"*)
                local int=$(gum input --placeholder "Interval (minutes)" --value "30")
                local mode=$(gum choose "weather" "time" "random")
                gum confirm "Start daemon?" && run_daemon "$int" "$mode"
                ;;
            *"Stop daemon"*)
                stop_daemon
                ;;
            *"Hooks"*)
                local act
                act=$(gum choose "List" "Create lockscreen" "Create preview" "Create spotify" "Create terminal color" "Edit" "Delete")
                case "$act" in
                    "List") ls -1 "$HOOKS_DIR" ;;
                    "Create lockscreen") create_lockscreen_hook ;;
                    "Create preview") create_terminal_preview_hook ;;
                    "Create spotify") create_spicetify_hook ;;
                    "Create terminal color") create_terminal_color_hook ;;
                    "Edit") ${EDITOR:-vim} "$HOOKS_DIR/$(ls -1 "$HOOKS_DIR" | gum choose)" ;;
                    "Delete") rm -f "$HOOKS_DIR/$(ls -1 "$HOOKS_DIR" | gum choose)" ;;
                esac
                ;;
            *"Install deps"*)
                install_dependencies
                ;;
            *"Show colors"*)
                if [[ -f "$COLOR_CACHE" ]]; then
                    cat "$COLOR_CACHE"
                elif [[ -f "$COLOR_CACHE_SH" ]]; then
                    cat "$COLOR_CACHE_SH"
                else
                    echo "No colors cached"
                fi
                ;;
            *"Desktop entry"*)
                create_desktop_entry
                ;;
            *"Systemd service"*)
                create_systemd_service
                ;;
            *"Reset"*)
                gum confirm "Reset all?" && reset_config
                ;;
            *"Diagnostics"*)
                self_test
                read -n 1 -p "Press any key..."
                ;;
            *"Exit"*)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
        esac

        echo
        sleep 1
    done
}

print_banner() {
    clear
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ███╗   ███╗██╗   ██╗    ████████╗██╗  ██╗███████╗███╗   ███╗███████╗       ║
║   ████╗ ████║╚██╗ ██╔╝    ╚══██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝       ║
║   ██╔████╔██║ ╚████╔╝        ██║   ███████║█████╗  ██╔████╔██║█████╗         ║
║   ██║╚██╔╝██║  ╚██╔╝         ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝         ║
║   ██║ ╚═╝ ██║   ██║          ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗       ║
║   ╚═╝     ╚═╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝       ║
║                                                                               ║
║                        Version v1.1.2 - Wael Isa                             ║
║                 PATH FIXED & WALLHAVEN WORKING                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# ==================== HELP ====================

show_help() {
    cat << EOF
my-theme.sh ${SCRIPT_VERSION} - Dynamic Wallpaper & System Theme Engine

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -h, --help              Show this help
    -v, --version           Show version
    -i, --interactive       Start interactive menu (default)
    -r, --random            Set random wallpaper
    -t, --time              Set time-based wallpaper
    -w, --weather           Set weather-based wallpaper
    -c, --city CITY         Set city for weather
    -f, --force             Force new wallpaper
    -p, --profile PROFILE   Switch profile
    -d, --daemon            Run as daemon
    --mode MODE             Daemon mode (random|weather|time)
    --interval MIN          Daemon interval (default: 30)
    -s, --set FILE          Set specific wallpaper
    --wallhaven [CAT]       Fetch from WallHaven
    --wallhaven-key KEY     Set API key
    --clean-wallhaven [DAYS] Clean old wallpapers
    --watch                 Start folder watcher
    --stop-watch            Stop watcher
    --stop                  Stop daemon
    --snapshot [NAME]       Save snapshot
    --load NAME             Load snapshot
    --list-snapshots        List snapshots
    --list-profiles         List profiles
    --list-hooks            List hooks
    --create-desktop        Create desktop entry
    --create-service        Create systemd service
    --install-deps          Install dependencies
    --reset-config          Reset configuration
    --diagnostic            Run self-test
    --debug                 Enable debug mode

EXAMPLES:
    $SCRIPT_NAME                    # Interactive menu
    $SCRIPT_NAME --weather --city "London"
    $SCRIPT_NAME --daemon --mode random --interval 30
    $SCRIPT_NAME --wallhaven anime
    $SCRIPT_NAME --diagnostic       # Test installation
EOF
}

# ==================== MAIN FUNCTION ====================
main() {
    local mode="random"
    local interval=30
    local interactive_mode=false
    local daemon_mode=false
    local specific_wallpaper=""
    local wallhaven_category=""

    # Load settings (this will fix WALLPAPER_DIR)
    load_settings

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--version) echo "my-theme.sh ${SCRIPT_VERSION}"; exit 0 ;;
            -i|--interactive) interactive_mode=true; shift ;;
            -r|--random) mode="random"; shift ;;
            -t|--time) mode="time"; shift ;;
            -w|--weather) mode="weather"; shift ;;
            -c|--city) CITY="$2"; save_settings; shift 2 ;;
            -f|--force) FORCE_MODE=true; shift ;;
            -p|--profile) switch_profile "$2" "no-update"; shift 2 ;;
            -d|--daemon) daemon_mode=true; shift ;;
            --mode) mode="$2"; shift 2 ;;
            --interval) interval="$2"; shift 2 ;;
            -s|--set) mode="specific"; specific_wallpaper="$2"; shift 2 ;;
            --wallhaven) wallhaven_category="${2:-random}"; shift 2 ;;
            --wallhaven-key) save_api_key "$2"; shift 2; exit 0 ;;
            --clean-wallhaven) clean_wallhaven_folder "$2"; shift 2; exit 0 ;;
            --watch) start_watcher; exit 0 ;;
            --stop-watch) stop_watcher; exit 0 ;;
            --stop) stop_daemon; exit 0 ;;
            --snapshot) save_snapshot "$2"; shift 2; exit 0 ;;
            --load) load_snapshot "$2"; shift 2; exit 0 ;;
            --list-snapshots) ls -1 "$SNAPSHOTS_DIR" 2>/dev/null || echo "No snapshots"; exit 0 ;;
            --list-profiles) ls -1 "$PROFILES_DIR" 2>/dev/null || echo "No profiles"; exit 0 ;;
            --list-hooks) ls -1 "$HOOKS_DIR" 2>/dev/null || echo "No hooks"; exit 0 ;;
            --create-desktop) create_desktop_entry; exit 0 ;;
            --create-service) create_systemd_service; exit 0 ;;
            --install-deps) install_dependencies; exit 0 ;;
            --reset-config) reset_config; exit 0 ;;
            --diagnostic) self_test; exit 0 ;;
            --debug) DEBUG=true; shift ;;
            *) print_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    # Export for functions
    export CITY
    export SPECIFIC_WALLPAPER="$specific_wallpaper"
    export FORCE_MODE

    # Create default hooks (never fail)
    create_lockscreen_hook 2>/dev/null || true
    create_terminal_preview_hook 2>/dev/null || true
    create_spicetify_hook 2>/dev/null || true
    create_terminal_color_hook 2>/dev/null || true

    # Handle interactive mode
    if [[ "$interactive_mode" == true ]]; then
        # Check for wallpapers and show notice if none found
        check_for_wallpapers

        if command -v gum >/dev/null 2>&1; then
            gum_main_menu
            exit 0
        else
            print_error "Gum is required for interactive mode"
            print_info "Install with: $0 --install-deps"
            exit 1
        fi
    fi

    # For non-interactive mode, check dependencies
    if ! command -v magick >/dev/null 2>&1; then
        print_error "ImageMagick not found. Run with --install-deps to install."
        exit 1
    fi

    # Run in appropriate mode
    if [[ "$daemon_mode" == true ]]; then
        run_daemon "$interval" "$mode"
    else
        update_theme "$mode"
    fi
}

# ==================== MASTER ENTRY POINT ====================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run auto-install on first start
    if [[ ! -f "$FIRST_RUN_FILE" ]] && [[ "$*" != *"--install-deps"* ]] && [[ "$*" != *"--help"* ]] && [[ "$*" != *"-h"* ]]; then
        auto_install
    fi

    # If no arguments, go to interactive mode
    if [[ $# -eq 0 ]]; then
        # Check if gum is installed
        if ! command -v gum >/dev/null 2>&1; then
            echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║     Gum not found - running auto-install...                     ║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
            auto_install
        fi
        main --interactive
    else
        main "$@"
    fi
fi
