-- Heli: feste Fälle der automatischen Sensorzuordnung (suche.lua + kennung.lua) auf dem Mac, mit nachgebauten
-- Ethos-Quellen. Pflichtfälle laut «Vorgaben Sensorzuordnung» (a)–(g) und Rotorflight-Besonderheiten.
-- Aufruf (im Repo):  /opt/homebrew/opt/lua@5.4/bin/lua test/suche_test.lua
local DIR = "src/heli/"
UNIT_VOLT, UNIT_AMPERE, UNIT_RPM, UNIT_CELSIUS, UNIT_PERCENT, UNIT_MILLIAMPERE_HOUR, UNIT_DB = 1, 2, 3, 4, 5, 6, 7
CATEGORY_TELEMETRY_SENSOR = 9
local LISTE = {}
system = { getSources = function() return LISTE end }

local Q = {}
Q.__index = Q
function Q:name() return self._n end
function Q:unit() return self._u end
function Q:value() return self._v end
function Q:appId() return self._a end
function Q:subId() return self._s end
function Q:physId() return self._p end
-- Sensor: Name, AppID (nil = ohne Kennung), Teilwert, Physical ID, Einheit, Wert
local function S(n, a, s, p, u, v) return setmetatable({ _n = n, _a = a, _s = s, _p = p, _u = u, _v = v }, Q) end

local gut = function(v) if type(v) == "number" and v == v then return v end return nil end
local suche = dofile(DIR .. "suche.lua")
MAXBEFEHLE = 0
local fehler = 0
local function lauf(liste, cfg)
  LISTE = liste
  local w = { cfg = cfg or {} }
  -- wie am Sender: Laden + Index ist ein Aufruf, danach je Weckruf ein Schritt; Befehle je Aufruf zählen
  local function gezaehlt(f)
    local z = 0
    debug.sethook(function() z = z + 1 end, "", 1)
    local a, b = f()
    debug.sethook()
    if z > MAXBEFEHLE then MAXBEFEHLE = z end
    return a, b
  end
  local schritt = gezaehlt(function() return suche(w, dofile(DIR .. "kennung.lua"), gut) end)
  local fertig, n, k = false, 0, 0
  while not fertig do
    fertig, n = gezaehlt(schritt)
    k = k + 1
    assert(k < 1000, "Suche endet nicht")
  end
  return w, n
end
local function pruef(name, bed, info)
  if bed then print("ok    " .. name) else fehler = fehler + 1 print("FEHLER " .. name .. (info and (": " .. info) or "")) end
end
local function nm(q) return q and (q._n .. string.format("@%04X/%s", q._a or 0, tostring(q._p))) or "nil" end

-- (a) gleichnamige Sensoren verschiedener Geräte: «Strom» 0x0200 (FAS) / 0x0220 (Rotorflight BEC-Strom)
do
  local fas, bec = S("Strom", 0x0200, 0, 2, UNIT_AMPERE, 12), S("Strom", 0x0222, 0, 0x10, UNIT_AMPERE, 1.5)
  local w = lauf({ bec, fas })
  pruef("(a) Akkustrom = FAS 0x0200, nicht BEC-Strom 0x0222", w.cfg.qStrom == fas, nm(w.cfg.qStrom))
  local u1, u2 = S("Bat1 Spannung", 0x1000, 0, 0x10, UNIT_VOLT, 22.1), S("Bat1 Spannung", 0x0F00, 0, 0x19, UNIT_VOLT, 8.1)
  w = lauf({ u1, u2 })
  pruef("(a) Bat1 Spannung: RB-35 (0x0F00) vor 0x1000", w.cfg.qVolt == u2, nm(w.cfg.qVolt))
end
-- (b) zwei Instanzen derselben AppID: tiefste Instanz, Hinweis
do
  local e1, e0 = S("ESC Spannung", 0x0B51, 0, 0x0A, UNIT_VOLT, 22), S("ESC Spannung", 0x0B50, 0, 0x0B, UNIT_VOLT, 23)
  local w = lauf({ e1, e0 })
  pruef("(b) zwei Instanzen: 0x0B50 gewählt", w.cfg.qVolt == e0, nm(w.cfg.qVolt))
  pruef("(b) Hinweis 2 Sensoren", w.hinweise.qVolt and w.hinweise.qVolt[1] == 2)
  -- nur die höhere Instanz liefert einen Wert: die mit Wert gewinnt
  e0._v = nil
  w = lauf({ e1, e0 })
  pruef("(b) Sensor mit gültigem Wert gewinnt", w.cfg.qVolt == e1, nm(w.cfg.qVolt))
