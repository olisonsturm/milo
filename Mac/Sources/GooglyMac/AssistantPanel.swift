import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AssistantPanel {
    private var window: NSWindow?
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Milo · Dein persönlicher Assistent"
            window.contentView = NSHostingView(rootView: AssistantView())
            window.minSize = NSSize(width: 760, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AssistantView: View {
    @AppStorage("milo.personalContext") private var context = ""
    @State private var mode: AssistantMode = .everyday
    @State private var draft = ""
    @State private var turns: [AssistantTurn] = []
    @State private var busy = false
    @State private var error: String?
    @State private var usage: Int?
    @State private var shareContext = false
    @State private var editingContext = false
    @State private var configuration = LLMConfiguration.current
    @State private var task: Task<Void, Never>?
    private let accent = Color(red: 0.36, green: 0.33, blue: 0.85)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Label("milo", systemImage: "eyes").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(accent)
                Text("Ein Kopf weniger voll.").foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(AssistantMode.allCases) { option in
                        Button { mode = option; turns = []; usage = nil; error = nil; draft = "" } label: {
                            Label(option.rawValue, systemImage: option.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .background(mode == option ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(busy)
                    }
                }
                Spacer()
                Button("LLM-Einstellungen…") { LLMSettingsEditor.show() }.disabled(busy)
                Button { editingContext = true } label: { Label("Mein Kontext", systemImage: "note.text") }
                Toggle("Kontext mitsenden", isOn: $shareContext).toggleStyle(.checkbox)
                Text("Nur aktiv geteilter Kontext wird mit deiner Frage an den gewählten LLM-Dienst gesendet. Kein automatisches Mitlesen.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Microsoft · Kamera · Flutter\nGeplant, noch nicht verbunden").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 230).background(accent.opacity(0.04))
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(mode.rawValue).font(.title2.bold())
                        Text("Mac-Chat · ohne Handy · auf deine Anfrage").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Neuer Chat") { turns = []; usage = nil; error = nil }.disabled(busy || turns.isEmpty)
                }
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if turns.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Image(systemName: mode.symbol).font(.system(size: 42)).foregroundStyle(accent)
                                    Text(mode == .excel ? "Von Daten zu einer klaren Entscheidung." : "Was beschäftigt dich gerade?").font(.title.bold())
                                    Text(mode == .excel ? "Wir entwickeln Kennzahlen, Formeln, Diagramme und ein sauberes Layout. Der erste Schritt: Ziel und Daten verstehen." : "Teile eine Frage, eine Notiz oder eine Projektidee. Milo hilft dir, den nächsten Schritt zu finden.").foregroundStyle(.secondary)
                                    Button("Damit starten") { draft = mode.starter }
                                    Button("Excel-Beispiel ansehen · ohne API") { showPreview() }
                                }.padding(.vertical, 32)
                            }
                            ForEach(turns) { turn in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(turn.role == "user" ? "DU" : "MILO").font(.caption.bold()).foregroundStyle(accent)
                                    Text(turn.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    if turn.role == "assistant" {
                                        HStack {
                                            Button("Kopieren") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(turn.text, forType: .string) }
                                            Button("Als Notiz speichern…") { export(turn.text) }
                                        }.font(.caption)
                                    }
                                }.padding(16).background(turn.role == "user" ? accent.opacity(0.07) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)).id(turn.id)
                            }
                            if busy { ProgressView("Milo denkt…").id("busy") }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.onChange(of: turns.count) { _, _ in if let last = turns.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $draft).font(.body).frame(height: 76).padding(8)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: draft) { _, value in if value.count > AssistantCore.messageLimit { draft = String(value.prefix(AssistantCore.messageLimit)) } }
                    HStack {
                        Text(usage.map { "Letzte Anfrage: \($0) Tokens" } ?? "\(configuration.model) · max. 1.200 Ausgabe-Tokens")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if busy { Button("Abbrechen") { task?.cancel() } }
                        Button("Senden") { send() }.buttonStyle(.borderedProminent).tint(accent)
                            .disabled(busy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.padding(24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .miloLLMChanged)) { _ in configuration = .current; usage = nil }
        .sheet(isPresented: $editingContext) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Was Milo über dich wissen darf").font(.title2.bold())
                Text("Notizen, Projekte und Arbeitsweise. Lokal gespeichert; nur mit aktiviertem „Kontext mitsenden“ an den gewählten LLM-Dienst übertragen. Maximal 6.000 Zeichen.").foregroundStyle(.secondary)
                TextEditor(text: $context).frame(minHeight: 260).font(.body)
                    .onChange(of: context) { _, value in if value.count > AssistantCore.contextLimit { context = String(value.prefix(AssistantCore.contextLimit)) } }
                HStack {
                    Text("\(context.count) / 6.000 Zeichen").foregroundStyle(.secondary)
                    Spacer()
                    Button("Textdatei importieren…") { importContext() }
                    Button("Fertig") { editingContext = false }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(width: 600)
        }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !question.isEmpty else { return }
        let pending = AssistantTurn(role: "user", text: question)
        turns.append(pending); draft = ""; busy = true; error = nil
        let selectedMode = mode
        let notes = shareContext ? context : ""
        let history = turns
        let config = configuration
        let key = config.key
        task = Task { @MainActor in
            defer { busy = false; task = nil }
            do {
                let reply = try await AssistantCore.ask(mode: selectedMode, context: notes, turns: history, key: key, configuration: config)
                try Task.checkCancellation()
                turns.append(AssistantTurn(role: "assistant", text: reply.text)); usage = reply.tokens
            } catch {
                turns.removeAll { $0.id == pending.id }; draft = question
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }

    private func importContext() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md")!]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 32000) ?? Data()
            guard let text = String(data: data, encoding: .utf8) else { throw AssistantCore.Failure.invalidReply }
            context = String(text.prefix(AssistantCore.contextLimit))
        } catch { self.error = "Textdatei konnte nicht gelesen werden. Bitte UTF-8 verwenden." }
    }

    private func export(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Milo-Notiz.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try text.write(to: url, atomically: true, encoding: .utf8) }
        catch { self.error = "Die Notiz konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }

    private func showPreview() {
        mode = .excel
        turns = [AssistantTurn(role: "assistant", text: """
        VORSCHAU · Festes Beispiel, keine KI-Anfrage und keine echten Daten.

        Ein Vertriebsdashboard für den Monatsüberblick

        Aufbau: Rohdaten → Berechnungen → Dashboard. Eine Zeile je Verkauf; Spalten: Datum, Region, Produkt, Umsatz und Kosten.

        Vier Kennzahlen: Umsatz, Gewinn, Marge und Veränderung zum Vormonat. Beispiel bei englischem Excel und einer Tabelle namens Sales:
        Umsatz: =SUM(Sales[Revenue])
        Gewinn: =SUM(Sales[Revenue])-SUM(Sales[Cost])
        Marge: =IFERROR((SUM(Sales[Revenue])-SUM(Sales[Cost]))/SUM(Sales[Revenue]),0)
        Diese Formeln zeigen Gesamtwerte. Für Monatsfilter müssen PivotTables oder SUMIFS ergänzt werden.

        Layout: vier KPI-Karten oben, monatlicher Umsatz als Linie darunter, Regionen als horizontale Balken rechts. Dunkle Schrift, weißer Hintergrund, Violett als Akzent; keine 3D-Effekte. Marge als Prozent formatieren.

        Prüfen: Dubletten, leere Datumsfelder, Währung und Abstimmung mit der Quelle.

        Mit echten Spalten und deinem Ziel kann Milo daraus eine konkrete Bauanleitung machen. Dieser Prototyp erzeugt noch keine .xlsx-Datei.
        """)]
    }
}
