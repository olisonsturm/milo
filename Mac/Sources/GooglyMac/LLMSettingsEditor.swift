import AppKit

@MainActor
enum LLMSettingsEditor {
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "LLM-Einstellungen"
        alert.informativeText = "Wähle den Dienst für den Mac-Chat. Anfragen und aktiv geteilter Kontext gehen an diese URL. Der Handy-Sprachmodus nutzt weiterhin OpenAI."
        let form = LLMSettingsForm(configuration: .current)
        alert.accessoryView = form
        alert.window.initialFirstResponder = form.keyEntry.field
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")
        while alert.runModal() == .alertFirstButtonReturn {
            let config = form.configuration
            guard (try? config.endpoint()) != nil, !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                let error = NSAlert()
                error.messageText = "URL oder Modell fehlt"
                error.informativeText = AssistantCore.Failure.configuration.localizedDescription
                error.runModal()
                continue
            }
            config.save()
            let key = form.keyEntry.field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if form.removeKey.state == .on { config.setKey(nil) }
            else if !key.isEmpty { config.setKey(key) }
            NotificationCenter.default.post(name: .miloLLMChanged, object: nil)
            return
        }
    }
}

extension Notification.Name { static let miloLLMChanged = Notification.Name("milo.llm.changed") }

@MainActor
private final class LLMSettingsForm: NSView {
    let format = NSPopUpButton(frame: NSRect(x: 130, y: 274, width: 360, height: 28))
    let base = NSTextField(frame: NSRect(x: 130, y: 232, width: 360, height: 26))
    let model = NSTextField(frame: NSRect(x: 130, y: 190, width: 360, height: 26))
    let keyEntry = APIKeyEntryView()
    let removeKey = NSButton(checkboxWithTitle: "Gespeicherten Key für diesen Endpoint löschen", target: nil, action: nil)

    var configuration: LLMConfiguration {
        LLMConfiguration(format: LLMFormat.allCases[format.indexOfSelectedItem],
                         baseURL: base.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                         model: model.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    init(configuration: LLMConfiguration) {
        super.init(frame: NSRect(x: 0, y: 0, width: 510, height: 392))
        let keyStatus = NSTextField(labelWithString: configuration.key == nil
            ? "Für den aktuellen Endpoint ist kein API-Key gespeichert."
            : "Für den aktuellen Endpoint ist ein API-Key gespeichert.")
        keyStatus.frame = NSRect(x: 0, y: 316, width: 500, height: 24)
        keyStatus.textColor = configuration.key == nil ? .systemOrange : .secondaryLabelColor
        addSubview(keyStatus)
        for (text, y) in [("API-Format", 278), ("Base URL", 236), ("Modell", 194), ("API-Key", 148)] {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 0, y: y, width: 120, height: 22)
            addSubview(label)
        }
        format.addItems(withTitles: LLMFormat.allCases.map(\.rawValue))
        format.selectItem(at: LLMFormat.allCases.firstIndex(of: configuration.format) ?? 0)
        base.stringValue = configuration.baseURL
        model.stringValue = configuration.model
        model.placeholderString = "Exakter Modellname aus deinem Proxy"
        keyEntry.frame.origin = NSPoint(x: 130, y: 104)
        keyEntry.field.frame.size.width = 360
        keyEntry.field.placeholderString = configuration.key == nil
            ? "Hier den Key dieses Proxys einfügen"
            : "Key gespeichert; neuen Key zum Ersetzen einfügen"
        removeKey.frame = NSRect(x: 130, y: 74, width: 375, height: 24)
        for view in [format, base, model, keyEntry, removeKey] { addSubview(view) }
        let preset = NSButton(title: "Lokaler Claude-Proxy :6655", target: self, action: #selector(useLocalProxy))
        preset.frame = NSRect(x: 0, y: 356, width: 250, height: 30)
        preset.bezelStyle = .rounded
        addSubview(preset)
        let help = NSTextField(wrappingLabelWithString: "Root-URLs ergänzen /v1 und den API-Pfad. Alternativ die vollständige Endpoint-URL eintragen. Proxy-Keys werden pro Endpoint gespeichert; OpenAI-Keys werden nicht an deinen Proxy weitergereicht.")
        help.frame = NSRect(x: 0, y: 0, width: 500, height: 64)
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        addSubview(help)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func useLocalProxy() {
        format.selectItem(at: LLMFormat.allCases.firstIndex(of: .claude)!)
        base.stringValue = "http://localhost:6655/anthropic/v1"
        model.stringValue = "anthropic--claude-4.6-sonnet"
        keyEntry.field.stringValue = ""
        removeKey.state = .off
    }
}
