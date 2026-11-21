-- Heli RF: Heli-Fassungen der Testdateien zu Lua-Studio-Format 2 (Abschnitt 9) erzeugen, Lua 5.4.
-- Aufruf aus dem Repo-Ordner:  /opt/homebrew/opt/lua@5.4/bin/lua test/format2_dateien.lua ["<Ordner Testdateien>"]
--   Ordner = «FrSky Koordination/Lua-Studio-Format 2 - Testdateien» (wird nur gelesen; Standard: im Ordner FrSky Koordination).
-- Schreibt test/format2/<Kennung>.helirf.lua (Kennung = Name der Testdatei, z. B. p12_voll.helirf.lua).
--
-- Heli zeichnet oben eine eigene Kopfzeile bzw. Leiste (studio/beschreibung.json «reserviert», z. B. 800 × 480: y 0–57,
-- 784 × 316: y 0–33). Plätze und Schmuck der Originale liegen teils dort. Darum: Jedes Element, das ganz in der Ansicht
-- liegt, wird senkrecht in den freien Bereich darunter gestaucht (y' = R + y·(H−R)/H, Höhe entsprechend); Symbole
-- behalten ihre Kante und rücken höchstens bis H − Kante. Elemente, die nicht ganz in der Ansicht liegen (die absichtlich
-- ungültigen), bleiben unverändert und damit ungültig. Alles andere (Namen, px, Farben, Texte, Typen, auch 48.0 als
-- Kommazahl) bleibt gleich. Ob die Fassung für die Referenz gleichwertig ist (geladen / fehlend / verworfen, gezeichneter
-- Schmuck) und nichts Gültiges in der reservierten Fläche liegt, prüft test/format2_test.lua.
-- Zusätzlich:
--   p11_format1_ohne.helirf.lua   p11 ohne die Format-2-Felder (Vergleichsbild für Test 11: Bild wie v1)
--   l72_listen.helirf.lua         Regel 7.2: je 60 Einträge in werte, grenzen, einstellungen (ab dem 49. verworfen)
--   a75_stumm.helirf.lua          Regel 7.5: Sensor-Grenze mit ansage = false und vibration = false (Ton bleibt)
local repo = arg[0]:gsub("test/format2_dateien%.lua$", "")
if repo == "" then repo = "./" end
local QUELLE = arg[1] or ((os.getenv("FORMAT2_ORDNER") or error("Umgebungsvariable FORMAT2_ORDNER fehlt", 0)) .. "/Lua-Studio-Format 2 - Testdateien")
local ZIEL = repo .. "test/format2/"

local function lies(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local t = f:read("a")
  f:close()
  return t
end

-- reservierte Flächen aus studio/beschreibung.json: [breite .. "x" .. hoehe] = untere Kante (y + h)
local RES = {}
do
  local j = assert(lies(repo .. "studio/beschreibung.json"), "studio/beschreibung.json fehlt")
  local teil = j:match('"reserviert"%s*:%s*(%b[])')
  assert(teil, "reserviert fehlt in beschreibung.json")
  for o in teil:gmatch("%b{}") do
    local function z(k) return tonumber(o:match('"' .. k .. '"%s*:%s*(%-?%d+)')) end
    local br, ho, y, h = z("breite"), z("hoehe"), z("y"), z("h")
    if br and ho and y and h and y == 0 then
      local k = br .. "x" .. ho
      RES[k] = math.max(RES[k] or 0, y + h)
    end
  end
end

-- ---------------------------------------------------------------- Schreiben wie das Studio (eine Zeile, Escapes)
local function esc(t) return '"' .. t:gsub(".", function(c) return "\\" .. c:byte() end) .. '"' end
local VORN = { format = 1, luaVersion = 2, symbole = 3, ansichten = 4, werte = 5, grenzen = 6, einstellungen = 7 }
local function wert(v)
  local t = type(v)
  if t == "string" then return esc(v) end
  if t == "boolean" then return tostring(v) end
  if t == "number" then
    if math.type(v) == "integer" then return string.format("%d", v) end
    local s = string.format("%.17g", v)
    if tonumber(string.format("%.6f", v)) == v then s = string.format("%.6f", v):gsub("0+$", ""):gsub("%.$", ".0") end
    if not s:find("[%.e]") then s = s .. ".0" end
    return s
  end
  assert(t == "table", "Typ " .. t)
  local teile, n = {}, #v
  for i = 1, n do teile[#teile + 1] = wert(v[i]) end
  local schl = {}
  for k in pairs(v) do
    if not (math.type(k) == "integer" and k >= 1 and k <= n) then schl[#schl + 1] = k end
  end
  table.sort(schl, function(a, b)
    local va, vb = VORN[a] or 99, VORN[b] or 99
    if va ~= vb then return va < vb end
    return tostring(a) < tostring(b)
  end)
  for _, k in ipairs(schl) do
    if type(k) == "string" and k:find("^[%a_][%w_]*$") then teile[#teile + 1] = k .. " = " .. wert(v[k])
    else teile[#teile + 1] = "[" .. wert(k) .. "] = " .. wert(v[k]) end
  end
  if #teile == 0 then return "{}" end
  return "{ " .. table.concat(teile, ", ") .. " }"
end

-- ---------------------------------------------------------------- Stauchen unter die reservierte Fläche
local function ganz(v) return math.type(v) == "integer" end
local function stauche(a)
  local R = RES[tostring(a.breite) .. "x" .. tostring(a.hoehe)]
  if not R or R <= 0 or not ganz(a.hoehe) then return 0 end
  local H = a.hoehe
  local function m(y) return R + (y * (H - R)) // H end
  local n = 0
  local function rechteck(e)                              -- x, y, b, h ganz in der Ansicht
    if ganz(e.y) and ganz(e.h) and e.y >= 0 and e.h >= 1 and e.y + e.h <= H then
      local y1, y2 = m(e.y), m(e.y + e.h)
      e.y, e.h = y1, math.max(1, y2 - y1)
      n = n + 1
    end
  end
  for _, p in ipairs(type(a.plaetze) == "table" and a.plaetze or {}) do
    if type(p) == "table" then rechteck(p) end
  end
  for _, e in ipairs(type(a.deko) == "table" and a.deko or {}) do
    if type(e) == "table" then
      if e.art == "linie" then
        if ganz(e.y) and ganz(e.h) and e.y >= 0 and e.y < H and e.y + e.h >= 0 and e.y + e.h < H then
          local y1, y2 = m(e.y), m(e.y + e.h)
          local alt = e.h
          e.y, e.h = y1, y2 - y1
          -- eine gültige senkrechte Linie darf durch das Stauchen nicht die Länge 0 bekommen (Linie ohne Länge bleibt 0)
          if e.h == 0 and alt ~= 0 then e.h = alt > 0 and 1 or -1 end
          n = n + 1
        end
      elseif e.art == "symbol" then
        local k = ganz(e.px) and math.floor(e.px * 800 / 800 + 0.5) or nil   -- Bezugsbreite: Kante = px
        if ganz(e.y) and k and e.y >= 0 and e.y + k <= H then
          e.y = math.min(m(e.y), H - k)
          n = n + 1
        end
      else
        rechteck(e)
      end
    end
  end
  return n
end

local function schreibe(name, d)
  local t = "return " .. wert(d) .. "\n"
  local f = assert(io.open(ZIEL .. name .. ".helirf.lua", "wb"))
  f:write(t)
  f:close()
  return #t
end

os.execute("mkdir -p '" .. ZIEL .. "'")
local p = io.popen('ls "' .. QUELLE .. '"')
local namen = {}
for n in p:read("a"):gmatch("[^\n]+") do if n:find("^p%d%d_.*%.lua$") then namen[#namen + 1] = n end end
p:close()
table.sort(namen)
assert(#namen >= 11, "Testdateien nicht gefunden in " .. QUELLE)
for _, n in ipairs(namen) do
  local text = assert(lies(QUELLE .. "/" .. n))
  local d = assert(load(text, "=" .. n, "t", {}))()
  local verschoben = 0
  for _, a in ipairs(type(d.ansichten) == "table" and d.ansichten or {}) do verschoben = verschoben + stauche(a) end
  local k = n:gsub("%.lua$", "")
  local byte = schreibe(k, d)
  print(string.format("%-34s %6d Byte (Original %6d), %3d Elemente verschoben", k .. ".helirf.lua", byte, #text, verschoben))
  if k == "p11_format1" then
    -- Vergleich für Test 11: dieselbe Datei ohne Format-2-Felder
    d.symbole = nil
    for _, a in ipairs(d.ansichten or {}) do
      a.deko = nil
      for _, pl in ipairs(a.plaetze or {}) do pl.symbol, pl.symbolPx, pl.einheitZeigen = nil, nil, nil end
    end
    print(string.format("%-34s %6d Byte", "p11_format1_ohne.helirf.lua", schreibe("p11_format1_ohne", d)))
  end
end

-- Regel 7.2: je 60 Einträge (Funke verwirft ab dem 49.)
do
  local d = { format = 2, werte = {}, grenzen = {}, einstellungen = {},
    ansichten = { { breite = 800, hoehe = 480, plaetze = { { x = 10, y = 70, b = 380, h = 120, w = "sensor:0A00:0", titel = "Test" } } } } }
  for i = 1, 60 do
    d.werte[string.format("sensor:%04X:0", 0x5100 + i)] = { faktor = 1.5, stellen = 1 }
    d.grenzen[string.format("sensor:%04X:0", 0x5100 + i)] = { richtung = "ueber", warnung = 50, alarm = 60 }
    d.einstellungen["e" .. i] = i
  end
  print(string.format("%-34s %6d Byte", "l72_listen.helirf.lua", schreibe("l72_listen", d)))
end
-- Regel 7.5: Sensor-Grenze mit ansage = false, vibration = false: Alarm spielt trotzdem einen Ton
do
  local d = { format = 2,
    grenzen = { ["sensor:0A00:0"] = { richtung = "ueber", alarm = 100, ansage = false, vibration = false } },
    ansichten = { { breite = 800, hoehe = 480, plaetze = { { x = 10, y = 70, b = 380, h = 120, w = "sensor:0A00:0", titel = "Stumm" } } } } }
  print(string.format("%-34s %6d Byte", "a75_stumm.helirf.lua", schreibe("a75_stumm", d)))
end
print("Ziel: " .. ZIEL)
