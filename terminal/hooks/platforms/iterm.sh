#!/bin/bash
# Platform focus handler for iTerm2
# Uses AppleScript to find and focus the correct tab/session by name

# platform_init — no-op for iTerm2 (no PID capture needed)
# @param $1 session_id
platform_init() {
  :
}

# platform_focus — AppleScript session focus by matching name
# Iterates iTerm2 windows → tabs → sessions, finds the one whose name
# contains the agent label, and brings it to front.
# @param $1 label (agent name, already sanitized)
# @param $2 session_id
platform_focus() {
  local label="$1"
  osascript -e "tell application \"iTerm\"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if name of s contains \"$label\" then
          select t
          select s
          return
        end if
      end repeat
    end repeat
  end repeat
end tell" 2>/dev/null
}
