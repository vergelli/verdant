return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()

  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.ability_names = { [7701] = "Big Heal", [7702] = "Small Heal", [7703] = "Big Heal", [8801] = "Ward" }
  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 8801, 600, 0)
  for _ = 1, 6 do
    H.heal({ hit = 3000, ability_id = 7701 })
    H.heal({ hit = 500, ability_id = 7703 })
    H.heal({ hit = 1000, ability_id = 7702 })
    H.shield({ hit = 500, ability_id = 8801, target_unit_id = 600 })
    H.advance(1000)
  end
  H.effect(EFFECT_RESULT_FADED, 8801, 600, 0)
  Verdant.Graph.on_stop_click()

  while view_label._text ~= "CONTRIB" do Verdant.Graph.next_view() end
  ok(VerdantGraphWindowViewportCanvas._hidden ~= true, "main canvas must be visible on CONTRIB")
  ok(VerdantGraphWindowViewportSkillArea._hidden == true, "skill area must hide on CONTRIB")
  ok(VerdantGraphWindowViewportNoDataLabel._hidden == true, "no-data must hide when there are contributions")

  local rows, n = Verdant.ContribView.rows()
  ok(n == 3, "three rows expected (two heal names, one shield), got " .. tostring(n))
  ok(rows[1].name == "Big Heal" and rows[1].ch == 0, "Big Heal must rank first")
  ok(rows[1].n == 2, "the two Big Heal ability ids merge into one row, got " .. tostring(rows[1].n))
  ok(rows[2].name == "Small Heal" and rows[2].ch == 0 and rows[2].n == 1, "Small Heal must rank second")
  ok(rows[3].name == "Ward" and rows[3].ch == 1, "Ward must rank last as a shield")
  ok(rows[1].v > rows[2].v and rows[2].v > rows[3].v, "rows must be sorted by value")
  local ratio = rows[1].v / rows[2].v
  ok(ratio > 3.0 and ratio < 4.0, "Big Heal must weigh about three and a half Small Heals, got " .. tostring(ratio))

  local texts = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantBuffLbl") and c._text then texts[c._text] = true end
  end
  ok(texts["CONTRIBUTION"] and texts["TYPE"] and texts["VALUE"], "column headers must render")
  ok(texts["Big Heal"] and texts["Small Heal"] and texts["Ward"], "every ability name must render")
  local big_rows = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantBuffLbl") and c._text == "Big Heal" then big_rows = big_rows + 1 end
  end
  ok(big_rows == 1, "a skill with two ability ids renders as one row, got " .. big_rows)
  ok(texts["Heal"] and texts["Shield"], "type column must read Heal and Shield")

  local icons = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantBuffIcon") then icons = icons + 1 end
  end
  ok(icons == 3, "one icon per row, got " .. icons)

  local widths = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantBuffSeg") and c._h == 5 and (c._a or 0) > 0.5 then
      widths[#widths + 1] = c._w
    end
  end
  table.sort(widths, function(a, b) return a > b end)
  ok(#widths == 3, "one coloured bar per row, got " .. #widths)
  ok(widths[1] > widths[2] and widths[2] > widths[3], "bars must shrink with the value")
  ok(math.abs(widths[1] / widths[2] - ratio) < 0.35, "bar widths must follow the value ratio")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  local chip_h = (VerdantGraphSummaryBg._hidden == false) and (VerdantGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 60
  H.state.mouse_y = canvas:GetTop() + chip_h + 20 + 12
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VerdantHoverCardName._text == "Big Heal", "hovering the first row must name the skill, got " .. tostring(VerdantHoverCardName._text))
  ok(VerdantHoverCardStat._text and VerdantHoverCardStat._text:find("Heal", 1, true)
     and VerdantHoverCardStat._text:find("%d+%%") and VerdantHoverCardStat._text:find("estimated", 1, true),
     "row hover must show type, share and the estimate note, got " .. tostring(VerdantHoverCardStat._text))
  ok(VerdantHoverCardStat._text:find("2 parts", 1, true), "row hover must count the merged ability ids, got " .. tostring(VerdantHoverCardStat._text))
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local SS = Verdant.SessionStore
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  SS.init()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 2000, ability_id = 7701 })
  H.advance(1000)
  H.heal({ hit = 2000, ability_id = 7701 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "autosave must have stored the session")
  Verdant.Graph.on_flush_click()
  ok(Verdant.Graph.load_session(SS.get(1)) ~= false, "the saved session must load")
  while view_label._text ~= "CONTRIB" do Verdant.Graph.next_view() end
  local lrows, ln = Verdant.ContribView.rows()
  ok(ln >= 1 and lrows[1].name == "Big Heal", "a library session must render the view from its saved shares")
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()

  Verdant.Graph.on_flush_click()
  H.ability_names = nil
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Metrics.reset()
end
