#!/usr/bin/env bash

# my-theme.sh - Dynamic Wallpaper & System Theme Engine
# Version: v0.0.7
# Build Date: 02/24/2026
# Author: Wael Isa
# Website: https://www.wael.name
# GitHub: https://github.com/waelisa
#
# ██╗    ██╗ █████╗ ███████╗██╗         ██╗███████╗ █████╗
# ██║    ██║██╔══██╗██╔════╝██║         ██║██╔════╝██╔══██╗
# ██║ █╗ ██║███████║█████╗  ██║         ██║███████╗███████║
# ██║███╗██║██╔══██║██╔══╝  ██║         ██║╚════██║██╔══██║
# ╚███╔███╔╝██║  ██║███████╗███████╗    ██║███████╗██║  ██║
# ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝╚══════╝╚═╝  ╚═╝
#
# Description: Dynamic wallpaper and system theme engine with WallHaven integration,
#              lockscreen synchronization, and full Gum-based TUI.
#
# Features:
#   • Interactive menu by default (just run ./my-theme.sh)
#   • Lockscreen synchronization (betterlockscreen & hyprlock)
#   • WallHaven API integration with secure key storage
#   • Terminal image preview (Sixel/Kitty support)
#   • Systemd user service integration
#   • Desktop entry for app launcher
#   • API key management with password input
#   • Welcome banner with ASCII art
#   • Professional error handling with notifications
#
# Changelog:
#   v0.0.7 - Fixed silent exit, added lockscreen hooks, terminal preview,
#            API key security, desktop entry, systemd service
#   v0.0.6 - Added WallHaven integration, fixed silent exit, added wallpaper management
#   v0.0.5 - Added app-based profiles, deep sleep, color averaging, snapshot gallery
#   v0.0.4 - Added cross-browser support, theme profiles, color averaging
#   v0.0.3 - Added hooks system, debounced watcher, geo-location
#   v0.0.2 - Added smart fallback, caching, night override, aspect ratio check
#   v0.0.1 - Initial release
#
#############################################################################################################################

set -euo pipefail

# Script configuration
SCRIPT_VERSION="v0.0.7"
SCRIPT_NAME=$(basename "$0")
CONFIG_DIR="${HOME}/.config/my-theme"
CACHE_DIR="${HOME}/.cache/my-theme"
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
WALLHAVEN_DIR="${HOME}/Pictures/Wallpapers/WallHaven"
PROFILES_DIR="${CONFIG_DIR}/profiles"
PROFILE_RULES_DIR="${CONFIG_DIR}/profile-rules"
SNAPSHOTS_DIR="${CONFIG_DIR}/snapshots"
HOOKS_DIR="${CONFIG_DIR}/hooks"
WEATHER_CACHE="${CACHE_DIR}/weather.cache"
WEATHER_CACHE_AGE=900  # 15 minutes in seconds
COLOR_CACHE="${CACHE_DIR}/current_colors"
GRADIENCE_DIR="${CONFIG_DIR}/gradience"
LOG_FILE="${CACHE_DIR}/my-theme.log"
SETTINGS_FILE="${CONFIG_DIR}/settings.conf"
WATCH_PID_FILE="${CACHE_DIR}/watch.pid"
WATCH_DEBOUNCE=2  # Seconds to debounce folder events
CURRENT_PROFILE="${CACHE_DIR}/current_profile"
THUMBNAILS_DIR="${CACHE_DIR}/thumbnails"
BROWSER_CSS="${CACHE_DIR}/browser_shared.css"
LAST_ACTIVE_PROFILE="${CACHE_DIR}/last_active_profile"
WALLHAVEN_CONFIG="${CONFIG_DIR}/wallhaven.conf"
WALLHAVEN_CACHE="${CACHE_DIR}/wallhaven.cache"
WALLHAVEN_IMAGE_CACHE="${CACHE_DIR}/wallhaven_images"
API_KEY_FILE="${CONFIG_DIR}/api.key"
DESKTOP_ENTRY_DIR="${HOME}/.local/share/applications"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Default settings
CITY="${CITY:-}"
MONITOR_RESOLUTION=""
NIGHT_OVERRIDE="20"  # 8 PM
SATURATION_BOOST="120"  # 20% saturation boost
CONTRAST_STRETCH="2%x2%"  # Discard extreme pixels
ASPECT_RATIO_TOLERANCE="0.1"  # 10% tolerance
FORCE_MODE=false
BATTERY_AWARE=true
BATTERY_INTERVAL_MULTIPLIER=2  # Double interval on battery
BATTERY_DEEP_SLEEP_THRESHOLD=20  # Disable watcher below 20%
NOTIFY_ERRORS=true
CURRENT_THEME_PROFILE="default"
AUTO_PROFILE_SWITCHING=true
PROFILE_CHECK_INTERVAL=60  # Check every 60 seconds
TEMP_MONITORING=true
HIGH_TEMP_THRESHOLD=80  # Celsius - switch to gaming mode
USE_SIXEL=false  # Enable if terminal supports it
WALLHAVEN_API_KEY=""
WALLHAVEN_CATEGORIES="111"  # general:1, anime:1, people:1
WALLHAVEN_PURITY="100"  # sfw:1, sketchy:0, nsfw:0
WALLHAVEN_RESOLUTION="1920x1080"
WALLHAVEN_LIMIT=10  # Number of wallpapers to fetch
WALLHAVEN_AUTO_CLEAN=false  # Auto clean old wallpapers
WALLHAVEN_CLEAN_DAYS=30  # Delete wallpapers older than this

# Default color palette (fallback)
declare -a DEFAULT_COLORS=("#2E3440" "#88C0D0" "#A3BE8C" "#EBCB8B" "#D08770" "#B48EAD" "#8FBCBB" "#5E81AC")

# Ensure all directories exist
mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${GRADIENCE_DIR}" "${HOOKS_DIR}" \
         "${PROFILES_DIR}" "${PROFILE_RULES_DIR}" "${SNAPSHOTS_DIR}" \
         "${THUMBNAILS_DIR}" "${WALLHAVEN_DIR}" "${WALLHAVEN_IMAGE_CACHE}" \
         "${DESKTOP_ENTRY_DIR}" "${SYSTEMD_USER_DIR}"

# Print welcome banner
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
║                    ██████╗ ██╗███╗   ██╗███████╗                             ║
║                    ██╔══██╗██║████╗  ██║██╔════╝                             ║
║                    ██████╔╝██║██╔██╗ ██║█████╗                               ║
║                    ██╔══██╗██║██║╚██╗██║██╔══╝                               ║
║                    ██║  ██║██║██║ ╚████║███████╗                             ║
║                    ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝                             ║
║                                                                               ║
║                        Version ${SCRIPT_VERSION} - Wael Isa                     ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Error handling with notifications
error_exit() {
    log "ERROR: $1"

    # Send desktop notification if enabled
    if [[ "$NOTIFY_ERRORS" == true ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -t 5000 "Theme Engine Error" "$1"
    fi

    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Error: $1"
    else
        echo "❌ Error: $1"
    fi
    exit 1
}

# Send notification
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    log "NOTIFY: $title - $message"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -t 3000 "$title" "$message"
    fi
}

# Check if terminal supports Sixel/Kitty image protocol
check_image_support() {
    if [[ "$TERM" == *"kitty"* ]] || [[ "$TERM" == *"sixel"* ]]; then
        USE_SIXEL=true
        return 0
    fi

    # Check for Sixel support
    if command -v chafa >/dev/null 2>&1; then
        USE_SIXEL=true
        return 0
    fi

    return 1
}

# Load settings
load_settings() {
    if [[ -f "${SETTINGS_FILE}" ]]; then
        source "${SETTINGS_FILE}"
        log "Loaded settings from ${SETTINGS_FILE}"
    fi

    # Load current profile
    if [[ -f "${CURRENT_PROFILE}" ]]; then
        CURRENT_THEME_PROFILE=$(cat "${CURRENT_PROFILE}")
        log "Current profile: $CURRENT_THEME_PROFILE"
    fi

    # Load WallHaven config
    if [[ -f "${WALLHAVEN_CONFIG}" ]]; then
        source "${WALLHAVEN_CONFIG}"
        log "Loaded WallHaven configuration"
    fi

    # Load API key securely
    if [[ -f "${API_KEY_FILE}" ]]; then
        WALLHAVEN_API_KEY=$(cat "${API_KEY_FILE}" 2>/dev/null || echo "")
        log "Loaded API key"
    fi

    # Check image support
    check_image_support
}

# Save settings
save_settings() {
    cat > "${SETTINGS_FILE}" << EOF
# My Theme Settings
# Generated on $(date)

CITY="${CITY}"
WALLPAPER_DIR="${WALLPAPER_DIR}"
NIGHT_OVERRIDE="${NIGHT_OVERRIDE}"
SATURATION_BOOST="${SATURATION_BOOST}"
CONTRAST_STRETCH="${CONTRAST_STRETCH}"
FORCE_MODE="${FORCE_MODE}"
BATTERY_AWARE="${BATTERY_AWARE}"
BATTERY_INTERVAL_MULTIPLIER="${BATTERY_INTERVAL_MULTIPLIER}"
BATTERY_DEEP_SLEEP_THRESHOLD="${BATTERY_DEEP_SLEEP_THRESHOLD}"
NOTIFY_ERRORS="${NOTIFY_ERRORS}"
CURRENT_THEME_PROFILE="${CURRENT_THEME_PROFILE}"
AUTO_PROFILE_SWITCHING="${AUTO_PROFILE_SWITCHING}"
PROFILE_CHECK_INTERVAL="${PROFILE_CHECK_INTERVAL}"
TEMP_MONITORING="${TEMP_MONITORING}"
HIGH_TEMP_THRESHOLD="${HIGH_TEMP_THRESHOLD}"
EOF
    log "Settings saved to ${SETTINGS_FILE}"
}

# Save WallHaven config
save_wallhaven_config() {
    cat > "${WALLHAVEN_CONFIG}" << EOF
# WallHaven Configuration
# Generated on $(date)

WALLHAVEN_CATEGORIES="${WALLHAVEN_CATEGORIES}"
WALLHAVEN_PURITY="${WALLHAVEN_PURITY}"
WALLHAVEN_RESOLUTION="${WALLHAVEN_RESOLUTION}"
WALLHAVEN_LIMIT="${WALLHAVEN_LIMIT}"
WALLHAVEN_AUTO_CLEAN="${WALLHAVEN_AUTO_CLEAN}"
WALLHAVEN_CLEAN_DAYS="${WALLHAVEN_CLEAN_DAYS}"
EOF
    log "WallHaven config saved to ${WALLHAVEN_CONFIG}"
}

# Save API key securely
save_api_key() {
    local api_key="$1"
    echo "$api_key" > "${API_KEY_FILE}"
    chmod 600 "${API_KEY_FILE}"
    WALLHAVEN_API_KEY="$api_key"
    log "API key saved securely"
    notify "API Key" "WallHaven API key saved"
}

# Check if gum is available
if command -v gum >/dev/null 2>&1; then
    HAS_GUM=true
else
    HAS_GUM=false
fi

# Pretty print function
pretty_print() {
    if [[ "$HAS_GUM" == true ]]; then
        gum "$@"
    else
        echo "$*"
    fi
}

# Get battery percentage
get_battery_percentage() {
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        cat "/sys/class/power_supply/BAT0/capacity" 2>/dev/null || echo "100"
    elif command -v acpi >/dev/null 2>&1; then
        acpi -b | grep -o '[0-9]\+%' | tr -d '%' 2>/dev/null || echo "100"
    else
        echo "100"
    fi
}

# Check if on battery and deep sleep should activate
check_deep_sleep() {
    if [[ "$BATTERY_AWARE" != true ]]; then
        return 1
    fi

    local battery_percent
    battery_percent=$(get_battery_percentage)

    # Check if on battery and below threshold
    if command -v acpi >/dev/null 2>&1; then
        if acpi -b 2>/dev/null | grep -q "Discharging"; then
            if [[ $battery_percent -lt $BATTERY_DEEP_SLEEP_THRESHOLD ]]; then
                log "Deep sleep: Battery at ${battery_percent}% (threshold: ${BATTERY_DEEP_SLEEP_THRESHOLD}%)"
                return 0  # Deep sleep mode
            fi
        fi
    fi

    return 1  # Normal mode
}

# Get CPU temperature
get_cpu_temperature() {
    local temp=0

    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | cut -c1-2)
    elif command -v sensors >/dev/null 2>&1; then
        temp=$(sensors | grep -i "core 0" | awk '{print $3}' | tr -d '+°C' | cut -d. -f1)
    fi

    echo "${temp:-0}"
}

