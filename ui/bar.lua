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

-- ESO attribute bar textures
local FILL_TEXTURE  = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE    = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FRAME_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_frame.dds"
-- TextureCoords for fill atlas: the fill strip is the top 53.125% of the sheet
local FILL_T, FILL_B = 0, 0.53125

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
  local WM   = WINDOW_MANAGER
  local area = controls.bar_area

  -- bg: dark background using ESO attr-bar bg texture
  local bg = WM:CreateControl("VerdantBarBg", area, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(0.10, 0.10, 0.12, 1)
  controls.bg = bg

  -- fill: single BOTTOMLEFT anchor; SetWidth+SetHeight called each tick.
  local fill = WM:CreateControl("VerdantBarFill", area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local c = COLORS["EMS"]
  fill:SetColor(c.r, c.g, c.b, c.a)
  controls.fill = fill

  -- fill_heal: EMS stacked mode — eHPS (green) from bottom
  local fh = WM:CreateControl("VerdantBarFillHeal", area, CT_TEXTURE)
  fh:ClearAnchors()
  fh:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fh:SetTexture(FILL_TEXTURE)
  fh:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local ch = COLORS["eHPS"]
  fh:SetColor(ch.r, ch.g, ch.b, ch.a)
  fh:SetHidden(true)
  controls.fill_heal = fh

  -- fill_shield: EMS stacked mode — MPS (pink) above heal segment.
  -- Anchor is repositioned each tick in refresh() to sit on top of fill_heal.
  local fs = WM:CreateControl("VerdantBarFillShield", area, CT_TEXTURE)
  fs:ClearAnchors()
  fs:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fs:SetTexture(FILL_TEXTURE)
  fs:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local cs = COLORS["MPS"]
  fs:SetColor(cs.r, cs.g, cs.b, cs.a)
  fs:SetHidden(true)
  controls.fill_shield = fs

  -- frame: ESO attribute-bar frame overlay drawn on top of fills
  local frame = WM:CreateControl("VerdantBarFrame", area, CT_TEXTURE)
  frame:ClearAnchors()
  frame:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  frame:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  frame:SetTexture(FRAME_TEXTURE)
  frame:SetColor(1, 1, 1, 0.9)
  controls.frame = frame
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

  -- mode button: show what the NEXT click will switch to
  controls.mode_btn:SetText(display_pct and "#" or "%")
  controls.mode_btn:SetColor(0.75, 0.75, 0.75, 1)

  -- fill bar(s)
  local area_w = controls.bar_area:GetWidth()
  local area_h = controls.bar_area:GetHeight()
  if area_h <= 4 then return end

  if m == "EMS" then
    -- stacked fill: eHPS green at bottom, MPS pink stacked above it
    controls.fill:SetHidden(true)

    local heal_frac   = math_max(0, math_min(1, r.C_heal   or 0))
    local shield_frac = math_max(0, math_min(1, r.C_shield or 0))
    local heal_h      = (heal_frac   > 0.005) and math_max(2, area_h * heal_frac)   or 0
    local shield_h    = (shield_frac > 0.005) and math_max(2, area_h * shield_frac) or 0

    local fh = controls.fill_heal
    fh:SetHidden(false)
    fh:SetWidth(area_w)
    fh:SetHeight(heal_h)

    local fs = controls.fill_shield
    -- reposition bottom edge to sit on top of the heal segment
    fs:ClearAnchors()
    fs:SetAnchor(BOTTOMLEFT, controls.bar_area, BOTTOMLEFT, 0, -heal_h)
    fs:SetHidden(false)
    fs:SetWidth(area_w)
    fs:SetHeight(shield_h)
  else
    -- single colored fill
    controls.fill_heal:SetHidden(true)
    controls.fill_shield:SetHidden(true)

    local fill_h = (frac > 0.005) and math_max(2, area_h * frac) or 0
    local f = controls.fill
    f:SetHidden(false)
    f:SetWidth(area_w)
    f:SetHeight(fill_h)
    f:SetColor(color.r, color.g, color.b, color.a)
  end
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

  -- show window before first refresh so GetWidth/GetHeight return real values
  local visible = (b.visible == nil) and true or b.visible
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_BarTick", 1000, refresh)
  refresh()
end
