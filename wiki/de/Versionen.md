🇬🇧 [English](../en/Changelog.md) · 🇩🇪 [Deutsch](../de/Versionen.md)

# Versionen

Alle Einzelheiten: [CHANGELOG.md](../../CHANGELOG.md).

| Version | Wichtigste Änderungen |
|---|---|
| 1.15.0 | Symbole ganz entfernt (Entscheid nach Sendertest), Menüzeile «Symbole anzeigen» weg; alte Symbole und «symbole=» still überlesen. paint p12_voll 5 994 → 4 463, Speicher 657 → 617 KB. |
| 1.14.4 | Symbole so gross wie der Text (kleinere Masken 12/16 px aus Lua-Studio 0.10.6), Titel normal gross; Menüzeile «Symbole anzeigen» (Werk ein, in der Datendatei). |
| 1.14.3 | «Einheit steht schon im Titel» zählt nur als eigenes Wort (Grenzen: Anfang/Ende, Leerzeichen, Klammer, %), «A» in «Akku» blendet die Einheit nicht mehr aus. |
| 1.14.2 | Platzkopf: keine grosse, fette Einheit mehr («fett» wie «Einheit am Wert»), Einheit entfällt, wenn sie schon im Titel steht; Titel so hoch wie das Symbol (höchstens ein Drittel des Platzes). Wie Electric 0.7.3. |
| 1.14.1 | Studio-Hinweise stehen in der eigenen Kopfzeile statt unten und verdecken keine Werte mehr. Info-Datei: «hinweis» enthält auch den Anpass-Text; Systemnamen aus Kommentaren und Testnamen entfernt; Mac-Test für umgerechnete Ansichten. |
| 1.14.0 | Studio-Layout wird immer gefunden: Suche in `SCRIPTS:/studio/`, `SD:/scripts/studio/` und `RADIO:/scripts/studio/`; passt der Dateiname nicht zum Modell, im Widget-Menü unter «Studio-Layout» die Datei wählen (die Wahl gewinnt). Passt keine Ansicht genau zur Fenstergrösse, wird die mit dem ähnlichsten Seitenverhältnis umgerechnet (5 s Hinweis «Studio: Ansicht 800x480 angepasst»); der Schmuck fällt in einer umgerechneten Ansicht weg, zu kleine Plätze werden Zahl oder entfallen. Kaputte Datei oder fehlende Ansicht: Hinweiszeile unten. |
| 1.13.1 | Governor-Feld zeigt ohne Governor-Telemetrie «kein Governor»; Doku für jeden Heli mit Telemetrie. |
| 1.13.0 | Umbenannt von «Heli RF» in «Heli» (Schlüssel und Ordner `heli`, Studio-Datei `<Kennung>.heli.lua`), nicht rückwärtskompatibel, siehe [Umstieg](Installation.md#umstieg-von-heli-rf). |
| 1.12.0 | «Auch bei Motor aus» je Alarm (Menü und Lua-Studio), Speicher wird nach dem Modellwechsel frei, ein Studio-Eintrag ohne Schwellen schaltet keinen Alarm mehr ab. Vorabversion. |
| 1.11.0 | Lua-Studio-Format 2: Symbole, fette Einheit, Schmuck. |
| 1.10.1 | Sensoren der Studio-Datei am Sender, grosse Studio-Dateien in Stücken. |
| 1.10.0 | Studio-Datei aus Lua-Studio. |
| 1.9.1 | Governor und Arming Flags direkt gelesen. |
| 1.9.0 | Kompaktansicht, Feld Governor mit SCHARF/SICHER. |

---
[← Start](../Home.md) | [Zurück](Fehlerbehebung.md) | Weiter →
