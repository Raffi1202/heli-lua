-- Heli: Anzeige (Seite 1), Überwachung in zwei Stufen mit Alarm, Drehzahl- und Autorotation-Ansage,
-- Flug-Erfassung mit Motorschalter, Rückfragen, Einstellungen. Seite 2 (Flugliste) steht in fluege.lua.
local K = {}
local floor, max, min = math.floor, math.max, math.min

local FORMAT = 7                 -- Kennung des Speicherformats (bei geänderter Reihenfolge erhöhen)
local DT_BILD = 0.2              -- Bild höchstens alle 0,2 s neu zeichnen
local MAX_FLUEGE = 20            -- so viele Flüge bleiben in der Liste

-- Sensoren und Quellen (Reihenfolge = Reihenfolge im Speicher, Neues nur ans Ende)
local QUELLEN = {
  { "qProz", "Akku %", "Battery %" }, { "qVolt", "Akkuspannung", "Battery voltage" }, { "qRpm", "Drehzahl", "Head speed" },
  { "qStrom", "Strom", "Current" }, { "qTemp", "Reglertemperatur", "ESC temperature" }, { "qBec", "BEC-Spannung", "BEC voltage" },
  { "qZelle", "Zellenspannung", "Cell voltage" }, { "qMah", "Verbrauch mAh", "Used capacity mAh" }, { "qRssi", "RSSI", "RSSI" },
  { "qGas", "Gaskanal", "Throttle channel" }, { "qPid", "PID-Profil", "PID profile" }, { "qRate", "Raten-Profil", "Rate profile" },
  { "qAkkuProfil", "Akku-Profil", "Battery profile" },   -- nicht mehr benutzt (seit 1.4.1); nur noch zum Lesen der Formate 1–4, ab Format 5 nicht gespeichert
  { "qMotor", "Motorschalter", "Motor switch" },     -- ab Format 3
}

-- Zahlen: Name, ab Werk, kleinster, grösster Wert (Reihenfolge = Reihenfolge im Speicher, Neues nur ans Ende)
local OHNE_PLATZ = { mAus = true, akkutyp = true }   -- ab Format 7 ohne eigenen Platz im storage
local ZAHLEN = {
  { "zellen", 0, 0, 14 }, { "kapaz", 0, 0, 30000 },
  { "rpmMax", 2400, 500, 6000 }, { "aMax", 250, 10, 500 }, { "tMax", 100, 50, 150 },
  { "warnEin", 1, 0, 1 }, { "warnGrenze", 80, 30, 150 }, { "warnTakt", 5, 2, 60 },
  { "rpmEin", 1, 0, 1 }, { "gasGrenze", -25, -100, 100 }, { "rpmTakt", 1, 1, 30 }, { "rpmMin", 300, 0, 6000 },
  { "sprache", 0, 0, 2 }, { "flugRpm", 500, 100, 6000 }, { "flugSek", 30, 5, 300 },
  -- ab Format 2: weitere Alarme (Zellenspannung in 1/100 V, BEC in 1/10 V)
  { "aProzEin", 1, 0, 1 }, { "aProzGrenze", 25, 5, 90 }, { "aProzTakt", 10, 5, 120 },
  { "aZelleEin", 1, 0, 1 }, { "aZelleGrenze", 350, 250, 420 }, { "aZelleTakt", 10, 5, 120 },
  { "aBecEin", 0, 0, 1 }, { "aBecGrenze", 70, 30, 150 }, { "aBecTakt", 10, 5, 120 },
  { "aMahEin", 0, 0, 1 }, { "aMahGrenze", 4000, 100, 30000 }, { "aMahTakt", 20, 5, 120 },
  -- ab Format 3: Stellung «Motor aus» des Motorschalters (1 oben, 2 Mitte, 3 unten)
  { "swAus", 1, 1, 3 },
  -- ab Format 4: erste Schwelle je Überwachung (Anzeige orange, noch kein Ton), gleiche Einheiten wie die Alarmschwelle
  { "warnOrange", 70, 30, 150 }, { "aProzOrange", 35, 5, 95 }, { "aZelleOrange", 360, 250, 420 },
  { "aBecOrange", 72, 30, 150 }, { "aMahOrange", 3500, 100, 30000 },
  -- Ansage «Autorotation» nach Motor aus: alle so viele Sekunden, bis der Rotor steht (0 = aus)
  { "autoSek", 3, 0, 30 },
  -- ab Format 5: Akkutyp für die %-Schätzung aus der Spannung (1 LiPo, 2 LiHV, 3 Li-Ion)
  { "akkutyp", 1, 1, 3 },
  -- ab Format 6: «auch bei Motor aus» je Alarm als Bitmaske (1 Reglertemp., 2 Akku %, 4 Zelle, 8 BEC, 16 Verbrauch),
  -- gesetztes Bit = Alarm kommt auch bei Motorschalter aus (ab Werk alle). Im storage kein eigener Platz (fasst nur ~51
  -- Werte): steckt im Platz von swAus, gespeichert als swAus + 4 × (31 − mAus).
  { "mAus", 31, 0, 31 },
  -- ab Format 7: gewählte Studio-Datei als Kennzahl des Pfads (0 = automatisch nach Modellname). Dafür steckt akkutyp
  -- im Platz von autoSek (autoSek + 32 × (akkutyp − 1)); akkutyp und mAus haben keinen eigenen Platz.
  { "studio", 0, 0, 16777215 },
}
-- Ältere Speicherformate werden weiter gelesen: Zahl der Quellen und Zahlen je Format
-- Zellen-Alarm ab Werk je Akkutyp in 1/100 V: { orange, rot }. LiPo und LiHV 3,60 / 3,50 V, Li-Ion 3,10 / 3,00 V.
local ZELLE_WERK = { { 360, 350 }, { 360, 350 }, { 310, 300 } }

