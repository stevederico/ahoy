#!/bin/bash
# Ahoy Terminal Setup — installs Claude Code hooks for agent identity & focus
# Usage: bash terminal/setup.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
PLATFORMS_DIR="$HOOKS_DIR/platforms"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "  Ahoy Terminal Setup"
echo "  ═══════════════════"
echo ""

# ── Preflight checks ──────────────────────────────────────────────

# macOS only
[[ "$(uname)" == "Darwin" ]] || error "macOS required (uses say, afplay, osascript)"

# ── Options ───────────────────────────────────────────────────────

echo "  Voice & sound alerts play audio when agents need attention."
echo "  Examples: \"Hi, I'm Monte\", \"Monte completed fix login bug\""
echo ""
echo -n "  Enable voice & sound alerts? (y/n) "
read -r ENABLE_TTS
echo ""

# ── Create directories ────────────────────────────────────────────

mkdir -p "$HOOKS_DIR" "$PLATFORMS_DIR" "$CLAUDE_DIR/cache/names"

# ── Copy hook scripts ─────────────────────────────────────────────

for f in session-start.sh prompt-submit.sh pretooluse.sh notification.sh stop.sh session-end.sh; do
  if [ -f "$HOOKS_DIR/$f" ]; then
    warn "Backing up existing $f → $f.bak"
    cp "$HOOKS_DIR/$f" "$HOOKS_DIR/$f.bak"
  fi
  cp "$SCRIPT_DIR/hooks/$f" "$HOOKS_DIR/$f"
  chmod +x "$HOOKS_DIR/$f"
  info "Installed hooks/$f"
done

# ── Copy platform modules ────────────────────────────────────────

for f in terminal.sh vscode.sh iterm.sh tmux.sh; do
  cp "$SCRIPT_DIR/hooks/platforms/$f" "$PLATFORMS_DIR/$f"
  chmod +x "$PLATFORMS_DIR/$f"
  info "Installed hooks/platforms/$f"
done

# ── Strip TTS if declined ─────────────────────────────────────────

if [[ "$ENABLE_TTS" != "y" && "$ENABLE_TTS" != "Y" ]]; then
  # session-start.sh — remove TTS greeting block
  sed -i '' '/say "hi/d; /say "I'\''m/d' "$HOOKS_DIR/session-start.sh"
  # notification.sh — remove sound and voice
  sed -i '' '/afplay.*say/d' "$HOOKS_DIR/notification.sh"
  # stop.sh — remove voice announcement
  sed -i '' '/say "/d' "$HOOKS_DIR/stop.sh"
  info "TTS disabled — voice and sound removed from hooks"
else
  info "TTS enabled"
fi

# ── Copy agent names (only if not already present) ────────────────

if [ -f "$CLAUDE_DIR/agent-names.txt" ]; then
  warn "agent-names.txt already exists — skipping (keeping your custom names)"
else
  cp "$SCRIPT_DIR/agent-names.txt" "$CLAUDE_DIR/agent-names.txt"
  info "Installed agent-names.txt"
fi

# ── Merge hooks into settings.json ───────────────────────────────

HOOKS_CONFIG='{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/session-start.sh"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/prompt-submit.sh"}]}],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/pretooluse.sh"}]}],
    "Notification": [{"matcher": "permission_prompt", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/notification.sh"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/stop.sh"}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/session-end.sh"}]}]
  },
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
  # Backup existing settings
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
  warn "Backed up settings.json → settings.json.bak"

  # Deep merge: hook config wins for hook keys, preserves everything else
  MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOKS_CONFIG"))
  echo "$MERGED" > "$SETTINGS_FILE"
  info "Merged hooks into existing settings.json"
else
  echo "$HOOKS_CONFIG" | jq '.' > "$SETTINGS_FILE"
  info "Created settings.json with hook config"
fi

# ── Done ──────────────────────────────────────────────────────────

echo ""
echo "  Setup complete! Start a new Claude Code session to test."
echo ""
echo "  What you'll get:"
echo "    • Each session gets a unique agent name"
if [[ "$ENABLE_TTS" == "y" || "$ENABLE_TTS" == "Y" ]]; then
echo "    • Voice alerts speak agent name on events"
echo "    • Sound effect on permission prompts"
fi
echo "    • Terminal tabs show state: 🔨 working, ⚠️ needs input, ✅ done"
echo "    • Permission prompts auto-focus the correct tab"
echo "    • Works in Terminal.app, iTerm2, and VS Code (with Ahoy extension)"
echo ""
echo "  To change settings, rerun: bash $(dirname "$0")/setup.sh"
echo "  To uninstall: bash $(dirname "$0")/uninstall.sh"
echo ""
