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

- **Zero config** — no API keys, no account, nothing to set up.
- **Auto-located** — finds your city from your egress IP via [ip-api.com],
  then fetches the weather for *that* location, so the temperature matches
  the place shown.
- **Override when you need it** — set `TMUX_WEATHER_LOCATION` on any host
  whose IP geolocation is off (datacenter / mobile / coarse ISP).
- **Never blocks** — the network refresh runs in the background behind an
  atomic lock, so your status bar redraw is always instant, even on slow
  links, and refreshes never pile up.
- **Cached** — hits the network at most once every 10 minutes (configurable).
- **Localized** — place names come straight from the geolocation provider.

## Requirements

`bash`, `curl`, and `python3` (used to parse the geolocation JSON — no `jq`
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
| `TMUX_WEATHER_LOCATION` | _(unset)_ | Force a place (e.g. `"San Nicolas de los Arroyos"`); skips IP geolocation |
| `TMUX_WEATHER_INTERVAL` | `600` | Seconds between network refreshes |
| `TMUX_WEATHER_TIMEOUT` | `10` | Per-request curl timeout, in seconds |
| `TMUX_WEATHER_CACHE` | `/tmp/.tmux-weather-data` | Cache file path |
| `TMUX_WEATHER_LAST` | `/tmp/.tmux-weather-last` | Refresh-timestamp file path |
| `TMUX_WEATHER_LOCK` | `/tmp/.tmux-weather.lock` | Lock directory path |

To pin a location, export the variable wherever tmux is launched (e.g. in
`~/.bashrc` / `~/.zshrc` on that host):

```sh
export TMUX_WEATHER_LOCATION="San Nicolas de los Arroyos"
```

## How it works

1. Resolves your location: `TMUX_WEATHER_LOCATION` if set, otherwise
   [ip-api.com] geolocates your egress IP to a city + coordinates.
2. Asks [wttr.in] for the condition and temperature **at those coordinates**,
   so the weather always matches the displayed place.
3. Writes `icon temp place` to a cache file atomically. The refresh happens
   in a background process behind a lock; the foreground call just prints the
   cache — instant, and offline-safe between refreshes.

If geolocation ever fails, it falls back to wttr.in's own IP-based detection.

## Credits

Geolocation by [ip-api.com]. Weather by [wttr.in]. Please respect their usage
policies — the built-in 10-minute cache keeps this well within fair use.

## License

[MIT](LICENSE) © Ezequiel Guerra

[ip-api.com]: https://ip-api.com/
[wttr.in]: https://github.com/chubin/wttr.in
