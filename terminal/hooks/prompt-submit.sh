#!/bin/bash
# UserPromptSubmit hook — fires when user sends a message
# Caches prompt for TTS, resets terminal title
umask 077
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')
prompt=$(echo "$input" | jq -r '.prompt')

echo "$prompt" > "/tmp/claude_prompt_${sid}"

# Reset terminal title to just the name (clear ✅/⚠️ emoji)
cwd=$(echo "$input" | jq -r '.cwd')
name=$(cat "/tmp/claude_name_${sid}" 2>/dev/null)
label=${name:-$(basename "$cwd")}
printf '\033]0;%s\007' "$label" > /dev/tty 2>/dev/null
