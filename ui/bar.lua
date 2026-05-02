Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Bar = {}
local M = Verdant.Bar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetAPIVersion           = GetAPIVersion
local string_format           = string.format
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor

-- ── display metric cycle ──────────────────────────────────────────────────
local DISPLAY_METRICS = { "EMS", "eHPS", "MPS" }

local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.25, g = 0.88, b = 0.35, a = 0.92 },
  MPS  = { r = 0.90, g = 0.38, b = 0.68, a = 0.92 },
}

local TRACK_COLOR = { r = 0.06, g = 0.06, b = 0.06, a = 0.95 }
-- Flat tintable texture (attribute bar fill, designed for colour overrides)
local BAR_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

-- size constraints (px)
local MIN_W, MAX_W = 60, 140
local MIN_H, MAX_H = 180, 440

-- ── state ─────────────────────────────────────────────────────────────────
local metric_idx  = 1
local display_pct = false
local controls    = {}

-- ── helpers ───────────────────────────────────────────────────────────────
local function current_metric() return DISPLAY_METRICS[metric_idx] end

local function contribution_values(r)
  local m = current_metric()
  if m == "EMS"  then return r.C_self,   r.EMS,  "EMS" end
  if m == "eHPS" then return r.C_heal,   r.eHPS, "HPS" end
  if m == "MPS"  then return r.C_shield, r.MPS,  "MPS" end
  return 0, 0, "?"
end

local function save_state()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.bar = sv.bar or {}
  local b = sv.bar
  b.metric_idx  = metric_idx
  b.display_pct = display_pct
  b.visible     = not controls.window:IsHidden()
end

-- ── bar texture setup ─────────────────────────────────────────────────────
local function setup_textures()
  local WM  = WINDOW_MANAGER
  local area = controls.bar_area

  -- track: 3px larger on each side → "containment" border effect.
  -- Uses two anchors; height is fully determined, so no SetHeight needed.
  local track = WM:CreateControl("VerdantBarTrack", area, CT_TEXTURE)
  track:ClearAnchors()
  track:SetAnchor(TOPLEFT,     area, TOPLEFT,     -3, -3)
  track:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT,  3,  3)
  track:SetTexture(BAR_TEXTURE)
  track:SetColor(TRACK_COLOR.r, TRACK_COLOR.g, TRACK_COLOR.b, TRACK_COLOR.a)
  controls.track = track

  -- fill: single BOTTOMLEFT anchor so SetWidth + SetHeight are unambiguous.
  -- ESO ignores SetHeight when two opposing anchors fully constrain the axis;
  -- a single anchor leaves height free.
  local fill = WM:CreateControl("VerdantBarFill", area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fill:SetTexture(BAR_TEXTURE)
  local c = COLORS["EMS"]
  fill:SetColor(c.r, c.g, c.b, c.a)
  fill:SetWidth(area:GetWidth())
  fill:SetHeight(0)
  controls.fill = fill
end

-- ── refresh (called by 1 Hz tick and on user input) ───────────────────────
local function refresh()
  if controls.window:IsHidden() then return end

  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)

  local frac, raw, suffix = contribution_values(r)
  frac = math_max(0, math_min(1, frac or 0))
  raw  = raw or 0

  local m     = current_metric()
  local color = COLORS[m]

  -- metric label (colored to match bar)
  controls.metric_label:SetText(m)
  controls.metric_label:SetColor(color.r, color.g, color.b, 1)

  -- value below metric label (white)
  if display_pct then
    controls.value_label:SetText(string_format("%.0f%%", frac * 100))
  else
    controls.value_label:SetText(string_format("%d %s", math_floor(raw), suffix))
  end
  controls.value_label:SetColor(1, 1, 1, 1)

  -- fill: single anchor, explicit width + height each tick.
  -- Width keeps up with window resize; height represents the fraction.
  local area_w = controls.bar_area:GetWidth()
  local area_h = controls.bar_area:GetHeight()
  if area_h > 4 then
    local fill_h = (frac > 0.005) and math_max(2, area_h * frac) or 0
    controls.fill:SetWidth(area_w)
    controls.fill:SetHeight(fill_h)
    controls.fill:SetColor(color.r, color.g, color.b, color.a)
  end

  -- mode button: show what the NEXT click will switch to
  controls.mode_btn:SetText(display_pct and "#" or "%")
  controls.mode_btn:SetColor(0.75, 0.75, 0.75, 1)
end

-- ── public API ────────────────────────────────────────────────────────────
function M.prev_metric()
  metric_idx = ((metric_idx - 2) % #DISPLAY_METRICS) + 1
  save_state()
  refresh()
end

function M.next_metric()
  metric_idx = (metric_idx % #DISPLAY_METRICS) + 1
  save_state()
  refresh()
end

function M.toggle_display_mode()
  display_pct = not display_pct
  save_state()
  refresh()
end

function M.toggle()
  controls.window:SetHidden(not controls.window:IsHidden())
  save_state()
end

function M.show() controls.window:SetHidden(false) save_state() end
function M.hide() controls.window:SetHidden(true)  save_state() end

function M.on_move_stop()
  local left, top = controls.window:GetScreenRect()
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar.x, sv.bar.y = left, top end
end

function M.on_resize_stop()
  local w, h = controls.window:GetDimensions()
  w = math_max(MIN_W, math_min(MAX_W, w))
  h = math_max(MIN_H, math_min(MAX_H, h))
  controls.window:SetDimensions(w, h)
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar.w, sv.bar.h = w, h end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  local C  = Verdant.Constants
  local sv = Verdant.SavedVars
  sv.bar = sv.bar or {}
  local b = sv.bar

  metric_idx  = b.metric_idx  or 1
  display_pct = b.display_pct or false

  controls.window        = VerdantBarWindow
  controls.metric_label  = VerdantBarWindowMetricLabel
  controls.value_label   = VerdantBarWindowValueLabel
  controls.bar_area      = VerdantBarWindowBarArea
  controls.mode_btn      = VerdantBarWindowModeBtn
  controls.version_label = VerdantBarWindowVersionLabel
  controls.api_label     = VerdantBarWindowApiLabel
  controls.prev_btn      = VerdantBarWindowPrevBtn
  controls.next_btn      = VerdantBarWindowNextBtn

  -- arrow labels
  controls.prev_btn:SetText("<")
  controls.prev_btn:SetColor(0.75, 0.75, 0.75, 1)
  controls.next_btn:SetText(">")
  controls.next_btn:SetColor(0.75, 0.75, 0.75, 1)

  -- version labels (small, grey)
  controls.api_label:SetText(string_format("API %d", GetAPIVersion()))
  controls.api_label:SetColor(0.45, 0.45, 0.45, 1)
  controls.version_label:SetText(string_format("v%s", C.VERSION))
  controls.version_label:SetColor(0.45, 0.45, 0.45, 1)

  -- size constraints and restore
  controls.window:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
  controls.window:SetDimensions(b.w or 70, b.h or 240)

  if b.x and b.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, b.x, b.y)
  end

  setup_textures()

  -- register 1 Hz tick; show window first so refresh() doesn't bail early
  local visible = (b.visible == nil) and true or b.visible
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_BarTick", 1000, refresh)
  refresh()
end
