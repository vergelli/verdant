Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Bar = {}
local M = Verdant.Bar

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetAPIVersion           = GetAPIVersion
local PlaySound               = PlaySound
local string_format           = string.format
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor

-- ── display metric cycle ──────────────────────────────────────────────────
-- "ALL" is the 4th position: shows three columns simultaneously
local DISPLAY_METRICS = { "EMS", "eHPS", "MPS", "ALL" }

local COLORS = {
  EMS  = { r = 0.95, g = 0.80, b = 0.20, a = 0.92 },
  eHPS = { r = 0.25, g = 0.88, b = 0.35, a = 0.92 },
  MPS  = { r = 0.90, g = 0.38, b = 0.68, a = 0.92 },
}

local FILL_TEXTURE  = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE    = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local BORDER_EDGE   = "EsoUI/Art/Tooltips/UI-Border.dds"
local FILL_T, FILL_B = 0, 0.53125

-- ── size constraints ──────────────────────────────────────────────────────
local MIN_W_SINGLE, MAX_W_SINGLE = 60,  140
local MIN_W_ALL,    MAX_W_ALL    = 110, 200
local MIN_H,        MAX_H        = 180, 440

-- triple-view column geometry (fixed, centered in window)
local TRI_COL_W   = 26
local TRI_COL_GAP = 8
local TRI_COLS    = { "EMS", "eHPS", "MPS" }
local TRI_COL_X   = { EMS = 0, eHPS = TRI_COL_W + TRI_COL_GAP, MPS = (TRI_COL_W + TRI_COL_GAP) * 2 }
local TRI_TOTAL_W = TRI_COL_W * 3 + TRI_COL_GAP * 2   -- 94

-- ── state ─────────────────────────────────────────────────────────────────
local metric_idx  = 1
local display_pct = false
local controls    = {}  -- flat bag: .window, .bar_area, .fill, .tri_container, .tri[m], …

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

-- ── small helper: create a CT_BACKDROP border overlay (transparent center) ──
-- Created LAST inside a parent so it renders on top of fill textures.
local function make_border(parent, name)
  local WM     = WINDOW_MANAGER
  local border = WM:CreateControl(name, parent, CT_BACKDROP)
  border:ClearAnchors()
  border:SetAnchor(TOPLEFT,     parent, TOPLEFT,     0, 0)
  border:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
  border:SetEdgeTexture(BORDER_EDGE, 128, 16, 3, 0)
  border:SetCenterColor(0, 0, 0, 0)
  border:SetInsets(3, 3, -3, -3)
  return border
end

-- ── single-bar texture setup ──────────────────────────────────────────────
local function setup_single_bar()
  local WM   = WINDOW_MANAGER
  local area = controls.bar_area

  local bg = WM:CreateControl("VerdantBarBg", area, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(0.10, 0.10, 0.12, 1)
  controls.bg = bg

  -- main fill (eHPS / MPS single metric, or EMS total)
  local fill = WM:CreateControl("VerdantBarFill", area, CT_TEXTURE)
  fill:ClearAnchors()
  fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fill:SetTexture(FILL_TEXTURE)
  fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local c = COLORS["EMS"]
  fill:SetColor(c.r, c.g, c.b, c.a)
  controls.fill = fill

  -- EMS stacked mode: eHPS green segment (bottom)
  local fh = WM:CreateControl("VerdantBarFillHeal", area, CT_TEXTURE)
  fh:ClearAnchors()
  fh:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fh:SetTexture(FILL_TEXTURE)
  fh:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local ch = COLORS["eHPS"]
  fh:SetColor(ch.r, ch.g, ch.b, ch.a)
  fh:SetHidden(true)
  controls.fill_heal = fh

  -- EMS stacked mode: MPS pink segment (above eHPS).
  -- Bottom anchor is repositioned each tick in refresh() to sit atop fill_heal.
  local fs = WM:CreateControl("VerdantBarFillShield", area, CT_TEXTURE)
  fs:ClearAnchors()
  fs:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
  fs:SetTexture(FILL_TEXTURE)
  fs:SetTextureCoords(0, 1, FILL_T, FILL_B)
  local cs = COLORS["MPS"]
  fs:SetColor(cs.r, cs.g, cs.b, cs.a)
  fs:SetHidden(true)
  controls.fill_shield = fs

  -- CT_BACKDROP border — created LAST so it renders on top of all fills
  controls.bar_border = make_border(area, "VerdantBarBorder")
end

-- ── triple-column view setup (created in Lua inside main window) ──────────
local function setup_triple_view()
  local WM  = WINDOW_MANAGER
  local win = controls.window

  -- container: same vertical span as bar_area (TOP+BOTTOM), fixed width centered
  local container = WM:CreateControl("VerdantBarTriContainer", win, CT_CONTROL)
  container:ClearAnchors()
  container:SetAnchor(TOP,    win, TOP,    0, 46)
  container:SetAnchor(BOTTOM, win, BOTTOM, 0, -36)
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

    -- bar area (between labels)
    local area = WM:CreateControl("VerdantBarTriArea" .. m, container, CT_CONTROL)
    area:ClearAnchors()
    area:SetAnchor(TOPLEFT,    container, TOPLEFT,    x, 18)
    area:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, x, -18)
    area:SetWidth(TRI_COL_W)
    col.area = area

    -- bg
    local bg = WM:CreateControl("VerdantBarTriBg" .. m, area, CT_TEXTURE)
    bg:ClearAnchors()
    bg:SetAnchor(TOPLEFT,     area, TOPLEFT,     0, 0)
    bg:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
    bg:SetTexture(BG_TEXTURE)
    bg:SetColor(0.10, 0.10, 0.12, 1)

    -- fill
    local fill = WM:CreateControl("VerdantBarTriFill" .. m, area, CT_TEXTURE)
    fill:ClearAnchors()
    fill:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, 0)
    fill:SetTexture(FILL_TEXTURE)
    fill:SetTextureCoords(0, 1, FILL_T, FILL_B)
    local c = COLORS[m]
    fill:SetColor(c.r, c.g, c.b, c.a)
    col.fill = fill

    -- border (last = on top)
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

