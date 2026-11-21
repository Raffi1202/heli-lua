-- Heli RF: Sensorsuche im Ethos-Simulator 26.2 mit echten Quellen (per Lua angelegt). Kein Teil des Widgets.

local function frame(phys, app, v)
  simulator.injectSPortFrame({ module = 0, band = 0, rx = 0, physId = phys, primId = 0x10, appId = app, value = v })
end
local function neu(name, app, phys, unit)
  local ok, e = pcall(function()
    local s = model.createSensor({ type = SENSOR_TYPE_DIY })
    s:appId(app); s:physId(phys); if unit then s:unit(unit) end; s:name(name)
  end)
  if not ok then print("TEST anlegen Fehler " .. name .. " " .. tostring(e)) end
end
local L = {
  { "ESC Strom", 0x0B50, 0x0A, UNIT_AMPERE }, { "ESC Spannung", 0x0B50, 0x0A, UNIT_VOLT },
  { "ESC Temp.", 0x0B70, 0x0E, UNIT_CELSIUS }, { "ESC Temp.", 0x0B70, 0x0A, UNIT_CELSIUS },
  { "ESC U/min", 0x0B60, 0x0A, UNIT_RPM }, { "Drehzahl", 0x0500, 0x10, UNIT_RPM },
  { "Spannung", 0x0211, 0x10, UNIT_VOLT }, { "Spannung", 0x0210, 0x10, UNIT_VOLT },
  { "ADC3", 0x0900, 0x10, UNIT_VOLT }, { "ADC4", 0x0910, 0x10, UNIT_VOLT },
  { "Strom", 0x0222, 0x10, UNIT_AMPERE }, { "Kraftstoff", 0x0600, 0x10, UNIT_PERCENT },
  { "Headspeed", 0x5100, 0x10, UNIT_RPM }, { "PID Profile", 0x5130, 0x10, nil }, { "Temp. 1", 0x0400, 0x10, UNIT_CELSIUS },
}
for i = 1, 100 - #L do L[#L + 1] = { "Fueller " .. i, 0x5200 + i, 0x10, UNIT_VOLT } end   -- zusammen 100 Sensoren
for _, s in ipairs(L) do neu(s[1], s[2], s[3], s[4]) end
for _ = 1, 20 do frame(0x10, 0xF101, 80) frame(0x0A, 0x0B70, 45) simulator.sleep(0.05) end
local function lade(n)
  for _, p in ipairs({ "/scripts/helirf/" .. n, "scripts/helirf/" .. n, n }) do
    local f = loadfile(p)
    if f then return f end
  end
  error("nicht gefunden: " .. n)
end
local function gut(v) if type(v) == "number" and v == v then return v end return nil end
local ok, e = pcall(function()
  local w = { cfg = {} }
  local schritt = lade("suche.lua")()(w, lade("kennung.lua")(), gut)
  local fertig, n, k = false, 0, 0
  while not fertig do fertig, n = schritt() k = k + 1 end
  local okL, lst = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  print("TEST Sensoren " .. (okL and #lst or -1) .. ", Schritte " .. k)
  print("TEST neu zugewiesen " .. n)
  for _, f in ipairs({ "qVolt", "qStrom", "qZelle", "qTemp", "qBec", "qRpm", "qProz", "qMah", "qRssi", "qPid" }) do
    local q = w.cfg[f]
    local t = "nil"
    if q then t = q:name() .. string.format(" %04X/%02X sub=%s", q:appId(), q:physId(), tostring(q:subId())) end
    local h = w.hinweise[f]
    print("TEST " .. f .. " = " .. t .. (h and (" HINWEIS " .. h[1] .. " " .. h[2]) or ""))
  end
  local w2 = { cfg = {} }
  local s2 = lade("suche.lua")()(w2, lade("kennung.lua")(), gut)
  local f2, n2 = false, 0
  while not f2 do f2, n2 = s2() end
  print("TEST zweiter Lauf mit leerem cfg " .. tostring(n2))
end)
print("TEST Ergebnis " .. tostring(ok) .. " " .. tostring(e))
