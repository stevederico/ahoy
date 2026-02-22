#!/bin/bash
# Platform focus handler for tmux
# Uses tmux pane IDs to select the correct pane on permission prompts

# platform_init — capture tmux pane ID for later focus
# Writes pane ID to /tmp/claude_tmux_pane_<sid>.
# @param $1 session_id
platform_init() {
  local sid="$1"
  local pane_id
  pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
  if [ -n "$pane_id" ]; then
    echo "$pane_id" > "/tmp/claude_tmux_pane_${sid}"
  fi
}

# platform_focus — select the tmux window and pane that owns this session
# @param $1 label (agent name)
# @param $2 session_id
platform_focus() {
  local label="$1"
  local sid="$2"
  local pane_file="/tmp/claude_tmux_pane_${sid}"

  if [ -f "$pane_file" ]; then
    local pane_id
    pane_id=$(cat "$pane_file" 2>/dev/null)
    if [ -n "$pane_id" ]; then
      tmux select-window -t "$pane_id" 2>/dev/null
      tmux select-pane -t "$pane_id" 2>/dev/null
    fi
  fi
}
