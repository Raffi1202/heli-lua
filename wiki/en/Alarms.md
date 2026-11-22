🇬🇧 [English](../en/Alarms.md) · 🇩🇪 [Deutsch](../de/Alarme.md)

# Alarms

> **Pre-release:** version 1.15.1 is tested in the Ethos simulator; the transmitter test on the X18RS follows. Use at your own risk.

## Green, orange, red
Five values are monitored, each with two thresholds:
- **Orange:** only the display turns orange. No sound.
- **Red:** display and frame red, header flashes, plus tone, vibration and announcement (e.g. «Battery, 20 percent»), repeated at the set interval.

| Group | Orange | Red + sound | Factory | Interval |
|---|---|---|---|---|
| ESC temperature | from 70 °C | from 80 °C | on | 5 s |
| Battery % | below 35 % | below 25 % | on | 10 s |
| Cell voltage | below 3.60 V (Li-Ion 3.10) | below 3.50 V (Li-Ion 3.00) | on | 10 s |
| BEC voltage | below 7.2 V | below 7.0 V | off | 10 s |
| Used capacity | from 3500 mAh | from 4000 mAh | off | 20 s |

Red starts after one second beyond the threshold and ends with some margin. Without a value a monitor stays silent. While the RPM callout or «Autorotation» runs, at most one alarm comes every 10 s.

## Also with motor off (new in 1.12.0)
Each alarm group has the tick **Also with motor off**, on by default. If it is removed and the motor switch is in the «motor off» position, this alarm stays silent: no sound, no vibration, no announcement. The display still turns orange or red, and the alarm comes back as soon as the motor is on. Without a motor switch the tick has no effect. In Lua-Studio the same setting exists per limit (`beiMotorAus`).

## What is never silent
- **Completely silent only with «off»:** an alarm is only switched off by «On» = off in the menu or `aus = true` in the Studio file. A Studio file without thresholds or with both thresholds `false` keeps the factory limit; `ansage = false` / `vibration = false` still leave a tone.
- **Always comes:** «Lost headspeed» from the governor (tone, vibration, announcement, at most every 10 s), with or without motor switch.

## RPM callout and «Autorotation»
With the throttle channel at −25 % or lower and the rotor turning (above 300 RPM) the head speed is called out every second. Turning off the motor with the motor switch while the rotor turns gives «Autorotation» every 3 s until the rotor stops or the motor is back on.

---
[← Home](../Home.md) | [Previous](Display.md) | [Next →](Lua-Studio.md)
