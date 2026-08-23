return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Verdant.SessionStore
  local sv = Verdant.SavedVars

  sv.library = { version = 1, sessions = {} }
  sv.settings = sv.settings or {}
  sv.settings.session_autosave = true
  H.state.grouped = true
  H.state.group_size = 2
  H.state.player_group_tag = "group1"
  H.unit_names = { group1 = "Me1", group2 = "Ally2" }
  H.fire(EVENT_GROUP_UPDATE)

  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_record_click()
  H.heal({ hit = 900, target_name = "Ally2", target_unit_id = 602 })
  H.effect(EFFECT_RESULT_GAINED, 111, 602, 0)
  H.power("group2", 15000, 40000)
  H.advance(600)
  H.heal({ hit = 2500, target_name = "Ally2", target_unit_id = 602 })
  H.power("group2", 25000, 40000)
  H.advance(2600)
  H.death(true)
  H.death(false)
  H.advance(1500)
  Verdant.Graph.on_stop_click()

  for _ = 1, 5 do Verdant.Graph.next_view() end
  VerdantSettingsPanel._hidden = true
  Verdant.Settings.toggle()
  Verdant.Library.show()
  Verdant.Library.on_row_click(1)
  Verdant.Assign.show()

  local canvas = VerdantGraphWindowViewportCanvas
  H.state.mouse_x = canvas:GetLeft() + 100
  H.state.mouse_y = canvas:GetTop() + 60
  local hit = VerdantGraphHitMain
  if hit._onOnMouseEnter then hit._onOnMouseEnter(hit) end
  H.advance(200)

  local offenders = {}
  for _, c in ipairs(H.controls) do
    local is_texture = (c._ctype == CT_TEXTURE) or (c._xml_tag == "Texture")
    if is_texture and c._hidden == false and c._tex == nil and c._r ~= nil then
      offenders[#offenders + 1] = tostring(c._name or "?")
    end
  end
  ok(#offenders == 0,
     "colored textures without a texture file render INVISIBLE in the live client: "
     .. table.concat(offenders, ", "))

  local fly = VerdantAssignPanelFlyoutFill
  ok(fly._tex ~= nil and fly._tex:find("attributeBar"), "flyout floor must use the fill texture")

  Verdant.Assign.hide()
  Verdant.Library.hide()
  Verdant.Settings.toggle()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  sv.settings.session_autosave = false
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  H.state.mouse_x, H.state.mouse_y = 400, 300
end
