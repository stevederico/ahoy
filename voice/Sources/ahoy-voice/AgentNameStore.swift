import Foundation

/// Polls `/tmp/claude_name_*` for active Claude Code agent names.
/// Fires a timer every 5 seconds, diffs the set, and logs arrivals/departures.
final class AgentNameStore {
    private var timer: DispatchSourceTimer?
    private var names: Set<String> = []
    private let queue = DispatchQueue(label: "ahoy.agent-names")

    /// Current set of active agent names (thread-safe read).
    func currentNames() -> Set<String> {
        queue.sync { names }
    }

    /// Starts polling. Call once at launch.
    func start() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 5.0)
        source.setEventHandler { [weak self] in self?.poll() }
        source.resume()
        timer = source
    }

    /// Stops polling and clears state.
    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Reads `/tmp/claude_name_*` files and updates the name set.
    private func poll() {
        let fm = FileManager.default
        let tmpDir = "/tmp"

        guard let entries = try? fm.contentsOfDirectory(atPath: tmpDir) else { return }

        var fresh = Set<String>()
        for entry in entries where entry.hasPrefix("claude_name_") {
            let path = (tmpDir as NSString).appendingPathComponent(entry)
            if let data = fm.contents(atPath: path),
               let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                fresh.insert(name)
            }
        }

        let arrived = fresh.subtracting(names)
        let departed = names.subtracting(fresh)

        for name in arrived {
            print("[agents] online: \(name)")
        }
        for name in departed {
            print("[agents] offline: \(name)")
        }

        names = fresh
    }
}
