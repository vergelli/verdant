Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Settings = {}
local M = Verdant.Settings

local GetUIMousePosition = GetUIMousePosition
local math_max   = math.max
local math_min   = math.min
local math_floor = math.floor
local string_format = string.format

local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FILL_T, FILL_B = 0, 0.53125

-- ── rate presets ──────────────────────────────────────────────────────────
-- Stored as milliseconds; displayed as Hz.
-- 50 ms (20 Hz) is the practical upper bound — faster than the game's
-- own combat event rate so the display updates every visible frame.
local PRESETS    = { 50, 100, 200, 500, 1000, 2000 }
local PRESET_HZ  = {
  [50]   = "20 Hz",
  [100]  = "10 Hz",
  [200]  = "5 Hz",
  [500]  = "2 Hz",
  [1000] = "1 Hz",
  [2000] = "0.5 Hz",
}
local DEFAULT_MS = 1000

local controls   = {}
local current_ms = DEFAULT_MS

-- ── helpers ───────────────────────────────────────────────────────────────
local function nearest_idx(ms)
  local bi, bd = 1, math.huge
  for i, p in ipairs(PRESETS) do
    local d = math.abs(p - ms)
    if d < bd then bi, bd = i, d end
  end
  return bi
end

local function update_slider()
  local track = controls.track
  local w     = track:GetWidth()
  if w <= 0 then return end  -- not yet laid out (hidden window)

  local idx  = nearest_idx(current_ms)
  local pct  = (idx - 1) / (#PRESETS - 1)

  -- fill: proportional gold strip from left
  controls.fill:SetWidth(math_max(2, w * pct))
  controls.fill:SetHeight(track:GetHeight())

  -- thumb: bright 3-px vertical bar at the current position.
  -- Uses TOP+BOTTOM single-horizontal-center anchors against TOPLEFT/BOTTOMLEFT
  -- of the track so only the X position needs to be computed.
  controls.thumb:ClearAnchors()
  controls.thumb:SetAnchor(TOP,    track, TOPLEFT,    w * pct, -1)
  controls.thumb:SetAnchor(BOTTOM, track, BOTTOMLEFT, w * pct,  1)
  controls.thumb:SetWidth(3)

  controls.rate_label:SetText(PRESET_HZ[current_ms] or (current_ms .. " ms"))
end

-- ── public API ────────────────────────────────────────────────────────────
function M.on_track_click(control)
  local cx         = GetUIMousePosition()  -- x, (y discarded)
  local track_left = control:GetLeft()
  local track_w    = control:GetWidth()
  if track_w <= 0 then return end

  local pct = math_max(0, math_min(1, (cx - track_left) / track_w))
  -- snap to nearest discrete preset
  local idx = math_floor(pct * (#PRESETS - 1) + 0.5) + 1
  idx = math_max(1, math_min(#PRESETS, idx))
  current_ms = PRESETS[idx]

  -- re-register the bar tick at the new interval
  Verdant.Bar.set_rate(current_ms)

  -- persist
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar.rate_ms = current_ms end

  update_slider()
end

function M.toggle()
  local win    = controls.window
  local hidden = win:IsHidden()

  if hidden then
    -- position: below bar window if there is room, otherwise above it
    local bw = VerdantBarWindow
    local bLeft, bTop, bRight, bBottom = bw:GetScreenRect()
    local ph = win:GetHeight()

    win:ClearAnchors()
    if bBottom + 4 + ph <= GuiRoot:GetHeight() then
      win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, bLeft, bBottom + 4)
    else
      win:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, bLeft, bTop - 4)
    end

    win:SetHidden(false)
    update_slider()  -- width is valid once visible
  else
    win:SetHidden(true)
  end
end

-- ── setup ─────────────────────────────────────────────────────────────────
local function setup_slider()
  local WM    = WINDOW_MANAGER
  local track = controls.track

  -- dark background (exact fit of track control)
  local bg = WM:CreateControl("VerdantSettingsBg", track, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     track, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, track, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(0.10, 0.10, 0.12, 1)

  -- fill: gold, grows left to right with current preset
  local fill = WM:CreateControl("VerdantSettingsFill", track, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, track, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  fill:SetColor(0.95, 0.80, 0.20, 0.90)
  controls.fill = fill

  -- thumb: bright white 3-px vertical indicator
  local thumb = WM:CreateControl("VerdantSettingsThumb", track, CT_TEXTURE)
  thumb:SetTexture(FILL_TEXTURE)
  thumb:SetTextureCoords(0, 1, FILL_T, FILL_B)
  thumb:SetColor(1, 1, 1, 1)
  controls.thumb = thumb
end

function M.init()
  local sv = Verdant.SavedVars
  sv.bar   = sv.bar or {}
  -- clamp saved value to the nearest valid preset
  current_ms = PRESETS[nearest_idx(sv.bar.rate_ms or DEFAULT_MS)]

  controls.window     = VerdantSettingsPanel
  controls.title      = VerdantSettingsPanelTitle
  controls.rate_label = VerdantSettingsPanelRateLabel
  controls.track      = VerdantSettingsPanelSliderTrack

  controls.title:SetText("Refresh Rate")
  controls.title:SetColor(0.75, 0.75, 0.75, 1)
  controls.rate_label:SetColor(0.95, 0.80, 0.20, 1)

  setup_slider()
  -- update_slider() is deferred to first toggle() open because the
  -- panel is hidden at init time and GetWidth() would return 0.
end
