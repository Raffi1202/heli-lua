🇬🇧 [English](../en/Installation.md) · 🇩🇪 [Deutsch](../de/Installation.md)

# Installation

**Du brauchst:** einen FrSky-Sender mit Ethos (26.1 oder neuer) und Farbbildschirm, einen Computer mit der FrSky Suite und das USB-Kabel, dazu einen Heli mit Telemetrie über den FrSky-Empfänger (Rotorflight, FrSky-Sensoren über FBUS/S.Port oder ein Telemetrie-Regler). Die Sensoren vorher im Modell suchen (Modell › Telemetrie › Neue Sensoren suchen).

## Mit der FrSky Suite
1. `Heli-RF-1.12.0-zum-Teilen.zip` entpacken. Darin liegen die Anleitungen, `LIES MICH.txt` und das Paket `Heli-RF-1.12.0.zip`. **Das Paket nicht entpacken.**
2. Sender einschalten, per USB verbinden und am Sender **Ethos Suite** wählen.
3. In der Suite: **Lua-Bibliothek › Von lokaler ZIP installieren**, `Heli-RF-1.12.0.zip` wählen, **Skripte installieren**.
4. Sender trennen und neu starten.

Der Sender muss verbunden sein, bevor du «Skripte installieren» klickst. Einen alten Ordner `helirf` nicht vorher löschen: Darin liegt die Flugliste.

## Von Hand
`Heli-RF-1.12.0.zip` entpacken, den Sender als USB-Laufwerk verbinden und den Ordner `helirf` (mit dem Unterordner `audio`) in den Ordner `scripts` des Senders kopieren. Einen vorhandenen Ordner überschreiben, nicht löschen. Bei Sendern mit SD-Karte dorthin, wo die anderen Lua-Skripte liegen; im Zweifel `SD:/scripts/helirf`. An der X18RS mit Ethos 26.2.0 lud nur die SD-Karte.

## Auf einen Bildschirm legen
Bildschirme › **+** › Layout **Vollbild** (oder ein Feld mit Leisten für die Kompaktansicht) › Feld antippen › Widget › **Heli RF**.

---
[← Start](../Home.md) | Zurück | [Weiter →](Einrichten.md)
