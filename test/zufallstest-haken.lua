-- Heli: Haken für den Zufallstest im fensterlosen Ethos-Simulator. Kein Teil des Widgets.
-- test/zufallstest.py setzt diesen Text beim Kopieren in den Simulator an die Stelle der Zeile
--   «  v.sender = zahl(w.qSender)» in kern.lua (Funktion lesen), die echten Dateien bleiben unverändert.
-- Bei jedem Weckruf bekommen alle Werte Zufalls- und Extremwerte (nil, 0, negativ, riesig, krumm), dazu zufällige
-- Seite, Rückfrage, Flugliste, Sprache und zufälliges Tippen und Wischen. Alle 400 Durchläufe eine Zeile «Heli FUZZ».
-- Bestanden: «Fehler nil», «Ereignis-Fehler 0» und kein stetig wachsender Lua-Speicher.
  v.sender = zahl(w.qSender)
  do
    FZ = (FZ or 0) + 1
    if FZ == 1 then F0 = os.clock() collectgarbage() M0 = collectgarbage("count")
      FN = { play = 0 }
      system.playNumber = function() FN.play = FN.play + 1 end
      system.playTone = function() end system.playHaptic = function() end
    end
    local werte = { nil, 0, -1, -0.0001, 0.4, 1, 3.3, 79.9, 80, 80.1, 99999, -99999, 1e8, 123456.789, 2400, 2401, 250, 100, 4.2, 50.4 }
    local function z() local i = math.random(1, #werte + 3) return werte[i] end
    v.tele = math.random(1, 12) > 1
    v.volt, v.rpm, v.strom, v.temp, v.bec, v.mah, v.rssi = z(), z(), z(), z(), z(), z(), z()
    v.pid, v.rate, v.gas, v.zelle, v.proz, v.zellen = z(), z(), z(), z(), z(), z()
    v.becTief, v.zelleTief = z(), z()
    v.gov = ({ nil, 0, 4, 6, 9, 12, -1 })[math.random(1, 8)] v.scharf = ({ true, false })[math.random(1, 3)]
    v.mahRoh = z() w.mahNull = math.random(0, 3) * 700 if math.random(1, 40) == 1 then w.anker = { math.random(0, 100), math.random(0, 3000) } end if math.random(1, 25) == 1 then w.anker = nil end
    local namen = { nil, "", "N", "Normal", "Idle 1", "Ein sehr langer Flugphasenname mit Umlauten äöü ÄÖÜ", "°C %d %s \n x" }
    v.modus = namen[math.random(1, #namen + 1)]
    if math.random(1, 6) == 1 then w.seite = math.random(1, 2) end
    if math.random(1, 30) == 1 then w.dialog = ({ "flug", "mah", "liste", "unsinn" })[math.random(1, 5)] end
    if math.random(1, 10) == 1 then w.wahl = z() end
    if math.random(1, 40) == 1 then local l = {} for i = 1, math.random(0, 25) do l[i] = { z() or i, z(), z(), z(), z(), z(), z(), z(), z() } end w.liste = l end
    if math.random(1, 50) == 1 then w.akt = math.random(1, 2) == 1 and { dauer = z() or 0, nr = z(), mah = z(), pause = math.random(1, 2) == 1 } or nil end
    c.swAus = math.random(1, 3)
    w.autoAn = math.random(1, 3) == 1 c.autoSek = math.random(0, 3) w.ab = z() c.sprache = math.random(0, 2)
    if not FSTUB then FSTUB = true system.playFile = function() FN.play = FN.play + 1 end end
    do local ok, e = pcall(K.ereignis, w, EVT_TOUCH, ({ TOUCH_START, TOUCH_MOVE, TOUCH_END })[math.random(1, 3)], math.random(0, 800), math.random(0, 480)) if not ok then FE = (FE or 0) + 1 if FE < 4 then print("Heli FUZZ Fehler ereignis: " .. tostring(e)) end end end
    if FZ % 400 == 0 then print("Heli FUZZ Ereignis-Fehler " .. tostring(FE or 0) .. ", Liste " .. #w.liste .. ", Seite " .. w.seite) end
    c.zellen = math.random(0, 14) c.kapaz = math.random(0, 3) * 5000
    c.flugSek = 5 c.warnTakt = 2
    if FZ % 400 == 0 then collectgarbage()
      print(string.format("Heli FUZZ %5.1f s, Durchlauf %d, Lua-Speicher %+.1f KB seit Start, Ansagen %d, Fluege %d, Fehler %s", os.clock() - F0, FZ, collectgarbage("count") - M0, FN.play, w.fluege, tostring(w.fehler)))
    end
  end
