import AVFoundation
import Speech

/// Wraps `AVAudioEngine` + `SFSpeechRecognizer` for continuous on-device speech recognition.
/// Each instance is single-use — create a new `SpeechEngine` per recognition cycle.
final class SpeechEngine {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var configObserver: NSObjectProtocol?

    /// Called with partial transcription text on each update.
    var onTranscription: ((String) -> Void)?
    /// Called when recognition ends (timeout, error, or audio config change).
    var onFinished: ((Error?) -> Void)?

    /// Creates a speech engine with the default locale recognizer.
    init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!

        if !recognizer.supportsOnDeviceRecognition {
            print("[speech] warning: on-device recognition not supported, falling back to server")
        }
    }

    /// Starts audio capture and speech recognition.
    /// - Throws: If the audio engine fails to start.
    func start() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                self?.onTranscription?(text)
            }
            if error != nil || result?.isFinal == true {
                self?.stop()
                self?.onFinished?(error)
            }
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            print("[speech] audio config changed, restarting")
            self?.stop()
            self?.onFinished?(nil)
        }
    }

    /// Stops audio capture and recognition. Safe to call multiple times.
    func stop() {
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
}
