# Heli RF: Sprachansagen

Diese Liste ist die einzige Quelle der Ansagen. Texte immer hier ändern und dann neu erzeugen
(mit einem eigenen TTS-Werkzeug).
Ablage: `src/helirf/audio/de/<Dateiname>.wav` und `src/helirf/audio/en/<Dateiname>.wav`.
Format WAV A-law, mono, 16 kHz, 8 Bit. Stimmen wie die Ethos-Originale: deutsch de-DE-Wavenet-E (Tempo 1,1),
englisch en-US-Wavenet-F. Vorne und hinten keine Stille, weil direkt danach die Zahl folgt.

| Dateiname | Deutsch | Englisch | Aussprache-Hinweis | Wann |
|---|---|---|---|---|
| `alarm_reglertemperatur` | Reglertemperatur | ESC temperature | ESC im Englischen buchstabiert | Reglertemperatur im roten Bereich, danach die Zahl mit «Grad Celsius» |
| `alarm_akku` | Akku | Battery | – | Akku % im roten Bereich, danach die Zahl mit «Prozent» |
| `alarm_zellenspannung` | Zellenspannung | Cell voltage | – | Zellenspannung im roten Bereich, danach die Zahl mit «Volt» |
| `alarm_bec` | BEC-Spannung | BEC voltage | BEC als Wort gesprochen («Beck»), nicht buchstabiert (Wahl des Auftraggebers) | BEC-Spannung im roten Bereich, danach die Zahl mit «Volt» |
| `alarm_verbrauch` | Verbrauch | Capacity used | – | Verbrauch im roten Bereich, danach die Zahl mit «Milliamperestunden» |
| `autorotation` | Autorotation | Autorotation | – | nach Motor aus per Motorschalter bei drehendem Rotor, alle 3 s, bis der Rotor steht |
| `drehzahl_verloren` | Achtung! Drehzahl verloren | Warning! Headspeed lost | «Headspeed» englisch | Rotorflight-Governor wechselt auf «Fallback» (Drehzahlsignal fehlt), einmal beim Wechsel, ohne Zahl (seit 1.9.0) |

Zahlen und Einheiten spricht Ethos selbst in der Sprache des Senders (`system.playNumber`). Die Drehzahlansage ist
nur eine Zahl ohne Datei. Fehlt eine Datei, bleibt beim Alarm Ton und Zahl, bei «Autorotation» kommen drei kurze Töne.

Stand 17.11.2026: Alle zwölf Dateien sind erzeugt und vom Auftraggeber am Computer angehört und abgenommen. Am
Sender noch nicht gehört.

`drehzahl_verloren` (20.11.2026, ethos-sounds 1.0.0): erzeugt, noch nicht angehört.
