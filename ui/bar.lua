Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Bar = {}
local M = Verdant.Bar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetAPIVersion           = GetAPIVersion
local PlaySound               = PlaySound
local WINDOW_MANAGER          = WINDOW_MANAGER
local string_format           = string.format
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor

-- ── display metric cycle ──────────────────────────────────────────────────
-- "ALL" is the 4th position: shows three columns simultaneously
local DISPLAY_METRICS = { "EMS", "eHPS", "MPS", "ALL" }

local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 },  -- pastel green
  MPS  = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 },  -- pastel pink
}

local FILL_TEXTURE  = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE    = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local GLOSS_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill_gloss.dds"
local FILL_T, FILL_B = 0, 0.53125

-- 4-strip border: warm gold tint, 2 px each side
local BORDER_COLOR = { r = 0.75, g = 0.62, b = 0.38, a = 0.90 }
local BORDER_SIZE  = 2

-- ── size constraints ──────────────────────────────────────────────────────
local MIN_W_SINGLE, MAX_W_SINGLE = 60,  140
local MIN_W_ALL,    MAX_W_ALL    = 110, 200
local MIN_H,        MAX_H        = 180, 440

-- triple-view column geometry (fixed width, centered in window)
local TRI_COL_W   = 26
local TRI_COL_GAP = 8
local TRI_COLS    = { "EMS", "eHPS", "MPS" }
local TRI_COL_X   = { EMS = 0, eHPS = TRI_COL_W + TRI_COL_GAP, MPS = (TRI_COL_W + TRI_COL_GAP) * 2 }
local TRI_TOTAL_W = TRI_COL_W * 3 + TRI_COL_GAP * 2   -- 94 px

-- ── skill-color fill pools ────────────────────────────────────────────────
-- Pre-allocated textures for stacked per-skill segments on eHPS / MPS bars.
-- 8 slots covers any realistic number of distinct skills in a 5-second window.
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

-- Positions and colors pool textures as stacked vertical segments.
-- segments: array of { r,g,b,a, share } sorted largest-first (from group_shares).
-- total_frac: 0-1 contribution for this metric.
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

-- ── peak-value tracking ──────────────────────────────────────────────────
-- Holds the highest contribution fraction seen per metric.
-- Resets after PEAK_DECAY_MS of not being beaten.
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

-- Places and shows the peak line.  peak_frac=0 hides it.
local function render_peak_line(line, parent, area_w, area_h, peak_frac)
  if peak_frac < 0.01 then line:SetHidden(true) ; return end
  local y = -math_floor(area_h * math_min(1, peak_frac))
  line:ClearAnchors()
  line:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, y)
  line:SetWidth(area_w)
  line:SetHidden(false)
end

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
  return 0, 0, ""
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

local function apply_size_constraints()
  local is_all = (current_metric() == "ALL")
  local min_w  = is_all and MIN_W_ALL or MIN_W_SINGLE
  local max_w  = is_all and MAX_W_ALL or MAX_W_SINGLE
  controls.window:SetDimensionConstraints(min_w, MIN_H, max_w, MAX_H)
  if is_all then
    local w, h = controls.window:GetDimensions()
    if w < MIN_W_ALL then controls.window:SetDimensions(MIN_W_ALL, h) end
  end
end

-- ── border: 4 solid CT_TEXTURE strips, warm gold ─────────────────────────
-- Created LAST inside a parent so each strip renders above the fill textures.
-- Each strip is anchored using two opposing corners of the *parent* so the
-- strips track resizes without any Lua intervention.
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

  -- top:    my TOPLEFT    = parent TOPLEFT,   my BOTTOMRIGHT = parent TOPRIGHT   + (0, B)
  strip("T", TOPLEFT, TOPLEFT, 0, 0, BOTTOMRIGHT, TOPRIGHT,    0,  B)
  -- bottom: my TOPLEFT    = parent BOTTOMLEFT + (0, -B), my BOTTOMRIGHT = parent BOTTOMRIGHT
  strip("B", TOPLEFT, BOTTOMLEFT, 0, -B, BOTTOMRIGHT, BOTTOMRIGHT, 0, 0)
  -- left:   my TOPLEFT    = parent TOPLEFT,   my BOTTOMRIGHT = parent BOTTOMLEFT + (B, 0)
  strip("L", TOPLEFT, TOPLEFT, 0, 0, BOTTOMRIGHT, BOTTOMLEFT, B, 0)
  -- right:  my TOPLEFT    = parent TOPRIGHT   + (-B, 0), my BOTTOMRIGHT = parent BOTTOMRIGHT
  strip("R", TOPLEFT, TOPRIGHT, -B, 0, BOTTOMRIGHT, BOTTOMRIGHT, 0, 0)
