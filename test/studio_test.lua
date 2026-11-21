-- Heli: Studio-Datei laden (Lua-Studio-Format v1, Abschnitte 3, 4 und 12) auf dem Mac, Lua 5.4.
-- Aufruf aus dem Repo-Ordner:  /opt/homebrew/opt/lua@5.4/bin/lua test/studio_test.lua
--
--  1. studioLaden aus src/heli/studio.lua zwischen «-- ===== Referenz studioLaden» und «-- ===== Ende Referenz =====»
--     herauslösen und Zeile für Zeile mit der Referenz vergleichen (wörtlich). Fehlt studio.lua noch, läuft alles
--     Weitere mit der Referenzdatei selbst.
--  2. Alle Angriffs- und Grenzfalldateien (test/studio-messen/dateien, Kopien aus «Lua-Studio-Format v1 -
--     Testdateien») laden: Ergebnis wie im Format (geladen / kaputt / zuNeu), nie ein Absturz. Je Datei Befehle
--     (debug.sethook) und Speicher (Aufräumen aus, Spitze und bleibend) wie im Messskript des Formats.
--  3. Die Heli-Dateien aus test/studio (python3 test/studio_dateien.py) ebenso; voll.heli.lua unter 5000 Befehlen
--     und unter der Speicherspitze des Grenzfalls g16_lang24.
--  6. (1.10.1) Sender-Eigenheiten (getSources mit Tabelle leer, getSource mit appId ohne Wert): Studio-Sensoren,
--     Info-Datei, Rotorflight-Rückfall; Befehle im Betrieb mit 160 Grenzen und 100 Wert-Anpassungen; Alarm nie stumm.
--  4. Nur wenn studio.lua da ist: einfache Textprüfungen (Kennung nach 2.1, kein read("a"), Pfad SCRIPTS:/studio/,
--     remove vor rename) und, falls das Modul eine Funktion «kennung» hat, die Beispiele aus 2.1.
-- Umgebung: STUDIO_REF = andere Referenzdatei (Standard: Ordner Lua-Studio format).
local repo = arg[0]:gsub("test/studio_test%.lua$", "")
if repo == "" then repo = "./" end
local REF = os.getenv("STUDIO_REF") or ((os.getenv("FORMAT2_ORDNER") or error("Umgebungsvariable FORMAT2_ORDNER fehlt: Ordner mit den Unterlagen zum Lua-Studio-Format", 0))
  .. "/Lua-Studio-Format v1 - Referenz studio_laden.lua")
local STUDIO = repo .. "src/heli/studio.lua"

local fehlerZahl, hinweise = 0, 0
local function pruefe(ok, text)
  print((ok and "ok      " or "FEHLER  ") .. text)
  if not ok then fehlerZahl = fehlerZahl + 1 end
