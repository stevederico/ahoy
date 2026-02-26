#!/bin/bash
# OpenCode setup for Ahoy — installs shell hooks and the OpenCode plugin.
# Usage: bash ahoy/opencode/setup.sh
set -e

# --- Helpers -----------------------------------------------------------

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ahoy]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ahoy]${NC} $1"; }
error() { echo -e "${RED}[ahoy]${NC} $1" >&2; }

# --- Preflight ---------------------------------------------------------

if [ "$(uname)" != "Darwin" ]; then
  error "Ahoy requires macOS (uses say, afplay, osascript)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
PLATFORMS_DIR="$HOOKS_DIR/platforms"
PLUGIN_DIR="$HOME/.config/opencode/plugins"

# --- TTS prompt --------------------------------------------------------

echo ""
info "Ahoy setup for OpenCode"
echo ""
read -rp "Enable voice & sound alerts? (y/n) [y]: " tts_choice
tts_choice=${tts_choice:-y}

# --- Install shell hooks -----------------------------------------------

info "Installing shell hooks to $HOOKS_DIR ..."

mkdir -p "$HOOKS_DIR" "$PLATFORMS_DIR" "$CLAUDE_DIR/cache/names"

HOOKS=(session-start.sh notification.sh pretooluse.sh prompt-submit.sh stop.sh session-end.sh)
for hook in "${HOOKS[@]}"; do
  src="$REPO_DIR/terminal/hooks/$hook"
  dst="$HOOKS_DIR/$hook"
  if [ -f "$dst" ]; then
    cp "$dst" "$dst.bak"
    warn "Backed up existing $hook → $hook.bak"
  fi
  cp "$src" "$dst"
  chmod +x "$dst"
done

PLATFORMS=(terminal.sh iterm.sh tmux.sh vscode.sh)
for plat in "${PLATFORMS[@]}"; do
  cp "$REPO_DIR/terminal/hooks/platforms/$plat" "$PLATFORMS_DIR/$plat"
  chmod +x "$PLATFORMS_DIR/$plat"
done

info "Hooks installed."

# --- Strip TTS if declined ---------------------------------------------

if [[ "$tts_choice" =~ ^[Nn] ]]; then
  warn "Stripping voice & sound lines from hooks ..."
  for hook in "${HOOKS[@]}"; do
    sed -i '' '/say /d; /afplay /d' "$HOOKS_DIR/$hook"
  done
fi

# --- Agent names -------------------------------------------------------

NAMES_FILE="$CLAUDE_DIR/agent-names.txt"
if [ ! -f "$NAMES_FILE" ]; then
  cp "$REPO_DIR/terminal/agent-names.txt" "$NAMES_FILE"
  info "Agent names installed to $NAMES_FILE"
else
  info "Agent names already present — skipping."
fi

# --- Install OpenCode plugin -------------------------------------------

info "Installing OpenCode plugin to $PLUGIN_DIR ..."

mkdir -p "$PLUGIN_DIR"
cp "$REPO_DIR/opencode/plugins/ahoy.js" "$PLUGIN_DIR/ahoy.js"

info "Plugin installed."

# --- Done --------------------------------------------------------------

echo ""
info "Setup complete! Start a new OpenCode session to try it out."
info "Uninstall with: bash ahoy/opencode/uninstall.sh"
echo ""
