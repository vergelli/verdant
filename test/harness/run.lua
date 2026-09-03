HARNESS_ROOT  = arg[1] or "."
HARNESS_DEBUG = (arg[2] ~= "0")

dofile(HARNESS_ROOT .. "/test/harness/mock_eso.lua")
dofile(HARNESS_ROOT .. "/test/harness/loader.lua")

HARNESS.fire(EVENT_ADD_ON_LOADED, "Verdant")

local CASES = {
  "boot",
  "heal_flow",
  "shield_filter",
  "record_flow",
  "header_metrics",
  "buff_tracker",
  "buff_merge",
  "buff_states",
  "buffs_view",
  "buffs_hover",
  "auto_record",
  "dmg_overlay",
  "death_markers",
  "user_profiles",
  "slash_report",
  "trace_flow",
  "group_death_markers",
  "triage_fsm",
  "triage_view",
  "ui_behaviors",
  "solid_fills",
  "vsf_codec",
  "session_store",
  "library_flow",
  "render_bounds",
  "donut_widget",
  "button_manners",
  "report_card",
  "record_isolation",
  "skill_donut",
  "categories",
  "new_category_ui",
  "view_tabs",
  "assign_scroll",
  "hitch",
  "bar_touches",
  "legacy_session",
  "pixel_grid",
  "skill_layout",
  "grow_to_fill",
  "overheal_view",
  "ultimate_band",
  "settings_columns",
  "light_mode",
  "buff_watch",
  "zero_alloc",
  "clarity",
}

local passed, failed = 0, 0
for _, name in ipairs(CASES) do
  local case = dofile(HARNESS_ROOT .. "/test/harness/cases/" .. name .. ".lua")
  local ok, err = pcall(case, HARNESS)
  if ok then
    passed = passed + 1
    print(string.format("PASS  %s", name))
  else
    failed = failed + 1
    print(string.format("FAIL  %s\n      %s", name, tostring(err)))
  end
end

print(string.format("== %d passed, %d failed (DEBUG=%s) ==",
  passed, failed, tostring(HARNESS_DEBUG)))
os.exit(failed == 0 and 0 or 1)
