return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SC = Verdant.SkillColors
  local A  = Verdant.Assign

  A.show()
  ok(VerdantAssignPanel._hidden == false, "assign window opens")
  local new_entry = nil
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if name:find("^VerdantAssignFlyoutE") and c._hidden == false and c._text == "+ New category" then new_entry = c end
  end
  ok(new_entry ~= nil, "the flyout ends with the new-category entry")

  A.open_newcat_for_test(880001)
  ok(VerdantAssignPanelNewCat._hidden == false, "the new-category panel opens")
  ok(VerdantAssignSwatchRim1._hidden == false and VerdantAssignSwatchRim2._hidden == true, "first swatch starts selected")

  H.sounds = {}
  VerdantAssignPanelNewCatNameBoxEdit:SetText("   ")
  A.on_newcat_create()
  ok(H.sounds[#H.sounds] == "sound:NEGATIVE_CLICK", "an empty name refuses with the negative click")
  ok(VerdantAssignPanelNewCat._hidden == false, "the panel stays open after a refusal")

  A.on_newcat_swatch(5)
  ok(VerdantAssignSwatchRim5._hidden == false and VerdantAssignSwatchRim1._hidden == true, "picking a swatch moves the rim")
  VerdantAssignPanelNewCatNameBoxEdit:SetText("Pets")
  H.sounds = {}
  A.on_newcat_create()
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "creating confirms with the accept sound")
  ok(VerdantAssignPanelNewCat._hidden == true, "the panel closes after creating")
  ok(SC.is_group("custom_pets") and SC.group_label("custom_pets") == "Pets", "the group exists with its label")
  local col = SC.group_color("custom_pets")
  ok(math.abs(col.r - 0.25) < 0.01 and math.abs(col.g - 0.80) < 0.01, "the group wears swatch 5")
  local sv = Verdant.SavedVars
  ok(sv.custom_groups and sv.custom_groups.custom_pets and sv.custom_groups.custom_pets.label == "Pets",
     "the group is persisted for the next login")

  local pets_entry = nil
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if name:find("^VerdantAssignFlyoutE") and c._hidden == false and c._text == "Pets" then pets_entry = c end
  end
  ok(pets_entry ~= nil, "the flyout lists the new group")

  A.on_confirm_yes()
  ok(SC.group_of(880001) == "custom_pets", "the ability that opened the panel gets the new group")
  ok(sv.skill_overrides[880001] == "custom_pets", "the assignment is persisted")

  A.show()
  A.open_newcat_for_test(nil)
  A.on_newcat_cancel()
  ok(VerdantAssignPanelNewCat._hidden == true, "cancel closes the panel")
  A.hide()
end