local ALT = { [1] = { 13, 15 }, [2] = { 13, 27 }, [3] = { 14, 28 }, [4] = { 14, 34 }, [5] = { 13, 35 }, [6] = { 13, 35 } }
-- Ab Format 5 belegt das alte, unbenutzte Feld «Akku-Profil» keinen Speicherplatz mehr (dafür der Akkutyp): Ethos
-- speichert nur rund 51 Werte je Widget (gemessen 26.1.2). Format 5: fmt + 13 Quellen + 35 Zahlen + ende = 50.
-- Format 6: «mAus» teilt sich den Platz mit swAus, weiter 50 Werte (1 Reserve; für mehr Einstellungen eine eigene Datei).
local function quellenSpeicher(fmt)
  if fmt < 5 then return QUELLEN end
  local l = {}
  for _, f in ipairs(QUELLEN) do
    if f[1] ~= "qAkkuProfil" then l[#l + 1] = f end
  end
  return l
end

-- Alarme: Wert in v, Vorsilbe der Einstellungen (…Ein, …Orange, …Grenze, …Takt), tief = Alarm bei zu kleinem Wert,
-- Teiler der Schwelle, Abstand zum Entwarnen, Einheit und Kommastellen der Ansage, kleinster gültiger Wert, Sprachdatei
local ALARME = {
  { "temp", "warn", false, 1, 2, UNIT_CELSIUS, 0, nil, "alarm_reglertemperatur" },
  { "proz", "aProz", true, 1, 2, UNIT_PERCENT, 0, nil, "alarm_akku" },
  { "zelle", "aZelle", true, 100, 0.05, UNIT_VOLT, 2, 0.5, "alarm_zellenspannung" },
  { "bec", "aBec", true, 10, 0.2, UNIT_VOLT, 1, 0.5, "alarm_bec" },
  { "mah", "aMah", false, 1, 50, UNIT_MILLIAMPERE_HOUR, 0, nil, "alarm_verbrauch" },
}

-- Texte der Anzeige: 1 = englisch, 2 = deutsch (Einstellung «Sprache»: 0 = wie der Sender)
local TEXT = {
  { akku = "BATTERY", rpm = "HEAD RPM", strom = "CURRENT", temp = "ESC TEMP", uRpm = "RPM", uA = "AMPS",
    max = "MAX", modus = "FLIGHT MODE", bec = "BEC OUTPUT", zelle = "CELL VOLT", mah = "USED CAPACITY",
    tief = "LOW", nullen = "RESET", zEin = "SET CELLS", zEin2 = "in menu", fluege = "Flights", flug = "Flight", profil = "Profile", rate = "Rate",
    gov = "GOVERNOR", kopfRpm = "Head", scharf = "ARMED", sicher = "SAFE", empfang = "SIGNAL", zeit = "FLIGHT TIME",
    fluegeK = "FLIGHTS", laeuft = "running", pause = "paused", nurRf = "no governor", klein = "zone too small",
    studioKaputt = "Studio file broken - default", sKaputt = "Studio: file faulty (%s)", sSyntax = "syntax",
    sZuNeu = "too new, update the Lua", sKeine = "Studio: no matching view", sAngepasst = "Studio: view %s adapted",
    sWeg = ", %d left out", studioZuNeu = "Studio file too new - update the Lua",
    studioFehler = "Studio file: %s errors", funkeVerworfen = "Changes on the radio discarded", funkeNicht = "Change not saved",
    symFehlen = "Studio: %s symbols missing", leistung = "POWER", govN = { [0] = "OFF", "IDLE", "SPOOLUP", "RECOVERY", "ACTIVE", "HOLD", "LOST HEADSPEED", "AUTOROTATION", "BAILOUT", "BYPASS" } },
  { akku = "AKKU", rpm = "DREHZAHL", strom = "STROM", temp = "REGLERTEMP.", uRpm = "U/MIN", uA = "AMPERE",
    max = "MAX", modus = "FLUGMODUS", bec = "BEC-SPANNUNG", zelle = "ZELLE", mah = "VERBRAUCHT",
    tief = "TIEF", nullen = "AUF 0", zEin = "ZELLEN?", zEin2 = "im Menü", fluege = "Flüge", flug = "Flug", profil = "Profil", rate = "Rate",
    gov = "GOVERNOR", kopfRpm = "Kopf", scharf = "SCHARF", sicher = "SICHER", empfang = "EMPFANG", zeit = "FLUGZEIT",
    fluegeK = "FLÜGE", laeuft = "läuft", pause = "Pause", nurRf = "kein Governor", klein = "Feld zu klein",
    studioKaputt = "Studio-Datei kaputt - Standard", sKaputt = "Studio: Datei fehlerhaft (%s)", sSyntax = "Syntax",
    sZuNeu = "zu neu, Lua aktualisieren", sKeine = "Studio: keine passende Ansicht", sAngepasst = "Studio: Ansicht %s angepasst",
    sWeg = ", %d weggelassen", studioZuNeu = "Studio-Datei zu neu - Lua aktualisieren",
    studioFehler = "Studio-Datei: %s Fehler", funkeVerworfen = "Änderungen an der Funke verworfen", funkeNicht = "Änderung nicht gespeichert",
    symFehlen = "Studio: %s Symbole fehlen", leistung = "LEISTUNG", govN = { [0] = "AUS", "LEERLAUF", "HOCHLAUF", "WIEDERANLAUF", "AKTIV", "HOLD", "DREHZAHL VERLOREN", "AUTOROTATION", "BAILOUT", "BYPASS" } },
}

local C = nil                    -- Farben, beim ersten Zeichnen angelegt
local REF = { 15, 18, 25, 27, 33, 41, 53 }   -- Schrifthöhen auf 800 × 480, für die das Bild ausgelegt ist
local MASS = 1                   -- Massstab des Bildes gegenüber 800 × 480, in zeichne gesetzt
local SCHRIFT = nil              -- Schriften mit Höhe, beim ersten Zeichnen gemessen
local STUDIO = nil               -- studio.lua (Lua-Studio-Format v1): nur geladen beim Laden der Datei, für .funke.lua und Info-Datei
local LAUF = nil                 -- studiolauf.lua: Betrieb mit Studio-Datei, nur geladen, solange eine gilt
local ZS = nil                   -- Farben, Texte, Schriften für ansicht.lua (in paint gesetzt)
local ANSICHT = nil              -- ansicht.lua: zeichnet die Plätze einer Studio-Ansicht, nur geladen, solange eine passt
-- studio_symbole.lua (Referenz Lua-Studio-Format 2): je Widget in w.sym, nur geladen, solange eine Format-2-Datei gilt
local STUDIO_HINWEIS_S = 8       -- s: so lange steht ein Studio-Hinweis unten, danach bleibt oben rechts ein «!»

-- ---------------------------------------------------------------- Hilfen

-- Ganze Zahl als Text; verträgt auch krumme oder fehlende Werte
local function ganz(x)
  x = tonumber(x)
  if x == nil or x ~= x or x > 1e9 or x < -1e9 then return "0" end
  return string.format("%.0f", x)
end

local function gut(v)
  if type(v) == "number" and v == v and v > -1e9 and v < 1e9 then return v end
  return nil
end

local function zahl(q, opt)
  if q == nil then return nil end
  local ok, v
  -- Optionen (Zellenzahl, einzelne Zelle) nur als Tabelle: q:value(OPTION_…) liefert die Gesamtspannung
  -- (gemessen, Simulator 26.1.2), q:value({ options = OPTION_… }) den gewünschten Wert.
  if opt ~= nil then ok, v = pcall(q.value, q, { options = opt }) else ok, v = pcall(q.value, q) end
  if not ok then return nil end
  return gut(v)
end

-- Zellenspannung: ein Zellensensor (FLVSS, in Ethos «LiPo») liefert mit q:value() die Summe seiner Zellen. Dann
-- gilt die tiefste Zelle. Echter Zellensensor = ganze Zellenzahl 1 bis 8 und jede Zelle bis 5 V (wie liesAkku in
-- motoren-lua). Ein anderer Sensor über 5 V ist eine Gesamtspannung: geteilt durch die eingestellte Zellenzahl,
-- ohne Zellenzahl kein Wert (nichts raten).
local function zelleWert(q, zellen)
  if q == nil then return nil end
  if OPTION_CELL_COUNT and OPTION_CELL_INDEX then
    local n = zahl(q, OPTION_CELL_COUNT)
    if n and n >= 1 and n <= 8 and n == floor(n) then
      local tief, echt = nil, true
      for i = 1, n do
        local ok, opt = pcall(OPTION_CELL_INDEX, i)
        local z = ok and zahl(q, opt) or nil
        if z and z > 5 then
          echt = false
          break
        end
        if z and z > 0 and (tief == nil or z < tief) then tief = z end
      end
      if echt and tief then return tief end
    end
  end
  local roh = zahl(q)
  if roh and roh > 5 then
    if zellen and zellen > 0 then return roh / zellen end
    return nil
  end
  return roh
end

-- Sprache: 1 = englisch, 2 = deutsch. Einstellung 0 heisst «wie der Sender» (deutsch nur bei deutschem Sender).
local SPRACHE_SENDER = nil
local function sprache(c)
  if c.sprache == 1 or c.sprache == 2 then return c.sprache end
  if SPRACHE_SENDER == nil then
    SPRACHE_SENDER = 1
    if system.getLocale then
      local ok, l = pcall(system.getLocale)
      if ok and type(l) == "string" and l:sub(1, 2):lower() == "de" then SPRACHE_SENDER = 2 end
    end
  end
  return SPRACHE_SENDER
end

-- Sprachdatei abspielen: audio/de/<name>.wav oder audio/en/<name>.wav. Gibt false zurück, wenn die Datei fehlt.
local AUDIO_DA = {}
local function sage(w, name)
  if not system.playFile then return false end
  local pfad = "audio/" .. (sprache(w.cfg) == 2 and "de" or "en") .. "/" .. name .. ".wav"
  local da = AUDIO_DA[pfad]
  if da == nil then
    local ok, f = pcall(io.open, pfad, "r")
    da = (ok and f ~= nil) or false
    if da then pcall(f.close, f) end
    AUDIO_DA[pfad] = da
  end
  if da then pcall(system.playFile, pfad) end
  return da
end

-- Bit je Alarm in der Einstellung «mAus» (Reihenfolge wie ALARME)
local MAUS_BIT = { temp = 1, proz = 2, zelle = 4, bec = 8, mah = 16 }
K.MAUS_BIT = MAUS_BIT

-- Stellung eines Schalters: 1 oben, 2 Mitte, 3 unten (nil, wenn nicht lesbar)
local function stellung(q)
  local x = zahl(q)
  if x == nil then return nil end
  local ok1, lo = pcall(q.minimum, q)
  local ok2, hi = pcall(q.maximum, q)
  lo, hi = ok1 and gut(lo) or nil, ok2 and gut(hi) or nil
  if not (lo and hi and hi > lo) then lo, hi = -100, 100 end
  local d = (hi - lo) / 3
  if x < lo + d then return 1 end
  if x > hi - d then return 3 end
  return 2
end

local function istQuelle(v)
  local t = type(v)
  if not (t == "userdata" or (t == "table" and type(v.value) == "function")) then return false end
  if CATEGORY_NONE then
    local ok, k = pcall(v.category, v)
    if ok and k == CATEGORY_NONE then return false end
  end
  return true
end

-- Liste aller Telemetriesensoren. Am Sender (X18RS, Ethos 26.2.0, 20.11.2026) liefert getSources mit einer Tabelle
-- { category = … } eine LEERE Liste; mit der Kategorie als Zahl geht es (wie die Sensorsuche). Tabelle nur als Rückfall.
local function sensorListe()
  if not (system.getSources and CATEGORY_TELEMETRY_SENSOR) then return {} end
  local ok, l = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  if ok and type(l) == "table" and #l > 0 then return l end
  ok, l = pcall(system.getSources, { category = CATEGORY_TELEMETRY_SENSOR })
  if ok and type(l) == "table" then return l end
  return {}
end

local function standard()
  local c = {}
  for _, z in ipairs(ZAHLEN) do c[z[1]] = z[2] end
  return c
end

local function begrenze(c)
  for _, z in ipairs(ZAHLEN) do
    local v = gut(c[z[1]])
    if v == nil then v = z[2] end
    c[z[1]] = max(z[3], min(z[4], floor(v + 0.5)))
  end
end

-- Datei mit dem Flugzähler des aktuellen Modells
local function datei()
  local ok, p = pcall(model.path)
  if not ok or type(p) ~= "string" or p == "" then
    local ok2, n = pcall(model.name)
    p = (ok2 and type(n) == "string" and n ~= "") and n or "modell"
  end
  p = p:gsub("%.bin$", ""):gsub("[^%w%-]", "_")
  return "daten/" .. p .. ".txt"
end

-- Dauerwerte dieses Modells aus der Datei: Flugzähler, Nullpunkt des Verbrauchs und die Liste der letzten Flüge.
-- Ein Flug ist eine Liste: 1 Nr, 2 Dauer s, 3 mAh, 4 max. Drehzahl, 5 max. Strom, 6 max. Reglertemp.,
-- 7 tiefste Zelle, 8 tiefste BEC-Spannung, 9 Akku % am Ende (fehlende Werte nil).
local function liesDaten()
  local liste = {}
  local ok, f = pcall(io.open, datei(), "r")
  if not ok or not f then
    -- Übergang 1.13.0: Daten von «Heli RF» aus dem alten Ordner lesen (nur lesen, nie löschen). Beim nächsten Speichern
    -- landen sie im neuen Ordner scripts/heli/daten/.
    ok, f = pcall(io.open, "SCRIPTS:/helirf/" .. datei(), "r")
    if not ok or not f then return 0, 0, liste end
    print("Heli: flight data taken over from scripts/helirf/" .. datei())
  end
  local teile, len = {}, 0
  while len < 4096 do                                   -- Ethos liest nur in Stücken
    local ok2, s = pcall(f.read, f, 512)
    if not ok2 or type(s) ~= "string" or s == "" then break end
    teile[#teile + 1] = s
    len = len + #s
  end
  pcall(f.close, f)
  local text = table.concat(teile)
  local n, m = tonumber(text:match("fluege=(%d+)")), tonumber(text:match("mahnull=(%d+)"))
  if not (n and n >= 0 and n < 100000) then n = 0 end
  if not (m and m >= 0 and m < 1000000) then m = 0 end
  for zeile in text:gmatch("[^\r\n]+") do
    local d = zeile:match("^f=(.*)$")
    if d and #liste < MAX_FLUEGE then
      local r, i = {}, 0
      for teil in (d .. ","):gmatch("([^,]*),") do
        i = i + 1
        if i <= 9 then r[i] = gut(tonumber(teil)) end
      end
        if r[1] then liste[#liste + 1] = r end
    end
  end
  -- offener (pausierter) Flug vom letzten Mal
  local offen = nil
  local d = text:match("\na=([^\r\n]*)")
  if d then
    local r, i = {}, 0
    for teil in (d .. ","):gmatch("([^,]*),") do
      i = i + 1
      if i <= 9 then r[i] = gut(tonumber(teil)) end
    end
    if r[1] then
      offen = { nr = r[1], dauer = r[2] or 0, mah = r[3], rpm = r[4], a = r[5], t = r[6], z = r[7], bec = r[8], proz = r[9], pause = true }
    end
  end
  return floor(n), floor(m), liste, offen, not text:find("\nsymbole=0") -- 1.14.4: «Symbole anzeigen» (Werk ein)
end

local FORM = { "%.0f", "%.0f", "%.0f", "%.0f", "%.0f", "%.0f", "%.2f", "%.1f", "%.0f" }

local function schreibeDaten(w)
  if os and os.mkdir then pcall(os.mkdir, "daten") end
  local z = { "fluege=" .. ganz(w.fluege), "mahnull=" .. ganz(w.mahNull), "symbole=" .. (w.symbole == false and "0" or "1") }
  for _, r in ipairs(w.liste) do
    local e = {}
    for i = 1, 9 do e[i] = gut(r[i]) and string.format(FORM[i], r[i]) or "" end
    z[#z + 1] = "f=" .. table.concat(e, ",")
  end
  local a = w.akt
  if a and a.nr then                                   -- offener Flug: geht beim Ausschalten des Senders nicht verloren
    local r, e = { a.nr, a.dauer, a.mah, a.rpm, a.a, a.t, a.z, a.bec, a.proz }, {}
    for i = 1, 9 do e[i] = gut(r[i]) and string.format(FORM[i], r[i]) or "" end
    z[#z + 1] = "a=" .. table.concat(e, ",")
  end
  local ok, f = pcall(io.open, datei(), "w")
  if not ok or not f then return false end
  local okw = pcall(f.write, f, table.concat(z, "\n") .. "\n")
  pcall(f.close, f)
  return okw
end

-- ---------------------------------------------------------------- Anlegen, Lesen, Schreiben

function K.neu()
  local w = {
    cfg = standard(), v = {}, tB = 0, tRpm = -1000, seite = 1, liste = {}, ziele = {}, nZiele = 0,
    tStill = nil, tTeleWeg = nil, al = {}, tAlarmFrei = -1000, nSuche = 0, tSuche = -1000, fluege = 0, mahNull = 0, version = K.VERSION, autoOffen = true,
  }
  w.fluege, w.mahNull, w.liste, w.akt, w.symbole = liesDaten()
  if w.mahNull > 0 then w.mahHoch = w.mahNull end
  w.v.al, w.v.st = {}, {}
  for _, a in ipairs(ALARME) do w.al[a[1]] = { an = false, t = -1000 } end
  if CATEGORY_SYSTEM_EVENT and SYSTEM_EVENT_TELEMETRY_ACTIVE then
    local ok, q = pcall(system.getSource, { category = CATEGORY_SYSTEM_EVENT, member = SYSTEM_EVENT_TELEMETRY_ACTIVE })
    if ok then w.qTele = q end
  end
  if CATEGORY_SYSTEM_EVENT and SYSTEM_EVENT_FLIGHT_RESET then
    local ok, q = pcall(system.getSource, { category = CATEGORY_SYSTEM_EVENT, member = SYSTEM_EVENT_FLIGHT_RESET })
    if ok then w.qReset = q end
  end
  if CATEGORY_FLIGHT and FLIGHT_CURRENT_MODE then
    local ok, q = pcall(system.getSource, { category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE })
    if ok then w.qModus = q end
  end
  if CATEGORY_SYSTEM and MAIN_VOLTAGE then
    local ok, q = pcall(system.getSource, { category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE })
    if ok then w.qSender = q end
  end
  return w
end

local symFrei                    -- unten bei der Studio-Datei

function K.lies(w)
  local c = standard()
  w.cfg = c
  -- Die Studio-Datei gilt über den gelesenen Einstellungen: nach jedem Lesen neu anwenden
  w.studio, w.studioFertig, w.studioJob, w.cfgWidget, w.gs, w.funkeOffen = nil, false, nil, nil, nil, false
  symFrei(w)
  if not (storage and storage.read) then return end
  local function hol(name)
    local ok, v = pcall(storage.read, name)
    if ok then return v end
    return nil
  end
  local fmt = hol("fmt")
  local nq, nz
  if fmt == FORMAT then
    nq, nz = #quellenSpeicher(fmt), #ZAHLEN - 2          -- mAus und akkutyp ohne eigenen Platz
  elseif fmt ~= nil and ALT[fmt] then
    nq, nz = ALT[fmt][1], ALT[fmt][2]
  else
    return
  end
  local q, z = {}, {}
  for i = 1, nq do q[i] = hol("q" .. i) end
  for i = 1, nz do z[i] = hol("z" .. i) end
  if hol("ende") ~= fmt then
    print("Heli: gespeicherte Einstellungen unlesbar, Werte ab Werk")
    return
  end
  for i, f in ipairs(quellenSpeicher(fmt)) do c[f[1]] = istQuelle(q[i]) and q[i] or nil end
  if fmt >= 7 then
    local j = 0
    for _, f in ipairs(ZAHLEN) do
      if not OHNE_PLATZ[f[1]] then j = j + 1 c[f[1]] = gut(z[j]) end
    end
    if c.autoSek then                                   -- autoSek + 32 × (akkutyp − 1) zerlegen
      local roh = floor(c.autoSek + 0.5)
      c.autoSek, c.akkutyp = roh % 32, 1 + roh // 32
    end
  else
    for i, f in ipairs(ZAHLEN) do
      if i <= nz then c[f[1]] = gut(z[i]) end         -- neuere Zahlen bleiben auf dem Werkswert
    end
  end
  if fmt >= 6 and c.swAus then                          -- swAus + 4 × (31 − mAus) zerlegen
    local roh = floor(c.swAus + 0.5)
    c.swAus, c.mAus = roh % 4, 31 - roh // 4
  end
  if fmt < 4 then
    -- Einstellungen von vor Version 1.4: die neue Schwelle Orange passend zur bestehenden roten setzen
    if c.warnGrenze then c.warnOrange = c.warnGrenze - 10 end
    if c.aProzGrenze then c.aProzOrange = c.aProzGrenze + 10 end
    if c.aZelleGrenze then c.aZelleOrange = c.aZelleGrenze + 10 end
    if c.aBecGrenze then c.aBecOrange = c.aBecGrenze + 2 end
    if c.aMahGrenze then c.aMahOrange = c.aMahGrenze - 500 end
    -- früher war «englisch» der Werkswert; jetzt gilt ab Werk die Sprache des Senders
    if c.sprache == 1 then c.sprache = 0 end
  end
  -- 1.7.0 kannte noch keine Li-Ion-Werkswerte: steht ein Li-Ion-Modell noch auf den LiPo-Werkswerten, die Li-Ion-Werte
  -- nehmen (selbst eingestellte Schwellen bleiben)
  if c.akkutyp == 3 and c.aZelleOrange == ZELLE_WERK[1][1] and c.aZelleGrenze == ZELLE_WERK[1][2] then
    c.aZelleOrange, c.aZelleGrenze = ZELLE_WERK[3][1], ZELLE_WERK[3][2]
  end
  begrenze(c)
  w.autoOffen = false
end

function K.schreibe(w)
  if not (storage and storage.write) then return end
  local c = w.cfg
  local e = w.cfgWidget or c       -- mit Studio-Datei: die eigenen Zahlen des Widgets bleiben im Widget-Speicher
  pcall(storage.write, "fmt", FORMAT)
  for i, f in ipairs(quellenSpeicher(FORMAT)) do
    local v = c[f[1]]
    pcall(storage.write, "q" .. i, istQuelle(v) and v or 0)
  end
  for i, f in ipairs(ZAHLEN) do
    local x = e[f[1]] or f[2]
    if f[1] == "swAus" then x = x + 4 * (31 - (e.mAus or 31)) end   -- mAus im selben Platz
    if f[1] == "autoSek" then x = x + 32 * ((e.akkutyp or 1) - 1) end   -- akkutyp im selben Platz
    if f[1] == "studio" then x = c.studio or 0 end      -- Wahl der Studio-Datei gilt immer aus dem Widget
    if not OHNE_PLATZ[f[1]] then pcall(storage.write, "z" .. i, x) end
  end
  pcall(storage.write, "ende", FORMAT)
end

-- ---------------------------------------------------------------- Sensoren automatisch zuweisen

-- Füllt nur leere Felder. Kennung (AppID + Teilwert) zuerst, Namen und Einheit nur als Rückfall; alles bleibt von
-- Hand änderbar. suche.lua und die gemeinsame kennung.lua werden nur für die Suche geladen und danach freigegeben
-- (Lua-Speicher am Sender ist knapp).
-- Die Suche läuft über mehrere Weckrufe (Ethos bricht zu lange Aufrufe ab): sucheStart lädt sie, sucheSchritt
-- führt einen Schritt aus und gibt am Ende die Zahl der neu zugewiesenen Felder zurück (sonst nil) und den Speicher frei.
-- 1.11.0: Start in zwei Weckrufen (erst kennung.lua, dann suche.lua mit dem Index), zusammen waren es bis 4 800
-- Befehle in einem Aufruf.
local function sucheStart(w)
  if w.lauf then return end
  if not w.sucheKen then
    local f1, e1 = loadfile("kennung.lua")
    if not f1 then error(tostring(e1), 0) end
    w.sucheKen = f1()
    return
  end
  local ken = w.sucheKen
  w.sucheKen = nil
  local f2, e2 = loadfile("suche.lua")
  if not f2 then error(tostring(e2), 0) end
  w.lauf = f2()(w, ken, gut)
end

local function sucheSchritt(w)
  if not w.lauf then return nil end
  local ok, fertig, n = pcall(w.lauf)
  if ok and not fertig then return nil end
  w.lauf = nil
  collectgarbage()
  if not ok then error(fertig, 0) end
  if (n or 0) > 0 and model and model.dirty then pcall(model.dirty) end
  return n or 0
end

-- ---------------------------------------------------------------- Werte lesen, Töne, Flugzähler

-- Ruhespannung einer Zelle -> Ladung in % (Stützpunkte Spannung, Prozent), je Akkutyp. Richtwerte: LiPo 4,20 V,
-- LiHV 4,35 V, Li-Ion 4,20 V voll; Li-Ion verläuft flacher und tiefer (leer um 3,0 V).
local KENNLINIE = {
  { 3.27, 0, 3.61, 5, 3.69, 10, 3.71, 15, 3.73, 20, 3.75, 25, 3.77, 30, 3.79, 35, 3.80, 40, 3.82, 45, 3.84, 50,
    3.85, 55, 3.87, 60, 3.91, 65, 3.95, 70, 3.98, 75, 4.02, 80, 4.08, 85, 4.11, 90, 4.15, 95, 4.20, 100 },
  { 3.30, 0, 3.65, 5, 3.73, 10, 3.76, 15, 3.78, 20, 3.80, 25, 3.82, 30, 3.84, 35, 3.86, 40, 3.88, 45, 3.90, 50,
    3.93, 55, 3.96, 60, 4.00, 65, 4.04, 70, 4.08, 75, 4.13, 80, 4.18, 85, 4.23, 90, 4.29, 95, 4.35, 100 },
  { 3.00, 0, 3.30, 5, 3.40, 10, 3.47, 15, 3.52, 20, 3.56, 25, 3.60, 30, 3.63, 35, 3.66, 40, 3.69, 45, 3.72, 50,
    3.76, 55, 3.80, 60, 3.84, 65, 3.88, 70, 3.92, 75, 3.96, 80, 4.01, 85, 4.06, 90, 4.13, 95, 4.20, 100 },
}

-- Akkutyp wechseln: stehen die Zellen-Schwellen noch auf dem Werkswert des alten Typs, gelten die Werkswerte des
-- neuen. Selbst eingestellte Schwellen bleiben, wie sie sind.
local function akkutypSetzen(c, typ)
  local alt, neu = ZELLE_WERK[c.akkutyp] or ZELLE_WERK[1], ZELLE_WERK[typ] or ZELLE_WERK[1]
  if c.aZelleOrange == alt[1] and c.aZelleGrenze == alt[2] then
    c.aZelleOrange, c.aZelleGrenze = neu[1], neu[2]
  end
  c.akkutyp = typ
end

local function zelleProzent(u, typ)
  local k = KENNLINIE[typ] or KENNLINIE[1]
  if u <= k[1] then return 0 end
  for i = 3, #k, 2 do
    if u <= k[i] then
      return k[i - 1] + (k[i + 1] - k[i - 1]) * (u - k[i - 2]) / (k[i] - k[i - 2])
    end
  end
  return 100
end

-- Akku ohne Last: Zellenspannung da, kaum Strom, Rotor steht (soweit die Sensoren vorhanden sind)
local function istRuhe(v)
  return v.zelle ~= nil and v.zelle > 2.5 and (v.strom == nil or v.strom < 5) and (v.rpm == nil or v.rpm < 100)
end

local function telemetrie(w)
  local q = w.qTele
  if q == nil then return true end
  local ok, v = pcall(q.value, q)
  if not ok then return true end
  if type(v) == "number" then return v > 0 end
  if type(v) == "boolean" then return v end
  return true
end

-- Gasstellung in Prozent (−100 … +100)
local function gasProzent(q)
  local v = zahl(q)
  if v == nil then return nil end
  local ok, hi = pcall(q.maximum, q)
  hi = ok and gut(hi) or nil
  if hi and hi > 0 then return v / hi * 100 end
  return v / 10.24
end

-- Flybarless-System: Governor-Zustand (AppID 0x5125, 0 aus … 9 Bypass) und Arming-Flags (0x5122, Bit 0 = scharf).
-- Ethos legt für diese AppIDs keine Sensoren an, und per Lua angelegte DIY-Sensoren bekamen am Sender keine Werte
-- (X18RS, 20.11.2026). Darum liest das Widget die S.Port-Rahmen direkt (wie das Flybarless-System selbst): ein Leser für
-- 0x5120–0x512F, je Weckruf höchstens 16 Rahmen. Ein Wert gilt 5 s. Hat der Benutzer selbst Sensoren mit diesen
-- AppIDs angelegt, gelten deren Werte, wenn keine Rahmen kommen.
local RF_GOV, RF_ARM = 0x5125, 0x5122
local function rfLesen(w, now)
  if w.sp == nil and now - (w.tSp or -100) >= 5 then
    w.tSp = now
    if sport and sport.getSensor then
      local ok, se = pcall(sport.getSensor, { appIdStart = 0x5120, appIdEnd = 0x512F })
      if ok and se then w.sp = se end
    end
  end
  local se = w.sp
  if se and se.popFrame then
    for _ = 1, 16 do
      local ok, f = pcall(se.popFrame, se)
      if not ok or not f then break end
      local okA, a = pcall(f.appId, f)
      local okV, x = pcall(f.value, f)
      if okA and okV and type(x) == "number" then
        if a == RF_GOV then w.govRoh, w.tGovRoh = x, now
        elseif a == RF_ARM then w.armRoh, w.tArmRoh = x, now end
      end
    end
  end
  -- Eigene Sensoren mit diesen AppIDs: in der Sensorliste suchen (je Aufruf 20, dann 30 s Pause). Nicht über
  -- getSource mit appId: am Sender lieferte das ein Objekt ohne Wert, für fehlende Sensoren eines der Kategorie «keine»
  -- (X18RS, 20.11.2026, 1.10.1).
  if (w.qGov == nil or w.qArm == nil) and (w.rfListe or now - (w.tRf or -100) >= 30) then
    local R = w.rfListe
    if R == nil then
      w.tRf, w.rfListe = now, { l = sensorListe(), i = 0 }
    else
      local bis = min(#R.l, R.i + 20)
      for i = R.i + 1, bis do
        local q = R.l[i]
        local ok, a = pcall(q.appId, q)
        if ok and istQuelle(q) then
          if a == RF_GOV and w.qGov == nil then w.qGov = q elseif a == RF_ARM and w.qArm == nil then w.qArm = q end
        end
      end
      R.i = bis
      if bis >= #R.l then w.rfListe = nil end
    end
  end
  local g = (w.tGovRoh and now - w.tGovRoh <= 5) and w.govRoh or (w.qGov and zahl(w.qGov)) or nil
  local a = (w.tArmRoh and now - w.tArmRoh <= 5) and w.armRoh or (w.qArm and zahl(w.qArm)) or nil
  return g, a
end

-- Text der Menüzeile «Akku % kommt von»: was gerade gilt (Sensor mit Wert, Sensor ohne Wert, eigene Schätzung)
local function herkunftText(w)
  local c, v = w.cfg, w.v
  local de = sprache(c) == 2
  if not istQuelle(c.qProz) then return de and "eigene Schätzung (Akkutyp)" or "own estimate (battery type)" end
  local ok, n = pcall(c.qProz.name, c.qProz)
  n = (ok and type(n) == "string" and n ~= "") and n or "?"
  if v.prozSensor then return "Sensor " .. n end
  return n .. (de and ": kein Wert, Schätzung" or ": no value, estimate")
end

local function lesen(w, now)
  local c, v = w.cfg, w.v
  local tele = telemetrie(w)
  if tele then
    -- neuer Akku (Telemetrie war über 30 s weg): Tiefstwerte von vorn; kurze Aussetzer im Flug ändern nichts
    if w.tTeleWeg and now - w.tTeleWeg > 30 then
      v.becTief, v.zelleTief, w.anker, w.tRuhe, w.prozRuhe = nil, nil, nil, nil, nil
      v.rpmHoch, v.stromHoch, v.tempHoch = nil, nil, nil
    end
    w.tTeleWeg = nil
  elseif w.tTeleWeg == nil then
    w.tTeleWeg = now
  end
  v.tele = tele
  local function s(q) if tele then return zahl(q) end return nil end
  v.volt, v.rpm, v.strom, v.temp = s(c.qVolt), s(c.qRpm), s(c.qStrom), s(c.qTemp)
  v.bec, v.mahRoh, v.rssi = s(c.qBec), s(c.qMah), s(c.qRssi)
  -- Verbrauch ab dem Nullpunkt. Zählt der Sensor selbst wieder von vorn (neuer Akku, erst nach 2 s am Stück
  -- geglaubt), gilt wieder sein Wert, und Akku % und Tiefstwerte beginnen neu.
  local roh = v.mahRoh
  if roh then
    if w.mahHoch and roh < w.mahHoch - 5 then
      w.tFall = w.tFall or now
      if now - w.tFall >= 2 then
        w.mahHoch, w.tFall = roh, nil
        if w.mahNull > 0 then
          w.mahNull = 0
          w.tSchreib = now + 2
        end
        w.anker, w.tRuhe, w.prozRuhe, v.becTief, v.zelleTief = nil, nil, nil, nil, nil
        v.rpmHoch, v.stromHoch, v.tempHoch = nil, nil, nil
      end
    else
      w.mahHoch, w.tFall = roh, nil
    end
  end
  v.mah = roh and max(0, roh - w.mahNull) or nil
  v.pid, v.rate = s(c.qPid), s(c.qRate)
  v.gas = gasProzent(c.qGas)
  local g, a = rfLesen(w, now)
  if not tele then g, a = nil, nil end
  v.gov = g and floor(g + 0.5) or nil
  if a then v.scharf = floor(a + 0.5) % 2 == 1 else v.scharf = w.swAn end   -- ohne Governor-Telemetrie: Motorschalter

  -- Zellenzahl: eingestellt, sonst aus Akkuspannung und Zellensensor gerechnet. Aus der Gesamtspannung allein
  -- wird nicht geschätzt (46,4 V können 11 volle oder 12 halbleere Zellen sein).
  v.zelle = tele and zelleWert(c.qZelle, c.zellen) or nil
  if c.zellen > 0 then
    v.zellen = c.zellen
  elseif v.zelle and v.zelle > 2.5 and v.volt and v.volt > 2.5 then
    v.zellen = max(1, floor(v.volt / v.zelle + 0.5))
  else
    v.zellen = nil
  end
  if v.zelle == nil and v.volt and c.zellen > 0 then v.zelle = v.volt / c.zellen end
  -- Nur eine Gesamtspannung, kein Zellensensor und Zellenzahl «automatisch»: nicht schätzen, sondern zum Einstellen
  -- auffordern (Entscheid des Users 19.11.2026, gleich wie Motoren Lua)
  local rohZelle = tele and zahl(c.qZelle) or nil
  v.zellenFehlt = tele and c.zellen == 0 and v.zelle == nil
    and ((v.volt ~= nil and v.volt > 2.5) or (rohZelle ~= nil and rohZelle > 5)) or false

  -- Akku in %: 1. eigener Sensor. 2. Startwert aus der Ruhespannung (beim Anstecken oder nach dem Zurücksetzen),
  -- danach mit den verbrauchten mAh herunterzählen. 3. Ohne Kapazität oder Verbrauch: nur aus der Zellenspannung.
  v.proz = s(c.qProz)
  v.prozSensor = v.proz ~= nil
  if w.fHerkunft then                                   -- Menü offen: Zeile «Akku % kommt von» nachführen
    local text = herkunftText(w)
    if text ~= w.tHerkunft then
      w.tHerkunft = text
      if not pcall(w.fHerkunft.value, w.fHerkunft, text) then w.fHerkunft = nil end
    end
  end
  if v.proz == nil then
    local ruhe = istRuhe(v)
    if not ruhe then
      w.tRuhe = nil
    elseif w.anker == nil then
      w.tRuhe = w.tRuhe or now
      if now - w.tRuhe >= 2 then w.anker = { zelleProzent(v.zelle, c.akkutyp), v.mah or 0 } end   -- 2 s ruhig: Startwert merken
    end
    if c.kapaz > 0 and v.mah then
      if w.anker then
        v.proz = w.anker[1] - (v.mah - w.anker[2]) / c.kapaz * 100
      elseif v.zelle and not ruhe then
        v.proz = 100 - v.mah / c.kapaz * 100            -- noch nie in Ruhe gemessen (Sender im Flug eingeschaltet)
      end                                               -- sonst «--», bis der Startwert nach 2 s steht
    elseif v.zelle and v.zelle > 2.5 then
      -- ohne Kapazität: nur aus der Spannung. Unter Last wäre das zu tief, darum gilt der letzte Wert in Ruhe.
      if ruhe or w.prozRuhe == nil then w.prozRuhe = zelleProzent(v.zelle, c.akkutyp) end
      v.proz = w.prozRuhe
    end
  end
  -- kein Flugakku dran (Spannung bekannt und fast 0): keine %-Anzeige und kein Alarm
  if (v.zelle and v.zelle < 0.5) or (v.volt and v.volt < 1) then v.proz = nil end
  if v.proz then v.proz = max(0, min(100, v.proz)) end

  -- Höchst- und Tiefstwerte mit diesem Akku
  if v.rpm and (v.rpmHoch == nil or v.rpm > v.rpmHoch) then v.rpmHoch = v.rpm end
  if v.strom and (v.stromHoch == nil or v.strom > v.stromHoch) then v.stromHoch = v.strom end
  if v.temp and (v.tempHoch == nil or v.temp > v.tempHoch) then v.tempHoch = v.temp end
  if v.bec and v.bec > 0.5 and (v.becTief == nil or v.bec < v.becTief) then v.becTief = v.bec end
  if v.zelle and v.zelle > 0.5 and (v.zelleTief == nil or v.zelle < v.zelleTief) then v.zelleTief = v.zelle end

  local ok, m = false, nil
  if w.qModus then ok, m = pcall(w.qModus.stringValue, w.qModus) end
  v.modus = (ok and type(m) == "string" and m ~= "") and m or nil
  v.sender = zahl(w.qSender)
  -- Überwachung in zwei Stufen. Orange (erste Schwelle): nur die Anzeige wird orange. Rot (zweite Schwelle): Alarm mit
  -- Ton, wenn der Wert 1 s am Stück jenseits der Schwelle liegt. Zurück geht es erst mit etwas Abstand (kein Flattern).
  -- v.st: nil = nicht überwacht, 0 = gut (grün), 1 = orange, 2 = rot.
  local irgend = false
  for _, a in ipairs(ALARME) do
    local z, x = w.al[a[1]], v[a[1]]
    local G = w.gs and w.gs[a[1]]                     -- mit Studio-Datei: Grenzen aus studio.lua (eine Stufe kann aus sein)
    if (G and not G.ein) or (not G and c[a[2] .. "Ein"] ~= 1) or x == nil or (a[8] and x < a[8]) then
      z.an, z.seit, z.orange = false, nil, false
      v.st[a[1]] = nil
    else
      local g, o
      if G then g, o = G.g, G.o else g, o = c[a[2] .. "Grenze"] / a[4], c[a[2] .. "Orange"] / a[4] end
      local drin, raus, drinO, rausO
      if G and (g == nil or o == nil) then
        drin, raus, drinO, rausO = false, true, false, true
        if a[3] then
          if g then drin, raus = x < g, x > g + a[5] end
          if o then drinO, rausO = x < o, x > o + a[5] end
        else
          if g then drin, raus = x >= g, x < g - a[5] end
          if o then drinO, rausO = x >= o, x < o - a[5] end
        end
      elseif a[3] then
        drin, raus, drinO, rausO = x < g, x > g + a[5], x < o, x > o + a[5]
      else
        drin, raus, drinO, rausO = x >= g, x < g - a[5], x >= o, x < o - a[5]
      end
      if drin then
        z.seit = z.seit or now
        if now - z.seit >= 1 then z.an = true end
      else
        z.seit = nil
        if raus then z.an = false end
      end
      if drinO then z.orange = true elseif rausO then z.orange = false end
      v.st[a[1]] = (z.an and 2) or ((z.orange or drin) and 1) or 0
    end
    v.al[a[1]] = z.an
    irgend = irgend or z.an
  end
  v.warn = irgend
end

-- Verbrauch auf 0 setzen (Nullpunkt = jetziger Sensorwert), Tiefstwerte von vorn
local function nullen(w)
  local v = w.v
  w.mahNull = max(0, floor((v.mahRoh or w.mahHoch or 0) + 0.5))     -- ohne Telemetrie: letzter bekannter Stand
  v.becTief, v.zelleTief = nil, nil
  v.rpmHoch, v.stromHoch, v.tempHoch = nil, nil, nil
  -- Akku %: in Ruhe neu aus der Spannung bestimmen, unter Last beim jetzigen Stand weiterzählen
  if istRuhe(v) or v.proz == nil then w.anker = nil else w.anker = { v.proz, 0 } end
  w.prozRuhe = nil
  w.tRuhe = nil
  w.tSchreib = os.clock() + 1
  w.tB = 0
end

-- «Flug zurücksetzen» von Ethos setzt auch den Verbrauch im Widget zurück
local function flugReset(w)
  local q = w.qReset
  if q == nil then return end
  local ok, st = pcall(q.state, q)
  if not ok then return end
  st = st == true or (type(st) == "number" and st ~= 0)
  if w.resetAlt == false and st then nullen(w) end
  w.resetAlt = st
end

-- Motorschalter steht auf «Motor aus» (ohne zugewiesenen Schalter nie)
local function motorAus(c)
  local st = stellung(c.qMotor)
  return st ~= nil and st == c.swAus
end

local function toene(w, now)
  local c, v = w.cfg, w.v
  -- «auch bei Motor aus» (21.11.2026): ein Alarm ohne Haken schweigt (Ton, Vibration, Ansage), solange der Motorschalter
  -- auf aus steht. Die Anzeige bleibt orange/rot. Governor «Drehzahl verloren» kommt immer.
  local aus = nil
  -- Alarme: Ton, Vibration, Wort und Wert, je Alarm im eigenen Takt, nie zwei innerhalb von 3 s.
  -- Sind mehrere fällig, kommt der dran, der am längsten nicht angesagt wurde (keiner verhungert).
  if now >= w.tAlarmFrei then
    local wahl, zw = nil, nil
    for _, a in ipairs(ALARME) do
      local z = w.al[a[1]]
      if z.an and v[a[1]] and now - z.t >= c[a[2] .. "Takt"] and (zw == nil or z.t < zw.t) then
        local still = false
        if (c.mAus // MAUS_BIT[a[1]]) % 2 == 0 then
          if aus == nil then aus = motorAus(c) end
          still = aus
        end
        if not still then wahl, zw = a, z end
      end
    end
    if wahl then
      local x = v[wahl[1]]
      zw.t = now
      -- laufen Drehzahlansage oder «Autorotation», haben die Alarme Nachrang: höchstens alle 10 s einer
      w.tAlarmFrei = now + ((v.ansage or w.autoAn) and 10 or 3)
      if system.playTone then
        pcall(system.playTone, 2200, 180, 60)
        pcall(system.playTone, 2200, 180, 60)
      end
      local G = w.gs and w.gs[wahl[1]]                 -- Studio-Datei: Ansage und Vibration je Wert
      if system.playHaptic and not (G and G.vib == false) then pcall(system.playHaptic, ". .") end
      if not (G and G.ans == false) then
        sage(w, wahl[9])                               -- z. B. «Reglertemperatur», danach der Wert
        local dez = wahl[7]
        local a = w.studio and w.studio.werte["lua:" .. w.studio.UEB[wahl[1]][1]]
        if a then x, dez = x * a.faktor + a.versatz, a.stellen or dez end   -- angepasster Wert (Format 6.4)
        if system.playNumber then
          if dez == 0 then x = floor(x + 0.5) end
          pcall(system.playNumber, x, wahl[6], dez)
        end
      end
      -- dem Alarm kurz Platz lassen, dann wieder Drehzahl (eine fällige Ansage nur verschieben, nie vorziehen)
      w.tRpm = max(w.tRpm, now + min(2, c[wahl[2] .. "Takt"] / 2) - c.rpmTakt)
    elseif w.studio and LAUF then
      -- weitere Grenzen der Studio-Datei (Sensoren, Kanäle): Ton und Vibration, ohne Ansage (keine Sprachdatei)
      local e = LAUF.extraFaellig(w, now, motorAus(c))
      if e then
        w.tAlarmFrei = now + ((v.ansage or w.autoAn) and 10 or 3)
        if system.playTone then
          pcall(system.playTone, 2200, 180, 60)
          pcall(system.playTone, 2200, 180, 60)
        end
        if e.vib and system.playHaptic then pcall(system.playHaptic, ". .") end
      end
    end
  end
  -- Governor «Drehzahl verloren» (Governor-Fallback): einmal beim Wechsel Ton, Vibration und Ansage
  -- (ein kurzer Telemetrie-Ausfall zählt nicht als Wechsel; höchstens alle 10 s)
  if v.gov ~= nil and v.gov ~= w.govAlt then
    if v.gov == 6 and now - (w.tGov or -100) >= 10 then
      w.tGov = now
      if not sage(w, "drehzahl_verloren") and system.playTone then pcall(system.playTone, 2200, 300, 0) end
      if system.playHaptic then pcall(system.playHaptic, ". . .") end
    end
    w.govAlt = v.gov
  end
  -- «Autorotation»: nach Motor aus (Schalter) wiederholt, bis der Rotor steht oder der Motor wieder läuft
  if w.autoAn then
    local rpm = v.rpm
    if c.autoSek <= 0 or (rpm and rpm < 30) or (rpm == nil and now - (w.tAutoRpm or now) > 5) then
      w.autoAn = false
    else
      if rpm then w.tAutoRpm = now end
      if now - (w.tAuto or -1000) >= c.autoSek then
        w.tAuto = now
        if not sage(w, "autorotation") and system.playTone then      -- ohne Sprachdatei: drei kurze Töne
          pcall(system.playTone, 1500, 120, 60)
          pcall(system.playTone, 1500, 120, 60)
          pcall(system.playTone, 1500, 120, 60)
        end
        w.tRpm = max(w.tRpm, now + 1.3 - c.rpmTakt)                  -- danach wieder die Drehzahl
      end
    end
  end
  -- Drehzahlansage: Gas auf oder unter der Schwelle und der Rotor dreht noch
  if c.rpmEin == 1 and v.gas and v.gas <= c.gasGrenze + 0.5 and v.rpm and v.rpm >= c.rpmMin and v.rpm > 0 then
    v.ansage = true
    if now - w.tRpm >= c.rpmTakt then
      w.tRpm = now
      local x = v.rpm
      local a = w.studio and w.studio.werte["lua:drehzahl"]
      if a then x = x * a.faktor + a.versatz end       -- Studio-Datei: angepasste Drehzahl ansagen (Format 6.4)
      if system.playNumber then pcall(system.playNumber, floor(x + 0.5), 0, 0) end
    end
  else
    v.ansage = false
  end
end

-- Flug in die Liste übernehmen (nur wenn er gezählt hat) und abschliessen
local function flugEnde(w)
  local a = w.akt
  w.akt, w.tStill = nil, nil
  if w.dialog == "flug" then w.dialog = nil end
  w.tB = 0
  if a == nil or a.nr == nil then return end
  local l = w.liste
  l[#l + 1] = { a.nr, a.dauer, a.mah, a.rpm, a.a, a.t, a.z, a.bec, a.proz }
  while #l > MAX_FLUEGE do table.remove(l, 1) end
  schreibeDaten(w)
end

-- Flug erfassen.
-- Mit Motorschalter: Aus → Ein beginnt einen Flug (oder setzt einen pausierten fort); Ein → Aus hält ihn an und
-- fragt «Flug beendet?». «Nein» lässt ihn pausiert; ist der Akku danach über 30 s weg, gilt er als beendet.
-- Ohne Motorschalter: Beginn, sobald die Drehzahl über der Schwelle liegt, Ende nach 5 s darunter.
-- Ein Flug zählt (Nummer, Liste) erst, wenn er lange genug gedauert hat.
local function flug(w, now)
  local c, v = w.cfg, w.v
  local dt = now - (w.tFlugAlt or now)
  w.tFlugAlt = now
  if dt < 0 or dt > 5 then dt = 0 end
  local a = w.akt
  local aktiv = false
  local st = stellung(c.qMotor)
  if st then
    local an, war = st ~= c.swAus, w.swAn
    w.swAn = an
    if war == nil then
      -- erster Durchlauf mit diesem Schalter (Sender eingeschaltet oder Schalter eben zugewiesen)
      if an and a == nil and v.rpm and v.rpm >= c.flugRpm then
        a = { dauer = 0 }                                         -- Motor läuft schon: Flug beginnt jetzt
        w.akt = a
      elseif not an and a and not a.pause then
        if a.nr then
          a.pause = true                                          -- lief nach Drehzahl, Schalter steht auf Aus
          schreibeDaten(w)
        else
          w.akt, a = nil, nil
        end
      end
    else
      if an and not war then
        w.autoAn = false
        if a and a.pause then
          a.pause = false
          a.mahLetzt = nil                                        -- Verbrauch während der Pause zählt nicht zum Flug
          if w.dialog == "flug" then w.dialog = nil end          -- unbeantwortet wieder ein: war nur eine Pause
          w.tB = 0
        elseif a == nil then
          a = { dauer = 0 }
          w.akt = a
        end
      elseif war and not an then
        -- Motor aus bei drehendem Rotor: Ansage «Autorotation»
        if v.rpm and v.rpm >= 100 then w.autoAn, w.tAuto, w.tAutoRpm = true, nil, now end
      end
      if war and not an and a and not a.pause then
        if a.nr then
          a.pause = true
          w.dialog = "flug"
          w.tB = 0
          schreibeDaten(w)                                        -- offenen Flug sichern
        else
          w.akt, a = nil, nil                                     -- zu kurz für einen Flug: verwerfen
        end
      end
    end
    if a and a.pause and w.tTeleWeg and now - w.tTeleWeg > 30 then
      flugEnde(w)
      return
    end
    aktiv = a ~= nil and not a.pause
  else
    w.swAn, w.autoAn = nil, false
    local rpm = v.rpm
    if rpm and rpm < c.flugRpm then w.flugSperre = nil end
    if w.flugSperre then
      -- der laufende Flug wurde eben gelöscht: bis der Rotor steht, beginnt kein neuer
    elseif rpm and rpm >= c.flugRpm then
      w.tStill = nil
      if a == nil then
        a = { dauer = 0 }
        w.akt = a
      end
      if a.pause then
        a.pause, a.mahLetzt = nil, nil
      end
      aktiv = true
    elseif a then
      if rpm then
        w.tStill = w.tStill or now
        if now - w.tStill >= 5 then
          flugEnde(w)
          return
        end
      elseif w.tTeleWeg and now - w.tTeleWeg > 30 then
        flugEnde(w)
        return
      end
    end
  end
  if not aktiv then return end

  -- Zeit und Werte dieses Flugs
  a.dauer = a.dauer + dt
  if a.nr == nil and a.dauer >= c.flugSek then
    w.fluege = w.fluege + 1
    a.nr = w.fluege
    schreibeDaten(w)
  end
  local rpm = v.rpm
  if rpm and (a.rpm == nil or rpm > a.rpm) then a.rpm = rpm end
  if v.strom and (a.a == nil or v.strom > a.a) then a.a = v.strom end
  if v.temp and (a.t == nil or v.temp > a.t) then a.t = v.temp end
  if v.zelle and v.zelle > 0.5 and (a.z == nil or v.zelle < a.z) then a.z = v.zelle end
  if v.bec and v.bec > 0.5 and (a.bec == nil or v.bec < a.bec) then a.bec = v.bec end
  if v.proz then a.proz = v.proz end
  if v.mah then
    a.mah = a.mah or 0
    if a.mahLetzt and v.mah > a.mahLetzt then a.mah = a.mah + (v.mah - a.mahLetzt) end   -- verträgt ein Zurücksetzen
    a.mahLetzt = v.mah
  end
end

-- ---------------------------------------------------------------- Studio-Datei (Lua-Studio-Format v1)

-- Was studio.lua vom Kern braucht
local STUDIO_H = { ZAHLEN = ZAHLEN, ZELLE_WERK = ZELLE_WERK, standard = standard, istQuelle = istQuelle,
  sensorListe = sensorListe, MAUS_BIT = MAUS_BIT }

-- Format 2: Symbole der Studio-Datei (Referenz studio_symbole.lua, nur geladen bei format = 2) freigeben
function symFrei(w)
  if w.sym then pcall(w.sym.freigeben) end
  w.sym, w.symOffen = nil, false
end

-- Format 2: Referenz laden (je Widget eigene Kopie, eigener Zustand) und mit den Original-Tabellen starten.
-- Prüfen und Laden der Symbole laufen danach in eigenen wakeup (S.schritt), nie in paint.
local function symStart(w, roh)
  local f, e = loadfile("studio_symbole.lua")
  local ok, SY = false, e
  if f then ok, SY = pcall(f) end
  if not (ok and type(SY) == "table") then
    print("Heli: studio_symbole.lua nicht ladbar: " .. tostring(SY))
    return
  end
  w.sym = SY
  local okA, eA = pcall(SY.start, roh)
  w.symOffen = okA
  if not okA then
    print("Heli: Symbole: " .. tostring(eA))
    symFrei(w)
  end
end

-- Hinweis: Band unten (8 s), danach «!» oben rechts bis zum nächsten Modellwechsel; Text auch ins Log
-- ===== Fenstergrösse ohne genau passende Ansicht: ähnlichstes Seitenverhältnis, proportional umrechnen (einmal je Grösse) =====
local DARST_MIN = { zahl = { 90, 50 }, ring = { 110, 110 }, balken_w = { 140, 40 }, balken_s = { 50, 110 },
  kurve = { 180, 90 }, status = { 120, 40 } }   -- wie studio.lua M.DARST (Bezug Breite 800)

local function kopfHoehe(B, H)                  -- eigene Kopfzeile, die über den Plätzen liegt (wie in zeichnen)
  if H < B * 0.5 then return 34 * min(B / 784, H / 316) end
  return 58 * min(B / 800, H / 480)
end

local function ansichtFuer(w, wh)
  local S = w.studio
  if not S or not wh then return nil end
  return S.ansichten[wh] or (S.skaliert and S.skaliert[wh]) or nil
end

local function skaliere(Q, B, H)
  local ks0, kt0 = kopfHoehe(Q.breite, Q.hoehe), kopfHoehe(B, H)
  local kx, ky = B / Q.breite, (H - kt0) / (Q.hoehe - ks0)
  local A = { breite = B, hoehe = H, plaetze = {}, roh = Q.roh, weg = 0,
    deko = { kx = kx, ky = ky, ks0 = ks0, kt0 = kt0, B = B, H = H } }
  for _, q in ipairs(Q.plaetze) do
    local y0 = math.max(q.y, ks0)
    local n = {}
    for k, v in pairs(q) do if k ~= "r" then n[k] = v end end
    n.x, n.y = floor(q.x * kx + 0.5), floor(kt0 + (y0 - ks0) * ky + 0.5)
    n.b, n.h = floor(q.b * kx), floor((q.y + q.h - y0) * ky)
    if n.x + n.b > B then n.b = B - n.x end
    if n.y + n.h > H then n.h = H - n.y end
    local function passt(d) local m = DARST_MIN[d] return n.b >= floor(m[1] * B / 800 + 0.5) and n.h >= floor(m[2] * B / 800 + 0.5) end
    if not passt(n.darst) and n.darst ~= "status" and passt("zahl") then n.darst = "zahl" end
    if passt(n.darst) and n.h > 0 then A.plaetze[#A.plaetze + 1] = n else A.weg = A.weg + 1 end
  end
  return A
end

-- im wakeup: für die aktuelle Fenstergrösse die genutzte Ansicht bestimmen, bei Bedarf umrechnen, Hinweise setzen
local function studioUmrechnen(w, now)
  local S, wh = w.studio, w.fensterJetzt
  S.skaliert, S.keine = S.skaliert or {}, S.keine or {}
  if S.ansichten[wh] then
    if w.ansichtGenutzt ~= wh or w.angepasst then w.ansichtGenutzt, w.angepasst, w.sInfo, w.infoOffen = wh, false, nil, true end
    return
  end
  if S.skaliert[wh] or S.keine[wh] then return end
  local B, H = wh:match("^(%d+)x(%d+)$")
  B, H = tonumber(B), tonumber(H)
  local T = TEXT[sprache(w.cfg)]
  local best, bd, bf = nil, nil, nil
  for _, Q in pairs(S.ansichten) do
    local d = math.abs(math.log((Q.breite / Q.hoehe) / (B / H)))
    local fl = Q.breite * Q.hoehe
    if best == nil or d < bd - 1e-9 or (math.abs(d - bd) <= 1e-9 and fl > bf) then best, bd, bf = Q, d, fl end
  end
  if best == nil or not B then
    S.keine[wh] = true
    w.sFest, w.sAusruf, w.ansichtGenutzt, w.angepasst, w.infoOffen = T.sKeine, true, "", false, true
    print("Heli: " .. T.sKeine)
    return
  end
  local A = skaliere(best, B, H)
  S.skaliert[wh] = A
  local quelle = best.breite .. "x" .. best.hoehe
  w.ansichtGenutzt, w.angepasst, w.infoOffen = quelle, true, true
  local t = string.format(T.sAngepasst, best.breite .. "x" .. best.hoehe) .. (A.weg > 0 and string.format(T.sWeg, A.weg) or "")
  w.sHinweis, w.sHinweisBis, w.sAusruf, w.sNurKurz, w.sInfo = t, now + 5, true, true, t
  print("Heli: " .. t .. " -> " .. wh)
end

local function studioHinweis(w, text, now)
  w.sHinweis, w.sHinweisBis, w.sAusruf = text, now + STUDIO_HINWEIS_S, true
  print("Heli: " .. text)
end

local function studioLaden()
  if STUDIO == nil then
    local f, e = loadfile("studio.lua")
    if not f then error(e, 0) end
    STUDIO = f()
  end
  return STUDIO
end

local function lauf()
  if LAUF == nil then
    local f, e = loadfile("studiolauf.lua")
    if not f then error(e, 0) end
    LAUF = f()
  end
  return LAUF
end

-- Ohne (gültige) Studio-Datei: wieder die Zahlen aus dem Widget-Speicher, Sensoren wie zuletzt eingestellt
local function studioWeg(w)
  local e = w.cfgWidget
  if e then
    for k, v in pairs(e) do w.cfg[k] = v end
  end
  w.cfgWidget, w.gs, w.studio = nil, nil, nil
  symFrei(w)
  LAUF, ANSICHT = nil, nil
end

-- Einmal nach dem Laden des Modells in Schritten lesen, danach laufend Quellen suchen, Min/Max/Kurven führen,
-- Änderungen aus dem Menü in .funke.lua schreiben und die Info-Datei. studio.lua bleibt nur dafür geladen.
local function studioWecke(w, now)
  local T = TEXT[sprache(w.cfg)]
  if not w.studioFertig then
    local ok, m = pcall(studioLaden)
    if not ok then
      print("Heli: studio.lua nicht ladbar: " .. tostring(m))
      w.studioFertig, w.infoOffen = true, false
      return
    end
    local J = STUDIO.schritt(w, STUDIO_H)
    if J == nil then return true end
    w.studioFertig, w.infoOffen, w.studioZustand, w.studioFehler = true, true, J.zustand, nil
    w.sHinweis, w.sAusruf, w.sFest, w.sNurKurz, w.sInfo = nil, nil, nil, nil, nil
    w.studioQuelle, w.studioWahl, w.ansichtGenutzt, w.angepasst = J.quelle, J.wahl, nil, false
    symFrei(w)
    local okL, eL = true, nil
    if J.zustand == "geladen" then okL, eL = pcall(lauf) end
    if J.zustand == "geladen" and okL then
      STUDIO.anwenden(w, J, STUDIO_H)
      w.anker, w.prozRuhe = nil, nil                   -- Akkutyp kann anders sein: Startwert neu bestimmen
      w.studioFehler = J.fehler
      if J.fehler > 0 then studioHinweis(w, string.format(T.studioFehler, tostring(J.fehler)), now) end
      if J.funkeVerworfen then studioHinweis(w, T.funkeVerworfen, now) end
      if J.roh then symStart(w, J.roh) end             -- Format 2: Symbole ab dem nächsten wakeup prüfen und laden
    else
      if not okL then print("Heli: studiolauf.lua nicht ladbar: " .. tostring(eL)) end
      studioWeg(w)
      if J.zustand == "kaputt" or J.zustand == "zuNeu" then          -- Datei gefunden, aber Standardanzeige: fester Hinweis
        w.sFest, w.sAusruf = string.format(T.sKaputt, J.zustand == "zuNeu" and T.sZuNeu or T.sSyntax), true
        print("Heli: " .. w.sFest)
      end
    end
    return true
  end
  if w.studio then lauf().wecke(w, now, STUDIO_H) end
  if w.symOffen and w.sym then                          -- Format 2: Symbole prüfen und laden in Stücken (nie in paint)
    local ok, fertig = pcall(w.sym.schritt)
    if not ok or fertig then
      w.symOffen = false
      local okZ, _, fehlend = pcall(w.sym.zaehler)
      if okZ and type(fehlend) == "number" and fehlend > 0 then
        studioHinweis(w, string.format(T.symFehlen, tostring(fehlend)), now)
      end
    end
    -- kein «schwer»: die Plätze werden daneben schon vorbereitet (zusammen gemessen unter 3500 Befehle je Aufruf)
  end
  if w.funkeOffen and w.studio and now - (w.tFunke or -100) >= 2 then
    w.funkeOffen, w.tFunke = false, now
    local ok, gut = pcall(function()
      local M = studioLaden()
      return M.funkeSchreiben(M.kennung(), M.funkeAusCfg(w, STUDIO_H))
    end)
    if not (ok and gut) then studioHinweis(w, T.funkeNicht, now) end
    return true
  end
  if w.infoOffen then
    local ok, fertig = pcall(function() return studioLaden().infoSchritt(w, w.version, STUDIO.FORMATE, STUDIO_H) end)
    if not ok then print("Heli: Info-Datei: " .. tostring(fertig)) end
    if not ok or fertig then w.infoOffen = false end
    return true
  end
  if STUDIO and not w.studioJob then                   -- nichts mehr zu tun: studio.lua freigeben
    STUDIO = nil
    collectgarbage()
  end
end

function K.wecke(w)
  local now = os.clock()
  lesen(w, now)
  toene(w, now)
  flug(w, now)
  flugReset(w)
  -- Studio-Datei: Laden, Anwenden, .funke.lua und Info-Datei sind «schwere» Aufrufe; dann bleibt die Vorbereitung der
  -- Plätze für den nächsten Aufruf (Befehlsgrenze). Alarme und Töne oben laufen in jedem Aufruf.
  local schwer = false
  if not w.studioFertig or w.studio or w.infoOffen or STUDIO then schwer = studioWecke(w, now) end
  -- Plätze der sichtbaren Studio-Ansicht vorbereiten (paint zeichnet nur), je Aufruf höchstens 4
  if not schwer and w.studio and ANSICHT and ZS and w.seite ~= 2 then
    local a = ansichtFuer(w, w.fensterJetzt)
    if a then ANSICHT.vorbereiten(w, ZS, a, lauf(), 4) end
  end
  if w.sHinweis and now >= w.sHinweisBis then
    w.sHinweis = nil
    if w.sNurKurz then w.sAusruf, w.sNurKurz = w.sFest ~= nil, nil end   -- «angepasst»: danach nichts mehr
  end
  if not schwer and w.studio and w.fensterJetzt then studioUmrechnen(w, now) end
  if w.tSchreib and now >= w.tSchreib then
    w.tSchreib = nil
    schreibeDaten(w)
  end
  -- beim ersten Mal mit Telemetrie die Sensoren selbst zuweisen; wiederholen, bis die wichtigsten da sind
  if w.lauf then
    local okS, nS = pcall(sucheSchritt, w)
    if not okS or nS then
      w.tSuche = now
      print("Heli: Suche: " .. (okS and (tostring(nS) .. " neu zugewiesen") or ("Fehler " .. tostring(nS))))
    end
  elseif w.sucheKen then                                 -- zweiter Teil des Starts (sucheStart)
    if not pcall(sucheStart, w) then w.sucheKen = nil end
  elseif w.autoOffen and w.v.tele and now - w.tSuche >= 3 then
    w.tSuche = now
    w.nSuche = w.nSuche + 1
    if w.nSuche > 10 or (w.cfg.qRpm and w.cfg.qTemp) then w.autoOffen = false else pcall(sucheStart, w) end
  end
  if lcd.isVisible and not lcd.isVisible() then return end
  if now - w.tB >= DT_BILD then
    w.tB = now
    lcd.invalidate()
  end
end

-- ---------------------------------------------------------------- Zeichnen

local function farben()
  local R = lcd.RGB
  C = {
    bg = R(8, 16, 34), kachel = R(21, 34, 62), rand = R(44, 62, 100), linie = R(36, 52, 88),
    weiss = R(255, 255, 255), titel = R(214, 222, 236), grau = R(150, 164, 190),
    spur = R(38, 82, 150), gelb = R(245, 197, 24), hblau = R(168, 212, 242), blau = R(64, 150, 240),
    orange = R(242, 140, 30), rot = R(239, 60, 60), gruen = R(64, 220, 110), akzent = R(190, 204, 226),
  }
end

local function schriften()
  SCHRIFT = {}
  for i, f in ipairs({ FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL }) do
    lcd.font(f)
    local _, h = lcd.getTextSize("0")
    SCHRIFT[i] = { f, h }
  end
end

-- Text; gr = Schriftstufe 1–7, ym = Mitte in der Höhe, fett = doppelt gezeichnet, breit = wird verkleinert, bis er passt
local function text(x, ym, t, gr, farbe, ausr, fett, breit)
  gr = max(1, min(7, gr))
  -- auf kleineren Bildschirmen (X18: 480 × 320) die Schrift nehmen, die zur verkleinerten Kachel passt
  local ziel = REF[gr] * MASS * 1.15
  while gr > 1 and SCHRIFT[gr][2] > ziel do gr = gr - 1 end
  lcd.font(SCHRIFT[gr][1])
  if breit then
    while gr > 1 and lcd.getTextSize(t) > breit do
      gr = gr - 1
      lcd.font(SCHRIFT[gr][1])
    end
    -- passt er auch in der kleinsten Schrift nicht: hinten kürzen (höchstens 60 Schritte, ganze Zeichen)
    local n = 0
    if lcd.getTextSize(t) > breit then
      while n < 60 and #t > 1 and lcd.getTextSize(t .. ".") > breit do
        n = n + 1
        t = t:sub(1, #t - 1)
        while #t > 1 and t:byte(#t) >= 128 and t:byte(#t) < 192 do t = t:sub(1, #t - 1) end
        if #t > 0 and t:byte(#t) >= 192 then t = t:sub(1, #t - 1) end
      end
      t = t .. "."                                      -- gekürzt: Punkt zeigt, dass etwas fehlt
    end
  end
  lcd.color(farbe)
  local y = floor(ym - SCHRIFT[gr][2] / 2)
  x = floor(x)
  lcd.drawText(x, y, t, ausr or LEFT)
  if fett then lcd.drawText(x + 1, y, t, ausr or LEFT) end
  return SCHRIFT[gr][2]
end

local function rund(x, y, b, h, r, farbe)
  x, y, b, h, r = floor(x), floor(y), floor(b), floor(h), floor(r)
  lcd.color(farbe)
  if r < 1 then
    lcd.drawFilledRectangle(x, y, b, h)
    return
  end
  lcd.drawFilledRectangle(x + r, y, b - 2 * r, h)
  lcd.drawFilledRectangle(x, y + r, b, h - 2 * r)
  lcd.drawFilledCircle(x + r, y + r, r)
  lcd.drawFilledCircle(x + b - r - 1, y + r, r)
  lcd.drawFilledCircle(x + r, y + h - r - 1, r)
  lcd.drawFilledCircle(x + b - r - 1, y + h - r - 1, r)
end

local function kachel(x, y, b, h, s, randFarbe)
  local r = 6 * s
  rund(x, y, b, h, r, randFarbe or C.rand)
  local d = randFarbe and max(2, floor(3 * s)) or max(1, floor(1.5 * s))
  rund(x + d, y + d, b - 2 * d, h - 2 * d, r - d, C.kachel)
end

-- Kreisbogen; Winkel in Grad, 0 = oben, im Uhrzeigersinn
local function bogen(cx, cy, r1, r2, a0, a1, farbe)
  if a1 <= a0 then return end
  lcd.color(farbe)
  cx, cy, r1, r2 = floor(cx), floor(cy), floor(r1), floor(r2)
  if a0 >= 360 then a0, a1 = a0 - 360, a1 - 360 end
  if a1 > 360 then
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, 360)
    lcd.drawAnnulusSector(cx, cy, r1, r2, 0, a1 - 360)
  else
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, a1)
  end
end

local function fz(v, dez)
  if v == nil then return "--" end
  return string.format("%." .. dez .. "f", v)
end

-- Farbe einer überwachten Anzeige nach Stufe: gut grün, erste Schwelle orange, Alarm rot; ohne Überwachung «sonst»
local function stufenFarbe(st, sonst)
  if st == 2 then return C.rot end
  if st == 1 then return C.orange end
  if st == 0 then return C.gruen end
  return sonst
end

-- Kachel mit Tacho: Bogen über 270°, unten bleiben 90° offen (von links unten über oben nach rechts unten)
local function ringKachel(x, y, b, h, s, titel, akzent, wert, einheit, anteil, farbe, unten, untenFarbe, alarm)
  kachel(x, y, b, h, s, alarm and C.rot or nil)
  lcd.color(alarm and C.rot or akzent)
  lcd.drawFilledRectangle(floor(x + 8 * s), floor(y), floor(b - 16 * s), max(2, floor(2 * s)))
  text(x + b / 2, y + 17 * s, titel, 2, alarm and C.rot or C.titel, CENTERED, false, b - 12 * s)
  local cx, cy, ra, ri = x + b / 2, y + 104 * s, 66 * s, 54 * s
  bogen(cx, cy, ri, ra, 225, 495, C.spur)
  if anteil and anteil > 0 then
    anteil = min(1, anteil)
    bogen(cx, cy, ri, ra, 225, 225 + anteil * 270, farbe)
  end
  local hw = text(cx, cy - 7 * s, wert, s < 0.5 and 5 or 6, alarm and C.rot or C.weiss, CENTERED, true, 2 * ri - 10 * s)   -- kleine Ringe: eine Stufe kleiner
  if s >= 0.5 or #einheit <= 3 then                       -- kleine Ringe: lange Einheiten weglassen (Titel sagt es)
    text(cx, cy - 7 * s + hw / 2 + SCHRIFT[1][2] / 2 + 2, einheit, 1, C.titel, CENTERED, true, 2 * ri - 10 * s)   -- direkt unter dem Wert
  end
  if unten then text(x + b / 2, y + h - 17 * s, unten, 2, untenFarbe, CENTERED, true, b - 12 * s) end
end

-- Kleine Kachel: Titel oben links, Wert gross rechts, Zusatz klein rechts unten
local function wertKachel(x, y, b, h, s, titel, wert, zusatz, farbe, akzent, alarm)
  kachel(x, y, b, h, s, alarm and C.rot or nil)
  if alarm then farbe, akzent = C.rot, C.rot end
  lcd.color(akzent or C.akzent)
  lcd.drawFilledRectangle(floor(x), floor(y + 6 * s), max(2, floor(4 * s)), floor(h - 12 * s))
  text(x + 16 * s, y + 18 * s, titel, 2, C.titel, LEFT, false, b - 24 * s)
  text(x + b - 12 * s, y + h * (zusatz and 0.53 or 0.59), wert, 6, farbe or C.weiss, RIGHT, true, b - 28 * s)
  if zusatz then text(x + b - 12 * s, y + h - 16 * s, zusatz, 2, C.titel, RIGHT, false, b - 28 * s) end
end

-- Pille SCHARF (grün) / SICHER (grau), rechtsbündig bis x; gibt die Breite zurück
local function pille(x, ym, s, scharf, T)
  if scharf == nil then return 0 end
  local t = scharf and T.scharf or T.sicher
  lcd.font(SCHRIFT[2][1])
  local tb = lcd.getTextSize(t)
  local b, h = tb + 22 * s, 24 * s
  rund(x - b, ym - h / 2, b, h, h / 2, scharf and C.gruen or C.grau)
  text(x - b / 2, ym, t, 2, C.bg, CENTERED, true, b - 8 * s)
  return b
end

-- Governor-Zustand als Text und Farbe: aktiv grün, Übergänge orange, «Drehzahl verloren» rot, aus/Leerlauf grau
local GOV_FARBE = { [0] = "grau", "grau", "orange", "orange", "gruen", "hblau", "rot", "hblau", "orange", "orange" }
local function govText(gov, T)
  if gov == nil then return "--", C.grau end
  local n = T.govN[gov]
  if n == nil then return tostring(gov), C.weiss end
  return n, C[GOV_FARBE[gov]] or C.weiss
end

local function kopf(w, W, s, T)
  local v = w.v
  local hk = 56 * s
  if v.warn and floor(os.clock() * 2) % 2 == 0 then
    lcd.color(C.rot)
    lcd.drawFilledRectangle(0, 0, W, floor(hk))
  end
  local sz = w.sHinweis or w.sFest                     -- Studio-Hinweis steht anstelle des Modellnamens (verdeckt keine Werte)
  if sz then
    text(14 * s, hk / 2, sz, 3, C.orange, LEFT, true, W / 2 - 90 * s)
  else
    local ok, name = pcall(model.name)
    text(14 * s, hk / 2, (ok and type(name) == "string") and name or "", 6, C.weiss, LEFT, true, 300 * s)
  end
  local okd, zeit = pcall(os.date, "%H:%M")
  if okd and type(zeit) == "string" then text(W / 2, hk / 2, zeit, 6, C.weiss, CENTERED, false, 150 * s) end

  -- rechts: Senderakku, Empfangsbalken, Profil / Rate
  local x = W - 14 * s
  if w.sAusruf and not (w.sHinweis or w.sFest) then x = x - 22 end   -- Platz für das «!» der Studio-Datei oben rechts
  local bb, bh = 26 * s, 34 * s
  local lo, hi = 6.4, 8.4
  if system.voltageRange then
    local okr, a, b = pcall(system.voltageRange)
    if okr and gut(a) and gut(b) and b > a then lo, hi = a, b end
  end
  local voll = v.sender and max(0, min(1, (v.sender - lo) / (hi - lo))) or 0
  local fa = voll > 0.25 and C.gruen or C.rot
  rund(x - bb, hk / 2 - bh / 2 + 3 * s, bb, bh - 3 * s, 3 * s, fa)
  rund(x - bb + 2 * s, hk / 2 - bh / 2 + 5 * s, bb - 4 * s, bh - 7 * s, 2 * s, C.bg)
  lcd.color(fa)
  lcd.drawFilledRectangle(floor(x - bb / 2 - 5 * s), floor(hk / 2 - bh / 2), floor(10 * s), floor(4 * s))
  local fh = (bh - 11 * s) * voll
  if fh >= 1 then lcd.drawFilledRectangle(floor(x - bb + 4 * s), floor(hk / 2 + bh / 2 - 4 * s - fh), floor(bb - 8 * s), floor(fh)) end
  x = x - bb - 12 * s

  local stufen = 0
  if v.rssi then
    local r = v.rssi
    if r < 0 then r = r + 120 end                      -- dBm (negativ) auf 0 … 100 bringen
    stufen = (r >= 75 and 4) or (r >= 55 and 3) or (r >= 40 and 2) or (r > 0 and 1) or 0
  end
  for i = 4, 1, -1 do
    local h = (6 + 5 * i) * s
    lcd.color(i <= stufen and C.gruen or C.linie)
    lcd.drawFilledRectangle(floor(x - 7 * s), floor(hk / 2 + 13 * s - h), floor(6 * s), floor(h))
    x = x - 9 * s
  end
  x = x - 8 * s

  if v.pid or v.rate then
    local t = T.profil .. " " .. fz(v.pid, 0) .. " / " .. T.rate .. " " .. fz(v.rate, 0)
    text(x, hk / 2, t, 3, C.weiss, RIGHT, true, 200 * s)
  end
  lcd.color(C.linie)
  lcd.drawFilledRectangle(0, floor(hk), W, max(1, floor(2 * s)))
end

-- Felder zum Antippen: beim Zeichnen gemerkt (Tabellen werden wiederverwendet)
local ZW = nil
local function ziel(x, y, b, h, id, arg)
  local w = ZW
  if w == nil then return end
  local n = w.nZiele + 1
  w.nZiele = n
  local z = w.ziele[n]
  if z == nil then
    z = {}
    w.ziele[n] = z
  end
  z[1], z[2], z[3], z[4], z[5], z[6] = x, y, b, h, id, arg
end

-- Rückfragen: Frage deutsch/englisch, Ja deutsch/englisch, Nein deutsch/englisch
local DIALOG = {
  flug = { "Flug beendet?", "Flight finished?", "JA, BEENDET", "YES, FINISHED", "NEIN, NUR PAUSE", "NO, JUST PAUSE" },
  mah = { "Verbrauch auf 0 mAh setzen?", "Reset used capacity to 0 mAh?", "JA, AUF 0", "YES, RESET", "NEIN", "NO" },
  liste = { "Alle Flüge aus der Liste löschen?", "Clear all flights from the list?", "JA, LÖSCHEN", "YES, CLEAR", "NEIN", "NO" },
  loeschen = { "Flug %s löschen?", "Delete flight %s?", "JA, LÖSCHEN", "YES, DELETE", "NEIN", "NO" },
}

local function dialog(w, W, H, s)
  local d = DIALOG[w.dialog]
  if d == nil then
    w.dialog = nil
    return
  end
  local o = sprache(w.cfg) == 2 and 0 or 1
  lcd.color(lcd.RGB(0, 0, 0, 0.6))
  lcd.drawFilledRectangle(0, 0, W, H)
  -- auf kleinen Displays nicht schmaler als 400 und Knöpfe nicht niedriger als 32 Punkte (soweit Platz ist)
  local b, h = max(min(W - 20 * s, 470 * s), min(W - 16, 400)), max(200 * s, min(H - 16, 150))
  local x, y = (W - b) / 2, (H - h) / 2
  rund(x, y, b, h, 12 * s, C.hblau)
  rund(x + 2, y + 2, b - 4, h - 4, 11 * s, C.bg)
  local frage = d[1 + o]
  if w.dialog == "loeschen" then frage = string.format(frage, ganz(w.wahl)) end
  text(W / 2, y + 46 * s, frage, 5, C.weiss, CENTERED, true, b - 30 * s)
  local a = w.akt
  if w.dialog == "flug" and a then
    local sek = max(0, floor((a.dauer or 0) + 0.5))
    local zeile = (o == 0 and "Dieser Flug: " or "This flight: ") .. string.format("%d:%02d", floor(sek / 60), sek % 60)
    if a.mah then zeile = zeile .. ", " .. ganz(a.mah) .. " mAh" end
    text(W / 2, y + 86 * s, zeile, 3, C.grau, CENTERED, false, b - 30 * s)
  end
  local kb, kh = (b - 66 * s) / 2, max(46 * s, 32)
  local ky = y + h - kh - 22 * s
  ziel(0, 0, W, H, "dlgAussen")                         -- solange die Frage offen ist, wirkt sonst nichts
  rund(x + 22 * s, ky, kb, kh, 8 * s, C.grau)
  rund(x + 22 * s + 2, ky + 2, kb - 4, kh - 4, 7 * s, C.kachel)
  text(x + 22 * s + kb / 2, ky + kh / 2, d[5 + o], 3, C.titel, CENTERED, true, kb - 12 * s)
  ziel(x + 22 * s, ky, kb, kh, "dlgNein")
  rund(x + 44 * s + kb, ky, kb, kh, 8 * s, C.gruen)
  text(x + 44 * s + kb + kb / 2, ky + kh / 2, d[3 + o], 3, C.bg, CENTERED, true, kb - 12 * s)
  ziel(x + 44 * s + kb, ky, kb, kh, "dlgJa")
end

-- Die vier Ringe (Akku, Drehzahl, Strom, Reglertemperatur), gleich im Vollbild und in der Kompaktansicht
local function ringe(w, T, f, rd, lu, b4, y1, h1, s)
  local c, v = w.cfg, w.v
  local akku = (v.zellen and (ganz(v.zellen) .. "S ") or "") .. f(v.volt, 1, "V")
  local fa = stufenFarbe(v.st.proz, C.gelb)
  ringKachel(rd, y1, b4, h1, s, T.akku, fa, f(v.proz, 0), "%", v.proz and v.proz / 100,
    fa, akku, v.al.proz and C.rot or C.weiss, v.al.proz)
  ringKachel(rd + (b4 + lu), y1, b4, h1, s, T.rpm, C.hblau, f(v.rpm, 0), T.uRpm, v.rpm and v.rpm / c.rpmMax, C.hblau,
    T.max .. " " .. f(v.rpmHoch, 0), C.gelb)
  ringKachel(rd + 2 * (b4 + lu), y1, b4, h1, s, T.strom, C.blau, f(v.strom, 0), T.uA, v.strom and v.strom / c.aMax, C.blau,
    T.max .. " " .. f(v.stromHoch, 0, v.stromHoch and "A" or ""), C.gelb)
  fa = stufenFarbe(v.st.temp, C.hblau)
  ringKachel(rd + 3 * (b4 + lu), y1, b4, h1, s, T.temp, fa, f(v.temp, 0), "°C", v.temp and v.temp / c.tMax,
    fa, T.max .. " " .. f(v.tempHoch, 0, v.tempHoch and "°C" or ""), v.al.temp and C.rot or C.gelb, v.al.temp)
end

local function flugzeit(a)
  local sek = max(0, floor((a and a.dauer or 0) + 0.5))
  return string.format("%d:%02d", floor(sek / 60), sek % 60)
end

-- Kompaktansicht für das Layout mit Kopf- und Fussleiste (X18RS/X20: 784 × 316, X14: 630 × 258, X18: 472 × 210).
-- Modellname, Uhr und Senderakku zeigt dort Ethos. Oben eine schmale Leiste (Flugzeit, SCHARF/SICHER, Profil/Rate,
-- Empfang), darunter die vier Ringe und acht Felder.
local function kompaktLeiste(w, W, H, T)
  local v = w.v
  local k = min(W / 784, H / 316)
  local rd, lu = 6 * k, 4 * k
  local hs, y0 = 30 * k, 2 * k
  MASS = 0.72 * k
  kachel(rd, y0, W - 2 * rd, hs, k, v.warn and floor(os.clock() * 2) % 2 == 0 and C.rot or nil)
  local ym = y0 + hs / 2
  text(rd + 12 * k, ym, flugzeit(w.akt), 4, w.akt and not w.akt.pause and C.weiss or C.grau, LEFT, true, 90 * k)
  pille(rd + 220 * k, ym, k, v.scharf, T)                -- rechtsbündig, Platz für «SCHARF» / «ARMED»
  local sz = w.sHinweis or w.sFest                     -- Studio-Hinweis anstelle von Profil / Rate (verdeckt keine Werte)
  if sz then
    text(rd + 236 * k, ym, sz, 2, C.orange, LEFT, true, 300 * k)
  elseif v.pid or v.rate then
    text(rd + 236 * k, ym, T.profil .. " " .. fz(v.pid, 0) .. " / " .. T.rate .. " " .. fz(v.rate, 0), 2, C.weiss, LEFT, true, 240 * k)
  end
  local stufen = 0
  if v.rssi then
    local r = v.rssi
    if r < 0 then r = r + 120 end
    stufen = (r >= 75 and 4) or (r >= 55 and 3) or (r >= 40 and 2) or (r > 0 and 1) or 0
  end
  local xb = W - rd - 14 * k
  if w.sAusruf and not (w.sHinweis or w.sFest) then xb = xb - 22 end   -- Platz für das «!» der Studio-Datei oben rechts
  for i = 4, 1, -1 do
    local h = (4 + 4 * i) * k
    lcd.color(i <= stufen and C.gruen or C.linie)
    lcd.drawFilledRectangle(floor(xb - 5 * k), floor(ym + 10 * k - h), max(2, floor(5 * k)), floor(h))
    xb = xb - 8 * k
  end
  return k, rd, lu, hs, y0
end

local function kompakt(w, W, H, T, f)
  local v = w.v
  local k, rd, lu, hs, y0 = kompaktLeiste(w, W, H, T)

  local b4 = (W - 2 * rd - 3 * lu) / 4
  local y1, h1 = y0 + hs + lu, 148 * k
  MASS = h1 / 202
  ringe(w, T, f, rd, lu, b4, y1, h1, h1 / 202)

  local yf = y1 + h1 + lu
  local hf = (H - yf - 2 * k - lu) / 2
  local sf = hf / 98
  MASS = sf
  local function feld(sp, ze, titel, wert, zusatz, farbe, akzent, alarm)
    local fx, fy = rd + sp * (b4 + lu), yf + ze * (hf + lu)
    wertKachel(fx, fy, b4, hf, sf, titel, wert, zusatz, farbe, akzent, alarm)
    return fx, fy
  end
  local gName, gFarbe = govText(v.gov, T)
  feld(0, 0, T.gov, gName, v.gov and (T.kopfRpm .. " " .. f(v.rpm, 0)) or T.nurRf, gFarbe, gFarbe, v.gov == 6)
  if v.zellenFehlt then
    feld(1, 0, T.zelle, T.zEin, T.zEin2, C.orange, C.orange)
  else
    feld(1, 0, T.zelle, f(v.zelle, 2, "V"), v.zelleTief and (T.tief .. " " .. f(v.zelleTief, 2, "V")) or nil,
      stufenFarbe(v.st.zelle, nil), nil, v.al.zelle)
  end
  local mx, my = feld(2, 0, T.mah, f(v.mah, 0, " mAh"), T.nullen, stufenFarbe(v.st.mah, nil), nil, v.al.mah)
  ziel(mx, my, b4, hf, "mah")
  feld(3, 0, T.bec, f(v.bec, 1, "V"), v.becTief and (T.tief .. " " .. f(v.becTief, 1, "V")) or nil,
    stufenFarbe(v.st.bec, nil), nil, v.al.bec)
  feld(0, 1, T.modus, v.modus or "--", nil, C.gruen, C.gruen)
  feld(1, 1, T.empfang, v.rssi and f(v.rssi, 0, " dB") or "--", nil, nil, nil)
  feld(2, 1, T.leistung, (v.volt and v.strom) and f(v.volt * v.strom, 0, " W") or "--", nil, nil, nil)
  local fx, fy = feld(3, 1, T.fluegeK, ganz(w.fluege), w.akt and (w.akt.pause and T.pause or T.laeuft) or nil, nil, nil)
  ziel(fx, fy, b4, hf, "seite2")
  if v.ansage then
    lcd.color(C.hblau)
    lcd.drawFilledCircle(floor(fx + 24 * sf), floor(fy + hf - 16 * sf), floor(5 * sf))
  end
end

local FL = nil                                          -- Seite 2 (fluege.lua), nur geladen, solange sie offen ist
local HILFEN = { text = text, kachel = kachel, rund = rund, ganz = ganz, ziel = ziel }

-- Text in einer gewünschten Pixelhöhe (grösste Schrift, die nicht höher ist), für die Plätze der Studio-Datei
local function textPx(x, ym, t, px, farbe, ausr, fett, breit)
  local gr = 1
  for i = 7, 1, -1 do
    if SCHRIFT[i][2] <= px then gr = i break end
  end
  local m = MASS
  MASS = 100                                            -- Schriftwahl hier nicht nach dem Massstab verkleinern
  local h = text(x, ym, tostring(t), gr, farbe, ausr, fett, breit)
  MASS = m
  return h
end

-- Studio-Hinweis: ein Band unten, 24 Pixel hoch, dunkel, über den Plätzen; danach «!» oben rechts
local function studioBand(w, W, H, oben)
  if not w.sAusruf then return end
  if w.sHinweis or w.sFest then
    return                                              -- Text steht in der eigenen Kopfzeile (kopf / kompaktLeiste)
  else
    local r = 9
    lcd.color(C.orange)
    lcd.drawFilledCircle(W - r - 3, floor(oben), r)
    textPx(W - r - 3, oben, "!", 17, C.bg, CENTERED, true)
  end
end

-- Plätze der Studio-Ansicht zeichnen (ansicht.lua nur laden, solange eine Ansicht passt)
local function studioAnsicht(w, A, T, f, s)
  if ANSICHT == nil then
    local dat, e = loadfile("ansicht.lua")
    if not dat then error(e, 0) end
    ANSICHT = dat()
  end
  ZS = ZS or { govText = govText }
  ZS.C, ZS.T, ZS.sp, ZS.SCHRIFT, ZS.WERTE = C, T, sprache(w.cfg), SCHRIFT, w.studio.WERTE
  ANSICHT.zeichne(w, ZS, A, s, ziel)
end

local function zeichnen(w)
  if C == nil then farben() end
  if SCHRIFT == nil then schriften() end
  local W, H = lcd.getWindowSize()
  local s = min(W / 800, H / 480)
  MASS = s
  local c, v = w.cfg, w.v
  local T = TEXT[sprache(c)]
  local fe = w.fenster or {}                            -- Fenstergrössen für die Info-Datei (Lua-Studio-Format v1)
  w.fenster = fe
  local wh = W .. "x" .. H
  if wh ~= w.fensterJetzt then
    w.fensterJetzt = wh
    local neu = true
    for _, x in ipairs(fe) do if x[1] == W and x[2] == H then neu = false end end
    if neu and #fe < 8 then fe[#fe + 1] = { W, H } w.infoOffen = true end
  end
  -- Zu kleines Feld (z. B. Zone im Layout 2×2): nur ein Hinweis, kein abgeschnittenes Bild, keine Tippziele.
  -- Vollbild hat Höhe/Breite ≥ 0,56, das Layout mit Leisten ≤ 0,44 (gemessen 20.11.2026): darunter die Kompaktansicht.
  local klein = H < W * 0.5
  if W < 440 or H < (klein and 190 or 250) then
    ZW, w.nZiele = w, 0
    lcd.color(C.bg)
    lcd.drawFilledRectangle(0, 0, W, H)
    lcd.color(C.weiss)
    lcd.font(FONT_S or FONT_STD)
    lcd.drawText(W / 2, H / 2 - 8, T.klein, TEXT_CENTER)
    return
  end
  local komma = sprache(c) == 2
  local function f(x, dez, einheit)
    if x == nil then return "--" end
    local t = fz(x, dez)
    if komma then t = t:gsub("%.", ",") end
    return t .. (einheit or "")
  end

  lcd.color(C.bg)
  lcd.drawFilledRectangle(0, 0, W, H)
  ZW, w.nZiele = w, 0
  -- Ansicht der Studio-Datei für genau diese Fenstergrösse (ersetzt Seite 1 bzw. die Kompaktansicht unter der Leiste)
  local A = w.studio and w.seite ~= 2 and ansichtFuer(w, wh)
  if klein and w.seite ~= 2 then
    if A then
      local k = min(W / 784, H / 316)
      studioAnsicht(w, A, T, f, k)
      lcd.color(C.bg)
      lcd.drawFilledRectangle(0, 0, W, floor(34 * k))
      kompaktLeiste(w, W, H, T)                       -- eigene Leiste liegt über den Plätzen (reserviert)
      studioBand(w, W, H, 17 * k)
    else
      kompakt(w, W, H, T, f)
      if w.sAusruf then studioBand(w, W, H, 17 * min(W / 784, H / 316)) end
    end
    if w.dialog then
      MASS = s
      dialog(w, W, H, s)
    end
    return
  end
  if not A then kopf(w, W, s, T) end
  if A then
    studioAnsicht(w, A, T, f, s)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(0, 0, W, floor(58 * s))
    kopf(w, W, s, T)                                    -- eigene Kopfzeile liegt über den Plätzen (reserviert)
    studioBand(w, W, H, 28 * s)
    MASS = s
    if w.dialog then dialog(w, W, H, s) end
    return
  end

  if w.seite == 2 then
    if FL == nil then
      local dat, fehler = loadfile("fluege.lua")
      if not dat then
        w.seite = 1                                     -- Seite 2 fehlt: bei der Anzeige bleiben und melden
        error(fehler, 0)
      end
      FL = dat()
    end
    HILFEN.C, HILFEN.deutsch = C, sprache(c) == 2
    FL.zeichne(w, W, H, s, HILFEN)
    if w.sAusruf then studioBand(w, W, H, 28 * s) end
    if w.dialog then dialog(w, W, H, s) end
    return
  end

  -- oben: vier Ringe
  local rd, lu = 10 * s, 6 * s
  local b4 = (W - 2 * rd - 3 * lu) / 4
  local y1, h1 = 63 * s, 202 * s
  ringe(w, T, f, rd, lu, b4, y1, h1, s)

  -- unten links: Governor-Zustand (Flybarless-System) mit SCHARF/SICHER, darunter der Flugzähler
  local y2 = y1 + h1 + lu
  local h2 = H - y2 - 6 * s
  local bl = 2 * b4 + lu
  local hf = 40 * s
  local gName, gFarbe = govText(v.gov, T)
  wertKachel(rd, y2, bl, h2 - hf - lu, s, T.gov, gName, v.gov and (T.kopfRpm .. " " .. f(v.rpm, 0, " " .. T.uRpm)) or T.nurRf,
    gFarbe, gFarbe, v.gov == 6)
  pille(rd + bl - 12 * s, y2 + 18 * s, s, v.scharf, T)
  kachel(rd, y2 + h2 - hf, bl, hf, s)
  text(rd + bl / 2, y2 + h2 - hf / 2, ganz(w.fluege) .. " " .. (w.fluege == 1 and T.flug or T.fluege), 2, C.weiss, CENTERED, true, bl - 70 * s)
  if v.ansage then
    lcd.color(C.hblau)
    lcd.drawFilledCircle(floor(rd + 22 * s), floor(y2 + h2 - hf / 2), floor(7 * s))
  end

  -- unten rechts: vier Werte
  local xr = rd + 2 * (b4 + lu)
  local hk = (h2 - lu) / 2
  wertKachel(xr, y2, b4, hk, s, T.modus, v.modus or "--", nil, C.gruen, C.gruen)
  wertKachel(xr + b4 + lu, y2, b4, hk, s, T.bec, f(v.bec, 1, "V"), v.becTief and (T.tief .. " " .. f(v.becTief, 1, "V")) or nil,
    stufenFarbe(v.st.bec, nil), nil, v.al.bec)
  if v.zellenFehlt then                                       -- nur Gesamtspannung, Zellenzahl fehlt: gut sichtbar melden
    wertKachel(xr, y2 + hk + lu, b4, hk, s, T.zelle, T.zEin, nil, C.orange, C.orange)
    text(xr + b4 - 12 * s, y2 + hk + lu + hk - 16 * s, T.zEin2, 2, C.orange, RIGHT, true, b4 - 28 * s)
  else
    wertKachel(xr, y2 + hk + lu, b4, hk, s, T.zelle, f(v.zelle, 2, "V"), v.zelleTief and (T.tief .. " " .. f(v.zelleTief, 2, "V")) or nil,
      stufenFarbe(v.st.zelle, nil), nil, v.al.zelle)
  end
  wertKachel(xr + b4 + lu, y2 + hk + lu, b4, hk, s, T.mah, f(v.mah, 0), "mAh", stufenFarbe(v.st.mah, nil), nil, v.al.mah)
  do                                                          -- Knopf «Verbrauch zurücksetzen» (das ganze Feld wirkt)
    local kx, kb, kh = xr + b4 + lu + 12 * s, 78 * s, 24 * s
    local ky = y2 + hk + lu + hk - kh - 7 * s
    rund(kx, ky, kb, kh, 6 * s, C.grau)
    rund(kx + 1, ky + 1, kb - 2, kh - 2, 5 * s, C.kachel)
    text(kx + kb / 2, ky + kh / 2, T.nullen, 1, C.titel, CENTERED, true, kb - 6 * s)
  end
  ziel(xr + b4 + lu, y2 + hk + lu, b4, hk, "mah")           -- antippen: Verbrauch zurücksetzen
  ziel(rd, y2, bl, h2, "seite2")                              -- antippen: Flugliste
  if w.sAusruf then studioBand(w, W, H, 28 * s) end
  if w.dialog then dialog(w, W, H, s) end
end

-- ZW (Tippziele) zeigt nur während des Zeichnens auf das Widget. Danach loslassen: sonst hält der Kern das zuletzt
-- gezeichnete Widget fest, Ethos kann es nach einem Modellwechsel nicht verwerfen und der Speicher bleibt belegt (21.11.2026).
function K.zeichne(w)
  local ok, e = pcall(zeichnen, w)
  ZW = nil
  if not ok then error(e, 0) end
end

-- ---------------------------------------------------------------- Antippen und Wischen

local function treffer(w, x, y)
  for i = w.nZiele, 1, -1 do
    local z = w.ziele[i]
    if x >= z[1] and x <= z[1] + z[3] and y >= z[2] and y <= z[2] + z[4] then return z[5], z[6] end
  end
  return nil
end

local function seite(w, n)
  w.seite, w.wahl, w.ab = n, nil, 0
  if n == 1 and FL then
    FL = nil
    collectgarbage()
  end
  w.tB = 0
  lcd.invalidate()
end

-- Einen einzelnen Flug löschen (z. B. ein kurzes Ein und Aus, das nicht zählen soll). Der Flugzähler geht um eins
-- zurück und die späteren Flüge rücken nach, damit die Nummern lückenlos bleiben.
local function flugLoeschen(w, nr)
  nr = gut(nr)
  if nr == nil then return end
  local weg = false
  if w.akt and w.akt.nr == nr then
    w.akt, w.tStill, weg = nil, nil, true
    w.flugSperre = true                                -- ohne Motorschalter: erst nach Rotorstillstand wieder zählen
  else
    for i, r in ipairs(w.liste) do
      if r[1] == nr then
        table.remove(w.liste, i)
        weg = true
        break
      end
    end
  end
  w.wahl = nil
  if not weg then return end
  w.fluege = max(0, w.fluege - 1)
  for _, r in ipairs(w.liste) do
    if r[1] and r[1] > nr then r[1] = r[1] - 1 end
  end
  if w.akt and w.akt.nr and w.akt.nr > nr then w.akt.nr = w.akt.nr - 1 end
  schreibeDaten(w)
end

local function aktion(w, id, arg)
  if w.dialog then
    -- offene Rückfrage: nur ihre zwei Knöpfe wirken
    if id == "dlgJa" then
      local d = w.dialog
      w.dialog = nil
      if d == "flug" then
        flugEnde(w)
      elseif d == "mah" then
        nullen(w)
      elseif d == "loeschen" then
        flugLoeschen(w, w.wahl)
      elseif d == "liste" then
        w.liste, w.wahl = {}, nil
        schreibeDaten(w)
      end
    elseif id == "dlgNein" then
      w.dialog = nil                                   -- beim Flug: bleibt pausiert
    end
  elseif id == "mah" then
    w.dialog = "mah"
  elseif id == "loeschen" then
    if w.wahl then w.dialog = "loeschen" end
  elseif id == "liste" then
    w.dialog = "liste"
  elseif id == "seite2" then
    seite(w, 2)
  elseif id == "seite1" then
    seite(w, 1)
  elseif id == "flug" then
    w.wahl = arg
    if w.akt and w.akt.pause and w.akt.nr == arg then w.dialog = "flug" end   -- pausierten Flug antippen: nochmals fragen
  elseif id == "abwahl" then
    w.wahl = nil
  end
  w.tB = 0
  lcd.invalidate()
  return true
end

-- Kurzes Tippen wirkt auf das Feld darunter. Wischen zur anderen eigenen Seite (Anzeige ↔ Flüge) gehört dem Widget,
-- jedes andere Wischen und langes Drücken bleiben bei Ethos.
-- Drehrad: auf der Anzeige öffnet eine Drehung nach rechts die Flugliste; dort wählt Drehen den Flug (rechts = weiter
-- nach unten, links = nach oben), links über den obersten Flug hinaus geht es zurück zur Anzeige. Links auf der Anzeige
-- tut nichts (sonst sprang das Bild beim Linksdrehen bei jeder Raste zwischen den Seiten). Das Widget übernimmt jede
-- Drehung: Gibt es sie an Ethos weiter, kommt keine weitere Drehung mehr an (Simulator 26.1.2, 18.11.2026). Alle
-- anderen Tasten bleiben bei Ethos. Einen pausierten Flug fragt das Drehrad nicht nach (nur Antippen).
local function drehen(w, rechts)
  if w.dialog then return true end                       -- offene Rückfrage: Drehen ändert nichts
  if w.seite ~= 2 then
    if rechts then seite(w, 2) end
    return true
  end
  local nr = {}
  if w.akt and w.akt.nr then nr[#nr + 1] = w.akt.nr end  -- gleiche Reihenfolge wie die Liste in fluege.lua
  for i = #w.liste, 1, -1 do nr[#nr + 1] = w.liste[i][1] end
  local i = 1
  for k = 1, #nr do
    if w.wahl and nr[k] == w.wahl then i = k end
  end
  if rechts then
    i = min(#nr, i + 1)
  elseif i <= 1 then
    seite(w, 1)
    return true
  else
    i = i - 1
  end
  w.wahl = nr[i]
  local platz = w.platz or 1                              -- gewählte Zeile sichtbar halten
  local ab = w.ab or 0
  if i <= ab then ab = i - 1 elseif i > ab + platz then ab = i - platz end
  w.ab = max(0, ab)
  w.tB = 0
  lcd.invalidate()
  return true
end

function K.ereignis(w, kat, wert, x, y)
  if EVT_KEY and kat == EVT_KEY then
    if KEY_ROTARY_RIGHT and wert == KEY_ROTARY_RIGHT then return drehen(w, true) end
    if KEY_ROTARY_LEFT and wert == KEY_ROTARY_LEFT then return drehen(w, false) end
    return false
  end
  if not (EVT_TOUCH and kat == EVT_TOUCH) then return false end
  x, y = gut(x), gut(y)
  local t = w.tipp
  -- Am echten Sender kann ein Ereignis ohne Fingerposition kommen (v. a. beim Loslassen). Dann gilt die letzte
  -- bekannte Position; ohne sie würde ein angefangener Wisch nie fertig und die Anzeige wirkte eingefroren.
  if (x == nil or y == nil) and t then x, y = t.lx or t.x, t.ly or t.y end
  if x == nil or y == nil then
    if wert == TOUCH_END then w.tipp = nil end
    return false
  end
  if wert == TOUCH_START then
    w.tipp = { x = x, y = y, lx = x, ly = y, t0 = os.clock(), fest = true }
    return false
  elseif wert == TOUCH_MOVE and t then
    t.lx, t.ly = x, y
    local dx, dy = x - t.x, y - t.y
    if math.abs(dx) > 20 or math.abs(dy) > 20 then t.fest = false end
    if w.dialog then return true end                    -- offene Rückfrage: kein Wischen
    if w.seite == 2 and not t.mein and not t.ethos and math.abs(dy) > 20 and math.abs(dy) > math.abs(dx) then
      t.mein, t.rollen = true, true                     -- auf und ab in der Flugliste
    end
    t.dy = dy
    if not t.mein and not t.ethos and math.abs(dx) > 20 and math.abs(dx) > math.abs(dy) then
      if (dx < 0 and w.seite == 1) or (dx > 0 and w.seite == 2) then t.mein = true else t.ethos = true end
    end
    t.dx = dx
    -- Seite schon während des Wischens wechseln, nicht erst beim Loslassen: wirkt auch, wenn das Loslassen
    -- am Sender nicht ankommt, und man sieht sofort, dass der Wisch erkannt ist.
    if t.mein and not t.rollen and not t.gewechselt and math.abs(dx) >= 50 then
      t.gewechselt = true
      seite(w, w.seite == 1 and 2 or 1)
    end
    return t.mein == true
  elseif wert == TOUCH_END and t then
    w.tipp = nil
    if t.rollen then
      local zh = w.zeilenH or 30
      w.ab = max(0, (w.ab or 0) + floor(-(t.dy or 0) / zh + 0.5))      -- fluege.lua begrenzt nach oben
      w.tB = 0
      lcd.invalidate()
      return true
    end
    if t.mein then
      if not t.gewechselt and math.abs(t.dx or 0) >= 50 then seite(w, w.seite == 1 and 2 or 1) end
      return true
    end
    if t.fest and os.clock() - t.t0 < 0.7 then
      local id, arg = treffer(w, x, y)
      if id and id == treffer(w, t.x, t.y) then return aktion(w, id, arg) end
    end
  end
  return false
end

-- ---------------------------------------------------------------- Einstellungen (Widget konfigurieren)

function K.menue(w)
  local c = w.cfg
  local de = sprache(c) == 2
  local function tr(deutsch, englisch) return de and deutsch or englisch end
  local UMIN = tr(" U/min", " RPM")
  local function fertig()
    begrenze(c)
    if w.studio then                                  -- mit Studio-Datei gehen Änderungen nach .funke.lua
      lauf().menueSync(w)
      w.funkeOffen = true
    end
    if model and model.dirty then pcall(model.dirty) end
  end
  -- Sensorfeld. Bei einem FrSky-Sensor stehen AppID und Physical ID im Titel, damit gleichnamige Sensoren
  -- unterscheidbar sind. Passten bei der Suche mehrere Sensoren, folgt eine Hinweiszeile.
  local function quelle(panel, name, titel)
    local q, zusatz = c[name], ""
    if q ~= nil then
      local okA, a = pcall(q.appId, q)
      local okP, ph = pcall(q.physId, q)
      if okA and type(a) == "number" and a > 0 and a < 0x10000 then
        a = floor(a)
        zusatz = string.format(" [%04X", a) .. ((okP and type(ph) == "number" and ph >= 0 and ph < 0x100)
          and string.format("/%02X]", floor(ph)) or "]")
      end
    end
    form.addSourceField(form.addLine(titel .. zusatz, panel), nil, function() return c[name] end, function(x)
      c[name] = istQuelle(x) and x or nil
      if w.hinweise then w.hinweise[name] = nil end
      fertig()
    end)
    local h = w.hinweise and w.hinweise[name]
    if h and q ~= nil then
      form.addStaticText(form.addLine(tr("  Hinweis", "  Note"), panel), nil,
        string.format(tr("%d Sensoren passen, gewählt: %s – bitte prüfen", "%d sensors match, chosen: %s – please check"), h[1], h[2]))
    end
  end
  local function nummer(panel, name, titel, einheit, schritt, dez)
    local z
    for _, e in ipairs(ZAHLEN) do if e[1] == name then z = e end end
    local fe = form.addNumberField(form.addLine(titel, panel), nil, z[3], z[4], function() return c[name] end, function(x)
      c[name] = x
      fertig()
    end)
    if fe then
      if einheit then pcall(fe.suffix, fe, einheit) end
      if schritt then pcall(fe.step, fe, schritt) end
      if dez then pcall(fe.decimals, fe, dez) end
      local werk = z[2]                                -- Zellen-Alarm: Werkswert des eingestellten Akkutyps
      if name == "aZelleOrange" then werk = (ZELLE_WERK[c.akkutyp] or ZELLE_WERK[1])[1] end
      if name == "aZelleGrenze" then werk = (ZELLE_WERK[c.akkutyp] or ZELLE_WERK[1])[2] end
      pcall(fe.default, fe, werk)
    end
  end
  local function schalter(panel, name, titel)
    form.addBooleanField(form.addLine(titel, panel), nil, function() return c[name] == 1 end, function(x)
      c[name] = x and 1 or 0
      fertig()
    end)
  end
  local function gruppe(titel)
    local p = form.addExpansionPanel(titel)
    pcall(p.open, p, false)
    return p
  end
  -- Rückfrage im Menü (für Sender ohne Berührung). Ethos wählt den letzten Knopf vor: ABBRECHEN steht zuletzt.
  local function frage(titel, text, ja, tun)
    if not form.openDialog then return end           -- ohne Rückfrage wird nichts gelöscht oder beendet
    pcall(form.openDialog, {
      title = titel, message = text,
      buttons = {
        { label = ja, action = function() pcall(tun) w.tB = 0 return true end },
        { label = tr("ABBRECHEN", "CANCEL"), action = function() return true end },
      },
      wakeup = function() end, paint = function() end, options = TEXT_LEFT,
    })
  end
  local function quellenName(name)
    for _, f in ipairs(QUELLEN) do
      if f[1] == name then return tr(f[2], f[3]) end
    end
    return name
  end

  local kopfzeile = form.addLine(tr("Sensoren automatisch suchen", "Find sensors automatically"))
  form.addButton(kopfzeile, nil, { text = tr("Suchen", "Search"), press = function()
    local ok, e = pcall(sucheStart, w)
    if not ok then print("Heli: Suche: Fehler " .. tostring(e)) return end
    -- Die Suche läuft in Schritten; der Dialog treibt sie an (auch der Weckruf des Widgets) und schliesst sich am Ende.
    if form.openDialog then
      local d
      local okD, dd = pcall(form.openDialog, {
        title = tr("Sensoren", "Sensors"), message = tr("Suche läuft …", "Searching …"),
        buttons = { { label = "OK", action = function() return true end } },
        wakeup = function()
          if w.sucheKen and not w.lauf then                -- zweiter Teil des Starts (1.11.0)
            if not pcall(sucheStart, w) then w.sucheKen = nil end
          elseif w.lauf then
            local okS, nS = pcall(sucheSchritt, w)
            if not okS or nS then print("Heli: Suche: " .. (okS and (tostring(nS) .. " neu zugewiesen") or ("Fehler " .. tostring(nS)))) end
          end
          if not w.lauf and d then pcall(d.close, d) d = nil end
        end,
        paint = function() end, options = TEXT_LEFT,
      })
      if okD then d = dd end
    end
  end })

  -- Studio-Datei (Lua-Studio-Format v1): Zustand und «Zurück auf Studio-Stand» (mit Datei) bzw. «Zurück auf Standard»
  local zs = w.studioZustand
  local zt = (zs == "geladen" and tr("geladen", "loaded")) or (zs == "kaputt" and tr("kaputt", "broken"))
    or (zs == "zuNeu" and tr("zu neu", "too new")) or tr("keine", "none")
  if zs == "geladen" and (w.studioFehler or 0) > 0 then zt = zt .. ", " .. string.format(tr("%s Fehler", "%s errors"), tostring(w.studioFehler)) end
  form.addButton(form.addLine(tr("Studio-Datei: ", "Studio file: ") .. zt), nil, { text = tr("Zurück", "Reset"), press = function()
    if w.studio then
      frage(tr("Zurück auf Studio-Stand?", "Back to Studio settings?"),
        tr("Deine Änderungen an der Funke werden gelöscht.", "Your changes on the radio are deleted."),
        tr("JA, ZURÜCK", "YES, RESET"), function()
          local M = studioLaden()
          M.funkeSchreiben(M.kennung(), nil)                                -- .funke.lua löschen, Studio-Datei neu lesen
          w.studio, w.studioFertig, w.studioJob, w.funkeOffen = nil, false, nil, false
          symFrei(w)
        end)
    else
      frage(tr("Zurück auf Standard?", "Back to defaults?"),
        tr("Einstellungen und Grenzwerte ab Werk; Sensoren und Flüge bleiben.", "Factory settings and limits; sensors and flights stay."),
        tr("JA, ZURÜCK", "YES, RESET"), function()
          for k, x in pairs(standard()) do c[k] = x end
          w.anker, w.prozRuhe = nil, nil
          fertig()
        end)
    end
  end })

  -- Studio-Layout: Liste nur hier beim Öffnen des Menüs bauen (alle *.heli.lua der Suchorte), 0 = automatisch
  local okM, MS = pcall(studioLaden)
  local wahl = { { tr("automatisch (Modellname)", "automatic (model name)"), 0 } }
  local da = (c.studio or 0) == 0
  if okM then
    local okD, l = pcall(MS.dateien)
    for _, e in ipairs(okD and l or {}) do
      wahl[#wahl + 1] = { e.name:sub(1, -(#MS.LUA + 6)) .. " (" .. tostring(e.ort) .. ")", e.z }
      if e.z == c.studio then da = true end
    end
  end
  if not da then wahl[#wahl + 1] = { tr("(Datei fehlt)", "(file missing)"), c.studio } end
  form.addChoiceField(form.addLine(tr("Studio-Layout", "Studio layout")), nil, wahl,
    function() return c.studio or 0 end, function(x)
      c.studio = x
      if w.cfgWidget then w.cfgWidget.studio = x end
      K.schreibe(w)
      if w.studio then studioWeg(w) end                 -- eigene Werte zurück, dann neu laden
      w.studioFertig, w.studioJob, w.funkeOffen, w.sFest, w.sAusruf = false, nil, false, nil, nil
    end)

  -- 1.14.4: Symbole der Studio-Ansicht an der Funke abschaltbar; gespeichert in der Datendatei (Widget-Speicher voll)
  form.addBooleanField(form.addLine(tr("Symbole anzeigen", "Show symbols")), nil, function() return w.symbole ~= false end,
    function(x) w.symbole = x schreibeDaten(w) end)

  local p = gruppe(tr("Sensoren", "Sensors"))
  for _, f in ipairs(QUELLEN) do
    if f[1] ~= "qGas" and f[1] ~= "qMotor" and f[1] ~= "qAkkuProfil" then quelle(p, f[1], tr(f[2], f[3])) end
  end

  p = gruppe(tr("Akku", "Battery"))
  nummer(p, "zellen", tr("Zellen (0 = automatisch)", "Cells (0 = automatic)"), " S")
  nummer(p, "kapaz", tr("Kapazität für %-Anzeige", "Capacity for % display"), " mAh", 50)
  form.addChoiceField(form.addLine(tr("Akkutyp", "Battery type"), p), nil,
    { { "LiPo", 1 }, { "LiHV", 2 }, { "Li-Ion", 3 } },
    function() return c.akkutyp end, function(x)
      akkutypSetzen(c, x)                                -- Werkswerte des Zellen-Alarms folgen dem Typ
      w.anker, w.prozRuhe = nil, nil                   -- Startwert mit der neuen Kennlinie neu bestimmen
      fertig()
    end)
  -- Woher die %-Anzeige kommt: ein Akku-%-Sensor mit Wert (z. B. vom Flybarless oder Regler) gilt immer zuerst, nur
  -- ohne ihn schätzt das Widget selbst (Ruhespannung nach Akkutyp, dann mAh). lesen() führt die Zeile laufend nach.
  w.tHerkunft = herkunftText(w)
  w.fHerkunft = form.addStaticText(form.addLine(tr("Akku % kommt von", "Battery % from"), p), nil, w.tHerkunft)
  form.addButton(form.addLine(tr("Verbrauch zurücksetzen", "Reset used capacity"), p), nil,
    { text = tr("Auf 0 mAh", "Set to 0 mAh"), press = function()
      frage(tr("Verbrauch", "Used capacity"), tr("Verbrauch auf 0 mAh setzen?", "Reset used capacity to 0 mAh?"),
        tr("JA, AUF 0", "YES, RESET"), function() nullen(w) end)
    end })

  p = gruppe(tr("Tachos: Endwert der Skala", "Gauges: full scale"))
  nummer(p, "rpmMax", tr("Drehzahl", "Head speed"), UMIN, 50)
  nummer(p, "aMax", tr("Strom", "Current"), " A", 5)
  nummer(p, "tMax", tr("Reglertemperatur", "ESC temperature"), " °C", 5)

  -- Alarme: je Gruppe Ein, erste Schwelle (orange), zweite Schwelle (rot mit Ton) und Wiederholzeit
  local function alarm(n, titel, vor, hoch, einheit, schritt, dez)
    local g = gruppe(titel)
    local richtung = hoch and tr("ab", "from") or tr("unter", "below")
    schalter(g, vor .. "Ein", tr("Ein", "On"))
    nummer(g, vor .. "Orange", "Orange " .. richtung, einheit, schritt, dez)
    nummer(g, vor .. "Grenze", tr("Rot + Ton ", "Red + sound ") .. richtung, einheit, schritt, dez)
    nummer(g, vor .. "Takt", tr("Wiederholen alle", "Repeat every"), " s")
    local bit = MAUS_BIT[n]
    form.addBooleanField(form.addLine(tr("Auch bei Motor aus", "Also with motor off"), g), nil,
      function() return (c.mAus // bit) % 2 == 1 end, function(x)
        local an = (c.mAus // bit) % 2 == 1
        if x and not an then c.mAus = c.mAus + bit elseif an and not x then c.mAus = c.mAus - bit end
        fertig()
      end)
  end
  alarm("temp", tr("Alarm Reglertemperatur", "Alarm ESC temperature"), "warn", true, " °C")
  alarm("proz", tr("Alarm Akku %", "Alarm battery %"), "aProz", false, " %")
  alarm("zelle", tr("Alarm Zellenspannung", "Alarm cell voltage"), "aZelle", false, " V", nil, 2)
  alarm("bec", tr("Alarm BEC-Spannung", "Alarm BEC voltage"), "aBec", false, " V", nil, 1)
  alarm("mah", tr("Alarm Verbrauch", "Alarm used capacity"), "aMah", true, " mAh", 50)

  p = gruppe(tr("Drehzahlansage", "RPM callout"))
  schalter(p, "rpmEin", tr("Ein", "On"))
  quelle(p, "qGas", quellenName("qGas"))
  nummer(p, "gasGrenze", tr("Ansagen bei Gas bis", "Throttle at or below"), " %")
  nummer(p, "rpmTakt", tr("Ansage alle", "Call out every"), " s")
  nummer(p, "rpmMin", tr("Nur über Drehzahl", "Only above"), UMIN, 50)

  p = gruppe(tr("Flug und Motorschalter", "Flight and motor switch"))
  quelle(p, "qMotor", quellenName("qMotor"))
  form.addChoiceField(form.addLine(tr("Stellung Motor aus", "Motor off position"), p), nil,
    { { tr("oben", "up"), 1 }, { tr("Mitte", "middle"), 2 }, { tr("unten", "down"), 3 } },
    function() return c.swAus end, function(x)
      c.swAus = x
      fertig()
    end)
  nummer(p, "autoSek", tr("Autorotation alle (0=aus)", "Autorotation every (0=off)"), " s")
  nummer(p, "flugSek", tr("Flug zählt ab Dauer", "Flight counts after"), " s")
  nummer(p, "flugRpm", tr("Ohne Schalter: ab", "Without switch: from"), UMIN, 50)

  -- Alles, was auf den Seiten nur per Berührung geht, gibt es hier als Knopf (X14, X10, X12 haben keine Berührung)
  p = gruppe(tr("Flüge ohne Berührung", "Flights without touch"))
  form.addChoiceField(form.addLine(tr("Seite", "Page"), p), nil, { { tr("Anzeige", "Display"), 1 }, { tr("Flüge", "Flights"), 2 } },
    function() return w.seite end, function(x) seite(w, x == 2 and 2 or 1) end)
  form.addNumberField(form.addLine(tr("Flug wählen (0=neuester)", "Select flight (0=latest)"), p), nil, 0, 99999,
    function() return gut(w.wahl) or 0 end, function(x)
      x = gut(x) or 0
      w.wahl = x > 0 and floor(x + 0.5) or nil
      w.tB = 0
    end)
  form.addButton(form.addLine(tr("Gewählten Flug löschen", "Delete selected flight"), p), nil, { text = tr("Löschen", "Delete"), press = function()
    -- 0 = oberste Zeile der Liste (laufender oder neuester Flug); eine Nummer, die es nicht gibt, löscht nichts
    local nr = w.wahl
    if nr == nil then
      nr = (w.akt and w.akt.nr) or (w.liste[#w.liste] and w.liste[#w.liste][1])
    end
    local da = w.akt and w.akt.nr == nr
    for _, r in ipairs(w.liste) do if r[1] == nr then da = true end end
    if not da then
      if form.openDialog then
        pcall(form.openDialog, { title = tr("Flugliste", "Flight list"),
          message = string.format(tr("Flug %s gibt es nicht.", "There is no flight %s."), ganz(nr or 0)),
          buttons = { { label = "OK", action = function() return true end } },
          wakeup = function() end, paint = function() end, options = TEXT_LEFT })
      end
      return
    end
    frage(tr("Flugliste", "Flight list"), string.format(tr("Flug %s löschen?", "Delete flight %s?"), ganz(nr)),
      tr("JA, LÖSCHEN", "YES, DELETE"), function() flugLoeschen(w, nr) end)
  end })
  form.addButton(form.addLine(tr("Laufenden Flug beenden", "Finish current flight"), p), nil, { text = tr("Beenden", "Finish"), press = function()
    if not (w.akt and w.akt.nr) then return end
    frage(tr("Flug", "Flight"), tr("Flug beendet?", "Flight finished?"), tr("JA, BEENDET", "YES, FINISHED"), function()
      flugEnde(w)
      w.flugSperre = true                             -- ohne Motorschalter: neuer Flug erst nach Rotorstillstand
    end)
  end })
  -- «Flug beendet?» auf der Seite ohne Berührung schliessen: der Flug bleibt pausiert (wie «NEIN, NUR PAUSE»)
  form.addButton(form.addLine(tr("Rückfrage: nur Pause", "Question: just pause"), p), nil, { text = tr("Nur Pause", "Just pause"), press = function()
    if w.dialog then
      w.dialog = nil
      w.tB = 0
    end
  end })
  form.addButton(form.addLine(tr("Flugliste löschen", "Clear flight list"), p), nil, { text = tr("Löschen", "Clear"), press = function()
    frage(tr("Flugliste", "Flight list"), tr("Alle Flüge aus der Liste löschen?", "Clear all flights from the list?"),
      tr("JA, LÖSCHEN", "YES, CLEAR"), function()
        w.liste, w.wahl = {}, nil
        schreibeDaten(w)
      end)
  end })

  p = gruppe(tr("Anzeige und Flugzähler", "Display and flight count"))
  form.addChoiceField(form.addLine("Sprache / Language", p), nil,
    { { tr("wie der Sender", "same as radio"), 0 }, { "Deutsch", 2 }, { "English", 1 } },
    function() return c.sprache end, function(x)
      c.sprache = x
      fertig()
    end)
  form.addNumberField(form.addLine(tr("Flugzähler", "Flight count"), p), nil, 0, 99999, function() return w.fluege end, function(x)
    w.fluege = max(0, floor((gut(x) or 0) + 0.5))
    w.tSchreib = os.clock() + 2                -- erst 2 s nach der letzten Änderung einmal schreiben
  end)
  form.addStaticText(form.addLine("Heli", p), nil, "Version " .. tostring(w.version or ""))
end

return K
