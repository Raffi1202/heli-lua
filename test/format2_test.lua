-- Heli: Pflichttests Lua-Studio-Format 2 (Abschnitt 9, Tests 1–13, 15–17, dazu Regeln 7.2 und 7.5) auf dem Mac, Lua 5.4.
-- Aufruf aus dem Repo-Ordner:
--   /opt/homebrew/opt/lua@5.4/bin/lua test/format2_dateien.lua     (einmal: Heli-Fassungen nach test/format2/)
--   /opt/homebrew/opt/lua@5.4/bin/lua test/format2_test.lua
-- Umgebung: FORMAT2_ORDNER = Ordner mit den Unterlagen zum Lua-Studio-Format (Pflicht).
--
--  A. Referenz wörtlich: src/heli/studio_symbole.lua Byte für Byte gleich «Lua-Studio-Format 2 - Referenz studio_symbole.lua».
--  B. Heli-Fassungen (test/format2/) gegen die Originale mit der Referenz allein: gleiche Zähler geladen / fehlend /
--     verworfen, gleich viel gezeichneter Schmuck und Symbole, nichts Gezeichnetes in der reservierten Kopfzeile/Leiste.
--  C. Das ganze Widget (main.lua → kern.lua → …) in einer nachgebauten Ethos-Umgebung (X18RS 26.2.0): create, read,
--     dann je Bild ein wakeup und ein paint. Befehle (debug.sethook, Zählung 1) je wakeup und je GANZEM paint; die
--     Nachbildung von Ethos selbst (Quelle «=ethos») zählt nicht mit, am Sender sind das C-Funktionen.
--     Je Fall: Zähler der Referenz (S.zaehler), loadMask nur für gültige Dateien und nie in paint, S.schritt nie in paint,
--     höchstens 4 Masken je paint zum ersten Mal, Hinweis «Studio: n Symbole fehlen», kein Fehler im Widget.
-- Fälle: 1–5, 15 p01 · 6 p06 · 7 p07 · 8 p08 · 9 p09 · 10 p10 · 11 p11 (Bild wie v1) · 12 p12 (800 × 480 und 784 × 316)
--        · 13 Modellwechsel 10 × p12/p06 · 15 p01 bei Displaybreite 640 · 16 p16 · 17 p17 und erstes paint von p12 nach
--        S.start · 7.2 Listengrenzen (l72) · 7.5 kein ganz stummer Alarm (a75).
-- Schreibt nichts ins Repo: Kopie von src/heli und symbole/ in einem Temp-Ordner.
local repo = arg[0]:gsub("test/format2_test%.lua$", "")
if repo == "" then repo = "./" end
local KOORD = os.getenv("FORMAT2_ORDNER") or error("Umgebungsvariable FORMAT2_ORDNER fehlt: Ordner mit den Unterlagen zum Lua-Studio-Format", 0)
local REF = KOORD .. "/Lua-Studio-Format 2 - Referenz studio_symbole.lua"
local TESTORDNER = KOORD .. "/Lua-Studio-Format 2 - Testdateien"
local F2 = repo .. "test/format2/"
local GRENZE = 5000          -- wakeup und Prüfschritte (Format 2 §9)
local GRENZE_PAINT = 10000   -- ganzes paint: Ziel nach Format 2 §9 (geändert 21.11.2026, vorher 5000)

local fehlerZahl, hinweise = 0, 0
local messungen = {}
local function pruefe(ok, text)
  print((ok and "ok      " or "FEHLER  ") .. text)
  if not ok then fehlerZahl = fehlerZahl + 1 end
