🇬🇧 [English](../en/Setup.md) · 🇩🇪 [Deutsch](../de/Einrichten.md)

# Setup

Open the widget's settings via Screens › choose the screen › tap into the widget. Alarms, announcements and the flight list need no special functions in the model.

![Menu](../../docs/bilder-simulator/Heli%20-%20Sim%20800x480%2002%20Menue.png)

## Sensors (once per model)
1. Switch on the heli so that telemetry is running.
2. **Find sensors automatically › Search.** The widget fills every empty sensor field it recognises (by Application ID, not by name; custom sensors by name and unit).
3. Open the group **Sensors** and check every field. Set empty or wrong fields by hand. The search can be wrong.
4. **Governor (optional):** if your flybarless system sends them, enable *Governor State* and *Arming Flags* in its telemetry. Heli reads them directly (AppID 0x5125 / 0x5122).

| Field | Sensor |
|---|---|
| Battery % | remaining charge in %; leave empty and the widget calculates it |
| Battery voltage | total voltage of the flight battery |
| Head speed | rotor speed, otherwise the ESC RPM |
| Current / ESC temperature | from the ESC |
| BEC voltage | BEC or receiver supply |
| Cell voltage | per cell; a cell sensor (FLVSS) works too; empty works if *Cells* is set |
| Used capacity mAh | capacity used |
| RSSI | signal bars |
| PID profile, Rate profile | optional |

## Other groups
- **Battery:** Cells, Capacity, Battery type (LiPo, LiHV, Li-Ion). Needed for the % display without a % sensor.
- **Alarm …:** thresholds, see [Alarms](Alarms.md).
- **RPM callout › Throttle channel:** without it there is no RPM callout.
- **Flight and motor switch:** the switch that turns off the motor and its «motor off» position. Without a switch, flights are detected by head speed and there is no «Autorotation» announcement.
- **Gauges: full scale:** full-scale values of the gauges.
- **Display and flight count › Sprache / Language:** same as radio, Deutsch or English.
- **Flights without touch:** for X14, X10, X12 (page, select / delete / finish flight).

Settings are saved with the model. With a Studio file its settings apply, see [Lua-Studio](Lua-Studio.md).

---
[← Home](../Home.md) | [Previous](Installation.md) | [Next →](Display.md)
