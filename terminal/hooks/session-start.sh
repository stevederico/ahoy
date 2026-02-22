#!/bin/bash
# SessionStart hook — fires when a session begins or resumes
# Assigns agent name from pool, sets terminal title, TTS greeting
umask 077

# Sweep stale name cache files older than 7 days
find "$HOME/.claude/cache/names" -type f -mtime +7 -delete 2>/dev/null

# Guard: prevent recursive spawning
# Kill with: pkill -f "session-start.sh"; rm -f /tmp/claude_session_start.lock /tmp/claude_name_*
LOCKFILE="/tmp/claude_session_start.lock"
if [ -f "$LOCKFILE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt 30 ]; then
    exit 0
  fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
sid=$(echo "$input" | jq -r '.session_id')
tp=$(echo "$input" | jq -r '.transcript_path')

# Persistent name store (survives /compact, /clear, reboots)
NAMES_DIR="$HOME/.claude/cache/names"
mkdir -p "$NAMES_DIR"

# Check for existing name: persistent cache → temp file → transcript fallback
existing=""
if [ -f "$NAMES_DIR/$sid" ]; then
  existing=$(cat "$NAMES_DIR/$sid")
elif [ -f "/tmp/claude_name_${sid}" ]; then
  existing=$(cat "/tmp/claude_name_${sid}")
elif [ -f "$tp" ]; then
  existing=$(grep '"agent-name"' "$tp" 2>/dev/null | tail -1 | jq -r .agentName 2>/dev/null)
  [ "$existing" = "null" ] && existing=""
fi

if [ -n "$existing" ]; then
  echo "$existing" > "/tmp/claude_name_${sid}"
  echo "$existing" > "$NAMES_DIR/$sid"
  resumed=1
else
  # Get names already taken by other sessions
  taken=$(cat /tmp/claude_name_* 2>/dev/null)

  # Pick a random available name from the pool
  name=$(while IFS= read -r n; do
    [ -n "$n" ] && echo "$n"
  done < ~/.claude/agent-names.txt | while IFS= read -r n; do
    echo "$taken" | grep -qx "$n" || echo "$n"
  done | awk 'BEGIN{srand()}{lines[NR]=$0}END{print lines[int(rand()*NR)+1]}')

  [ -z "$name" ] && name="Agent-$$"
  echo "$name" > "/tmp/claude_name_${sid}"
  echo "$name" > "$NAMES_DIR/$sid"
  resumed=0
fi

label=$(cat "/tmp/claude_name_${sid}")

# Set terminal title
printf '\033]0;%s\007' "$label" > /dev/tty 2>/dev/null

# Platform-specific init (e.g., PID capture for VS Code Ahoy extension)
case "$TERM_PROGRAM" in
  Apple_Terminal) source ~/.claude/hooks/platforms/terminal.sh ;;
  vscode)         source ~/.claude/hooks/platforms/vscode.sh ;;
esac
if type platform_init &>/dev/null; then
  platform_init "$sid"
fi

# Inject name into conversation
echo "Your name is $label. Introduce yourself by this name when you first respond."

# TTS greeting in background
(if [ "$resumed" = "0" ]; then
  say "hi, I'm $label"
else
  say "I'm $label, welcome back"
fi) &
