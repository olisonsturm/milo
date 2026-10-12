# Milo

Ein persönlicher Mac-Assistent für Alltag, Projekte und Excel-Dashboards. Experimenteller Fork von [Bluey by Riley](https://github.com/rbrown101010/bluey-by-riley), mit einem neuen Standalone-Chat. Der Arbeitsname Milo ist noch nicht als Marke geprüft.

## Sofort ausprobieren

Voraussetzung: macOS 14+ und Xcode Command Line Tools.

```sh
./scripts/build-mac.sh
open build/Milo.app
```

Der Mac-Chat öffnet sich beim Start; später über das Menüleisten-Symbol → **Milo öffnen…**. Kein iPhone nötig. Mit **Excel-Beispiel ansehen · ohne API** lässt sich die Oberfläche ohne Key und ohne Modellkosten testen. Diese Vorschau ist ein festes Beispiel.

Für echte Antworten: **LLM-Einstellungen…** im Chat oder Menü öffnen und Base URL, API-Format, Modell und eigenen API-Key hinterlegen. OpenAI bleibt als Standard verfügbar. ChatGPT-Abonnements ersetzen kein API-Guthaben. **Alltag**, **Excel-Dashboard** oder **Projekte** wählen, Frage eingeben und **Senden** drücken. Antworten lassen sich kopieren und als Markdown speichern. Eine laufende Anfrage kann abgebrochen werden; bereits entstandene API-Kosten werden dadurch nicht rückgängig gemacht.

Unter **Mein Kontext** kannst du Notizen/Projektinformationen schreiben oder eine UTF-8-Textdatei importieren. Import ersetzt den bisherigen Kontext und übernimmt maximal 6.000 Zeichen. Erst **Kontext mitsenden** aktivieren, um diese Informationen mit einer Frage zu teilen. Es gibt noch keine automatische Suche in Apple Notes, OneNote oder Projektordnern.

## Claude über lokalen Hai-Proxy

Unter **LLM-Einstellungen…** auf **Lokaler Claude-Proxy :6655** klicken:

- API-Format: **Claude Messages**
- Base URL: `http://localhost:6655/anthropic/v1`
- Modell: `anthropic--claude-4.6-sonnet` (oder ein anderes vom Proxy angebotenes Modell)
- API-Key: der **Hai-Proxy-Key**, nicht der OpenAI-Key

Milo sendet an `/anthropic/v1/messages` mit `Authorization: Bearer …` und `anthropic-version`. Der Dienst muss laufen. API-Keys werden pro Endpoint gespeichert und bei URL-Wechsel nicht automatisch übernommen. Das leere Key-Feld behält einen gespeicherten Key; zum Entfernen die Checkbox aktivieren. Lokale Proxys ohne Authentifizierung dürfen das Feld leer lassen; der Hai-Proxy verlangt einen Key.

Alternativ sind vollständige Endpoint-URLs möglich. Root-URLs ergänzen `/v1` und den Pfad für das ausgewählte Format; vorhandene Pfade bleiben erhalten. HTTP ist nur für Loopback erlaubt, sonst HTTPS. Redirects werden nicht verfolgt. Der Handy-Sprach-/Recherchemodus nutzt weiterhin den separaten OpenAI-Key.

## Was der Prototyp kann

- Standalone-Textchat mit OpenAI Responses, OpenAI-kompatiblem Chat oder Claude Messages; Base URL und Modell frei konfigurierbar.
- Lokaler, explizit geteilter persönlicher Kontext.
- Excel-Bauanleitungen: Kennzahlen, Formeln, Datenprüfungen, Diagramme und Layout.
- Fragen zur Projektplanung und zum Alltag; Antworten kopieren/exportieren.
- Tokenanzeige der letzten erfolgreichen Anfrage.
- Optional: geerbter iPhone-Begleiter mit Bildschirmzeiger, Sprache und Computersteuerung.

Der Mac-Chat führt noch keine Aktionen aus und erzeugt keine `.xlsx`-Dateien. Microsoft-OAuth, Outlook/Teams/OneNote, Handy-Mitteilungen, Kameraerkennung und Flutter sind noch nicht implementiert. Milo ist ein Assistenzprototyp, keine AGI.

## Kosten und Daten

Im Mac-Chat wird nur beim Senden eine Modellanfrage gestartet. Pro Anfrage maximal 6.000 Kontextzeichen, die letzten acht Nachrichten mit insgesamt maximal 12.000 Zeichen und bis zu 1.200 Ausgabe-Tokens. Jede Nachricht ist auf 4.000 Zeichen begrenzt. Zeichenlimits sind keine exakten Token- oder Geldlimits. Der sichtbare Chat bleibt bis zum Neustart erhalten; ältere Nachrichten außerhalb des Fensters werden nicht ans Modell geschickt.

Der OpenAI-Responses-Modus verwendet `store: false`; das ist keine Garantie für Zero Data Retention beim Anbieter. Fragen, der begrenzte Verlauf und aktiv geteilter Kontext werden an den konfigurierten LLM-Dienst gesendet. Persönlicher Kontext bleibt in lokalen App-Einstellungen, Chatnachrichten bleiben im Arbeitsspeicher, exportierte Notizen am ausgewählten Ort.

Die geerbte Schlüsselablage ist `~/Library/Application Support/Googly/keys.json`, mit Benutzer-Dateirechten, **nicht** die macOS-Keychain. Die internen Googly-Namen, das Bonjour-Protokoll und `~/Documents/Bluey Notes` bleiben für Kompatibilität bestehen. Das App-Bundle hat eine eigene Milo-ID.

Der optionale iPhone-Sprachmodus nutzt die geerbte Realtime-/Transkriptionspipeline mit eigenem Kostenverhalten; die Textchat-Limits gelten dort nicht. Während einer wachen Handy-Sitzung wird Audio aufgenommen und in Abschnitten transkribiert. Zum ersten Test einfach den Mac-Chat verwenden.

## Optionaler iPhone-Modus

`GooglyEyes.xcodeproj` mit Xcode öffnen, eigenes Signing-Team wählen und auf dem iPhone starten. Beide Geräte im selben WLAN. App-Anzeigename: Milo. `project.yml` ist die XcodeGen-Quelle; nach Änderungen `xcodegen generate` verwenden.

**Bildschirmzugriff aktivieren…** startet die Berechtigungsabfragen am Mac. **Let Him Use the Computer** ist für neue Installationen standardmäßig aus. Die geerbten Aktionen brauchen Accessibility; Screenshots brauchen Screen Recording. Ein Doppeltipp auf dem Handy startet/stoppt eine Sitzung; gedrückt halten stellt eine Frage. ⌃⌥S stoppt Computeraktionen.

## Entwicklung und Tests

```sh
swift test
```

Tests prüfen Proxy-Endpunkte, Authentifizierung, Claude-/Chat-Antworten, Anfragegrenzen, optionalen Kontext, API-Antwortparsing und fehlende Schlüssel ohne Netzwerkzugriff. Ein erfolgreicher Build bestätigt noch keinen echten Modellaufruf oder eine funktionierende iPhone-Verbindung.

Siehe [Produktplan](docs/PRODUCT.md) für die nächsten sinnvollen Schritte.

## Herkunft und Lizenz

Upstream: [rbrown101010/bluey-by-riley](https://github.com/rbrown101010/bluey-by-riley). Die ursprüngliche [Unlicense](LICENSE) bleibt erhalten und erlaubt auch kommerzielle Nutzung. Mitgelieferte Schriftarten haben eigene OFL-Lizenzen unter `Shared/Fonts/`. Dienstbedingungen, Marken und neue Abhängigkeiten müssen vor einem kommerziellen Release separat geprüft werden.
