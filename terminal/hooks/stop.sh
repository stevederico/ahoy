#!/bin/bash
# Stop hook — fires when Claude finishes a turn
# Sets terminal title to ✅, speaks "{name} completed {task}"
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')
cwd=$(echo "$input" | jq -r '.cwd')
name=$(cat "/tmp/claude_name_${sid}" 2>/dev/null)
label=${name:-$(basename "$cwd")}

printf '\033]0;✅ %s\007' "$label" > /dev/tty 2>/dev/null
(task=$(cat "/tmp/claude_prompt_${sid}" 2>/dev/null); task=${task:0:40}
say "$label completed ${task:-task}") &
