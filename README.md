<p align="center">
  <img src="headline.jpg" alt="Ahoy">
</p>

# Ahoy

### auto-focus terminal tabs across multi-agent coding sessions

<br />

![ahoy-demo-3](https://github.com/user-attachments/assets/b8bfdc41-3dfd-4862-92c5-7813f69db7f6)

<br />

## Quick Start

### Claude Code

Two commands — works with Terminal.app, iTerm2, and tmux out of the box:

```bash
git clone https://github.com/stevederico/ahoy
bash ahoy/terminal/setup.sh
```

Start a new Claude Code session and you're good to go. Open multiple tabs, run agents in each, and Ahoy handles the rest.

### OpenCode

Same two-command pattern — reuses the same shell hooks:

```bash
git clone https://github.com/stevederico/ahoy
bash ahoy/opencode/setup.sh
```

The setup script installs the shell hooks to `~/.claude/hooks/` (shared with Claude Code) and copies the OpenCode plugin to `~/.config/opencode/plugins/ahoy.js`. OpenCode discovers plugins by filesystem — no config merge needed.

**Note:** OpenCode has no `UserPromptSubmit` equivalent, so TTS completion will say "completed task" instead of echoing the prompt text. All other features work identically.

<br />

## Features

- **Agent names** — each session gets a unique name (Monte, Bill, Mel, ...)
- **Tab states** — emoji prefixes show what each agent is doing: working, needs input, done
- **Auto-focus** — permission prompts bring the correct tab to front
- **Voice & sound alerts** — (optional) TTS speaks the agent name, Tink sound on prompts

<br />

## Terminal Compatibility

| Feature | Terminal.app | iTerm2 | tmux | VS Code |
|---------|:---:|:---:|:---:|:---:|
| Agent names | Yes | Yes | Yes | Yes |
| Emoji tab states | Yes | Yes | Yes | Yes |
| Voice & sound alerts | Yes | Yes | Yes | Yes |
| Auto-focus on permission prompt | AppleScript | AppleScript | tmux select-pane | Ahoy extension |

Agent names, emoji states, and TTS work everywhere — they use standard escape sequences and macOS built-ins. Auto-focus is platform-specific: Terminal.app and iTerm2 use AppleScript, tmux uses `select-window`/`select-pane`, and VS Code uses the Ahoy extension.

<br />

## How It Works

Ahoy uses six hooks that fire at different points in the agent lifecycle:

| Hook | When it fires | What it does |
|------|--------------|-------------|
| **SessionStart** | Session begins or resumes | Assigns agent name, sets terminal title, TTS greeting |
| **UserPromptSubmit** | User sends a message | Caches prompt text for TTS, resets title emoji |
| **PreToolUse** | Agent executes a tool | Clears the needs-input emoji, restores working state |
| **Notification** | Permission prompt appears | Plays sound, speaks agent name, auto-focuses tab |
| **Stop** | Agent finishes a turn | Sets done emoji, speaks "{name} completed {task}" |
| **SessionEnd** | Session closes | Cleans up temp files, releases agent name back to pool |

Platform handlers do the focus: AppleScript for Terminal.app/iTerm2, pane selection for tmux, file-watch for VS Code.

<br />

## Requirements

- macOS (uses `say`, `afplay`, `osascript`)
- A coding agent: [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [OpenCode](https://opencode.ai)

<br />

## What the Setup Script Does

1. Copies hook scripts to `~/.claude/hooks/`
2. Installs platform adapters for Terminal.app, iTerm2, tmux, and VS Code
3. Adds agent name pool to `~/.claude/agent-names.txt`
4. Merges hook config into `~/.claude/settings.json`
5. Disables the coding agent's built-in title management (prevents conflicts)
6. Asks if you want voice & sound alerts (optional)

Rerun `setup.sh` anytime to change your settings.

### VS Code Users

Terminal.app, iTerm2, and tmux work out of the box — no extra setup.

VS Code requires the Ahoy extension for auto-focus. Download the latest `.vsix` from [GitHub Releases](https://github.com/stevederico/ahoy/releases/latest) and install:

```bash
code --install-extension ahoy-*.vsix
```

### Manual Hook Setup

If you prefer to configure hooks manually instead of using the setup script, add these to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-start.sh" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/prompt-submit.sh" }] }
    ],
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/pretooluse.sh" }] }
    ],
    "Notification": [
      { "matcher": "permission_prompt", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/notification.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/stop.sh" }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-end.sh" }] }
    ]
  },
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

<br />

## Usage

Once installed, Ahoy works automatically:

1. Open multiple terminal tabs (or VS Code terminals)
2. Start coding agent sessions in different tabs
3. When Claude needs input, that tab automatically focuses

### Manual Focus (VS Code)

Command Palette → **Ahoy: Focus Terminal** to manually select a terminal.

<br />

## Customization

### Agent Names

Names are stored one per line in `~/.claude/agent-names.txt`. To add names, append to the file. To remove, delete the line. Active sessions keep their name until they end regardless of pool changes.

### Audio Toggle

Toggle voice and sound alerts without re-running setup:

| Command | What it does |
|---------|-------------|
| `bash ahoy/terminal/audio.sh off` | Mute — disables TTS and sound effects |
| `bash ahoy/terminal/audio.sh on` | Unmute — re-enables TTS and sound effects |
| `bash ahoy/terminal/audio.sh` | Interactive — detects current state and prompts to toggle |

Changes take effect on the next hook trigger — no restart needed.

### Terminal Title Conflict

Add `"env": { "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1" }` to your `~/.claude/settings.json` to prevent the coding agent's built-in title management from conflicting with the hooks. The setup script does this automatically.

### Adding a New Platform

Create `~/.claude/hooks/platforms/<name>.sh` exporting two functions:

- **`platform_init`** `$sid` — called once at session start (e.g., capture PID, register watcher)
- **`platform_focus`** `$label` `$sid` — called on permission prompts to bring the tab to front

Then add a case to the `$TERM_PROGRAM` switch in `notification.sh` and `session-start.sh`.

<br />

## Uninstall

### Claude Code

```bash
bash ahoy/terminal/uninstall.sh
```

This removes all hooks, restores any backups, and cleans up temp files.

### OpenCode

```bash
bash ahoy/opencode/uninstall.sh
```

This removes the OpenCode plugin only. Shell hooks in `~/.claude/hooks/` are left in place for Claude Code.

<br />

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

<br />

## License

MIT
