Verdant = Verdant or {}
Verdant.Graph = {}
local M = Verdant.Graph

local api  = Verdant.zenimax.api
local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local zev  = Verdant.zenimax.events
local WINDOW_MANAGER             = zui.WINDOW_MANAGER
local GetGameTimeMilliseconds    = api.GetGameTimeMilliseconds
local GetString                  = api.GetString
local math_max                   = math.max
local math_floor                 = math.floor
local string_format              = string.format

local log               = Verdant.Log.for_module("graph")
local TOPLEFT           = zc.TOPLEFT
local TOPRIGHT          = zc.TOPRIGHT
local BOTTOMLEFT        = zc.BOTTOMLEFT
local BOTTOM            = zc.BOTTOM
local BOTTOMRIGHT       = zc.BOTTOMRIGHT
local CENTER            = zc.CENTER
local GuiRoot           = zc.GuiRoot
local CT_TEXTURE        = zc.CT_TEXTURE
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_LEFT   = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local TEXT_ALIGN_RIGHT  = zc.TEXT_ALIGN_RIGHT
local TEXT_ALIGN_BOTTOM = zc.TEXT_ALIGN_BOTTOM

-- Colors matching bar.lua
local C_EHPS      = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 }  -- pastel green fill
local C_MPS       = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 }  -- pastel pink fill
local C_LINE_EHPS = { r = 0.65, g = 1.00, b = 0.72, a = 1.00 }  -- brighter green line
local C_LINE_EMS  = { r = 1.00, g = 0.78, b = 0.90, a = 1.00 }  -- brighter pink line

local C_NONCRIT   = { r = 0.34, g = 0.55, b = 0.40, a = 0.90 }  -- muted green base
local C_CRIT      = { r = 1.00, g = 0.85, b = 0.40, a = 0.96 }  -- bright gold (crit pops)

local C_VIEWPORT  = { r = 0.78, g = 1.00, b = 0.86 }

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_T, FILL_B = 0, 0.53125
local LINE_THICKNESS = 2
local LABEL_H        = 12
local N_HGRID      = 3
local N_VGRID      = 3
local TIME_STRIP_H = 18
local C_GRID_LINE = { r = 0.55, g = 0.58, b = 0.70, a = 0.25 }
local C_GRID_LBL  = { r = 0.82, g = 0.85, b = 0.90, a = 0.92 }
local C_TIME_LBL  = { r = 0.68, g = 0.70, b = 0.75, a = 0.85 }


local controls           = {}
local recording_start_ms = 0

local VIEW_EMS    = 1
local VIEW_SKILL  = 2
local VIEW_CRIT   = 3
local VIEW_LABELS = { "EMS", "SKILL", "CRIT" }
local current_view = VIEW_EMS

local function fmt_val(v)
  return ZO_AbbreviateAndLocalizeNumber(math_floor(v), 0, false)
end

local function fmt_secs(ms)
  local s = math_floor(ms / 1000)
  if s >= 60 then return string_format("%d:%02d", math_floor(s / 60), s % 60) end
  return s .. "s"
end

local Pool = Verdant.lib.plot.Pool

local function fill_factory(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, FILL_T, FILL_B)
  c:SetPixelRoundingEnabled(false)
end

local function fill_reset(c)
  c:SetHidden(true)
end

local function line_factory(line)
  line:SetThickness(LINE_THICKNESS)
end

local function line_reset(line)
  line:SetHidden(true)
  line:ClearAnchors()
end

local function make_fill_pool(name_prefix)
  return Pool.new(name_prefix, controls.canvas, CT_TEXTURE, fill_factory, fill_reset)
end

local function make_skill_fill_pool(name_prefix, canvas_key)
  return Pool.new(name_prefix, controls[canvas_key], CT_TEXTURE, fill_factory, fill_reset)
end

local function make_line_pool(name_prefix)
  return Pool.new_virtual(name_prefix, controls.canvas, "VerdantGraphLineTemplate", line_factory, line_reset)
