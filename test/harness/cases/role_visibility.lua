return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local V = Verdant.Visibility
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  local before_role, before_bar, before_graph = sv.settings.role_only, V.get("bar"), V.get("graph")
  local bar = VerdantBarWindow
  local btn = VerdantSettingsPanelRoleBtn

  H.state.lfg_role = LFG_ROLE_DPS
  V.set_role_only(false)
  V.set("graph", false)
  V.set("bar", true)
  ok(bar._hidden == false, "with the setting off the bar shows on a DPS role")
  ok(btn ~= nil and btn._text == "Healer only: Off", "settings button reads Off by default, got " .. tostring(btn and btn._text))

  H.sounds = {}
  Verdant.Settings.on_role_click()
  ok(sv.settings.role_only == true and V.get_role_only(), "the button turns the role gate on and persists it")
  ok(btn._text == "Healer only: On", "the button reads On, got " .. tostring(btn._text))
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "turning it on confirms with the accept sound")
  ok(bar._hidden == true, "a DPS role hides the bar once the gate is on")
  ok(V.get("bar") == true and sv.bar.visible == true, "the stored visibility choice is untouched")
  ok(not V.role_allows_bar(), "the gate reports the mismatch")

  H.set_role(LFG_ROLE_HEAL, "group3")
  ok(bar._hidden == true, "a role change for another group member is ignored")

  H.set_role(LFG_ROLE_HEAL)
  ok(bar._hidden == false, "switching to Healer brings the bar back")
  ok(V.role_allows_bar(), "the gate reports the match")

  H.set_role(LFG_ROLE_TANK)
  ok(bar._hidden == true, "Tank hides the bar again")

  V.set("graph", true)
  ok(VerdantGraphWindow._hidden == false, "the graph opens by hand whatever the role")
  V.set("graph", false)

  Verdant.Visibility.master_toggle()
  ok(V.get("bar") == false, "the master toggle still flips the stored choice")
  Verdant.Visibility.master_toggle()
  ok(V.get("bar") == true and bar._hidden == true, "toggled back on, the bar stays hidden while the role mismatches")

  H.state.lfg_role = LFG_ROLE_HEAL
  H.fire(EVENT_PLAYER_ACTIVATED)
  ok(bar._hidden == false, "the role is re-read on player activation")

  H.state.lfg_role = LFG_ROLE_DPS
  H.fire(EVENT_PLAYER_ACTIVATED)
  ok(bar._hidden == true, "and re-read again on the next activation")

  Verdant.Settings.on_role_click()
  ok(sv.settings.role_only == false, "the button turns the gate off")
  ok(bar._hidden == false, "with the gate off the role no longer matters")

  V.set_role_only(before_role == true)
  V.set("bar", before_bar)
  V.set("graph", before_graph)
  H.state.lfg_role = nil
end
