#!/bin/bash
# Notification hook — fires on permission prompts
# Plays Tink sound, speaks agent name, sets terminal title to ⚠️
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')
cwd=$(echo "$input" | jq -r '.cwd')
name=$(cat "/tmp/claude_name_${sid}" 2>/dev/null)
label=${name:-$(basename "$cwd")}

# Sanitize label for AppleScript — strip quotes to prevent injection
label=${label//\"/}
label=${label//\'/}

printf '\033]0;⚠️ %s\007' "$label" > /dev/tty 2>/dev/null

# Source platform-specific focus handler
case "$TERM_PROGRAM" in
  Apple_Terminal) source ~/.claude/hooks/platforms/terminal.sh ;;
  vscode)         source ~/.claude/hooks/platforms/vscode.sh ;;
  iTerm.app)      source ~/.claude/hooks/platforms/iterm.sh ;;
esac

# TTS + sound (shared, all platforms)
# Platform-specific tab focus (no-op if platform unknown)
(if type platform_focus &>/dev/null; then
  platform_focus "$label" "$sid"
fi
afplay /System/Library/Sounds/Tink.aiff & say "$label") &