end

local function make_skill_line_pool(name_prefix, canvas_key)
  return Pool.new_virtual(name_prefix, controls[canvas_key], "VerdantGraphLineTemplate", line_factory, line_reset)
end

local function create_grid(prefix, parent_ctrl)
  local WM  = WINDOW_MANAGER
  local obj = { hlines = {}, vlines = {}, ylabels = {} }

  for i = 1, N_HGRID do
    local gl = WM:CreateControl(prefix .. "H" .. i, parent_ctrl, CT_TEXTURE)
    gl:SetTexture(FILL_TEXTURE)
    gl:SetTextureCoords(0, 1, 0, 0.05)
    gl:SetHeight(1)
    gl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    gl:SetHidden(true)
    obj.hlines[i] = gl

    local lbl = WM:CreateControl(prefix .. "YL" .. i, parent_ctrl, CT_LABEL)
    lbl:SetFont("ZoFontGameSmall")
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    lbl:SetColor(C_GRID_LBL.r, C_GRID_LBL.g, C_GRID_LBL.b, C_GRID_LBL.a)
    lbl:SetDimensions(54, 10)
    lbl:SetHidden(true)
    obj.ylabels[i] = lbl
  end

  for i = 1, N_VGRID do
    local vl = WM:CreateControl(prefix .. "V" .. i, parent_ctrl, CT_TEXTURE)
    vl:SetTexture(FILL_TEXTURE)
    vl:SetTextureCoords(0, 0.05, 0, 1)
    vl:SetWidth(1)
    vl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    vl:SetHidden(true)
    obj.vlines[i] = vl
  end

  local function make_time_lbl(name, align)
    local t = WM:CreateControl(name, parent_ctrl, CT_LABEL)
    t:SetFont("ZoFontGameSmall")
    t:SetHorizontalAlignment(align)
    t:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    t:SetColor(C_TIME_LBL.r, C_TIME_LBL.g, C_TIME_LBL.b, C_TIME_LBL.a)
    t:SetDimensions(44, 10)
    t:SetHidden(true)
    return t
  end
  obj.time_l = make_time_lbl(prefix .. "TL", TEXT_ALIGN_LEFT)
  obj.time_m = make_time_lbl(prefix .. "TM", TEXT_ALIGN_CENTER)
  obj.time_r = make_time_lbl(prefix .. "TR", TEXT_ALIGN_RIGHT)

  return obj
end

local function hide_grid(grid)
  for i = 1, N_HGRID do
    grid.hlines[i]:SetHidden(true)
    grid.ylabels[i]:SetHidden(true)
  end
  for i = 1, N_VGRID do
    grid.vlines[i]:SetHidden(true)
  end
  grid.time_l:SetHidden(true)
  grid.time_m:SetHidden(true)
  grid.time_r:SetHidden(true)
end

