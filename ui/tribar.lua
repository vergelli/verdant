Verdant = Verdant or {}
local Verdant = Verdant

Verdant.TriBar = {}
local M = Verdant.TriBar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local string_format           = string.format
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor

local FILL_TEXTURE  = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE    = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FRAME_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_frame.dds"
local FILL_T, FILL_B = 0, 0.53125

local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.25, g = 0.88, b = 0.35, a = 0.92 },
  MPS  = { r = 0.90, g = 0.38, b = 0.68, a = 0.92 },
}

local COLS = { "EMS", "eHPS", "MPS" }

-- controls[m] = { area, label, value, bar = { bg, fill, frame } }
local controls = {}

-- ── per-column bar textures ───────────────────────────────────────────────
local function make_bar(area, name_suffix, color)
  local WM = WINDOW_MANAGER

  local bg = WM:CreateControl("VerdantTriBarBg" .. name_suffix, area, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(0.10, 0.10, 0.12, 1)

  local fill = WM:CreateControl("VerdantTriBarFill" .. name_suffix, area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  fill:SetColor(color.r, color.g, color.b, color.a)

  local frame = WM:CreateControl("VerdantTriBarFrame" .. name_suffix, area, CT_TEXTURE)
  frame:ClearAnchors()
  frame:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  frame:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  frame:SetTexture(FRAME_TEXTURE)
  frame:SetColor(1, 1, 1, 0.9)

  return { bg = bg, fill = fill, frame = frame }
end

-- ── refresh (1 Hz tick) ───────────────────────────────────────────────────
local function refresh()
  if controls.window:IsHidden() then return end

  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)

  local vals = {
    EMS  = { frac = r.C_self   or 0, raw = r.EMS  or 0 },
    eHPS = { frac = r.C_heal   or 0, raw = r.eHPS or 0 },
    MPS  = { frac = r.C_shield or 0, raw = r.MPS  or 0 },
  }

  for _, m in ipairs(COLS) do
    local c    = controls[m]
    local v    = vals[m]
    local col  = COLORS[m]
    local frac = math_max(0, math_min(1, v.frac))

    c.label:SetText(m)
    c.label:SetColor(col.r, col.g, col.b, 1)
    c.value:SetText(string_format("%d", math_floor(v.raw)))
    c.value:SetColor(1, 1, 1, 1)

    local area_w = c.area:GetWidth()
    local area_h = c.area:GetHeight()
    if area_h > 4 then
      local fill_h = (frac > 0.005) and math_max(2, area_h * frac) or 0
      c.bar.fill:SetWidth(area_w)
      c.bar.fill:SetHeight(fill_h)
    end
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.toggle()
  local hidden = not controls.window:IsHidden()
  controls.window:SetHidden(hidden)
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.visible = not hidden end
end

function M.show() controls.window:SetHidden(false) end
function M.hide() controls.window:SetHidden(true)  end

function M.on_move_stop()
  local left, top = controls.window:GetScreenRect()
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.x, sv.tribar.y = left, top end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  local sv = Verdant.SavedVars
  sv.tribar = sv.tribar or {}
  local b = sv.tribar

  controls.window = VerdantTriBarWindow

  controls.EMS  = {
    area  = VerdantTriBarWindowEmsArea,
    label = VerdantTriBarWindowEmsLabel,
    value = VerdantTriBarWindowEmsValue,
  }
  controls.eHPS = {
    area  = VerdantTriBarWindowEhpsArea,
    label = VerdantTriBarWindowEhpsLabel,
    value = VerdantTriBarWindowEhpsValue,
  }
  controls.MPS  = {
    area  = VerdantTriBarWindowMpsArea,
    label = VerdantTriBarWindowMpsLabel,
    value = VerdantTriBarWindowMpsValue,
  }

  if b.x and b.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, b.x, b.y)
  end

  for _, m in ipairs(COLS) do
    controls[m].bar = make_bar(controls[m].area, m, COLORS[m])
  end

  local visible = b.visible or false
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_TriBarTick", 1000, refresh)
  if visible then refresh() end
end
