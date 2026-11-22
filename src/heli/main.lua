-- Heli: Vollbild-Anzeige für Helis (Ethos-Widget).
-- Diese Datei meldet nur das Widget an. Die Arbeit steckt in kern.lua und wird erst beim ersten Gebrauch geladen.
-- NAME, VERSION und INFO liest auch das Paket-Skript für die FrSky Suite.
local NAME = "Heli"
local VERSION = "1.14.2"
local INFO = "Vollbild-Anzeige für Helis: Tachos, Alarme in zwei Stufen, Drehzahl- und Autorotation-Ansage, Flugliste, Einstellungsdatei für Lua-Studio. Deutsch und Englisch."
local K = nil
local gemeldet = {}
local lebend = 0          -- Zahl der Widget-Instanzen, die Ethos noch hält

-- Speicher freigeben (Auftrag 21.11.2026): Ethos 26.2 meldet kein «close». Nach einem Modellwechsel verwirft Ethos die
-- Widget-Tabelle; ihr Finalizer läuft bei der nächsten Müllabfuhr. Lebt keine Instanz mehr, fällt der Verweis auf den Kern,
-- und mit ihm Studio-Daten, Masken, Übersetzungen und Module. Nichts Ungesichertes geht verloren: Flugliste und offener Flug
-- liegen laufend in der Datendatei, Einstellungen speichert Ethos über write. Kein collectgarbage im Finalizer
-- (in Lua 5.4 dort wirkungslos); Ethos räumt bei seiner nächsten Müllabfuhr auf.
local function verworfen()
  lebend = lebend - 1
  if lebend <= 0 then
    lebend = 0
    K = nil
    gemeldet = {}
  end
end

local function kern()
  if K == nil then
    local f, e = loadfile("kern.lua")
    if not f then error(e, 0) end
    K = f()
    K.VERSION = VERSION
  end
  return K
end

-- Ein Fehler im Skript darf die Funke nicht stören: einmal melden und weiterlaufen.
local function ruf(name, w, ...)
  local ok, a = pcall(function(...) return kern()[name](w, ...) end, ...)
  if ok then return a end
  if not gemeldet[name] then
    gemeldet[name] = true
    print("Heli: Fehler in " .. name .. ": " .. tostring(a))
  end
  if type(w) == "table" then
    w.fehler = name .. ": " .. tostring(a)
    w.fehlerZeit = os.clock()
  end
  return nil
end

local function create()
  local ok, w = pcall(function() return kern().neu() end)
  if ok and type(w) == "table" then
    lebend = lebend + 1
    setmetatable(w, { __gc = verworfen })
    return w
  end
  print("Heli: Fehler in create: " .. tostring(w))
  lebend = lebend + 1                          -- auch diese Instanz kann den Kern laden (ruf): mitzählen
  return setmetatable({ fehler = "create: " .. tostring(w) }, { __gc = verworfen })
end

-- Nach einem Skript-Reload ruft Ethos die Widgets teils ohne Widget-Objekt auf: dann nichts tun (gemessen 19.11.2026, X18RS)
local function gueltig(w) return type(w) == "table" end

local function paint(w)
  if not gueltig(w) then return end
  if w.cfg then ruf("zeichne", w) end
  if w.fehler and w.fehlerZeit and os.clock() - w.fehlerZeit > 15 then w.fehler = nil end   -- alter Fehler: ausblenden
  if w.fehler then                             -- Fehler sichtbar über dem Bild, unten links
    local _, H = lcd.getWindowSize()
    lcd.font(FONT_S)
    lcd.color(lcd.RGB(0, 0, 0))
    lcd.drawFilledRectangle(0, H - 26, lcd.getTextSize("Heli: " .. w.fehler) + 16, 26)
    lcd.color(lcd.RGB(239, 68, 68))
    lcd.drawText(8, H - 24, "Heli: " .. w.fehler)
  end
end

local function init()
  system.registerWidget({
    key = "heli",
    name = NAME,
    create = create,
    wakeup = function(w) if gueltig(w) and w.cfg then ruf("wecke", w) end end,
    paint = paint,
    event = function(w, kat, wert, x, y) if gueltig(w) and w.cfg then return ruf("ereignis", w, kat, wert, x, y) end end,
    configure = function(w) if gueltig(w) and w.cfg then ruf("menue", w) end end,
    read = function(w) if gueltig(w) and w.cfg then ruf("lies", w) end end,
    write = function(w) if gueltig(w) and w.cfg then ruf("schreibe", w) end end,
    title = false,
  })
end

return { init = init }
