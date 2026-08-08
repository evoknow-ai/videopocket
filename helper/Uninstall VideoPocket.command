#!/bin/zsh
set -eu
INSTALL_DIR="$HOME/Library/Application Support/VideoPocket"
AGENT_PATH="$HOME/Library/LaunchAgents/com.videopocket.helper.plist"
launchctl bootout "gui/$(id -u)/com.videopocket.helper" 2>/dev/null || true
if [[ -d "$INSTALL_DIR" ]]; then mv "$INSTALL_DIR" "$HOME/.Trash/VideoPocket Helper $(date +%s)"; fi
if [[ -f "$AGENT_PATH" ]]; then mv "$AGENT_PATH" "$HOME/.Trash/com.videopocket.helper.plist"; fi
osascript -e 'display notification "The local helper was moved to Trash." with title "VideoPocket removed"'
echo "VideoPocket helper was removed. Downloads were left untouched."
