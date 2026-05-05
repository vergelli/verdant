Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Settings = {}
local M = Verdant.Settings

local GetUIMousePosition = GetUIMousePosition
local GetString          = GetString
local WINDOW_MANAGER     = WINDOW_MANAGER
local math_max           = math.max
local math_min           = math.min
local math_floor         = math.floor

-- Slider visuals use eso_subblade textures: track BG = normal blade,
-- fill = selected blade (active portion), thumb stays as a thin highlight.
local TRACK_TEXTURE = "EsoUI/Art/Quest/eso_subblade_normal.dds"
local FILL_TEXTURE  = "EsoUI/Art/Quest/eso_subblade_selected.dds"
local THUMB_TEXTURE = "EsoUI/Art/Quest/eso_subblade_mouseover.dds"

-- ── presets ───────────────────────────────────────────────────────────────────
local RATE_PRESETS   = { 50, 100, 200, 500, 1000, 2000 }
local RATE_LABELS    = {
  [50]   = "20 Hz", [100] = "10 Hz", [200] = "5 Hz",
  [500]  = "2 Hz",  [1000] = "1 Hz", [2000] = "0.5 Hz",
}
local RATE_DEFAULT   = 1000

local HEAL_PRESETS   = { 2000, 3000, 5000, 8000, 10000, 15000 }
local HEAL_LABELS    = {
  [2000] = "2s", [3000] = "3s", [5000]  = "5s",
  [8000] = "8s", [10000] = "10s", [15000] = "15s",
}
local HEAL_DEFAULT   = 5000

local SHIELD_PRESETS = { 10000, 15000, 20000, 30000, 45000, 60000 }
local SHIELD_LABELS  = {
  [10000] = "10s", [15000] = "15s", [20000] = "20s",
  [30000] = "30s", [45000] = "45s", [60000] = "60s",
}
local SHIELD_DEFAULT = 30000

-- Sampling rate (stored as ms interval; label shows Hz)
local SAMPLE_PRESETS = { 1000, 500, 200, 100 }
local SAMPLE_LABELS  = { [1000] = "1 Hz", [500] = "2 Hz", [200] = "5 Hz", [100] = "10 Hz" }
local SAMPLE_DEFAULT = 1000

-- Time window for temporal buffer (stored as seconds)
local TWINDOW_PRESETS = { 30, 60, 120, 180, 300 }
local TWINDOW_LABELS  = { [30] = "30s", [60] = "1m", [120] = "2m", [180] = "3m", [300] = "5m" }
local TWINDOW_DEFAULT = 60

-- ── state ─────────────────────────────────────────────────────────────────────
local controls       = {}
local current_rate    = RATE_DEFAULT
local current_heal    = HEAL_DEFAULT
local current_shield  = SHIELD_DEFAULT
local current_sample  = SAMPLE_DEFAULT
local current_twindow = TWINDOW_DEFAULT

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

