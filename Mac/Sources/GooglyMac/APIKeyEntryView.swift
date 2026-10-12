import AppKit

/// Explicit paste also works when a menu-bar app's modal field misses keyboard shortcuts.
@MainActor
final class APIKeyEntryView: NSView {
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 38, width: 420, height: 24))

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 66))
        addSubview(field)
        let paste = NSButton(title: "Aus Zwischenablage einfügen", target: self, action: #selector(pasteKey))
        paste.frame = NSRect(x: 0, y: 0, width: 240, height: 30)
        paste.bezelStyle = .rounded
        addSubview(paste)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func pasteKey() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        field.stringValue = text.trimmingCharacters(in: .whitespacesAndNewlines)
        window?.makeFirstResponder(field)
    }
}
