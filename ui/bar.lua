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
-- Each entry drives which slice of contribution() is shown on the bar.
local DISPLAY_METRICS = { "EMS", "eHPS", "MPS" }

-- v1.0 colours: EMS = gold, eHPS = green, MPS = pink
local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.25, g = 0.88, b = 0.35, a = 0.92 },
  MPS  = { r = 0.90, g = 0.38, b = 0.68, a = 0.92 },
}

local TRACK_COLOR  = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
local BAR_TEXTURE  = "EsoUI/Art/Tooltips/UI-TooltipCenter.dds"

-- size constraints (px)
local MIN_W, MAX_W = 50,  130
local MIN_H, MAX_H = 160, 420

-- ── state ─────────────────────────────────────────────────────────────────
local metric_idx  = 1      -- index into DISPLAY_METRICS
local display_pct = false  -- false = raw number, true = percentage

local controls = {}  -- populated in init()

-- ── helpers ───────────────────────────────────────────────────────────────
local function current_metric() return DISPLAY_METRICS[metric_idx] end

local function contribution_values(r)
  local m = current_metric()
  if m == "EMS"  then return r.C_self,   r.EMS,  "EMS"  end
  if m == "eHPS" then return r.C_heal,   r.eHPS, "HPS"  end
  if m == "MPS"  then return r.C_shield, r.MPS,  "MPS"  end
  return 0, 0, "?"
end

local function save_state()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.bar = sv.bar or {}
  local b = sv.bar
  b.metric_idx   = metric_idx
  b.display_pct  = display_pct
  b.visible      = not controls.window:IsHidden()
end

-- ── bar texture setup ─────────────────────────────────────────────────────
local function setup_textures()
  local WM       = WINDOW_MANAGER
  local bar_area = controls.bar_area

  -- track: slightly larger than bar_area to give "containment" depth
  local track = WM:CreateControl("VerdantBarTrack", bar_area, CT_TEXTURE)
  track:ClearAnchors()
  track:SetAnchor(TOPLEFT,     bar_area, TOPLEFT,     -3, -3)
  track:SetAnchor(BOTTOMRIGHT, bar_area, BOTTOMRIGHT,  3,  3)
  track:SetTexture(BAR_TEXTURE)
  track:SetColor(TRACK_COLOR.r, TRACK_COLOR.g, TRACK_COLOR.b, TRACK_COLOR.a)
  controls.track = track

  -- fill: anchored bottom-left + bottom-right so it grows upward.
  -- height is set each tick; top edge floats.
  local fill = WM:CreateControl("VerdantBarFill", bar_area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT,  bar_area, BOTTOMLEFT,  0, 0)
  fill:SetAnchor(BOTTOMRIGHT, bar_area, BOTTOMRIGHT, 0, 0)
  fill:SetHeight(2)
  fill:SetTexture(BAR_TEXTURE)
  local c = COLORS["EMS"]
  fill:SetColor(c.r, c.g, c.b, c.a)
  controls.fill = fill
end

-- ── refresh (1 Hz tick) ───────────────────────────────────────────────────
local function refresh()
  if controls.window:IsHidden() then return end

  local r       = Verdant.Metrics.contribution(GetGameTimeMilliseconds())
  local frac, raw, suffix = contribution_values(r)
  frac = math_max(0, math_min(1, frac or 0))
  raw  = raw or 0

  local m     = current_metric()
  local color = COLORS[m]

  -- metric acronym (colored)
  controls.metric_label:SetText(m)
  controls.metric_label:SetColor(color.r, color.g, color.b, 1)

  -- value text
  if display_pct then
    controls.value_label:SetText(string_format("%.0f%%", frac * 100))
  else
    controls.value_label:SetText(string_format("%d %s", math_floor(raw), suffix))
  end

  -- bar fill height
  local area_h = controls.bar_area:GetHeight()
  if area_h > 4 then
    controls.fill:SetHeight(math_max(2, area_h * frac))
    controls.fill:SetColor(color.r, color.g, color.b, color.a)
  end

  -- mode button label: show what pressing it would switch TO
  controls.mode_btn:SetText(display_pct and "#" or "%")
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
  local hidden = not controls.window:IsHidden()
  controls.window:SetHidden(hidden)
  save_state()
end

function M.show() controls.window:SetHidden(false) save_state() end
function M.hide() controls.window:SetHidden(true)  save_state() end

function M.on_move_stop()
  local left, top = controls.window:GetScreenRect()
  local sv = Verdant.SavedVars
  if sv then
    sv.bar = sv.bar or {}
    sv.bar.x, sv.bar.y = left, top
  end
end

function M.on_resize_stop()
  local w, h = controls.window:GetDimensions()
  w = math_max(MIN_W, math_min(MAX_W, w))
  h = math_max(MIN_H, math_min(MAX_H, h))
  controls.window:SetDimensions(w, h)
  local sv = Verdant.SavedVars
  if sv then
    sv.bar = sv.bar or {}
    sv.bar.w, sv.bar.h = w, h
  end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  local C  = Verdant.Constants
  local sv = Verdant.SavedVars
  sv.bar = sv.bar or {}
  local b = sv.bar

  -- restore display state
  metric_idx  = b.metric_idx  or 1
  display_pct = b.display_pct or false

  -- bind named XML controls
  controls.window       = VerdantBarWindow
  controls.metric_label = VerdantBarWindowMetricLabel
  controls.value_label  = VerdantBarWindowValueLabel
  controls.bar_area     = VerdantBarWindowBarArea
  controls.mode_btn     = VerdantBarWindowModeBtn
  controls.version_label= VerdantBarWindowVersionLabel
  controls.prev_btn     = VerdantBarWindowPrevBtn
  controls.next_btn     = VerdantBarWindowNextBtn

  -- arrow button labels
  controls.prev_btn:SetText("<")
  controls.next_btn:SetText(">")

  -- version label
  controls.version_label:SetText(
    string_format("API %d  v%s", GetAPIVersion(), C.VERSION))

  -- size constraints
  controls.window:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)

  -- restore size
  local w = b.w or 70
  local h = b.h or 220
  controls.window:SetDimensions(w, h)

  -- restore position (nil = keep XML default: bottom-right)
  if b.x and b.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, b.x, b.y)
  end

  -- build textures now that bar_area dimensions are known
  setup_textures()

  -- initial refresh before first tick
  refresh()

  -- 1 Hz update
  Verdant.Events.register_update("Verdant_BarTick", 1000, refresh)

  -- restore visibility (default: visible)
  local visible = (b.visible == nil) and true or b.visible
  controls.window:SetHidden(not visible)
end
