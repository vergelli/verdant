return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local S  = Verdant.Settings
  local sv = Verdant.SavedVars

  eq(S.snapshot().profile_id, "custom", "without built-in presets the panel starts on Custom")
  ok(S.on_profile_selected("solo") == nil and S.snapshot().profile_id == "custom", "an old preset id is ignored")
  sv.settings.user_profiles = sv.settings.user_profiles or {}
  sv.settings.user_profiles["PvP Night"] = { rate = 200, heal = 3000, shield = 5000, sample = 200, twindow = 30 }
  S.on_profile_selected("user:PvP Night")
  eq(S.snapshot().rate_ms, 200, "a user profile applies its rate")

  VerdantSettingsPanelPNameBoxEdit:SetText("Raid Night")
  S.on_profile_save_click()

  ok(sv.settings.user_profiles["Raid Night"], "user profile not persisted")
  eq(sv.settings.user_profiles["Raid Night"].rate, 200, "saved rate")
  eq(sv.settings.profile, "user:Raid Night", "profile id not persisted")
  eq(S.snapshot().profile_label, "* Raid Night", "profile label")

  S.on_reset_click()
  eq(S.snapshot().rate_ms, 1000, "reset restores the default rate")
  eq(S.snapshot().time_window_s, 60, "reset restores the default window")
  eq(S.snapshot().profile_id, "custom", "reset lands on Custom")

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
  eq(S.snapshot().profile_id, "custom", "deleting with nothing selected keeps Custom")
  sv.settings.user_profiles["PvP Night"] = nil
end