local function draw_grid(grid, canvas, max_val, span_ms)
  local cw = canvas:GetWidth()
  local ch = canvas:GetHeight()
  if cw <= 0 or ch <= 0 then
    hide_grid(grid)
    return
  end

  local has_y    = (max_val > 0)
  local has_time = (span_ms > 0)
  if not has_y and not has_time then
    hide_grid(grid)
    return
  end

  local y_base   = has_time and TIME_STRIP_H or 0
  local ch_plot  = math_max(1, ch - y_base)

  if has_y then
    for i = 1, N_HGRID do
      local frac = i / (N_HGRID + 1)
      local y    = y_base + math_floor(ch_plot * frac)

      local gl = grid.hlines[i]
      gl:ClearAnchors()
      gl:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT,  0, -y)
      gl:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, 0, -y)
      gl:SetHidden(false)

      local lbl = grid.ylabels[i]
      lbl:ClearAnchors()
      lbl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 2, -(y + 1))
      lbl:SetText(fmt_val(max_val * frac))
      lbl:SetHidden(false)
    end
  else
    for i = 1, N_HGRID do
      grid.hlines[i]:SetHidden(true)
      grid.ylabels[i]:SetHidden(true)
    end
  end

  for i = 1, N_VGRID do
    local frac = i / (N_VGRID + 1)
    local x    = math_floor(cw * frac)

    local vl = grid.vlines[i]
    vl:ClearAnchors()
    vl:SetAnchor(TOPLEFT,    canvas, TOPLEFT,    x, 0)
    vl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -y_base)
    vl:SetHidden(false)
  end

  if has_time then
    grid.time_l:ClearAnchors()
    grid.time_l:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT,  2, 0)
    grid.time_l:SetText("0s")
    grid.time_l:SetHidden(false)

    grid.time_m:ClearAnchors()
    grid.time_m:SetAnchor(BOTTOM, canvas, BOTTOM, 0, 0)
    grid.time_m:SetText(fmt_secs(span_ms / 2))
    grid.time_m:SetHidden(false)

    grid.time_r:ClearAnchors()
    grid.time_r:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, -2, 0)
    grid.time_r:SetText(fmt_secs(span_ms))
    grid.time_r:SetHidden(false)
  else
    grid.time_l:SetHidden(true)
    grid.time_m:SetHidden(true)
    grid.time_r:SetHidden(true)
  end
end

local function release_all_pools()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_line_ehps:ReleaseAllObjects()
  controls.pool_line_ems:ReleaseAllObjects()
  controls.pool_skill_top:ReleaseAllObjects()
  controls.pool_skill_bot:ReleaseAllObjects()
  controls.pool_line_skill_top:ReleaseAllObjects()
  controls.pool_line_skill_bot:ReleaseAllObjects()
end

local function hide_all_grids()
  hide_grid(controls.grid_ems)
  hide_grid(controls.grid_top)
  hide_grid(controls.grid_bot)
end

local function layout_skill_area()
  local sa = controls.skill_area
  local sw = sa:GetWidth()
  local sh = sa:GetHeight()
  if sw <= 0 or sh <= 0 then return end

  local usable = sh - LABEL_H * 2 - 4
  if usable < 2 then return end
  local top_h = math_floor(usable / 2)
  local bot_h = usable - top_h
  local mid_y = LABEL_H + top_h + 2

  controls.ehps_label:ClearAnchors()
  controls.ehps_label:SetAnchor(TOPLEFT, sa, TOPLEFT, 0, 0)
  controls.ehps_label:SetDimensions(sw, LABEL_H)

  controls.ehps_canvas:ClearAnchors()
  controls.ehps_canvas:SetAnchor(TOPLEFT, sa, TOPLEFT, 0, LABEL_H)
  controls.ehps_canvas:SetDimensions(sw, top_h)

  controls.mps_label:ClearAnchors()
  controls.mps_label:SetAnchor(TOPLEFT, sa, TOPLEFT, 0, mid_y)
  controls.mps_label:SetDimensions(sw, LABEL_H)

  controls.mps_canvas:ClearAnchors()
  controls.mps_canvas:SetAnchor(TOPLEFT, sa, TOPLEFT, 0, mid_y + LABEL_H)
  controls.mps_canvas:SetDimensions(sw, bot_h)
end

local r1_xs, r1_ehps_hs, r1_ems_hs = {}, {}, {}
local r2_xs_top, r2_colh_top       = {}, {}
local r2_xs_bot, r2_colh_bot       = {}, {}
local r3_xs, r3_top_hs             = {}, {}