local function setup_slider_visuals(track, name_prefix)
  local WM = WINDOW_MANAGER

  local bg = WM:CreateControl(name_prefix .. "Bg", track, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     track, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, track, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(TRACK_TEXTURE)
  bg:SetColor(1, 1, 1, 1)

  local fill = WM:CreateControl(name_prefix .. "Fill", track, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, track, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetColor(1, 1, 1, 1)

  local thumb = WM:CreateControl(name_prefix .. "Thumb", track, CT_TEXTURE)
  thumb:SetTexture(THUMB_TEXTURE)
  thumb:SetColor(1, 1, 1, 1)

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

local function reinit_buffer()
  local hz       = math_floor(1000 / current_sample)  -- intervals/s → Hz
  local capacity = current_twindow * hz
  Verdant.TemporalBuffer.init(capacity)
end

-- ── public API ────────────────────────────────────────────────────────────────
function M.toggle()
  local win    = controls.window
  local hidden = win:IsHidden()

  if hidden then
    local bw = VerdantBarWindow
    local bLeft, bTop, _, bBottom = bw:GetScreenRect()
    local ph = win:GetHeight()
    win:ClearAnchors()
    if bBottom + 4 + ph <= GuiRoot:GetHeight() then
      win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, bLeft, bBottom + 4)
    else
      win:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, bLeft, bTop - 4)
    end
    win:SetHidden(false)

    -- widths are valid now that the panel is visible
    local c = controls
    update_slider(c.track_rate,    c.fill_rate,    c.thumb_rate,    c.label_rate,    RATE_PRESETS,    RATE_LABELS,    current_rate)
    update_slider(c.track_heal,    c.fill_heal,    c.thumb_heal,    c.label_heal,    HEAL_PRESETS,    HEAL_LABELS,    current_heal)
    update_slider(c.track_shield,  c.fill_shield,  c.thumb_shield,  c.label_shield,  SHIELD_PRESETS,  SHIELD_LABELS,  current_shield)
    update_slider(c.track_sample,  c.fill_sample,  c.thumb_sample,  c.label_sample,  SAMPLE_PRESETS,  SAMPLE_LABELS,  current_sample)
    update_slider(c.track_twindow, c.fill_twindow, c.thumb_twindow, c.label_twindow, TWINDOW_PRESETS, TWINDOW_LABELS, current_twindow)
  else
    win:SetHidden(true)
  end
end

function M.on_rate_track_click(control)
  local cx      = GetUIMousePosition()
  local track_w = control:GetWidth()
  if track_w <= 0 then return end
  local pct = math_max(0, math_min(1, (cx - control:GetLeft()) / track_w))
  local idx = math_max(1, math_min(#RATE_PRESETS, math_floor(pct * (#RATE_PRESETS - 1) + 0.5) + 1))
  current_rate = RATE_PRESETS[idx]
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
  persist_temporal("time_window_s", current_twindow)
  reinit_buffer()
  update_slider(controls.track_twindow, controls.fill_twindow, controls.thumb_twindow, controls.label_twindow, TWINDOW_PRESETS, TWINDOW_LABELS, current_twindow)
end

-- ── init ──────────────────────────────────────────────────────────────────────
function M.init()
  local sv = Verdant.SavedVars
  sv.bar      = sv.bar      or {}
  sv.temporal = sv.temporal or {}

  current_rate    = RATE_PRESETS   [nearest_idx(RATE_PRESETS,    sv.bar.rate_ms             or RATE_DEFAULT)]
  current_heal    = HEAL_PRESETS   [nearest_idx(HEAL_PRESETS,    sv.bar.heal_window_ms      or HEAL_DEFAULT)]
  current_shield  = SHIELD_PRESETS [nearest_idx(SHIELD_PRESETS,  sv.bar.shield_window_ms    or SHIELD_DEFAULT)]
  current_sample  = SAMPLE_PRESETS [nearest_idx(SAMPLE_PRESETS,  sv.temporal.sample_rate_ms or SAMPLE_DEFAULT)]
  current_twindow = TWINDOW_PRESETS[nearest_idx(TWINDOW_PRESETS, sv.temporal.time_window_s  or TWINDOW_DEFAULT)]

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

  local c = controls
  c.fill_rate,    c.thumb_rate    = setup_slider_visuals(c.track_rate,    "VerdantSettingsRate")
  c.fill_heal,    c.thumb_heal    = setup_slider_visuals(c.track_heal,    "VerdantSettingsHeal")
  c.fill_shield,  c.thumb_shield  = setup_slider_visuals(c.track_shield,  "VerdantSettingsShield")
  c.fill_sample,  c.thumb_sample  = setup_slider_visuals(c.track_sample,  "VerdantSettingsSample")
  c.fill_twindow, c.thumb_twindow = setup_slider_visuals(c.track_twindow, "VerdantSettingsTWindow")
  -- slider display deferred to first toggle() — panel is hidden and GetWidth() returns 0
end
