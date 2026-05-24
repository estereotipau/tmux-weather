#!/usr/bin/env bash
# tmux-weather — cached, auto-located weather for your tmux status bar.
#
# Data sources (no API keys required):
#   - ip-api.com   IP geolocation: city name + coordinates
#   - wttr.in      weather conditions + temperature (queried by coordinates)
#
# Location resolution order:
#   1. $TMUX_WEATHER_LOCATION  if set (e.g. "San Nicolas de los Arroyos")
#   2. ip-api.com geolocation of your egress IP
#   3. wttr.in's own IP geolocation (last-resort fallback)
#
# The network refresh runs in the background behind an atomic lock, so the
# status bar never blocks — even on slow links — and never spawns duplicates.
#
# Usage in ~/.tmux.conf:
#   set -g status-right "#(~/.local/bin/tmux-weather.sh)"
#
# Tunables (all optional, via environment):
#   TMUX_WEATHER_LOCATION   force a place, skip IP geolocation   (unset)
#   TMUX_WEATHER_INTERVAL   seconds between network refreshes     (600)
#   TMUX_WEATHER_TIMEOUT    per-request curl timeout, seconds     (10)
#   TMUX_WEATHER_CACHE      cache file                            (/tmp/.tmux-weather-data)
#   TMUX_WEATHER_LAST       refresh-timestamp file                (/tmp/.tmux-weather-last)
#   TMUX_WEATHER_LOCK       lock directory                        (/tmp/.tmux-weather.lock)
#   TMUX_WEATHER_SYNC       if set, refresh in foreground (debug) (unset)

set -u

CACHE="${TMUX_WEATHER_CACHE:-/tmp/.tmux-weather-data}"
LAST="${TMUX_WEATHER_LAST:-/tmp/.tmux-weather-last}"
LOCK="${TMUX_WEATHER_LOCK:-/tmp/.tmux-weather.lock}"
INTERVAL="${TMUX_WEATHER_INTERVAL:-600}"
TIMEOUT="${TMUX_WEATHER_TIMEOUT:-10}"
OVERRIDE="${TMUX_WEATHER_LOCATION:-}"

icon_for() {
    case "$1" in
        *Clear*|*Sunny*)    echo "☀" ;;
        *Partly*|*Cloudy*)  echo "☁" ;;
        *Rain*|*Drizzle*)   echo "☂" ;;
        *Snow*|*Sleet*)     echo "❄" ;;
        *Thunder*)          echo "⛈" ;;
        *Fog*|*Mist*)       echo "🌫" ;;
        *Overcast*)         echo "☁" ;;
        *)                  echo "☁" ;;
    esac
}

refresh() {
    local query="" name=""

    if [ -n "$OVERRIDE" ]; then
        query="$OVERRIDE"
        name="$OVERRIDE"
    else
        # ip-api.com geolocates the egress IP and returns a city name + coords
        # ("City|lat,lon"). More accurate than wttr.in's own IP geolocation.
        local geo
        geo=$(curl -sL --max-time "$TIMEOUT" \
              "http://ip-api.com/json/?fields=status,city,lat,lon" 2>/dev/null \
              | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if d.get("status") == "success" and d.get("city"):
    print("%s|%s,%s" % (d["city"], d["lat"], d["lon"]))
' 2>/dev/null)
        if [ -n "$geo" ]; then
            name="${geo%%|*}"
            query="${geo##*|}"
        fi
        # If geo failed, name/query stay empty → wttr.in auto-detect fallback.
    fi

    # wttr.in accepts "lat,lon" or a place name; spaces must be '+'.
    local wq="${query// /+}"
    local weather
    weather=$(curl -sL --max-time "$TIMEOUT" "wttr.in/${wq}?format=%C+%t&m" 2>/dev/null)
    if [ -z "$weather" ] || [[ "$weather" == *Unknown* ]]; then
        return 0
    fi

    # No name yet (geo failed) → let wttr.in name the auto-detected location.
    if [ -z "$name" ]; then
        name=$(curl -sL --max-time "$TIMEOUT" "wttr.in/${wq}?format=%l" 2>/dev/null)
    fi

    local temp
    temp=$(printf '%s' "$weather" | rev | cut -d' ' -f1 | rev | sed 's/^+//')

    # Atomic write so a concurrent reader never sees a half-written cache.
    printf '%s  %s %s\n' "$(icon_for "$weather")" "$temp" "$name" > "$CACHE.$$"
    mv -f "$CACHE.$$" "$CACHE"
    date +%s > "$LAST"
}

now=$(date +%s)
last=$(cat "$LAST" 2>/dev/null || echo 0)

if [ ! -f "$CACHE" ] || [ "$((now - last))" -ge "$INTERVAL" ]; then
    # Reap a stale lock left by a killed refresh (>2 min old) so we never wedge.
    if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
        rmdir "$LOCK" 2>/dev/null
    fi
    if [ -n "${TMUX_WEATHER_SYNC:-}" ]; then
        refresh
    elif mkdir "$LOCK" 2>/dev/null; then
        ( refresh; rmdir "$LOCK" 2>/dev/null ) >/dev/null 2>&1 &
    fi
fi

cat "$CACHE" 2>/dev/null || echo ""
