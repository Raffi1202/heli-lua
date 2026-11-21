-- Heli Demo: Makro für die FrSky Suite (Simulator). Spielt einen Heli-Flug als Schleife ab.
-- Nur zur Vorführung im Simulator, nie Teil des Widgets und nichts für den echten Sender.
-- Legt fehlende Sensoren im Modell an, speist Telemetrie ein (S.Port), bewegt den Gasknüppel und den Motorschalter SA.
-- Ablauf: am Boden (Motor aus), Motor ein, Hochlaufen, Schweben, 3D, Regler zu heiss (Alarm), Motor aus mit
-- Autorotation (Drehzahlansage, Rückfrage «Flug beendet?»), gelandet. Ohne Antwort läuft der Flug als Pause weiter.
-- Stoppen mit «Makro stoppen» in der Suite.
local GAS_GEBER = 1      -- simulator.setAnalog: Geber 1 = Gasknüppel (gemessen im Simulator 26.1.2)
local SCHALTER = 0       -- simulator.setSwitch: SA (-1 oben = Motor aus, 1 unten = Motor ein)
local DT = 0.1
local ZELLEN = 12
local KAPAZ = 5000       -- mAh

-- Sensoren: Name, AppID, Einheit, Kommastellen
local PHYS = 0x10
local SENS = {
  { "Headspeed", 0x5210, UNIT_RPM, 0 }, { "Current", 0x5211, UNIT_AMPERE, 1 },
  { "ESC Temp", 0x5212, UNIT_CELSIUS, 0 }, { "BEC Voltage", 0x5213, UNIT_VOLT, 2 },
  { "Voltage", 0x5214, UNIT_VOLT, 2 }, { "Consumption", 0x5215, UNIT_MILLIAMPERE_HOUR, 0 },
  { "Charge Level", 0x5216, UNIT_PERCENT, 0 }, { "Cell Voltage", 0x5217, UNIT_VOLT, 2 },
  { "PID Profile", 0x5218, nil, 0 }, { "Rate Profile", 0x5219, nil, 0 }, { "RSSI", 0x521A, UNIT_PERCENT, 0 },
}

local function frame(phys, app, v)
  simulator.injectSPortFrame({ module = 0, band = 0, rx = 0, physId = phys, primId = 0x10, appId = app, value = v })
end
local function finde(app)
  local ok, liste = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  if not ok or type(liste) ~= "table" then return nil end
  for _, q in ipairs(liste) do
    local o1, a = pcall(q.appId, q)
    if o1 and a == app then return q end
  end
  return nil
end
local function anlegen(name, app, unit, dez)
  if finde(app) then return "da" end
  local ok, e = pcall(function()
    local s = model.createSensor({ type = SENSOR_TYPE_DIY })
    s:appId(app); s:physId(PHYS)
    if unit then s:unit(unit) end
    s:decimals(dez); pcall(s.protocolDecimals, s, dez)
    s:name(name)
  end)
  return ok and "neu" or ("Fehler: " .. tostring(e))
end
local function wert(app, x, dez) frame(PHYS, app, math.floor(x * 10 ^ (dez or 0) + 0.5)) end

-- Abschnitte: Dauer s, Gas % (−100 … 100), Drehzahl, Strom A, Reglertemperatur °C, PID-Profil, Text
local AB = {
  { 5, -100, 0, 2, 35, 1, "Am Boden, Motor aus" },
  { 8, 20, 1900, 25, 40, 1, "Hochlaufen" },
  { 15, 40, 2000, 60, 55, 1, "Schweben" },
  { 15, 80, 2250, 180, 78, 2, "3D-Flug" },
  { 10, 85, 2200, 200, 86, 2, "Regler zu heiss: Warnung" },
  { 3, -100, 2150, 3, 80, 2, "Gas weg" },
  { 10, -100, 1100, 3, 72, 2, "Autorotation: Drehzahlansage" },
  { 4, -100, 0, 2, 62, 1, "Gelandet" },
}

for _, s in ipairs(SENS) do print("HELIRFDEMO Sensor " .. s[1] .. " " .. anlegen(s[1], s[2], s[3], s[4])) end

local mah = 0
local function schritt(a, b, f)
  local function m(i) return a[i] + (b[i] - a[i]) * f end
  local rpm, strom, temp = m(3), m(4), m(5)
  mah = mah + strom * DT / 3.6
  if mah > KAPAZ * 0.85 then mah = 0 end                       -- «frischer Akku», damit die Schleife endlos läuft
  local volt = ZELLEN * (4.15 - 0.55 * mah / KAPAZ) - strom * 0.012
  frame(0x00, 0xF101, 75 + math.random(0, 10))                -- RSSI: hält die Telemetrie aktiv
  wert(0x5210, rpm); wert(0x5211, strom, 1); wert(0x5212, temp)
  wert(0x5213, 7.9 - strom / 1000, 2); wert(0x5214, volt, 2); wert(0x5215, mah)
  wert(0x5216, 100 - mah / KAPAZ * 100); wert(0x5217, volt / ZELLEN, 2)
  wert(0x5218, b[6]); wert(0x5219, b[6]); wert(0x521A, 78 + math.random(0, 8))
  simulator.setAnalog(GAS_GEBER, math.floor(b[2] <= -100 and -100 or m(2)))
  simulator.setSwitch(SCHALTER, (b[2] <= -100) and -1 or 1)
end

for _ = 1, 20 do schritt(AB[1], AB[1], 1); simulator.sleep(DT) end
local tel = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = SYSTEM_EVENT_TELEMETRY_ACTIVE })
print("HELIRFDEMO Telemetrie aktiv: " .. ((tel and (tel:value() or 0) > 0) and "ja" or "nein"))
for _, s in ipairs(SENS) do
  local q = finde(s[2])
  print("HELIRFDEMO Wert " .. s[1] .. " = " .. tostring(q and q:value()))
end
simulator.setAnalog(GAS_GEBER, -100); simulator.sleep(0.3)
local g = system.getSource({ category = CATEGORY_ANALOG, member = 2 })
print("HELIRFDEMO Gasknueppel " .. tostring(g and g:name()) .. " = " .. tostring(g and g:value()))

while true do
  for i = 1, #AB do
    local a, b = AB[i == 1 and #AB or i - 1], AB[i]
    print("HELIRFDEMO Abschnitt: " .. b[7])
    local n = math.floor(b[1] / DT)
    for k = 1, n do
      schritt(a, b, math.min(1, k / n * 2))                    -- in der ersten Hälfte des Abschnitts auf den Zielwert
      simulator.sleep(DT)
    end
  end
end
