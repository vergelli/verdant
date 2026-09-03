return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function near(a, b) return math.abs(a - b) < 1e-6 end

  local Donut = Verdant.lib.plot.Donut
  local TAU = 2 * math.pi
  local colors = {
    { r = 0.4, g = 0.8, b = 0.5 },
    { r = 0.9, g = 0.8, b = 0.3 },
    { r = 0.6, g = 0.6, b = 0.6 },
  }

  local d = Donut.new("VerdantTestDonut", GuiRoot, 96, { mode = "origin" })
  ok(d:set({ 50, 30, 20 }, colors) == 3, "three positive values make three slices")
  local s1, s2, s3 = VerdantTestDonutSlice1, VerdantTestDonutSlice2, VerdantTestDonutSlice3
  ok(s1._ctype == CT_COOLDOWN, "slices are cooldown controls")
  ok(s1._tex == "Verdant/assets/ring.dds", "slices use the ring texture")
  ok(near(s1._cd_pct, 0.5) and near(s2._cd_pct, 0.3) and near(s3._cd_pct, 0.2),
     "each slice fills its own share")
  ok(near(s1._cd_origin, 0) and near(s2._cd_origin, 0.5 * TAU) and near(s3._cd_origin, 0.8 * TAU),
     "origins accumulate around the ring in radians")
  ok(near(s2._fr, 0.9) and near(s2._fg, 0.8), "fill color comes from the palette")
  ok(s1._cd_type == CD_TYPE_RADIAL, "slices are radial")

  ok(d:set({ 50, 0, 50 }, colors) == 2, "a zero value drops its slice")
  ok(s3._hidden == true, "the spare slice control hides")
  ok(near(s2._cd_pct, 0.5) and near(s2._cd_origin, 0.5 * TAU), "the remaining slices close ranks")

  ok(d:set({ 0, 0, 0 }, colors) == 0, "no data draws nothing")
  ok(s1._hidden == true, "all slices hide on empty data")

  local deg = Donut.new("VerdantTestDonutDeg", GuiRoot, 64, { origin_unit = "deg" })
  deg:set({ 1, 1 }, colors)
  ok(near(VerdantTestDonutDegSlice2._cd_origin, 180), "degree mode scales the origin to 360")

  local st = Donut.new("VerdantTestDonutStack", GuiRoot, 64, { mode = "stack" })
  st:set({ 50, 30, 20 }, colors)
  local a, b, c = VerdantTestDonutStackSlice1, VerdantTestDonutStackSlice2, VerdantTestDonutStackSlice3
  ok(near(a._cd_pct, 0.5) and near(b._cd_pct, 0.8) and near(c._cd_pct, 1.0),
     "stack mode draws cumulative arcs")
  ok(a._draw_level > b._draw_level and b._draw_level > c._draw_level,
     "stack mode keeps the first slice on top")

  if HARNESS_DEBUG then
    Verdant.DonutProbe.toggle()
    ok(Verdant.DonutProbe.is_shown(), "the probe window opens")
    ok(VerdantDonutProberadSlice1 ~= nil and VerdantDonutProbestackSlice3 ~= nil,
       "the probe builds every variant")
    Verdant.DonutProbe.toggle()
    ok(not Verdant.DonutProbe.is_shown(), "the probe window toggles closed")
  end
end
