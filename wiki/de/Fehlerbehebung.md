🇬🇧 [English](../en/Troubleshooting.md) · 🇩🇪 [Deutsch](../de/Fehlerbehebung.md)

# Fehlerbehebung

## Lua-Speicher
Alle Lua-Skripte auf dem Sender teilen sich einen Lua-Speicher, an der **X18RS rund 2048 KB**. Jedes Lua, das seit dem Einschalten angezeigt wurde, belegt einen Teil davon. Meldet Ethos **«too much RAM»** (Zu wenig Lua-Speicher) oder bleibt ein Skript stehen: **Sender aus- und wieder einschalten.** Nicht benutzte Skripte entfernen. Seit 1.12.0 gibt Heli RF nach einem Modellwechsel seinen Speicher fast ganz frei (rund 4–5 KB bleiben, im Simulator gemessen).

## Sensoren
| Was du siehst | Was hilft |
|---|---|
| überall `--` | Heli an, Telemetrie da? Sensoren zuweisen ([Einrichten](Einrichten.md)). |
| ein Wert `--` oder unsinnig | Feld unter Sensoren von Hand setzen. |
| «ZELLEN?» / Zellenspannung `--` | Unter Akku die Zellen einstellen. |
| Akku % `--` oder falsch | Zellen und Kapazität einstellen; Feld «Akku %» leeren, wenn ein %-Sensor Falsches zeigt. |
| Governor «--», «nur mit Rotorflight» | In Rotorflight Governor State und Arming Flags einschalten. Ohne Rotorflight normal. |
| Reglertemperatur bleibt bei 100 °C | In Ethos das Maximum des Sensors erhöhen (Bereich −30 bis 100 °C). |

## Alarme und Ansagen
| Was du siehst | Was hilft |
|---|---|
| Alarm zu oft / zu früh | Schwellen anpassen, «Wiederholen alle» verlängern oder die Überwachung ausschalten. |
| Ton und Zahl ohne Worte | `scripts/helirf/audio` fehlt: neu installieren. |
| keine Drehzahlansage | Gaskanal, «Ein», über 300 U/min, Gas ≤ −25 %, Lautstärke. |
| keine «Autorotation» | Motorschalter und «Stellung Motor aus» gesetzt, «Autorotation alle» nicht 0, Rotor dreht. |
| Alarm still bei Motor aus | Haken «Auch bei Motor aus» entfernt ([Alarme](Alarme.md)). |

## Weitere Hinweise
- **Hinweise zur Studio-Datei** («kaputt», «zu neu», «n Fehler», «n Symbole fehlen»): aus Lua-Studio neu übertragen oder Heli RF aktualisieren; Einzelheiten im Log.
- **Rote Zeile «Heli RF: …»:** Das Widget hat einen Fehler gemeldet; der Sender läuft weiter. Foto + Meldung.
- **«Feld zu klein»:** Vollbild oder ein Feld mit Leisten nehmen.
- **«Heli RF» fehlt in der Widget-Liste:** Lua-Bibliothek der Suite prüfen, neu starten; von Hand muss `main.lua` in `scripts/helirf/` auf dem Laufwerk liegen, von dem der Sender lädt.

## Update
Die neue Version wie unter [Installation](Installation.md) aufspielen. Einstellungen, Flugzähler und Flugliste bleiben. 1.12.0 speichert in einem neuen Format (Auch bei Motor aus = ein nach dem Update); eine ältere Version nimmt danach Werkseinstellungen.

---
[← Start](../Home.md) | [Zurück](FAQ.md) | [Weiter →](Versionen.md)