end
local function hinweis(text) print("HINWEIS " .. text) hinweise = hinweise + 1 end
local function messung(text) messungen[#messungen + 1] = text end
local function lies(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local t = f:read("a")
  f:close()
  return t
end
local function zeilen(t)
  local l = {}
  for z in (t .. "\n"):gmatch("(.-)\n") do l[#l + 1] = z end
  return l
end

-- ---------------------------------------------------------------- A. Referenz wörtlich
local refText = lies(REF)
if not refText then print("FEHLER  Referenz fehlt: " .. REF) os.exit(2) end
local SYMDATEI = repo .. "src/heli/studio_symbole.lua"
local heliSym = lies(SYMDATEI)
if not heliSym then
  -- anderer Name? die Datei mit der Kopfzeile der Referenz suchen
  local p = io.popen('ls "' .. repo .. 'src/heli/"')
  for n in p:read("a"):gmatch("[^\n]+") do
    local t = n:find("%.lua$") and lies(repo .. "src/heli/" .. n)
    if t and t:sub(1, 60) == refText:sub(1, 60) then SYMDATEI, heliSym = repo .. "src/heli/" .. n, t end
  end
  p:close()
end
if not heliSym then
  pruefe(false, "studio_symbole.lua fehlt in src/heli (Einbau Format 2 noch nicht da)")
else
  local abw
  if heliSym ~= refText then
    local a, b = zeilen(refText), zeilen(heliSym)
    for i = 1, math.max(#a, #b) do
      if a[i] ~= b[i] then abw = string.format("Zeile %d: Heli «%s», Referenz «%s»", i, tostring(b[i]), tostring(a[i])) break end
    end
    abw = abw or "Zeilenenden oder Schluss verschieden"
  end
  pruefe(abw == nil, SYMDATEI:gsub("^.*src/", "src/") .. " wörtlich wie die Referenz (" .. #refText .. " Byte)" .. (abw and (": " .. abw) or ""))
end
local version = (lies(repo .. "src/heli/main.lua") or ""):match('local VERSION = "([^"]+)"') or "?"
print("Heli " .. version)

-- reservierte Flächen aus beschreibung.json
local RES = {}
do
  local j = lies(repo .. "studio/beschreibung.json") or ""
  for o in (j:match('"reserviert"%s*:%s*(%b[])') or ""):gmatch("%b{}") do
    local function z(k) return tonumber(o:match('"' .. k .. '"%s*:%s*(%-?%d+)')) end
    if z("y") == 0 and z("breite") then RES[z("breite") .. "x" .. z("hoehe")] = z("y") + z("h") end
  end
end

-- ---------------------------------------------------------------- Ethos-Nachbildung (Quelle «=ethos», zählt nicht mit)
local ETHOS = [==[
local E, io_open, os_rename, os_remove, loadfile_, tmp, skript = ...
local function pfad(p)
  if p:sub(1, 9) == "SCRIPTS:/" then return tmp .. "/SCRIPTS/" .. p:sub(10) end
  if p:sub(1, 1) == "/" then return tmp .. p end
  return skript .. "/" .. p
end
local G = {}
local KONST = { FONT_S_BOLD = false }        -- gibt es in Ethos 26.2 nicht
local nr = 1000
setmetatable(G, { __index = function(t, k)
  local v = _G[k]
  if v ~= nil then return v end
  if type(k) == "string" and k:find("^[A-Z][A-Z0-9_]*$") and KONST[k] == nil then
    nr = nr + 1
    rawset(t, k, nr)
    return nr
  end
  return nil
end })
G._G = G
G.CATEGORY_NONE, G.CATEGORY_TELEMETRY_SENSOR, G.CATEGORY_SYSTEM_EVENT = 0, 4, 5
G.FONT_XS, G.FONT_S, G.FONT_STD, G.FONT_L, G.FONT_XL, G.FONT_XXL, G.FONT_BOLD = 1, 2, 3, 4, 5, 6, 256
G.FONT_STD_BOLD = 3 + 256
local HOEHE = { [1] = 12, [2] = 16, [3] = 20, [4] = 26, [5] = 34, [6] = 46 }
local font = 3
G.print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  E.log[#E.log + 1] = table.concat(t, " ")
end
-- Dateien: SCRIPTS:/ und relative Pfade in den Temp-Ordner; rename überschreibt wie am Sender nicht
G.io = setmetatable({ open = function(p, m)
  if type(p) ~= "string" then return nil end
  if p:find("symbole", 1, true) then E.geoeffnet[#E.geoeffnet + 1] = p end
  return io_open(pfad(p), m)
end }, { __index = io })
G.os = setmetatable({
  clock = function() return E.T end,
  time = function() return 1763700000 + math.floor(E.T) end,
  date = function(f) if f == "*t" or f == "!*t" then return { year = 2026, month = 11, day = 21, hour = 12, min = 0, sec = 0 } end return "12:00" end,
  rename = function(a, b)
    local f = io_open(pfad(b), "r")
    if f then f:close() return nil, "exists" end
    return os_rename(pfad(a), pfad(b))
  end,
  remove = function(p) return os_remove(pfad(p)) end,
  mkdir = function() return true end,
}, { __index = os })
G.loadfile = function(p, m, env)
  local f, e = loadfile_(pfad(p), m or "t", env or G)
  if not f then return f, e end
  if p:find("studio_symbole", 1, true) or E.symName and p:find(E.symName, 1, true) then
    return function(...)
      local S = f(...)
      if type(S) == "table" and S.zaehler then E.fangen(S) end
      return S
    end
  end
  return f
end
G.dofile = function(p) return assert(G.loadfile(p))() end
G.require = nil
-- Quellen: fehlende Sensoren wie am Sender (Kategorie «keine»); E.sensoren = Liste für getSources(Zahl)
local function quelle(kat, wert, app, sub)
  local o = {}
  o.category = function() return kat end
  o.value = function() return wert end
  o.appId = function() return app end
  o.subId = function() return sub or 0 end
  o.physId = function() return 0 end
  o.member = function() return 0 end
  o.name = function() return app and string.format("S%04X", app) or "---" end
  o.unit = function() return nil end
  o.decimals = function() return 0 end
  o.state = function() return wert ~= nil end
  o.stringValue = function() return wert and tostring(wert) or "" end
  return o
end
E.quelle = quelle
G.system = {
  getVersion = function() return { board = "X18RS", version = "26.2.0", simulation = false, lcdWidth = E.B, lcdHeight = 480,
    major = 26, minor = 2, revision = 0 } end,
  getLocale = function() return "de" end,
  getSource = function(t)
    if type(t) == "table" and t.category == G.CATEGORY_SYSTEM_EVENT then return quelle(G.CATEGORY_SYSTEM_EVENT, E.tele and 1 or 0) end
    if type(t) == "string" then
      for _, s in ipairs(E.sensoren) do if s.name() == t then return s end end
    end
    return quelle(G.CATEGORY_NONE, nil)
  end,
  getSources = function(k) if k == G.CATEGORY_TELEMETRY_SENSOR then return E.sensoren end return {} end,
  getUnitName = function() return "" end,
  playTone = function() E.toene = E.toene + 1 end,
  playHaptic = function() E.vib = E.vib + 1 end,
  playNumber = function() E.zahlen = E.zahlen + 1 end,
  playFile = function() E.dateien = E.dateien + 1 end,
  voltageRange = function() return 6.0, 8.4 end,
  registerWidget = function(d) E.widget = d end,
  getMemoryUsage = function() return { luaRamAvailable = 400000, luaBitmapsRamAvailable = 2000000 } end,
}
G.model = { name = function() return E.modell end, path = function() return "models/" .. E.modell:gsub("%W", "_") .. ".bin" end,
  dirty = function() end }
G.storage = { read = function() return nil end, write = function() end }
local leer = setmetatable({}, { __index = function() return function() return nil end end })
G.form = setmetatable({}, { __index = function() return function() return leer end end })
local maskenNr = 0
G.lcd = {
  getWindowSize = function() return E.W, E.H end,
  isVisible = function() return true end,
  invalidate = function() E.invalidate = E.invalidate + 1 end,
  RGB = function(r, g, b) return ((r or 0) * 256 + (g or 0)) * 256 + (b or 0) end,
  color = function() end,
  font = function(f) font = f end,
  getTextSize = function(t)
    local f = (font or 3) % 256
    local h = HOEHE[f] or 20
    return #tostring(t or "") * math.floor(h * 0.5 + 0.5), h
  end,
  drawText = function(x, y, t)
    E.trace[#E.trace + 1] = "T" .. tostring(x) .. "," .. tostring(y) .. ":" .. tostring(t)
    E.texte[#E.texte + 1] = tostring(t)
    if E.inDeko then E.dk.text = E.dk.text + 1 E.dkY[#E.dkY + 1] = y end
  end,
  drawLine = function(x1, y1, x2, y2)
    E.trace[#E.trace + 1] = "L" .. x1 .. "," .. y1 .. "," .. x2 .. "," .. y2
    if E.inDeko then E.dk.linie = E.dk.linie + 1 E.dkY[#E.dkY + 1] = math.min(y1, y2) end
  end,
  drawRectangle = function(x, y, b, h)
    E.trace[#E.trace + 1] = "R" .. x .. "," .. y .. "," .. b .. "," .. h
    if E.inDeko then E.dk.rahmen = E.dk.rahmen + 1 E.dkY[#E.dkY + 1] = y end
  end,
  drawFilledRectangle = function(x, y, b, h) E.trace[#E.trace + 1] = "F" .. x .. "," .. y .. "," .. b .. "," .. h end,
  drawFilledCircle = function() end, drawCircle = function() end, drawAnnulusSector = function() end,
  drawPoint = function() end, drawBitmap = function() end, drawFilledTriangle = function() end, drawArc = function() end,
  drawMask = function(x, y, m)
    E.trace[#E.trace + 1] = "M" .. x .. "," .. y .. "," .. tostring(type(m) == "table" and m.p)
    if type(m) ~= "table" then return end
    if E.inDeko then E.dk.symbol = E.dk.symbol + 1 E.dkY[#E.dkY + 1] = y end
    if E.inPlatz then E.platzMasken = E.platzMasken + 1 end
    if not E.gezeichnet[m] then E.gezeichnet[m] = true E.erstImBild = E.erstImBild + 1 end
  end,
  loadMask = function(p)
    E.masken[#E.masken + 1] = p
    if E.inPaint then E.loadImPaint = E.loadImPaint + 1 end
    local f = io_open(pfad(p), "rb")
    if not f then return nil end
    f:close()
    maskenNr = maskenNr + 1
    local m = { p = p:match("[^/]+$"), nr = maskenNr }
    E.lebend[m] = true
    return m
  end,
  loadBitmap = function() return {} end,
}
-- Referenz beobachten: Aufrufe zählen, ohne ihr Verhalten zu ändern
E.fangen = function(S)
  E.S = S
  local o = {}
  for _, k in ipairs({ "start", "schritt", "bildAnfang", "platz", "deko", "freigeben" }) do o[k] = S[k] end
  S.start = function(d) E.startN = E.startN + 1 E.nachStart = true E.fertig = false return o.start(d) end
  S.schritt = function()
    if E.inPaint then E.schrittImPaint = E.schrittImPaint + 1 end
    local r = o.schritt()
    if r and not E.fertig then E.fertig = true E.fertigBild = E.bild end
    return r
  end
  S.bildAnfang = function() E.bildAnfangN = E.bildAnfangN + 1 return o.bildAnfang() end
  S.platz = function(p, x, y, f)
    E.inPlatz = true
    local a, b = o.platz(p, x, y, f)
    E.inPlatz = false
    E.platzRet[#E.platzRet + 1] = { a, b }
    return a, b
  end
  S.deko = function(...) E.inDeko = true local r = o.deko(...) E.inDeko = false E.dekoN = E.dekoN + 1 return r end
  S.freigeben = function() E.freigebenN = E.freigebenN + 1 return o.freigeben() end
end
return G
]==]

-- ---------------------------------------------------------------- Temp-Ordner
local tmp = os.tmpname()
os.remove(tmp)
assert(os.execute("mkdir -p '" .. tmp .. "/heli/daten' '" .. tmp .. "/SCRIPTS/studio' && cp -R '" .. repo ..
  "src/heli/.' '" .. tmp .. "/heli/'"))
assert(os.execute("cp -R '" .. TESTORDNER .. "/symbole' '" .. tmp .. "/SCRIPTS/studio/symbole'"))
local io_open, os_rename, os_remove = io.open, os.rename, os.remove
local function kopiere(von, nach)
  local t = assert(lies(von), "fehlt: " .. von)
  local b = assert(io_open(nach, "wb")) b:write(t) b:close()
end

local getinfo = debug.getinfo
local PROFIL = {}                               -- FORMAT2_PROFIL=1: Befehle je Funktion im ruhigen paint von p12 800x480
local profilAn = false
local function messe(f, ...)
  local n = 0
  if profilAn then
    debug.sethook(function()
      local i = getinfo(2, "S")
      if i.source ~= "=ethos" then
        n = n + 1
        local k = i.short_src:match("[^/]*$") .. ":" .. i.linedefined
        PROFIL[k] = (PROFIL[k] or 0) + 1
      end
    end, "", 1)
  else
    debug.sethook(function() if getinfo(2, "S").source ~= "=ethos" then n = n + 1 end end, "", 1)
  end
  local ok, e = pcall(f, ...)
  debug.sethook()
  return n, ok, e
end

local E
local function neueUmgebung(B)
  E = { T = 0, B = B or 800, W = 800, H = 480, modell = "Heli Studio", log = {}, geoeffnet = {}, masken = {},
    lebend = setmetatable({}, { __mode = "k" }), gezeichnet = setmetatable({}, { __mode = "k" }), sensoren = {}, tele = false,
    toene = 0, vib = 0, zahlen = 0, dateien = 0, invalidate = 0, trace = {}, texte = {}, dk = {}, dkY = {}, platzRet = {},
    startN = 0, schrittImPaint = 0, bildAnfangN = 0, dekoN = 0, freigebenN = 0, loadImPaint = 0, erstImBild = 0,
    platzMasken = 0, bild = 0 }
  local G = assert(load(ETHOS, "=ethos", "t", _ENV))(E, io_open, os_rename, os_remove, loadfile, tmp, tmp .. "/heli")
  local main = assert(G.loadfile("main.lua"))()
  main.init()
  assert(E.widget, "registerWidget nicht aufgerufen")
  return E.widget
end

local ZIEL = tmp .. "/SCRIPTS/studio/Heli_Studio.heli.lua"
local function kennungDatei(modell) return tmp .. "/SCRIPTS/studio/" .. modell:gsub("[^%w]", "_"):sub(1, 32) .. ".heli.lua" end

-- Ein Modell laden und laufen lassen: create, read, dann je Bild wakeup + paint (wie Ethos, ~10 Bilder/s).
-- Rückgabe: Ergebnis-Tabelle
local function lauf(def, datei, fenster, opt)
  opt = opt or {}
  E.modell = opt.modell or "Heli Studio"
  local ziel = kennungDatei(E.modell)
  if datei then kopiere(datei, ziel) elseif not opt.behalten then os_remove(ziel) end
  E.W, E.H = fenster[1], fenster[2]
  E.masken, E.geoeffnet, E.log = {}, {}, {}
  E.schrittImPaint, E.loadImPaint, E.startN, E.bildAnfangN, E.dekoN = 0, 0, 0, 0, 0
  E.fertig, E.fertigBild, E.nachStart = false, nil, false
  if not opt.weiter then E.T = 0 end
  local r = { maxW = 0, maxP = 0, ersteNachStart = nil, maxErst = 0, absturz = nil, bilder = 0, dekoTexteVoll = nil }
  local w = def.create()
  def.read(w)
  local nachFertig = 0
  for k = 1, opt.bilder or 400 do
    E.bild = k
    E.T = E.T + 0.1
    local nw, okW, eW = messe(def.wakeup, w)
    if not okW and not r.absturz then r.absturz = "wakeup: " .. tostring(eW) end
    E.inPaint, E.erstImBild, E.trace, E.texte, E.platzRet, E.platzMasken = true, 0, {}, {}, {}, 0
    E.dk, E.dkY = { text = 0, linie = 0, rahmen = 0, symbol = 0 }, {}
    local nachStart = E.nachStart
    E.nachStart = false
    local b0 = E.bildAnfangN
    if opt.profil and k == opt.profil then profilAn = true end
    local np, okP, eP = messe(def.paint, w)
    profilAn = false
    local studioBild = E.bildAnfangN > b0          -- dieses Bild zeigte die Studio-Ansicht (Format 2)
    E.inPaint = false
    if not okP and not r.absturz then r.absturz = "paint: " .. tostring(eP) end
    if nachStart and r.ersteNachStart == nil then r.ersteNachStart = np end
    if nw > r.maxW then r.maxW = nw end
    if np > r.maxP then r.maxP = np end
    if studioBild then
      if np > (r.maxPStudio or 0) then r.maxPStudio = np end
    elseif np > (r.maxPEigen or 0) then r.maxPEigen = np end
    if E.erstImBild > r.maxErst then r.maxErst = E.erstImBild end
    if opt.texte and r.dekoTexteVoll == nil and E.fertig and E.dk.text >= opt.texte then r.dekoTexteVoll = k - E.fertigBild end
    r.bilder = k
    if w.studioFertig and (E.S == nil or E.fertig) and not (E.S and E.S.nochZuZeichnen()) then
      nachFertig = nachFertig + 1
      if nachFertig >= (opt.nachlauf or 40) and not (opt.profil and k < opt.profil) then break end
    end
  end
  if w.fehler and not r.absturz then r.absturz = "w.fehler: " .. tostring(w.fehler) end
  for _, z in ipairs(E.log) do
    if z:find("Fehler in", 1, true) and not r.absturz then r.absturz = z end
  end
  r.w, r.zustand = w, w.studioZustand
  r.z = { 0, 0, 0 }
  if E.S then r.z = { E.S.zaehler() } end
  r.trace, r.texte, r.dk, r.dkY, r.platzRet, r.platzMasken = E.trace, E.texte, E.dk, E.dkY, E.platzRet, E.platzMasken
  r.masken, r.geoeffnet, r.log = E.masken, E.geoeffnet, E.log
  r.schrittImPaint, r.loadImPaint, r.bildAnfangN, r.dekoN = E.schrittImPaint, E.loadImPaint, E.bildAnfangN, E.dekoN
  return r
end

local function txt(z) return z[1] .. " / " .. z[2] .. " / " .. z[3] end
local function gleich(z, e) return z[1] == e[1] and z[2] == e[2] and z[3] == e[3] end
local function logHat(r, ...)
  for _, z in ipairs(r.log) do
    for _, m in ipairs({ ... }) do if z:find(m, 1, true) then return true end end
  end
  for _, z in ipairs(r.texte) do
    for _, m in ipairs({ ... }) do if z:find(m, 1, true) then return true end end
  end
  return false
end

-- ---------------------------------------------------------------- B. Heli-Fassungen gegen die Originale (Referenz allein)
print("\nB. Heli-Fassungen (test/format2) gegen die Originale, Referenz allein:")
do
  local function referenzLauf(text)
    neueUmgebung(800)
    local G = assert(load(ETHOS, "=ethos", "t", _ENV))(E, io_open, os_rename, os_remove, loadfile, tmp, tmp .. "/heli")
    local S = assert(load(refText, "=studio_symbole", "t", G))()
    S.B = 800
    local d = assert(load(text, "=datei", "t", {}))()
    S.start(d)
    for _ = 1, 300 do if S.schritt() then break end end
    local dk, ys, symb = { text = 0, linie = 0, rahmen = 0, symbol = 0 }, {}, 0
    for _, a in ipairs(type(d.ansichten) == "table" and d.ansichten or {}) do
      for _ = 1, 30 do                                  -- Texte: höchstens 2 je paint zum ersten Mal gemessen
        E.dk, E.dkY, E.inDeko = { text = 0, linie = 0, rahmen = 0, symbol = 0 }, {}, true
        S.bildAnfang()
        S.deko(a, 0, 0)
        E.inDeko = false
      end
      for k, v in pairs(E.dk) do dk[k] = dk[k] + v end
      for _, y in ipairs(E.dkY) do ys[#ys + 1] = { y, a } end
      for _, p in ipairs(type(a.plaetze) == "table" and a.plaetze or {}) do
        if type(p) == "table" and type(p.y) == "number" then
          local e = S.platz(p, p.x or 0, p.y, 0)
          if e and e > 0 then symb = symb + 1 end
        end
      end
    end
    return { S.zaehler() }, dk, ys, symb, d
  end
  local p = io.popen('ls "' .. TESTORDNER .. '"')
  for n in p:read("a"):gmatch("[^\n]+") do
    if n:find("^p%d%d_.*%.lua$") then
      local heli = F2 .. n:gsub("%.lua$", ".heli.lua")
      local t1, t2 = lies(TESTORDNER .. "/" .. n), lies(heli)
      if not t2 then
        pruefe(false, n .. ": Heli-Fassung fehlt (zuerst lua test/format2_dateien.lua)")
      else
        local z1, d1, _, s1 = referenzLauf(t1)
        local z2, d2, ys, s2, dd = referenzLauf(t2)
        local frei = true
        for _, e in ipairs(ys) do
          local R = RES[tostring(e[2].breite) .. "x" .. tostring(e[2].hoehe)] or 0
          if e[1] < R then frei = false end
        end
        for _, a in ipairs(type(dd.ansichten) == "table" and dd.ansichten or {}) do
          local R = RES[tostring(a.breite) .. "x" .. tostring(a.hoehe)] or 0
          for _, pl in ipairs(a.plaetze or {}) do if type(pl.y) == "number" and pl.y < R then frei = false end end
        end
        pruefe(gleich(z1, z2) and d1.text == d2.text and d1.linie == d2.linie and d1.rahmen == d2.rahmen
          and d1.symbol == d2.symbol and s1 == s2 and frei,
          string.format("%-28s %s, Schmuck T%d L%d R%d S%d, Platz-Symbole %d; reservierte Fläche frei: %s", n, txt(z2), d2.text,
            d2.linie, d2.rahmen, d2.symbol, s2, tostring(frei)))
      end
    end
  end
  p:close()
end

-- ---------------------------------------------------------------- C. Ganzes Widget
print("\nC. Ganzes Widget (main.lua) in der Ethos-Nachbildung, X18RS 26.2.0:")
local okStart, defOderFehler = pcall(neueUmgebung, 800)
if not okStart then
  pruefe(false, "Widget lädt nicht: " .. tostring(defOderFehler))
  os.execute("rm -rf '" .. tmp .. "'")
  os.exit(1)
end
local function fall(datei, fenster, B, opt)
  local def = neueUmgebung(B or 800)
  return lauf(def, datei and (F2 .. datei) or nil, fenster, opt)
end
local function grund(r)
  return string.format("Zustand %s, Zähler %s, wakeup max %d, paint max %d%s", tostring(r.zustand), txt(r.z), r.maxW, r.maxP,
    r.absturz and (", ABSTURZ " .. r.absturz) or "")
end
local eigenUeber = {}
local function allgemein(name, r)
  pruefe(r.absturz == nil, name .. ": kein Fehler im Widget" .. (r.absturz and (" (" .. r.absturz .. ")") or ""))
  -- Pflicht: wakeup und das ganze paint der Studio-Ansicht. Das paint der eingebauten Belegung (vor dem Laden, ohne
  -- passende Ansicht) ist keine Format-2-Sache und wird nur gemessen (Zeile «Messungen», Hinweis unten).
  pruefe(r.maxW < GRENZE and (r.maxPStudio or 0) < GRENZE_PAINT, string.format("%s: wakeup unter %d (%d), ganzes paint der Studio-Ansicht unter %d (%s)",
    name, GRENZE, r.maxW, GRENZE_PAINT, tostring(r.maxPStudio or "–")))
  if (r.maxPEigen or 0) >= GRENZE_PAINT then eigenUeber[#eigenUeber + 1] = name .. " " .. r.maxPEigen end
  pruefe(r.schrittImPaint == 0 and r.loadImPaint == 0, string.format("%s: S.schritt/loadMask nie in paint (%d / %d)", name, r.schrittImPaint, r.loadImPaint))
  pruefe(r.maxErst <= 4, name .. ": höchstens 4 Masken je paint zum ersten Mal (" .. r.maxErst .. ")")
  messung(string.format("%-28s wakeup %5d, paint Studio-Ansicht %5s, paint eingebaute Belegung %5s, erstes paint nach S.start %5s, %3d Bilder",
    name, r.maxW, tostring(r.maxPStudio or "–"), tostring(r.maxPEigen or "–"), tostring(r.ersteNachStart or "–"), r.bilder))
end

-- Grundlast ohne Studio-Datei
local r0 = fall(nil, { 800, 480 })
collectgarbage("collect") collectgarbage("collect")
local speicher0 = collectgarbage("count")
allgemein("ohne Studio-Datei 800x480", r0)

-- Tests 1–5, 15 (p01)
local r = fall("p01_kaputte_png.heli.lua", { 800, 480 })
allgemein("1–5,15 p01 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), "1–5,15 p01: " .. grund(r) .. " (erwartet 0 / 0 / 0)")
do
  local nur = #r.masken == 0                          -- 1.15.0: Symbole entfernt, keine Symboldatei geöffnet
  pruefe(nur, "1–5,15 p01: keine Symboldatei geöffnet (" .. #r.masken .. " Aufrufe: " .. table.concat(r.masken, ", "):gsub("SCRIPTS:/studio/symbole/", "") .. ")")
  local n = 0
  for _, z in ipairs(r.log) do if z:find("^Studio%-Symbol") then n = n + 1 end end
  pruefe(n == 0, "1–5,15 p01: keine Zeile «Studio-Symbol» (" .. n .. ")")
  pruefe(not logHat(r, "8 Symbole fehlen", "8 symbols missing"), "1 p01: kein Symbol-Hinweis mehr")
end

-- Test 15 mit Displaybreite 640 (X14): alle 48-px-Dateien abgewiesen ausser fremdkante_48 (38 × 38)
r = fall("p01_kaputte_png.heli.lua", { 630, 258 }, 640)
allgemein("15 p01 B=640 630x258", r)
pruefe(gleich(r.z, { 0, 0, 0 }), "15 p01 bei 640 px: " .. grund(r) .. " (erwartet 0 / 0 / 0)")

-- Test 6 (p06)
r = fall("p06_100_symbole.heli.lua", { 800, 480 })
allgemein("6 p06 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), "6 p06: " .. grund(r) .. " (erwartet 0 / 0 / 0)")
pruefe(not logHat(r, "Symbole fehlen", "symbols missing"), "6 p06: Symbole still überlesen")

-- Test 7 (p07)
r = fall("p07_namen.heli.lua", { 800, 480 })
allgemein("7 p07 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), "7 p07: " .. grund(r) .. " (erwartet 0 / 0 / 0)")
do
  local gut = true
  for _, p in ipairs(r.geoeffnet) do
    -- ab 1.14.4: zu jedem gültigen Namen auch name_12.png / name_16.png (kleine Stufen für den Platzkopf)
    local n = p:match("^SCRIPTS:/studio/symbole/(.+)_%d+%.png$")
    if n ~= "aaaaaaaaaaaaaaaaaaaaaaaa" and n ~= "akku" then gut = false print("        geöffnet: " .. p) end
  end
  pruefe(gut, "7 p07: io.open nur für die zwei gültigen Namen (mit _12/_16) (" .. #r.geoeffnet .. " Aufrufe)")
end

-- Test 8 (p08)
r = fall("p08_px.heli.lua", { 800, 480 })
allgemein("8 p08 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), "8 p08: " .. grund(r) .. " (erwartet 0 / 0 / 0)")

-- Test 9 (p09): gezeichnet 8 Rahmen, 2 Texte, 1 Linie, 1 Symbol, nichts in der Kopfzeile
r = fall("p09_deko.heli.lua", { 800, 480 })
allgemein("9 p09 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 15 }), "9 p09: " .. grund(r) .. " (erwartet 0 / 0 / 15)")
do
  local d, unter = r.dk, true
  for _, y in ipairs(r.dkY) do if y < (RES["800x480"] or 0) then unter = false end end
  pruefe(d.rahmen == 8 and d.text == 2 and d.linie == 1 and d.symbol == 0 and unter,
    string.format("9 p09: letztes Bild Schmuck %d Rahmen, %d Texte, %d Linie, %d Symbol (erwartet 8/2/1/0), unter der Kopfzeile %s",
      d.rahmen, d.text, d.linie, d.symbol, tostring(unter)))
end

-- Test 10 (p10): nur Platz 3 zeigt das Symbol
r = fall("p10_symbol_ohne_eintrag.heli.lua", { 800, 480 })
allgemein("10 p10 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), "10 p10: " .. grund(r) .. " (erwartet 0 / 0 / 0)")
do
  local ein = 0
  for _, x in ipairs(r.platzRet) do if (x[1] or 0) > 0 then ein = ein + 1 end end
  pruefe(#r.platzRet == 4 and ein == 0 and r.platzMasken == 0,
    string.format("10 p10: S.platz %d× im letzten Bild, %d mit Einrückung, %d Masken gezeichnet (erwartet 4 / 0 / 0)", #r.platzRet, ein, r.platzMasken))
  pruefe(logHat(r, "Studio"), "10 p10: Hinweis im Log")
end

-- Test 11 (p11, Format 1): Felder überlesen, Bild wie dieselbe Datei ohne Format-2-Felder
r = fall("p11_format1.heli.lua", { 800, 480 })
allgemein("11 p11 800x480", r)
local r11b = fall("p11_format1_ohne.heli.lua", { 800, 480 })
do
  local alle0 = true
  for _, x in ipairs(r.platzRet) do if x[1] ~= 0 or x[2] ~= true then alle0 = false end end
  pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }) and #r.masken == 0 and r.dk.text + r.dk.linie + r.dk.rahmen + r.dk.symbol == 0
    and alle0, "11 p11: " .. grund(r) .. ", " .. #r.masken .. " loadMask, kein Schmuck, S.platz immer 0,true")
  local abw
  for i = 1, math.max(#r.trace, #r11b.trace) do
    if r.trace[i] ~= r11b.trace[i] then abw = string.format("Zeichenbefehl %d: «%s» statt «%s»", i, tostring(r.trace[i]), tostring(r11b.trace[i])) break end
  end
  pruefe(abw == nil, "11 p11: Bild gleich wie ohne Format-2-Felder (" .. #r.trace .. " Zeichenbefehle)" .. (abw and (": " .. abw) or ""))
end

-- 1.14.0 R3: Fenstergrössen ohne passende Ansicht, p12 wird umgerechnet (Befehle für wakeup und paint der umgerechneten Ansicht)
for _, fe in ipairs({ { 640, 360, 640 }, { 480, 320, 480 }, { 630, 258, 640 }, { 472, 210, 480 } }) do
  r = fall("p12_voll.heli.lua", { fe[1], fe[2] }, fe[3])
  local name = string.format("R3 umgerechnet p12 %dx%d", fe[1], fe[2])
  allgemein(name, r)
  pruefe(r.zustand == "geladen" and (r.maxPStudio or 0) > 0, name .. ": umgerechnete Studio-Ansicht gezeichnet (paint " .. tostring(r.maxPStudio) .. ")")
end

-- Test 12 (p12) in beiden Fenstern, Lua-Speicher gemessen; Test 17 Teil 2: erstes paint nach S.start
for _, fe in ipairs({ { 800, 480 }, { 784, 316 } }) do
  r = fall("p12_voll.heli.lua", fe, 800, { profil = (os.getenv("FORMAT2_PROFIL") and fe[1] == 800) and 120 or nil })
  local name = string.format("12 p12 %dx%d", fe[1], fe[2])
  allgemein(name, r)
  pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }), name .. ": " .. grund(r) .. " (erwartet 20 / 0 / 0)")
  pruefe(r.ersteNachStart ~= nil and r.ersteNachStart < GRENZE_PAINT, name .. ": erstes paint nach S.start " .. tostring(r.ersteNachStart) .. " Befehle (Test 17)")
  pruefe(r.bildAnfangN > 0 and r.dekoN > 0, name .. ": S.bildAnfang und S.deko in paint aufgerufen (" .. r.bildAnfangN .. " / " .. r.dekoN .. ")")
  local w = r.w
  r = nil
  collectgarbage("collect") collectgarbage("collect")
  messung(string.format("%s: Lua-Speicher mit geladener Datei %.1f KB über der Grundlast ohne Studio-Datei", name,
    collectgarbage("count") - speicher0))
  w = nil
end

-- Test 16 (p16)
r = fall("p16_wertanpassungen.heli.lua", { 800, 480 })
allgemein("16 p16 800x480", r)
pruefe(r.zustand == "geladen" and gleich(r.z, { 0, 0, 0 }) and r.maxW < GRENZE, "16 p16: " .. grund(r))

-- Test 17 (p17): Texte nach wenigen Bildern da
r = fall("p17_schmaltexte.heli.lua", { 800, 480 }, 800, { texte = 24 })
allgemein("17 p17 800x480", r)
pruefe(r.zustand == "geladen" and (r.maxPStudio or 0) < GRENZE_PAINT and r.dekoTexteVoll ~= nil and r.dekoTexteVoll <= 15,
  "17 p17: " .. grund(r) .. ", alle 24 Texte " .. tostring(r.dekoTexteVoll) .. " Bilder nach dem Ende von S.schritt (höchstens 15)")

-- Regel 7.2: je 60 Einträge in werte, grenzen, einstellungen -> ab dem 49. verworfen plus Hinweis
r = fall("l72_listen.heli.lua", { 800, 480 })
allgemein("7.2 l72 800x480", r)
do
  local gefunden = {}
  for _, z in ipairs(r.log) do
    for _, k in ipairs({ "werte", "grenzen", "einstellungen" }) do
      if z:find(k, 1, true) and z:find("48", 1, true) and (z:find("verworfen", 1, true) or z:find("discard", 1, true)) then gefunden[k] = true end
    end
  end
  pruefe(r.zustand == "geladen" and gefunden.werte and gefunden.grenzen and gefunden.einstellungen,
    string.format("7.2 l72: Zustand %s; Hinweis «über 48 verworfen» für werte %s, grenzen %s, einstellungen %s", tostring(r.zustand),
      tostring(gefunden.werte == true), tostring(gefunden.grenzen == true), tostring(gefunden.einstellungen == true)))
end

-- Regel 7.5: Sensor über der Alarmgrenze, ansage = false, vibration = false -> trotzdem ein Ton
do
  local def = neueUmgebung(800)
  E.tele = true
  E.sensoren = { E.quelle(4, 150, 0x0A00, 0) }
  r = lauf(def, F2 .. "a75_stumm.heli.lua", { 800, 480 }, { bilder = 300, nachlauf = 300 })
  allgemein("7.5 a75 800x480", r)
  pruefe(r.zustand == "geladen" and E.toene >= 1 and E.vib == 0,
    string.format("7.5 a75: Alarm ohne Ansage und Vibration: %d Töne, %d Vibrationen, %d Zahlen, %d Dateien (Ton erwartet)", E.toene, E.vib,
      E.zahlen, E.dateien))
end

-- Test 13: Modellwechsel 10 × hin und her (p12 20 × 64 px, p06 20 × 24 px): Speicher und Masken wachsen nicht
do
  local def = neueUmgebung(800)
  kopiere(F2 .. "p12_voll.heli.lua", kennungDatei("Heli Studio"))
  kopiere(F2 .. "p06_100_symbole.heli.lua", kennungDatei("Heli Zwei (B)"))
  local speicher, lebend, maxLebend, absturz = {}, {}, 0, nil
  for i = 1, 10 do
    local m = i % 2 == 1 and "Heli Studio" or "Heli Zwei (B)"
    local rr = lauf(def, nil, { 800, 480 }, { modell = m, weiter = true, behalten = true })
    if rr.absturz and not absturz then absturz = rr.absturz end
    local erw = { 0, 0, 0 }                              -- 1.15.0: Symbole entfernt
    if not gleich(rr.z, erw) and not absturz then absturz = "Wechsel " .. i .. ": Zähler " .. txt(rr.z) end
    rr = nil
    collectgarbage("collect") collectgarbage("collect")
    speicher[i] = collectgarbage("count")
    local n = 0
    for _ in pairs(E.lebend) do n = n + 1 end
    lebend[i] = n
    if n > maxLebend then maxLebend = n end
  end
  pruefe(absturz == nil, "13 Modellwechsel: geladen ohne Fehler" .. (absturz and (" (" .. absturz .. ")") or ""))
  pruefe(speicher[10] - speicher[2] < 8 and speicher[9] - speicher[1] < 8,
    string.format("13 Modellwechsel: Lua-Speicher nach Wechsel 1/2: %.1f/%.1f KB, nach 9/10: %.1f/%.1f KB", speicher[1], speicher[2],
      speicher[9], speicher[10]))
  pruefe(maxLebend <= 20, "13 Modellwechsel: höchstens " .. maxLebend .. " Masken gleichzeitig lebendig (≤ 20; je Wechsel: " ..
    table.concat(lebend, " ") .. ")")
  messung("13 Modellwechsel: Lua-Speicher je Wechsel " .. table.concat((function()
    local t = {} for i, v in ipairs(speicher) do t[i] = string.format("%.0f", v) end return t end)(), " ") .. " KB")
end

if #eigenUeber > 0 then
  hinweis("paint der eingebauten Belegung (ohne Studio-Ansicht, auch während der Feldprüfung) über " .. GRENZE_PAINT .. " Befehle: " ..
    table.concat(eigenUeber, "; "))
end
if next(PROFIL) then
  local l = {}
  for k, v in pairs(PROFIL) do l[#l + 1] = { k, v } end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  print("\nProfil ruhiges paint p12 800x480 (Befehle je Funktion, Datei:Zeile der Definition):")
  for i = 1, math.min(15, #l) do print(string.format("  %6d  %s", l[i][2], l[i][1])) end
end
print("\nMessungen (Befehle je Aufruf, höchstens):")
for _, m in ipairs(messungen) do print("  " .. m) end
os.execute("rm -rf '" .. tmp .. "'")
print(string.format("\nHeli %s. Hinweise: %d", version, hinweise))
print(fehlerZahl == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehlerZahl .. " Fehler"))
os.exit(fehlerZahl == 0 and 0 or 1)