end

-- ── single-bar texture setup ──────────────────────────────────────────────
local function setup_single_bar()
  local WM   = WINDOW_MANAGER
  local area = controls.bar_area

  -- dark background
  local bg = WM:CreateControl("VerdantBarBg", area, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(0.10, 0.10, 0.12, 1)
  controls.bg = bg

  -- main fill (single metric, or EMS total placeholder)
  local fill = WM:CreateControl("VerdantBarFill", area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  fill:SetColor(COLORS.EMS.r, COLORS.EMS.g, COLORS.EMS.b, COLORS.EMS.a)
  controls.fill = fill

  -- EMS stacked: eHPS green (bottom)
  local fh = WM:CreateControl("VerdantBarFillHeal", area, CT_TEXTURE)
  fh:ClearAnchors()
  fh:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fh:SetTexture(FILL_TEXTURE)
  fh:SetTextureCoords(0, 1, FILL_T, FILL_B)
  fh:SetColor(COLORS.eHPS.r, COLORS.eHPS.g, COLORS.eHPS.b, COLORS.eHPS.a)
  fh:SetHidden(true)
  controls.fill_heal = fh

  -- EMS stacked: MPS pink (above eHPS). Anchor repositioned each tick.
  local fs = WM:CreateControl("VerdantBarFillShield", area, CT_TEXTURE)
  fs:ClearAnchors()
  fs:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fs:SetTexture(FILL_TEXTURE)
  fs:SetTextureCoords(0, 1, FILL_T, FILL_B)
  fs:SetColor(COLORS.MPS.r, COLORS.MPS.g, COLORS.MPS.b, COLORS.MPS.a)
  fs:SetHidden(true)
  controls.fill_shield = fs

  -- skill-color fill pools for eHPS and MPS modes (created before gloss)
  controls.pool_ehps = make_skill_pool(area, "VerdantBarSkillEhps")
  controls.pool_mps  = make_skill_pool(area, "VerdantBarSkillMps")

  -- gloss overlay: subtle horizontal sheen from the original ESO fill gloss sheet.
  -- Covers the full bar area so it applies equally to any fill configuration.
  local gloss = WM:CreateControl("VerdantBarGloss", area, CT_TEXTURE)
  gloss:ClearAnchors()
  gloss:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  gloss:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  gloss:SetTexture(GLOSS_TEXTURE)
  gloss:SetTextureCoords(0, 1, FILL_T, FILL_B)
  gloss:SetColor(1, 1, 1, 0.25)
  controls.gloss = gloss

  -- peak line: bright 2-px strip above gloss, below border
  local pl = WM:CreateControl("VerdantBarPeakLine", area, CT_TEXTURE)
  pl:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  pl:SetTexture(FILL_TEXTURE)
  pl:SetTextureCoords(0, 1, FILL_T, FILL_B)
  pl:SetDimensions(0, 2)
  pl:SetColor(1, 1, 1, 0.92)
  pl:SetHidden(true)
  controls.peak_line = pl

  -- 4-strip gold border — created LAST so it renders above fills and gloss
  make_border(area, "VerdantBarBorder")
end

-- ── triple-column view (Lua-created inside main window) ───────────────────
local function setup_triple_view()
  local WM  = WINDOW_MANAGER
  local win = controls.window

  -- container: same vertical span as bar_area, fixed width centered
  local container = WM:CreateControl("VerdantBarTriContainer", win, CT_CONTROL)
  container:ClearAnchors()
  container:SetAnchor(TOP,    win, TOP,    0, 52)
  container:SetAnchor(BOTTOM, win, BOTTOM, 0, -70)
  container:SetWidth(TRI_TOTAL_W)
  container:SetHidden(true)
  controls.tri_container = container

  controls.tri = {}

  for _, m in ipairs(TRI_COLS) do
    local x   = TRI_COL_X[m]
    local col = {}
    controls.tri[m] = col

    -- metric label (top of column)
    local lbl = WM:CreateControl("VerdantBarTriLabel" .. m, container, CT_LABEL)
    lbl:ClearAnchors()
    lbl:SetAnchor(TOPLEFT, container, TOPLEFT, x, 0)
    lbl:SetDimensions(TRI_COL_W, 14)
    lbl:SetFont("ZoFontGameSmall")
    lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    col.label = lbl

    -- bar area (between label and value)
    local area = WM:CreateControl("VerdantBarTriArea" .. m, container, CT_CONTROL)
    area:ClearAnchors()
    area:SetAnchor(TOPLEFT,    container, TOPLEFT,    x, 18)
    area:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, x, -18)
    area:SetWidth(TRI_COL_W)
    col.area = area

    local bg = WM:CreateControl("VerdantBarTriBg" .. m, area, CT_TEXTURE)
    bg:ClearAnchors()
    bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
    bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
    bg:SetTexture(BG_TEXTURE)
    bg:SetColor(0.10, 0.10, 0.12, 1)

    local fill = WM:CreateControl("VerdantBarTriFill" .. m, area, CT_TEXTURE)
    fill:ClearAnchors()
    fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
    fill:SetTexture(FILL_TEXTURE)
    fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
    local c = COLORS[m]
    fill:SetColor(c.r, c.g, c.b, c.a)
    col.fill = fill

    -- EMS: stacked heal (pastel green, bottom) + shield (pastel pink, above)
    if m == "EMS" then
      fill:SetHidden(true)

      local fh = WM:CreateControl("VerdantBarTriFillHeal" .. m, area, CT_TEXTURE)
      fh:ClearAnchors()
      fh:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
      fh:SetTexture(FILL_TEXTURE)
      fh:SetTextureCoords(0, 1, FILL_T, FILL_B)
      fh:SetColor(COLORS.eHPS.r, COLORS.eHPS.g, COLORS.eHPS.b, COLORS.eHPS.a)
      fh:SetHidden(true)
      col.fill_heal = fh

      local fs = WM:CreateControl("VerdantBarTriFillShield" .. m, area, CT_TEXTURE)
      fs:ClearAnchors()
      fs:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
      fs:SetTexture(FILL_TEXTURE)
      fs:SetTextureCoords(0, 1, FILL_T, FILL_B)
      fs:SetColor(COLORS.MPS.r, COLORS.MPS.g, COLORS.MPS.b, COLORS.MPS.a)
      fs:SetHidden(true)
      col.fill_shield = fs
    end

    -- skill pool for eHPS and MPS columns
    if m ~= "EMS" then
      col.pool = make_skill_pool(area, "VerdantBarTriSkill" .. m)
    end

    local gloss = WM:CreateControl("VerdantBarTriGloss" .. m, area, CT_TEXTURE)
    gloss:ClearAnchors()
    gloss:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
    gloss:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
    gloss:SetTexture(GLOSS_TEXTURE)
    gloss:SetTextureCoords(0, 1, FILL_T, FILL_B)
    gloss:SetColor(1, 1, 1, 0.25)

    -- peak line: above gloss, below border
    local tpl = WM:CreateControl("VerdantBarTriPeak" .. m, area, CT_TEXTURE)
    tpl:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
    tpl:SetTexture(FILL_TEXTURE)
    tpl:SetTextureCoords(0, 1, FILL_T, FILL_B)
    tpl:SetDimensions(0, 2)
    tpl:SetColor(1, 1, 1, 0.92)
    tpl:SetHidden(true)
    col.peak_line = tpl

    -- 4-strip border (last = on top of fill + gloss)
    make_border(area, "VerdantBarTriBorder" .. m)

    -- value label (bottom of column)
    local val = WM:CreateControl("VerdantBarTriValue" .. m, container, CT_LABEL)
    val:ClearAnchors()
    val:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, x, 0)
    val:SetDimensions(TRI_COL_W, 14)
    val:SetFont("ZoFontGameSmall")
    val:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    col.value = val
  end