local function render_view1()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_line_ehps:ReleaseAllObjects()
  controls.pool_line_ems:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_ems)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas  = controls.canvas
  local cw      = canvas:GetWidth()
  local ch      = canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end

  local ch_plot = math_max(4, ch - TIME_STRIP_H)

  local max_ems = 0
  local t_first, t_last = 0, 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    local ems = s.eHPS + s.MPS
    if ems > max_ems then max_ems = ems end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end)
  if max_ems <= 0 then return end

  draw_grid(controls.grid_ems, canvas, max_ems, t_last - t_first)


  local capacity    = Verdant.TemporalBuffer.capacity()
  local slot_w      = cw / capacity
  local bar_gap     = (slot_w > 3) and 1 or 0
  local bw          = math_max(1, slot_w - bar_gap)
  local slot_offset = capacity - n
  local xs          = r1_xs
  local ehps_hs     = r1_ehps_hs
  local ems_hs      = r1_ems_hs

  Verdant.TemporalBuffer.iterate(function(i, s)
    local x  = (slot_offset + i - 1) * slot_w
    local xc = x + bw * 0.5

    local ehps_h = math_max(0, math_floor(ch_plot * (s.eHPS / max_ems) + 0.5))
    local mps_h  = math_max(0, math_floor(ch_plot * (s.MPS  / max_ems) + 0.5))

    xs[i]      = xc
    ehps_hs[i] = ehps_h
    ems_hs[i]  = ehps_h + mps_h

    if ehps_h > 0 then
      local te = controls.pool_ehps:AcquireObject()
      te:ClearAnchors()
      te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      te:SetWidth(bw)
      te:SetHeight(ehps_h)
      te:SetColor(C_EHPS.r, C_EHPS.g, C_EHPS.b, C_EHPS.a)
      te:SetHidden(false)
    end

    if mps_h > 0 then
      local tm = controls.pool_mps:AcquireObject()
      tm:ClearAnchors()
      tm:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + ehps_h))
      tm:SetWidth(bw)
      tm:SetHeight(mps_h)
      tm:SetColor(C_MPS.r, C_MPS.g, C_MPS.b, C_MPS.a)
      tm:SetHidden(false)
    end
  end)

  if slot_w >= 3 then
    for i = 2, n do
      local x1, x2 = xs[i-1], xs[i]

      local le = controls.pool_line_ehps:AcquireObject()
      le:ClearAnchors()
      le:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, x1, -(ehps_hs[i-1] + TIME_STRIP_H))
      le:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, x2, -(ehps_hs[i]   + TIME_STRIP_H))
      le:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, C_LINE_EHPS.a)
      le:SetThickness(LINE_THICKNESS)
      le:SetHidden(false)

      local lm = controls.pool_line_ems:AcquireObject()
      lm:ClearAnchors()
      lm:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, x1, -(ems_hs[i-1] + TIME_STRIP_H))
      lm:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, x2, -(ems_hs[i]   + TIME_STRIP_H))
      lm:SetColor(C_LINE_EMS.r, C_LINE_EMS.g, C_LINE_EMS.b, C_LINE_EMS.a)
      lm:SetThickness(LINE_THICKNESS)
      lm:SetHidden(false)
    end
  end
end

