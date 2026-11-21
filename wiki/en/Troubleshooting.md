🇬🇧 [English](../en/Troubleshooting.md) · 🇩🇪 [Deutsch](../de/Fehlerbehebung.md)

# Troubleshooting

## Lua memory
All Lua scripts on the radio share one Lua memory, about **2048 KB on the X18RS**. Every Lua that has been shown since switching on keeps part of it. If Ethos reports **«too much RAM»** (Lua has used too much RAM) or a script stops: **switch the radio off and on again.** Remove scripts you do not use. Since 1.12.0 Heli RF frees almost all of its memory after a model change (about 4–5 KB stay, measured in the simulator).

## Sensors
| Symptom | Help |
|---|---|
| `--` everywhere | Heli on, telemetry present? Assign the sensors ([Setup](Setup.md)). |
| One value `--` or nonsense | Set the field under Sensors by hand. |
| «SET CELLS» / cell voltage `--` | Set Cells under Battery. |
| Battery % `--` or wrong | Set Cells and Capacity; clear «Battery %» if a % sensor shows wrong values. |
| Governor «--», «Rotorflight only» | Enable Governor State and Arming Flags in Rotorflight. Normal without Rotorflight. |
| ESC temperature stops at 100 °C | Increase the sensor maximum in Ethos (range −30 to 100 °C). |

## Alarms and announcements
| Symptom | Help |
|---|---|
| Alarm too often / too early | Adjust thresholds, lengthen «Repeat every», or switch the monitor off. |
| Tone and number without words | `scripts/helirf/audio` missing: install again. |
| No RPM callout | Throttle channel, «On», above 300 RPM, throttle ≤ −25 %, volume. |
| No «Autorotation» | Motor switch and «Motor off position» set, «Autorotation every» not 0, rotor turning. |
| Alarm silent with motor off | Tick «Also with motor off» removed ([Alarms](Alarms.md)). |

## Other notes
- **Studio file notes** («broken», «too new», «n errors», «n symbols missing»): transfer again from Lua-Studio or update Heli RF; details in the log.
- **Red line «Heli RF: …»:** the widget reported an error; the radio keeps running. Photo + report.
- **«zone too small»:** use Full screen or one field with bars.
- **«Heli RF» missing from the widget list:** check the Suite's Lua library, restart; by hand `main.lua` must be in `scripts/helirf/` on the drive the radio loads from.

## Update
Install the new version like [Installation](Installation.md). Settings, flight count and flight list are kept. 1.12.0 saves in a new format (Also with motor off = on after the update); an older version then uses factory settings.

---
[← Home](../Home.md) | [Previous](FAQ.md) | [Next →](Changelog.md)
