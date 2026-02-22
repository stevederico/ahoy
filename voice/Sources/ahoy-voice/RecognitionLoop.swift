import Foundation
import AppKit

/// Manages a timeout-resilient recognition loop that matches agent names to focus terminal tabs.
final class RecognitionLoop {
    private let store: AgentNameStore
    private let focuser: TerminalFocuser
    private var engine: SpeechEngine?
    private var lastFocusTimes: [String: Date] = [:]

    /// Debounce interval — ignores repeated matches for the same name within this window.
    private let debounceInterval: TimeInterval = 3.0

    /// Creates a recognition loop wired to the given store and focuser.
    /// - Parameters:
    ///   - store: Agent name source.
    ///   - focuser: Terminal tab focuser.
    init(store: AgentNameStore, focuser: TerminalFocuser) {
        self.store = store
        self.focuser = focuser
    }

    /// Starts the recognition loop. Runs indefinitely until the process exits.
    func start() {
        startCycle()
    }

    /// Spins up a fresh SpeechEngine and listens for agent names.
    private func startCycle() {
        let eng = SpeechEngine()
        self.engine = eng

        eng.onTranscription = { [weak self] text in
            self?.handleTranscription(text)
        }

        eng.onFinished = { [weak self] error in
            if let error = error {
                print("[loop] recognition ended: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.startCycle()
            }
        }

        do {
            try eng.start()
            print("[loop] listening...")
        } catch {
            print("[loop] failed to start: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startCycle()
            }
        }
    }

    /// Tokenizes transcription and scans for agent name matches.
    /// - Parameter text: Cumulative partial transcription from SpeechEngine.
    private func handleTranscription(_ text: String) {
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        handleListening(words: words)
    }

    /// Scans words for agent name matches and focuses the matching tab.
    /// - Parameter words: Tokenized, lowercased transcription words.
    private func handleListening(words: [String]) {
        let names = store.currentNames()

        for name in names {
            let nameLower = name.lowercased()
            let nameTokens = nameLower.components(separatedBy: .whitespacesAndNewlines)

            for (_, word) in words.enumerated().reversed() {
                if nameTokens.contains(word) {
                    let now = Date()
                    if let last = lastFocusTimes[nameLower], now.timeIntervalSince(last) < debounceInterval {
                        break
                    }
                    lastFocusTimes[nameLower] = now

                    print("[match] heard \"\(name)\" — focusing tab")
                    focuser.focus(name: name)
                    playSound("Pop")
                    return
                }
            }
        }
    }

    /// Plays a macOS system sound by name.
    /// - Parameter name: Sound file name without extension (e.g. "Pop", "Glass").
    private func playSound(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
