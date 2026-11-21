-- Heli: laufender Betrieb mit Studio-Datei (Lua-Studio-Format v1 und 2). Nur geladen, solange eine Studio-Datei gilt.
-- Das Laden und Prüfen der Datei, .funke.lua und die Info-Datei macht studio.lua; es wird danach freigegeben.
-- Was von dort gebraucht wird (Wert-Tabelle, überwachte Werte, geprüfte Plätze und Grenzen), steht in w.studio.
local L = {}
local floor = math.floor

-- Sensoren und Kanäle der Studio-Datei suchen, in Schritten. Rückgabe true = fertig.
-- Sensoren (1.10.1): nicht über system.getSource mit appId (am Sender X18RS, Ethos 26.2.0, ein Objekt ohne Wert), sondern
-- in der Sensorliste (H.sensorListe: Kategorie als Zahl; die Tabellenform war am Sender leer). Die Liste wird einmal in
-- Stücken zu JE_LISTE Sensoren zu einem Verzeichnis (AppID:Teilwert und AppID:Teilwert:Physical ID) gemacht, dann
-- werden je Aufruf höchstens JE_SUCHE Schlüssel aufgelöst. Ein fehlender Sensor bleibt «---» (kein Scheinwert).
-- Kanäle bleiben über getSource (CATEGORY_CHANNEL, member); H.istQuelle prüft die Kategorie «keine» (Abschnitt 12.6).
local JE_LISTE, JE_SUCHE = 20, 6
local function verzeichnisSchritt(S, H)
  local V = S.verz
  if V == nil then
    S.verz = { l = H.sensorListe(), i = 0, t = {} }
    return false
  end
  local bis = math.min(#V.l, V.i + JE_LISTE)
  for i = V.i + 1, bis do
    local q = V.l[i]
    local function r(f) local okf, v = pcall(q[f], q) if okf then return v end return nil end
    if H.istQuelle(q) then
      local a, sub, ph = r("appId"), r("subId") or 0, r("physId")
      if math.type(a) == "integer" then
        local k = a .. ":" .. sub
        if V.t[k] == nil then V.t[k] = q end
        if ph ~= nil and V.t[k .. ":" .. ph] == nil then V.t[k .. ":" .. ph] = q end
      end
    end
  end
  V.i = bis
  if bis < #V.l then return false end
  V.l, V.fertig = nil, true
  return true
end

function L.quellenSchritt(w, H)
  local S = w.studio
  for _ = 1, JE_SUCHE do
    local o = S.offen[#S.offen]
    if o == nil then break end
    local key, art, a, sub, ph = o[1], o[2], o[3], o[4], o[5]
    local q, eh, dez = nil, nil, nil
    if art == "kanal" and CATEGORY_CHANNEL then
      local ok, r = pcall(system.getSource, { category = CATEGORY_CHANNEL, member = a - 1 })
      if ok and H.istQuelle(r) then
        local okV, v = pcall(r.value, r)                 -- Format 2, Regel 7.3: Kategorie und Wert prüfen
        if okV and v ~= nil then q, eh, dez = r, "%", 0 end
      end
    elseif art == "sensor" then
      if not (S.verz and S.verz.fertig) then verzeichnisSchritt(S, H) return false end
      q = S.verz.t[a .. ":" .. sub .. (ph and (":" .. ph) or "")]
    end
    if q ~= nil and art == "sensor" then
      local okD, d = pcall(q.decimals, q)
      if okD and math.type(d) == "integer" then dez = d end
      local okU, u = pcall(q.unit, q)
      if okU and u ~= nil and system.getUnitName then
        local okN, nm = pcall(system.getUnitName, u)
        if okN and type(nm) == "string" then eh = nm end
      end
    end
    if q == nil then print("Heli: Studio: " .. key .. " nicht gefunden, Platz zeigt ---") end
    local nm = nil                                     -- Standardtitel: Name der Quelle in Ethos (6.3)
    if q ~= nil then
      local okN, n = pcall(q.name, q)
      if okN and type(n) == "string" and n ~= "" then nm = n end
    end
    S.quellen[key] = q and { q = q, eh = eh, dez = dez, kanal = art == "kanal", name = nm } or false
    S.offen[#S.offen] = nil
  end
  if #S.offen > 0 then return false end
  S.verz = nil                                         -- Verzeichnis und Liste freigeben
  return true
end

-- Wert eines Schlüssels: Zahl (angepasst nach «werte»), Einheit, Stellen, Name (Sprache sp: 1 englisch, 2 deutsch)
function L.wert(w, key, art, s, sp)
  local S, v = w.studio, w.v
  local x, eh, dez, name
  if art == "lua" then
    local d = S.WERTE[s]
    local f = d[1]
    if f == "!flugzeit" then x = w.akt and w.akt.dauer or 0
    elseif f == "!fluege" then x = w.fluege or 0
    elseif f == "!scharf" then if v.scharf ~= nil then x = v.scharf and 1 or 0 end
    elseif f == "!leistung" then if v.volt and v.strom then x = v.volt * v.strom end
    else x = v[f] end
    if type(x) ~= "number" then x = nil end
    eh, dez, name = d[2], d[3], d[sp == 2 and 7 or 8]
  elseif art == "sensor" or art == "kanal" then
    local Q = S.quellen[key]
    if Q then
      local ok, r = pcall(Q.q.value, Q.q)
      if ok and type(r) == "number" and r == r and r > -1e9 and r < 1e9 then x = Q.kanal and r / 10.24 or r end
      eh, dez = Q.eh, Q.dez
    end
    name = Q and Q.name or key
  else
    return nil, "", 0, ""
  end
  local a = S.werte[key]
  if a then
    if x then x = x * a.faktor + a.versatz end
    eh, dez, name = a.einheit or eh, a.stellen or dez, a.name or name
  end
  return x, eh or "", dez or 0, name or ""
end

-- Nach einer Änderung im Funken-Menü: Grenzen eines Alarms, dessen Einstellungen sich geändert haben, gelten ab
-- jetzt so, wie sie im Menü stehen.
function L.menueSync(w)
  local c, S = w.cfg, w.studio
  for n, u in pairs(S.UEB) do
    local E, O, G = c[u[2] .. "Ein"], c[u[2] .. "Orange"], c[u[2] .. "Grenze"]
    local b = S.gCfg[n]
    if E ~= b[1] or O ~= b[2] or G ~= b[3] then
      local alt = w.gs[n] or {}
      w.gs[n] = { ein = E == 1, o = O / u[3], g = G / u[3], ans = alt.ans ~= false, vib = alt.vib ~= false }
      S.gCfg[n] = { E, O, G }
    end
  end
end

-- Weitere Grenzen (Sensoren, Kanäle, nicht überwachte Werte): Zustand je Wert wie im Kern (Warnung = nur Farbe,
-- Alarm nach 1 s am Stück).
-- Befehlsgrenze im Betrieb (1.10.1): je Aufruf nur JE_RING Einträge im Ring prüfen (vorher alle: 160 Grenzen über
-- 10 000 Befehle je Aufruf). «Heisse» Einträge (Warnung, Alarm oder Entprellung läuft) prüft es zusätzlich in jedem
-- Aufruf, höchstens JE_HEISS; so gilt die 1 s Entprellung wie bei den Grundwerten. Bis 10 Grenzen wie bisher (alle
-- in jedem Aufruf); bei 160 kommt ein neuer Alarm nach rund 2 s (mehr als 6 aktive Grenzen: über den Ring, gemessen 2,2 s).
local JE_RING, JE_HEISS = 10, 6
local function extraPruefen(w, now)
  local S = w.studio
  local X = S.extra
  local n = #X
  if n == 0 then S.alarmAn = false return end
  local heiss, an = S.heiss or {}, S.an or {}
  S.heiss, S.an = heiss, an
  local runde = (S.runde or 0) + 1
  S.runde = runde
  local tele = w.v.tele ~= false
  local function pruef(x)
    local wert = L.wert(w, x.key, x.art, x.s, 1)
    local e, z = x.e, x.z
    local function jenseits(gr)
      if type(gr) ~= "number" or wert == nil then return false end
      if e.richtung == "unter" then return wert < gr end
      return wert > gr
    end
    local drin = (x.art ~= "sensor" or tele) and jenseits(e.alarm)   -- Kanäle brauchen keine Telemetrie
    if drin then
      z.seit = z.seit or now
      if now - z.seit >= 1 then z.an = true end
    else
      z.seit, z.an = nil, false
    end
    local st = wert ~= nil and ((z.an and 2) or ((drin or jenseits(e.warnung)) and 1) or 0) or nil
    S.st[x.key] = st
    x.runde = runde
    an[x] = z.an or nil
    heiss[x] = (z.seit or (st and st >= 1)) and true or nil
  end
  local start = S.ring or 0
  local anz = math.min(n, JE_RING)
  for j = 1, anz do pruef(X[(start + j - 1) % n + 1]) end
  S.ring = (start + anz) % n
  local zusatz = 0
  for x in pairs(heiss) do                             -- nur vorhandene Schlüssel werden geändert (pairs bleibt gültig)
    if zusatz >= JE_HEISS then break end
    if x.runde ~= runde then
      zusatz = zusatz + 1
      pruef(x)
    end
  end
  S.alarmAn = next(an) ~= nil
end

-- Fälliger Alarm einer weiteren Grenze (alle 10 s wiederholt; der am längsten nicht gemeldete zuerst), sonst nil.
-- Immer mit Ton (kern.lua), auch bei ansage/vibration = false; ganz still nur mit «aus = true» (dann kein Eintrag).
-- motorAus = true: Grenzen mit beiMotorAus = false schweigen, solange der Motorschalter auf aus steht (Format 2 §3.5).
function L.extraFaellig(w, now, motorAus)
  local S = w.studio
  local wahl = nil
  for x in pairs(S.an or {}) do                        -- nur Einträge im Alarm (1.10.1: nicht mehr alle durchgehen)
    local z = x.z
    if z.an and now - z.t >= 10 and (wahl == nil or z.t < wahl.z.t) and not (motorAus and x.e.beiMotorAus == false) then wahl = x end
  end
  if wahl then wahl.z.t = now return { vib = wahl.e.vibration ~= false } end
  return nil
end

-- Laufend (je wakeup): Quellen suchen, weitere Grenzen, Min/Max/Mittel und Kurvenpunkte der sichtbaren Ansicht
function L.wecke(w, now, H)
  local S = w.studio
  if #S.offen > 0 then L.quellenSchritt(w, H) end
  extraPruefen(w, now)
  if S.alarmAn then w.v.warn = true end
  if w.akt ~= S.flug then                               -- neuer Flug: Min/Max/Mittel von vorn
    if w.akt ~= nil then S.zx = {} end
    S.flug = w.akt
  end
  local a = w.fensterJetzt and S.ansichten[w.fensterJetzt]
  if a == nil then return end
  for i, q in ipairs(a.plaetze) do
    if q.zusatz ~= "keine" or q.darst == "kurve" then
      local x = L.wert(w, q.w, q.art, q.s, 1)
      if x and q.zusatz ~= "keine" then
        local z = S.zx[q.w]
        if z == nil then z = { x, x, 0, 0 } S.zx[q.w] = z end
        if x < z[1] then z[1] = x end
        if x > z[2] then z[2] = x end
        z[3], z[4] = z[3] + x, z[4] + 1
      end
      local r = q.r
      if q.darst == "kurve" and r and r.km then        -- Lage der Kurve steht fest (ansicht.lua): Punkte in Pixeln ablegen
        local K = S.kurven[i]
        if K == nil or K.w ~= q.w then K = { w = q.w, y = {}, t = -1e9 } S.kurven[i] = K end
        if now - K.t >= q.kurveS / r.km then           -- r.km Punkte (höchstens 60) über kurveS Sekunden
          K.t = now
          local y = false
          if x then
            local a = (x - r.lo) / (r.hi - r.lo)
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            y = floor(r.ky0 - a * r.kh)
          end
          local Y = K.y
          if #Y >= r.km then table.remove(Y, 1) end
          Y[#Y + 1] = y
        end
      end
    end
  end
end

return L
