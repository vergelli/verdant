return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local S  = Verdant.Settings
  local sv = Verdant.SavedVars

  S.on_profile_selected("pvp")
  eq(S.snapshot().rate_ms, 200, "pvp preset rate")

  VerdantSettingsPanelPNameBoxEdit:SetText("Raid Night")
  S.on_profile_save_click()

  ok(sv.settings.user_profiles["Raid Night"], "user profile not persisted")
  eq(sv.settings.user_profiles["Raid Night"].rate, 200, "saved rate")
  eq(sv.settings.profile, "user:Raid Night", "profile id not persisted")
  eq(S.snapshot().profile_label, "* Raid Night", "profile label")

  S.on_profile_selected("solo")
  eq(S.snapshot().rate_ms, 1000, "solo preset rate")

  S.on_profile_selected("user:Raid Night")
  eq(S.snapshot().rate_ms, 200, "loading user profile must restore rate")
  eq(S.snapshot().time_window_s, 30, "loading user profile must restore window")

  VerdantSettingsPanelPNameBoxEdit:SetText("")
  S.on_profile_save_click()
  ok(sv.settings.user_profiles["Raid Night"], "empty-name save must overwrite selected user profile")

  S.on_profile_delete_click()
  ok(VerdantSettingsConfirm._hidden == false, "deleting a profile asks first")
  ok((VerdantSettingsConfirmMsg._text or ""):find("Raid Night", 1, true), "the question names the profile")
  S.on_confirm_no()
  ok(sv.settings.user_profiles["Raid Night"] and VerdantSettingsConfirm._hidden == true, "Keep leaves the profile alone")
  S.on_profile_delete_click()
  S.on_confirm_yes()
  eq(sv.settings.user_profiles["Raid Night"], nil, "delete must remove the profile")
  eq(S.snapshot().profile_id, "custom", "after delete fall back to custom")

  S.on_profile_delete_click()
  S.on_profile_selected("solo")
  eq(S.snapshot().rate_ms, 1000, "builtin presets must survive the feature")
end
