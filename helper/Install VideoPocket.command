#!/bin/zsh
set -eu

SOURCE_DIR="${0:A:h}"
INSTALL_DIR="$HOME/Library/Application Support/VideoPocket"
LOG_DIR="$HOME/Library/Logs/VideoPocket"
AGENT_PATH="$HOME/Library/LaunchAgents/com.videopocket.helper.plist"
VENV_DIR="$INSTALL_DIR/.venv"

echo ""
echo "VideoPocket for Mac"
echo "───────────────────"
echo "Installing the private local helper…"

BREW_BIN="$(command -v brew || true)"
if [[ -z "$BREW_BIN" ]]; then
  osascript -e 'display dialog "VideoPocket needs Homebrew for its private video tools. Install Homebrew, then run this installer again." buttons {"Open Homebrew Website"} default button 1 with title "VideoPocket"'
  open "https://brew.sh"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  "$BREW_BIN" install python
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Installing the video converter…"
  "$BREW_BIN" install ffmpeg
fi

PYTHON_BIN="$(command -v python3)"
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"
cp "$SOURCE_DIR/videopocket_helper.py" "$INSTALL_DIR/videopocket_helper.py"

echo "Preparing VideoPocket's isolated environment…"
"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip yt-dlp
"$VENV_DIR/bin/python" "$INSTALL_DIR/videopocket_helper.py" --init >/dev/null

sed \
  -e "s|__HELPER__|$INSTALL_DIR/videopocket_helper.py|g" \
  -e "s|__PYTHON__|$VENV_DIR/bin/python|g" \
  -e "s|__LOG_DIR__|$LOG_DIR|g" \
  "$SOURCE_DIR/com.videopocket.helper.plist.template" > "$AGENT_PATH"

launchctl bootout "gui/$(id -u)/com.videopocket.helper" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PATH"
sleep 1

if curl --silent --fail http://127.0.0.1:17839/health >/dev/null; then
  echo ""
  echo "✓ VideoPocket is installed and running."
  echo "  You may now close this window."
  osascript -e 'display notification "The Chrome extension will pair automatically." with title "VideoPocket is ready"'
else
  echo "Installation finished, but the helper did not respond."
  echo "See: $LOG_DIR/error.log"
  read -k 1 "?Press any key to close."
  exit 1
fi