# Get monitor resolution
get_monitor_resolution() {
    if command -v xrandr >/dev/null 2>&1; then
        xrandr --current | grep '*' | head -1 | awk '{print $1}'
    elif command -v sway >/dev/null 2>&1; then
        swaymsg -t get_outputs | jq -r '.[0].current_mode | "\(.width)x\(.height)"'
    else
        echo "1920x1080"  # Default fallback
    fi
}

# Calculate aspect ratio
calculate_aspect_ratio() {
    local dimensions="$1"
    local width height

    if [[ "$dimensions" =~ ([0-9]+)x([0-9]+) ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
        echo "scale=4; $width / $height" | bc
    else
        echo "1.7778"  # 16:9 default
    fi
}

# Check if image aspect ratio matches monitor
check_aspect_ratio() {
    local image_path="$1"
    local image_dimensions
    local image_ratio monitor_ratio ratio_diff

    image_dimensions=$(magick identify -format "%wx%h" "$image_path" 2>/dev/null || echo "1920x1080")
    image_ratio=$(calculate_aspect_ratio "$image_dimensions")
    monitor_ratio=$(calculate_aspect_ratio "$MONITOR_RESOLUTION")

    ratio_diff=$(echo "scale=4; ($image_ratio - $monitor_ratio) / $monitor_ratio" | bc)
    ratio_diff="${ratio_diff#-}"  # Absolute value

    if (( $(echo "$ratio_diff <= $ASPECT_RATIO_TOLERANCE" | bc -l) )); then
        return 0  # Good match
    else
        return 1  # Poor match
    fi
}

# Get contrast color (for text)
get_contrast_color() {
    local hex=${1#\#}
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # Perceived luminance formula
    local luminance=$(( (r * 212) + (g * 715) + (b * 72) ))

    if [[ $luminance -gt 128000 ]]; then
        echo "#282a36"  # Dark for light backgrounds
    else
        echo "#f8f8f2"  # Light for dark backgrounds
    fi
}

# Advanced color darkening using ImageMagick
darken_color() {
    local color="$1"
    local percent="${2:-20}"  # Default 20% darker

    if command -v magick >/dev/null 2>&1; then
        magick xc:"$color" -fill black -colorize "${percent}%" -format "%[pixel:u.p{0,0}]" info: 2>/dev/null || echo "$color"
    else
        # Fallback to simple blending
        blend_color "$color" "black" "$((100 - percent))"
    fi
}

# Lighten color
lighten_color() {
    local color="$1"
    local percent="${2:-20}"  # Default 20% lighter

    if command -v magick >/dev/null 2>&1; then
        magick xc:"$color" -fill white -colorize "${percent}%" -format "%[pixel:u.p{0,0}]" info: 2>/dev/null || echo "$color"
    else
        # Fallback to simple blending
        blend_color "$color" "white" "$((100 - percent))"
    fi
}

# Blend color with black/white for better background
blend_color() {
    local hex="${1#\#}"
    local blend_with="$2"  # "black" or "white"
    local ratio="${3:-80}"  # 80% original, 20% blend by default

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    if [[ "$blend_with" == "black" ]]; then
        r=$(( (r * ratio + 0 * (100 - ratio)) / 100 ))
        g=$(( (g * ratio + 0 * (100 - ratio)) / 100 ))
        b=$(( (b * ratio + 0 * (100 - ratio)) / 100 ))
    else
        r=$(( (r * ratio + 255 * (100 - ratio)) / 100 ))
        g=$(( (g * ratio + 255 * (100 - ratio)) / 100 ))
        b=$(( (b * ratio + 255 * (100 - ratio)) / 100 ))
    fi

    printf "#%02x%02x%02x" "$r" "$g" "$b"
}

# Auto-detect city from IP
detect_city() {
    local city=""

    # Try ipinfo.io first
    if command -v curl >/dev/null 2>&1; then
        city=$(curl -s --max-time 3 ipinfo.io/city 2>/dev/null || echo "")
    fi

    # Fallback to ipapi.co
    if [[ -z "$city" ]] && command -v curl >/dev/null 2>&1; then
        city=$(curl -s --max-time 3 "ipapi.co/json" 2>/dev/null | jq -r '.city // empty' 2>/dev/null || echo "")
    fi

    echo "${city:-London}"  # Default to London if detection fails
}

# Fetch weather condition with caching and auto-detection
fetch_weather_condition() {
    local city="${1:-$CITY}"
    local weather_data=""
    local cache_age=0
    local condition="general"

    # Auto-detect city if not provided
    if [[ -z "$city" ]]; then
        city=$(detect_city)
        log "Auto-detected city: $city"
        CITY="$city"
        save_settings
    fi

    # Check cache
    if [[ -f "$WEATHER_CACHE" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            cache_age=$(($(date +%s) - $(stat -f %m "$WEATHER_CACHE")))
        else
            cache_age=$(($(date +%s) - $(stat -c %Y "$WEATHER_CACHE")))
        fi
    fi

    # Use cache if fresh
    if [[ $cache_age -lt $WEATHER_CACHE_AGE ]] && [[ -f "$WEATHER_CACHE" ]] && [[ "$FORCE_MODE" == false ]]; then
        weather_data=$(cat "$WEATHER_CACHE")
        log "Using cached weather data (${cache_age}s old)"
    else
        log "Fetching weather for ${city}..."
        weather_data=$(curl -s --max-time 5 "wttr.in/${city}?format=%C" 2>/dev/null || echo "")

        if [[ -n "$weather_data" ]] && [[ ! "$weather_data" =~ "Unknown" ]]; then
            echo "$weather_data" > "$WEATHER_CACHE"
            log "Weather data cached"
        elif [[ -f "$WEATHER_CACHE" ]]; then
            weather_data=$(cat "$WEATHER_CACHE")
            log "Weather API failed, using cached data"
        fi
    fi

    # Normalize weather condition
    if [[ -n "$weather_data" ]]; then
        # Convert to lowercase and get last word (for "Light rain" -> "rain")
        condition=$(echo "$weather_data" | tr '[:upper:]' '[:lower:]' | awk '{print $NF}')
    fi

    # Check for night override (unless force mode is on)
    if [[ "$FORCE_MODE" == false ]]; then
        local current_hour
        current_hour=$(date +%H)
        if [[ $current_hour -ge $NIGHT_OVERRIDE ]] || [[ $current_hour -lt 6 ]]; then
            log "Night override active (hour: $current_hour)"
            echo "night"
            return
        fi
    fi

    # Map to folder names
    case "$condition" in
        sunny|clear)              echo "clear" ;;
        rain|drizzle|shower)      echo "rainy" ;;
        cloudy|overcast)           echo "cloudy" ;;
        snow|blizzard|sleet)       echo "snowy" ;;
        fog|mist|haze)             echo "foggy" ;;
        thunder*|storm)            echo "stormy" ;;
        *)                         echo "general" ;;
    esac
}