end

-- ── refresh (1 Hz tick + on user input) ──────────────────────────────────
local function refresh()
  if controls.window:IsHidden() then return end

  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)
  local m   = current_metric()

  controls.mode_btn:SetText(display_pct and "#" or "%")

  if m == "ALL" then
    -- ── triple-column view ────────────────────────────────────────────────
    controls.bar_area:SetHidden(true)
    controls.metric_label:SetHidden(true)
    controls.value_label:SetHidden(true)
    controls.tri_container:SetHidden(false)

    local vals = {
      EMS  = { frac = r.C_self   or 0, raw = r.EMS  or 0 },
      eHPS = { frac = r.C_heal   or 0, raw = r.eHPS or 0 },
      MPS  = { frac = r.C_shield or 0, raw = r.MPS  or 0 },
    }

    for _, cm in ipairs(TRI_COLS) do
      local col   = controls.tri[cm]
      local v     = vals[cm]
      local col_c = COLORS[cm]
      local frac  = math_max(0, math_min(1, v.frac))

      col.label:SetText(cm)
      col.label:SetColor(col_c.r, col_c.g, col_c.b, 1)

      if display_pct then
        col.value:SetText(string_format("%.0f%%", frac * 100))
      else
        col.value:SetText(string_format("%d", math_floor(v.raw)))
      end
      col.value:SetColor(1, 1, 1, 1)

      update_peak(cm, frac, now)

      local area_w = col.area:GetWidth()
      local area_h = col.area:GetHeight()
      if area_h > 4 then
        if cm == "eHPS" then
          col.fill:SetHidden(true)
          local segs = Verdant.Metrics.eHPS_by_group(now)
          render_skill_segments(col.pool, col.area, segs, area_w, area_h, frac)
        elseif cm == "MPS" then
          col.fill:SetHidden(true)
          local segs = Verdant.Metrics.MPS_by_group(now)
          render_skill_segments(col.pool, col.area, segs, area_w, area_h, frac)
        else
          -- EMS: stacked heal (green, bottom) + shield (pink, above)
          col.fill:SetHidden(true)
          local heal_frac   = math_max(0, math_min(1, r.C_heal   or 0))
          local shield_frac = math_max(0, math_min(1, r.C_shield or 0))
          local heal_h      = (heal_frac   > 0.005) and math_max(2, area_h * heal_frac)   or 0
          local shield_h    = (shield_frac > 0.005) and math_max(2, area_h * shield_frac) or 0

          local fh = col.fill_heal
          fh:SetHidden(false)
          fh:SetWidth(area_w)
          fh:SetHeight(heal_h)

          local fs = col.fill_shield
          fs:ClearAnchors()
          fs:SetAnchor(BOTTOMLEFT, col.area, BOTTOMLEFT, 0, -heal_h)
          fs:SetHidden(false)
          fs:SetWidth(area_w)
          fs:SetHeight(shield_h)
        end
        render_peak_line(col.peak_line, col.area, area_w, area_h, peaks[cm].frac)
      end
    end

  else
    -- ── single-metric view ────────────────────────────────────────────────
    controls.bar_area:SetHidden(false)
    controls.metric_label:SetHidden(false)
    controls.value_label:SetHidden(false)
    controls.tri_container:SetHidden(true)

    local frac, raw, suffix = contribution_values(r)
    frac = math_max(0, math_min(1, frac or 0))
    raw  = raw or 0
    local color = COLORS[m]

    controls.metric_label:SetText(m)
    controls.metric_label:SetColor(color.r, color.g, color.b, 1)

    if display_pct then
      controls.value_label:SetText(string_format("%.0f%%", frac * 100))
    else
      controls.value_label:SetText(string_format("%d %s", math_floor(raw), suffix))
    end
    controls.value_label:SetColor(1, 1, 1, 1)

    local area_w = controls.bar_area:GetWidth()
    local area_h = controls.bar_area:GetHeight()
    if area_h <= 4 then return end

    update_peak(m, frac, now)

    if m == "EMS" then
      -- stacked fill: eHPS green (bottom), MPS pink (above); no per-skill coloring
      controls.fill:SetHidden(true)
      for i = 1, POOL_SIZE do controls.pool_ehps[i]:SetHidden(true) end
      for i = 1, POOL_SIZE do controls.pool_mps[i]:SetHidden(true)  end

      local heal_frac   = math_max(0, math_min(1, r.C_heal   or 0))
      local shield_frac = math_max(0, math_min(1, r.C_shield or 0))
      local heal_h      = (heal_frac   > 0.005) and math_max(2, area_h * heal_frac)   or 0
      local shield_h    = (shield_frac > 0.005) and math_max(2, area_h * shield_frac) or 0

      local fh = controls.fill_heal
      fh:SetHidden(false)
      fh:SetWidth(area_w)
      fh:SetHeight(heal_h)

      local fs = controls.fill_shield
      fs:ClearAnchors()
      fs:SetAnchor(BOTTOMLEFT, controls.bar_area, BOTTOMLEFT, 0, -heal_h)
      fs:SetHidden(false)
      fs:SetWidth(area_w)
      fs:SetHeight(shield_h)

    elseif m == "eHPS" then
      controls.fill:SetHidden(true)
      controls.fill_heal:SetHidden(true)
      controls.fill_shield:SetHidden(true)
      for i = 1, POOL_SIZE do controls.pool_mps[i]:SetHidden(true) end
      local segs = Verdant.Metrics.eHPS_by_group(now)
      render_skill_segments(controls.pool_ehps, controls.bar_area, segs, area_w, area_h, frac)

    elseif m == "MPS" then
      controls.fill:SetHidden(true)
      controls.fill_heal:SetHidden(true)
      controls.fill_shield:SetHidden(true)
      for i = 1, POOL_SIZE do controls.pool_ehps[i]:SetHidden(true) end
      local segs = Verdant.Metrics.MPS_by_group(now)
      render_skill_segments(controls.pool_mps, controls.bar_area, segs, area_w, area_h, frac)
    end

    render_peak_line(controls.peak_line, controls.bar_area, area_w, area_h, peaks[m].frac)
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.prev_metric()
  metric_idx = ((metric_idx - 2) % #DISPLAY_METRICS) + 1
  PlaySound(SOUNDS.DIALOG_ACCEPT)
  apply_size_constraints()
  save_state()
  refresh()
end

function M.next_metric()
  metric_idx = (metric_idx % #DISPLAY_METRICS) + 1
  PlaySound(SOUNDS.DIALOG_ACCEPT)
  apply_size_constraints()
  save_state()
  refresh()
end

function M.toggle_display_mode()
  display_pct = not display_pct
  PlaySound(SOUNDS.DIALOG_ACCEPT)
  save_state()
  refresh()
end

function M.toggle()
  local hidden = controls.window:IsHidden()
  controls.window:SetHidden(not hidden)
  PlaySound(hidden and SOUNDS.ARMORY_OPEN or SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
  save_state()
end

function M.show()
  controls.window:SetHidden(false)
  PlaySound(SOUNDS.ARMORY_OPEN)
  save_state()
end

function M.hide()
  controls.window:SetHidden(true)
  PlaySound(SOUNDS.ADVENTURE_ZONE_OVERVIEW_CLOSED)
  save_state()
end

-- Called by Settings when the slider changes
function M.set_rate(ms)
  Verdant.Events.unregister_update("Verdant_BarTick")
  Verdant.Events.register_update("Verdant_BarTick", ms, refresh)
end

function M.on_move_stop()
  local left, top = controls.window:GetScreenRect()
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar.x, sv.bar.y = left, top end
end

function M.reset_peaks()
  for k in pairs(peaks) do peaks[k].frac = 0 ; peaks[k].t = 0 end
end

function M.on_resize_stop()
  local w, h = controls.window:GetDimensions()
  local is_all = (current_metric() == "ALL")
  local min_w  = is_all and MIN_W_ALL or MIN_W_SINGLE
  local max_w  = is_all and MAX_W_ALL or MAX_W_SINGLE
  w = math_max(min_w, math_min(max_w, w))
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
  controls.title_label   = VerdantBarWindowTitleLabel
  controls.metric_label  = VerdantBarWindowMetricLabel
  controls.value_label   = VerdantBarWindowValueLabel
  controls.bar_area      = VerdantBarWindowBarArea
  controls.mode_btn      = VerdantBarWindowModeBtn
  controls.version_label = VerdantBarWindowVersionLabel
  controls.api_label     = VerdantBarWindowApiLabel
  controls.prev_btn      = VerdantBarWindowPrevBtn
  controls.next_btn      = VerdantBarWindowNextBtn
  controls.settings_btn  = VerdantBarWindowSettingsBtn

  controls.title_label:SetText("Verdant")
  controls.title_label:SetColor(0.55, 0.55, 0.55, 0.70)

  controls.prev_btn:SetText("<")
  controls.prev_btn:SetColor(0.75, 0.75, 0.75, 1)
  controls.next_btn:SetText(">")
  controls.next_btn:SetColor(0.75, 0.75, 0.75, 1)

  controls.api_label:SetHidden(true)
  controls.version_label:SetText(string_format("v%s  API %d", C.VERSION, GetAPIVersion()))
  controls.version_label:SetColor(0.40, 0.40, 0.40, 1)

  local is_all = (DISPLAY_METRICS[metric_idx] == "ALL")
  local min_w  = is_all and MIN_W_ALL or MIN_W_SINGLE
  local max_w  = is_all and MAX_W_ALL or MAX_W_SINGLE
  controls.window:SetDimensionConstraints(min_w, MIN_H, max_w, MAX_H)
  controls.window:SetDimensions(b.w or 70, b.h or 240)

  if b.x and b.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, b.x, b.y)
  end

  setup_single_bar()
  setup_triple_view()

  local visible = (b.visible == nil) and true or b.visible
  controls.window:SetHidden(not visible)

  local rate_ms = b.rate_ms or 1000
  Verdant.Events.register_update("Verdant_BarTick", rate_ms, refresh)
  refresh()
end
