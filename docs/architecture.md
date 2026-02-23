# Agent Identity & Awareness System

A hook-based system that gives each Claude Code session a persistent human name, spoken audio feedback, and terminal tab management. When running multiple agents in parallel, each gets a unique identity — you can hear which agent needs attention, see its state at a glance in the terminal tab bar, and the correct tab auto-focuses on permission prompts.

## Architecture

```
~/.claude/
├── settings.json          # Hook registration (which events fire which scripts)
├── agent-names.txt        # Name pool (Bill, Mel, Carl, Monte, ...)
├── ahoy-terminal.md       # This document
├── cache/names/<sid>      # Persistent name store (survives /compact, /clear, reboot)
└── hooks/
    ├── session-start.sh   # Assign name, greet via TTS, platform init
    ├── prompt-submit.sh   # Cache prompt text, reset title
    ├── pretooluse.sh      # Set title to working state
    ├── notification.sh    # Alert, platform focus, speak name
    ├── stop.sh            # Announce completion via TTS
    ├── session-end.sh     # Cleanup, reset terminal title
    └── platforms/         # Modular focus handlers per terminal
        ├── terminal.sh    # Terminal.app — AppleScript tab focus
        └── vscode.sh      # VS Code — Ahoy PID-file integration

/tmp/
├── claude_name_<sid>           # Runtime name (fast reads, volatile)
├── claude_prompt_<sid>         # Last user prompt (for TTS on completion)
├── claude_term_pid_<sid>       # Terminal shell PID (VS Code only)
├── claude-terminal-focus       # Ahoy extension file watcher (VS Code only)
└── claude_session_start.lock   # Recursion guard
```

## Platform Detection

The focus mechanism (how the correct terminal tab is brought to front) varies by platform. Detection uses `$TERM_PROGRAM`, which is set by the host terminal and inherited by hook subprocesses:

| `$TERM_PROGRAM` | Terminal | Focus Strategy |
|---|---|---|
| `Apple_Terminal` | Terminal.app | AppleScript — find tab by title, activate window |
| `vscode` | VS Code | Ahoy extension — write PID to `/tmp/claude-terminal-focus` |
| `iTerm.app` | iTerm2 | (future) |
| `WarpTerminal` | Warp | (future) |
| *(unrecognized)* | Any | No focus attempt — TTS and sound still fire |

Escape codes for terminal titles (`\033]0;...\007`) work in all terminals, so emoji tab states are universal and need no platform branching.

### Adding a New Platform

Create `~/.claude/hooks/platforms/<name>.sh` exporting two functions:

- **`platform_init`** `$sid` — called once at session start (e.g., capture PID, register watcher)
- **`platform_focus`** `$label` `$sid` — called on permission prompts to bring the tab to front

Then add a case to the `$TERM_PROGRAM` switch in `notification.sh` and `session-start.sh`.

## Lifecycle

### 1. Session Start (`session-start.sh`)

Triggered by the `SessionStart` hook event.

1. **Sweep stale cache** — deletes `~/.claude/cache/names/*` files older than 7 days (orphan cleanup for crashed sessions)
2. **Recursion guard** — lockfile at `/tmp/claude_session_start.lock` prevents re-entrant spawning; auto-expires after 30 seconds
3. **Resolve name** — checks three sources in order:
   - `~/.claude/cache/names/<sid>` (persistent, survives reboots)
   - `/tmp/claude_name_<sid>` (volatile, current boot only)
   - Transcript file grep for `"agent-name"` JSON (last resort recovery)
4. **Assign new name** (if no existing name found):
   - Reads `~/.claude/agent-names.txt` for the pool
   - Excludes names already claimed by other sessions (via `/tmp/claude_name_*`)
   - Picks randomly from remaining names via `awk srand()`
   - Falls back to `Agent-<PID>` if pool exhausted
5. **Write name** to both `/tmp/claude_name_<sid>` (fast runtime access) and `~/.claude/cache/names/<sid>` (persistence)
6. **Set terminal tab title** to the name
7. **Platform init** — sources the platform module and calls `platform_init "$sid"` (e.g., VS Code captures terminal PID)
8. **Inject identity** — outputs `"Your name is <name>. Introduce yourself..."` which Claude sees as a system reminder
9. **TTS greeting** — `say "hi, I'm <name>"` (new) or `say "I'm <name>, welcome back"` (resumed)

### 2. User Sends a Message (`prompt-submit.sh`)

Triggered by the `UserPromptSubmit` hook event.

1. Caches the prompt text to `/tmp/claude_prompt_<sid>` (used later by `stop.sh` for TTS)
2. Resets terminal title to just the name (clears any emoji state like `✅` or `⚠️`)

### 3. Tool Execution (`pretooluse.sh`)

Triggered by the `PreToolUse` hook event — fires on every tool call.