end
-- (c) gleiche AppID auf zwei Physical IDs: Standard-Physical-ID (ESC 0x0A), Hinweis
do
  local p0e, p0a = S("ESC Temp.", 0x0B70, 0, 0x0E, UNIT_CELSIUS, 40), S("ESC Temp.", 0x0B70, 0, 0x0A, UNIT_CELSIUS, 41)
  local w = lauf({ p0e, p0a })
  pruef("(c) gleiche AppID, Physical ID 0x0A gewählt", w.cfg.qTemp == p0a, nm(w.cfg.qTemp))
  pruef("(c) Hinweis 2 Sensoren", w.hinweise.qTemp and w.hinweise.qTemp[1] == 2)
end
-- (d) nur Gesamtspannung ohne Zellen; Rotorflight 0x0900 (Steuerplatine) nie als Akku
do
  local fbl, vfas = S("ADC3", 0x0900, 0, 0x10, UNIT_VOLT, 7.9), S("Spannung", 0x0210, 0, 0x10, UNIT_VOLT, 49.8)
  local w = lauf({ fbl, vfas })
  pruef("(d) Akkuspannung = 0x0210", w.cfg.qVolt == vfas, nm(w.cfg.qVolt))
  pruef("(d) kein Zellensensor, Steuerplatine nirgends", w.cfg.qZelle == nil and w.cfg.qBec ~= fbl)
  local zel = S("ADC4", 0x0910, 0, 0x10, UNIT_VOLT, 3.95)
  w = lauf({ fbl, vfas, zel })
  pruef("(d) Rotorflight Ø-Zelle 0x0910 als Zellenspannung", w.cfg.qZelle == zel, nm(w.cfg.qZelle))
end
-- (e) Betaflight-«Kraftstoff» = mAh (Wert über 100) ist kein Akku-%; Rotorflight 0x0600 mit % schon
do
  local bf = S("Kraftstoff", 0x0600, 0, 0x10, UNIT_PERCENT, 1350)
  local w = lauf({ bf })
  pruef("(e) Betaflight-Kraftstoff 1350 nicht als Akku %", w.cfg.qProz == nil, nm(w.cfg.qProz))
  bf._v = 76
  w = lauf({ bf })
  pruef("(e) Rotorflight-Kraftstoff 76 % als Akku %", w.cfg.qProz == bf, nm(w.cfg.qProz))
end
-- per Lua angelegte Sensoren: subId() = nil, gepackte AppID über die Einheit
do
  local u, i = S("ESC Spannung", 0x0B50, nil, 0x0A, UNIT_VOLT, 44), S("ESC Strom", 0x0B50, nil, 0x0A, UNIT_AMPERE, 30)
  local m, r = S("ESC Verbr.", 0x0B60, nil, 0x0A, UNIT_MILLIAMPERE_HOUR, 500), S("ESC U/min", 0x0B60, nil, 0x0A, UNIT_RPM, 9000)
  local w = lauf({ i, u, m, r })
  pruef("subId nil: ESC Spannung/Strom/mAh/U/min über Einheit", w.cfg.qVolt == u and w.cfg.qStrom == i and w.cfg.qMah == m and w.cfg.qRpm == r,
    nm(w.cfg.qVolt) .. " " .. nm(w.cfg.qStrom) .. " " .. nm(w.cfg.qMah) .. " " .. nm(w.cfg.qRpm))
  local t1 = S("Temp. 1", 0x0400, nil, 0x10, UNIT_CELSIUS, 30)
  w = lauf({ t1 })
  pruef("subId nil: einfacher Bereich (Temp. 1) erkannt", w.cfg.qTemp == t1, nm(w.cfg.qTemp))
end
-- (f) leeres Modell
do
  local w, n = lauf({})
  pruef("(f) leeres Modell: nichts zugewiesen, kein Fehler", n == 0 and next(w.cfg) == nil)