-- ── refresh (called by 1 Hz tick and on user input) ───────────────────────
local function refresh()
  if controls.window:IsHidden() then return end

  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)
  local m   = current_metric()

  if m == "ALL" then
    -- ── triple-column view ────────────────────────────────────────────────
    controls.bar_area:SetHidden(true)
    controls.metric_label:SetHidden(true)
    controls.value_label:SetHidden(true)
    controls.mode_btn:SetHidden(true)
    controls.tri_container:SetHidden(false)

    local vals = {
      EMS  = { frac = r.C_self   or 0, raw = r.EMS  or 0 },
      eHPS = { frac = r.C_heal   or 0, raw = r.eHPS or 0 },
      MPS  = { frac = r.C_shield or 0, raw = r.MPS  or 0 },
    }

    for _, cm in ipairs(TRI_COLS) do
      local col  = controls.tri[cm]
      local v    = vals[cm]
      local col_c = COLORS[cm]
      local frac = math_max(0, math_min(1, v.frac))

      col.label:SetText(cm)
      col.label:SetColor(col_c.r, col_c.g, col_c.b, 1)
      col.value:SetText(string_format("%d", math_floor(v.raw)))
      col.value:SetColor(1, 1, 1, 1)

      local area_w = col.area:GetWidth()
      local area_h = col.area:GetHeight()
      if area_h > 4 then
        local fill_h = (frac > 0.005) and math_max(2, area_h * frac) or 0
        col.fill:SetWidth(area_w)
        col.fill:SetHeight(fill_h)
      end
    end

  else
    -- ── single-metric view ────────────────────────────────────────────────
    controls.bar_area:SetHidden(false)
    controls.metric_label:SetHidden(false)
    controls.value_label:SetHidden(false)
    controls.mode_btn:SetHidden(false)
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

    controls.mode_btn:SetText(display_pct and "#" or "%")
    controls.mode_btn:SetColor(0.75, 0.75, 0.75, 1)

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
      fs:ClearAnchors()
      fs:SetAnchor(BOTTOMLEFT, controls.bar_area, BOTTOMLEFT, 0, -heal_h)
      fs:SetHidden(false)
      fs:SetWidth(area_w)
      fs:SetHeight(shield_h)
    else
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

function M.on_move_stop()
  local left, top = controls.window:GetScreenRect()
  local sv = Verdant.SavedVars
  if sv then sv.bar = sv.bar or {} ; sv.bar.x, sv.bar.y = left, top end
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
  controls.metric_label  = VerdantBarWindowMetricLabel
  controls.value_label   = VerdantBarWindowValueLabel
  controls.bar_area      = VerdantBarWindowBarArea
  controls.mode_btn      = VerdantBarWindowModeBtn
  controls.version_label = VerdantBarWindowVersionLabel
  controls.api_label     = VerdantBarWindowApiLabel
  controls.prev_btn      = VerdantBarWindowPrevBtn
  controls.next_btn      = VerdantBarWindowNextBtn

  controls.prev_btn:SetText("<")
  controls.prev_btn:SetColor(0.75, 0.75, 0.75, 1)
  controls.next_btn:SetText(">")
  controls.next_btn:SetColor(0.75, 0.75, 0.75, 1)

  controls.api_label:SetText(string_format("API %d", GetAPIVersion()))
  controls.api_label:SetColor(0.45, 0.45, 0.45, 1)
  controls.version_label:SetText(string_format("v%s", C.VERSION))
  controls.version_label:SetColor(0.45, 0.45, 0.45, 1)

  -- restore size and position
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

  -- show before first refresh so GetWidth/GetHeight return real values
  local visible = (b.visible == nil) and true or b.visible
  controls.window:SetHidden(not visible)

  Verdant.Events.register_update("Verdant_BarTick", 1000, refresh)
  refresh()
end
