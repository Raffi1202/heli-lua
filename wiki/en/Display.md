🇬🇧 [English](../en/Display.md) · 🇩🇪 [Deutsch](../de/Anzeige.md)

# Display

![Full screen, English](../../docs/bilder-simulator/Heli%20-%20Sim%20800x480%2012%20Englisch.png)

Full screen: model name, time, profile/rate, signal, radio battery at the top; gauges for battery %, head speed, current and ESC temperature (each with MAX = highest value with this battery); fields for Governor with ARMED/SAFE and flight count (tap = flight list), flight mode, BEC voltage and cell voltage (LOW = lowest value) and used mAh with **RESET**. `--` means: no telemetry or no sensor assigned.

**Governor (Rotorflight):** OFF, IDLE, SPOOLUP, RECOVERY, BAILOUT, BYPASS, ACTIVE, HOLD, AUTOROTATION, LOST HEADSPEED (red, tone, vibration, announcement). Without Rotorflight values it shows «--» and «Rotorflight only». ARMED/SAFE comes from the arming flags, otherwise from the motor switch.

## Compact view
In the layout with bars the widget draws a narrow top bar (flight time, ARMED/SAFE, profile/rate, signal), four gauges and eight fields: Governor, Cell, Used (tap = reset), BEC, Flight mode, Signal, Power and Flights. The size is detected automatically.

![Compact view, English](../../docs/bilder-simulator/Heli%20-%20Sim%20784x316%2034%20Kompakt%20Englisch.png)

## Flight list (page 2)
Swipe left, tap the flight count or turn the rotary encoder right. The last 20 flights, the newest at the top. Tap a flight to see its values; **DELETE FLIGHT …** removes one, **CLEAR LIST** all (the flight count is kept). Saved per model in `scripts/heli/daten/`.

**Flights:** with a motor switch, «motor on» starts a flight, «motor off» pauses it and asks «Flight finished?». Without a switch a flight starts above 500 RPM and ends 5 s below. A flight only counts after 30 s.

**Language:** Display and flight count › Sprache / Language. The screenshots in the manual show the German display.

---
[← Home](../Home.md) | [Previous](Setup.md) | [Next →](Alarms.md)
