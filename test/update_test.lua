-- Heli RF: Update-Test. Eine ältere Version (aus einem Git-Tag) schreibt Einstellungen, die aktuelle liest sie.
-- Aufruf über test/update_test.py. storage arbeitet wie Ethos nach Reihenfolge (Schlüssel egal).
-- Update-Test: alte Version schreibt Einstellungen (storage nach Reihenfolge, Schlüssel egal), neue liest sie.
local werte, pos = {}, 0
local GRENZE = 51                            -- Ethos: rund 256 Byte = 51 Werte, danach «Max size reached»
storage = { write = function(_, v) if #werte >= GRENZE then error("Max size reached") end werte[#werte + 1] = v end, read = function() pos = pos + 1 return werte[pos] end }
local function q(n) return { name = function() return n end, value = function() return 0 end } end
local neuK = dofile(arg[2])
local fehler = 0
for alt in (arg[3] or ""):gmatch("%S+") do
  local A = dofile(arg[1] .. "/kern_" .. alt .. ".lua")
  werte, pos = {}, 0
  local w = { cfg = {} }
  A.lies(w)                                  -- leer: Werkswerte der alten Version
  local c = w.cfg
  c.zellen, c.kapaz, c.warnGrenze, c.warnOrange, c.swAus, c.autoSek, c.aZelleGrenze, c.sprache = 12, 5000, 85, 75, 2, 7, 340, 2
  c.qProz, c.qMotor, c.qRpm = q("Bat%"), q("SF"), q("Headspeed")
  local mitTyp = A.lies and (io.open(arg[1] .. "/kern_" .. alt .. ".lua"):read("a")):find("akkutyp", 1, true) ~= nil
  if mitTyp then c.akkutyp = 2 end
  werte, pos = {}, 0
  A.schreibe(w)
  local n = #werte
  pos = 0
  local w2 = { cfg = {} }
  neuK.lies(w2)
  local d = w2.cfg
  local ok = d.zellen == 12 and d.kapaz == 5000 and d.warnGrenze == 85 and d.warnOrange == 75 and d.swAus == 2
    and d.autoSek == 7 and d.aZelleGrenze == 340 and d.sprache == 2 and d.qProz and d.qProz:name() == "Bat%"
    and d.qMotor and d.qMotor:name() == "SF" and d.qRpm and d.qRpm:name() == "Headspeed"
    and d.akkutyp == (mitTyp and 2 or 1) and d.mAus == 31
  if not ok then fehler = fehler + 1 end
  print(string.format("%s -> neu: %d Werte, %s  (zellen %s kapaz %s warn %s/%s swAus %s auto %s zelle %s akkutyp %s)",
    alt, n, ok and "ALLES ÜBERNOMMEN" or "FEHLER", tostring(d.zellen), tostring(d.kapaz), tostring(d.warnOrange),
    tostring(d.warnGrenze), tostring(d.swAus), tostring(d.autoSek), tostring(d.aZelleGrenze), tostring(d.akkutyp)))
end
-- 1.12.0: neue Fassung schreibt und liest selbst; mAus steckt im Platz von swAus (Format 6), Speicher wie Ethos begrenzt
for _, fall in ipairs({ { 1, 31 }, { 2, 0 }, { 3, 21 }, { 3, 0 }, { 1, 30 } }) do
  werte, pos = {}, 0
  local w = { cfg = {} }
  neuK.lies(w)
  w.cfg.swAus, w.cfg.mAus, w.cfg.qMotor = fall[1], fall[2], q("SF")
  neuK.schreibe(w)
  local n = #werte
  pos = 0
  local w2 = { cfg = {} }
  neuK.lies(w2)
  local ok = w2.cfg.swAus == fall[1] and w2.cfg.mAus == fall[2] and n <= GRENZE - 1
  if not ok then fehler = fehler + 1 end
  print(string.format("neu -> neu: swAus %d mAus %2d: %d Werte (Reserve %d), gelesen swAus %s mAus %s %s", fall[1], fall[2], n,
    GRENZE - n, tostring(w2.cfg.swAus), tostring(w2.cfg.mAus), ok and "ok" or "FEHLER"))
end
print(fehler == 0 and "UPDATE-TEST BESTANDEN" or ("UPDATE-TEST FEHLER: " .. fehler))
os.exit(fehler == 0 and 0 or 1)
