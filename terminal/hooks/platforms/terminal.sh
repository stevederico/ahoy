#!/bin/bash
# Platform focus handler for Terminal.app
# Extracted from notification.sh — uses AppleScript to find and focus the correct tab

# platform_init — no-op for Terminal.app (no PID capture needed)
# @param $1 session_id
platform_init() {
  :
}

# platform_focus — AppleScript tab focus by matching custom title
# Iterates Terminal.app windows/tabs, finds the one whose title contains
# the agent label, and brings it to front.
# @param $1 label (agent name, already sanitized)
# @param $2 session_id
platform_focus() {
  local label="$1"
  osascript -e "tell application \"Terminal\"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      if custom title of t contains \"$label\" then
        set selected tab of w to t
        set frontmost of w to true
        return
      end if
    end repeat
  end repeat
end tell" 2>/dev/null
}
