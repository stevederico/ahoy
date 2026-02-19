<p align="center">
  <img src="icon.png" width="128" height="128" alt="Ahoy">
</p>

# Ahoy

A VS Code extension that focuses the correct terminal tab when Claude Code needs input.

## The Problem

When running multiple Claude Code sessions in different VS Code terminals, it's hard to know which terminal needs your attention. VS Code doesn't provide a way to programmatically highlight or focus a specific terminal tab.

## The Solution

Ahoy tracks which terminal each Claude Code session is running in and automatically focuses that terminal when Claude needs input.

## How It Works

1. **SessionStart hook** captures the terminal's shell PID when you start a Claude Code session
2. **Notification hook** writes the PID to a watch file when Claude needs input
3. **Ahoy extension** watches the file and focuses the matching terminal

## Installation

### Install the Extension

```bash
code --install-extension ahoy-1.0.0.vsix
```

Or install from source:

```bash
cd ahoy
npm install
npm run compile
npm run package
code --install-extension ahoy-1.0.0.vsix
```

### Configure Claude Code Hooks

Add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_start_$$; (cwd=$(jq -r .cwd < /tmp/claude_start_$$); sid=$(jq -r .session_id < /tmp/claude_start_$$); termpid=$(ps -o ppid= -p $PPID | tr -d ' '); echo \"pid:$termpid\" > /tmp/claude_term_pid_${sid}; rm /tmp/claude_start_$$) &"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_hook_$$; sid=$(jq -r .session_id < /tmp/claude_hook_$$); (if [ -f /tmp/claude_term_pid_${sid} ]; then cat /tmp/claude_term_pid_${sid} > /tmp/claude-terminal-focus; fi; rm /tmp/claude_hook_$$) &"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_stop_$$; sid=$(jq -r .session_id < /tmp/claude_stop_$$); (if [ -f /tmp/claude_term_pid_${sid} ]; then cat /tmp/claude_term_pid_${sid} > /tmp/claude-terminal-focus; fi; rm /tmp/claude_stop_$$) &"
          }
        ]
      }
    ]
  }
}
```

## Usage

Once installed, Ahoy works automatically:

1. Open multiple terminals in VS Code
2. Start Claude Code sessions in different terminals
3. When Claude needs input, that terminal automatically focuses

### Manual Focus

Command Palette → **Ahoy: Focus Terminal** to manually select a terminal.

### Optional: Add Sound and Voice (macOS)

Want audio alerts? Here are the hooks with sound and voice:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_start_$$; (cwd=$(jq -r .cwd < /tmp/claude_start_$$); sid=$(jq -r .session_id < /tmp/claude_start_$$); termpid=$(ps -o ppid= -p $PPID | tr -d ' '); echo \"pid:$termpid\" > /tmp/claude_term_pid_${sid}; say \"$(basename \"$cwd\")\"; rm /tmp/claude_start_$$) &"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_hook_$$; cwd=$(jq -r .cwd < /tmp/claude_hook_$$); sid=$(jq -r .session_id < /tmp/claude_hook_$$); (if [ -f /tmp/claude_term_pid_${sid} ]; then cat /tmp/claude_term_pid_${sid} > /tmp/claude-terminal-focus; fi; afplay /System/Library/Sounds/Tink.aiff & say \"$(basename \"$cwd\")\"; rm /tmp/claude_hook_$$) &"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat > /tmp/claude_stop_$$; cwd=$(jq -r .cwd < /tmp/claude_stop_$$); sid=$(jq -r .session_id < /tmp/claude_stop_$$); (if [ -f /tmp/claude_term_pid_${sid} ]; then cat /tmp/claude_term_pid_${sid} > /tmp/claude-terminal-focus; fi; say \"$(basename \"$cwd\") done\"; rm /tmp/claude_stop_$$) &"
          }
        ]
      }
    ]
  }
}
```

**What you get:**
- **SessionStart**: Voice says project name
- **Notification**: Tink sound + voice says project name
- **Stop**: Voice says "[project] done"

## API

Write to `/tmp/claude-terminal-focus` to focus a terminal:

```bash
# Focus by PID
echo "pid:12345" > /tmp/claude-terminal-focus

# Focus by terminal name
echo "name:my-terminal" > /tmp/claude-terminal-focus

# Focus by index (1-based)
echo "index:3" > /tmp/claude-terminal-focus

# Focus with VS Code notification toast
echo "pid:12345:notify" > /tmp/claude-terminal-focus
```

## Requirements

- VS Code 1.85.0+
- macOS (uses `ps` command for PID lookup)
- `jq` installed (`brew install jq`)

## License

MIT
