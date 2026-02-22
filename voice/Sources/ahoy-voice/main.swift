import Speech
import AVFoundation
import AVFAudio
import Foundation

// MARK: - Argument parsing

/// Parses `--platform terminal|iterm2` from command-line arguments.
/// - Returns: The platform override, or nil for auto-detection.
func parsePlatform() -> TerminalFocuser.Platform? {
    let args = CommandLine.arguments
    guard let idx = args.firstIndex(of: "--platform"), idx + 1 < args.count else {
        return nil
    }
    guard let platform = TerminalFocuser.Platform(rawValue: args[idx + 1]) else {
        print("error: unknown platform '\(args[idx + 1])'. Use 'terminal' or 'iterm2'.")
        exit(1)
    }
    return platform
}

// MARK: - Permission checks

/// Requests speech recognition authorization. Blocks until resolved, exits on deny.
func requestSpeechPermission() {
    let semaphore = DispatchSemaphore(value: 0)
    var authorized = false

    SFSpeechRecognizer.requestAuthorization { status in
        authorized = (status == .authorized)
        if !authorized {
            print("error: speech recognition permission denied (status: \(status.rawValue))")
        }
        semaphore.signal()
    }

    semaphore.wait()
    if !authorized { exit(1) }
}

/// Requests microphone access. Blocks until resolved, exits on deny.
func requestMicrophonePermission() {
    let semaphore = DispatchSemaphore(value: 0)
    var authorized = false

    AVCaptureDevice.requestAccess(for: .audio) { granted in
        authorized = granted
        if !granted {
            print("error: microphone permission denied")
        }
        semaphore.signal()
    }

    semaphore.wait()
    if !authorized { exit(1) }
}

// MARK: - Main

print("ahoy-voice v1.4.0: voice-controlled terminal tab focus")
print("requesting permissions...")

requestSpeechPermission()
requestMicrophonePermission()
print("permissions granted")

let platformOverride = parsePlatform()

let store = AgentNameStore()
let focuser = TerminalFocuser(override: platformOverride)
let loop = RecognitionLoop(store: store, focuser: focuser)

store.start()
loop.start()

print("say an agent name to focus its tab (Ctrl+C to stop)")

// Keep the process alive
RunLoop.main.run()
