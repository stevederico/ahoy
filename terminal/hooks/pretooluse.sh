#!/bin/bash
# PreToolUse hook — clears ⚠️ emoji from terminal title when tool executes
input=$(cat)
eval "$(echo "$input" | jq -r '@sh "sid=\(.session_id) cwd=\(.cwd)"')"
name=$(cat "/tmp/claude_name_${sid}" 2>/dev/null)
label=${name:-$(basename "$cwd")}
printf '\033]0;🔨 %s\007' "$label" > /dev/tty 2>/dev/null