# Detect running apps and determine profile
detect_profile_from_apps() {
    local -A app_profiles=()
    local detected_profile=""

    # Load profile rules
    if [[ -d "$PROFILE_RULES_DIR" ]]; then
        for rule_file in "$PROFILE_RULES_DIR"/*.conf; do
            if [[ -f "$rule_file" ]]; then
                source "$rule_file"
                # Rule files should define: APP_PATTERN and PROFILE_NAME
                if [[ -n "${APP_PATTERN:-}" ]] && [[ -n "${PROFILE_NAME:-}" ]]; then
                    app_profiles["$APP_PATTERN"]="$PROFILE_NAME"
                fi
            fi
        done
    fi

    # Default rules (can be overridden by user rules)
    app_profiles["code"]="work"
    app_profiles["idea"]="work"
    app_profiles["pycharm"]="work"
    app_profiles["steam"]="gaming"
    app_profiles["hl2_linux"]="gaming"
    app_profiles["spotify"]="relax"
    app_profiles["firefox"]="web"
    app_profiles["chrome"]="web"

    # Check temperature for gaming mode
    if [[ "$TEMP_MONITORING" == true ]]; then
        local current_temp
        current_temp=$(get_cpu_temperature)
        if [[ $current_temp -gt $HIGH_TEMP_THRESHOLD ]]; then
            log "High temperature detected (${current_temp}°C), switching to gaming profile"
            echo "gaming"
            return
        fi
    fi

    # Check running processes
    for pattern in "${!app_profiles[@]}"; do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            detected_profile="${app_profiles[$pattern]}"
            log "Detected app: $pattern -> profile: $detected_profile"
            break
        fi
    done

    echo "${detected_profile:-default}"
}

# Auto-switch profile based on running apps
check_and_switch_profile() {
    if [[ "$AUTO_PROFILE_SWITCHING" != true ]]; then
        return
    fi

    local detected_profile
    detected_profile=$(detect_profile_from_apps)

    # Save last active profile for comparison
    if [[ -f "$LAST_ACTIVE_PROFILE" ]]; then
        local last_profile
        last_profile=$(cat "$LAST_ACTIVE_PROFILE")
        if [[ "$last_profile" == "$detected_profile" ]]; then
            return  # No change
        fi
    fi

    if [[ "$detected_profile" != "default" ]] && [[ "$detected_profile" != "$CURRENT_THEME_PROFILE" ]]; then
        log "Auto-switching to profile: $detected_profile"
        notify "Profile Switch" "Auto-switched to $detected_profile profile"
        switch_profile "$detected_profile" "no-update"
        echo "$detected_profile" > "$LAST_ACTIVE_PROFILE"
        # Trigger theme update with new profile
        update_theme "random"
    fi
}

# Get profile wallpaper directory
get_profile_wallpaper_dir() {
    local profile="$1"
    local profile_dir="${PROFILES_DIR}/${profile}"

    if [[ -f "${profile_dir}/wallpaper_dir.txt" ]]; then
        cat "${profile_dir}/wallpaper_dir.txt"
    else
        echo "$WALLPAPER_DIR"
    fi
}

# Smart wallpaper selection with fallback
select_wallpaper() {
    local condition="$1"
    local wallpaper_dir="$WALLPAPER_DIR"

    # Check if using a profile with custom wallpaper dir
    if [[ "$CURRENT_THEME_PROFILE" != "default" ]]; then
        wallpaper_dir=$(get_profile_wallpaper_dir "$CURRENT_THEME_PROFILE")
        log "Using profile wallpaper directory: $wallpaper_dir"
    fi

    local target_dir="${wallpaper_dir}/${condition}"
    local selected=""
    local fallback_used=false

    log "Selecting wallpaper for condition: $condition (force mode: $FORCE_MODE)"

    # In force mode, always pick random from main directory
    if [[ "$FORCE_MODE" == true ]]; then
        log "Force mode active, picking random wallpaper"
        selected=$(find "$wallpaper_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | shuf -n 1)
        echo "$selected"
        return
    fi

    # Try specific subfolder first
    if [[ -d "$target_dir" ]] && [[ -n "$(ls -A "$target_dir" 2>/dev/null)" ]]; then
        if [[ "$HAS_GUM" == true ]]; then
            gum spin --spinner dot --title "Looking in ${condition} folder..." -- sleep 0.5
        fi

        # Find images and check aspect ratio
        while IFS= read -r img; do
            if check_aspect_ratio "$img"; then
                selected="$img"
                log "Found aspect-ratio matched wallpaper: $img"
                break
            fi
        done < <(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | shuf)

        # If no aspect ratio match, just take any
        if [[ -z "$selected" ]]; then
            selected=$(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | shuf -n 1)
            log "No aspect ratio match, using any image from ${condition} folder"
        fi
    fi

    # Fallback to main directory
    if [[ -z "$selected" ]]; then
        fallback_used=true
        log "Folder '${condition}' not found or empty, falling back to main directory"

        if [[ "$HAS_GUM" == true ]]; then
            gum style --foreground 214 "⚠️  Folder '${condition}' not found, using main wallpaper directory"
        fi

        selected=$(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | shuf -n 1)
    fi

    echo "$selected"
}

# Extract colors from wallpaper (with enhanced processing)
extract_colors() {
    local wallpaper="$1"
    local num_colors="${2:-8}"
    local -a colors=()

    if [[ ! -f "$wallpaper" ]]; then
        log "Wallpaper not found: $wallpaper"
        printf '%s\n' "${DEFAULT_COLORS[@]}"
        return
    fi

    log "Extracting colors from wallpaper with enhanced processing..."

    # Extract colors with:
    # - Contrast stretch (discard extreme pixels)
    # - Saturation boost for vibrancy
    # - Unique colors extraction
    mapfile -t colors < <(magick "$wallpaper" \
        -contrast-stretch "${CONTRAST_STRETCH}" \
        -modulate 100,${SATURATION_BOOST} \
        +dither \
        -colors "$num_colors" \
        -unique-colors txt: 2>/dev/null | \
        grep -E -o "#[0-9A-Fa-f]{6}")

    # Fallback to defaults if extraction failed
    if [[ ${#colors[@]} -lt 3 ]]; then
        log "Color extraction failed, using defaults"
        printf '%s\n' "${DEFAULT_COLORS[@]}"
    else
        printf '%s\n' "${colors[@]}"
    fi
}

# Create thumbnail for snapshot
create_thumbnail() {
    local wallpaper="$1"
    local snapshot_name="$2"
    local thumbnail_path="${THUMBNAILS_DIR}/${snapshot_name}.jpg"

    if [[ -f "$wallpaper" ]] && command -v magick >/dev/null 2>&1; then
        magick "$wallpaper" -resize 200x200^ -gravity center -extent 200x200 "$thumbnail_path" 2>/dev/null
        echo "$thumbnail_path"
    fi
}

# Display thumbnail in terminal (if supported)
display_thumbnail() {
    local thumbnail_path="$1"

    if [[ ! -f "$thumbnail_path" ]]; then
        return
    fi

    if [[ "$USE_SIXEL" == true ]]; then
        if command -v chafa >/dev/null 2>&1; then
            chafa "$thumbnail_path" --size=20x20
        elif command -v img2sixel >/dev/null 2>&1; then
            img2sixel "$thumbnail_path"
        fi
    fi
}

# Generate Gradience preset
generate_gradience_preset() {
    local -a colors=("$@")
    local bg_color="${colors[0]}"
    local muted_bg
    muted_bg=$(darken_color "$bg_color" 15)  # 15% darker for GTK

    local preset_file="${GRADIENCE_DIR}/my-theme.json"

    cat > "$preset_file" << EOF
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
    "window_bg_color": "${muted_bg}",
    "view_bg_color": "${muted_bg}"
  }
}
EOF

    log "Gradience preset generated: $preset_file"

    # Apply if Gradience CLI is available
    if command -v gradience-cli >/dev/null 2>&1; then
        gradience-cli apply -p "$preset_file" 2>/dev/null || true
        log "Applied Gradience preset"
    fi
}

# Universal wallpaper setter
set_wallpaper() {
    local wall_path="$1"
    local de="${XDG_CURRENT_DESKTOP:-}"
    local session_type="${XDG_SESSION_TYPE:-x11}"

    log "Setting wallpaper (DE: $de, Session: $session_type)"

    if [[ ! -f "$wall_path" ]]; then
        error_exit "Wallpaper not found: $wall_path"
    fi

    case "$de" in
        *GNOME*|*Unity*|*Cinnamon*)
            gsettings set org.gnome.desktop.background picture-uri "file://$wall_path" 2>/dev/null || true
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wall_path" 2>/dev/null || true
            ;;
        *KDE*|*Plasma*)
            if command -v qdbus >/dev/null 2>&1; then
                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
                    "var allDesktops = desktops(); for (var i=0; i<allDesktops.length; i++) { d = allDesktops[i]; d.currentConfigGroup = Array('Wallpapers', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$wall_path'); }" 2>/dev/null || true
            fi
            ;;
        *XFCE*)
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$wall_path" 2>/dev/null || true
            ;;
        *sway*|*Hyprland*|*Wayland*)
            if command -v swww >/dev/null 2>&1; then
                # Ensure swww daemon is running
                if ! pgrep -x "swww-daemon" >/dev/null; then
                    swww-daemon &
                    sleep 1
                fi
                # Animated transition
                swww img "$wall_path" \
                    --transition-fps 60 \
                    --transition-type grow \
                    --transition-pos 0.9,0.9 \
                    --transition-duration 2 2>/dev/null || true
            elif command -v swaybg >/dev/null 2>&1; then
                pkill swaybg 2>/dev/null || true
                swaybg -i "$wall_path" -m fill &
            fi
            ;;
        *)
            # Fallback for X11 WMs
            if command -v feh >/dev/null 2>&1; then
                feh --bg-fill "$wall_path" 2>/dev/null || true
            elif command -v nitrogen >/dev/null 2>&1; then
                nitrogen --set-zoom-fill "$wall_path" 2>/dev/null || true
            else
                log "No supported wallpaper setter found"
                return 1
            fi
            ;;
    esac

    log "Wallpaper set successfully"
}

# Update terminal colors
update_terminal_colors() {
    local -a colors=("$@")
    local bg_color="${colors[0]}"
    local fg_color
    fg_color=$(get_contrast_color "$bg_color")

    # Create muted backgrounds for terminals
    local muted_bg
    muted_bg=$(darken_color "$bg_color" 20)  # 20% darker for terminal

    # Save to cache (for hooks to use)
    {
        echo "BG=$bg_color"
        echo "FG=$fg_color"
        echo "MUTED_BG=$muted_bg"
        echo "SELECTED_WALL=$CURRENT_WALLPAPER"
        for i in "${!colors[@]}"; do
            echo "COLOR$i=${colors[$i]}"
        done
        echo "TIMESTAMP=$(date +%s)"
        echo "PROFILE=$CURRENT_THEME_PROFILE"
    } > "$COLOR_CACHE"

    log "Updating terminal colors..."

    # Xresources
    if [[ -f "${HOME}/.Xresources" ]]; then
        local xresources_backup="${HOME}/.Xresources.bak"
        cp "${HOME}/.Xresources" "$xresources_backup"

        sed -i "s/^.*foreground:.*/*.foreground: ${fg_color}/g" "${HOME}/.Xresources" 2>/dev/null || true
        sed -i "s/^.*background:.*/*.background: ${muted_bg}/g" "${HOME}/.Xresources" 2>/dev/null || true

        for i in {0..15}; do
            if [[ $i -lt ${#colors[@]} ]]; then
                sed -i "s/^.*color${i}:.*/*.color${i}: ${colors[$i]}/g" "${HOME}/.Xresources" 2>/dev/null || true
            fi
        done

        if command -v xrdb >/dev/null 2>&1; then
            xrdb -merge "${HOME}/.Xresources" 2>/dev/null || true
        fi
    fi

    # Kitty
    if [[ -d "${HOME}/.config/kitty" ]]; then
        local kitty_conf="${HOME}/.config/kitty/theme.conf"
        {
            echo "# Generated by my-theme.sh on $(date)"
            echo "background $muted_bg"
            echo "foreground $fg_color"
            for i in {0..15}; do
                [[ $i -lt ${#colors[@]} ]] && echo "color$i ${colors[$i]}"
            done
        } > "$kitty_conf"

        pgrep -x "kitty" >/dev/null && kill -SIGUSR1 $(pgrep -x "kitty") 2>/dev/null || true
    fi

    # Alacritty
    if [[ -d "${HOME}/.config/alacritty" ]]; then
        local alacritty_conf="${HOME}/.config/alacritty/colors.toml"
        {
            echo "# Generated by my-theme.sh on $(date)"
            echo "[colors.primary]"
            echo "background = '$muted_bg'"
            echo "foreground = '$fg_color'"
            echo ""
            echo "[colors.normal]"
            for i in {0..7}; do
                [[ $i -lt ${#colors[@]} ]] && echo "  color$i = '${colors[$i]}'"
            done
            echo ""
            echo "[colors.bright]"
            for i in {8..15}; do
                [[ $((i-8)) -lt ${#colors[@]} ]] && echo "  color$((i-8)) = '${colors[$((i-8))]}'"
            done
        } > "$alacritty_conf"
    fi

    log "Terminal colors updated"
}

# Update browser themes with shared CSS
update_browser_themes() {
    local -a colors=("$@")
    local bg_color="${colors[0]}"
    local fg_color
    fg_color=$(get_contrast_color "$bg_color")
    local accent_color="${colors[2]}"
    local muted_bg
    muted_bg=$(darken_color "$bg_color" 15)

    log "Updating browser themes..."

    # Create shared CSS file for all browsers
    cat > "$BROWSER_CSS" << EOF
/* Generated by my-theme.sh v${SCRIPT_VERSION} */
:root {
    --theme-bg: ${bg_color};
    --theme-fg: ${fg_color};
    --theme-accent: ${accent_color};
    --theme-surface: ${muted_bg};
    --theme-color0: ${colors[0]};
    --theme-color1: ${colors[1]};
    --theme-color2: ${colors[2]};
    --theme-color3: ${colors[3]};
    --theme-color4: ${colors[4]};
    --theme-color5: ${colors[5]};
    --theme-timestamp: ${TIMESTAMP:-$(date +%s)};
}
EOF

    # Firefox
    local firefox_profiles="${HOME}/.mozilla/firefox"
    if [[ -d "$firefox_profiles" ]]; then
        for profile in "$firefox_profiles"/*.default*; do
            if [[ -d "$profile/chrome" ]]; then
                local firefox_css="${profile}/chrome/colors.css"
                # Create import file for Firefox
                echo "@import \"${BROWSER_CSS}\";" > "$firefox_css"
                log "Updated Firefox theme for profile: $(basename "$profile")"
            fi
        done
    fi

    # Chrome/Chromium based browsers
    local chrome_configs=(
        "${HOME}/.config/google-chrome"
        "${HOME}/.config/chromium"
        "${HOME}/.config/brave-browser"
        "${HOME}/.config/microsoft-edge"
        "${HOME}/.config/vivaldi"
    )

    for browser_config in "${chrome_configs[@]}"; do
        if [[ -d "$browser_config" ]]; then
            local chrome_custom_css="${browser_config}/Default/User StyleSheets/Custom.css"
            mkdir -p "$(dirname "$chrome_custom_css")"

            # Create import for Chrome-based browsers
            echo "/* Import theme colors */" > "$chrome_custom_css"
            echo "@import url('file://${BROWSER_CSS}');" >> "$chrome_custom_css"

            log "Updated theme for: $(basename "$browser_config")"
        fi
    done

    notify "Browser Themes" "Updated browser color schemes"
}

# Create lockscreen hook (ultimate masterpiece)
create_lockscreen_hook() {
    local hook_file="${HOOKS_DIR}/99-lockscreen.sh"

    if [[ ! -f "$hook_file" ]]; then
        cat > "$hook_file" << 'EOF'
#!/usr/bin/env bash

# Ultimate Lockscreen Synchronization Hook
# This runs after every theme update to sync your lockscreen

CACHE_FILE="$HOME/.cache/my-theme/current_colors"
[[ -f "$CACHE_FILE" ]] && source "$CACHE_FILE"

# For X11 with betterlockscreen
if command -v betterlockscreen >/dev/null 2>&1; then
    if [[ -n "$SELECTED_WALL" ]] && [[ -f "$SELECTED_WALL" ]]; then
        betterlockscreen -u "$SELECTED_WALL" --blur 0.5 &
        echo "betterlockscreen updated"
    fi
fi

# For Wayland with hyprlock
if [[ -d "$HOME/.config/hypr" ]]; then
    HYPR_VARS="$HOME/.config/hypr/theme_vars.conf"
    mkdir -p "$(dirname "$HYPR_VARS")"

    # Create theme variables for hyprlock
    {
        echo "# Generated by my-theme.sh - $(date)"
        echo "\$accent = rgb(${COLOR2#\#})"
        echo "\$bg = rgb(${BG#\#})"
        echo "\$fg = rgb(${FG#\#})"
        echo "\$muted = rgb(${MUTED_BG#\#})"
        echo "\$wallpaper = $SELECTED_WALL"
    } > "$HYPR_VARS"

    echo "hyprlock theme variables updated"
fi

# For SDDM (KDE Login Manager)
if [[ -d "/etc/sddm.conf.d" ]] && command -v sddm-greeter-qt6 >/dev/null 2>&1; then
    SDDM_THEME_DIR="/usr/share/sddm/themes/my-theme"
    if [[ -d "$SDDM_THEME_DIR" ]] && [[ -f "$SELECTED_WALL" ]]; then
        cp "$SELECTED_WALL" "$SDDM_THEME_DIR/background.jpg" 2>/dev/null || true
        echo "SDDM wallpaper updated (requires root for permanent change)"
    fi
fi

# For LightDM
if [[ -d "/etc/lightdm" ]] && command -v lightdm >/dev/null 2>&1; then
    LIGHTDM_BG="/usr/share/backgrounds/my-theme-wallpaper.jpg"
    if [[ -f "$SELECTED_WALL" ]] && [[ -w "$(dirname "$LIGHTDM_BG")" ]]; then
        cp "$SELECTED_WALL" "$LIGHTDM_BG" 2>/dev/null || true
        echo "LightDM wallpaper updated"
    fi
fi

echo "Lockscreen synchronization complete"
EOF
        chmod +x "$hook_file"
        log "Created lockscreen hook (ultimate masterpiece)"
    fi
}

# Create terminal preview hook
create_terminal_preview_hook() {
    local hook_file="${HOOKS_DIR}/98-terminal-preview.sh"

    if [[ ! -f "$hook_file" ]] && command -v chafa >/dev/null 2>&1; then
        cat > "$hook_file" << 'EOF'
#!/usr/bin/env bash

# Terminal Preview Hook
# Shows a small preview of the new wallpaper in supported terminals

CACHE_FILE="$HOME/.cache/my-theme/current_colors"
[[ -f "$CACHE_FILE" ]] && source "$CACHE_FILE"

# Only run in Kitty or terminals with Sixel support
if [[ "$TERM" == *"kitty"* ]] || [[ "$TERM" == *"sixel"* ]]; then
    if [[ -n "$SELECTED_WALL" ]] && [[ -f "$SELECTED_WALL" ]]; then
        echo
        echo "📸 Wallpaper Preview:"
        if command -v chafa >/dev/null 2>&1; then
            chafa "$SELECTED_WALL" --size=40x20
        elif command -v img2sixel >/dev/null 2>&1; then
            img2sixel "$SELECTED_WALL"
        fi
        echo
    fi
fi
EOF
        chmod +x "$hook_file"
        log "Created terminal preview hook"
    fi
}

# Create Spicetify hook
create_spicetify_hook() {
    local hook_file="${HOOKS_DIR}/update_spotify.sh"

    if [[ ! -f "$hook_file" ]]; then
        cat > "$hook_file" << 'EOF'
#!/usr/bin/env bash

# Spicetify Spotify theme updater
CACHE_FILE="$HOME/.cache/my-theme/current_colors"
[[ -f "$CACHE_FILE" ]] && source "$CACHE_FILE"

SPICETIFY_THEME_DIR="$HOME/.config/spicetify/Themes/MyTheme"

if command -v spicetify >/dev/null 2>&1; then
    # Create theme if it doesn't exist
    if [[ ! -d "$SPICETIFY_THEME_DIR" ]]; then
        mkdir -p "$SPICETIFY_THEME_DIR"
    fi

    # Generate color.ini
    cat > "$SPICETIFY_THEME_DIR/color.ini" << INI
[Base]
main_bg = ${BG#\#}
main_fg = ${FG#\#}
accent = ${COLOR2#\#}
text = ${COLOR3#\#}
button = ${COLOR4#\#}
button_active = ${COLOR5#\#}
tab_active = ${COLOR2#\#}
notification = ${COLOR1#\#}
notification_error = ${COLOR1#\#}
playback_bar = ${COLOR2#\#}
misc = ${COLOR0#\#}
INI

    # Apply theme
    spicetify config current_theme MyTheme
    spicetify apply -quiet
    echo "Spotify theme updated"
fi
EOF
        chmod +x "$hook_file"
        log "Created Spicetify hook"
    fi
}

# Execute external hooks
run_hooks() {
    local hooks_dir="${HOOKS_DIR}"

    # Ensure the directory exists
    if [[ ! -d "$hooks_dir" ]]; then
        mkdir -p "$hooks_dir"
        log "Created hooks directory: $hooks_dir"
        return
    fi

    # Find and execute all executable files in the hooks folder
    if [[ -n "$(ls -A "$hooks_dir" 2>/dev/null)" ]]; then
        log "Running post-theme hooks..."
        local hook_count=0

        for hook in "$hooks_dir"/*; do
            if [[ -x "$hook" ]] && [[ ! -d "$hook" ]]; then
                log "Executing hook: $(basename "$hook")"
                # Run in background to prevent blocking
                "$hook" > "${CACHE_DIR}/hook_$(basename "$hook").log" 2>&1 &
                ((hook_count++))
            fi
        done

        log "Started $hook_count hook(s) in background"

        if [[ "$HAS_GUM" == true ]] && [[ $hook_count -gt 0 ]]; then
            gum style --foreground 42 "✅ Started $hook_count hook(s)"
        fi

        if [[ $hook_count -gt 0 ]]; then
            notify "Theme Hooks" "Started $hook_count background hooks"
        fi
    fi
}

# Fetch random wallpaper from WallHaven
fetch_wallhaven_wallpaper() {
    local category="$1"
    local api_url="https://wallhaven.cc/api/v1/search"
    local params=""

    # Build API parameters based on category
    case "$category" in
        "general")
            params="categories=111&purity=100"
            ;;
        "anime")
            params="categories=010&purity=100"
            ;;
        "people")
            params="categories=001&purity=100"
            ;;
        "random")
            params="categories=${WALLHAVEN_CATEGORIES}&purity=${WALLHAVEN_PURITY}"
            ;;
        *)
            params="categories=${WALLHAVEN_CATEGORIES}&purity=${WALLHAVEN_PURITY}"
            ;;
    esac

    # Add API key if available
    if [[ -n "$WALLHAVEN_API_KEY" ]]; then
        params="${params}&apikey=${WALLHAVEN_API_KEY}"
    fi

    # Add resolution filter
    if [[ -n "$WALLHAVEN_RESOLUTION" ]]; then
        params="${params}&resolutions=${WALLHAVEN_RESOLUTION}"
    fi

    # Add sorting (random)
    params="${params}&sorting=random&limit=${WALLHAVEN_LIMIT}"

    log "Fetching WallHaven wallpapers with params: $params"

    # Make API request
    local response
    response=$(curl -s "${api_url}?${params}")

    # Parse response and extract image URLs
    local image_urls
    mapfile -t image_urls < <(echo "$response" | jq -r '.data[].path // empty' 2>/dev/null)

    if [[ ${#image_urls[@]} -eq 0 ]]; then
        log "No wallpapers found from WallHaven"
        return 1
    fi

    # Select random image from results
    local selected_url="${image_urls[$RANDOM % ${#image_urls[@]}]}"

    if [[ -z "$selected_url" ]]; then
        log "Failed to select wallpaper URL"
        return 1
    fi

    log "Selected WallHaven wallpaper: $selected_url"
    echo "$selected_url"
}

# Download WallHaven wallpaper
download_wallhaven_wallpaper() {
    local image_url="$1"
    local filename=$(basename "$image_url")
    local local_path="${WALLHAVEN_DIR}/${filename}"
    local temp_path="${WALLHAVEN_IMAGE_CACHE}/${filename}"

    # Check if already downloaded
    if [[ -f "$local_path" ]]; then
        log "Wallpaper already exists: $local_path"
        echo "$local_path"
        return 0
    fi

    log "Downloading wallpaper from: $image_url"

    # Download to temp location first
    if curl -L -s --max-time 30 "$image_url" -o "$temp_path"; then
        # Verify it's a valid image
        if magick identify "$temp_path" >/dev/null 2>&1; then
            mv "$temp_path" "$local_path"
            log "Downloaded: $local_path"
            echo "$local_path"
            return 0
        else
            log "Downloaded file is not a valid image"
            rm -f "$temp_path"
        fi
    else
        log "Failed to download wallpaper"
    fi

    return 1
}

# Clean old WallHaven wallpapers
clean_wallhaven_folder() {
    local days="${1:-$WALLHAVEN_CLEAN_DAYS}"

    if [[ ! -d "$WALLHAVEN_DIR" ]]; then
        log "WallHaven directory does not exist"
        return
    fi

    log "Cleaning WallHaven wallpapers older than $days days"

    local count=0
    local size_before=$(du -sh "$WALLHAVEN_DIR" | cut -f1)

    # Find and delete old files
    while IFS= read -r file; do
        rm -f "$file"
        ((count++))
    done < <(find "$WALLHAVEN_DIR" -type f -mtime +"$days" 2>/dev/null)

    local size_after=$(du -sh "$WALLHAVEN_DIR" | cut -f1)

    log "Cleaned $count files (Size: $size_before → $size_after)"

    if [[ $count -gt 0 ]]; then
        notify "WallHaven Cleanup" "Removed $count old wallpapers"
    fi
}

# Save theme snapshot
save_snapshot() {
    local snapshot_name="$1"
    local snapshot_dir="${SNAPSHOTS_DIR}/${snapshot_name}"

    if [[ -z "$snapshot_name" ]]; then
        snapshot_name="snapshot_$(date +%Y%m%d_%H%M%S)"
        snapshot_dir="${SNAPSHOTS_DIR}/${snapshot_name}"
    fi

    mkdir -p "$snapshot_dir"

    # Save current colors
    if [[ -f "$COLOR_CACHE" ]]; then
        cp "$COLOR_CACHE" "$snapshot_dir/colors.txt"
    fi

    # Save settings
    cp "$SETTINGS_FILE" "$snapshot_dir/settings.conf" 2>/dev/null || true

    # Save current wallpaper path and create thumbnail
    if [[ -n "${CURRENT_WALLPAPER:-}" ]] && [[ -f "$CURRENT_WALLPAPER" ]]; then
        cp "$CURRENT_WALLPAPER" "$snapshot_dir/wallpaper.jpg" 2>/dev/null || true
        echo "$CURRENT_WALLPAPER" > "$snapshot_dir/wallpaper_path.txt"
        create_thumbnail "$CURRENT_WALLPAPER" "$snapshot_name"
    fi

    log "Saved snapshot: $snapshot_name"
    notify "Theme Snapshot" "Saved as: $snapshot_name"
    echo "$snapshot_name"
}

# Load theme snapshot
load_snapshot() {
    local snapshot_name="$1"
    local snapshot_dir="${SNAPSHOTS_DIR}/${snapshot_name}"

    if [[ ! -d "$snapshot_dir" ]]; then
        error_exit "Snapshot not found: $snapshot_name"
    fi

    # Load colors
    if [[ -f "$snapshot_dir/colors.txt" ]]; then
        cp "$snapshot_dir/colors.txt" "$COLOR_CACHE"
        source "$COLOR_CACHE"
    fi

    # Load settings
    if [[ -f "$snapshot_dir/settings.conf" ]]; then
        cp "$snapshot_dir/settings.conf" "$SETTINGS_FILE"
        load_settings
    fi

    # Load wallpaper
    if [[ -f "$snapshot_dir/wallpaper.jpg" ]]; then
        CURRENT_WALLPAPER="$snapshot_dir/wallpaper.jpg"
    elif [[ -f "$snapshot_dir/wallpaper_path.txt" ]]; then
        CURRENT_WALLPAPER=$(cat "$snapshot_dir/wallpaper_path.txt")
    fi

    log "Loaded snapshot: $snapshot_name"
    notify "Theme Snapshot" "Loaded: $snapshot_name"
}

# Debounced folder watcher
start_watcher() {
    if ! command -v inotifywait >/dev/null 2>&1; then
        log "inotifywait not found. Please install inotify-tools."
        return 1
    fi

    # Check deep sleep mode
    if check_deep_sleep; then
        log "Deep sleep mode active - not starting watcher"
        notify "Deep Sleep" "Watcher disabled to save battery"
        return 0
    fi

    log "Starting debounced folder watcher on $WALLPAPER_DIR"

    # Kill existing watcher if running
    if [[ -f "$WATCH_PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$WATCH_PID_FILE")
        kill "$old_pid" 2>/dev/null || true
        rm "$WATCH_PID_FILE"
        sleep 1
    fi

    # Start watcher in background with debounce
    (
        local last_trigger=0

        while true; do
            # Check deep sleep periodically
            if check_deep_sleep; then
                log "Deep sleep activated - stopping watcher"
                exit 0
            fi

            # Wait for file system events
            inotifywait -q -e create -e delete -e move -e modify "$WALLPAPER_DIR" 2>/dev/null

            current_time=$(date +%s)
            time_diff=$((current_time - last_trigger))

            # Debounce: only trigger if last trigger was more than WATCH_DEBOUNCE seconds ago
            if [[ $time_diff -gt $WATCH_DEBOUNCE ]]; then
                log "Wallpaper directory changed, updating theme (debounced)..."
                # Run update in background to not block watcher
                (
                    # Save current FORCE_MODE and override for watcher
                    OLD_FORCE_MODE="$FORCE_MODE"
                    FORCE_MODE=true  # Force random on folder changes
                    update_theme "random"
                    FORCE_MODE="$OLD_FORCE_MODE"
                ) &
                last_trigger=$current_time
            else
                log "Debounced: ignoring rapid event (last trigger ${time_diff}s ago)"
            fi
        done
    ) &

    echo $! > "$WATCH_PID_FILE"
    log "Debounced watcher started with PID: $(cat "$WATCH_PID_FILE")"

    notify "Folder Watcher" "Started monitoring $WALLPAPER_DIR"
}

# Stop folder watcher
stop_watcher() {
    if [[ -f "$WATCH_PID_FILE" ]]; then
        local pid
        pid=$(cat "$WATCH_PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm "$WATCH_PID_FILE"
        log "Watcher stopped"

        if [[ "$HAS_GUM" == true ]]; then
            gum style --foreground 42 "✅ Folder watcher stopped"
        fi

        notify "Folder Watcher" "Stopped monitoring"
    fi
}

# Create profile
create_profile() {
    local profile_name="$1"
    local profile_dir="${PROFILES_DIR}/${profile_name}"

    if [[ -d "$profile_dir" ]]; then
        if gum confirm "Profile '$profile_name' exists. Overwrite?"; then
            rm -rf "$profile_dir"
        else
            return
        fi
    fi

    mkdir -p "$profile_dir"

    # Ask for wallpaper directory
    local wallpaper_dir
    wallpaper_dir=$(gum input --placeholder "Wallpaper directory" --value "$WALLPAPER_DIR")
    echo "$wallpaper_dir" > "$profile_dir/wallpaper_dir.txt"

    # Ask for settings
    local night_override
    night_override=$(gum input --placeholder "Night override hour" --value "$NIGHT_OVERRIDE")
    echo "NIGHT_OVERRIDE=$night_override" > "$profile_dir/settings.conf"

    gum style --foreground 42 "✅ Created profile: $profile_name"
    notify "Theme Profile" "Created: $profile_name"
}

# Create profile rule
create_profile_rule() {
    local rule_name="$1"
    local rule_file="${PROFILE_RULES_DIR}/${rule_name}.conf"

    if [[ -f "$rule_file" ]]; then
        if ! gum confirm "Rule exists. Overwrite?"; then
            return
        fi
    fi

    local app_pattern
    app_pattern=$(gum input --placeholder "App pattern (e.g., 'code', 'firefox')")
    local profile_name
    profile_name=$(gum input --placeholder "Profile name to switch to")

    cat > "$rule_file" << EOF
# Profile rule for my-theme.sh
# Generated on $(date)

APP_PATTERN="$app_pattern"
PROFILE_NAME="$profile_name"
EOF

    gum style --foreground 42 "✅ Created profile rule: $rule_name"
}

# Switch profile
switch_profile() {
    local profile_name="$1"
    local skip_update="${2:-}"
    local profile_dir="${PROFILES_DIR}/${profile_name}"

    if [[ ! -d "$profile_dir" ]] && [[ "$profile_name" != "default" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    # Save current profile
    if [[ "$profile_name" == "default" ]]; then
        rm -f "$CURRENT_PROFILE"
        CURRENT_THEME_PROFILE="default"
        WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
    else
        echo "$profile_name" > "$CURRENT_PROFILE"
        CURRENT_THEME_PROFILE="$profile_name"

        # Load profile settings
        if [[ -f "$profile_dir/settings.conf" ]]; then
            source "$profile_dir/settings.conf"
        fi

        # Update wallpaper dir
        if [[ -f "$profile_dir/wallpaper_dir.txt" ]]; then
            WALLPAPER_DIR=$(cat "$profile_dir/wallpaper_dir.txt")
        fi
    fi

    save_settings
    log "Switched to profile: $profile_name"
    notify "Theme Profile" "Switched to: $profile_name"

    # Optionally update theme immediately
    if [[ -z "$skip_update" ]] && [[ "$HAS_GUM" == true ]]; then
        if gum confirm "Update theme now with new profile?"; then
            update_theme "random"
        fi
    fi
}

# Create desktop entry
create_desktop_entry() {
    local desktop_file="${DESKTOP_ENTRY_DIR}/my-theme.desktop"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=My Theme Engine
Comment=Dynamic Wallpaper & System Theme Manager
Exec=$TERMINAL -e $0 --interactive
Icon=preferences-desktop-theme
Terminal=false
Categories=Settings;System;
Keywords=theme;wallpaper;dynamic;
EOF

    chmod +x "$desktop_file"
    log "Created desktop entry: $desktop_file"
    notify "Desktop Entry" "Added to application menu"
}

# Create systemd user service
create_systemd_service() {
    local service_file="${SYSTEMD_USER_DIR}/my-theme.service"

    cat > "$service_file" << EOF
[Unit]
Description=My Theme Engine - Dynamic Wallpaper & Theme Manager
After=graphical-session.target

[Service]
Type=simple
ExecStart=$0 --daemon --interval 30 --weather
Restart=on-failure
RestartSec=30
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%I/bus

[Install]
WantedBy=default.target
EOF

    log "Created systemd user service: $service_file"
    notify "Systemd Service" "Created. Enable with: systemctl --user enable my-theme.service"
}

# Run as daemon
run_daemon() {
    local interval="${1:-30}"
    local mode="${2:-weather}"

    log "Starting daemon mode (interval: ${interval} minutes, mode: ${mode})"
    notify "Theme Daemon" "Starting with ${interval}min interval"

    # Start folder watcher
    start_watcher

    # Convert minutes to seconds
    local interval_seconds=$((interval * 60))

    # Trap to clean up watcher on exit
    trap stop_watcher EXIT INT TERM

    # Run initial update
    update_theme "$mode"

    while true; do
        # Check for app-based profile switching
        if [[ "$AUTO_PROFILE_SWITCHING" == true ]]; then
            check_and_switch_profile
        fi

        # Check if on battery and adjust interval
        local current_interval=$interval_seconds
        if check_battery; then
            current_interval=$((interval_seconds * BATTERY_INTERVAL_MULTIPLIER))
            log "On battery: increasing interval to ${current_interval}s"
        fi

        # Check deep sleep (battery < threshold)
        if check_deep_sleep; then
            log "Deep sleep mode active - stopping watcher and sleeping longer"
            stop_watcher
            sleep $((current_interval * 3))  # Sleep even longer in deep sleep
            continue
        fi

        log "Sleeping for $((current_interval / 60)) minutes..."
        sleep "$current_interval"
        update_theme "$mode"
    done
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."

    local packages=()
    local pkg_manager=""

    # Detect package manager
    if command -v apt >/dev/null 2>&1; then
        pkg_manager="apt"
        packages=(imagemagick feh bc curl jq inotify-tools x11-utils acpi libnotify-bin lm-sensors chafa)
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
        packages=(ImageMagick feh bc curl jq inotify-tools xrandr acpi libnotify lm_sensors chafa)
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
        packages=(imagemagick feh bc curl jq inotify-tools xorg-xrandr acpi libnotify lm_sensors chafa)
    elif command -v zypper >/dev/null 2>&1; then
        pkg_manager="zypper"
        packages=(imagemagick feh bc curl jq inotify-tools xrandr acpi libnotify lm_sensors chafa)
    else
        error_exit "Unsupported package manager"
    fi

    # Install gum if not present
    if ! command -v gum >/dev/null 2>&1; then
        if [[ "$pkg_manager" == "apt" ]]; then
            echo "deb [trusted=yes] https://repo.charm.sh/apt/ /" | sudo tee /etc/apt/sources.list.d/charm.list
            sudo apt update && sudo apt install -y gum
        elif [[ "$pkg_manager" == "pacman" ]]; then
            sudo pacman -S --noconfirm gum
        else
            curl -L https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_linux_x86_64.tar.gz | tar xz
            sudo mv gum_*/gum /usr/local/bin/
        fi
    fi

    # Install packages
    if [[ "$pkg_manager" == "apt" ]]; then
        sudo apt update
        sudo apt install -y "${packages[@]}"
    elif [[ "$pkg_manager" == "dnf" ]]; then
        sudo dnf install -y "${packages[@]}"
    elif [[ "$pkg_manager" == "pacman" ]]; then
        sudo pacman -S --noconfirm "${packages[@]}"
    elif [[ "$pkg_manager" == "zypper" ]]; then
        sudo zypper install -y "${packages[@]}"
    fi

    # Install swww for Wayland
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]] && ! command -v swww >/dev/null 2>&1; then
        if command -v cargo >/dev/null 2>&1; then
            cargo install swww
        fi
    fi

    log "Dependencies installed successfully!"
    notify "Theme Engine" "Dependencies installed"
}

# WallHaven menu
wallhaven_menu() {
    local choice

    while true; do
        choice=$(gum choose \
            --header="🌌 WallHaven Wallpaper Manager" \
            --cursor="👉 " \
            --selected.foreground="212" \
            --height=15 \
            "🔑 Configure API Key (secure)" \
            "🎲 Fetch Random Wallpaper" \
            "🖼️  Fetch General Wallpapers" \
            "🌸 Fetch Anime Wallpapers" \
            "👥 Fetch People Wallpapers" \
            "⚙️  Configure Categories" \
            "🧹 Clean Old Wallpapers" \
            "📁 Open WallHaven Folder" \
            "↩️  Back to Main Menu")

        case "$choice" in
            *"API Key"*)
                local api_key
                api_key=$(gum input --placeholder "Enter your WallHaven API Key" --password)
                if [[ -n "$api_key" ]]; then
                    save_api_key "$api_key"
                    gum style --foreground 42 "✅ API Key saved securely!"
                fi
                ;;
            *"Random Wallpaper"*)
                if [[ -z "$WALLHAVEN_API_KEY" ]]; then
                    if ! gum confirm "No API key configured. Continue without key? (rate limits apply)"; then
                        continue
                    fi
                fi

                gum spin --spinner globe --title "Fetching random wallpaper..." -- sleep 1
                local image_url
                image_url=$(fetch_wallhaven_wallpaper "random")

                if [[ -n "$image_url" ]]; then
                    gum style --foreground 212 "📸 Downloading: $image_url"
                    local local_path
                    local_path=$(download_wallhaven_wallpaper "$image_url")

                    if [[ -n "$local_path" ]] && [[ -f "$local_path" ]]; then
                        gum style --foreground 42 "✅ Downloaded to: $local_path"

                        if gum confirm "Apply this wallpaper now?"; then
                            SPECIFIC_WALLPAPER="$local_path" update_theme "specific"
                        fi
                    else
                        gum style --foreground 196 "❌ Failed to download wallpaper"
                    fi
                else
                    gum style --foreground 196 "❌ Failed to fetch wallpaper"
                fi
                ;;
            *"General"*)
                gum spin --spinner globe --title "Fetching general wallpaper..." -- sleep 1
                local image_url
                image_url=$(fetch_wallhaven_wallpaper "general")

                if [[ -n "$image_url" ]]; then
                    local local_path
                    local_path=$(download_wallhaven_wallpaper "$image_url")

                    if [[ -n "$local_path" ]]; then
                        gum style --foreground 42 "✅ Downloaded to: $local_path"

                        if gum confirm "Apply this wallpaper now?"; then
                            SPECIFIC_WALLPAPER="$local_path" update_theme "specific"
                        fi
                    fi
                fi
                ;;
            *"Anime"*)
                gum spin --spinner globe --title "Fetching anime wallpaper..." -- sleep 1
                local image_url
                image_url=$(fetch_wallhaven_wallpaper "anime")

                if [[ -n "$image_url" ]]; then
                    local local_path
                    local_path=$(download_wallhaven_wallpaper "$image_url")

                    if [[ -n "$local_path" ]]; then
                        gum style --foreground 42 "✅ Downloaded to: $local_path"

                        if gum confirm "Apply this wallpaper now?"; then
                            SPECIFIC_WALLPAPER="$local_path" update_theme "specific"
                        fi
                    fi
                fi
                ;;
            *"People"*)
                gum spin --spinner globe --title "Fetching people wallpaper..." -- sleep 1
                local image_url
                image_url=$(fetch_wallhaven_wallpaper "people")

                if [[ -n "$image_url" ]]; then
                    local local_path
                    local_path=$(download_wallhaven_wallpaper "$image_url")

                    if [[ -n "$local_path" ]]; then
                        gum style --foreground 42 "✅ Downloaded to: $local_path"

                        if gum confirm "Apply this wallpaper now?"; then
                            SPECIFIC_WALLPAPER="$local_path" update_theme "specific"
                        fi
                    fi
                fi
                ;;
            *"Configure Categories"*)
                local categories
                categories=$(gum choose \
                    --header="Select categories to include:" \
                    --no-limit \
                    "General" "Anime" "People")

                local cats="000"
                if [[ "$categories" == *"General"* ]]; then
                    cats="${cats:0:0}1${cats:1:2}"
                fi
                if [[ "$categories" == *"Anime"* ]]; then
                    cats="${cats:0:1}1${cats:2:1}"
                fi
                if [[ "$categories" == *"People"* ]]; then
                    cats="${cats:0:2}1"
                fi

                WALLHAVEN_CATEGORIES="$cats"

                local resolution
                resolution=$(gum input --placeholder "Resolution (e.g., 1920x1080)" --value "$WALLHAVEN_RESOLUTION")
                if [[ -n "$resolution" ]]; then
                    WALLHAVEN_RESOLUTION="$resolution"
                fi

                local limit
                limit=$(gum input --placeholder "Number to fetch (max 24)" --value "$WALLHAVEN_LIMIT")
                if [[ -n "$limit" ]]; then
                    WALLHAVEN_LIMIT="$limit"
                fi

                save_wallhaven_config
                gum style --foreground 42 "✅ Categories configured!"
                ;;
            *"Clean"*)
                local days
                days=$(gum input --placeholder "Delete wallpapers older than (days)" --value "$WALLHAVEN_CLEAN_DAYS")
                if [[ -n "$days" ]]; then
                    clean_wallhaven_folder "$days"
                fi
                ;;
            *"Open Folder"*)
                xdg-open "$WALLHAVEN_DIR" 2>/dev/null || open "$WALLHAVEN_DIR" 2>/dev/null
                ;;
            *"Back"*)
                break
                ;;
        esac

        echo
        if [[ "$choice" != *"Back"* ]]; then
            gum confirm "Return to WallHaven menu?" --affirmative="Yes" --negative="Main Menu" || break
        fi
    done
}

# Main theme update function
update_theme() {
    local mode="$1"
    local condition=""
    local wallpaper=""

    log "Starting theme update (mode: $mode, force: $FORCE_MODE)"

    # Get monitor resolution for aspect ratio checking
    MONITOR_RESOLUTION=$(get_monitor_resolution)
    log "Monitor resolution: $MONITOR_RESOLUTION"

    # Determine condition based on mode
    case "$mode" in
        weather)
            if [[ "$HAS_GUM" == true ]]; then
                condition=$(gum spin --spinner globe --title "Fetching weather..." -- bash -c "fetch_weather_condition")
            else
                condition=$(fetch_weather_condition)
            fi
            ;;
        time)
            condition=$(date +%H)
            if [[ $condition -ge 5 ]] && [[ $condition -lt 9 ]]; then
                condition="morning"
            elif [[ $condition -ge 9 ]] && [[ $condition -lt 17 ]]; then
                condition="day"
            elif [[ $condition -ge 17 ]] && [[ $condition -lt 20 ]]; then
                condition="evening"
            else
                condition="night"
            fi
            ;;
        random)
            condition="random"
            ;;
        specific)
            if [[ -n "${SPECIFIC_WALLPAPER:-}" ]]; then
                wallpaper="$SPECIFIC_WALLPAPER"
            fi
            ;;
        *)
            condition="general"
            ;;
    esac

    # Select wallpaper if not already set
    if [[ -z "$wallpaper" ]]; then
        if [[ "$HAS_GUM" == true ]]; then
            wallpaper=$(gum spin --spinner dot --title "Selecting wallpaper for: $condition" -- bash -c "select_wallpaper '$condition'")
        else
            wallpaper=$(select_wallpaper "$condition")
        fi
    fi

    if [[ -z "$wallpaper" ]]; then
        # Don't exit - just notify and return
        log "No wallpaper found. Please add images or use WallHaven."
        notify "No Wallpaper" "Please add images or use WallHaven" "normal"
        return 1
    fi

    CURRENT_WALLPAPER="$wallpaper"
    log "Selected wallpaper: $wallpaper"

    # Extract colors
    local -a colors
    if [[ "$HAS_GUM" == true ]]; then
        mapfile -t colors < <(gum spin --spinner pulse --title "Extracting colors..." -- bash -c "extract_colors '$wallpaper' 8")
    else
        mapfile -t colors < <(extract_colors "$wallpaper" 8)
    fi

    # Show palette with gum
    if [[ "$HAS_GUM" == true ]]; then
        gum style --border rounded --margin "1" --padding "1" --border-foreground 212 "🎨 Generated Theme"

        for i in "${!colors[@]}"; do
            gum style \
                --background "${colors[$i]}" \
                --foreground "$(get_contrast_color "${colors[$i]}")" \
                --padding "0 2" \
                --margin "0 1" \
                --align center \
                "Color $i: ${colors[$i]}"
        done
    fi

    # Set wallpaper
    if [[ "$HAS_GUM" == true ]]; then
        gum spin --spinner line --title "Applying wallpaper..." -- bash -c "set_wallpaper '$wallpaper'"
    else
        set_wallpaper "$wallpaper"
    fi

    # Update terminal colors
    if [[ "$HAS_GUM" == true ]]; then
        gum spin --spinner line --title "Updating terminal colors..." -- bash -c "update_terminal_colors '${colors[@]}'"
    else
        update_terminal_colors "${colors[@]}"
    fi

    # Update browser themes
    if [[ "$HAS_GUM" == true ]]; then
        gum spin --spinner line --title "Updating browser themes..." -- bash -c "update_browser_themes '${colors[@]}'"
    else
        update_browser_themes "${colors[@]}"
    fi

    # Generate Gradience preset
    if [[ "$HAS_GUM" == true ]] && command -v gradience-cli >/dev/null 2>&1; then
        gum spin --spinner line --title "Applying GTK theme..." -- bash -c "generate_gradience_preset '${colors[@]}'"
    fi

    # Run external hooks (including lockscreen and preview)
    if [[ "$HAS_GUM" == true ]]; then
        gum spin --spinner pipe --title "Triggering external hooks..." -- bash -c "run_hooks"
    else
        run_hooks
    fi

    # Auto-clean WallHaven if enabled
    if [[ "$WALLHAVEN_AUTO_CLEAN" == true ]]; then
        clean_wallhaven_folder "$WALLHAVEN_CLEAN_DAYS" >/dev/null 2>&1 &
    fi

    # Show success message
    if [[ "$HAS_GUM" == true ]]; then
        gum style --foreground 42 "✅ Theme updated successfully!"
        gum table -s "|" -p <<EOF
Mode|${mode}
Condition|${condition}
Profile|${CURRENT_THEME_PROFILE}
Wallpaper|$(basename "$wallpaper")
Primary Color|${colors[0]}
Text Color|$(get_contrast_color "${colors[0]}")
Hooks|$(ls -1 "${HOOKS_DIR}" 2>/dev/null | wc -l) available
EOF
    else
        log "Theme update completed"
    fi

    # Send notification
    notify "Theme Updated" "Mode: $mode | Profile: $CURRENT_THEME_PROFILE" "low"

    # Save settings
    save_settings
}

# Snapshot gallery
snapshot_gallery() {
    if [[ ! -d "$SNAPSHOTS_DIR" ]] || [[ -z "$(ls -A "$SNAPSHOTS_DIR")" ]]; then
        gum style --foreground 214 "No snapshots found"
        return
    fi

    local snapshots=()
    while IFS= read -r snap; do
        snapshots+=("$(basename "$snap")")
    done < <(find "$SNAPSHOTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    while true; do
        local selected_snap
        selected_snap=$(gum choose --height=15 --header="📸 Snapshot Gallery (select to preview)" "${snapshots[@]}" "↩️  Back to menu")

        if [[ "$selected_snap" == "↩️  Back to menu" ]] || [[ -z "$selected_snap" ]]; then
            break
        fi

        # Show snapshot details
        clear
        gum style --border double --margin "1" --padding "1" --border-foreground 212 "Snapshot: $selected_snap"

        # Display thumbnail if available
        local thumbnail="${THUMBNAILS_DIR}/${selected_snap}.jpg"
        if [[ -f "$thumbnail" ]] && [[ "$USE_SIXEL" == true ]]; then
            echo
            display_thumbnail "$thumbnail"
            echo
        fi

        # Show snapshot info
        if [[ -f "${SNAPSHOTS_DIR}/${selected_snap}/colors.txt" ]]; then
            gum style --foreground 212 "Colors:"
            head -10 "${SNAPSHOTS_DIR}/${selected_snap}/colors.txt"
        fi

        echo
        local action
        action=$(gum choose "Load this snapshot" "Delete this snapshot" "Back to gallery")

        case "$action" in
            "Load this snapshot")
                load_snapshot "$selected_snap"
                if gum confirm "Update theme now?"; then
                    update_theme "random"
                fi
                break
                ;;
            "Delete this snapshot")
                if gum confirm "Delete $selected_snap?"; then
                    rm -rf "${SNAPSHOTS_DIR}/${selected_snap}"
                    rm -f "${THUMBNAILS_DIR}/${selected_snap}.jpg"
                    snapshots=("${snapshots[@]/$selected_snap}")
                    gum style --foreground 42 "✅ Snapshot deleted"
                fi
                ;;
        esac
    done
}

# Interactive menu with gum
gum_main_menu() {
    local choice

    # Print welcome banner
    print_banner

    while true; do
        # Check for app-based profile switching
        if [[ "$AUTO_PROFILE_SWITCHING" == true ]]; then
            check_and_switch_profile
        fi

        # Show current profile in menu header
        local profile_indicator=""
        if [[ "$CURRENT_THEME_PROFILE" != "default" ]]; then
            profile_indicator=" [Profile: ${CURRENT_THEME_PROFILE}]"
        fi

        choice=$(gum choose \
            --header="🎨 My Theme Engine ${SCRIPT_VERSION}${profile_indicator}" \
            --cursor="👉 " \
            --selected.foreground="212" \
            --height=30 \
            "🌤️  Weather-based theme" \
            "⏰ Time-based theme" \
            "🎲 Random theme" \
            "🖼️  Select specific wallpaper" \
            "🌌 WallHaven wallpapers" \
            "📸 Snapshot gallery" \
            "👤 Profile management" \
            "🤖 Auto-profile rules" \
            "⚙️  Configure settings" \
            "👁️  Start folder watcher (debounced)" \
            "🛑 Stop folder watcher" \
            "🔄 Run as daemon" \
            "🔧 Manage hooks" \
            "📦 Install dependencies" \
            "🎨 Show current colors" \
            "🚀 Create desktop entry" \
            "⚙️  Create systemd service" \
            "🔄 Reset configuration" \
            "❌ Exit")

        case "$choice" in
            *Weather*)
                CITY=$(gum input --placeholder "Enter city name (leave empty for auto-detect)" --value "$CITY")
                FORCE_MODE=$(gum confirm "Force new wallpaper?" && echo true || echo false)
                update_theme "weather"
                ;;
            *Time*)
                FORCE_MODE=$(gum confirm "Force new wallpaper?" && echo true || echo false)
                update_theme "time"
                ;;
            *Random*)
                FORCE_MODE=$(gum confirm "Force new wallpaper?" && echo true || echo false)
                update_theme "random"
                ;;
            *specific*|*wallpaper*)
                local wallpaper_dir="$WALLPAPER_DIR"
                if [[ "$CURRENT_THEME_PROFILE" != "default" ]]; then
                    wallpaper_dir=$(get_profile_wallpaper_dir "$CURRENT_THEME_PROFILE")
                fi

                local wallpaper
                wallpaper=$(find "$wallpaper_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | \
                    gum choose --height=20 --header="Select wallpaper:")
                if [[ -n "$wallpaper" ]]; then
                    SPECIFIC_WALLPAPER="$wallpaper" update_theme "specific"
                fi
                ;;
            *WallHaven*)
                wallhaven_menu
                ;;
            *gallery*)
                snapshot_gallery
                ;;
            *Profile*)
                local prof_action=$(gum choose "Create profile" "Switch profile" "List profiles" "Delete profile")
                case "$prof_action" in
                    "Create profile")
                        local prof_name=$(gum input --placeholder "Profile name")
                        if [[ -n "$prof_name" ]]; then
                            create_profile "$prof_name"
                        fi
                        ;;
                    "Switch profile")
                        if [[ -d "$PROFILES_DIR" ]]; then
                            local profiles=("default")
                            while IFS= read -r prof; do
                                profiles+=("$(basename "$prof")")
                            done < <(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d)

                            local prof_to_switch=$(printf '%s\n' "${profiles[@]}" | gum choose)
                            if [[ -n "$prof_to_switch" ]]; then
                                if [[ "$prof_to_switch" == "default" ]]; then
                                    rm -f "$CURRENT_PROFILE"
                                    CURRENT_THEME_PROFILE="default"
                                    WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
                                    gum style --foreground 42 "✅ Switched to default profile"
                                else
                                    switch_profile "$prof_to_switch"
                                fi
                            fi
                        fi
                        ;;
                    "List profiles")
                        gum style --border rounded --margin "1" --padding "1" "👤 Theme Profiles"
                        echo "  • default (current: $([[ "$CURRENT_THEME_PROFILE" == "default" ]] && echo "✓")"
                        if [[ -d "$PROFILES_DIR" ]]; then
                            for prof in "$PROFILES_DIR"/*; do
                                if [[ -d "$prof" ]]; then
                                    prof_name=$(basename "$prof")
                                    echo "  • $prof_name $( [[ "$CURRENT_THEME_PROFILE" == "$prof_name" ]] && echo "✓")"
                                fi
                            done
                        fi
                        ;;
                    "Delete profile")
                        if [[ -d "$PROFILES_DIR" ]]; then
                            local prof_to_delete=$(ls -1 "$PROFILES_DIR" | gum choose)
                            if [[ -n "$prof_to_delete" ]] && gum confirm "Delete profile $prof_to_delete?"; then
                                rm -rf "${PROFILES_DIR}/${prof_to_delete}"
                                if [[ "$CURRENT_THEME_PROFILE" == "$prof_to_delete" ]]; then
                                    rm -f "$CURRENT_PROFILE"
                                    CURRENT_THEME_PROFILE="default"
                                fi
                                gum style --foreground 42 "✅ Profile deleted"
                            fi
                        fi
                        ;;
                esac
                ;;
            *Auto-profile*|*rules*)
                local rule_action=$(gum choose "Create rule" "List rules" "Delete rule" "Toggle auto-switching")
                case "$rule_action" in
                    "Create rule")
                        local rule_name=$(gum input --placeholder "Rule name (e.g., work-apps)")
                        if [[ -n "$rule_name" ]]; then
                            create_profile_rule "$rule_name"
                        fi
                        ;;
                    "List rules")
                        if [[ -d "$PROFILE_RULES_DIR" ]] && [[ -n "$(ls -A "$PROFILE_RULES_DIR")" ]]; then
                            gum style --border rounded --margin "1" --padding "1" "📋 Profile Rules"
                            for rule in "$PROFILE_RULES_DIR"/*.conf; do
                                if [[ -f "$rule" ]]; then
                                    source "$rule"
                                    echo "  • $(basename "$rule" .conf): $APP_PATTERN → $PROFILE_NAME"
                                fi
                            done
                        else
                            gum style --foreground 214 "No rules found"
                        fi
                        ;;
                    "Delete rule")
                        if [[ -d "$PROFILE_RULES_DIR" ]]; then
                            local rule_to_delete=$(ls -1 "$PROFILE_RULES_DIR" | gum choose)
                            if [[ -n "$rule_to_delete" ]] && gum confirm "Delete rule $rule_to_delete?"; then
                                rm "${PROFILE_RULES_DIR}/${rule_to_delete}"
                                gum style --foreground 42 "✅ Rule deleted"
                            fi
                        fi
                        ;;
                    "Toggle auto-switching")
                        AUTO_PROFILE_SWITCHING=$([[ "$AUTO_PROFILE_SWITCHING" == true ]] && echo false || echo true)
                        gum style --foreground 42 "✅ Auto-switching: $AUTO_PROFILE_SWITCHING"
                        save_settings
                        ;;
                esac
                ;;
            *Configure*|*settings*)
                CITY=$(gum input --placeholder "City name (auto-detect if empty)" --value "$CITY")
                NIGHT_OVERRIDE=$(gum input --placeholder "Night override hour (0-23)" --value "$NIGHT_OVERRIDE")
                SATURATION_BOOST=$(gum input --placeholder "Saturation boost % (100-200)" --value "$SATURATION_BOOST")
                CONTRAST_STRETCH=$(gum input --placeholder "Contrast stretch (e.g., 2%x2%)" --value "$CONTRAST_STRETCH")
                BATTERY_AWARE=$(gum confirm "Enable battery-aware mode?" && echo true || echo false)
                BATTERY_DEEP_SLEEP_THRESHOLD=$(gum input --placeholder "Deep sleep battery %" --value "$BATTERY_DEEP_SLEEP_THRESHOLD")
                NOTIFY_ERRORS=$(gum confirm "Enable desktop notifications?" && echo true || echo false)
                TEMP_MONITORING=$(gum confirm "Enable temperature monitoring?" && echo true || echo false)
                HIGH_TEMP_THRESHOLD=$(gum input --placeholder "High temp threshold (°C)" --value "$HIGH_TEMP_THRESHOLD")
                WALLHAVEN_AUTO_CLEAN=$(gum confirm "Auto-clean WallHaven folder?" && echo true || echo false)
                WALLHAVEN_CLEAN_DAYS=$(gum input --placeholder "Clean wallpapers older than (days)" --value "$WALLHAVEN_CLEAN_DAYS")
                save_settings
                gum style --foreground 42 "✅ Settings saved!"
                ;;
            *watcher*)
                start_watcher
                gum style --foreground 42 "✅ Debounced folder watcher started (PID: $(cat "$WATCH_PID_FILE"))"
                gum style --foreground 214 "Press any key to stop..."
                read -n 1
                stop_watcher
                ;;
            *Stop*)
                stop_watcher
                ;;
            *daemon*)
                local interval=$(gum input --placeholder "Update interval (minutes)" --value "30")
                local mode=$(gum choose "weather" "time" "random")
                gum confirm "Start daemon mode?" && run_daemon "$interval" "$mode"
                ;;
            *hooks*)
                local hook_action=$(gum choose "List hooks" "Create new hook" "Create Spotify hook" "Create lockscreen hook" "Create terminal preview" "Edit hook" "Delete hook")
                case "$hook_action" in
                    "List hooks")
                        if [[ -d "$HOOKS_DIR" ]] && [[ -n "$(ls -A "$HOOKS_DIR")" ]]; then
                            gum style --border rounded --margin "1" --padding "1" "Available Hooks"
                            for hook in "$HOOKS_DIR"/*; do
                                if [[ -x "$hook" ]]; then
                                    gum style --foreground 42 "✓ $(basename "$hook")"
                                elif [[ -f "$hook" ]]; then
                                    gum style --foreground 214 "⚠️  $(basename "$hook") (not executable)"
                                fi
                            done
                        else
                            gum style --foreground 214 "No hooks found"
                        fi
                        ;;
                    "Create new hook")
                        local hook_name=$(gum input --placeholder "Hook name (e.g., update_vscode.sh)")
                        if [[ -n "$hook_name" ]]; then
                            local hook_path="${HOOKS_DIR}/${hook_name}"
                            cat > "$hook_path" << 'EOF'
#!/usr/bin/env bash
# Auto-generated hook for my-theme.sh
source "$HOME/.cache/my-theme/current_colors"
echo "Hook executed at $(date)" >> "$HOME/.cache/my-theme/hook.log"
EOF
                            chmod +x "$hook_path"
                            gum style --foreground 42 "✅ Created hook: $hook_name"
                        fi
                        ;;
                    "Create Spotify hook")
                        create_spicetify_hook
                        gum style --foreground 42 "✅ Created Spotify hook"
                        ;;
                    "Create lockscreen hook")
                        create_lockscreen_hook
                        gum style --foreground 42 "✅ Created lockscreen hook (ultimate)"
                        ;;
                    "Create terminal preview")
                        create_terminal_preview_hook
                        gum style --foreground 42 "✅ Created terminal preview hook"
                        ;;
                    "Edit hook")
                        local hook_to_edit=$(find "$HOOKS_DIR" -type f -exec basename {} \; | gum choose)
                        if [[ -n "$hook_to_edit" ]]; then
                            ${EDITOR:-vim} "${HOOKS_DIR}/${hook_to_edit}"
                        fi
                        ;;
                    "Delete hook")
                        local hook_to_delete=$(find "$HOOKS_DIR" -type f -exec basename {} \; | gum choose)
                        if [[ -n "$hook_to_delete" ]] && gum confirm "Delete $hook_to_delete?"; then
                            rm "${HOOKS_DIR}/${hook_to_delete}"
                            gum style --foreground 42 "✅ Deleted hook"
                        fi
                        ;;
                esac
                ;;
            *dependencies*)
                install_dependencies
                ;;
            *colors*)
                if [[ -f "$COLOR_CACHE" ]]; then
                    gum style --border rounded --margin "1" --padding "1" "Current Colors"
                    while IFS= read -r line; do
                        if [[ "$line" =~ ^(BG|FG|MUTED_BG|SELECTED_WALL|COLOR[0-9]+)=(.*) ]]; then
                            key="${BASH_REMATCH[1]}"
                            value="${BASH_REMATCH[2]}"
                            if [[ "$value" =~ ^# ]]; then
                                gum style --foreground "$value" "  $key: $value"
                            else
                                echo "  $key: $value"
                            fi
                        fi
                    done < "$COLOR_CACHE"
                else
                    gum style --foreground 214 "No colors cached yet. Run an update first."
                fi
                ;;
            *desktop*)
                create_desktop_entry
                gum style --foreground 42 "✅ Desktop entry created!"
                ;;
            *systemd*)
                create_systemd_service
                gum style --foreground 42 "✅ Systemd service created!"
                gum style --foreground 214 "Enable with: systemctl --user enable my-theme.service"
                gum style --foreground 214 "Start with: systemctl --user start my-theme.service"
                ;;
            *Reset*)
                if gum confirm "Reset all configuration?"; then
                    rm -rf "${CACHE_DIR:?}"/*
                    gum style --foreground 42 "✅ Configuration reset!"
                fi
                ;;
            *Exit*)
                gum style --foreground 212 "Goodbye! 👋"
                exit 0
                ;;
        esac

        echo
        if ! gum confirm "Return to main menu?" --affirmative="Yes" --negative="Exit"; then
            gum style --foreground 212 "Goodbye! 👋"
            exit 0
        fi
    done
}

# Show help
show_help() {
    cat << EOF
my-theme.sh ${SCRIPT_VERSION} - Dynamic Wallpaper & System Theme Engine

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    -i, --interactive       Start interactive menu (default with no args)
    -r, --random            Select random wallpaper
    -t, --time              Select wallpaper based on time
    -w, --weather           Select wallpaper based on weather
    -c, --city CITY         Set city for weather
    -f, --force             Force new wallpaper (ignore cache)
    -p, --profile PROFILE   Switch to theme profile
    -d, --daemon            Run as daemon
    --interval MIN          Update interval (default: 30)
    -s, --set FILE          Set specific wallpaper
    --wallhaven [CATEGORY]  Fetch from WallHaven (general|anime|people|random)
    --wallhaven-key KEY     Set WallHaven API key (secure)
    --clean-wallhaven [DAYS] Clean old WallHaven wallpapers
    --watch                 Start folder watcher
    --stop-watch            Stop folder watcher
    --snapshot NAME         Save current theme as snapshot
    --load NAME             Load theme snapshot
    --list-snapshots        List available snapshots
    --list-profiles         List available profiles
    --create-rule           Create auto-profile rule
    --create-desktop        Create desktop entry
    --create-service        Create systemd user service
    --install-deps          Install dependencies
    --list-colors           Show current colors
    --list-hooks            List available hooks
    --run-hooks             Run hooks manually
    --reset-config          Reset configuration

Examples:
    ${SCRIPT_NAME}                          # Start interactive menu
    ${SCRIPT_NAME} --weather --city "Paris" --force
    ${SCRIPT_NAME} --profile work --daemon --interval 60
    ${SCRIPT_NAME} --wallhaven anime        # Fetch anime wallpaper
    ${SCRIPT_NAME} --wallhaven-key YOUR_API_KEY
    ${SCRIPT_NAME} --clean-wallhaven 30
    ${SCRIPT_NAME} --create-desktop         # Add to app launcher
    ${SCRIPT_NAME} --create-service         # Create systemd service
EOF
}

# List profiles
list_profiles() {
    echo "Available profiles:"
    echo "  default (current: $([[ "$CURRENT_THEME_PROFILE" == "default" ]] && echo "✓")"
    if [[ -d "$PROFILES_DIR" ]]; then
        for prof in "$PROFILES_DIR"/*; do
            if [[ -d "$prof" ]]; then
                prof_name=$(basename "$prof")
                echo "  $prof_name $( [[ "$CURRENT_THEME_PROFILE" == "$prof_name" ]] && echo "✓")"
            fi
        done
    fi
}

# List snapshots
list_snapshots() {
    if [[ -d "$SNAPSHOTS_DIR" ]] && [[ -n "$(ls -A "$SNAPSHOTS_DIR")" ]]; then
        echo "Available snapshots:"
        for snap in "$SNAPSHOTS_DIR"/*; do
            if [[ -d "$snap" ]]; then
                echo "  • $(basename "$snap")"
            fi
        done
    else
        echo "No snapshots found"
    fi
}

# List hooks
list_hooks() {
    if [[ -d "$HOOKS_DIR" ]] && [[ -n "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]]; then
        echo "Available hooks:"
        for hook in "$HOOKS_DIR"/*; do
            if [[ -x "$hook" ]]; then
                echo "  ✓ $(basename "$hook")"
            elif [[ -f "$hook" ]]; then
                echo "  ⚠️  $(basename "$hook") (not executable)"
            fi
        done
    else
        echo "No hooks found in $HOOKS_DIR"
    fi
}

# Reset configuration
reset_config() {
    log "Resetting configuration..."
    stop_watcher 2>/dev/null || true
    rm -rf "${CACHE_DIR:?}"/*
    rm -f "${SETTINGS_FILE}"
    rm -f "$CURRENT_PROFILE"
    rm -f "$LAST_ACTIVE_PROFILE"
    rm -f "${WALLHAVEN_CONFIG}"
    rm -f "${API_KEY_FILE}"
    mkdir -p "${CACHE_DIR}" "${HOOKS_DIR}"
    CURRENT_THEME_PROFILE="default"
    log "Configuration reset complete"

    if [[ "$HAS_GUM" == true ]]; then
        gum style --foreground 42 "✅ Configuration reset complete"
    fi

    notify "Theme Engine" "Configuration reset"
}

# Main execution
main() {
    local mode="random"
    local interval=30
    local interactive=false
    local daemon_mode=false
    local specific_wallpaper=""
    local wallhaven_category=""

    # Load saved settings
    load_settings

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "my-theme.sh ${SCRIPT_VERSION}"
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -r|--random)
                mode="random"
                shift
                ;;
            -t|--time)
                mode="time"
                shift
                ;;
            -w|--weather)
                mode="weather"
                shift
                ;;
            -c|--city)
                CITY="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -p|--profile)
                switch_profile "$2" "no-update"
                shift 2
                ;;
            -d|--daemon)
                daemon_mode=true
                shift
                ;;
            --interval)
                interval="$2"
                shift 2
                ;;
            -s|--set)
                mode="specific"
                specific_wallpaper="$2"
                shift 2
                ;;
            --wallhaven)
                wallhaven_category="${2:-random}"
                shift 2
                ;;
            --wallhaven-key)
                save_api_key "$2"
                shift 2
                ;;
            --clean-wallhaven)
                local days="${2:-$WALLHAVEN_CLEAN_DAYS}"
                clean_wallhaven_folder "$days"
                exit 0
                ;;
            --watch)
                start_watcher
                exit 0
                ;;
            --stop-watch)
                stop_watcher
                exit 0
                ;;
            --snapshot)
                save_snapshot "$2"
                shift 2
                exit 0
                ;;
            --load)
                load_snapshot "$2"
                shift 2
                # Optionally update after loading
                if [[ "$HAS_GUM" == true ]] && [[ -t 0 ]]; then
                    gum confirm "Update theme now?" && update_theme "random"
                fi
                exit 0
                ;;
            --list-snapshots)
                list_snapshots
                exit 0
                ;;
            --list-profiles)
                list_profiles
                exit 0
                ;;
            --create-rule)
                if [[ -n "$2" ]]; then
                    create_profile_rule "$2"
                    shift 2
                else
                    echo "Usage: --create-rule RULE_NAME"
                    exit 1
                fi
                exit 0
                ;;
            --create-desktop)
                create_desktop_entry
                exit 0
                ;;
            --create-service)
                create_systemd_service
                exit 0
                ;;
            --install-deps)
                install_dependencies
                exit 0
                ;;
            --list-colors)
                if [[ -f "$COLOR_CACHE" ]]; then
                    cat "$COLOR_CACHE"
                else
                    echo "No colors cached yet."
                fi
                exit 0
                ;;
            --list-hooks)
                list_hooks
                exit 0
                ;;
            --run-hooks)
                run_hooks
                exit 0
                ;;
            --reset-config)
                if [[ "$HAS_GUM" == true ]] && [[ -t 0 ]]; then
                    gum confirm "Reset configuration?" && reset_config
                else
                    reset_config
                fi
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Handle WallHaven direct fetch
    if [[ -n "$wallhaven_category" ]]; then
        gum spin --spinner globe --title "Fetching wallpaper from WallHaven..." -- sleep 1
        local image_url
        image_url=$(fetch_wallhaven_wallpaper "$wallhaven_category")

        if [[ -n "$image_url" ]]; then
            local local_path
            local_path=$(download_wallhaven_wallpaper "$image_url")

            if [[ -n "$local_path" ]]; then
                echo "✅ Downloaded to: $local_path"
                if [[ -t 0 ]] && gum confirm "Apply this wallpaper now?"; then
                    SPECIFIC_WALLPAPER="$local_path" update_theme "specific"
                fi
            fi
        fi
        exit 0
    fi

    # Export for functions
    export CITY
    export SPECIFIC_WALLPAPER="$specific_wallpaper"
    export FORCE_MODE

    # Check if wallpaper directory exists (don't exit, just warn)
    local wallpaper_dir_to_check="$WALLPAPER_DIR"
    if [[ "$CURRENT_THEME_PROFILE" != "default" ]]; then
        wallpaper_dir_to_check=$(get_profile_wallpaper_dir "$CURRENT_THEME_PROFILE")
    fi

    if [[ ! -d "$wallpaper_dir_to_check" ]]; then
        mkdir -p "$wallpaper_dir_to_check"
        log "Created wallpaper directory: $wallpaper_dir_to_check"
        # Don't exit - just notify
        if [[ "$HAS_GUM" == true ]] && [[ -t 0 ]] && [[ "$interactive" == true ]]; then
            gum style --foreground 214 "⚠️  Created wallpaper directory. Use WallHaven to download wallpapers!"
        fi
    fi

    # Create default hooks
    create_spicetify_hook
    create_lockscreen_hook
    create_terminal_preview_hook

    # Interactive mode
    if [[ "$interactive" == true ]] || [[ $# -eq 0 && -t 0 ]]; then
        if [[ "$HAS_GUM" == false ]]; then
            echo "Gum is required for interactive mode. Installing..."
            install_dependencies
            # Recheck after installation
            if command -v gum >/dev/null 2>&1; then
                HAS_GUM=true
            fi
        fi

        # Final check for gum
        if [[ "$HAS_GUM" == true ]]; then
            gum_main_menu
        else
            echo "❌ Gum installation failed. Please install manually:"
            echo "  - Debian/Ubuntu: sudo apt install gum"
            echo "  - Arch: sudo pacman -S gum"
            echo "  - Or download from: https://github.com/charmbracelet/gum"
            exit 1
        fi
        exit 0
    fi

    # Check dependencies for non-interactive mode
    if ! command -v magick >/dev/null 2>&1; then
        error_exit "ImageMagick not found. Run with --install-deps to install."
    fi

    # Run in appropriate mode
    if [[ "$daemon_mode" == true ]]; then
        run_daemon "$interval" "$mode"
    else
        update_theme "$mode"
    fi
}

# Final Script Entry Logic - The Masterpiece
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If no arguments are passed AND we are in a terminal, force interactive
    if [[ $# -eq 0 ]] && [[ -t 0 ]]; then
        main --interactive
    else
        main "$@"
    fi
fi
