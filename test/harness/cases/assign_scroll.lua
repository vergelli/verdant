return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SC = Verdant.SkillColors
  local A  = Verdant.Assign

  H.ability_icons = H.ability_icons or {}
  H.ability_names = H.ability_names or {}
  for i = 1, 20 do
    local id = 990000 + i
    H.ability_icons[id] = "/esoui/art/icons/ability_mystery_" .. i .. ".dds"
    H.ability_names[id] = "Mystery " .. i
    SC.group_of(id)
  end
  local n_unknown = #SC.get_unknowns()
  ok(n_unknown >= 20, "twenty unknown skills must be logged, got " .. n_unknown)

  A.show_reset_scroll()
  A.show()
  local function visible_names()
    local out, n = {}, 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if name:find("^VerdantAssignRow%d+Name$") and c._hidden ~= true and c._text then
        local p = c._parent
        if p and p._hidden == false then out[c._text] = true; n = n + 1 end
      end
    end
    return out, n
  end
  local before, n_before = visible_names()
  ok(n_before > 0 and n_before < n_unknown, "the list shows a page, not everything: " .. n_before)
  local help = VerdantAssignPanelHelpLabel._text or ""
  ok(help:find("wheel") ~= nil and help:find("below") ~= nil, "the help line says there is more and how to reach it: " .. help)

  H.sounds = {}
  A.on_scroll(-1)
  local after, n_after = visible_names()
  ok(n_after == n_before, "scrolling keeps the page size")
  local moved = false
  for name in pairs(after) do if not before[name] then moved = true end end
  ok(moved, "scrolling down reveals a hidden skill")
  ok(H.sounds[#H.sounds] == "sound:DEFAULT_CLICK", "scrolling clicks")

  for _ = 1, 40 do A.on_scroll(-1) end
  local bottom = VerdantAssignPanelHelpLabel._text or ""
  ok(bottom:find("^0 more below") ~= nil, "scrolling clamps at the bottom: " .. bottom)
  for _ = 1, 40 do A.on_scroll(1) end
  local top, n_top = visible_names()
  ok(n_top == n_before, "scrolling back up restores the first page")
  for name in pairs(before) do ok(top[name], "first page must come back: " .. name) end

  A.hide()
end
