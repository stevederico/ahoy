#!/bin/bash
# SessionEnd hook — fires when a session closes
# Cleans up temp files, releases agent name back to pool, resets terminal title
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')

# Reset terminal title to empty
printf '\033]0;\007' > /dev/tty 2>/dev/null

rm -f "/tmp/claude_name_${sid}" "/tmp/claude_prompt_${sid}" "/tmp/claude_term_pid_${sid}" "$HOME/.claude/cache/names/$sid"
