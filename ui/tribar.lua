Verdant = Verdant or {}
local Verdant = Verdant

Verdant.TriBar = {}
local M = Verdant.TriBar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local PlaySound               = PlaySound
local string_format           = string.format
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor

local FILL_TEXTURE  = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE    = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local GLOSS_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill_gloss.dds"
local BORDER_EDGE   = "EsoUI/Art/Tooltips/UI-Border.dds"
local FILL_T, FILL_B = 0, 0.53125

local POOL_SIZE = 8

local function make_skill_pool(parent, name_prefix)
  local WM   = WINDOW_MANAGER
  local pool = {}
  for i = 1, POOL_SIZE do
    local t = WM:CreateControl(name_prefix .. i, parent, CT_TEXTURE)
    t:ClearAnchors()
    t:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)
    t:SetTexture(FILL_TEXTURE)
    t:SetTextureCoords(0, 1, FILL_T, FILL_B)
    t:SetHidden(true)
    pool[i] = t
  end
  return pool
end

local function render_skill_segments(pool, parent, segments, area_w, area_h, total_frac)
  local total_h = (total_frac > 0.005) and math_max(2, area_h * math_min(1, total_frac)) or 0
  local cum_h   = 0
  local n       = math_min(#segments, POOL_SIZE)
  for i = 1, n do
    local seg   = segments[i]
    local seg_h = math_max(1, math_floor(total_h * seg.share + 0.5))
    local t     = pool[i]
    t:ClearAnchors()
    t:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, -cum_h)
    t:SetWidth(area_w)
    t:SetHeight(seg_h)
    t:SetColor(seg.r, seg.g, seg.b, seg.a)
    t:SetHidden(false)
    cum_h = cum_h + seg_h
  end
  for i = n + 1, POOL_SIZE do
    pool[i]:SetHidden(true)
  end
end

local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.25, g = 0.88, b = 0.35, a = 0.92 },
  MPS  = { r = 0.90, g = 0.38, b = 0.68, a = 0.92 },
}

local COLS = { "EMS", "eHPS", "MPS" }

-- controls[m] = { area, label, value, bar = { bg, fill, frame } }
local controls = {}

local BORDER_COLOR = { r = 0.75, g = 0.62, b = 0.38, a = 0.90 }
local BORDER_SIZE  = 2

local function make_border(parent, name)
  local WM  = WINDOW_MANAGER
  local r, g, b, a = BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, BORDER_COLOR.a
  local B   = BORDER_SIZE
  local function strip(suffix, a1, rp1, x1, y1, a2, rp2, x2, y2)
    local t = WM:CreateControl(name .. suffix, parent, CT_TEXTURE)
    t:ClearAnchors()
    t:SetAnchor(a1, parent, rp1, x1, y1)
    t:SetAnchor(a2, parent, rp2, x2, y2)
    t:SetTexture(FILL_TEXTURE)
    t:SetTextureCoords(0, 1, FILL_T, FILL_B)
    t:SetColor(r, g, b, a)
  end
  strip("T", TOPLEFT, TOPLEFT,     0,  0, BOTTOMRIGHT, TOPRIGHT,     0,  B)
  strip("B", TOPLEFT, BOTTOMLEFT,  0, -B, BOTTOMRIGHT, BOTTOMRIGHT,  0,  0)
  strip("L", TOPLEFT, TOPLEFT,     0,  0, BOTTOMRIGHT, BOTTOMLEFT,   B,  0)
  strip("R", TOPLEFT, TOPRIGHT,   -B,  0, BOTTOMRIGHT, BOTTOMRIGHT,  0,  0)
end

-- ── per-column bar textures ───────────────────────────────────────────────
-- use_pool: true for eHPS/MPS columns (skill-colored segments);
--           false for EMS (single gold fill).
local function make_bar(area, name_suffix, color, use_pool)
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
  if use_pool then fill:SetHidden(true) end

  local pool = use_pool and make_skill_pool(area, "VerdantTriBarSkill" .. name_suffix) or nil

  local gloss = WM:CreateControl("VerdantTriBarGloss" .. name_suffix, area, CT_TEXTURE)
  gloss:ClearAnchors()
  gloss:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  gloss:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  gloss:SetTexture(GLOSS_TEXTURE)
  gloss:SetTextureCoords(0, 1, FILL_T, FILL_B)
  gloss:SetColor(1, 1, 1, 0.25)

  -- 4-strip border — last so it renders above fill, pool segments, and gloss
  make_border(area, "VerdantTriBarBorder" .. name_suffix)

  return { bg = bg, fill = fill, pool = pool }
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
      if m == "eHPS" then
        local segs = Verdant.Metrics.eHPS_by_group(now)
        render_skill_segments(c.bar.pool, c.area, segs, area_w, area_h, frac)
      elseif m == "MPS" then
        local segs = Verdant.Metrics.MPS_by_group(now)
        render_skill_segments(c.bar.pool, c.area, segs, area_w, area_h, frac)
      else
        local fill_h = (frac > 0.005) and math_max(2, area_h * frac) or 0
        c.bar.fill:SetWidth(area_w)
        c.bar.fill:SetHeight(fill_h)
      end
    end
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.toggle()
  local hidden = controls.window:IsHidden()
  controls.window:SetHidden(not hidden)
  PlaySound(hidden and SOUNDS.ARMORY_OPEN or SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.visible = hidden end
end

function M.show()
  controls.window:SetHidden(false)
  PlaySound(SOUNDS.ARMORY_OPEN)
end

function M.hide()
  controls.window:SetHidden(true)
  PlaySound(SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
end

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
    controls[m].bar = make_bar(controls[m].area, m, COLORS[m], m ~= "EMS")
  end

  local visible = b.visible or false
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_TriBarTick", 1000, refresh)
  if visible then refresh() end
end
