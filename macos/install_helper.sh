#!/bin/zsh
set -eu

RESOURCE_DIR="${0:A:h}"
INSTALL_DIR="$HOME/Library/Application Support/VideoPocket"
LOG_DIR="$HOME/Library/Logs/VideoPocket"
AGENT_PATH="$HOME/Library/LaunchAgents/com.videopocket.helper.plist"
VENV_DIR="$INSTALL_DIR/.venv"
BREW_BIN=""

if [[ -x /opt/homebrew/bin/brew ]]; then BREW_BIN=/opt/homebrew/bin/brew; fi
if [[ -z "$BREW_BIN" && -x /usr/local/bin/brew ]]; then BREW_BIN=/usr/local/bin/brew; fi
if [[ -z "$BREW_BIN" ]]; then exit 20; fi

if ! command -v ffmpeg >/dev/null 2>&1; then "$BREW_BIN" install ffmpeg; fi
if ! command -v python3 >/dev/null 2>&1; then "$BREW_BIN" install python; fi

PYTHON_BIN="$(command -v python3)"
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"
cp "$RESOURCE_DIR/videopocket_helper.py" "$INSTALL_DIR/videopocket_helper.py"
"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip yt-dlp
"$VENV_DIR/bin/python" "$INSTALL_DIR/videopocket_helper.py" --init >/dev/null

sed \
  -e "s|__HELPER__|$INSTALL_DIR/videopocket_helper.py|g" \
  -e "s|__PYTHON__|$VENV_DIR/bin/python|g" \
  -e "s|__LOG_DIR__|$LOG_DIR|g" \
  "$RESOURCE_DIR/com.videopocket.helper.plist.template" > "$AGENT_PATH"

launchctl bootout "gui/$(id -u)/com.videopocket.helper" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PATH"
sleep 1
curl --silent --fail http://127.0.0.1:17839/health >/dev/null
