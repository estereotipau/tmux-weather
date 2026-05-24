#!/usr/bin/env bash
# Symlink tmux-weather.sh into ~/.local/bin so `git pull` updates it in place.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/tmux-weather.sh"
DEST="${HOME}/.local/bin"

mkdir -p "$DEST"
chmod +x "$SRC"
ln -sf "$SRC" "$DEST/tmux-weather.sh"

echo "Linked $DEST/tmux-weather.sh -> $SRC"
echo
echo "Add to ~/.tmux.conf:"
echo '  set -g status-right "#(~/.local/bin/tmux-weather.sh)"'
echo "Then: tmux source-file ~/.tmux.conf"
