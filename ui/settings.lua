Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Settings = {}
local M = Verdant.Settings

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local GetUIMousePosition = api.GetUIMousePosition
local GetString          = api.GetString
local WINDOW_MANAGER     = zui.WINDOW_MANAGER
local math_max           = math.max
local math_min           = math.min
local math_floor         = math.floor

-- ── UI constants ──────────────────────────────────────────────────────────
local log         = Verdant.Log.for_module("settings")
local TOP         = zc.TOP
local TOPLEFT     = zc.TOPLEFT
local BOTTOM      = zc.BOTTOM
local BOTTOMLEFT  = zc.BOTTOMLEFT
local CT_TEXTURE  = zc.CT_TEXTURE
local GuiRoot     = zc.GuiRoot

-- Slider visuals: original ESO attributeBar textures with their proper
-- texture coords (top half of the dynamic_fill is the visible band).
local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_T, FILL_B = 0, 0.53125

-- ── presets ───────────────────────────────────────────────────────────────────
local RATE_PRESETS   = { 50, 100, 200, 500, 1000, 2000 }
local RATE_LABELS    = {
  [50]   = "20 Hz", [100] = "10 Hz", [200] = "5 Hz",
  [500]  = "2 Hz",  [1000] = "1 Hz", [2000] = "0.5 Hz",
}
local RATE_DEFAULT   = 1000