local function render_view2()
  controls.pool_skill_top:ReleaseAllObjects()
  controls.pool_skill_bot:ReleaseAllObjects()
  controls.pool_line_skill_top:ReleaseAllObjects()
  controls.pool_line_skill_bot:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_top)
    hide_grid(controls.grid_bot)
    return
  end
  controls.no_data:SetHidden(true)

  local ec = controls.ehps_canvas
  local mc = controls.mps_canvas
  local cw = ec:GetWidth()
  if cw <= 0 then return end

  local max_ehps, max_mps = 0, 0
  local t_first, t_last   = 0, 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    if s.eHPS > max_ehps then max_ehps = s.eHPS end
    if s.MPS  > max_mps  then max_mps  = s.MPS  end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end)
  local span_ms    = t_last - t_first
  local max_shared = math_max(max_ehps, max_mps)

  draw_grid(controls.grid_top, ec, max_shared, 0)
  draw_grid(controls.grid_bot, mc, max_shared, span_ms)

  local capacity    = Verdant.TemporalBuffer.capacity()
  local slot_w      = cw / capacity
  local bar_gap     = (slot_w > 3) and 1 or 0
  local bw          = math_max(1, slot_w - bar_gap)
  local slot_offset = capacity - n

  if max_ehps > 0 then
    local ch     = ec:GetHeight()
    local xs     = r2_xs_top
    local col_hs = r2_colh_top

    Verdant.TemporalBuffer.iterate(function(i, s)
      local x     = (slot_offset + i - 1) * slot_w
      local col_h = math_max(0, math_floor(ch * (s.eHPS / max_shared) + 0.5))
      xs[i]      = x + bw * 0.5
      col_hs[i]  = col_h

      local y_off   = 0
      local egroups = s.ehps_groups
      for gi = 1, egroups.count do
        local grp   = egroups[gi]
        local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
        local t = controls.pool_skill_top:AcquireObject()
        t:ClearAnchors()
        t:SetAnchor(BOTTOMLEFT, ec, BOTTOMLEFT, x, -y_off)
        t:SetWidth(bw)
        t:SetHeight(seg_h)
        t:SetColor(grp.r, grp.g, grp.b, grp.a)
        t:SetHidden(false)
        y_off = y_off + seg_h
      end
    end)

    if slot_w >= 3 then
      for i = 2, n do
        local le = controls.pool_line_skill_top:AcquireObject()
        le:ClearAnchors()
        le:SetAnchor(BOTTOMLEFT,  ec, BOTTOMLEFT, xs[i-1], -col_hs[i-1])
        le:SetAnchor(BOTTOMRIGHT, ec, BOTTOMLEFT, xs[i],   -col_hs[i])
        le:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, C_LINE_EHPS.a)
        le:SetThickness(LINE_THICKNESS)
        le:SetHidden(false)
      end
    end
  end

  if max_mps > 0 then
    local ch_plot = math_max(1, mc:GetHeight() - TIME_STRIP_H)
    local xs      = r2_xs_bot
    local col_hs  = r2_colh_bot

    Verdant.TemporalBuffer.iterate(function(i, s)
      local x     = (slot_offset + i - 1) * slot_w
      local col_h = math_max(0, math_floor(ch_plot * (s.MPS / max_shared) + 0.5))
      xs[i]      = x + bw * 0.5
      col_hs[i]  = col_h

      local y_off   = 0
      local mgroups = s.mps_groups
      for gi = 1, mgroups.count do
        local grp   = mgroups[gi]
        local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
        local t = controls.pool_skill_bot:AcquireObject()
        t:ClearAnchors()
        t:SetAnchor(BOTTOMLEFT, mc, BOTTOMLEFT, x, -(y_off + TIME_STRIP_H))
        t:SetWidth(bw)
        t:SetHeight(seg_h)
        t:SetColor(grp.r, grp.g, grp.b, grp.a)
        t:SetHidden(false)
        y_off = y_off + seg_h
      end
    end)

    if slot_w >= 3 then
      for i = 2, n do
        local lm = controls.pool_line_skill_bot:AcquireObject()
        lm:ClearAnchors()
        lm:SetAnchor(BOTTOMLEFT,  mc, BOTTOMLEFT, xs[i-1], -(col_hs[i-1] + TIME_STRIP_H))
        lm:SetAnchor(BOTTOMRIGHT, mc, BOTTOMLEFT, xs[i],   -(col_hs[i]   + TIME_STRIP_H))
        lm:SetColor(C_LINE_EMS.r, C_LINE_EMS.g, C_LINE_EMS.b, C_LINE_EMS.a)
        lm:SetThickness(LINE_THICKNESS)   -- invalidate cached segment geometry
        lm:SetHidden(false)
      end
    end
  end
end

