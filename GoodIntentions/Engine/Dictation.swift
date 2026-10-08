// Real dictation for the first screen: the microphone, turned into text.
// Speech stays on the device when the phone supports that for English.
// This only fills in the sentence. What the model does with it is unchanged.

import AVFoundation
import Foundation
import Observation
import Speech

@Observable
final class Dictation {
    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var problem: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() async {
        if isRecording {
            stop()
        } else {
            await start()
        }
    }

    func clear() {
        transcript = ""
        problem = nil
    }

    func start() async {
        guard !isRecording else { return }
        problem = nil
        transcript = ""

        guard await Self.allowed() else {
            problem = "Microphone or speech recognition is switched off for this app. Turn them on in Settings, or type instead."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = "Speech recognition is not available right now. Type instead."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            Self.attach(request, to: engine)
            engine.prepare()
            try engine.start()
            isRecording = true

            task = Self.recognise(request, with: recognizer) { [weak self] text, finished in
                Task { @MainActor in
                    self?.heard(text, finished: finished)
                }
            }
        } catch {
            problem = "Could not start listening: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func heard(_ text: String?, finished: Bool) {
        // Results can still arrive after stopping. By then the sentence has
        // been sent, so they are dropped.
        guard isRecording else { return }
        if let text, !text.isEmpty { transcript = text }
        if finished { stop() }
    }

    // MARK: Off the main thread

    // The system calls these closures on its own threads, so they are built
    // outside the main actor and touch nothing that belongs to it.

    nonisolated private static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    nonisolated private static func attach(_ request: SFSpeechAudioBufferRecognitionRequest, to engine: AVAudioEngine) {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognise(
        _ request: SFSpeechAudioBufferRecognitionRequest,
        with recognizer: SFSpeechRecognizer,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let finished = error != nil || (result?.isFinal ?? false)
            onUpdate(result?.bestTranscription.formattedString, finished)
        }
    }
}
