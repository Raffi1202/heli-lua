🇬🇧 [English](../en/Alarms.md) · 🇩🇪 [Deutsch](../de/Alarme.md)

# Alarme

> **Vorabversion:** Version 1.14.4 ist im Ethos-Simulator getestet; der Sendertest an der X18RS folgt. Nutzung auf eigene Verantwortung.

## Grün, orange, rot
Fünf Werte werden überwacht, jeder mit zwei Schwellen:
- **Orange:** nur die Anzeige wird orange. Kein Ton.
- **Rot:** Anzeige und Rahmen rot, die Kopfzeile blinkt, dazu Ton, Vibration und Ansage (z. B. «Akku, 20 Prozent»), wiederholt im eingestellten Takt.

| Gruppe | Orange | Rot + Ton | ab Werk | Takt |
|---|---|---|---|---|
| Reglertemperatur | ab 70 °C | ab 80 °C | ein | 5 s |
| Akku % | unter 35 % | unter 25 % | ein | 10 s |
| Zellenspannung | unter 3,60 V (Li-Ion 3,10) | unter 3,50 V (Li-Ion 3,00) | ein | 10 s |
| BEC-Spannung | unter 7,2 V | unter 7,0 V | aus | 10 s |
| Verbrauch | ab 3500 mAh | ab 4000 mAh | aus | 20 s |

Rot beginnt nach einer Sekunde jenseits der Schwelle und endet mit etwas Abstand. Ohne Wert bleibt eine Überwachung still. Laufen Drehzahlansage oder «Autorotation», kommt höchstens alle 10 s ein Alarm.

![Alarm](../../docs/bilder-simulator/Heli%20-%20Sim%20800x480%2006%20Alarm.png)

## Auch bei Motor aus (neu in 1.12.0)
Jede Alarmgruppe hat den Haken **Auch bei Motor aus**, ab Werk ein. Ist er weg und steht der Motorschalter auf «Motor aus», schweigt dieser Alarm: kein Ton, keine Vibration, keine Ansage. Die Anzeige wird trotzdem orange bzw. rot, und sobald der Motor wieder ein ist, kommt der Alarm wieder. Ohne Motorschalter wirkt der Haken nicht. In Lua-Studio gibt es dieselbe Einstellung je Grenze (`beiMotorAus`).

## Was nie stumm wird
- **Ganz still nur mit «aus»:** Ein Alarm schaltet nur ab mit «Ein» = aus im Menü oder `aus = true` in der Studio-Datei. Eine Studio-Datei ohne Schwellen oder mit beiden Schwellen `false` behält die Werkgrenze; `ansage = false` bzw. `vibration = false` lassen einen Ton übrig.
- **Kommt immer:** «Drehzahl verloren» vom Governor (Ton, Vibration, Ansage, höchstens alle 10 s), mit oder ohne Motorschalter.

## Drehzahlansage und «Autorotation»
Steht der Gaskanal auf −25 % oder tiefer und dreht der Rotor (über 300 U/min), sagt der Sender jede Sekunde die Drehzahl an. Schaltest du den Motor mit dem Motorschalter aus, während der Rotor dreht, kommt alle 3 s «Autorotation», bis der Rotor steht oder der Motor wieder ein ist.

---
[← Start](../Home.md) | [Zurück](Anzeige.md) | [Weiter →](Lua-Studio.md)
