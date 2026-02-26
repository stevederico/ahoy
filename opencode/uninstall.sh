#!/bin/bash
# Remove the Ahoy OpenCode plugin. Leaves shared shell hooks in place
# for Claude Code.
# Usage: bash ahoy/opencode/uninstall.sh
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ahoy]${NC} $1"; }
error() { echo -e "${RED}[ahoy]${NC} $1" >&2; }

PLUGIN="$HOME/.config/opencode/plugins/ahoy.js"

if [ -f "$PLUGIN" ]; then
  rm -f "$PLUGIN"
  info "Removed $PLUGIN"
else
  info "Plugin not found — nothing to remove."
fi

echo ""
info "OpenCode plugin uninstalled."
info "Shell hooks in ~/.claude/hooks/ were left in place for Claude Code."
echo ""