-- Heal and Shield windows share the same 1..30 s range with 1 s step so they
-- can be compared 1:1 in the UI and so users don't have to learn two scales.
local function range_presets(start_s, end_s)
  local p, lbls = {}, {}
  for s = start_s, end_s do
    local ms = s * 1000
    p[#p + 1]   = ms
    lbls[ms]    = s .. "s"
  end
  return p, lbls
end

local HEAL_PRESETS,   HEAL_LABELS   = range_presets(1, 30)
local SHIELD_PRESETS, SHIELD_LABELS = range_presets(1, 30)
local HEAL_DEFAULT   = 5000
local SHIELD_DEFAULT = 10000

-- Sampling rate (stored as ms interval; label shows Hz). 1..10 Hz, 1 Hz step.
local SAMPLE_PRESETS = {}
local SAMPLE_LABELS  = {}
for hz = 1, 10 do
  local ms = math.floor(1000 / hz + 0.5)
  SAMPLE_PRESETS[#SAMPLE_PRESETS + 1] = ms
  SAMPLE_LABELS[ms] = hz .. " Hz"
end
local SAMPLE_DEFAULT = 1000

-- Time window for temporal buffer (stored as seconds).
-- 15 s → 10 min in 15-second steps: 15, 30, 45, 60, ..., 600.
-- Upper end (>5min) is intended for end-game PvE bosses that run long;
-- combinations with high sample rate are gated by a capacity warning.
local function twindow_presets()
  local p, lbls = {}, {}
  for s = 15, 600, 15 do
    p[#p + 1] = s
    if s % 60 == 0 then
      lbls[s] = (s / 60) .. "m"
    elseif s < 60 then
      lbls[s] = s .. "s"
    else
      lbls[s] = string.format("%d:%02d", math.floor(s / 60), s % 60)
    end
  end
  return p, lbls
end
local TWINDOW_PRESETS, TWINDOW_LABELS = twindow_presets()
local TWINDOW_DEFAULT = 60

-- Viewport alpha (stored as integer percentage 0..100, step 5).  Stored as
-- int (not float) to avoid floating-point key issues in the labels lookup.
local VPALPHA_PRESETS = {}
local VPALPHA_LABELS  = {}
for pct = 0, 100, 5 do
  VPALPHA_PRESETS[#VPALPHA_PRESETS + 1] = pct
  VPALPHA_LABELS[pct] = pct .. "%"
end
local VPALPHA_DEFAULT = 30

-- Font scale: 3 discrete sizes mapped to ESO's pre-rendered fonts. Stored
-- as integer index 1..3 so SavedVars carries a stable value across font
-- name renames. Applied to bar value/title labels and graph axis labels.
local FONT_PRESETS = { 1, 2, 3 }
local FONT_LABELS  = { [1] = "Small", [2] = "Medium", [3] = "Large" }
local FONT_DEFAULT = 1   -- preserves current visuals (ZoFontGameSmall everywhere)
-- ESO ships predictable Game-family fonts at three discrete sizes.
-- ZoFontGameMedium does NOT exist in stock ESO and silently falls
-- back to default — that's why "Large" looked unchanged before.
local FONT_SPECS   = {
  [1] = "ZoFontGameSmall",
  [2] = "ZoFontGame",
  [3] = "ZoFontGameLarge",
}

-- ── state ─────────────────────────────────────────────────────────────────────
local controls       = {}
local current_rate    = RATE_DEFAULT
local current_heal    = HEAL_DEFAULT
local current_shield  = SHIELD_DEFAULT
local current_sample  = SAMPLE_DEFAULT
local current_twindow = TWINDOW_DEFAULT
local current_vpalpha = VPALPHA_DEFAULT
local current_font    = FONT_DEFAULT

-- ── shared helpers ────────────────────────────────────────────────────────────
local function nearest_idx(presets, ms)
  local bi, bd = 1, math.huge
  for i, p in ipairs(presets) do
    local d = math.abs(p - ms)
    if d < bd then bi, bd = i, d end
  end
  return bi
end

local function update_slider(track, fill, thumb, label, presets, labels, ms)
  local w = track:GetWidth()
  if w <= 0 then return end
  local idx = nearest_idx(presets, ms)
  local pct = (idx - 1) / (#presets - 1)
  fill:SetWidth(math_max(2, w * pct))
  fill:SetHeight(track:GetHeight())
  thumb:ClearAnchors()
  thumb:SetAnchor(TOP,    track, TOPLEFT,    w * pct, -1)
  thumb:SetAnchor(BOTTOM, track, BOTTOMLEFT, w * pct,  1)
  thumb:SetWidth(3)
  label:SetText(labels[ms] or (math_floor(ms / 1000) .. "s"))
end

-- Background texture for the empty track. progressbar_frame_bg is a dark
-- inner panel; stretching it across our 14px slider height makes the
-- track visible (was previously an invisible Control hosting only fill
-- and thumb). If it ends up looking off at this scale the texture can be
-- swapped here in one place.
local TRACK_BG_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_frame_bg.dds"

local function setup_slider_visuals(track, name_prefix)
  local WM = WINDOW_MANAGER

  -- Track background: behind the fill so the empty portion of the slider
  -- still shows a visible panel.
  local bg = WM:CreateControl(name_prefix .. "Bg", track, CT_TEXTURE)
  bg:SetAnchorFill(track)
  bg:SetTexture(TRACK_BG_TEXTURE)
  bg:SetColor(0.55, 0.55, 0.55, 0.85)
  bg:SetDrawLevel(0)

  local fill = WM:CreateControl(name_prefix .. "Fill", track, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, track, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  -- Warm amber/cream matching ESO's tooltip border tone (BORDER_COLOR
  -- in bar.lua). Was a punchy primary yellow that clashed with the
  -- otherwise-muted UI palette.
  fill:SetColor(0.85, 0.72, 0.45, 0.90)
  fill:SetDrawLevel(1)

  local thumb = WM:CreateControl(name_prefix .. "Thumb", track, CT_TEXTURE)
  thumb:SetTexture(FILL_TEXTURE)
  thumb:SetTextureCoords(0, 1, FILL_T, FILL_B)
  thumb:SetColor(1, 1, 1, 1)
  thumb:SetDrawLevel(2)

  return fill, thumb
end

local function persist(key, val)
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar[key] = val end
end

local function persist_temporal(key, val)
  local sv = Verdant.SavedVars
  if sv then sv.temporal = sv.temporal or {} ; sv.temporal[key] = val end
end

-- Capacity-based safety warning. Render cost scales with the number of
-- samples the temporal buffer has to draw; a long window combined with
-- a high sample rate can balloon to thousands of samples and impact FPS.
-- Threshold tuned for ~600px canvas where slot_w < 3px already disables
-- per-segment line drawing — fills still cost O(capacity).
local CAPACITY_WARN_THRESHOLD = 1500

local function warn_if_heavy(capacity, twindow_s, hz)
  if capacity <= CAPACITY_WARN_THRESHOLD then return end
  local msg = string.format(
    "%ss x %s Hz = %d samples may impact FPS. Consider lower sample rate for long windows.",
    twindow_s, hz, capacity)
  -- Chat in red so the user notices.
  d("|cFF4444[V] WARNING:|r " .. msg)
  log:warn("heavy combo:", msg)
end

local function reinit_buffer()
  local hz       = math_floor(1000 / current_sample)  -- intervals/s → Hz
  local capacity = current_twindow * hz
  Verdant.TemporalBuffer.init(capacity)
  warn_if_heavy(capacity, current_twindow, hz)
end

-- Apply the active font scale to bar value/title/metric labels. Settings
-- panel labels themselves intentionally stay at fixed size so the config
-- UI stays compact regardless of accessibility choice.
local function apply_font_scale()
  local font = FONT_SPECS[current_font] or FONT_SPECS[FONT_DEFAULT]
  -- Bar single-view labels.
  if VerdantBarWindowMetricLabel then VerdantBarWindowMetricLabel:SetFont(font) end
  if VerdantBarWindowValueLabel  then VerdantBarWindowValueLabel:SetFont(font)  end
  if VerdantBarWindowTitleLabel  then VerdantBarWindowTitleLabel:SetFont(font)  end
  -- Bar triple-view labels (one per metric column, created in Lua).
  for _, m in ipairs({"EMS", "eHPS", "MPS"}) do
    local lbl = _G["VerdantBarTriLabel"  .. m]
    local val = _G["VerdantBarTriValue"  .. m]
    if lbl then lbl:SetFont(font) end
    if val then val:SetFont(font) end
  end
  -- Graph window static chrome labels. Dynamic axis labels (Y-values,
  -- time-strip) intentionally stay fixed-size: they're meant to be
  -- compact reference tickmarks.
  if VerdantGraphWindowTitleLabel  then VerdantGraphWindowTitleLabel:SetFont(font)  end
  if VerdantGraphWindowStatusLabel then VerdantGraphWindowStatusLabel:SetFont(font) end
  if VerdantGraphWindowViewLabel   then VerdantGraphWindowViewLabel:SetFont(font)   end
  if VerdantGraphWindowEhpsLabel   then VerdantGraphWindowEhpsLabel:SetFont(font)   end
  if VerdantGraphWindowMpsLabel    then VerdantGraphWindowMpsLabel:SetFont(font)    end
  if VerdantGraphWindowNoDataLabel then VerdantGraphWindowNoDataLabel:SetFont(font) end
end

local function refresh_all_sliders()
  local c = controls
  update_slider(c.track_rate,    c.fill_rate,    c.thumb_rate,    c.label_rate,    RATE_PRESETS,    RATE_LABELS,    current_rate)
  update_slider(c.track_heal,    c.fill_heal,    c.thumb_heal,    c.label_heal,    HEAL_PRESETS,    HEAL_LABELS,    current_heal)
  update_slider(c.track_shield,  c.fill_shield,  c.thumb_shield,  c.label_shield,  SHIELD_PRESETS,  SHIELD_LABELS,  current_shield)
  update_slider(c.track_sample,  c.fill_sample,  c.thumb_sample,  c.label_sample,  SAMPLE_PRESETS,  SAMPLE_LABELS,  current_sample)
  update_slider(c.track_twindow, c.fill_twindow, c.thumb_twindow, c.label_twindow, TWINDOW_PRESETS, TWINDOW_LABELS, current_twindow)
  update_slider(c.track_vpalpha, c.fill_vpalpha, c.thumb_vpalpha, c.label_vpalpha, VPALPHA_PRESETS, VPALPHA_LABELS, current_vpalpha)
  update_slider(c.track_font,    c.fill_font,    c.thumb_font,    c.label_font,    FONT_PRESETS,    FONT_LABELS,    current_font)
end

-- ── public API ────────────────────────────────────────────────────────────────
function M.toggle()
  local win    = controls.window
  local hidden = win:IsHidden()
  if hidden then
    win:SetHidden(false)
    refresh_all_sliders()
  else
    win:SetHidden(true)
  end
end

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv or not controls.window then return end
  sv.settings = sv.settings or {}
  sv.settings.x = controls.window:GetLeft()
  sv.settings.y = controls.window:GetTop()
end

function M.on_rate_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#RATE_PRESETS, math_floor(pct * (#RATE_PRESETS - 1) + 0.5) + 1))
  current_rate = RATE_PRESETS[idx]
  log:info("rate ->", current_rate, "ms")
  Verdant.Bar.set_rate(current_rate)
  persist("rate_ms", current_rate)
  update_slider(controls.track_rate, controls.fill_rate, controls.thumb_rate, controls.label_rate, RATE_PRESETS, RATE_LABELS, current_rate)
end

function M.on_heal_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#HEAL_PRESETS, math_floor(pct * (#HEAL_PRESETS - 1) + 0.5) + 1))
  current_heal = HEAL_PRESETS[idx]
  log:info("heal_window ->", current_heal, "ms")
  Verdant.Metrics.set_window(current_heal)
  persist("heal_window_ms", current_heal)
  update_slider(controls.track_heal, controls.fill_heal, controls.thumb_heal, controls.label_heal, HEAL_PRESETS, HEAL_LABELS, current_heal)
end

function M.on_shield_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#SHIELD_PRESETS, math_floor(pct * (#SHIELD_PRESETS - 1) + 0.5) + 1))
  current_shield = SHIELD_PRESETS[idx]
  log:info("shield_window ->", current_shield, "ms")
  Verdant.Metrics.set_shield_window(current_shield)
  persist("shield_window_ms", current_shield)
  update_slider(controls.track_shield, controls.fill_shield, controls.thumb_shield, controls.label_shield, SHIELD_PRESETS, SHIELD_LABELS, current_shield)
end

function M.on_sample_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#SAMPLE_PRESETS, math_floor(pct * (#SAMPLE_PRESETS - 1) + 0.5) + 1))
  current_sample = SAMPLE_PRESETS[idx]
  log:info("sample_rate ->", current_sample, "ms")
  persist_temporal("sample_rate_ms", current_sample)
  reinit_buffer()
  update_slider(controls.track_sample, controls.fill_sample, controls.thumb_sample, controls.label_sample, SAMPLE_PRESETS, SAMPLE_LABELS, current_sample)
end

function M.on_twindow_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#TWINDOW_PRESETS, math_floor(pct * (#TWINDOW_PRESETS - 1) + 0.5) + 1))
  current_twindow = TWINDOW_PRESETS[idx]
  log:info("time_window ->", current_twindow, "s")
  persist_temporal("time_window_s", current_twindow)
  reinit_buffer()
  update_slider(controls.track_twindow, controls.fill_twindow, controls.thumb_twindow, controls.label_twindow, TWINDOW_PRESETS, TWINDOW_LABELS, current_twindow)
end

function M.on_vpalpha_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#VPALPHA_PRESETS, math_floor(pct * (#VPALPHA_PRESETS - 1) + 0.5) + 1))
  current_vpalpha = VPALPHA_PRESETS[idx]
  log:info("viewport_alpha ->", current_vpalpha, "%")
  persist_temporal("viewport_alpha_pct", current_vpalpha)
  Verdant.Graph.set_viewport_alpha(current_vpalpha / 100)
  update_slider(controls.track_vpalpha, controls.fill_vpalpha, controls.thumb_vpalpha, controls.label_vpalpha, VPALPHA_PRESETS, VPALPHA_LABELS, current_vpalpha)
end

function M.on_font_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#FONT_PRESETS, math_floor(pct * (#FONT_PRESETS - 1) + 0.5) + 1))
  current_font = FONT_PRESETS[idx]
  log:info("font_scale ->", FONT_LABELS[current_font])
  local sv = Verdant.SavedVars
  if sv then sv.settings = sv.settings or {} ; sv.settings.font_scale = current_font end
  apply_font_scale()
  update_slider(controls.track_font, controls.fill_font, controls.thumb_font, controls.label_font, FONT_PRESETS, FONT_LABELS, current_font)
end

-- Restores every setting to its default value, persists, reapplies.
function M.on_reset_click()
  log:info("reset to defaults")
  current_rate    = RATE_DEFAULT
  current_heal    = HEAL_DEFAULT
  current_shield  = SHIELD_DEFAULT
  current_sample  = SAMPLE_DEFAULT
  current_twindow = TWINDOW_DEFAULT
  current_vpalpha = VPALPHA_DEFAULT
  current_font    = FONT_DEFAULT

  -- Persist all back to SavedVars.
  persist("rate_ms",          current_rate)
  persist("heal_window_ms",   current_heal)
  persist("shield_window_ms", current_shield)
  persist_temporal("sample_rate_ms",     current_sample)
  persist_temporal("time_window_s",      current_twindow)
  persist_temporal("viewport_alpha_pct", current_vpalpha)
  local sv = Verdant.SavedVars
  if sv then sv.settings = sv.settings or {} ; sv.settings.font_scale = current_font end

  -- Reapply: bar tick, metric windows, temporal buffer, viewport alpha, font.
  Verdant.Bar.set_rate(current_rate)
  Verdant.Metrics.set_window(current_heal)
  Verdant.Metrics.set_shield_window(current_shield)
  reinit_buffer()
  Verdant.Graph.set_viewport_alpha(current_vpalpha / 100)
  apply_font_scale()
  refresh_all_sliders()
end

-- ── init ──────────────────────────────────────────────────────────────────────
-- Snapshot of the current configuration for /verdant report and other
-- introspection. Read-only; do NOT mutate the returned table.
function M.snapshot()
  local hz       = math_floor(1000 / current_sample)
  local capacity = current_twindow * hz
  return {
    rate_ms              = current_rate,
    heal_window_ms       = current_heal,
    shield_window_ms     = current_shield,
    sample_rate_ms       = current_sample,
    sample_rate_hz       = hz,
    time_window_s        = current_twindow,
    viewport_alpha_pct   = current_vpalpha,
    font_scale           = current_font,
    font_label           = FONT_LABELS[current_font],
    temporal_capacity    = capacity,
    capacity_warn_above  = CAPACITY_WARN_THRESHOLD,
  }
end

function M.report_lines()
  local s = M.snapshot()
  local heavy = (s.temporal_capacity > s.capacity_warn_above) and "  [HEAVY]" or ""
  return {
    string.format("[config] bar: refresh=%dms heal_window=%dms shield_window=%dms",
      s.rate_ms, s.heal_window_ms, s.shield_window_ms),
    string.format("[config] graph: sample=%dms (%dHz) window=%ds capacity=%d%s",
      s.sample_rate_ms, s.sample_rate_hz, s.time_window_s, s.temporal_capacity, heavy),
    string.format("[config] viewport_alpha=%d%% font=%s",
      s.viewport_alpha_pct, s.font_label),
  }
end

function M.init()
  local sv = Verdant.SavedVars
  sv.bar      = sv.bar      or {}
  sv.temporal = sv.temporal or {}

  sv.settings = sv.settings or {}

  current_rate    = RATE_PRESETS   [nearest_idx(RATE_PRESETS,    sv.bar.rate_ms             or RATE_DEFAULT)]
  current_heal    = HEAL_PRESETS   [nearest_idx(HEAL_PRESETS,    sv.bar.heal_window_ms      or HEAL_DEFAULT)]
  current_shield  = SHIELD_PRESETS [nearest_idx(SHIELD_PRESETS,  sv.bar.shield_window_ms    or SHIELD_DEFAULT)]
  current_sample  = SAMPLE_PRESETS [nearest_idx(SAMPLE_PRESETS,  sv.temporal.sample_rate_ms    or SAMPLE_DEFAULT)]
  current_twindow = TWINDOW_PRESETS[nearest_idx(TWINDOW_PRESETS, sv.temporal.time_window_s     or TWINDOW_DEFAULT)]
  current_vpalpha = VPALPHA_PRESETS[nearest_idx(VPALPHA_PRESETS, sv.temporal.viewport_alpha_pct or VPALPHA_DEFAULT)]
  current_font    = FONT_PRESETS   [nearest_idx(FONT_PRESETS,    sv.settings.font_scale         or FONT_DEFAULT)]

  Verdant.Metrics.set_window(current_heal)
  Verdant.Metrics.set_shield_window(current_shield)

  -- Pre-allocate circular buffer with the saved (or default) capacity.
  reinit_buffer()

  controls.window         = VerdantSettingsPanel
  controls.title_rate     = VerdantSettingsPanelTitle
  controls.label_rate     = VerdantSettingsPanelRateLabel
  controls.track_rate     = VerdantSettingsPanelSliderTrack
  controls.title_heal     = VerdantSettingsPanelHealTitle
  controls.label_heal     = VerdantSettingsPanelHealLabel
  controls.track_heal     = VerdantSettingsPanelSliderTrackHeal
  controls.title_shield   = VerdantSettingsPanelShieldTitle
  controls.label_shield   = VerdantSettingsPanelShieldLabel
  controls.track_shield   = VerdantSettingsPanelSliderTrackShield
  controls.title_sample   = VerdantSettingsPanelSampleTitle
  controls.label_sample   = VerdantSettingsPanelSampleLabel
  controls.track_sample   = VerdantSettingsPanelSliderTrackSample
  controls.title_twindow  = VerdantSettingsPanelTWindowTitle
  controls.label_twindow  = VerdantSettingsPanelTWindowLabel
  controls.track_twindow  = VerdantSettingsPanelSliderTrackTWindow
  controls.title_vpalpha  = VerdantSettingsPanelVPAlphaTitle
  controls.label_vpalpha  = VerdantSettingsPanelVPAlphaLabel
  controls.track_vpalpha  = VerdantSettingsPanelSliderTrackVPAlpha
  controls.title_font     = VerdantSettingsPanelFontTitle
  controls.label_font     = VerdantSettingsPanelFontLabel
  controls.track_font     = VerdantSettingsPanelSliderTrackFont
  controls.window_title   = VerdantSettingsPanelWindowTitle
  controls.reset_btn      = VerdantSettingsPanelResetBtn

  controls.window_title:SetText("Verdant Settings")
  controls.reset_btn:SetText("Reset to Defaults")

  controls.title_rate:SetText("Refresh Rate")
  controls.title_rate:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_rate:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_heal:SetText("Heal Window")
  controls.title_heal:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_heal:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_shield:SetText("Shield Window")
  controls.title_shield:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_shield:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_sample:SetText(GetString(VERDANT_SETTING_SAMPLE_RATE))
  controls.title_sample:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_sample:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_twindow:SetText(GetString(VERDANT_SETTING_TIME_WINDOW))
  controls.title_twindow:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_twindow:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_vpalpha:SetText(GetString(VERDANT_SETTING_VIEWPORT_ALPHA))
  controls.title_vpalpha:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_vpalpha:SetColor(0.95, 0.80, 0.20, 1)

  controls.title_font:SetText("Font Size")
  controls.title_font:SetColor(0.75, 0.75, 0.75, 1)
  controls.label_font:SetColor(0.95, 0.80, 0.20, 1)

  local c = controls
  c.fill_rate,    c.thumb_rate    = setup_slider_visuals(c.track_rate,    "VerdantSettingsRate")
  c.fill_heal,    c.thumb_heal    = setup_slider_visuals(c.track_heal,    "VerdantSettingsHeal")
  c.fill_shield,  c.thumb_shield  = setup_slider_visuals(c.track_shield,  "VerdantSettingsShield")
  c.fill_sample,  c.thumb_sample  = setup_slider_visuals(c.track_sample,  "VerdantSettingsSample")
  c.fill_twindow, c.thumb_twindow = setup_slider_visuals(c.track_twindow, "VerdantSettingsTWindow")
  c.fill_vpalpha, c.thumb_vpalpha = setup_slider_visuals(c.track_vpalpha, "VerdantSettingsVPAlpha")
  c.fill_font,    c.thumb_font    = setup_slider_visuals(c.track_font,    "VerdantSettingsFont")
  -- slider display deferred to first toggle() — panel is hidden and GetWidth() returns 0

  -- Restore window position from SavedVars (centered fallback).
  if sv.settings.x and sv.settings.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.settings.x, sv.settings.y)
  else
    controls.window:ClearAnchors()
    controls.window:SetAnchor(zc.CENTER, GuiRoot, zc.CENTER, 0, 0)
  end

  -- Apply font scale once everything else is wired so bar/triple labels
  -- inherit the saved choice on /reloadui.
  apply_font_scale()

  -- Log the full config snapshot at startup so /verdant report after a
  -- reload always has the baseline.
  for _, line in ipairs(M.report_lines()) do log:info(line) end
end
