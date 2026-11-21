-- Heli: Sensoren automatisch zuweisen (nur während der Suche geladen, danach wieder freigegeben).
-- Ablauf nach «Vorgaben Sensorzuordnung» (20.11.2026):
--  0. Von Hand gesetzte (volle) Felder bleiben.
--  1. Kennung: AppID + Teilwert aus kennung.lua -> Schlüssel. Je Feld eine Rangfolge von Schlüsseln; der erste
--     Schlüssel, zu dem es einen Sensor gibt, gewinnt. Der Name zählt hier nicht (gleiche Namen bei verschiedenen Geräten).
--  2. Mehrere Sensoren zum selben Schlüssel (Instanzen 0–F oder gleiche AppID auf mehreren Physical IDs): nicht
--     raten, sondern a) Sensor mit gültigem Wert, b) tiefste Instanz, c) Standard-Physical-ID des Geräts. Hinweis im Menü.
--  3. Nur Sensoren ohne Kennung (Rotorflight-DIY 0x5xxx, berechnete Sensoren, ELRS/CRSF): Namen und Einheit als Rückfall.
-- Rotorflight belegt Standard-IDs teils anders: 0x0900 = Spannung der Steuerplatine (nicht Akku), 0x0910 = Ø-Zelle,
-- 0x0222/0x0229 = BEC-Strom (darum «strom2» nie als Akkustrom), 0x0600 = Akkuladung in %.
-- Aufruf: local schritt = suche(w, kennung, gut); dann je Weckruf schritt() -> fertig, Zahl neu zugewiesener Felder.
-- Verteilt über mehrere Aufrufe (höchstens SCHUB Sensoren je Aufruf): Ethos bricht einen Aufruf mit zu vielen Befehlen
-- ab («Max instructions count reached», X18RS 26.2, 20.11.2026). kennung.lua wird einmal nach Bereich (16 AppIDs)
-- in einen Index umgebaut, je Sensor zählen nur die Einträge seines Bereichs.
-- w.hinweise[feld] = { anzahl, name } bei Mehrdeutigkeit.
local SCHUB = 10
return function(w, KEN, gut)
  local c = w.cfg
  w.hinweise = w.hinweise or {}
  w.hinweise = w.hinweise or {}

  -- Rangfolge der Schlüssel je Feld
  local RANG = {
    qVolt = { "esc_u", "akku_u", "rb35_bat1_u", "bat1_u", "rb_bat1_u", "rb25_bat1_u", "d_akku_u" },
    qStrom = { "esc_i", "strom", "rb35_bat1_i", "bat1_i", "rb_bat1_i", "rb25_i", "d_strom" },
    qZelle = { "zellen", "adc4" },
    qTemp = { "esc_temp", "temp1" },
    qBec = { "bec_u", "rx_batt", "rb35_aus1_u", "rb_aus1_u", "bec2_u", "rx_batt1" },
    qRpm = { "rpm", "esc_rpm" },
    qProz = { "kraftstoff" },
    qMah = { "esc_mah", "rb_bat1_mah" },
    qRssi = { "rssi", "rx_rssi1", "d_rssi" },
  }
  local REIHE = { "qRpm", "qVolt", "qZelle", "qStrom", "qTemp", "qBec", "qProz", "qMah", "qRssi" }
  -- Standard-Physical-ID je Gerät (Tabelle, Ethos-Handbuch 26.2): Vorsilbe des Schlüssels -> ID
  local STDPHYS = { esc_ = 0x0A, bec_ = 0x08, rb35_ = 0x19, rb_ = 0x19, rb25_ = 0x19, zellen = 0x01, strom = 0x02,
    akku_u = 0x02, rpm = 0x04 }

  local function rufe(q, f)
    if type(q[f]) ~= "function" then return nil end
    local okf, v = pcall(q[f], q)
    if okf then return v end
    return nil
  end

  -- Index: Bereich -> Einträge. Bereich = AppID unter 0x0100 und ab 0xF000, sonst AppID ohne Instanz (unterste Stelle).
  local function bereich(id) return (id < 0x0100 or id >= 0xF000) and id or (id - id % 16) end
  local IDX = {}
  for _, e in ipairs(KEN) do
    local b = bereich(e[1])
    local l = IDX[b] or {}
    l[#l + 1] = e
    IDX[b] = l
  end
  KEN = nil
  -- Einheit, die zu einem Schlüssel passt (für Sensoren ohne Teilwert, s. u.)
  local function einheitVon(k)
    if k:find("_mah", 1, true) then return UNIT_MILLIAMPERE_HOUR end
    if k:find("rpm", 1, true) then return UNIT_RPM end
    if k:find("temp", 1, true) then return UNIT_CELSIUS end
    if k:sub(-2) == "_u" then return UNIT_VOLT end
    if k:sub(-2) == "_i" then return UNIT_AMPERE end
    return nil
  end
  -- Kennung aus AppID und Teilwert. Per Lua angelegte Sensoren liefern subId() = nil (Simulator, Befund Elektro
  -- 20.11.2026): bei gepackten AppIDs dann über die Einheit entscheiden (Volt -> Spannung, Ampere -> Strom …).
  local function kennung(id, teil, einheit)
    if type(id) ~= "number" then return nil end
    local erster, treffer = nil, 0
    for _, e in ipairs(IDX[bereich(id)] or {}) do
      if id >= e[1] and id <= e[2] then
        if e[3] == nil or e[3] == teil then
          if teil ~= nil or e[3] == nil then return e[4] end
        end
        if teil == nil then
          treffer = treffer + 1
          erster = erster or e[4]
          if einheit ~= nil and einheitVon(e[4]) == einheit then return e[4] end
        end
      end
    end
    if treffer == 1 then return erster end
    return nil
  end


  local S, nachSchluessel, n = {}, {}, 0
  local function setze(feld, s, anzahl)
    if c[feld] ~= nil or s.vergeben then return false end
    c[feld] = s.q
    s.vergeben = true
    n = n + 1
    if anzahl and anzahl > 1 then w.hinweise[feld] = { anzahl, s.roh or "?" } else w.hinweise[feld] = nil end
    return true
  end
  local function stdPhys(k)
    for v, p in pairs(STDPHYS) do
      if k:sub(1, #v) == v then return p end
    end
    return nil
  end
  -- beste Wahl unter mehreren Sensoren zum selben Schlüssel
  local function besser(a, b, std)
    local ga, gb = a.wert ~= nil, b.wert ~= nil
    if ga ~= gb then return ga end
    local ia, ib = (a.id or 0) % 16, (b.id or 0) % 16
    if ia ~= ib then return ia < ib end
    if std then
      local pa, pb = a.phys == std, b.phys == std
      if pa ~= pb then return pa end
    end
    return a.i < b.i
  end
  -- Akkuladung 0x0600: Betaflight/INAV senden dort verbrauchte mAh. Ein Wert über 100 ist darum kein Prozentwert.
  local function passt(feld, s)
    if s.k == "kraftstoff" and s.wert ~= nil and s.wert > 100 then return false end
    return true
  end

  local function hat(name, ...)
    for _, m in ipairs({ ... }) do
      if name:find(m, 1, true) then return true end
    end
    return false
  end
  -- Rückfall-Regeln (Feld, Bedingung), nur für Sensoren ohne Kennung. Die erste Regel kommt vor der Kennung.
  local REGELN = {
    { "qRpm", function(nm) return hat(nm, "headspeed", "head speed", "hspd") end },
    { "qRpm", function(nm, u)
      return ((UNIT_RPM and u == UNIT_RPM) or hat(nm, "rpm")) and not hat(nm, "tail", "motor", "esc", "erpm")
    end },
    { "qPid", function(nm) return hat(nm, "pid prof", "pid_prof", "pidprof") end },
    { "qRate", function(nm) return hat(nm, "rate prof", "rate_prof", "rateprof", "rates prof") end },
    { "qRssi", function(nm) return hat(nm, "rssi") end },
    { "qBec", function(nm, u)
      return hat(nm, "bec") and not hat(nm, "temp", "tmp", "curr", "strom") and (UNIT_VOLT == nil or u == nil or u == UNIT_VOLT)
    end },
    { "qZelle", function(nm) return hat(nm, "cell", "zelle", "lipo", "flvs") and not hat(nm, "count", "cells") end },
    { "qTemp", function(nm, u) return hat(nm, "esc") and (hat(nm, "temp", "tmp") or (UNIT_CELSIUS and u == UNIT_CELSIUS)) end },
    { "qMah", function(nm, u) return (UNIT_MILLIAMPERE_HOUR and u == UNIT_MILLIAMPERE_HOUR) or hat(nm, "consum", "mah", "verbr") end },
    { "qProz", function(nm, u)
      return hat(nm, "charge", "fuel", "batt%", "bat%") or (UNIT_PERCENT and u == UNIT_PERCENT and hat(nm, "bat", "akku"))
    end },
    { "qStrom", function(nm, u) return ((UNIT_AMPERE and u == UNIT_AMPERE) or hat(nm, "curr", "strom")) and not hat(nm, "bec") end },
    { "qVolt", function(nm) return hat(nm, "vfas", "voltage", "spannung", "vbat", "batt") and not hat(nm, "rx", "adc", "bec", "prof") end },
    -- letzte Rückfälle: irgendeine Drehzahl ausser Heck, irgendeine Temperatur
    { "qRpm", function(nm, u) return ((UNIT_RPM and u == UNIT_RPM) or hat(nm, "rpm")) and not hat(nm, "tail") end },
    { "qTemp", function(_, u) return UNIT_CELSIUS ~= nil and u == UNIT_CELSIUS end },
  }

  local liste, i, phase, r, j = nil, 0, 1, 1, 0
  -- ein Schritt: höchstens SCHUB Sensoren lesen bzw. prüfen
  return function()
    if phase == 1 then                               -- Liste holen
      if not (system.getSources and CATEGORY_TELEMETRY_SENSOR) then return true, 0 end
      local ok, l = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
      if not ok or type(l) ~= "table" then return true, 0 end
      liste, phase = l, 2
      return false, n
    elseif phase == 2 then                           -- Sensoren einlesen
      for _ = 1, SCHUB do
        i = i + 1
        local q = liste[i]
        if q == nil then
          liste, phase = nil, 3
          break
        end
        local name, id = rufe(q, "name"), rufe(q, "appId")
        local s = { q = q, i = i, name = type(name) == "string" and string.lower(name) or "", roh = name, id = id,
          phys = rufe(q, "physId"), einheit = rufe(q, "unit"), wert = gut(rufe(q, "value")) }
        s.k = kennung(id, rufe(q, "subId"), s.einheit)
        for _, f in ipairs(REIHE) do                 -- schon vergeben (von Hand oder früher): nicht ein zweites Mal
          if c[f] ~= nil and c[f] == q then s.vergeben = true end
        end
        S[#S + 1] = s
        if s.k then
          local l = nachSchluessel[s.k] or {}
          l[#l + 1] = s
          nachSchluessel[s.k] = l
        end
      end
      return false, n
    elseif phase == 3 or phase == 5 then             -- Rückfall-Regel r über SCHUB Sensoren
      local regel = REGELN[r]
      if regel == nil then return true, n end
      local feld, f = regel[1], regel[2]
      if c[feld] ~= nil then j = #S end
      for _ = 1, SCHUB do
        j = j + 1
        local s = S[j]
        if s == nil then break end
        if not s.k and not s.vergeben and f(s.name, s.einheit, s) then
          setze(feld, s)
          j = #S
          break
        end
      end
      if j >= #S then
        r, j = r + 1, 0
        if phase == 3 then phase = 4 end            -- nach der ersten Regel (Headspeed) kommt die Kennung
      end
      return false, n
    elseif phase == 4 then                           -- Stufe 1: Kennung (nur Nachschlagen, wenige Befehle)
      for _, feld in ipairs(REIHE) do
        if c[feld] == nil then
          for _, k in ipairs(RANG[feld]) do
            local l = nachSchluessel[k]
            if l then
              local frei, std = {}, stdPhys(k)
              for _, s in ipairs(l) do
                if not s.vergeben and passt(feld, s) then frei[#frei + 1] = s end
              end
              if #frei > 0 then
                local best = frei[1]
                for j = 2, #frei do
                  if besser(frei[j], best, std) then best = frei[j] end
                end
                setze(feld, best, #frei)
                break
              end
            end
          end
        end
      end
      phase = 5
      return false, n
    end
    return true, n
  end
end