local function render_view3()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_line_ehps:ReleaseAllObjects()
  controls.pool_line_ems:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_ems)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas  = controls.canvas
  local cw      = canvas:GetWidth()
  local ch      = canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H)

  local max_ehps = 0
  local t_first, t_last = 0, 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    if s.eHPS > max_ehps then max_ehps = s.eHPS end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end)
  if max_ehps <= 0 then
    hide_grid(controls.grid_ems)
    return
  end

  draw_grid(controls.grid_ems, canvas, max_ehps, t_last - t_first)

  local capacity    = Verdant.TemporalBuffer.capacity()
  local slot_w      = cw / capacity
  local bar_gap     = (slot_w > 3) and 1 or 0
  local bw          = math_max(1, slot_w - bar_gap)
  local slot_offset = capacity - n
  local xs          = r3_xs
  local top_hs      = r3_top_hs

  Verdant.TemporalBuffer.iterate(function(i, s)
    local x  = (slot_offset + i - 1) * slot_w
    local noncrit_h = math_max(0, math_floor(ch_plot * (s.noncrit / max_ehps) + 0.5))
    local crit_h    = math_max(0, math_floor(ch_plot * (s.crit    / max_ehps) + 0.5))
    xs[i]     = x + bw * 0.5
    top_hs[i] = noncrit_h + crit_h


    if noncrit_h > 0 then
      local tn = controls.pool_ehps:AcquireObject()
      tn:ClearAnchors()
      tn:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      tn:SetWidth(bw)
      tn:SetHeight(noncrit_h)
      tn:SetColor(C_NONCRIT.r, C_NONCRIT.g, C_NONCRIT.b, C_NONCRIT.a)
      tn:SetHidden(false)
    end


    if crit_h > 0 then
      local tc = controls.pool_mps:AcquireObject()
      tc:ClearAnchors()
      tc:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + noncrit_h))
      tc:SetWidth(bw)
      tc:SetHeight(crit_h)
      tc:SetColor(C_CRIT.r, C_CRIT.g, C_CRIT.b, C_CRIT.a)
      tc:SetHidden(false)
    end
  end)


  if slot_w >= 3 then
    for i = 2, n do
      local lt = controls.pool_line_ehps:AcquireObject()
      lt:ClearAnchors()
      lt:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, xs[i-1], -(top_hs[i-1] + TIME_STRIP_H))
      lt:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, xs[i],   -(top_hs[i]   + TIME_STRIP_H))
      lt:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, C_LINE_EHPS.a)
      lt:SetThickness(LINE_THICKNESS)
      lt:SetHidden(false)
    end
  end
end

local function render_current_view()
  if current_view == VIEW_EMS then
    render_view1()
  elseif current_view == VIEW_CRIT then
    render_view3()
  else
    layout_skill_area()
    render_view2()
  end
end

local function refresh_button_colors()
  local recording = Verdant.TemporalBuffer.is_recording()
  controls.btn_record:SetEnabled(not recording)
  controls.btn_stop:SetEnabled(recording)
end

local function set_view(v)
  current_view = v
  controls.view_label:SetText(VIEW_LABELS[v])

  local use_main_canvas = (v == VIEW_EMS or v == VIEW_CRIT)
  controls.canvas:SetHidden(not use_main_canvas)
  controls.skill_area:SetHidden(use_main_canvas)

  if Verdant.TemporalBuffer.count() == 0 then
    controls.no_data:SetHidden(false)
    return
  end
  controls.no_data:SetHidden(true)

  render_current_view()
end

local prof_enter = Verdant.Profiler.enter
local prof_exit  = Verdant.Profiler.exit

local sample_ehps_groups = { count = 0 }
local sample_mps_groups  = { count = 0 }

