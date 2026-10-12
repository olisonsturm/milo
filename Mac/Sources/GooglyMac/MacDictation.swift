import AppKit
import AVFoundation
import Speech
import Combine

@MainActor
final class MacDictation: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var starting = false
    @Published var transcript = ""
    @Published var error: String?
    private let engine = AVAudioEngine()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var timeout: Task<Void, Never>?
    private var tapped = false
    private var generation = UUID()

    func toggle() { if recording || starting { stop() } else { Task { await start() } } }
    func start() async {
        guard !recording, !starting else { return }
        starting = true; error = nil; transcript = ""
        let token = UUID(); generation = token
        defer { if generation == token { starting = false } }
        let permitted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard generation == token else { return }
        guard permitted, microphone else { error = "Mikrofon und Spracherkennung in macOS für Milo erlauben."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            error = "Lokale deutsche Spracherkennung ist nicht verfügbar. Prüfe macOS-Sprachpakete; Audio wird nicht an einen Cloud-Dienst gesendet."; return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { error = "Kein Mikrofon verfügbar."; return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        tapped = true
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let result { self.transcript = String(result.bestTranscription.formattedString.prefix(AssistantCore.messageLimit)) }
                if failure != nil || result?.isFinal == true {
                    if failure != nil && self.transcript.isEmpty { self.error = "Spracherkennung beendet. Bitte erneut versuchen." }
                    self.stop()
                }
            }
        }
        do { engine.prepare(); try engine.start(); recording = true }
        catch { self.error = "Mikrofon konnte nicht gestartet werden."; stop(); return }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }
    func stop() {
        generation = UUID(); starting = false; recording = false
        timeout?.cancel(); timeout = nil
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
    }
}
