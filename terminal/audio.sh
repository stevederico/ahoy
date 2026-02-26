#!/bin/bash
# Toggle Ahoy audio (TTS and sound effects) in installed hooks.
# Usage: bash ahoy/terminal/audio.sh [on|off]
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ahoy]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ahoy]${NC} $1"; }
error() { echo -e "${RED}[ahoy]${NC} $1" >&2; }

HOOKS_DIR="$HOME/.claude/hooks"
HOOKS=(session-start.sh notification.sh stop.sh)
MARKER="#AHOY_MUTED# "

# --- Detect current state ----------------------------------------------

has_active=false
has_muted=false
for hook in "${HOOKS[@]}"; do
  f="$HOOKS_DIR/$hook"
  [ -f "$f" ] || continue
  grep -q "${MARKER}" "$f" 2>/dev/null && has_muted=true
  grep -qE '(^|[^#])say |afplay ' "$f" 2>/dev/null && has_active=true
done

# --- Resolve action ----------------------------------------------------

action="$1"
if [ -z "$action" ]; then
  if $has_muted; then
    info "Audio is currently OFF."
    read -rp "Turn audio on? (y/n) [y]: " choice
    [[ "${choice:-y}" =~ ^[Yy] ]] && action="on" || exit 0
  else
    info "Audio is currently ON."
    read -rp "Turn audio off? (y/n) [y]: " choice
    [[ "${choice:-y}" =~ ^[Yy] ]] && action="off" || exit 0
  fi
fi

# --- Apply -------------------------------------------------------------

case "$action" in
  off)
    for hook in "${HOOKS[@]}"; do
      f="$HOOKS_DIR/$hook"
      [ -f "$f" ] || continue
      sed -i '' "s|^\(.*say \)|${MARKER}\1|; s|^\(.*afplay \)|${MARKER}\1|" "$f"
    done
    info "Audio disabled."
    ;;
  on)
    for hook in "${HOOKS[@]}"; do
      f="$HOOKS_DIR/$hook"
      [ -f "$f" ] || continue
      sed -i '' "s|${MARKER}||g" "$f"
    done
    info "Audio enabled."
    ;;
  *)
    error "Usage: bash ahoy/terminal/audio.sh [on|off]"
    exit 1
    ;;
esac