local function on_sample_update()
  prof_enter("graph.sample_tick")
  local now  = GetGameTimeMilliseconds()
  local ehps = Verdant.Metrics.eHPS(now)
  local mps  = Verdant.Metrics.MPS(now)
  local crit, noncrit = Verdant.Metrics.eHPS_crit_split(now)
  Verdant.Metrics.eHPS_by_group_into(sample_ehps_groups, now)
  Verdant.Metrics.MPS_by_group_into(sample_mps_groups, now)
  Verdant.TemporalBuffer.push(now, ehps, mps, crit, noncrit, sample_ehps_groups, sample_mps_groups)

  local elapsed = math_floor((now - recording_start_ms) / 1000)
  controls.status:SetText(string_format("%d:%02d", math_floor(elapsed / 60), elapsed % 60))

  if not controls.window:IsHidden() then
    render_current_view()
  end
  prof_exit("graph.sample_tick")
end

function M.on_record_click()
  if Verdant.TemporalBuffer.is_recording() then return end
  log:info("record click")
  Verdant.TemporalBuffer.clear()
  release_all_pools()
  hide_all_grids()
  controls.no_data:SetHidden(false)
  Verdant.TemporalBuffer.start_recording()
  recording_start_ms = GetGameTimeMilliseconds()
  local sv       = Verdant.SavedVars
  local interval = (sv and sv.temporal and sv.temporal.sample_rate_ms)
                   or Verdant.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  zev.register_update(Verdant.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  refresh_button_colors()
  controls.status:SetText("0:00")
end

function M.on_stop_click()
  if not Verdant.TemporalBuffer.is_recording() then return end
  log:info("stop click")
  Verdant.TemporalBuffer.stop_recording()
  zev.unregister_update(Verdant.Constants.TEMPORAL.UPDATE_NAME)
  refresh_button_colors()
  render_current_view()
end

function M.on_flush_click()
  if Verdant.TemporalBuffer.is_recording() then
    zev.unregister_update(Verdant.Constants.TEMPORAL.UPDATE_NAME)
    Verdant.TemporalBuffer.stop_recording()
  end
  Verdant.TemporalBuffer.clear()
  release_all_pools()
  hide_all_grids()
  refresh_button_colors()
  controls.status:SetText("")
  controls.no_data:SetHidden(false)
end

function M.on_close_click()
  Verdant.Visibility.set("graph", false)
  release_all_pools()
end

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.temporal = sv.temporal or {}
  local x, y = controls.window:GetCenter()
  sv.temporal.graph_x = x
  sv.temporal.graph_y = y
end

function M.on_resize_stop()
  local sv = Verdant.SavedVars
  if sv then
    sv.temporal = sv.temporal or {}
    local w, h = controls.window:GetDimensions()
    sv.temporal.graph_w = w
    sv.temporal.graph_h = h
  end
  if not controls.window:IsHidden() then
    render_current_view()
  end
end

function M.prev_view()
  local v = current_view - 1
  if v < VIEW_EMS then v = VIEW_CRIT end
  release_all_pools()
  set_view(v)
end

function M.next_view()
  local v = current_view + 1
  if v > VIEW_CRIT then v = VIEW_EMS end
  release_all_pools()
  set_view(v)
end

function M.set_viewport_alpha(a)
  VerdantGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, a)
end

function M.toggle()
  local now_visible = not Verdant.Visibility.get("graph")
  log:info("toggle ->", now_visible and "show" or "hide")
  Verdant.Visibility.set("graph", now_visible)
  if now_visible then
    local use_main_canvas = (current_view == VIEW_EMS or current_view == VIEW_CRIT)
    controls.canvas:SetHidden(not use_main_canvas)
    controls.skill_area:SetHidden(use_main_canvas)
    render_current_view()
  else
    release_all_pools()
  end
end


