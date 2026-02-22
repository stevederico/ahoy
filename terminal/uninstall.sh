#!/bin/bash
# Ahoy Terminal Uninstall — removes Claude Code hooks
# Usage: bash terminal/uninstall.sh
set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }

echo ""
echo "  Ahoy Terminal Uninstall"
echo "  ═══════════════════════"
echo ""

# ── Remove hook scripts ──────────────────────────────────────────

for f in session-start.sh prompt-submit.sh pretooluse.sh notification.sh stop.sh session-end.sh; do
  if [ -f "$HOOKS_DIR/$f" ]; then
    rm "$HOOKS_DIR/$f"
    info "Removed hooks/$f"
  fi
  # Restore backup if one exists
  if [ -f "$HOOKS_DIR/$f.bak" ]; then
    mv "$HOOKS_DIR/$f.bak" "$HOOKS_DIR/$f"
    warn "Restored hooks/$f from backup"
  fi
done

# ── Remove platform modules ──────────────────────────────────────

rm -f "$HOOKS_DIR/platforms/terminal.sh" "$HOOKS_DIR/platforms/vscode.sh"
rmdir "$HOOKS_DIR/platforms" 2>/dev/null && info "Removed hooks/platforms/" || true

# ── Remove hooks from settings.json ──────────────────────────────

if [ -f "$SETTINGS_FILE" ]; then
  CLEANED=$(jq 'del(.hooks) | del(.env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE)' "$SETTINGS_FILE")
  echo "$CLEANED" > "$SETTINGS_FILE"
  info "Removed hook config from settings.json"
fi

# ── Clean up temp files ──────────────────────────────────────────

rm -f /tmp/claude_name_* /tmp/claude_prompt_* /tmp/claude_term_pid_* /tmp/claude_session_start.lock
info "Cleaned up temp files"

echo ""
echo "  Uninstall complete. agent-names.txt was left in place."
echo ""
