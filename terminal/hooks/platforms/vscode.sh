#!/bin/bash
# Platform focus handler for VS Code integrated terminal
# Integrates with Ahoy extension's PID-based file watcher at /tmp/claude-terminal-focus

# platform_init — capture terminal shell PID for Ahoy extension
# Writes PID to /tmp/claude_term_pid_<sid> for later use by platform_focus.
# @param $1 session_id
platform_init() {
  local sid="$1"
  local term_pid
  term_pid=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ')
  if [ -n "$term_pid" ]; then
    echo "$term_pid" > "/tmp/claude_term_pid_${sid}"
  fi
}

# platform_focus — write focus request to Ahoy file watcher
# The Ahoy VS Code extension watches /tmp/claude-terminal-focus and focuses
# the terminal whose shell PID matches.
# @param $1 label (agent name)
# @param $2 session_id
platform_focus() {
  local label="$1"
  local sid="$2"
  local pid_file="/tmp/claude_term_pid_${sid}"
  local focus_file="/tmp/claude-terminal-focus"

  if [ -f "$pid_file" ]; then
    local term_pid
    term_pid=$(cat "$pid_file" 2>/dev/null)
    if [ -n "$term_pid" ]; then
      echo "pid:${term_pid}:label:${label}:notify" > "$focus_file"
    fi
  fi
}
