-- Heli: Studio-Datei je Modell lesen, prüfen und anwenden (Lua-Studio-Format v1 und 2).
-- Format 2 (1.11.0): Symbole, fette Einheit und Schmuck prüft und zeichnet studio_symbole.lua (Referenz, wörtlich);
-- hier bleiben nur die Original-Tabellen (J.roh) dafür übrig.
-- Wird nur geladen, solange ein Modell geladen wird, .funke.lua oder die Info-Datei geschrieben wird. Den laufenden
-- Betrieb mit Studio-Datei (Werte, Quellen, Kurven, weitere Grenzen) macht das kleinere studiolauf.lua.
-- Alles in Schritten: Der Kern ruft M.schritt(w, H) je wakeup auf, bis es ein Ergebnis gibt (Befehlsgrenze am Sender).
-- Dateien: SCRIPTS:/studio/<Kennung>.heli.lua (schreibt nur das Studio), .funke.lua (schreibt nur dieses Lua),
-- .info.json (schreibt nur dieses Lua, liest nur das Studio).
-- H kommt aus kern.lua: ZAHLEN, ZELLE_WERK, standard(), istQuelle().
local M = {}
local floor = math.floor

M.ORDNER = "SCRIPTS:/studio/"
-- Suchorte der Studio-Datei (Reihenfolge = Vorrang). .funke.lua und Info-Datei bleiben immer in M.ORDNER.
M.ORTE = { "SCRIPTS:/studio/", "SD:/scripts/studio/", "RADIO:/scripts/studio/" }

-- Kennzahl einer gewählten Datei (vollständiger Pfad) für den Widget-Speicher: 1 … 2^24 − 1, 0 = automatisch
function M.kennzahl(pfad)
  local h = 5381
  for i = 1, #pfad do h = (h * 33 + pfad:byte(i)) % 16777213 end
  return h + 1
end

