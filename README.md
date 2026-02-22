<p align="center">
  <img src="headline.jpg" alt="Ahoy">
</p>

# Ahoy

Auto-focus terminal tabs across multi-agent Claude Code sessions. When an agent needs input, Ahoy finds the right tab and brings it to you.

![ahoy-demo-3](https://github.com/user-attachments/assets/b8bfdc41-3dfd-4862-92c5-7813f69db7f6)

## The Problem

Running multiple Claude Code sessions means juggling terminal tabs. When one agent pauses for permission, you're left hunting for which tab needs attention.

## The Solution

Ahoy gives each session a unique agent name, shows emoji states in tab titles, and auto-focuses the correct tab when Claude needs input.

## Terminal Compatibility

| Feature | Terminal.app | iTerm2 | VS Code |
|---------|:---:|:---:|:---:|
| Agent names | Yes | Yes | Yes |
| Emoji tab states (🔨 ⚠️ ✅) | Yes | Yes | Yes |
| Voice & sound alerts | Yes | Yes | Yes |
| Auto-focus on permission prompt | AppleScript | AppleScript | Ahoy extension |

Agent names, emoji states, and TTS work everywhere — they use standard escape sequences and macOS built-ins. Auto-focus is platform-specific: Terminal.app and iTerm2 use AppleScript to locate and select the matching tab; VS Code uses the Ahoy extension to focus the correct terminal panel.

## How It Works

1. **SessionStart hook** assigns a unique agent name and sets the terminal title
2. **Notification hook** triggers when Claude needs input — plays a sound, speaks the agent name, and auto-focuses the tab
3. **Platform handlers** do the focus: AppleScript for Terminal.app/iTerm2, file-watch for VS Code

## Installation

### 1. Install the Terminal Hooks

The `terminal/` folder includes the full hook system — agent names, emoji tab states, TTS, and auto-focus. Run the setup script:

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

### 2. VS Code Only: Install the Extension

If you use VS Code, also install the Ahoy extension for terminal auto-focus:

Download the latest `.vsix` from [GitHub Releases](https://github.com/stevederico/ahoy/releases/latest) and install:

```bash
code --install-extension ahoy-*.vsix
```

Terminal.app and iTerm2 users do **not** need the extension — auto-focus works via AppleScript.

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

1. Open multiple terminal tabs (or VS Code terminals)
2. Start Claude Code sessions in different tabs
3. When Claude needs input, that tab automatically focuses

### Manual Focus (VS Code)

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

## License

MIT
