🇬🇧 [English](../en/Display.md) · 🇩🇪 [Deutsch](../de/Anzeige.md)

# Anzeige

![Vollbild](../../docs/bilder-simulator/Heli%20RF%20-%20Sim%20800x480%2004%20Normal.png)

Vollbild: oben Modellname, Uhrzeit, Profil/Rate, Empfang, Senderakku; Tachos für Akku %, Drehzahl, Strom und Reglertemperatur (jeweils MAX = höchster Wert mit diesem Akku); Felder für Governor mit SCHARF/SICHER und Flugzähler (antippen = Flugliste), Flugmodus, BEC-Spannung und Zellenspannung (TIEF = tiefster Wert) und Verbrauch mit **AUF 0**. `--` heisst: keine Telemetrie oder kein Sensor zugewiesen.

**Governor (Rotorflight):** AUS, LEERLAUF, HOCHLAUF, WIEDERANLAUF, BAILOUT, BYPASS, AKTIV, HOLD, AUTOROTATION, DREHZAHL VERLOREN (rot, Ton, Vibration, Ansage). Ohne Rotorflight-Werte steht «--» und «nur mit Rotorflight». SCHARF/SICHER kommt aus den Arming Flags, sonst vom Motorschalter.

## Kompaktansicht
Im Layout mit Leisten zeichnet das Widget oben eine schmale Leiste (Flugzeit, SCHARF/SICHER, Profil/Rate, Empfang), vier Tachos und acht Felder: Governor, Zelle, Verbraucht (antippen = auf 0), BEC, Flugmodus, Empfang, Leistung und Flüge. Die Grösse erkennt es selbst.

![Kompaktansicht](../../docs/bilder-simulator/Heli%20RF%20-%20Sim%20784x316%2030%20Kompakt.png)

## Flugliste (Seite 2)
Nach links wischen, den Flugzähler antippen oder das Drehrad nach rechts drehen. Die letzten 20 Flüge, der neueste oben. Einen Flug antippen zeigt seine Werte; **FLUG … LÖSCHEN** entfernt einen, **LISTE LÖSCHEN** alle (der Flugzähler bleibt). Gespeichert je Modell in `scripts/helirf/daten/`.

![Flugliste](../../docs/bilder-simulator/Heli%20RF%20-%20Sim%20800x480%2020%20Flugliste.png)

**Flüge:** Mit Motorschalter beginnt «Motor ein» einen Flug, «Motor aus» hält ihn an und fragt «Flug beendet?» (**JA, BEENDET** / **NEIN, NUR PAUSE**). Ohne Schalter beginnt ein Flug über 500 U/min und endet 5 s darunter. Ein Flug zählt erst ab 30 s.

**Sprache:** Anzeige und Flugzähler › Sprache / Language.

---
[← Start](../Home.md) | [Zurück](Einrichten.md) | [Weiter →](Alarme.md)
