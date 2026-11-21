🇬🇧 [English](../en/Setup.md) · 🇩🇪 [Deutsch](../de/Einrichten.md)

# Einrichten

Die Einstellungen des Widgets öffnest du über Bildschirme › Bildschirm wählen › ins Widget tippen. Alarme, Ansagen und Flugliste brauchen keine Sonderfunktionen im Modell.

![Menü](../../docs/bilder-simulator/Heli%20RF%20-%20Sim%20800x480%2002%20Menue.png)

## Sensoren (einmal je Modell)
1. Heli einschalten, damit Telemetrie läuft.
2. **Sensoren automatisch suchen › Suchen.** Das Widget füllt jedes leere Sensorfeld, das es erkennt (nach Application ID, nicht nach Namen; eigene Rotorflight-Sensoren nach Name und Einheit).
3. Gruppe **Sensoren** öffnen und jedes Feld kontrollieren. Leere oder falsche Felder von Hand setzen. Die Suche kann sich irren.
4. **Nur Rotorflight:** In der Rotorflight-Telemetrie *Governor State* und *Arming Flags* einschalten. Heli RF liest sie direkt (AppID 0x5125 / 0x5122).

| Feld | Sensor |
|---|---|
| Akku % | Restladung in %; leer lassen, dann rechnet das Widget selbst |
| Akkuspannung | Gesamtspannung des Flugakkus |
| Drehzahl | Rotordrehzahl, sonst die Drehzahl des Reglers |
| Strom / Reglertemperatur | vom Regler |
| BEC-Spannung | BEC bzw. Empfängerversorgung |
| Zellenspannung | je Zelle; ein Zellensensor (FLVSS) geht auch; leer geht, wenn *Zellen* eingestellt ist |
| Verbrauch mAh | verbrauchte Kapazität |
| RSSI | Empfangsbalken |
| PID-Profil, Raten-Profil | nicht nötig (z. B. Rotorflight) |

## Weitere Gruppen
- **Akku:** Zellen, Kapazität, Akkutyp (LiPo, LiHV, Li-Ion). Nötig für die %-Anzeige ohne %-Sensor.
- **Alarm …:** Schwellen, siehe [Alarme](Alarme.md).
- **Drehzahlansage › Gaskanal:** ohne ihn keine Drehzahlansage.
- **Flug und Motorschalter:** der Schalter, mit dem du den Motor ausschaltest, und seine Stellung «Motor aus». Ohne Schalter erkennt das Widget Flüge an der Drehzahl, und es gibt keine Ansage «Autorotation».
- **Tachos: Endwert der Skala:** Endwerte der Tachos.
- **Anzeige und Flugzähler › Sprache / Language:** wie der Sender, Deutsch oder English.
- **Flüge ohne Berührung:** für X14, X10, X12 (Seite, Flug wählen, löschen, beenden).

Die Einstellungen werden mit dem Modell gespeichert. Mit einer Studio-Datei gelten deren Einstellungen, siehe [Lua-Studio](Lua-Studio.md).

---
[← Start](../Home.md) | [Zurück](Installation.md) | [Weiter →](Anzeige.md)