-- Alle *.heli.lua (ohne .funke.lua) der Suchorte; Orte mit gleicher Dateiliste wie SCRIPTS: zählen nur einmal.
-- Nur beim Öffnen des Menüs oder einmal beim Laden aufrufen (nie in jedem wakeup).
function M.dateien()
  local liste, erste = {}, nil
  local endung = "." .. M.LUA .. ".lua"
  for i, ort in ipairs(M.ORTE) do
    local ok, l = pcall(system.listFiles, ort)
    if ok and type(l) == "table" then
      local namen = {}
      for _, e in ipairs(l) do
        local n = type(e) == "table" and e.name or e
        if type(n) == "string" and #n > #endung and n:sub(-#endung) == endung and not n:find("%.funke%.lua$") then
          namen[#namen + 1] = n
        end
      end
      table.sort(namen)
      local schluessel = table.concat(namen, "|")
      if i == 1 then erste = schluessel end
      if i == 1 or schluessel ~= erste or schluessel == "" then
        for _, n in ipairs(namen) do
          liste[#liste + 1] = { pfad = ort .. n, name = n, ort = ort:match("^(%u+):"), z = M.kennzahl(ort .. n) }
        end
      end
    end
  end
  return liste
end
M.LUA = "heli"
M.FORMAT = 2           -- höchstes Format, das diese Version liest (Format 2 seit 1.11.0)
M.FORMATE = { 1, 2 }   -- für die Info-Datei

-- ===== Referenz studioLaden, WÖRTLICH aus «Lua-Studio-Format v1 - Referenz studio_laden.lua» =====
-- Referenz: Studio-Datei sicher laden (Lua-Studio-Format v1, Abschnitt 3). Alle Luas übernehmen das wörtlich.
-- Rückgabe: Tabelle oder nil, Grund ("fehlt" | "kaputt" | "zuNeu").
local MAX_BYTE = 16384
local MAX_ELEMENTE = 1200   -- Kommas + «=» + «{» ausserhalb von Texten (Befehle und Speicher, gemessen)
local MAX_TABELLEN = 240    -- «{» ausserhalb von Texten (Speicher)
local SCHLUESSELWOERTER = { "and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in",
  "local", "nil", "not", "or", "repeat", "then", "until", "while" }

local function studioLaden(pfad, hoechstesFormat)
  local ok, f = pcall(io.open, pfad, "r")
  if not ok or not f then return nil, "fehlt" end
  local teile, n = {}, 0
  while true do
    local ok2, s = pcall(f.read, f, 512)
    if not ok2 then f:close() return nil, "kaputt" end
    if not s or #s == 0 then break end
    n = n + #s
    if n > MAX_BYTE then f:close() return nil, "kaputt" end
    teile[#teile + 1] = s
  end
  f:close()
  local s = table.concat(teile)
  teile = nil
  -- 1. Anfang: nur «return {»
  if not s:find("^%s*return%s*{") then return nil, "kaputt" end
  -- 2. erlaubte Bytes: Buchstaben, Ziffern, Leerraum, _ { } [ ] = , " \ - .
  if s:find('[^%w%s_{}%[%]=,"\\%-%.]') then return nil, "kaputt" end
  -- 2b. nach «\» nur Ziffern (Dezimal-Escapes); sperrt \" \z \x \u{…}, die die Textgrenzen verschieben könnten
  if s:find("\\%D") then return nil, "kaputt" end
  -- 3. verbotene Folgen: Verkettung, Kommentar, lange Texte
  if s:find("..", 1, true) or s:find("--", 1, true) or s:find("[[", 1, true) then return nil, "kaputt" end
  -- 4. Schlüsselwörter ausserhalb von Texten (Texte enthalten nie ein rohes ", das Studio schreibt \34)
  local ohneTexte = s:gsub('"[^"]*"', '""')
  for _, w in ipairs(SCHLUESSELWOERTER) do
    if ohneTexte:find("%f[%w_]" .. w .. "%f[^%w_]") then return nil, "kaputt" end
  end
  -- 4b. «-» nur als Vorzeichen direkt vor einer Ziffer, nach = , { [ (keine Rechenketten)
  if ohneTexte:find("%-%s*%D") or ohneTexte:find("[^=,{%[%s]%s*%-") then return nil, "kaputt" end
  local _, anzahlReturn = ohneTexte:gsub("%f[%w_]return%f[^%w_]", "")
  if anzahlReturn ~= 1 then return nil, "kaputt" end
  -- 4b2. kein Name und keine Zahl länger als 24 Zeichen (Speicher: lange Schlüssel)
  if ohneTexte:find(string.rep("[%w_]", 25)) then return nil, "kaputt" end
  -- 4c. reine Daten: Namen nur als Schlüssel direkt vor «=», sonst nur true/false (kein _ENV, keine Variablen, keine Aufrufe)
  if ohneTexte:find("==", 1, true) then return nil, "kaputt" end
  local rest = ohneTexte:gsub("^%s*return", "")
  rest = rest:gsub("[%a_][%w_]*%s*=", "=")
  rest = rest:gsub("%f[%w_]true%f[^%w_]", "")
  rest = rest:gsub("%f[%w_]false%f[^%w_]", "")
  local nameGefunden = rest:find("[%a_]")
  rest = nil
  if nameGefunden then return nil, "kaputt" end
  -- 4d. nach «[» nur ein Text, eine Zahl oder ein Vorzeichen (keine Ausdrücke als Schlüssel)
  if ohneTexte:find('%[%s*[^%d"%-]') then return nil, "kaputt" end
  -- 5. Grösse der Tabelle begrenzen (Befehlsgrenze beim Aufbau)
  local _, kommas = ohneTexte:gsub(",", "")
  local _, gleich = ohneTexte:gsub("=", "")
  local _, klammern = ohneTexte:gsub("{", "")
  if klammern > MAX_TABELLEN or kommas + gleich + klammern > MAX_ELEMENTE then return nil, "kaputt" end
  -- 6. laden ohne Umgebung, nur Text
  -- Zwischentexte der Prüfung freigeben, bevor übersetzt wird (Speicher-Spitze)
  ohneTexte = nil
  collectgarbage("collect")
  local ok3, chunk = pcall(load, s, "=studio", "t", {})
  s = nil
  collectgarbage("collect")
  if not ok3 or type(chunk) ~= "function" then return nil, "kaputt" end
  local ok4, d = pcall(chunk)
  if not ok4 or type(d) ~= "table" or math.type(d.format) ~= "integer" or d.format < 1 then return nil, "kaputt" end
  if d.format > hoechstesFormat then return nil, "zuNeu" end
  return d
end
-- ===== Ende Referenz =====
M.studioLaden = studioLaden

-- Werte dieses Luas (wie studio/beschreibung.json): Feld in w.v (oder Sonderfall mit «!»), Einheit, Stellen, min, max,
-- Grenzrichtung (nur überwachte Werte), Name de/en; u = Name des Alarms in kern.lua (ALARME), status = Text-Zustand,
-- zeit = Dauer in Sekunden.
M.WERTE = {
  akku_proz = { "proz", "%", 0, 0, 100, "unter", "Akku %", "Battery %", u = "proz" },
  zelle = { "zelle", "V", 2, 3.3, 4.2, "unter", "Zelle", "Cell", u = "zelle" },
  bec = { "bec", "V", 1, 4, 8.4, "unter", "BEC", "BEC", u = "bec" },
  reglertemp = { "temp", "°C", 0, 0, 100, "ueber", "Reglertemp.", "ESC temp.", u = "temp" },
  verbraucht = { "mah", "mAh", 0, 0, 5000, "ueber", "Verbraucht", "Used", u = "mah" },
  drehzahl = { "rpm", "U/min", 0, 0, 2400, nil, "Drehzahl", "Head speed" },
  strom = { "strom", "A", 0, 0, 250, nil, "Strom", "Current" },
  spannung = { "volt", "V", 1, 0, 60, nil, "Akkuspannung", "Battery voltage" },
  leistung = { "!leistung", "W", 0, 0, 5000, nil, "Leistung", "Power" },
  rssi = { "rssi", "dB", 0, 0, 100, nil, "Empfang", "Signal" },
  gas_proz = { "gas", "%", 0, -100, 100, nil, "Gas %", "Throttle %" },
  pid_profil = { "pid", "", 0, 1, 6, nil, "PID-Profil", "PID profile" },
  rate_profil = { "rate", "", 0, 1, 6, nil, "Raten-Profil", "Rate profile" },
  flugzeit = { "!flugzeit", "s", 0, 0, 600, nil, "Flugzeit", "Flight time", zeit = true },
  fluege = { "!fluege", "", 0, 0, 100, nil, "Flüge", "Flights" },
  governor = { "gov", "", 0, 0, 9, nil, "Governor", "Governor", status = true },
  scharf = { "!scharf", "", 0, 0, 1, nil, "Scharf", "Armed", status = true },
}
-- überwachte Werte: Alarm in kern.lua -> Studio-Wert, Vorsilbe der Einstellungen (…Ein/…Orange/…Grenze), Teiler
M.UEBERWACHT = { temp = { "reglertemp", "warn", 1 }, proz = { "akku_proz", "aProz", 1 },
  zelle = { "zelle", "aZelle", 100 }, bec = { "bec", "aBec", 10 }, mah = { "verbraucht", "aMah", 1 } }

-- Einstellungen, die das Studio setzen darf (Name im Widget), Art und bei «w» die erlaubten Werte. Keine
-- Grenzwert-Felder (…Ein, …Orange, …Grenze: die stehen in «grenzen»), keine Sensoren. Studio-Name = snake_case.
M.EINST = {
  { "zellen", "z" }, { "kapaz", "z" }, { "akkutyp", "w", { 1, 2, 3 } },
  { "rpmMax", "z" }, { "aMax", "z" }, { "tMax", "z" },
  { "warnTakt", "z" }, { "aProzTakt", "z" }, { "aZelleTakt", "z" }, { "aBecTakt", "z" }, { "aMahTakt", "z" },
  { "rpmEin", "b" }, { "gasGrenze", "z" }, { "rpmTakt", "z" }, { "rpmMin", "z" },
  { "sprache", "w", { 0, 1, 2 } }, { "flugRpm", "z" }, { "flugSek", "z" }, { "swAus", "w", { 1, 2, 3 } },
  { "autoSek", "z" },
}

-- Darstellungsarten und Mindestgrösse (Bezug 800 Pixel breit), Abschnitt 7
M.DARST = { zahl = { 90, 50 }, ring = { 110, 110 }, balken_w = { 140, 40 }, balken_s = { 50, 110 },
  kurve = { 180, 90 }, status = { 120, 40 } }

-- Name im Widget (rpmMax) <-> Studio-Name (rpm_max)
local function studioName(k) return (k:gsub("(%u)", function(c) return "_" .. c:lower() end)) end
M.studioName = studioName

-- Modellkennung (Abschnitt 2.1), byteweise
function M.kennung()
  local ok, n = pcall(model.name)
  local k = ((ok and type(n) == "string") and n or ""):gsub("[^%w]", "_"):sub(1, 32)
  if k == "" then k = "modell" end
  return k
end

local function endlich(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function ganz(v) return math.type(v) == "integer" end
local function kuerze(t, n)
  if type(t) ~= "string" then return nil end
  if #t <= n then return t end
  local e = n
  while e > 0 do
    local b = t:byte(e + 1)
    if b == nil or b < 0x80 or b > 0xBF then break end   -- nur vor einem Byte kürzen, das ein Zeichen beginnt
    e = e - 1
  end
  return t:sub(1, e)
end
M.kuerze = kuerze
local function farbe(f)
  if type(f) ~= "table" or #f ~= 3 then return nil end
  for i = 1, 3 do
    if not ganz(f[i]) or f[i] < 0 or f[i] > 255 then return nil end
  end
  return { f[1], f[2], f[3] }
end

-- Zeile aus ZAHLEN (kern.lua) zu einem Namen (Verzeichnis einmal aufbauen: Befehlsgrenze)
local ZI = nil
local function zeile(H, name)
  if ZI == nil then
    ZI = {}
    for _, z in ipairs(H.ZAHLEN) do ZI[z[1]] = z end
  end
  return ZI[name]
end

-- Wert-Schlüssel nach 6.6. Rückgabe: Art ("lua", "sensor", "kanal", "leer") und Teile, sonst nil.
function M.schluessel(k)
  if type(k) ~= "string" then return nil end
  if k == "leer" then return "leer" end
  local s = k:match("^lua:([%w_]+)$")
  if s then return M.WERTE[s] and "lua" or nil, s end
  local a, sub, ph = k:match("^sensor:(%x%x%x%x):(%d+):?(%d*)$")
  if a and not a:find("%l") and #sub <= 3 and #ph <= 2 then
    local p = ph ~= "" and tonumber(ph) or nil
    if p and p > 27 then return nil end
    return "sensor", tonumber(a, 16), tonumber(sub), p
  end
  local n = k:match("^kanal:(%d+)$")
  if n and #n <= 2 and tonumber(n) >= 1 and tonumber(n) <= 64 then return "kanal", tonumber(n) end
  return nil
end

-- ===== Prüfen (Abschnitt 6). Jede Prüfung zählt Fehler und schreibt je Fehler eine Zeile ins Log. =====
local function fehler(J, wo, warum)
  J.fehler = J.fehler + 1
  print("Heli: Studio-Datei " .. J.datei .. ": " .. wo .. ": " .. warum)
end

-- Einstellungen: nur die aus M.EINST; unbekannte Schlüssel ohne Hinweis überlesen. Ein Eintrag je Aufruf von
-- einstEintrag (in Stücken über teile, Format 2 Regel 7.1); Verzeichnis Studio-Name -> Zeile von M.EINST einmal.
local EI = nil
local function einstEintrag(J, H, s, v, ziel)
  if EI == nil then
    EI = {}
    for _, e in ipairs(M.EINST) do EI[studioName(e[1])] = e end
  end
  local e = type(s) == "string" and EI[s] or nil
  if e == nil or v == nil then return end
  local gut = false
  if e[2] == "z" then
    local z = zeile(H, e[1])
    gut = ganz(v) and z ~= nil and v >= z[3] and v <= z[4]
  elseif e[2] == "b" then
    gut = type(v) == "boolean"
    if gut then v = v and 1 or 0 end
  elseif ganz(v) then
    for _, a in ipairs(e[3]) do if a == v then gut = true end end
  end
  if gut then ziel[e[1]] = v
  else fehler(J, "einstellungen." .. s, "ungültig, Werkwert") end
end

-- Befehlsgrenze (Format 12.2, 1.10.1): Werte und Grenzen werden in Stücken zu JE_EINTRAG Einträgen geprüft, sonst
-- brauchten z. B. 160 Grenzen über 24 000 Befehle in einem Aufruf. Rückgabe true = fertig. Stand in J.teilK (letzter
-- Schlüssel), next statt pairs.
-- Format 2 (1.11.0), Regel 7.1: höchstens 8 Einträge je Aufruf (Prüfen, Zusammenführen); Regel 7.2: werte, grenzen
-- und einstellungen höchstens 48 Einträge, ab dem 49. (Reihenfolge von next) verworfen plus Hinweis.
local JE_EINTRAG = 8
local MAX_LISTE = 48
local function teile(J, quelle, wo, f)
  if quelle == nil then return true end
  if type(quelle) ~= "table" then fehler(J, wo, "keine Tabelle") return true end
  local k, e
  if J.teilK == nil then k, e = next(quelle) else k, e = next(quelle, J.teilK) end
  local n = 0
  while k ~= nil do
    f(k, e)
    n = n + 1
    if n >= JE_EINTRAG then J.teilK = k return false end
    k, e = next(quelle, k)
  end
  J.teilK = nil
  return true
end

local function werteEintrag(J, k, e, ziel)
  do
    local art, s = M.schluessel(k)
    if not art or art == "leer" or type(e) ~= "table" then
      fehler(J, "werte." .. tostring(k), "Eintrag verworfen")
    else
      local a = { faktor = 1, versatz = 0 }
      if art == "lua" and M.WERTE[s].u and type(e.faktor) == "number" and e.faktor < 0 then
        -- überwachter Wert mit negativem Faktor: die Alarmrichtung würde sich drehen, darum Faktor 1 (Standard)
        fehler(J, "werte." .. k .. ".faktor", "negativ bei überwachtem Wert, Faktor 1")
      elseif e.faktor ~= nil then
        if endlich(e.faktor) and math.abs(e.faktor) >= 0.0001 and math.abs(e.faktor) <= 10000 then a.faktor = e.faktor
        else fehler(J, "werte." .. k .. ".faktor", "ungültig, 1") end
      end
      if e.versatz ~= nil then
        if endlich(e.versatz) and e.versatz >= -100000 and e.versatz <= 100000 then a.versatz = e.versatz
        else fehler(J, "werte." .. k .. ".versatz", "ungültig, 0") end
      end
      if e.einheit ~= nil then
        if type(e.einheit) == "string" then a.einheit = kuerze(e.einheit, 8) else fehler(J, "werte." .. k .. ".einheit", "kein Text") end
      end
      if e.stellen ~= nil then
        if ganz(e.stellen) and e.stellen >= 0 and e.stellen <= 3 then a.stellen = e.stellen
        else fehler(J, "werte." .. k .. ".stellen", "ungültig") end
      end
      if e.name ~= nil then
        if type(e.name) == "string" then a.name = kuerze(e.name, 24) else fehler(J, "werte." .. k .. ".name", "kein Text") end
      end
      ziel[k] = a
    end
  end
end

-- Grenzen: nur Felder sammeln; Richtung und Reihenfolge prüft M.grenzenFertig nach dem Zusammenführen
local function grenzeEintrag(J, k, e, ziel)
  do
    local art = M.schluessel(k)
    if not art or art == "leer" or type(e) ~= "table" then
      fehler(J, "grenzen." .. tostring(k), "Eintrag verworfen")
    else
      local z = ziel[k] or {}
      if e.richtung ~= nil then
        if e.richtung == "unter" or e.richtung == "ueber" then z.richtung = e.richtung
        else z.richtungFalsch = true end
      end
      for _, n in ipairs({ "warnung", "alarm" }) do      -- false = diese Stufe aus (Format 6.5)
        if e[n] ~= nil then
          if e[n] == false or endlich(e[n]) then z[n] = e[n]
          else
            fehler(J, "grenzen." .. k .. "." .. n, "ungültig, Werkgrenze dieser Stufe")
            z[n] = "werk"                               -- überwachter Wert: Werkgrenze; sonst gilt die Stufe als nicht vorhanden
          end
        end
      end
      for _, n in ipairs({ "ansage", "vibration", "aus", "beiMotorAus" }) do   -- beiMotorAus: Format 2 §3.5 (21.11.2026)
        if e[n] ~= nil then
          if type(e[n]) == "boolean" then z[n] = e[n] else fehler(J, "grenzen." .. k .. "." .. n, "kein true/false") end
        end
      end
      ziel[k] = z
    end
  end
end

-- Nach dem Zusammenführen: Richtung und Reihenfolge prüfen. Ergebnis je Schlüssel:
-- { richtung, warnung (oder nil = aus, "werk"), alarm, ansage, vibration, beiMotorAus } bzw. { werk = true } oder { aus = true }
-- beiMotorAus fehlt oder ungültig: true (Alarm kommt auch bei Motorschalter aus, die sichere Richtung)
local function grenzeFertig(J, k, z, still, r)
  local function f(wo, warum) if not still then fehler(J, wo, warum) end end
  do
    local art, s = M.schluessel(k)
    local def = art == "lua" and M.WERTE[s][6] or nil
    local ueberwacht = def ~= nil and M.WERTE[s].u ~= nil
    local richtung = z.richtung or def
    local e = { ansage = z.ansage ~= false, vibration = z.vibration ~= false, beiMotorAus = z.beiMotorAus ~= false }
    if ueberwacht and (z.richtungFalsch or richtung ~= def) then
      -- überwachter Heli-Wert mit falscher oder abweichender Richtung: Werkgrenze bleibt (Alarm-Sicherheit)
      f("grenzen." .. k .. ".richtung", "passt nicht zum Wert, Werkgrenze gilt")
      e.werk, e.beiMotorAus = true, true                  -- ganz Werk, auch der Haken (sonst schriebe funkeAusCfg immer)
    elseif z.richtungFalsch or richtung == nil or (def and richtung ~= def) then
      f("grenzen." .. k .. ".richtung", "fehlt oder ungültig, Grenze aus")
      e.aus = true
    elseif z.aus then
      e.aus = true
    elseif ueberwacht and not z.warnung and not z.alarm then
      -- Eintrag ohne Stufen (z. B. nur beiMotorAus = false oder ansage = false) oder beide Stufen false: Werkgrenze, nur
      -- die Haken gelten. Ganz still wird ein Alarm nur mit aus = true (Entscheid des Users 20.11.2026).
      -- Vorher war der Alarm dann ganz aus (Prüfung 1.12.0).
      e.werk, e.ohneStufen = true, true
    else
      e.richtung = richtung
      e.warnung = z.warnung or nil
      e.alarm = z.alarm or nil
      if e.warnung == "werk" and not ueberwacht then e.warnung = nil end
      if e.alarm == "werk" and not ueberwacht then e.alarm = nil end
      if type(e.warnung) == "number" and type(e.alarm) == "number" and ((richtung == "unter" and not (e.alarm < e.warnung))
        or (richtung == "ueber" and not (e.alarm > e.warnung))) then
        f("grenzen." .. k, "Alarm und Warnung vertauscht, nur Alarm gilt")
        e.warnung = nil
      end
    end
    r[k] = e
  end
end
function M.grenzenFertig(J, roh, still)
  local r = {}
  for k, z in pairs(roh) do grenzeFertig(J, k, z, still, r) end
  return r
end

local function pruefePlatz(J, wo, p, br, ho, kurven)
  if type(p) ~= "table" then fehler(J, wo, "kein Platz, verworfen") return nil end
  for _, n in ipairs({ "x", "y", "b", "h" }) do
    if not ganz(p[n]) then fehler(J, wo .. "." .. n, "fehlt oder keine ganze Zahl, Platz verworfen") return nil end
  end
  local darst = p.darstellung
  if darst ~= nil and not M.DARST[darst] then fehler(J, wo .. ".darstellung", "unbekannt, zahl") darst = nil end
  darst = darst or "zahl"
  local art, s = M.schluessel(p.w)
  if not art then fehler(J, wo .. ".w", "unbekannter Wert, Platz verworfen") return nil end
  local status = art == "lua" and M.WERTE[s].status
  if darst == "status" and not status then fehler(J, wo .. ".darstellung", "status passt nicht, zahl") darst = "zahl" end
  if darst ~= "status" and status then darst = "status" end
  if darst == "kurve" and kurven[1] >= 2 then fehler(J, wo, "mehr als 2 Kurven, zahl") darst = "zahl" end
  -- Mindestgrösse (Abschnitt 7): Tabellenwert × breite / 800, gerundet; Bezug immer 800
  local mb = floor(M.DARST[darst][1] * br / 800 + 0.5)
  local mh = floor(M.DARST[darst][2] * br / 800 + 0.5)
  if p.x < 0 or p.y < 0 or p.x + p.b > br or p.y + p.h > ho or p.b < mb or p.h < mh then
    fehler(J, wo, "Lage oder Grösse ungültig, Platz verworfen")
    return nil
  end
  if darst == "kurve" then kurven[1] = kurven[1] + 1 end
  local q = { x = p.x, y = p.y, b = p.b, h = p.h, w = p.w, art = art, s = s, darst = darst, zusatz = "keine", kurveS = 120,
    roh = (J.d and J.d.format == 2) and p or nil }     -- Original-Platz für studio_symbole.lua (nur Format 2)
  if p.titel ~= nil then
    if type(p.titel) == "string" then q.titel = kuerze(p.titel, 24) else fehler(J, wo .. ".titel", "kein Text") end
  end
  if p.min ~= nil or p.max ~= nil then
    if endlich(p.min) and endlich(p.max) and p.max > p.min then q.min, q.max = p.min, p.max
    else fehler(J, wo .. ".min/max", "ungültig, Standard") end
  end
  for _, n in ipairs({ "farbe", "farbeWarn", "farbeAlarm", "hintergrund" }) do
    if p[n] ~= nil then
      q[n] = farbe(p[n])
      if not q[n] then fehler(J, wo .. "." .. n, "ungültig, Standard") end
    end
  end
  if p.zusatz ~= nil then
    if p.zusatz == "keine" or p.zusatz == "min" or p.zusatz == "max" or p.zusatz == "mittel" then q.zusatz = p.zusatz
    else fehler(J, wo .. ".zusatz", "ungültig, keine") end
  end
  if p.kurveS ~= nil then
    if ganz(p.kurveS) and p.kurveS >= 30 and p.kurveS <= 600 then q.kurveS = p.kurveS
    else fehler(J, wo .. ".kurveS", "ungültig, 120") end
  end
  if p.stufen ~= nil then
    local ok = type(p.stufen) == "table" and #p.stufen <= 3
    local st = {}
    if ok then
      for i, e in ipairs(p.stufen) do
        local fb = type(e) == "table" and farbe(e.farbe)
        if not (fb and endlich(e.ab) and (i == 1 or e.ab > st[i - 1].ab)) then ok = false break end
        st[i] = { ab = e.ab, farbe = fb }
      end
    end
    if ok then q.stufen = st else fehler(J, wo .. ".stufen", "ungültig, Liste verworfen") end
  end
  return q
end

-- Eine Ansicht in Teilen prüfen: je Aufruf höchstens JE_AUFRUF Plätze. Rückgabe: true = fertig.
local JE_AUFRUF = 4
local function pruefeAnsicht(J, i, a)
  local wo = "ansichten[" .. i .. "]"
  local A = J.ansicht
  if A == nil then
    if type(a) ~= "table" or not ganz(a.breite) or not ganz(a.hoehe) or a.breite < 100 or a.breite > 1024
      or a.hoehe < 100 or a.hoehe > 1024 or type(a.plaetze) ~= "table" then
      fehler(J, wo, "Ansicht verworfen")
      return true
    end
    A = { r = { breite = a.breite, hoehe = a.hoehe, plaetze = {}, roh = (J.d and J.d.format == 2) and a or nil },
      kurven = { 0 }, k = 0 }
    J.ansicht = A
  end
  local bis = math.min(#a.plaetze, 16, A.k + JE_AUFRUF)
  for k = A.k + 1, bis do
    local q = pruefePlatz(J, wo .. ".plaetze[" .. k .. "]", a.plaetze[k], a.breite, a.hoehe, A.kurven)
    if q then A.r.plaetze[#A.r.plaetze + 1] = q end
  end
  A.k = bis
  if A.k < math.min(#a.plaetze, 16) then return false end
  if #a.plaetze > 16 then fehler(J, wo, "mehr als 16 Plätze, Rest verworfen") end
  local key = A.r.breite .. "x" .. A.r.hoehe
  J.ansichten[key] = J.ansichten[key] or A.r
  J.ansicht = nil
  return true
end

-- Werkgrenze eines überwachten Werts als Eintrag in angezeigter Einheit (für das Zusammenführen, Format 6.5).
-- Ein Alarm, der ab Werk aus ist (BEC, Verbrauch), ergibt «aus = true» mit den Werk-Schwellen.
function M.werkGrenze(key, H, akkutyp)
  local art, s = M.schluessel(key)
  if art ~= "lua" or not M.WERTE[s].u then return nil end
  local u = M.UEBERWACHT[M.WERTE[s].u]
  local werk = H.standard()
  local wO, wG = werk[u[2] .. "Orange"], werk[u[2] .. "Grenze"]
  if u[2] == "aZelle" then
    local z = H.ZELLE_WERK[akkutyp or 1] or H.ZELLE_WERK[1]
    wO, wG = z[1], z[2]
  end
  return { richtung = M.WERTE[s][6], warnung = wO / u[3], alarm = wG / u[3], aus = werk[u[2] .. "Ein"] ~= 1 or nil }
end

-- ===== Ablauf beim Modellwechsel, ein Schritt je Aufruf =====
-- Rückgabe: nil = läuft noch, sonst das Ergebnis { zustand = "fehlt"|"geladen"|"kaputt"|"zuNeu", ... }
function M.schritt(w, H)
  local J = w.studioJob
  if J == nil then
    J = { stufe = 1, fehler = 0, k = M.kennung(), ort = 0, wahl = "auto" }
    J.basis = M.ORDNER .. J.k .. "." .. M.LUA             -- .funke.lua immer hier
    J.datei = J.k .. "." .. M.LUA .. ".lua"
    w.studioJob = J
    return nil
  end
  if J.stufe == 1 and J.ort == 0 then                    -- 1. ausdrückliche Wahl im Menü (gewinnt)
    J.ort = 1
    local z = w.cfg and w.cfg.studio or 0
    if z ~= 0 then
      for _, e in ipairs(M.dateien()) do
        if e.z == z then J.gewaehlt = e break end
      end
      if J.gewaehlt then
        J.wahl, J.quelle, J.datei = "menue", J.gewaehlt.pfad, J.gewaehlt.name
        local d, grund = studioLaden(J.quelle, M.FORMAT)
        if d then J.d, J.stufe = d, 2 return nil end
        J.zustand = grund
        print("Heli: Studio-Datei " .. J.quelle .. ": " .. tostring(grund))
        w.studioJob = nil
        return J
      end
      print("Heli: gewählte Studio-Datei nicht gefunden, automatisch")
    end
    return nil
  end
  if J.stufe == 1 and J.ort <= #M.ORTE then             -- 2. <Kennung>.heli.lua, je Aufruf ein Ort
    local pfad = M.ORTE[J.ort] .. J.k .. "." .. M.LUA .. ".lua"
    J.ort = J.ort + 1
    local d, grund = studioLaden(pfad, M.FORMAT)
    if grund == "fehlt" then return nil end
    J.quelle = pfad
    if not d then
      J.zustand = grund
      print("Heli: Studio-Datei " .. pfad .. ": " .. tostring(grund))
      w.studioJob = nil
      return J
    end
    J.d, J.stufe = d, 2
    return nil
  end
  if J.stufe == 1 then                                   -- nirgends gefunden
    local d, grund = nil, "fehlt"
    if true then                   -- Übergang 1.13.0: alte Studio-Datei von «Heli RF» (helirf)
      local alt, gAlt = studioLaden(M.ORDNER .. J.k .. ".helirf.lua", M.FORMAT)
      if gAlt ~= "fehlt" then
        J.quelle = M.ORDNER .. J.k .. ".helirf.lua"
        print("Heli: old studio file found (" .. J.k .. ".helirf.lua), please re-transfer with Lua-Studio")
        d, grund = alt, gAlt
      end
    end
    if not d then
      J.zustand = grund
      if grund ~= "fehlt" then print("Heli: Studio-Datei " .. J.datei .. ": " .. grund) end
      w.studioJob = nil
      return J
    end
    J.d, J.stufe = d, 2
    return nil
  elseif J.stufe == 2 then                               -- .funke.lua laden, übrig gebliebene .funke.neu
    local fu, grund = studioLaden(J.basis .. ".funke.lua", M.FORMAT)
    -- übrig gebliebene .funke.neu (Strom weg beim Schreiben): nur ohne .funke.lua übernehmen, sonst löschen
    local okO, nf = pcall(io.open, J.basis .. ".funke.neu", "r")
    if okO and nf then
      nf:close()
      local neu = grund == "fehlt" and studioLaden(J.basis .. ".funke.neu", M.FORMAT)
      local okR, r = false, nil
      if neu then okR, r = pcall(os.rename, J.basis .. ".funke.neu", J.basis .. ".funke.lua") end
      if neu and okR and r then fu, grund = neu, nil
      else pcall(os.remove, J.basis .. ".funke.neu") end
    end
    if fu == nil and grund ~= "fehlt" and grund ~= nil then
      J.funkeVerworfen = true
      print("Heli: Studio-Datei " .. J.k .. "." .. M.LUA .. ".funke.lua: " .. tostring(grund) .. ", verworfen")
    end
    J.fu, J.stufe = fu, 3
    return nil
  elseif J.stufe == 3 then                               -- Einstellungen, Werte, Grenzen: Aufgaben anlegen
    local d = J.d
    J.einst, J.werte, J.grenzenRoh, J.funkeEinst, J.funkeGrenzen = {}, {}, {}, {}, {}
    local function einst(J2, k, e, ziel) einstEintrag(J2, H, k, e, ziel) end
    J.aufg = { { d.einstellungen, "einstellungen", J.einst, einst }, { d.werte, "werte", J.werte, werteEintrag },
      { d.grenzen, "grenzen", J.grenzenRoh, grenzeEintrag } }
    if J.fu then
      J.aufg[4] = { J.fu.einstellungen, "einstellungen", J.funkeEinst, einst, true }
      J.aufg[5] = { J.fu.grenzen, "grenzen", J.funkeGrenzen, grenzeEintrag, true }
    end
    J.ai3, J.teilK = 1, nil
    J.stufe = 31
    return nil
  elseif J.stufe == 31 then                              -- in Stücken zu höchstens 8 (Format 2, Regel 7.1)
    local a = J.aufg[J.ai3]
    if a == nil then
      J.aufg, J.ai3 = nil, nil
      J.stufe, J.ai, J.ansichten = 4, 0, {}
      return nil
    end
    local datei = J.datei
    if a[5] then J.datei = J.k .. "." .. M.LUA .. ".funke.lua" end
    local ziel, f = a[3], a[4]
    a.n = a.n or 0
    local fertig = teile(J, a[1], a[2], function(k, e)
      a.n = a.n + 1
      if a.n <= MAX_LISTE then f(J, k, e, ziel) end      -- Regel 7.2: ab dem 49. Eintrag verworfen
    end)
    if fertig and a.n > MAX_LISTE then fehler(J, a[2], (a.n - MAX_LISTE) .. " Einträge über " .. MAX_LISTE .. " verworfen") end
    if fertig then J.ai3 = J.ai3 + 1 end
    J.datei = datei
    return nil
  elseif J.stufe == 4 then                               -- je Aufruf eine Ansicht (bzw. 6 Plätze)
    local liste = J.d.ansichten
    if liste ~= nil and type(liste) ~= "table" then
      if not J.ansListeFehler then fehler(J, "ansichten", "keine Liste") J.ansListeFehler = true end
      liste = nil
    end
    if J.ansicht == nil then J.ai = J.ai + 1 end
    local a = liste and liste[J.ai]
    if a ~= nil and J.ai <= 2 then
      pruefeAnsicht(J, J.ai, a)
      return nil
    end
    if liste and #liste > 2 then fehler(J, "ansichten", "mehr als 2, Rest verworfen") end
    J.stufe = 5
    return nil
  end
  if J.stufe == 7 then                                   -- eigener Aufruf: der Kern wendet das Ergebnis jetzt an
    w.studioJob = nil
    return J
  end
  if J.stufe == 6 then                                   -- weitere Grenzen und zu suchende Quellen sammeln, in Stücken
    local t = J.s6 or 1
    if t == 1 then
      J.extra, J.offen, J.schl, J.s6, J.teilK = {}, {}, {}, 2, nil
      for _, a in pairs(J.ansichten) do                    -- höchstens 2 × 16 Plätze
        for _, q in ipairs(a.plaetze) do
          if q.art == "sensor" or q.art == "kanal" then J.schl[q.w] = true end
        end
      end
      return nil
    elseif t == 2 then
      if teile(J, J.grenzen, "grenzen", function(key, e)
        local art, s = M.schluessel(key)
        if not (art == "lua" and M.WERTE[s].u) and not e.aus and not e.werk and (e.warnung or e.alarm) then
          J.extra[#J.extra + 1] = { key = key, art = art, s = s, e = e, z = { an = false, t = -1000 } }
          if art == "sensor" or art == "kanal" then J.schl[key] = true end
        end
      end) then J.s6 = 3 end
      return nil
    end
    if not teile(J, J.schl, "quellen", function(key)    -- Schlüssel schon zerlegt
      local art, a, sub, ph = M.schluessel(key)
      J.offen[#J.offen + 1] = { key, art, a, sub, ph }
    end) then return nil end
    J.schl, J.s6, J.stufe = nil, nil, 7
    return nil
  end
  -- Stufe 5: zusammenführen (Studio, darüber .funke.lua je Feld), in Stücken (Befehlsgrenze)
  local t = J.s5 or 1
  if t == 1 then                                         -- Einstellungen: Studio-Stand merken (Stücke zu 8)
    J.einstStudio = J.einstStudio or {}
    if teile(J, J.einst, "einstellungen", function(k, v) J.einstStudio[k] = v end) then J.s5 = 11 end
    return nil
  elseif t == 11 then                                    -- .funke.lua darüber (Stücke zu 8)
    if teile(J, J.funkeEinst, "einstellungen", function(k, v) J.einst[k] = v end) then
      J.grenzenStudio, J.grenzen, J.s5, J.teilK = {}, {}, 2, nil
    end
    return nil
  elseif t == 2 then                                     -- Studio-Stand nur gemerkt, Fehler zählt Teil 4
    local r = J.grenzenStudio
    if teile(J, J.grenzenRoh, "grenzen", function(k, z) grenzeFertig(J, k, z, true, r) end) then J.s5 = 3 end
    return nil
  elseif t == 3 then                                     -- .funke.lua je Feld darüber
    local typ = J.einst.akkutyp or 1
    if teile(J, J.funkeGrenzen, "grenzen", function(k, z)
      local g = J.grenzenRoh[k] or M.werkGrenze(k, H, typ) or {}
      for n, x in pairs(z) do g[n] = x end
      J.grenzenRoh[k] = g
    end) then J.s5 = 4 end
    return nil
  end
  local r = J.grenzen
  if not teile(J, J.grenzenRoh, "grenzen", function(k, z) grenzeFertig(J, k, z, false, r) end) then return nil end
  J.zustand = "geladen"
  -- Format 2: studio_symbole.lua (Referenz) braucht die Original-Tabellen (symbole, ansichten mit Plätzen und deko).
  -- Nur diese bleiben, werte/grenzen/einstellungen der Datei werden frei.
  local d = J.d
  if d.format == 2 then J.roh = { format = 2, symbole = d.symbole, ansichten = d.ansichten } end
  J.d, J.fu, J.grenzenRoh, J.s5, J.stufe = nil, nil, nil, nil, 6
  return nil
end

-- ===== Grenzen der überwachten Werte (ALARME in kern.lua) =====
-- Ergebnis je Alarm n, in Rohwerten wie im Kern (Wert in w.v): { ein, o (orange/Warnung oder nil), g (rot/Alarm oder
-- nil), ans, vib, mAus }. Fehlt der Eintrag oder ist er ungültig, gilt die Werkgrenze (Sicherheitsregel 6.5).
local function grenzeRoh(werte, H, c, n, e, werk)
  local u = M.UEBERWACHT[n]
  local vor, div = u[2], u[3]
  local wO, wG = werk[vor .. "Orange"], werk[vor .. "Grenze"]
  if vor == "aZelle" then
    local z = H.ZELLE_WERK[c.akkutyp] or H.ZELLE_WERK[1]
    wO, wG = z[1], z[2]
  end
  local r = { ans = true, vib = true, mAus = true, o = wO / div, g = wG / div }
  if e == nil or e.werk then
    r.ein = werk[vor .. "Ein"] == 1
    if e and e.ohneStufen then r.ans, r.vib, r.mAus = e.ansage, e.vibration, e.beiMotorAus ~= false end
    return r
  end
  r.ans, r.vib, r.mAus = e.ansage, e.vibration, e.beiMotorAus ~= false
  if e.aus then r.ein = false return r end
  local a = werte and werte["lua:" .. u[1]]
  local function roh(x, wv)
    if x == "werk" then return wv / div end           -- ungültige Stufe: Werkgrenze dieser Stufe
    if type(x) ~= "number" then return nil end         -- Stufe aus
    if a then x = (x - a.versatz) / a.faktor end      -- Grenze gilt im angezeigten Wert, der Kern prüft den Rohwert
    return x
  end
  local o, g = roh(e.warnung, wO), roh(e.alarm, wG)
  if o == nil and g == nil then r.ein = false return r end
  r.ein, r.o, r.g = true, o, g
  return r
end

-- Einstellungen …Ein/…Orange/…Grenze (ganze Zahlen im Bereich von ZAHLEN) für das Menü aus einem Ergebnis von grenzeRoh
local function grenzeCfg(H, n, r)
  local u = M.UEBERWACHT[n]
  local vor, div = u[2], u[3]
  local fO, fG = zeile(H, vor .. "Orange"), zeile(H, vor .. "Grenze")
  local function int(x, f)
    x = floor(x * div + 0.5)
    if x < f[3] then x = f[3] elseif x > f[4] then x = f[4] end
    return x
  end
  local tief = M.WERTE[u[1]][6] == "unter"
  local G = r.g and int(r.g, fG) or (tief and fG[3] or fG[4])   -- Alarm aus: Rand des Bereichs
  local O = r.o and int(r.o, fO) or G                           -- Warnung aus: gleich wie der Alarm
  return r.ein and 1 or 0, O, G
end

-- Ergebnis von M.schritt auf das Widget anwenden (nur bei Zustand «geladen»). Die Zahlen des Widget-Speichers bleiben
-- als Kopie in w.cfgWidget (kern.lua schreibt sie unverändert zurück); die Zahlen in w.cfg werden Werk -> Studio ->
-- .funke.lua. Sensorzuordnungen (q…) in w.cfg bleiben, wie sie im Widget eingestellt sind.
function M.anwenden(w, J, H)
  local c = w.cfg                                        -- dieselbe Tabelle (ein offenes Menü zeigt sie), Sensoren bleiben
  local werk = H.standard()
  if w.cfgWidget == nil then
    local e = {}
    for k in pairs(werk) do e[k] = c[k] end
    w.cfgWidget = e
  end
  for k, v in pairs(werk) do c[k] = v end
  local S = { zustand = "geladen", fehler = J.fehler, werte = J.werte, ansichten = J.ansichten, einstBasis = {},
    grenzenStudio = J.grenzenStudio, gCfg = {}, extra = J.extra, quellen = {}, offen = J.offen, st = {}, zx = {}, kurven = {},
    WERTE = M.WERTE, UEB = M.UEBERWACHT }               -- für studiolauf.lua und ansicht.lua (studio.lua wird freigegeben)
  for _, e in ipairs(M.EINST) do
    local k = e[1]
    local b = J.einstStudio[k]
    if b == nil then b = werk[k] end
    S.einstBasis[k] = b
    local v = J.einst[k]
    if v == nil then v = werk[k] end
    c[k] = v
  end
  w.gs = {}
  c.mAus = 0                                             -- «auch bei Motor aus» je Alarm aus Studio-Datei + .funke.lua
  for n, u in pairs(M.UEBERWACHT) do
    local r = grenzeRoh(J.werte, H, c, n, J.grenzen["lua:" .. u[1]], werk)
    w.gs[n] = r
    if r.mAus then c.mAus = c.mAus + H.MAUS_BIT[n] end
    local E, O, G = grenzeCfg(H, n, r)
    c[u[2] .. "Ein"], c[u[2] .. "Orange"], c[u[2] .. "Grenze"] = E, O, G
    S.gCfg[n] = { E, O, G }
  end
  w.studio = S
end

-- ===== .funke.lua schreiben (Abschnitt 9): Text nach Abschnitt 4, erst .funke.neu, prüfen, dann umbenennen =====
local function esc(t)
  return '"' .. t:gsub(".", function(c) return "\\" .. c:byte() end) .. '"'
end
local function zahl(v)
  if ganz(v) then return string.format("%d", v) end
  if v == floor(v) and math.abs(v) < 1e9 then return string.format("%d", floor(v)) end
  return string.format("%.4f", v)
end
M.esc, M.zahl = esc, zahl

-- einst: { [Studio-Name] = Wert }, grenzen: { [Schlüssel] = { warnung=, alarm=, aus= } }
function M.funkeText(einst, grenzen)
  local t = { "return { format = 1, einstellungen = {" }
  local namen = {}
  for k in pairs(einst) do namen[#namen + 1] = k end
  table.sort(namen)
  for _, k in ipairs(namen) do
    local v = einst[k]
    local x = type(v) == "boolean" and tostring(v) or zahl(v)
    t[#t + 1] = " " .. k .. " = " .. x .. ","
  end
  t[#t + 1] = " }, grenzen = {"
  local gk = {}
  for k in pairs(grenzen) do gk[#gk + 1] = k end
  table.sort(gk)
  for _, k in ipairs(gk) do
    local e = grenzen[k]
    local f = {}
    if e.aus == true then f[#f + 1] = "aus = true" elseif e.aus == false then f[#f + 1] = "aus = false" end
    if e.warnung == false then f[#f + 1] = "warnung = false" elseif e.warnung then f[#f + 1] = "warnung = " .. zahl(e.warnung) end
    if e.alarm == false then f[#f + 1] = "alarm = false" elseif e.alarm then f[#f + 1] = "alarm = " .. zahl(e.alarm) end
    if e.beiMotorAus ~= nil then f[#f + 1] = "beiMotorAus = " .. tostring(e.beiMotorAus == true) end
    t[#t + 1] = " [" .. esc(k) .. "] = { " .. table.concat(f, ", ") .. " },"
  end
  t[#t + 1] = " } }\n"
  return table.concat(t)
end

-- Rückgabe true, wenn geschrieben (oder ohne Änderung gelöscht)
function M.funkeSchreiben(kennung, text)
  local basis = M.ORDNER .. kennung .. "." .. M.LUA
  pcall(os.mkdir, "SCRIPTS:/studio")
  if text == nil then                                   -- nichts geändert: Datei weg
    pcall(os.remove, basis .. ".funke.lua")
    return true
  end
  local ok, f = pcall(io.open, basis .. ".funke.neu", "w")
  if not ok or not f then return false end
  local okW = pcall(f.write, f, text)
  f:close()
  if not okW or not studioLaden(basis .. ".funke.neu", M.FORMAT) then
    pcall(os.remove, basis .. ".funke.neu")
    return false
  end
  -- Am Sender überschreibt os.rename eine vorhandene Datei nicht (gemessen X18RS 20.11.2026): erst löschen
  local okA, alt = pcall(io.open, basis .. ".funke.lua", "r")
  if okA and alt then alt:close() pcall(os.remove, basis .. ".funke.lua") end
  local okR, r = pcall(os.rename, basis .. ".funke.neu", basis .. ".funke.lua")
  return okR and r ~= nil and r ~= false
end

-- Änderungen aus dem Funken-Menü gegenüber dem Studio-Stand als Text für .funke.lua (nil = keine Änderung)
function M.funkeAusCfg(w, H)
  local S, c = w.studio, w.cfg
  local werk = H.standard()
  local einst, grenzen, n = {}, {}, 0
  for _, e in ipairs(M.EINST) do
    local k = e[1]
    if c[k] ~= S.einstBasis[k] then
      einst[studioName(k)] = (e[2] == "b") and (c[k] == 1) or c[k]
      n = n + 1
    end
  end
  for nm, u in pairs(M.UEBERWACHT) do
    local key = "lua:" .. u[1]
    -- Studio-Stand mit dem jetzigen Akkutyp (ohne Eintrag folgt die Zellen-Werkgrenze dem Akkutyp)
    local bE, bO, bG = grenzeCfg(H, nm, grenzeRoh(S.werte, H, c, nm, S.grenzenStudio[key], werk))
    local E, O, G = c[u[2] .. "Ein"], c[u[2] .. "Orange"], c[u[2] .. "Grenze"]
    if E ~= bE or O ~= bO or G ~= bG then
      local a = S.werte[key]
      local function anz(x)
        x = x / u[3]
        if a then x = x * a.faktor + a.versatz end
        return x
      end
      if E ~= 1 then grenzen[key] = { aus = true }
      else grenzen[key] = { aus = false, warnung = (O ~= G) and anz(O) or false, alarm = anz(G) } end   -- hebt ein «aus» der Studio-Datei auf
      n = n + 1
    end
    -- «auch bei Motor aus»: true hebt ein false der Studio-Datei auf (Format 2 §3.5)
    local gs = S.grenzenStudio[key]
    local basis = not (gs and gs.beiMotorAus == false)
    local jetzt = (c.mAus // H.MAUS_BIT[nm]) % 2 == 1
    if jetzt ~= basis then
      grenzen[key] = grenzen[key] or {}
      grenzen[key].beiMotorAus = jetzt
      n = n + 1
    end
  end
  if n == 0 then return nil end
  return M.funkeText(einst, grenzen)
end

-- ===== Info-Datei (Abschnitt 14), JSON, nur das Studio liest sie =====
local function jtext(t)
  t = tostring(t or "")
  return '"' .. t:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
    return string.format("\\u%04X", c:byte())
  end) .. '"'
end
M.jtext = jtext

-- Sensorliste in Schritten (je Aufruf 5, höchstens 100). Rückgabe: nil = läuft, sonst true (geschrieben/unnötig)
-- Die Liste kommt aus H.sensorListe (kern.lua): Kategorie als Zahl, am Sender war die Tabellenform leer (1.10.1).
function M.infoSchritt(w, version, formate, H)
  local I = w.infoJob
  if I == nil then
    I = { i = 0, s = {} }
    I.liste = H.sensorListe()
    w.infoJob = I
    return nil
  end
  local bis = math.min(#I.liste, I.i + 5, 100)
  for i = I.i + 1, bis do
    local q = I.liste[i]
    local function r(f) local okf, v = pcall(q[f], q) if okf then return v end return nil end
    local a, sub, ph, nm, e = r("appId"), r("subId"), r("physId"), r("name"), r("unit")
    local t = '{ "appId": ' .. (ganz(a) and a or 0) .. ', "sub": ' .. (ganz(sub) and sub or 0)
      .. ', "phys": ' .. (ganz(ph) and ph or 0) .. ', "name": ' .. jtext(nm)
    local okE, eh = false, nil
    if e ~= nil and system.getUnitName then okE, eh = pcall(system.getUnitName, e) end
    if okE and type(eh) == "string" and eh ~= "" then t = t .. ', "einheit": ' .. jtext(eh) end
    I.s[#I.s + 1] = t .. " }"
  end
  I.i = bis
  if I.i < math.min(#I.liste, 100) then return nil end
  local okV, ver = pcall(system.getVersion)
  ver = okV and type(ver) == "table" and ver or {}
  local fenster = {}
  for _, f in ipairs(w.fenster or {}) do fenster[#fenster + 1] = '{ "breite": ' .. f[1] .. ', "hoehe": ' .. f[2] .. ' }' end
  local okN, name = pcall(model.name)
  local okP, pfad = pcall(model.path)
  local st = w.studioZustand or "fehlt"
  local t = '{\n "format": 1,\n "lua": "' .. M.LUA .. '",\n "luaVersion": ' .. jtext(version)
    .. ',\n "formate": [' .. table.concat(formate, ", ") .. '],\n "beiMotorAus": true,\n "modell": ' .. jtext(okN and name or "")
    .. ',\n "kennung": ' .. jtext(M.kennung())
    .. ((okP and type(pfad) == "string") and (',\n "modellPfad": ' .. jtext(pfad)) or "")
    .. ',\n "funke": ' .. jtext(ver.board) .. ',\n "ethos": ' .. jtext(ver.version)
    .. ',\n "fenster": [' .. table.concat(fenster, ", ") .. '],\n "studioDatei": ' .. jtext(st)
    .. ((st == "geladen" and (w.studioFehler or 0) > 0) and (',\n "fehler": ' .. w.studioFehler) or "")
    .. ',\n "sensoren": [\n  ' .. table.concat(I.s, ",\n  ") .. '\n ]'
    .. ',\n "studioQuelle": ' .. jtext(w.studioQuelle or "") .. ',\n "studioWahl": ' .. jtext(w.studioWahl or "auto")
    .. ',\n "ansichtGenutzt": ' .. jtext(w.ansichtGenutzt or "") .. ',\n "angepasst": ' .. tostring(w.angepasst == true)
    .. ',\n "hinweis": ' .. jtext(w.sFest or w.sInfo or "") .. '\n}\n'
  w.infoJob = nil
  if t == w.infoAlt then return true end               -- nichts geändert: nicht schreiben (SD-Karte schonen)
  pcall(os.mkdir, "SCRIPTS:/studio")
  local ok, f = pcall(io.open, M.ORDNER .. M.kennung() .. "." .. M.LUA .. ".info.json", "w")
  if ok and f then
    local okW = pcall(f.write, f, t)
    f:close()
    if okW then w.infoAlt = t return true end
  end
  print("Heli: Info-Datei konnte nicht geschrieben werden")
  return true
end

return M
