return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local Hitch = Verdant.Hitch

  ok(H.update_registered("VerdantHitch"), "the hitch watcher runs every frame")
  Hitch.reset()
  local t = 100000
  for _ = 1, 10 do
    t = t + 16
    Hitch.observe(t)
  end
  local frames, hitches = Hitch.stats()
  ok(frames >= 9 and hitches == 0, "smooth frames are not hitches: frames=" .. frames .. " hitches=" .. hitches)

  t = t + 284
  Hitch.observe(t)
  local _, n1, worst = Hitch.stats()
  ok(n1 == 1 and worst == 284, "a 284ms frame is a hitch, got n=" .. n1 .. " worst=" .. worst)
  local lines = Hitch.lines()
  ok(#lines >= 2 and lines[2]:find("idle") ~= nil, "a hitch with no Verdant work is reported idle: " .. tostring(lines[2]))

  Hitch.mark("tick")
  Hitch.mark("render")
  t = t + 120
  Hitch.observe(t)
  lines = Hitch.lines()
  ok(lines[2]:find("tick%+render") ~= nil, "a hitch on a busy frame names the work: " .. tostring(lines[2]))
  t = t + 16
  Hitch.observe(t)
  local _, n2 = Hitch.stats()
  ok(n2 == 2, "marks are consumed by the frame they happened in")

  for _ = 1, 20 do
    Hitch.mark("stop")
    t = t + 90
    Hitch.observe(t)
  end
  lines = Hitch.lines()
  ok(#lines == 13, "the log keeps the last twelve hitches, got " .. #lines)
  ok(lines[2]:find("stop") ~= nil, "the newest hitch comes first")

  Hitch.reset()
  local f0, h0, w0 = Hitch.stats()
  ok(f0 == 0 and h0 == 0 and w0 == 0, "reset clears everything")
end
