import AppKit

/// Detects the running terminal app and focuses a tab/session by agent name via AppleScript.
final class TerminalFocuser {
    /// Supported terminal platforms.
    enum Platform: String {
        case terminal = "terminal"
        case iterm2 = "iterm2"
    }

    private let platform: Platform

    /// Creates a focuser with an explicit platform or auto-detects from running apps.
    /// - Parameter override: If non-nil, forces a specific platform instead of auto-detecting.
    init(override: Platform? = nil) {
        if let p = override {
            self.platform = p
            print("[focus] platform override: \(p.rawValue)")
        } else {
            self.platform = TerminalFocuser.detect()
            print("[focus] detected platform: \(self.platform.rawValue)")
        }
    }

    /// Focuses the terminal tab whose title/name contains the given agent name.
    /// - Parameter name: The agent name to match against tab titles.
    func focus(name: String) {
        let sanitized = sanitizeName(name)

        let script: String
        switch platform {
        case .terminal:
            script = terminalFocusScript(label: sanitized)
        case .iterm2:
            script = itermFocusScript(label: sanitized)
        }

        runAppleScript(script, label: "focus")
    }

    // MARK: - iTerm2

    /// AppleScript to focus an iTerm2 session by name.
    /// - Parameter label: Sanitized agent name.
    /// - Returns: AppleScript source string.
    private func itermFocusScript(label: String) -> String {
        """
        tell application "iTerm"
          activate
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if name of s contains "\(label)" then
                  select t
                  select s
                  return
                end if
              end repeat
            end repeat
          end repeat
        end tell
        """
    }

    // MARK: - Terminal.app

    /// AppleScript to focus a Terminal.app tab by custom title.
    /// - Parameter label: Sanitized agent name.
    /// - Returns: AppleScript source string.
    private func terminalFocusScript(label: String) -> String {
        """
        tell application "Terminal"
          activate
          repeat with w in windows
            repeat with t in tabs of w
              if custom title of t contains "\(label)" then
                set selected tab of w to t
                set frontmost of w to true
                return
              end if
            end repeat
          end repeat
        end tell
        """
    }

    // MARK: - Shared

    /// Auto-detects the running terminal by checking bundle IDs.
    /// - Returns: The detected platform, defaults to `.terminal`.
    private static func detect() -> Platform {
        let apps = NSWorkspace.shared.runningApplications
        let bundles = Set(apps.compactMap(\.bundleIdentifier))

        if bundles.contains("com.googlecode.iterm2") {
            return .iterm2
        }
        return .terminal
    }

    /// Strips quotes from a name for safe AppleScript interpolation.
    /// - Parameter name: Raw agent name.
    /// - Returns: Sanitized string with quotes removed.
    private func sanitizeName(_ name: String) -> String {
        name.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
    }

    /// Executes an AppleScript string via NSAppleScript and logs errors.
    /// - Parameters:
    ///   - source: AppleScript source code.
    ///   - label: Label for error logging.
    private func runAppleScript(_ source: String, label: String) {
        let appleScript = NSAppleScript(source: source)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        if let error = error {
            print("[focus] \(label) error: \(error)")
        }
    }
}