1. Sets terminal title to `🔨 <name>` — indicates the agent is actively working
2. Optimized to a single `jq` call since this runs on the hot path (every Read, Write, Bash, Grep, etc.)

### 4. Permission Prompt (`notification.sh`)

Triggered by the `Notification` hook event with `permission_prompt` matcher.

1. Sets terminal title to `⚠️ <name>` — agent is blocked, needs approval
2. **Sources platform module** via `$TERM_PROGRAM` case switch
3. **Platform-specific tab focus** — calls `platform_focus "$label" "$sid"` (AppleScript for Terminal.app, PID file for VS Code, no-op for unknown terminals)
4. Plays the system `Tink.aiff` alert sound
5. Speaks the agent name via `say` so you hear which agent needs you

### 5. Turn Complete (`stop.sh`)

Triggered by the `Stop` hook event.

1. Sets terminal title to `✅ <name>` — agent finished its turn
2. Reads the cached prompt from `/tmp/claude_prompt_<sid>`
3. Speaks `"<name> completed <first 40 chars of prompt>"` via TTS
4. Uses bash substring `${task:0:40}` instead of `cut` to avoid splitting multibyte UTF-8

### 6. Session End (`session-end.sh`)

Triggered by the `SessionEnd` hook event.

1. Resets terminal title to empty (clears any lingering emoji/name)
2. Removes `/tmp/claude_name_<sid>`, `/tmp/claude_prompt_<sid>`, `/tmp/claude_term_pid_<sid>`, and `~/.claude/cache/names/<sid>`
3. This releases the name back to the pool for future sessions

## Terminal Tab States

| Icon | Meaning | Set By |
|------|---------|--------|
| (none) | Idle / waiting for input | `prompt-submit.sh` |
| 🔨 | Working (executing a tool) | `pretooluse.sh` |
| ⚠️ | Blocked on permission prompt | `notification.sh` |
| ✅ | Turn complete | `stop.sh` |
| (empty) | Session ended | `session-end.sh` |

## Data Flow

```
SessionStart ──→ assign name ──→ write /tmp + cache ──→ platform_init ──→ TTS "hi"
                                        │
UserPromptSubmit ──→ cache prompt ──→ reset title
                                        │
PreToolUse ──→ title "🔨 name" ◄────────┘ (reads /tmp for name)
                    │
Notification ──→ title "⚠️ name" ──→ platform_focus ──→ TTS + sound
                    │
Stop ──→ title "✅ name" ──→ TTS "name completed task"
                    │
SessionEnd ──→ title "" ──→ rm /tmp files + cache
```

## Platform Modules

### Terminal.app (`platforms/terminal.sh`)

- **`platform_init`** — no-op
- **`platform_focus`** — AppleScript that iterates `Terminal.app` windows/tabs, matches the tab whose `custom title` contains the agent label, selects it and brings the window to front. Label is pre-sanitized (quotes stripped) to prevent AppleScript injection.

### VS Code (`platforms/vscode.sh`)

- **`platform_init`** — captures the terminal shell PID via `ps -o ppid= -p $PPID` and writes it to `/tmp/claude_term_pid_<sid>`. This PID is used by the Ahoy extension to identify which terminal panel belongs to this session.
- **`platform_focus`** — writes `pid:<PID>:label:<name>:notify` to `/tmp/claude-terminal-focus`. The Ahoy extension watches this file and focuses the matching terminal panel in VS Code.

## Security

- **`umask 077`** on `session-start.sh` and `prompt-submit.sh` — `/tmp` files are owner-read-only
- **AppleScript injection prevention** — `notification.sh` strips `"` and `'` from the label before interpolating into AppleScript
- **`CLAUDE_CODE_DISABLE_TERMINAL_TITLE`** is set in `settings.json` to prevent Claude Code's built-in title management from conflicting with the hooks

## Settings Configuration

The hooks are registered in `~/.claude/settings.json` under the `hooks` key. Each hook type maps to a bash script:

```json
{
  "hooks": {
    "SessionStart":      [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-start.sh" }] }],
    "UserPromptSubmit":  [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/prompt-submit.sh" }] }],
    "PreToolUse":        [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/pretooluse.sh" }] }],
    "Notification":      [{ "matcher": "permission_prompt", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/notification.sh" }] }],
    "Stop":              [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/stop.sh" }] }],
    "SessionEnd":        [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-end.sh" }] }]
  }
}
```

## Name Pool

Names are stored one per line in `~/.claude/agent-names.txt`. The pool is designed for short, easy-to-hear, distinct names suitable for TTS:

```
Bill, Mel, Carl, Monte, Jeff, Will, Willie, Barry, Juan, Buster,
Orlando, Gaylord, Tim, Madison, Matt, Pablo, Hunter, Brandon,
Christy, John, Russ, Lon, Jon
```

To add names: append to the file. To remove: delete the line. Active sessions keep their name until they end regardless of pool changes.
