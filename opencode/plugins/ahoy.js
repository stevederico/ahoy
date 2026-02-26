/**
 * Ahoy plugin for OpenCode — bridges OpenCode lifecycle events to Ahoy's
 * shell hooks so agent names, tab states, auto-focus, and TTS work the same
 * way they do with Claude Code.
 *
 * The plugin pipes JSON into the existing scripts under ~/.claude/hooks/.
 * No shell logic is duplicated here.
 *
 * @param {object} api  OpenCode plugin API
 */
export default function ahoy(api) {
  const HOOKS_DIR = `${process.env.HOME}/.claude/hooks`;
  const agents = new Map();

  /**
   * Pipe a JSON payload into a shell hook script via stdin.
   * @param {string} script  Hook filename (e.g. "session-start.sh")
   * @param {object} payload JSON object piped to the script's stdin
   * @returns {Promise<string>} stdout from the hook
   */
  function runHook(script, payload) {
    const { execSync } = require("child_process");
    const path = `${HOOKS_DIR}/${script}`;
    try {
      const out = execSync(`bash "${path}"`, {
        input: JSON.stringify(payload),
        encoding: "utf-8",
        timeout: 10000,
        stdio: ["pipe", "pipe", "pipe"],
      });
      return out.trim();
    } catch {
      return "";
    }
  }

  /**
   * Extract a session ID from an OpenCode event, trying several shapes.
   * @param {object} event  OpenCode event object
   * @returns {string} session ID or fallback
   */
  function sessionId(event) {
    return (
      event?.properties?.sessionId ||
      event?.session_id ||
      event?.sessionId ||
      "opencode-default"
    );
  }

  /**
   * Build the standard JSON payload the shell hooks expect.
   * @param {object} event  OpenCode event object
   * @returns {object} payload with session_id and cwd
   */
  function basePayload(event) {
    return {
      session_id: sessionId(event),
      cwd: event?.properties?.cwd || event?.cwd || process.cwd(),
      transcript_path: "",
    };
  }

  // --- Event listeners ------------------------------------------------

  /**
   * session.created — assign agent name, set terminal title, TTS greeting.
   */
  api.on("session.created", (event) => {
    const payload = basePayload(event);
    const name = runHook("session-start.sh", payload);
    if (name) {
      agents.set(payload.session_id, name);
    }
  });

  /**
   * tool.execute.before — show hammer emoji in tab title while working.
   */
  api.on("tool.execute.before", (event) => {
    runHook("pretooluse.sh", basePayload(event));
  });

  /**
   * permission.asked — sound alert, TTS, auto-focus the right tab.
   */
  api.on("permission.asked", (event) => {
    runHook("notification.sh", basePayload(event));
  });

  /**
   * session.idle — mark turn complete, TTS "X completed task".
   */
  api.on("session.idle", (event) => {
    runHook("stop.sh", basePayload(event));
  });

  /**
   * session.deleted — clean up temp files and release agent name.
   */
  api.on("session.deleted", (event) => {
    const payload = basePayload(event);
    runHook("session-end.sh", payload);
    agents.delete(payload.session_id);
  });

  // --- System prompt injection ----------------------------------------

  /**
   * Inject the agent name into every system prompt so the model knows
   * its identity — mirrors what session-start.sh prints to stdout for
   * Claude Code.
   */
  if (api.experimental?.chat?.system?.transform) {
    api.experimental.chat.system.transform((prompt, context) => {
      const sid =
        context?.sessionId || context?.session_id || "opencode-default";
      const name = agents.get(sid);
      if (name) {
        return `${prompt}\n\nYour name is ${name}. Introduce yourself by this name when you first respond.`;
      }
      return prompt;
    });
  }
}
