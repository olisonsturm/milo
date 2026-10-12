import AppKit

/// Services receives selected text directly. Normal Copy stays an optional, local candidate detector.
@MainActor
final class MiloTaskCapture: NSObject {
    static let shared = MiloTaskCapture()
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount
    var watchesCopy: Bool {
        get { UserDefaults.standard.bool(forKey: "milo.excel.watchCopy") }
        set { UserDefaults.standard.set(newValue, forKey: "milo.excel.watchCopy"); lastChange = NSPasteboard.general.changeCount }
    }
    func start() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }
    func ignoreCurrentClipboard() { lastChange = NSPasteboard.general.changeCount }
    private func poll() {
        guard watchesCopy else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier,
              !ExcelCoach.shared.busy,
              let text = pasteboard.string(forType: .string), text.count >= 20,
              text.count <= AssistantCore.messageLimit else { return }
        ExcelCoach.shared.receive(text, candidate: true)
    }
    @objc func copyForMilo(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "Bitte eine Textaufgabe markieren."; return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        ignoreCurrentClipboard()
        ExcelCoach.shared.receive(text)
    }
    func useClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        ignoreCurrentClipboard()
        ExcelCoach.shared.receive(text)
    }
}
