#!/usr/bin/env bash
# tmux-weather — cached, auto-located weather for your tmux status bar.
#
# Data sources (no API keys required):
#   - wttr.in           weather conditions + temperature + IP geolocation
#   - Nominatim (OSM)    reverse-geocode fallback when wttr.in returns raw coords
#
# Usage in ~/.tmux.conf:
#   set -g status-right "#(~/.local/bin/tmux-weather.sh)"
#
# Tunables via environment:
#   TMUX_WEATHER_CACHE     cache file       (default /tmp/.tmux-weather-data)
#   TMUX_WEATHER_LAST      timestamp file   (default /tmp/.tmux-weather-last)
#   TMUX_WEATHER_INTERVAL  refresh seconds  (default 600)
#   TMUX_WEATHER_LANG      place-name lang  (default es)

set -u

CACHE="${TMUX_WEATHER_CACHE:-/tmp/.tmux-weather-data}"
LAST="${TMUX_WEATHER_LAST:-/tmp/.tmux-weather-last}"
INTERVAL="${TMUX_WEATHER_INTERVAL:-600}"
LANG_TAG="${TMUX_WEATHER_LANG:-es}"
UA="tmux-weather/1.0 (+https://github.com/estereotipau/tmux-weather)"

now=$(date +%s)
last=$(cat "$LAST" 2>/dev/null || echo 0)
diff=$((now - last))

if [ ! -f "$CACHE" ] || [ "$diff" -ge "$INTERVAL" ]; then
    weather=$(curl -sL --max-time 5 "wttr.in/?format=%C+%t&m" 2>/dev/null)
    location=$(curl -sL --max-time 5 "wttr.in/?format=%l" 2>/dev/null)

    if [ -n "$weather" ] && [[ "$weather" != *Unknown* ]]; then
        # wttr.in sometimes returns raw coordinates (e.g. "-34.60,-58.44")
        # instead of a place name. When that happens, reverse-geocode them.
        if [[ "$location" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
            lat="${location%%,*}"
            lon="${location##*,}"
            geo=$(curl -sL --max-time 5 -A "$UA" \
                "https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&zoom=10&accept-language=${LANG_TAG}" 2>/dev/null)
            name=$(printf '%s' "$geo" | python3 -c '
import json, sys
try:
    addr = json.load(sys.stdin).get("address", {})
except Exception:
    sys.exit(0)
for key in ("city","town","village","municipality","county","state_district","state"):
    if addr.get(key):
        print(addr[key]); break
' 2>/dev/null)
            [ -n "$name" ] && location="$name"
        fi

        icon=""
        case "$weather" in
            *Clear*|*Sunny*)    icon="☀" ;;
            *Partly*|*Cloudy*)  icon="☁" ;;
            *Rain*|*Drizzle*)   icon="☂" ;;
            *Snow*|*Sleet*)     icon="❄" ;;
            *Thunder*)          icon="⛈" ;;
            *Fog*|*Mist*)       icon="🌫" ;;
            *Overcast*)         icon="☁" ;;
            *)                  icon="☁" ;;
        esac
        # Temperature is the last whitespace-delimited token; drop a leading '+'.
        temp=$(echo "$weather" | rev | cut -d' ' -f1 | rev | sed 's/^+//')
        echo "$icon  $temp $location" > "$CACHE"
        echo "$now" > "$LAST"
    fi
fi

cat "$CACHE" 2>/dev/null || echo ""
