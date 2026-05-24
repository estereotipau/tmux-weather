# tmux-weather

Weather in your tmux status bar — cached, auto-located, zero-config.

A tiny shell script that shows the current condition, temperature and your
city in the tmux status bar. It auto-detects your location from your IP, so
it just works on a laptop, a remote server over SSH, or anywhere else —
no API keys, no coordinates to hardcode.

```
☀  12°C Buenos Aires
```

## Features

- **Zero config** — no API keys, no account, no coordinates to set.
- **Auto-located** — derives your location from your IP via [wttr.in].
- **Robust place names** — if wttr.in returns raw coordinates (a regression
  it occasionally exhibits), it reverse-geocodes them to a real city name
  via [Nominatim] / OpenStreetMap.
- **Cached** — hits the network at most once every 10 minutes (configurable),
  so it never blocks your status bar redraw.
- **Localized** — place names in your language (Spanish by default).

## Requirements

`bash`, `curl`, and `python3` (used to parse the geocoding response — no `jq`
needed). All present by default on most Linux distributions.

## Install

```sh
git clone https://github.com/estereotipau/tmux-weather.git
cd tmux-weather
./install.sh
```

`install.sh` symlinks the script into `~/.local/bin/`. To update later:
`git pull` — the symlink keeps pointing at the new version.

## Wire it into tmux

Add to `~/.tmux.conf`:

```tmux
set -g status-right "#(~/.local/bin/tmux-weather.sh)"
```

Then reload: `tmux source-file ~/.tmux.conf`.

## Configuration

All optional, via environment variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `TMUX_WEATHER_INTERVAL` | `600` | Seconds between network refreshes |
| `TMUX_WEATHER_LANG` | `es` | Language for place names |
| `TMUX_WEATHER_CACHE` | `/tmp/.tmux-weather-data` | Cache file path |
| `TMUX_WEATHER_LAST` | `/tmp/.tmux-weather-last` | Refresh-timestamp file path |

## How it works

1. Asks wttr.in for `condition + temperature` and for the IP-based location.
2. If the location comes back as raw `lat,lon`, it reverse-geocodes it with
   Nominatim and picks the most specific available name
   (`city → town → village → … → state`).
3. Writes `icon temp place` to a cache file and prints it. Subsequent calls
   within the refresh window just print the cache — instant, offline-safe.

## Credits

Weather by [wttr.in]. Reverse geocoding by [Nominatim] (© OpenStreetMap
contributors). Please respect their usage policies — the built-in 10-minute
cache keeps this well within fair use.

## License

[MIT](LICENSE) © Ezequiel Guerra

[wttr.in]: https://github.com/chubin/wttr.in
[Nominatim]: https://nominatim.org/