function M.init()
  local WM = WINDOW_MANAGER

  controls.window        = VerdantGraphWindow
  controls.title         = VerdantGraphWindowTitleLabel
  controls.btn_record    = VerdantGraphWindowRecordBtn
  controls.btn_stop      = VerdantGraphWindowStopBtn
  controls.btn_flush     = VerdantGraphWindowFlushBtn
  controls.status        = VerdantGraphWindowStatusLabel
  controls.btn_prev_view = VerdantGraphWindowPrevViewBtn
  controls.view_label    = VerdantGraphWindowViewLabel
  controls.btn_next_view = VerdantGraphWindowNextViewBtn
  controls.viewport      = VerdantGraphWindowViewport
  controls.canvas        = VerdantGraphWindowViewportCanvas
  controls.no_data       = VerdantGraphWindowViewportNoDataLabel
  controls.skill_area    = VerdantGraphWindowViewportSkillArea
  controls.ehps_label    = VerdantGraphWindowViewportSkillAreaEhpsLabel
  controls.ehps_canvas   = VerdantGraphWindowViewportSkillAreaEhpsCanvas
  controls.mps_label     = VerdantGraphWindowViewportSkillAreaMpsLabel
  controls.mps_canvas    = VerdantGraphWindowViewportSkillAreaMpsCanvas

  local sv = Verdant.SavedVars
  sv.temporal = sv.temporal or {}
  if sv.temporal.graph_x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.temporal.graph_x, sv.temporal.graph_y)
  end
  if sv.temporal.graph_w then
    controls.window:SetDimensions(sv.temporal.graph_w, sv.temporal.graph_h)
  end

  controls.window:SetDimensionConstraints(360, 240, 1000, 700)

  VerdantGraphWindowBg:SetCenterColor(0, 0, 0, 0)
  VerdantGraphWindowChromeTop   :SetColor(0.62, 1.00, 0.74, 0.82)
  VerdantGraphWindowChromeBottom:SetColor(0.62, 1.00, 0.74, 0.82)
  VerdantGraphWindowChromeLeft  :SetColor(0.62, 1.00, 0.74, 0.82)
  VerdantGraphWindowChromeRight :SetColor(0.62, 1.00, 0.74, 0.82)
  VerdantGraphWindowBg:SetEdgeColor(0.42, 1.00, 0.60, 1.0)

  local sv_a = (Verdant.SavedVars and Verdant.SavedVars.temporal
                and Verdant.SavedVars.temporal.viewport_alpha_pct) or 30
  VerdantGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, sv_a / 100)


  controls.grid_ems = create_grid("VerdantGridEms", controls.canvas)
  controls.grid_top = create_grid("VerdantGridTop", controls.ehps_canvas)
  controls.grid_bot = create_grid("VerdantGridBot", controls.mps_canvas)


  controls.pool_ehps           = make_fill_pool("VerdantGraphFillEhps")
  controls.pool_mps            = make_fill_pool("VerdantGraphFillMps")
  controls.pool_line_ehps      = make_line_pool("VerdantGraphLineEhps")
  controls.pool_line_ems       = make_line_pool("VerdantGraphLineEms")
  controls.pool_skill_top      = make_skill_fill_pool("VerdantSkillFillTop", "ehps_canvas")
  controls.pool_skill_bot      = make_skill_fill_pool("VerdantSkillFillBot", "mps_canvas")
  controls.pool_line_skill_top = make_skill_line_pool("VerdantSkillLineTop", "ehps_canvas")
  controls.pool_line_skill_bot = make_skill_line_pool("VerdantSkillLineBot", "mps_canvas")

  controls.title:SetText(GetString(VERDANT_GRAPH_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)

  controls.btn_record:SetText(GetString(VERDANT_GRAPH_RECORD))
  controls.btn_stop:SetText(GetString(VERDANT_GRAPH_STOP))
  controls.btn_flush:SetText(GetString(VERDANT_GRAPH_FLUSH))

  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)

  controls.no_data:SetText(GetString(VERDANT_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)


  controls.view_label:SetText(VIEW_LABELS[current_view])
  controls.view_label:SetColor(0.75, 0.75, 0.75, 1)

  controls.ehps_label:SetText("eHPS")
  controls.ehps_label:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, 0.80)
  controls.mps_label:SetText("MPS")
  controls.mps_label:SetColor(C_LINE_EMS.r, C_LINE_EMS.g, C_LINE_EMS.b, 0.80)

  refresh_button_colors()
end
