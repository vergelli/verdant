Verdant = Verdant or {}
local Verdant = Verdant

Verdant.TriBar = {}
local M = Verdant.TriBar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local PlaySound               = PlaySound
local WINDOW_MANAGER          = WINDOW_MANAGER
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
  eHPS = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 },  -- pastel green
  MPS  = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 },  -- pastel pink
}

local COLS = { "EMS", "eHPS", "MPS" }

-- controls[m] = { area, label, value, bar = { bg, fill, frame } }
local controls = {}

local PEAK_DECAY_MS = 60000
local peaks = { EMS = { frac=0, t=0 }, eHPS = { frac=0, t=0 }, MPS = { frac=0, t=0 } }

local function update_peak(key, frac, now)
  local p = peaks[key]
  if frac >= p.frac then
    p.frac = frac ; p.t = now
  elseif (now - p.t) > PEAK_DECAY_MS then
    p.frac = frac ; p.t = now
  end
end

local function render_peak_line(line, parent, area_w, area_h, peak_frac)
  if peak_frac < 0.01 then line:SetHidden(true) ; return end
  local y = -math_floor(area_h * math_min(1, peak_frac))
  line:ClearAnchors()
  line:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, y)
  line:SetWidth(area_w)
  line:SetHidden(false)
end

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
-- use_pool:    true for eHPS/MPS (skill-colored segments)
-- use_stacked: true for EMS (heal green + shield pink stacked fills)
local function make_bar(area, name_suffix, color, use_pool, use_stacked)
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
  if use_pool or use_stacked then fill:SetHidden(true) end

  -- EMS stacked fills: eHPS green (bottom), MPS pink (above)
  local fill_heal, fill_shield
  if use_stacked then
    fill_heal = WM:CreateControl("VerdantTriBarFillHeal" .. name_suffix, area, CT_TEXTURE)
    fill_heal:ClearAnchors()
    fill_heal:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
    fill_heal:SetTexture(FILL_TEXTURE)
    fill_heal:SetTextureCoords(0, 1, FILL_T, FILL_B)
    fill_heal:SetColor(COLORS.eHPS.r, COLORS.eHPS.g, COLORS.eHPS.b, COLORS.eHPS.a)
    fill_heal:SetHidden(true)

    fill_shield = WM:CreateControl("VerdantTriBarFillShield" .. name_suffix, area, CT_TEXTURE)
    fill_shield:ClearAnchors()
    fill_shield:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
    fill_shield:SetTexture(FILL_TEXTURE)
    fill_shield:SetTextureCoords(0, 1, FILL_T, FILL_B)
    fill_shield:SetColor(COLORS.MPS.r, COLORS.MPS.g, COLORS.MPS.b, COLORS.MPS.a)
    fill_shield:SetHidden(true)
  end

  local pool = use_pool and make_skill_pool(area, "VerdantTriBarSkill" .. name_suffix) or nil

  local gloss = WM:CreateControl("VerdantTriBarGloss" .. name_suffix, area, CT_TEXTURE)
  gloss:ClearAnchors()
  gloss:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  gloss:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  gloss:SetTexture(GLOSS_TEXTURE)
  gloss:SetTextureCoords(0, 1, FILL_T, FILL_B)
  gloss:SetColor(1, 1, 1, 0.25)

  -- peak line: above gloss, below border
  local pl = WM:CreateControl("VerdantTriBarPeak" .. name_suffix, area, CT_TEXTURE)
  pl:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  pl:SetTexture(FILL_TEXTURE)
  pl:SetTextureCoords(0, 1, FILL_T, FILL_B)
  pl:SetDimensions(0, 2)
  pl:SetColor(1, 1, 1, 0.92)
  pl:SetHidden(true)

  -- 4-strip border — last so it renders above all fills and gloss
  make_border(area, "VerdantTriBarBorder" .. name_suffix)

  return { bg=bg, fill=fill, fill_heal=fill_heal, fill_shield=fill_shield, pool=pool, peak_line=pl }
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

    update_peak(m, frac, now)

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
        -- EMS: stacked heal (green, bottom) + shield (pink, above)
        local heal_frac   = math_max(0, math_min(1, r.C_heal   or 0))
        local shield_frac = math_max(0, math_min(1, r.C_shield or 0))
        local heal_h      = (heal_frac   > 0.005) and math_max(2, area_h * heal_frac)   or 0
        local shield_h    = (shield_frac > 0.005) and math_max(2, area_h * shield_frac) or 0

        local fh = c.bar.fill_heal
        fh:SetHidden(false)
        fh:SetWidth(area_w)
        fh:SetHeight(heal_h)

        local fs = c.bar.fill_shield
        fs:ClearAnchors()
        fs:SetAnchor(BOTTOMLEFT, c.area, BOTTOMLEFT, 0, -heal_h)
        fs:SetHidden(false)
        fs:SetWidth(area_w)
        fs:SetHeight(shield_h)
      end
      render_peak_line(c.bar.peak_line, c.area, area_w, area_h, peaks[m].frac)
    end
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.toggle()
  local hidden = controls.window:IsHidden()
  controls.window:SetHidden(not hidden)
  PlaySound(hidden and SOUNDS.ARMORY_OPEN or SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
  if hidden then refresh() end
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.visible = hidden end
end

function M.show()
  controls.window:SetHidden(false)
  PlaySound(SOUNDS.ARMORY_OPEN)
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.visible = true end
end

function M.hide()
  controls.window:SetHidden(true)
  PlaySound(SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
  local sv = Verdant.SavedVars
  if sv then sv.tribar = sv.tribar or {} ; sv.tribar.visible = false end
end

function M.on_close_click()
  M.hide()
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
    controls[m].bar = make_bar(controls[m].area, m, COLORS[m], m ~= "EMS", m == "EMS")
  end

  local visible = b.visible or false
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_TriBarTick", 1000, refresh)
  if visible then refresh() end
end
