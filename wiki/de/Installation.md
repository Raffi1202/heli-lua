🇬🇧 [English](../en/Installation.md) · 🇩🇪 [Deutsch](../de/Installation.md)

# Installation

**Du brauchst:** einen FrSky-Sender mit Ethos (26.1 oder neuer) und Farbbildschirm, einen Computer mit der FrSky Suite und das USB-Kabel, dazu einen Heli mit Telemetrie über den FrSky-Empfänger (jedes Flybarless-System oder jeder Regler mit Telemetrie, oder FrSky-Sensoren über S.Port/FBUS). Die Sensoren vorher im Modell suchen (Modell › Telemetrie › Neue Sensoren suchen).

## Mit der FrSky Suite
1. `Heli-1.14.0-share.zip` entpacken. Darin liegen die Anleitungen, `LIES MICH.txt` und das Paket `Heli-1.14.0.zip`. **Das Paket nicht entpacken.**
2. Sender einschalten, per USB verbinden und am Sender **Ethos Suite** wählen.
3. In der Suite: **Lua-Bibliothek › Von lokaler ZIP installieren**, `Heli-1.14.0.zip` wählen, **Skripte installieren**.
4. Sender trennen und neu starten.

Der Sender muss verbunden sein, bevor du «Skripte installieren» klickst. Einen alten Ordner `heli` nicht vorher löschen: Darin liegt die Flugliste.

## Von Hand
`Heli-1.14.0.zip` entpacken, den Sender als USB-Laufwerk verbinden und den Ordner `heli` (mit dem Unterordner `audio`) in den Ordner `scripts` des Senders kopieren. Einen vorhandenen Ordner überschreiben, nicht löschen. Bei Sendern mit SD-Karte dorthin, wo die anderen Lua-Skripte liegen; im Zweifel `SD:/scripts/heli`. An der X18RS mit Ethos 26.2.0 lud nur die SD-Karte.

## Auf einen Bildschirm legen
Bildschirme › **+** › Layout **Vollbild** (oder ein Feld mit Leisten für die Kompaktansicht) › Feld antippen › Widget › **Heli**.


## Umstieg von Heli RF

**Umbenannt von «Heli RF» (`helirf`), nicht rückwärtskompatibel:** In vorhandenen Modellen das Widget neu auswählen (die Einstellungen beginnen mit den Werkswerten); Studio-Dateien in `<Kennung>.heli.lua` umbenennen oder mit Lua-Studio neu übertragen. Eine alte `<Kennung>.helirf.lua` wird noch gelesen, mit dem Hinweis «old studio file found, please re-transfer» im Log. Flugzähler und Flugliste übernimmt Heli automatisch aus `scripts/helirf/daten/` (nur lesen, nie löschen); den alten Ordner darum stehen lassen, bis jedes Modell einmal benutzt wurde. Wird im Modell nur der Widget-Schlüssel von `helirf` auf `heli` umgestellt statt das Widget neu zu wählen, bleiben auch alle Einstellungen.

1. Heli 1.14.0 installieren (Ordner `scripts/heli`).
2. In jedem Modell auf dem Bildschirm das Widget «Heli RF» durch **Heli** ersetzen, danach Sensoren und Einstellungen neu einrichten ([Einrichten](Einrichten.md)).
3. Studio-Datei mit Lua-Studio neu übertragen (oder `<Kennung>.helirf.lua` in `<Kennung>.heli.lua` umbenennen).
4. Wenn jedes Modell einmal mit Heli lief, kann der alte Ordner `scripts/helirf` gelöscht werden.

---
[← Start](../Home.md) | Zurück | [Weiter →](Einrichten.md)
