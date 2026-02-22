<p align="center">
  <img src="headline.jpg" alt="Ahoy">
</p>

# Ahoy

A VS Code extension that focuses the correct terminal tab when Claude Code needs input.

![ahoy-demo-3](https://github.com/user-attachments/assets/b8bfdc41-3dfd-4862-92c5-7813f69db7f6)

## The Problem

When running multiple Claude Code sessions in different VS Code terminals, it's hard to know which terminal needs your attention. VS Code doesn't provide a way to programmatically highlight or focus a specific terminal tab.

## The Solution

Ahoy tracks which terminal each Claude Code session is running in and automatically focuses that terminal when Claude needs input.

## How It Works

1. **SessionStart hook** captures the terminal's shell PID when you start a Claude Code session
2. **Notification hook** writes the PID to a watch file when Claude needs input
3. **Ahoy extension** watches the file and focuses the matching terminal

## Installation

### 1. Install the Extension

Download the latest `.vsix` from [GitHub Releases](https://github.com/stevederico/ahoy/releases/latest) and install:

```bash
code --install-extension ahoy-*.vsix
```

### 2. Install the Terminal Hooks

The `terminal/` folder includes a full hook system that gives each Claude Code session a unique agent name, emoji tab states, and auto-focus. Run the setup script:

```bash
git clone https://github.com/stevederico/ahoy
bash ahoy/terminal/setup.sh
```

The setup will ask if you want voice & sound alerts:

```
  Voice & sound alerts play audio when agents need attention.
  Examples: "Hi, I'm Monte", "Monte completed fix login bug"

  Enable voice & sound alerts? (y/n)
```

You can rerun `setup.sh` anytime to change your settings.

**What gets installed:**

| Feature | Description |
|---------|-------------|
| Agent names | Each session gets a unique name (Monte, Bill, Mel, ...) |
| Tab states | 🔨 working, ⚠️ needs input, ✅ done |
| Auto-focus | Permission prompts focus the correct terminal tab |
| Voice alerts | (optional) TTS speaks agent name and task completion |
| Sound alerts | (optional) Tink sound on permission prompts |

**Works in both Terminal.app and VS Code.** In Terminal.app, focus uses AppleScript. In VS Code, focus uses the Ahoy extension.

### Manual Hook Setup

If you prefer to configure hooks manually instead of using the setup script, add these to `~/.claude/settings.json`:

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

This is the minimal setup — just PID capture and focus, no agent names or TTS.

## Usage

Once installed, Ahoy works automatically:

1. Open multiple terminals in VS Code
2. Start Claude Code sessions in different terminals
3. When Claude needs input, that terminal automatically focuses

### Manual Focus

Command Palette → **Ahoy: Focus Terminal** to manually select a terminal.

## Uninstall

```bash
bash ahoy/terminal/uninstall.sh
```

This removes all hooks, restores any backups, and cleans up temp files.

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

# Focus with agent label and notification
echo "pid:12345:label:Monte:notify" > /tmp/claude-terminal-focus
```

## Requirements

- macOS
- VS Code 1.85.0+

## License

MIT