end
local function hinweis(text) print("HINWEIS " .. text) hinweise = hinweise + 1 end
local function lies(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local t = f:read("a")
  f:close()
  return t
end
local function zeilen(t)
  local l = {}
  for z in (t .. "\n"):gmatch("(.-)\r?\n") do l[#l + 1] = z end
  return l
end

-- ---------------------------------------------------------------- 1. Referenz und Auszug
local refText = lies(REF)
if not refText then print("FEHLER  Referenz fehlt: " .. REF) os.exit(2) end
-- Kern der Referenz: von «local MAX_BYTE» bis zum «end» der Funktion studioLaden
local refZ, kern = zeilen(refText), {}
do
  local an, inFunktion = false, false
  for _, z in ipairs(refZ) do
    if z:find("^local MAX_BYTE") then an = true end
    if an then
      kern[#kern + 1] = z
      if z:find("^local function studioLaden") then inFunktion = true end
      if inFunktion and z == "end" then break end
    end
  end
end
pruefe(#kern > 50 and kern[#kern] == "end", "Referenz gelesen: " .. #kern .. " Zeilen Kern")

local quelle, quellName
local studioText = lies(STUDIO)
if studioText then
  local z = zeilen(studioText)
  local von, bis
  for i, x in ipairs(z) do
    if not von and x:find("^%s*%-%- ===== Referenz studioLaden") then von = i end
    if von and not bis and i > von and x:find("^%s*%-%- ===== Ende Referenz =====") then bis = i end
  end
  pruefe(von and bis, "Marker in studio.lua gefunden (Zeilen " .. tostring(von) .. " bis " .. tostring(bis) .. ")")
  if von and bis then
    local aus = {}
    for i = von + 1, bis - 1 do aus[#aus + 1] = z[i] end
    -- der Kern muss als zusammenhängender Block wörtlich drinstehen, sonst nur Leer- und Kommentarzeilen
    local start
    for i, x in ipairs(aus) do if x == kern[1] then start = i break end end
    local abw
    if not start then
      abw = "erste Kernzeile «" .. kern[1] .. "» fehlt"
    else
      for j = 1, #kern do
        if aus[start + j - 1] ~= kern[j] then
          abw = string.format("studio.lua Zeile %d: «%s», Referenz: «%s»", von + start + j - 1,
            tostring(aus[start + j - 1]), kern[j])
          break
        end
      end
      for i, x in ipairs(aus) do
        if not abw and (i < start or i >= start + #kern) and not (x:find("^%s*$") or x:find("^%s*%-%-")) then
          abw = string.format("studio.lua Zeile %d: zusätzlicher Code im Referenzblock: «%s»", von + i, x)
        end
      end
    end
    pruefe(abw == nil, "studioLaden wörtlich wie die Referenz (" .. #kern .. " Zeilen)" .. (abw and (": " .. abw) or ""))
    quelle, quellName = table.concat(aus, "\n") .. "\nreturn studioLaden\n", "Auszug aus src/heli/studio.lua"
  end
else
  hinweis("src/heli/studio.lua fehlt noch: Auszug und Wortlaut nicht geprüft, Tests laufen mit der Referenz")
end
if not quelle then quelle, quellName = refText, "Referenzdatei" end
local chunk, e = load(quelle, "=studioLaden", "t", _ENV)
pruefe(chunk ~= nil, "studioLaden übersetzt (" .. quellName .. ")" .. (e and (": " .. e) or ""))
if not chunk then os.exit(1) end
local laden = chunk()
pruefe(type(laden) == "function", "studioLaden ist eine Funktion")

-- ---------------------------------------------------------------- Messen wie im Messskript des Formats
local function messe(pfad)
  local n = 0
  collectgarbage() collectgarbage("stop")
  local m0 = collectgarbage("count")
  debug.sethook(function() n = n + 1 end, "", 1)
  local ok, d, g = pcall(laden, pfad, 1)
  debug.sethook()
  local spitze = collectgarbage("count") - m0
  local erg = (not ok) and ("ABSTURZ " .. tostring(d)) or (d and "geladen" or g)
  d = nil
  collectgarbage("restart") collectgarbage()
  local bleibend = collectgarbage("count") - m0
  return erg, n, spitze, bleibend
end

local function liste(ordner, muster)
  local l = {}
  local p = io.popen('ls "' .. ordner .. '" 2>/dev/null')
  for n in p:read("a"):gmatch("[^\n]+") do if n:find(muster) then l[#l + 1] = n end end
  p:close()
  table.sort(l)
  return l
end

-- ---------------------------------------------------------------- 2. Angriffs- und Grenzfalldateien
local GELADEN = { g16_lang24 = true, g12_lang24 = true, typisch = true, g16_513 = true, g16_liste = true,
  g16_tab = true, g16_text = true }
local function erwartet(name)
  if GELADEN[name] then return "geladen" end
  if name == "format99" then return "zuNeu" end
  return "kaputt"
end
local ordner = repo .. "test/studio-messen/dateien/"
local maxN, spitzeG16 = 0, 0
local dateien = liste(ordner, "%.txt$")
pruefe(#dateien >= 31, #dateien .. " Angriffs- und Grenzfalldateien gefunden (31 im Format)")
print(string.format("\n%-34s %6s  %-8s %-8s %8s %10s %10s", "Datei", "Byte", "Ergebnis", "erwartet", "Befehle", "Spitze KB", "bleibt KB"))
local zeilenAus = {}
for _, n in ipairs(dateien) do
  local name = n:gsub("%.txt$", "")
  local erg, befehle, spitze, bleibend = messe(ordner .. n)
  local soll = erwartet(name)
  if befehle > maxN then maxN = befehle end
  if name == "g16_lang24" then spitzeG16 = spitze end
  local ok = erg == soll
  if not ok then fehlerZahl = fehlerZahl + 1 end
  print(string.format("%-34s %6d  %-8s %-8s %8d %10.1f %10.1f%s", name, #(lies(ordner .. n) or ""), erg, soll, befehle,
    spitze, bleibend, ok and "" or "   FEHLER"))
end
pruefe(maxN < 5000, "Angriffe: höchstens " .. maxN .. " Befehle in einem Aufruf (< 5000)")
-- fehlende Datei
local erg = messe(repo .. "test/studio/gibt_es_nicht.heli.lua")
pruefe(erg == "fehlt", "keine Datei: «fehlt» (" .. erg .. ")")

-- ---------------------------------------------------------------- 3. Heli-Dateien
local heli = liste(repo .. "test/studio/", "%.heli%.")
pruefe(#heli >= 12, #heli .. " Heli-Studio-Dateien in test/studio (python3 test/studio_dateien.py)")
print(string.format("\n%-34s %6s  %-8s %-8s %8s %10s %10s", "Datei", "Byte", "Ergebnis", "erwartet", "Befehle", "Spitze KB", "bleibt KB"))
for _, n in ipairs(heli) do
  local soll = n:find("^format99") and "zuNeu" or (n:find("^abgeschnitten") and "kaputt" or "geladen")
  local p = repo .. "test/studio/" .. n
  local e2, befehle, spitze, bleibend = messe(p)
  local ok = e2 == soll and befehle < 5000
  if not ok then fehlerZahl = fehlerZahl + 1 end
  print(string.format("%-34s %6d  %-8s %-8s %8d %10.1f %10.1f%s", n, #(lies(p) or ""), e2, soll, befehle, spitze,
    bleibend, ok and "" or "   FEHLER"))
  if n == "voll.heli.lua" then
    pruefe(befehle < 5000, "voll: " .. befehle .. " Befehle in einem Aufruf (< 5000)")
    pruefe(spitzeG16 > 0 and spitze <= spitzeG16, string.format("voll: Spitze %.1f KB unter dem Grenzfall g16_lang24 (%.1f KB)", spitze, spitzeG16))
  end
end
-- Inhalt der vollen Datei nachzählen (Abschnitt 12.2)
do
  local d = laden(repo .. "test/studio/voll.heli.lua", 1)
  if d then
    local nP, kurven, arten, sens, phys = 0, {}, {}, {}, false
    for i, a in ipairs(d.ansichten) do
      kurven[i] = 0
      for _, p in ipairs(a.plaetze) do
        nP = nP + 1
        arten[p.darstellung] = true
        if p.darstellung == "kurve" then kurven[i] = kurven[i] + 1 end
        if p.w:find("^sensor:") then
          sens[p.w] = true
          if select(2, p.w:gsub(":", "")) == 3 then phys = true end
        end
      end
    end
    local nA, nS = 0, 0
    for _ in pairs(arten) do nA = nA + 1 end
    for _ in pairs(sens) do nS = nS + 1 end
    pruefe(nP == 32 and kurven[1] == 2 and kurven[2] == 2 and nA == 6 and nS == 8 and phys,
      string.format("voll: %d Plätze, Kurven %d/%d, %d Darstellungsarten, %d Sensoren, Physical ID %s", nP,
        kurven[1] or 0, kurven[2] or 0, nA, nS, tostring(phys)))
  else
    pruefe(false, "voll.heli.lua nicht geladen")
  end
end

-- ---------------------------------------------------------------- 4. Textprüfungen an studio.lua (nur wenn da)
if studioText then
  local alle = studioText
  for _, n in ipairs(liste(repo .. "src/heli/", "%.lua$")) do
    if n ~= "studio.lua" then alle = alle .. "\n" .. (lies(repo .. "src/heli/" .. n) or "") end
  end
  pruefe(alle:find(':gsub("[^%w]", "_"):sub(1, 32)', 1, true) ~= nil, "Kennung nach 2.1: gsub(\"[^%w]\", \"_\"):sub(1, 32)")
  pruefe(alle:find('"modell"', 1, true) ~= nil, "Kennung: leer ergibt «modell»")
  pruefe(alle:find("SCRIPTS:/studio/", 1, true) ~= nil, "Pfad SCRIPTS:/studio/ benutzt")
  pruefe(not alle:find(':read%(%s*"%*?a"%s*%)') , "kein f:read(\"a\") im Lua (gibt es in Ethos nicht)")
  pruefe(not alle:find("%f[%w_]debug%."), "kein debug.* im ausgelieferten Lua")
  pruefe(alle:find(".heli.funke.lua", 1, true) ~= nil and alle:find(".heli.funke.neu", 1, true) ~= nil
    or (alle:find("funke.lua", 1, true) ~= nil and alle:find("funke.neu", 1, true) ~= nil), ".funke.lua und .funke.neu vorhanden")
  -- in der Schreibfunktion für .funke.lua: erst os.remove, dann os.rename (am Sender überschreibt rename nicht)
  local fs = alle:match("function [%w_.:]*[Ff]unke[Ss]chreiben.-\nend")
  if fs then
    local r, m = fs:find("os.rename", 1, true), fs:find("os.remove", 1, true)
    pruefe(r and m and m < r, "funkeSchreiben: os.remove vor os.rename (Abschnitt 9)")
  else
    hinweis("keine Funktion …funkeSchreiben gefunden: Reihenfolge remove/rename nur im Ablauf (Teil 5) geprüft")
  end
  pruefe(alle:find(".info.json", 1, true) ~= nil, "Info-Datei .info.json (Abschnitt 14)")
  -- Modul im Ersatz-Ethos laden; hat es eine Funktion «kennung», die Beispiele aus 2.1 prüfen
  local name = ""
  local env = setmetatable({
    model = { name = function() return name end, path = function() return "/models/test.bin" end },
    system = { getSources = function() return {} end, getVersion = function() return { board = "X18RS", version = "26.2.0" } end,
      getLocale = function() return "de" end },
    lcd = {}, CATEGORY_TELEMETRY_SENSOR = 4,
  }, { __index = _G })
  local f = load(studioText, "=studio.lua", "t", env)
  local ok, M = pcall(f or error)
  if ok and type(M) == "table" and type(M.kennung) == "function" then
    local faelle = { { "Extra 330 6S", "Extra_330_6S" }, { "M\195\182we", "M__we" }, { "Goblin 700 (neu)", "Goblin_700__neu_" },
      { "", "modell" }, { string.rep("x", 40), string.rep("x", 32) } }
    for _, fa in ipairs(faelle) do
      name = fa[1]
      local ok2, k = pcall(M.kennung)
      pruefe(ok2 and k == fa[2], "kennung(«" .. fa[1]:sub(1, 20) .. "») = " .. tostring(k) .. " (erwartet " .. fa[2] .. ")")
    end
  else
    hinweis("studio.lua hat keine Funktion «kennung» im Rückgabewert (oder lädt nicht ohne Ethos): Beispiele aus 2.1 nur im Simulator geprüft")
  end
end

-- ---------------------------------------------------------------- 5. Ablauf im Lua (nur wenn studio.lua da ist)
-- Wie im Kern: STUDIO.schritt(w, H) bis zum Ergebnis, danach STUDIO.anwenden. Ersatz-Ethos: SCRIPTS:/ zeigt auf einen
-- Temp-Ordner, os.rename überschreibt wie am Sender NICHT. H (STUDIO_H in kern.lua) holt der Test über debug.
if studioText then
  local tmp = os.tmpname()
  os.remove(tmp)
  os.execute("mkdir -p '" .. tmp .. "/SCRIPTS/studio'")
  local function pfad(p)
    if p:sub(1, 9) == "SCRIPTS:/" then return tmp .. "/SCRIPTS/" .. p:sub(10) end
    if p:sub(1, 1) == "/" then return p end
    return repo .. "src/heli/" .. p
  end
  local io_open, os_rename, os_remove, print_ = io.open, os.rename, os.remove, print
  local logZeilen = 0
  local name = "TEST"
  local G = setmetatable({}, { __index = _G })
  -- relative Pfade (daten/ usw.) beim Schreiben und Lesen in den Temp-Ordner, nie ins Repo
  local function pfadIo(p)
    if p:sub(1, 9) == "SCRIPTS:/" or p:sub(1, 1) == "/" then return pfad(p) end
    return tmp .. "/heli/" .. p
  end
  os.execute("mkdir -p '" .. tmp .. "/heli/daten'")
  G.io = setmetatable({ open = function(p, m) return io_open(pfadIo(p), m) end }, { __index = io })
  G.os = setmetatable({
    rename = function(a, b)
      local f = io_open(pfadIo(b), "r")
      if f then f:close() return nil, "exists" end      -- wie am Sender: überschreibt nicht
      return os_rename(pfadIo(a), pfadIo(b))
    end,
    remove = function(p) return os_remove(pfadIo(p)) end, mkdir = function() return true end,
  }, { __index = os })
  G.loadfile = function(p, ...) return loadfile(pfad(p), ...) end
  G.print = function() logZeilen = logZeilen + 1 end
  G.model = { name = function() return name end, path = function() return "MOTOR/test.bin" end }
  G.system = { getSources = function() return {} end, getSource = function() return nil end,
    getVersion = function() return { board = "X18RS", version = "26.2.0" } end, getLocale = function() return "de" end }
  G.lcd = { getWindowSize = function() return 800, 480 end }
  G.CATEGORY_TELEMETRY_SENSOR = 4
  G._G = G
  local okM, M = pcall(function() return assert(load(studioText, "=studio.lua", "t", G))() end)
  local okK, K = pcall(function() return assert(loadfile(repo .. "src/heli/kern.lua", "t", G))() end)
  local H
  if okK and type(K) == "table" then
    local gesehen = {}
    local function suche(f, tiefe)
      for i = 1, 255 do
        local n, v = debug.getupvalue(f, i)
        if not n then return nil end
        if type(v) == "table" and v.ZAHLEN and v.ZELLE_WERK then return v end
        if type(v) == "function" and tiefe > 0 and not gesehen[v] then
          gesehen[v] = true
          local r = suche(v, tiefe - 1)
          if r then return r end
        end
      end
    end
    for _, f in pairs(K) do if type(f) == "function" and not H then H = suche(f, 4) end end
  end
  if not (okM and type(M) == "table" and type(M.schritt) == "function" and H) then
    hinweis("Ablauf im Lua nicht prüfbar (studio.lua: " .. tostring(okM and type(M)) .. ", STUDIO_H gefunden: " .. tostring(H ~= nil) .. ")")
  else
    print("\nAblauf im Lua (schritt + anwenden), Befehle je Aufruf:")
    local ziel = tmp .. "/SCRIPTS/studio/TEST.heli.lua"
    local function kopiere(von, nach)
      local a = assert(io_open(von, "rb")) local t = a:read("a") a:close()
      local b = assert(io_open(nach, "wb")) b:write(t) b:close()
    end
    local function neuesW()
      local ok, w = pcall(K.neu)
      if ok and type(w) == "table" then return w end
      return { cfg = H.standard(), v = {}, st = {} }
    end
    local function ganz()
      local w, hoechst, J = neuesW(), 0, nil
      for _ = 1, 200 do       -- 1.10.1: grosse Dateien brauchen mehr Aufrufe (Stücke)
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1)
        local ok, e = pcall(M.schritt, w, H)
        debug.sethook()
        if n > hoechst then hoechst = n end
        if not ok then return nil, hoechst, tostring(e) end
        if e then J = e break end
      end
      if not J then return nil, hoechst, "kein Ergebnis nach 200 Aufrufen" end
      if J.zustand == "geladen" and M.anwenden then
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1)
        local ok, e = pcall(M.anwenden, w, J, H)
        debug.sethook()
        if n > hoechst then hoechst = n end
        if not ok then return J, hoechst, "anwenden: " .. tostring(e), w end
      end
      return J, hoechst, nil, w
    end
    local function laufDatei(von, soll, text)
      kopiere(von, ziel)
      logZeilen = 0
      local J, n, err = ganz()
      local ist = J and J.zustand or "?"
      local ok = err == nil and ist == soll and n < 5000
      pruefe(ok, string.format("%-34s %-8s %5d Befehle%s%s", text, ist, n, J and J.fehler and J.fehler > 0 and
        (", " .. J.fehler .. " Fehler / " .. logZeilen .. " Log-Zeilen") or "", err and (" " .. err) or ""))
      return J
    end
    os_remove(ziel)
    local J0, n0 = ganz()
    pruefe(J0 and J0.zustand == "fehlt", "keine Datei: " .. tostring(J0 and J0.zustand) .. ", " .. n0 .. " Befehle")
    for _, n in ipairs(dateien) do
      local nm = n:gsub("%.txt$", "")
      laufDatei(ordner .. n, erwartet(nm), nm)
    end
    for _, n in ipairs(heli) do
      if not n:find("funke") then
        local soll = n:find("^format99") and "zuNeu" or (n:find("^abgeschnitten") and "kaputt" or "geladen")
        local J = laufDatei(repo .. "test/studio/" .. n, soll, n)
        if J and (n:find("^falsche_typen") or n:find("^grenzen_richtung")) then
          pruefe(J.fehler > 0 and J.fehler == logZeilen - 0, n .. ": je Fehler eine Log-Zeile (" .. J.fehler .. " / " .. logZeilen .. ")")
        end
        if J and (n:find("^gueltig") or n:find("^voll") or n == "grenzen_fehlt.heli.lua") then
          pruefe(J.fehler == 0, n .. ": 0 Fehler (" .. J.fehler .. ")")
        end
      end
    end
    -- .funke.lua: schreiben (erst .neu, prüfen, alte entfernen, umbenennen), Rest-Fälle nach «Strom weg»
    kopiere(repo .. "test/studio/gueltig.heli.lua", ziel)
    local basis = tmp .. "/SCRIPTS/studio/TEST.heli"
    if M.funkeText and M.funkeSchreiben then
      local okT, text = pcall(M.funkeText, { kapaz = 4200 }, { ["lua:zelle"] = { warnung = 3.7, alarm = false } })
      pruefe(okT and type(text) == "string" and M.funkeSchreiben("TEST", text), ".funke.lua geschrieben")
      local okT2, text2 = pcall(M.funkeText, { kapaz = 4300 }, {})
      pruefe(okT2 and M.funkeSchreiben("TEST", text2), ".funke.lua überschrieben (Ziel vorhanden, rename überschreibt nicht)")
      local fu = laden(basis .. ".funke.lua", 1)
      pruefe(fu and fu.einstellungen and fu.einstellungen.kapaz == 4300, ".funke.lua zurückgelesen: kapaz " ..
        tostring(fu and fu.einstellungen and fu.einstellungen.kapaz))
      pruefe(io_open(basis .. ".funke.neu", "r") == nil, "keine .funke.neu übrig")
    else
      hinweis("funkeText/funkeSchreiben fehlen: Schreiben nicht geprüft")
    end
    local function datei(p, t) local f = io_open(p, "wb") f:write(t) f:close() end
    local gf = (lies(repo .. "test/studio/gueltig.heli.funke.lua"))
    os_remove(basis .. ".funke.lua")
    datei(basis .. ".funke.neu", gf)                                -- Strom weg nach remove, vor rename
    local J = ganz()
    pruefe(J and J.zustand == "geladen" and io_open(basis .. ".funke.neu", "r") == nil and lies(basis .. ".funke.lua") == gf,
      "übrig gebliebene .funke.neu ohne .funke.lua übernommen")
    datei(basis .. ".funke.neu", gf:sub(1, 40))                     -- halb geschriebene .neu neben .funke.lua
    J = ganz()
    pruefe(J and J.zustand == "geladen" and io_open(basis .. ".funke.neu", "r") == nil and lies(basis .. ".funke.lua") == gf,
      "halbe .funke.neu neben .funke.lua gelöscht, .funke.lua bleibt")
    datei(basis .. ".funke.lua", "return { format = 1, a = os }")
    J = ganz()
    pruefe(J and J.zustand == "geladen" and J.funkeVerworfen, "kaputte .funke.lua verworfen, Studio-Datei gilt")
    os_remove(basis .. ".funke.lua")
    -- Modellwechsel zehnmal (12.3): voll und gueltig im Wechsel, Speicher wächst nicht
    local function wechsel(n) kopiere(repo .. "test/studio/" .. n, ziel) local a, b, c, w = ganz() return w end
    wechsel("voll.heli.lua") wechsel("gueltig.heli.lua")
    collectgarbage() collectgarbage()
    local m0 = collectgarbage("count")
    for i = 1, 10 do wechsel(i % 2 == 0 and "gueltig.heli.lua" or "voll.heli.lua") end
    wechsel("gueltig.heli.lua")
    collectgarbage() collectgarbage()
    local m1 = collectgarbage("count")
    pruefe(m1 - m0 < 4, string.format("zehn Modellwechsel: Speicher %.1f KB -> %.1f KB", m0, m1))

    -- ---------------------------------------------------------- 6. Heli 1.10.1 (Sendertest Elektro 0.3.2)
    -- a) Sender-Eigenheiten X18RS, Ethos 26.2.0: getSources mit Tabelle -> leere Liste, mit Zahl -> alle Sensoren;
    --    getSource mit appId -> Objekt ohne Wert, für fehlende Sensoren Kategorie «keine». Studio-Sensoren,
    --    Info-Datei und der Rotorflight-Rückfall müssen trotzdem gehen.
    -- b) Befehlsgrenze im Betrieb: 160 Grenzen im Ring (höchstens rund 4000 Befehle je Aufruf), Alarm kommt trotzdem.
    -- c) Alarm nie ganz stumm: ansage = false und vibration = false -> Ton; auch bei Motorschalter «aus».
    print("\n6. Heli 1.10.1: Sender-Eigenheiten, Befehlsgrenze im Betrieb, Alarm nie stumm")
    local KAT_SENSOR, KAT_KEINE, KAT_KANAL = 4, 0, 7
    G.CATEGORY_NONE, G.CATEGORY_CHANNEL = KAT_KEINE, KAT_KANAL
    local function sensor(app, sub, ph, wert, nm)
      local q = { a = app, s = sub, p = ph, v = wert, n = nm or string.format("S%04X", app) }
      q.appId = function(o) return o.a end
      q.subId = function(o) return o.s end
      q.physId = function(o) return o.p end
      q.name = function(o) return o.n end
      q.unit = function() return 1 end
      q.decimals = function() return 1 end
      q.value = function(o) return o.v end
      q.category = function() return KAT_SENSOR end
      return q
    end
    local liste = {}
    for i = 0, 159 do liste[#liste + 1] = sensor(0x0A00 + i // 4, i % 4, i % 28, 50) end
    local s0400 = sensor(0x0400, 0, 1, 42.5, "Temp1")
    local b2, b3 = sensor(0x0B50, 0, 2, 7.1, "BEC A"), sensor(0x0B50, 0, 3, 6.4, "BEC B")
    for _, q in ipairs({ sensor(0x0500, 0, 1, 1800), sensor(0x0210, 0, 1, 44), sensor(0x0200, 0, 1, 12), s0400,
      sensor(0x0600, 0, 1, 80), sensor(0x0300, 0, 1, 3.9), sensor(0xF101, 0, 1, 90), b2, b3,
      sensor(0x5125, 0, 1, 4, "Gov"), sensor(0x5122, 0, 1, 1, "Arm") }) do liste[#liste + 1] = q end
    local leer = { category = function() return KAT_KEINE end, value = function() return nil end }
    local ohneWert = sensor(0, 0, 0, nil)
    G.system.getSources = function(f) if type(f) == "table" then return {} end return f == KAT_SENSOR and liste or {} end
    G.system.getSource = function(f)
      if type(f) == "table" and f.category == KAT_CHANNEL then
        local k = sensor(0, 0, 0, 512, "CH" .. (f.member + 1)) k.category = function() return KAT_KANAL end
        return k
      end
      if type(f) == "table" and f.appId then
        for _, q in ipairs(liste) do if q.a == f.appId then return ohneWert end end
        return leer
      end
      return nil
    end
    G.system.getUnitName = function() return "V" end
    local okL, LAUF = pcall(function() return assert(loadfile(repo .. "src/heli/studiolauf.lua", "t", G))() end)
    pruefe(okL and type(LAUF) == "table", "studiolauf.lua geladen")
    local function befehle(f, ...)
      local n = 0
      debug.sethook(function() n = n + 1 end, "", 1)
      local r = table.pack(pcall(f, ...))
      debug.sethook()
      if not r[1] then error(r[2], 0) end
      return n, table.unpack(r, 2, r.n)
    end
    -- a) voll.heli.lua: 8 Studio-Sensoren (einer mit Physical ID 3), dazu ein Kanal
    kopiere(repo .. "test/studio/voll.heli.lua", ziel)
    local Jv, _, errV, wv = ganz()
    pruefe(Jv and Jv.zustand == "geladen" and wv and wv.studio, "voll.heli.lua geladen und angewendet " .. tostring(errV))
    if wv and wv.studio and okL then
      local S, hoechst, aufrufe = wv.studio, 0, 0
      wv.v = wv.v or {}
      wv.v.tele = true
      local now = 100
      while #S.offen > 0 and aufrufe < 100 do
        local n = befehle(LAUF.wecke, wv, now, H)
        if n > hoechst then hoechst = n end
        aufrufe, now = aufrufe + 1, now + 0.05
      end
      pruefe(#S.offen == 0, string.format("Studio-Sensoren gesucht in %d Aufrufen, höchstens %d Befehle", aufrufe, hoechst))
      local Q = S.quellen["sensor:0400:0"]
      pruefe(Q and Q.q == s0400 and LAUF.wert(wv, "sensor:0400:0", "sensor", nil, 2) == 42.5,
        "sensor:0400:0 über die Liste gefunden, Wert 42.5 (getSource mit appId hätte keinen Wert)")
      Q = S.quellen["sensor:0B50:0:3"]
      pruefe(Q and Q.q == b3, "sensor:0B50:0:3 über die Physical ID gefunden (nicht 0B50 mit Physical ID 2)")
      pruefe(S.verz == nil, "Sensor-Verzeichnis danach freigegeben")
      -- fehlender Sensor -> «---»
      S.offen[1] = { "sensor:0999:0", "sensor", 0x0999, 0, nil }
      for _ = 1, 30 do if #S.offen == 0 then break end LAUF.wecke(wv, now, H) end
      pruefe(S.quellen["sensor:0999:0"] == false and LAUF.wert(wv, "sensor:0999:0", "sensor", nil, 2) == nil,
        "fehlender Sensor bleibt leer (Platz zeigt ---)")
      -- Info-Datei mit den Sensoren der Liste (höchstens 100)
      wv.infoJob = nil
      local hoechstI, fertig, k = 0, nil, 0
      repeat
        local n, r = befehle(M.infoSchritt, wv, "1.10.1", { 1 }, H)
        if n > hoechstI then hoechstI = n end
        fertig, k = r, k + 1
      until fertig or k > 100
      local info = lies(tmp .. "/SCRIPTS/studio/TEST.heli.info.json") or ""
      local _, anz = info:gsub('"appId"', "")
      pruefe(fertig and anz == 100, string.format("Info-Datei: %d Sensoren (Liste %d, höchstens 100), %d Aufrufe, höchstens %d Befehle",
        anz, #liste, k, hoechstI))
    end
    -- Rotorflight-Rückfall in kern.lua (rfLesen): eigene Sensoren 0x5125/0x5122 über die Liste
    local rf
    do
      local gesehen = {}
      local function such(f, t)
        for i = 1, 255 do
          local n, v = debug.getupvalue(f, i)
          if not n then return nil end
          if n == "rfLesen" and type(v) == "function" then return v end
          if type(v) == "function" and t > 0 and not gesehen[v] then
            gesehen[v] = true
            local r = such(v, t - 1)
            if r then return r end
          end
        end
      end
      for _, f in pairs(K) do if type(f) == "function" and not rf then rf = such(f, 4) end end
    end
    if rf then
      local w, g, a = { }, nil, nil
      for i = 1, 20 do g, a = rf(w, 10 + i * 0.05) end
      pruefe(g == 4 and a == 1, "Rotorflight-Rückfall: Governor " .. tostring(g) .. ", Arming " .. tostring(a) .. " aus eigenen Sensoren")
    else
      hinweis("rfLesen nicht gefunden: Rückfall nicht geprüft")
    end
    -- b) gross_grenzen.heli.lua: 48 Sensor-Grenzen (Alarm über 100), Betrieb im Ring (bis 1.10.1: 160; ab 1.11.0
    --    gelten nach Format 2, Regel 7.2 höchstens 48 Einträge je Liste)
    kopiere(repo .. "test/studio/gross_grenzen.heli.lua", ziel)
    local Jg, _, errG, wg = ganz()
    pruefe(Jg and Jg.zustand == "geladen" and Jg.fehler == 0 and wg and wg.studio and #wg.studio.extra == 48,
      "gross_grenzen: 48 weitere Grenzen " .. tostring(errG))
    if wg and wg.studio and okL then
      local S = wg.studio
      wg.v = wg.v or {}
      wg.v.tele = true
      local now, hoechst = 200, 0
      for _ = 1, 300 do
        local n = befehle(LAUF.wecke, wg, now, H)
        if n > hoechst then hoechst = n end
        now = now + 0.05
      end
      pruefe(#S.offen == 0 and not S.alarmAn and hoechst <= 4000,
        string.format("Betrieb 48 Grenzen, kein Alarm: höchstens %d Befehle je Aufruf", hoechst))
      for i = 1, 160 do if liste[i].a == 0x0A0B then liste[i].v = 150 end end   -- 4 Sensoren über der Grenze
      local t0, tAlarm, hoechstA = now, nil, 0
      for _ = 1, 100 do
        local n = befehle(LAUF.wecke, wg, now, H)
        if n > hoechstA then hoechstA = n end
        if S.alarmAn and not tAlarm then tAlarm = now - t0 end
        now = now + 0.05
      end
      local ton = LAUF.extraFaellig(wg, now)
      pruefe(tAlarm and tAlarm <= 16 * 0.05 + 1.05 and ton and hoechstA <= 4000,
        string.format("4 Grenzen im Alarm: erkannt nach %.2f s, fällig %s, höchstens %d Befehle", tAlarm or -1,
          tostring(ton ~= nil), hoechstA))
      local alle = 0
      for _ in pairs(S.an) do alle = alle + 1 end
      pruefe(alle == 4, "alle 4 Grenzen im Alarm (" .. alle .. ")")
      for i = 1, 160 do liste[i].v = 50 end
      for _ = 1, 40 do LAUF.wecke(wg, now, H) now = now + 0.05 end
      pruefe(not S.alarmAn, "Alarm vorbei, wenn die Werte wieder gut sind")
    end
    -- gross_werte.heli.lua: 48 Wert-Anpassungen, Betrieb
    kopiere(repo .. "test/studio/gross_werte.heli.lua", ziel)
    local Jw, _, _, ww = ganz()
    pruefe(Jw and Jw.zustand == "geladen" and Jw.fehler == 0, "gross_werte: geladen, 0 Fehler")
    -- 1.13.0: Übergang von «Heli RF» – nur eine alte <Kennung>.helirf.lua ist da: wird gelesen, Hinweis im Log
    do
      local alt = ziel:gsub("%.heli%.lua$", ".helirf.lua")
      kopiere(repo .. "test/studio/gueltig.heli.lua", alt)
      os.remove(ziel)
      local zeilen, pAlt = {}, G.print
      G.print = function(...) zeilen[#zeilen + 1] = table.concat({ ... }, " ") end
      local Ja = ganz()
      G.print = pAlt
      local hinweis = false
      for _, z in ipairs(zeilen) do if z:find("old studio file found", 1, true) then hinweis = true end end
      pruefe(Ja and Ja.zustand == "geladen" and hinweis, "alte .helirf.lua gelesen, Hinweis im Log: " .. tostring(Ja and Ja.zustand) .. " / " .. tostring(hinweis))
      os.remove(alt)
    end
    if ww and ww.studio and okL then
      ww.v = ww.v or {}
      local hoechst = 0
      for i = 1, 50 do local n = befehle(LAUF.wecke, ww, 300 + i * 0.05, H) if n > hoechst then hoechst = n end end
      pruefe(hoechst <= 4000, "Betrieb 48 Wert-Anpassungen: höchstens " .. hoechst .. " Befehle je Aufruf")
    end
    -- 1.11.0, Format 2 Regel 7.2: je 60 Einträge in werte, grenzen, einstellungen -> je 48 gelten, 3 Hinweise
    kopiere(repo .. "test/studio/ueber48.heli.lua", ziel)
    local Ju, nU, errU, wu = ganz()
    local nW, nG = 0, 0
    if wu and wu.studio then
      for _ in pairs(wu.studio.werte) do nW = nW + 1 end
      nG = #wu.studio.extra
    end
    pruefe(Ju and Ju.zustand == "geladen" and Ju.fehler == 3 and nW == 48 and nG == 48 and nU < 5000,
      string.format("ueber48: %s, %s Fehler, %d Werte, %d Grenzen, höchstens %d Befehle %s", tostring(Ju and Ju.zustand),
        tostring(Ju and Ju.fehler), nW, nG, nU, tostring(errU or "")))
    -- c) Alarm nie ganz stumm (Entscheid 20.11.2026), auch bei Motorschalter «aus»
    local toene, lauf
    do
      local gesehen = {}
      local function such(f, t)
        for i = 1, 255 do
          local n, v = debug.getupvalue(f, i)
          if not n then return end
          if n == "toene" and type(v) == "function" then toene = v end
          if n == "lauf" and type(v) == "function" then lauf = v end
          if type(v) == "function" and t > 0 and not gesehen[v] then gesehen[v] = true such(v, t - 1) end
        end
      end
      for _, f in pairs(K) do if type(f) == "function" then such(f, 4) end end
    end
    if toene and lauf then
      local ruf = { ton = 0, vib = 0, zahl = 0, datei = 0 }
      G.system.playTone = function() ruf.ton = ruf.ton + 1 end
      G.system.playHaptic = function() ruf.vib = ruf.vib + 1 end
      G.system.playNumber = function() ruf.zahl = ruf.zahl + 1 end
      G.system.playFile = function() ruf.datei = ruf.datei + 1 end
      local function fall(wie)
        for k in pairs(ruf) do ruf[k] = 0 end
        local w = neuesW()
        w.v.zelle, w.v.scharf, w.swAn, w.v.motorAus = 3.0, false, false, true   -- Motorschalter «aus»
        w.al.zelle = { an = true, t = -1000 }
        w.tAlarmFrei = -1000
        w.gs = { zelle = { ein = true, o = 3.6, g = 3.5, ans = wie.ans, vib = wie.vib } }
        w.studio = { werte = {}, UEB = M.UEBERWACHT }
        toene(w, 50)
        return ruf.ton, ruf.vib, ruf.zahl
      end
      local t, v, z = fall({ ans = false, vib = false })
      pruefe(t >= 1 and v == 0 and z == 0, string.format("Zelle ansage/vibration = false, Motor aus: %d Töne, %d Vibr., %d Zahlen", t, v, z))
      t, v, z = fall({ ans = true, vib = true })
      pruefe(t >= 1 and v == 1 and z == 1, string.format("Zelle mit Ansage, Motor aus: %d Töne, %d Vibr., %d Zahlen", t, v, z))
      -- weitere Grenze (Sensor) mit ansage = false, vibration = false: Ton
      for k in pairs(ruf) do ruf[k] = 0 end
      local okLa = pcall(lauf)
      local w = neuesW()
      w.v.scharf, w.swAn = false, false
      local x = { key = "sensor:0A00:0", art = "sensor", e = { richtung = "ueber", alarm = 100, ansage = false, vibration = false },
        z = { an = true, t = -1000 } }
      w.studio = { werte = {}, UEB = M.UEBERWACHT, extra = { x }, an = { [x] = true } }
      w.tAlarmFrei = -1000
      toene(w, 60)
      pruefe(okLa and ruf.ton >= 1 and ruf.vib == 0, string.format("Sensor-Grenze ansage/vibration = false: %d Töne, %d Vibr.", ruf.ton, ruf.vib))
      -- d) 1.12.0 «auch bei Motor aus» (Format 2 §3.5): Motorschalter SF, Stellung «Motor aus» = oben
      local function schalter(x) return { value = function() return x end, minimum = function() return -100 end,
        maximum = function() return 100 end } end
      local function mfall(mAus, pos)
        for k in pairs(ruf) do ruf[k] = 0 end
        local w = neuesW()
        w.cfg.qMotor, w.cfg.swAus, w.cfg.mAus = schalter(pos), 1, mAus
        w.v.zelle = 3.0
        w.al.zelle = { an = true, t = -1000 }
        w.tAlarmFrei = -1000
        toene(w, 70)
        return ruf.ton, ruf.vib, ruf.zahl
      end
      local ZB = (K.MAUS_BIT or {}).zelle or 4
      t, v, z = mfall(31, -100)
      pruefe(t >= 1, string.format("Zelle, Haken EIN, Schalter aus: Alarm kommt (%d Töne)", t))
      t, v, z = mfall(31 - ZB, -100)
      pruefe(t == 0 and v == 0 and z == 0, string.format("Zelle, Haken AUS, Schalter aus: still (%d Töne, %d Vibr., %d Zahlen)", t, v, z))
      t, v, z = mfall(31 - ZB, 100)
      pruefe(t >= 1, string.format("Zelle, Haken AUS, Schalter ein: Alarm kommt (%d Töne)", t))
      t = select(1, mfall(31 - 1, -100))
      pruefe(t >= 1, string.format("anderer Haken (Reglertemp.) AUS, Schalter aus: Zelle kommt (%d Töne)", t))
      -- weitere Grenze mit beiMotorAus = false
      local function xfall(bma, pos)
        for k in pairs(ruf) do ruf[k] = 0 end
        local w = neuesW()
        w.cfg.qMotor, w.cfg.swAus = schalter(pos), 1
        local x = { key = "sensor:0A00:0", art = "sensor", e = { richtung = "ueber", alarm = 100, beiMotorAus = bma },
          z = { an = true, t = -1000 } }
        w.studio = { werte = {}, UEB = M.UEBERWACHT, extra = { x }, an = { [x] = true } }
        w.tAlarmFrei = -1000
        toene(w, 80)
        return ruf.ton
      end
      pruefe(xfall(false, -100) == 0, "Sensor-Grenze beiMotorAus = false, Schalter aus: still")
      pruefe(xfall(false, 100) >= 1, "Sensor-Grenze beiMotorAus = false, Schalter ein: Ton")
      pruefe(xfall(true, -100) >= 1, "Sensor-Grenze beiMotorAus = true, Schalter aus: Ton")
      -- Laden, Anwenden und .funke.lua: Zelle false, BEC ungültig (Zahl) = true plus Hinweis
      local io_w = assert(io_open(ziel, "wb"))
      io_w:write('return { format = 1, luaVersion = ' .. M.esc("1.12.0") .. ', grenzen = {'
        .. ' [' .. M.esc("lua:zelle") .. '] = { beiMotorAus = false }, [' .. M.esc("lua:bec") .. '] = { beiMotorAus = 1 } } }\n')
      io_w:close()
      local Jm, _, _, wm = ganz()
      local cm = wm and wm.cfg and wm.cfg.mAus
      pruefe(Jm and Jm.zustand == "geladen" and Jm.fehler == 1 and cm == 31 - ZB,
        string.format("beiMotorAus aus der Datei: %s, %s Fehler, mAus = %s", tostring(Jm and Jm.zustand), tostring(Jm and Jm.fehler), tostring(cm)))
      -- Eintrag ohne Stufen: Werkgrenze gilt weiter (Zelle ab Werk ein, BEC ab Werk aus), nur der Haken ändert sich
      local werkC = H.standard()
      -- warnung = false und alarm = false ohne aus: kein Abschalten, Werkgrenze (Entscheid 20.11.2026)
      do
        local io_f = assert(io_open(ziel, "wb"))
        io_f:write('return { format = 1, grenzen = { [' .. M.esc("lua:zelle") .. '] = { warnung = false, alarm = false } } }\n')
        io_f:close()
        local Jf, _, _, wf = ganz()
        pruefe(Jf and Jf.zustand == "geladen" and wf and wf.cfg.aZelleEin == 1 and wf.cfg.aZelleGrenze == werkC.aZelleGrenze,
          string.format("Zelle warnung = false, alarm = false: Alarm ein %s, Grenze %s (Werk)", tostring(wf and wf.cfg.aZelleEin),
            tostring(wf and wf.cfg.aZelleGrenze)))
      end
      pruefe(wm and wm.cfg.aZelleEin == 1 and wm.cfg.aZelleGrenze == werkC.aZelleGrenze and wm.cfg.aBecEin == werkC.aBecEin
        and wm.gs and wm.gs.zelle and wm.gs.zelle.ein == true and wm.gs.zelle.g ~= nil,
        string.format("Eintrag nur mit beiMotorAus: Zelle ein %s (Grenze %s), BEC ein %s (Werk %s)", tostring(wm and wm.cfg.aZelleEin),
          tostring(wm and wm.cfg.aZelleGrenze), tostring(wm and wm.cfg.aBecEin), tostring(werkC.aBecEin)))
      if wm and wm.studio and M.funkeAusCfg then
        pruefe(M.funkeAusCfg(wm, H) == nil, "ohne Änderung im Menü: keine .funke.lua")
        wm.cfg.mAus = 31                                  -- im Menü Haken bei Zelle wieder EIN
        local ft = M.funkeAusCfg(wm, H) or ""
        pruefe(ft:find('["\\108\\117\\97\\58\\122\\101\\108\\108\\101"] = { beiMotorAus = true }', 1, true) ~= nil,
          ".funke.lua hebt beiMotorAus = false mit true auf: " .. ft:gsub("\n", " "))
        wm.cfg.mAus = 31 - ZB - 8                         -- Haken bei BEC aus (Studio: true)
        ft = M.funkeAusCfg(wm, H) or ""
        pruefe(ft:find("beiMotorAus = false", 1, true) ~= nil and select(2, ft:gsub("beiMotorAus", "")) == 1,
          ".funke.lua schreibt nur die geänderte BEC-Grenze: " .. ft:gsub("\n", " "))
      end
      G.system.playTone, G.system.playHaptic, G.system.playNumber, G.system.playFile = nil, nil, nil, nil
    else
      hinweis("toene/lauf nicht gefunden: Alarm-Ton nicht geprüft")
    end
  end
  os.execute("rm -rf '" .. tmp .. "'")
end

print(string.format("\nGeprüft mit: %s. Hinweise: %d", quellName, hinweise))
print(fehlerZahl == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehlerZahl .. " Fehler"))
os.exit(fehlerZahl == 0 and 0 or 1)
