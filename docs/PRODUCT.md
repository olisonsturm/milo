# Milo: erster Produktfokus

## Nutzen

Ein persönlicher Assistent, der aus einer Frage, einer Notiz oder einer Tabelle einen überprüfbaren nächsten Schritt macht. Der erste konkrete Schwerpunkt ist Excel: schnell von ungeordneten Daten zu einem verständlichen und gut gestalteten Dashboard.

## Jetzt umgesetzt

Standalone-Mac-Chat mit Markdown-Darstellung und lokaler deutscher Spracheingabe, manuell gepflegter Kontext, Excel-Blueprints und Markdown-Export. Copy-for-Milo als macOS-Dienst, optional erkannte Kopiervorgänge und ein kleiner Excel-Begleiter mit Zeigen-/Aktionsmodus. Begrenzte Requests und keine Hintergrund-Modellschleife. Der ursprüngliche iPhone-Begleiter bleibt optional.

## Nächster vertikaler Prototyp

1. CSV/XLSX gezielt auswählen und lokal Schema, Datentypen, fehlende Werte und Dubletten prüfen. Nur nötige Zusammenfassungen mit dem Modell teilen.
2. Ein konkretes Dashboard als echte `.xlsx` mit Formeln, Formatierung und Diagrammen erzeugen. Quelldaten, Kennzahlen und Summen prüfbar halten. Keine blind ausgeführten Modellskripte.
3. Microsoft-Anbindung: eigener OAuth-App-Login, zunächst vom Nutzer ausgewählte OneNote-/OneDrive-Inhalte und Outlook-Termine lesen; genaue Scopes und Datenzugriff sichtbar machen. Excel für Mac braucht eine eigene Adapterentscheidung; ein Microsoft-Login alleine steuert keine lokale Excel-App.
4. Ein nachvollziehbares Gedächtnis mit Quellen, Änderungsdatum, Bearbeiten/Löschen und relevanter Suche. Keine vollständige Notizensammlung bei jeder Frage senden.

## Danach

Globale Push-to-talk-Taste zusätzlich zur Chat-Diktierfunktion, dann optionaler Kamera-Trigger. Aktivierung und Aufnahme sichtbar, lokale Erkennung soweit möglich, keine Dauerübertragung zum Modell. Handy-Mitteilungen brauchen plattformspezifische, ausdrücklich aktivierte Integrationen; beliebiger App-Zugriff ist kein vorhandenes Feature.

Flutter kann später die gemeinsame Oberfläche für Mobil/Desktop liefern. Bildschirmaufnahme, Accessibility und native Office-Adapter bleiben Plattformmodule; der Swift-Unterbau lässt sich dafür nicht einfach unverändert in Flutter ausführen. Erst einen vollständigen Excel-Ablauf validieren, bevor die Oberfläche neu geschrieben wird.

## Produktionslücken

Echte macOS-Keychain statt geerbter Schlüsseldatei, abgesicherte Geräte-Paarung statt bloßer WLAN-Erkennung, nachvollziehbare Aktionsfreigaben, Kostenbudget für Sprachsitzungen und Tests der vollständigen Office-Abläufe. Die vorhandenen Computerregeln sind kein vollständiges Sicherheitsmodell für einen Agenten mit weitreichendem Zugriff.
