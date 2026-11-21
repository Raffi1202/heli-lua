# Heli: Anforderungen und Entscheide

Angelegt 17.11.2026. Hier steht, was das Widget können muss und was entschieden wurde.

## Auftrag

Vom 17.11.2026:

- Lua-Widget für die X18: Warnton, wenn der Regler 80 °C erreicht; Drehzahlansage jede Sekunde bei Gas −25 % oder tiefer.
- Feld Governor bzw. Flugmodus; alles einstellbar.
- Oben der Modellname.
- Anleitung zum Weitergeben; das Lua darf nicht abstürzen.
- Verbrauch zurücksetzen; Akku % richtig bei der eingestellten Zellenzahl.
- Schwellwerte der Alarme einstellbar, in zwei Stufen (grün, orange ohne Ton, rot mit Ton und Rahmen); Tachos unten offen.
- Flugliste auf einer zweiten Seite, Flug antippen zeigt seine Werte; Motorschalter startet und beendet den Flug, mit
  Pause und Rückfrage, Schalterstellung einstellbar; einzelne Flüge löschbar.
- Ansage «Autorotation» nach Motor aus, bis der Rotor steht.
- Deutsch und Englisch, auch die Ansagen.
- Knopf zum Zurücksetzen der Kapazität.

## Was es zeigen und können muss

| Nr. | Anforderung | Stand |
|---|---|---|
| 1 | Vollbild-Anzeige mit Akku %, Drehzahl, Strom, Reglertemperatur, Flugmodus, BEC, Zellenspannung, Verbrauch, Modellname | erfüllt |
| 2 | Alarm Reglertemperatur ab 80 °C, weitere Alarme (Akku %, Zelle, BEC, Verbrauch), Schwellen einstellbar | erfüllt (seit 1.2.0) |
| 3 | Zwei Schwellen: grün, orange ohne Ton, rot mit Umrandung, Ton und Ansage | erfüllt (1.4.0) |
| 4 | Drehzahlansage jede Sekunde bei Gas −25 % oder tiefer | erfüllt |
| 5 | Ansage «Autorotation» nach Motor aus, bis der Rotor steht | erfüllt (1.4.0) |
| 6 | Tachos mit offener Stelle unten, MAX = gemessener Höchstwert | erfüllt (1.4.0) |
| 7 | Verbrauch zurücksetzen mit sichtbarem Knopf; Akku % aus der Ruhespannung | erfüllt (1.1.0, 1.4.0) |
| 8 | Flugliste auf Seite 2, Werte des angetippten Flugs, einzelne Flüge und ganze Liste löschen | erfüllt (1.3.0, 1.5.0) |
| 9 | Flug über den Motorschalter, Rückfrage «Flug beendet?», Pause | erfüllt (1.3.0) |
| 10 | Alles deutsch und englisch, auch die Ansagen | erfüllt (1.4.0) |
| 11 | Anleitung als PDF, ZIP zum Weitergeben | erfüllt |
| 12 | Alle Displaygrössen, Bedienung auch ohne Berührung, Paket für die FrSky Suite | erfüllt (1.6.0), am Sender ungetestet |

## Freigabe des Konzepts

- 17.11.2026: Das Aussehen wurde schrittweise mit Bildern aus dem Simulator abgestimmt. Ein Konzeptblatt nach dem
  heutigen Bauplan gibt es für dieses Projekt nicht.

## Entscheide

| Datum | Entscheid | Grund |
|---|---|---|
| 17.11.2026 | Eigenes Widget statt fertiger Rotorflight-Suite | keines der Themes der Suite passte |
| 17.11.2026 | Drehzahlansage nur über 300 U/min | sonst sagt sie am Boden mit Gas aus dauernd «null» |
| 17.11.2026 | Ein Flug zählt ab 30 s; pausiert und Akku 30 s weg = beendet | kurze Läufe am Boden sollen nicht zählen (einstellbar) |
| 17.11.2026 | Rückfragen auf der Seite selbst gezeichnet | Alarme und Ansagen laufen weiter, während die Frage offen ist |
| 17.11.2026 | Tachos, Farben nach Schwellen, kein «P3» | Wunsch des Auftraggebers |
| 17.11.2026 | Skriptordner bleibt `heli`, Widget-Schlüssel `heli` | schon abgegeben; ein neuer Schlüssel würde alle Zuweisungen löschen |
| 17.11.2026 | Einstellungen im Widget-Speicher (50 von rund 51 Werten) | gewachsen; weitere Einstellungen müssten in die Datei unter `daten/` |

## Offen

- Test am echten Sender und im Flug (Schrift, Zusammenspiel der Ansagen, echte Sensornamen).
- Installation über die FrSky Suite ist noch nie ausprobiert.
- 640 × 360, 480 × 320 und 480 × 272 sind nur nachgestellt; Bedienung ohne Berührung nur über das Menü.
- Aufbau des Skripts weicht vom Bauplan ab (keine `felder.lua`/`texte.lua`, kein Konzeptblatt, eigener Zufallstest).
