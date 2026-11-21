-- Heli: Rotorflight-Rahmen im Ethos-Simulator 26.2 (Makro). Speist Governor-Zustand (0x5125) und Arming-Flags
-- (0x5122) auf Physical ID 0x1B ein, ohne Sensor im Modell. Danach muss das Widget AKTIV und SCHARF zeigen
-- (Bild im Ablauf direkt nach dem Makro). Kein Teil des Widgets.
local function frame(phys, app, v)
  simulator.injectSPortFrame({ module = 0, band = 0, rx = 0, physId = phys, primId = 0x10, appId = app, value = v })
end
local gov = GOV or 4
for _ = 1, 40 do
  frame(0x10, 0xF101, 80) frame(0x1B, 0x5125, gov) frame(0x1B, 0x5122, 1) frame(0x1B, 0x0500, 2150)
  simulator.sleep(0.05)
end
local n = 0
for _, q in ipairs(system.getSources(CATEGORY_TELEMETRY_SENSOR)) do
  local a = q:appId()
  if a == 0x5125 or a == 0x5122 then n = n + 1 end
end
print("TEST Sensoren mit 5125/5122 im Modell: " .. n .. " (erwartet 0)")