end
-- (g) 100 Sensoren, dazwischen die gesuchten
do
  local l = {}
  for i = 1, 96 do l[i] = S("Temp. 2", 0x0410 + (i % 16), 0, i % 28, UNIT_CELSIUS, i) end
  local esc = S("ESC U/min", 0x0B60, 0, 0x0A, UNIT_RPM, 1800)
  local rpm = S("Drehzahl", 0x0500, 0, 0x10, UNIT_RPM, 2100)
  local rx = S("Empf.-Batt.", 0xF104, 0, 0x10, UNIT_VOLT, 8.2)
  local rs = S("RSSI", 0xF101, 0, 0x10, UNIT_DB, 80)
  l[97], l[98], l[99], l[100] = esc, rx, rpm, rs
  local w = lauf(l)
  pruef("(g) 100 Sensoren: Drehzahl 0x0500 vor ESC U/min", w.cfg.qRpm == rpm, nm(w.cfg.qRpm))
  pruef("(g) BEC = Empf.-Batt., RSSI gefunden", w.cfg.qBec == rx and w.cfg.qRssi == rs)
  pruef("(g) Temp. 2 nicht als Reglertemperatur", w.cfg.qTemp == nil, nm(w.cfg.qTemp))
end
-- Rotorflight: DIY-Sensoren 0x5xxx über den Namen; Headspeed vor ESC U/min; von Hand gesetzte Felder bleiben
do
  local hs = S("Headspeed", 0x5100, 0, 0x10, UNIT_RPM, 2000)
  local esc = S("ESC U/min", 0x0B60, 0, 0x0A, UNIT_RPM, 9000)
  local pid = S("PID Profile", 0x5130, 0, 0x10, nil, 2)
  local rate = S("Rate Profile", 0x5131, 0, 0x10, nil, 1)
  local bat = S("Batt Profile", 0x5132, 0, 0x10, nil, 1)
  local et = S("ESC Temp.", 0x0B70, 0, 0x0A, UNIT_CELSIUS, 50)
  local t1 = S("Temp. 1", 0x0400, 0, 0x10, UNIT_CELSIUS, 30)
  local eu = S("ESC Spannung", 0x0B50, 0, 0x0A, UNIT_VOLT, 44)
  local ei = S("ESC Strom", 0x0B50, 1, 0x0A, UNIT_AMPERE, 30)
  local hand = S("Eigene Spannung", nil, 0, nil, UNIT_VOLT, 45)
  local w = lauf({ esc, t1, hs, pid, rate, bat, et, eu, ei }, { qVolt = hand })
  pruef("RF: Headspeed vor ESC U/min", w.cfg.qRpm == hs, nm(w.cfg.qRpm))
  pruef("RF: PID- und Raten-Profil", w.cfg.qPid == pid and w.cfg.qRate == rate)
  pruef("RF: ESC Temp. vor Temp. 1", w.cfg.qTemp == et, nm(w.cfg.qTemp))
  pruef("RF: ESC Strom über Teilwert 1", w.cfg.qStrom == ei, nm(w.cfg.qStrom))
  pruef("von Hand gesetzte Akkuspannung bleibt", w.cfg.qVolt == hand, nm(w.cfg.qVolt))
  pruef("Akku-Profil nirgends zugewiesen", w.cfg.qBec ~= bat and w.cfg.qProz ~= bat and w.cfg.qMah ~= bat)
  local w3 = lauf({ bat, hs })
  pruef("Akku-Profil nicht als Akkuspannung", w3.cfg.qVolt == nil, nm(w3.cfg.qVolt))
  local w2, n2 = lauf({ esc, t1, hs, pid, rate, bat, et, eu, ei }, w.cfg)
  pruef("zweite Suche ändert nichts", n2 == 0)
end
-- Sensoren ohne Kennung (ELRS/CRSF, berechnete): Namensregeln als Rückfall
do
  local rx = S("RxBt", nil, 0, nil, UNIT_VOLT, 7.9)
  local vb = S("Batt Voltage", nil, 0, nil, UNIT_VOLT, 22)
  local cu = S("Current", nil, 0, nil, UNIT_AMPERE, 10)
  local cap = S("Capacity", nil, 0, nil, UNIT_MILLIAMPERE_HOUR, 400)
  local rs = S("1RSS", nil, 0, nil, UNIT_DB, -60)
  local w = lauf({ rx, vb, cu, cap, rs })
  pruef("ohne Kennung: Akkuspannung, Strom, mAh über Name/Einheit", w.cfg.qVolt == vb and w.cfg.qStrom == cu and w.cfg.qMah == cap,
    nm(w.cfg.qVolt) .. " " .. nm(w.cfg.qStrom) .. " " .. nm(w.cfg.qMah))
end
print("höchste Befehlszahl je Aufruf: " .. MAXBEFEHLE)
pruef("Befehle je Aufruf unter 10 000", MAXBEFEHLE < 10000)
print(fehler == 0 and "ALLE FÄLLE BESTANDEN" or (fehler .. " FEHLER"))
os.exit(fehler == 0 and 0 or 1)
