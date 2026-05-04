Verdant = Verdant or {}
Verdant.Graph = {}
local M = Verdant.Graph

local ZO_ObjectPool              = ZO_ObjectPool
local WINDOW_MANAGER             = WINDOW_MANAGER
local EVENT_MANAGER              = EVENT_MANAGER
local CreateControlFromVirtual   = CreateControlFromVirtual
local GetGameTimeMilliseconds    = GetGameTimeMilliseconds
local GetString                  = GetString
local math_max                   = math.max
local math_floor                 = math.floor
local string_format              = string.format

-- Colors matching bar.lua
local C_EHPS      = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 }  -- pastel green fill
local C_MPS       = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 }  -- pastel pink fill
local C_LINE_EHPS = { r = 0.65, g = 1.00, b = 0.72, a = 1.00 }  -- brighter green line
local C_LINE_EMS  = { r = 1.00, g = 0.78, b = 0.90, a = 1.00 }  -- brighter pink line
local C_BG        = { r = 0.06, g = 0.06, b = 0.08, a = 1.00 }

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE     = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FILL_T, FILL_B = 0, 0.53125
local LINE_THICKNESS = 2
local LABEL_H        = 12

-- ── state ─────────────────────────────────────────────────────────────────
local controls           = {}
local recording_start_ms = 0

local VIEW_EMS    = 1
local VIEW_SKILL  = 2
local VIEW_LABELS = { "EMS", "SKILL" }
local current_view = VIEW_EMS

-- ── pool factories ────────────────────────────────────────────────────────
local function make_fill_pool(name_prefix)
  local counter = 0
  return ZO_ObjectPool:New(
    function(pool, key)
      counter = counter + 1
      local t = WINDOW_MANAGER:CreateControl(name_prefix .. counter, controls.canvas, CT_TEXTURE)
      t:SetTexture(FILL_TEXTURE)
      t:SetTextureCoords(0, 1, FILL_T, FILL_B)
      return t
    end,
    function(t) t:SetHidden(true) end
  )
end

-- Skill-view fill pool: canvas_key is the key in controls{} for the parent canvas.
-- The factory runs lazily so controls[canvas_key] is valid by first AcquireObject call.
local function make_skill_fill_pool(name_prefix, canvas_key)
  local counter = 0
  return ZO_ObjectPool:New(
    function(pool, key)
      counter = counter + 1
      local t = WINDOW_MANAGER:CreateControl(name_prefix .. counter, controls[canvas_key], CT_TEXTURE)
      t:SetTexture(FILL_TEXTURE)
      t:SetTextureCoords(0, 1, FILL_T, FILL_B)
      return t
    end,
    function(t) t:SetHidden(true) end
  )
end

local function make_line_pool(name_prefix)
  local counter = 0
  return ZO_ObjectPool:New(
    function(pool, key)
      counter = counter + 1
      local line = CreateControlFromVirtual(name_prefix .. counter, controls.canvas, "VerdantGraphLineTemplate")
      line:SetThickness(LINE_THICKNESS)
      return line
    end,
    function(line) line:SetHidden(true) end
  )
end

-- ── release all pools ─────────────────────────────────────────────────────
local function release_all_pools()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_line_ehps:ReleaseAllObjects()
  controls.pool_line_ems:ReleaseAllObjects()
  controls.pool_skill_top:ReleaseAllObjects()
  controls.pool_skill_bot:ReleaseAllObjects()
end

-- ── skill area layout ─────────────────────────────────────────────────────
-- Splits skill_area into two equal sub-canvases (top = eHPS, bot = MPS),
-- each preceded by a small label.  Called on every resize and before rendering.
local function layout_skill_area()
  local sa = controls.skill_area
  local sw = sa:GetWidth()
  local sh = sa:GetHeight()
  if sw <= 0 or sh <= 0 then return end

  local usable = sh - LABEL_H * 2 - 4   -- 4 px gap between the two sections
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

-- ── rendering: View 1 — EMS stacked fills + polylines ─────────────────────
local function render_view1()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_line_ehps:ReleaseAllObjects()
  controls.pool_line_ems:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw = canvas:GetWidth()
  local ch = canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end

  local max_ems = 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    local ems = s.eHPS + s.MPS
    if ems > max_ems then max_ems = ems end
  end)
  if max_ems <= 0 then return end

  local bar_w   = cw / n
  local xs      = {}
  local ehps_hs = {}
  local ems_hs  = {}

  Verdant.TemporalBuffer.iterate(function(i, s)
    local x  = (i - 1) * bar_w
    local bw = math_max(1, math_floor(bar_w))
    local xc = x + bar_w * 0.5

    local ehps_h = math_max(0, math_floor(ch * (s.eHPS / max_ems) + 0.5))
    local mps_h  = math_max(0, math_floor(ch * (s.MPS  / max_ems) + 0.5))

    xs[i]      = xc
    ehps_hs[i] = ehps_h
    ems_hs[i]  = ehps_h + mps_h

    if ehps_h > 0 then
      local te = controls.pool_ehps:AcquireObject()
      te:ClearAnchors()
      te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, 0)
      te:SetWidth(bw)
      te:SetHeight(ehps_h)
      te:SetColor(C_EHPS.r, C_EHPS.g, C_EHPS.b, C_EHPS.a)
      te:SetHidden(false)
    end

    if mps_h > 0 then
      local tm = controls.pool_mps:AcquireObject()
      tm:ClearAnchors()
      tm:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -ehps_h)
      tm:SetWidth(bw)
      tm:SetHeight(mps_h)
      tm:SetColor(C_MPS.r, C_MPS.g, C_MPS.b, C_MPS.a)
      tm:SetHidden(false)
    end
  end)

  for i = 2, n do
    local x1, x2 = xs[i-1], xs[i]

    local le = controls.pool_line_ehps:AcquireObject()
    le:ClearAnchors()
    le:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, x1, -ehps_hs[i-1])
    le:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, x2, -ehps_hs[i])
    le:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, C_LINE_EHPS.a)
    le:SetHidden(false)

    local lm = controls.pool_line_ems:AcquireObject()
    lm:ClearAnchors()
    lm:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, x1, -ems_hs[i-1])
    lm:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, x2, -ems_hs[i])
    lm:SetColor(C_LINE_EMS.r, C_LINE_EMS.g, C_LINE_EMS.b, C_LINE_EMS.a)
    lm:SetHidden(false)
  end
end

-- ── rendering: View 2 — skill breakdown sub-plots ─────────────────────────
local function render_view2()
  controls.pool_skill_top:ReleaseAllObjects()
  controls.pool_skill_bot:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    return
  end
  controls.no_data:SetHidden(true)

  local ec = controls.ehps_canvas
  local mc = controls.mps_canvas
  local cw = ec:GetWidth()
  if cw <= 0 then return end

  local max_ehps, max_mps = 0, 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    if s.eHPS > max_ehps then max_ehps = s.eHPS end
    if s.MPS  > max_mps  then max_mps  = s.MPS  end
  end)

  local bar_w = cw / n

  if max_ehps > 0 then
    local ch = ec:GetHeight()
    Verdant.TemporalBuffer.iterate(function(i, s)
      if #s.ehps_groups == 0 then return end
      local x     = (i - 1) * bar_w
      local bw    = math_max(1, math_floor(bar_w))
      local col_h = math_max(0, math_floor(ch * (s.eHPS / max_ehps) + 0.5))
      local y_off = 0
      for _, grp in ipairs(s.ehps_groups) do
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
  end

  if max_mps > 0 then
    local ch = mc:GetHeight()
    Verdant.TemporalBuffer.iterate(function(i, s)
      if #s.mps_groups == 0 then return end
      local x     = (i - 1) * bar_w
      local bw    = math_max(1, math_floor(bar_w))
      local col_h = math_max(0, math_floor(ch * (s.MPS / max_mps) + 0.5))
      local y_off = 0
      for _, grp in ipairs(s.mps_groups) do
        local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
        local t = controls.pool_skill_bot:AcquireObject()
        t:ClearAnchors()
        t:SetAnchor(BOTTOMLEFT, mc, BOTTOMLEFT, x, -y_off)
        t:SetWidth(bw)
        t:SetHeight(seg_h)
        t:SetColor(grp.r, grp.g, grp.b, grp.a)
        t:SetHidden(false)
        y_off = y_off + seg_h
      end
    end)
  end
end

local function render_current_view()
  if current_view == VIEW_EMS then
    render_view1()
  else
    layout_skill_area()
    render_view2()
  end
end

-- ── button state visuals ──────────────────────────────────────────────────
local function refresh_button_colors()
  local recording = Verdant.TemporalBuffer.is_recording()
  if recording then
    controls.btn_record:SetColor(0.55, 0.15, 0.15, 0.70)
    controls.btn_stop:SetColor(0.90, 0.90, 0.90, 1.00)
  else
    controls.btn_record:SetColor(1.00, 0.20, 0.20, 1.00)
    controls.btn_stop:SetColor(0.40, 0.40, 0.40, 0.70)
  end
end

-- ── view switching ────────────────────────────────────────────────────────
local function set_view(v)
  current_view = v
  controls.view_label:SetText(VIEW_LABELS[v])

  local is_ems = (v == VIEW_EMS)
  controls.canvas:SetHidden(not is_ems)
  controls.skill_area:SetHidden(is_ems)

  if Verdant.TemporalBuffer.count() == 0 then
    controls.no_data:SetHidden(false)
    return
  end
  controls.no_data:SetHidden(true)

  if is_ems then
    render_view1()
  else
    layout_skill_area()
    render_view2()
  end
end

-- ── sampling loop ─────────────────────────────────────────────────────────
local function on_sample_update()
  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)
  local eg  = Verdant.Metrics.eHPS_by_group(now)
  local mg  = Verdant.Metrics.MPS_by_group(now)
  Verdant.TemporalBuffer.push(now, r.eHPS, r.MPS, eg, mg)

  local elapsed = math_floor((now - recording_start_ms) / 1000)
  controls.status:SetText(string_format("%d:%02d", math_floor(elapsed / 60), elapsed % 60))

  if not controls.window:IsHidden() then
    render_current_view()
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.on_record_click()
  if Verdant.TemporalBuffer.is_recording() then return end
  Verdant.TemporalBuffer.clear()
  release_all_pools()
  controls.no_data:SetHidden(false)
  Verdant.TemporalBuffer.start_recording()
  recording_start_ms = GetGameTimeMilliseconds()
  local sv       = Verdant.SavedVars
  local interval = (sv and sv.temporal and sv.temporal.sample_rate_ms)
                   or Verdant.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  EVENT_MANAGER:RegisterForUpdate(Verdant.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  refresh_button_colors()
  controls.status:SetText("0:00")
end

function M.on_stop_click()
  if not Verdant.TemporalBuffer.is_recording() then return end
  Verdant.TemporalBuffer.stop_recording()
  EVENT_MANAGER:UnregisterForUpdate(Verdant.Constants.TEMPORAL.UPDATE_NAME)
  refresh_button_colors()
  render_current_view()
end

function M.on_flush_click()
  if Verdant.TemporalBuffer.is_recording() then
    EVENT_MANAGER:UnregisterForUpdate(Verdant.Constants.TEMPORAL.UPDATE_NAME)
    Verdant.TemporalBuffer.stop_recording()
  end
  Verdant.TemporalBuffer.clear()
  release_all_pools()
  refresh_button_colors()
  controls.status:SetText("")
  controls.no_data:SetHidden(false)
end

function M.on_close_click()
  controls.window:SetHidden(true)
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
  if v < VIEW_EMS then v = VIEW_SKILL end
  release_all_pools()
  set_view(v)
end

function M.next_view()
  local v = current_view + 1
  if v > VIEW_SKILL then v = VIEW_EMS end
  release_all_pools()
  set_view(v)
end

function M.toggle()
  local win = controls.window
  if win:IsHidden() then
    win:SetHidden(false)
    local is_ems = (current_view == VIEW_EMS)
    controls.canvas:SetHidden(not is_ems)
    controls.skill_area:SetHidden(is_ems)
    render_current_view()
  else
    win:SetHidden(true)
    release_all_pools()
  end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  local WM = WINDOW_MANAGER

  controls.window        = VerdantGraphWindow
  controls.title         = VerdantGraphWindowTitleLabel
  controls.btn_record    = VerdantGraphWindowRecordBtn
  controls.btn_stop      = VerdantGraphWindowStopBtn
  controls.btn_flush     = VerdantGraphWindowFlushBtn
  controls.status        = VerdantGraphWindowStatusLabel
  controls.canvas        = VerdantGraphWindowCanvas
  controls.no_data       = VerdantGraphWindowNoDataLabel
  controls.btn_prev_view = VerdantGraphWindowPrevViewBtn
  controls.view_label    = VerdantGraphWindowViewLabel
  controls.btn_next_view = VerdantGraphWindowNextViewBtn
  controls.skill_area    = VerdantGraphWindowSkillArea
  controls.ehps_label    = VerdantGraphWindowSkillAreaEhpsLabel
  controls.ehps_canvas   = VerdantGraphWindowSkillAreaEhpsCanvas
  controls.mps_label     = VerdantGraphWindowSkillAreaMpsLabel
  controls.mps_canvas    = VerdantGraphWindowSkillAreaMpsCanvas

  -- Restore saved position and size
  local sv = Verdant.SavedVars
  sv.temporal = sv.temporal or {}
  if sv.temporal.graph_x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.temporal.graph_x, sv.temporal.graph_y)
  end
  if sv.temporal.graph_w then
    controls.window:SetDimensions(sv.temporal.graph_w, sv.temporal.graph_h)
  end

  -- Canvas background (EMS view)
  local bg = WM:CreateControl("VerdantGraphCanvasBg", controls.canvas, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     controls.canvas, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, controls.canvas, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)

  -- Sub-canvas backgrounds (SKILL view)
  local bg_top = WM:CreateControl("VerdantSkillBgTop", controls.ehps_canvas, CT_TEXTURE)
  bg_top:ClearAnchors()
  bg_top:SetAnchor(TOPLEFT,     controls.ehps_canvas, TOPLEFT,     0, 0)
  bg_top:SetAnchor(BOTTOMRIGHT, controls.ehps_canvas, BOTTOMRIGHT, 0, 0)
  bg_top:SetTexture(BG_TEXTURE)
  bg_top:SetColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)

  local bg_bot = WM:CreateControl("VerdantSkillBgBot", controls.mps_canvas, CT_TEXTURE)
  bg_bot:ClearAnchors()
  bg_bot:SetAnchor(TOPLEFT,     controls.mps_canvas, TOPLEFT,     0, 0)
  bg_bot:SetAnchor(BOTTOMRIGHT, controls.mps_canvas, BOTTOMRIGHT, 0, 0)
  bg_bot:SetTexture(BG_TEXTURE)
  bg_bot:SetColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)

  -- Object pools
  controls.pool_ehps      = make_fill_pool("VerdantGraphFillEhps")
  controls.pool_mps       = make_fill_pool("VerdantGraphFillMps")
  controls.pool_line_ehps = make_line_pool("VerdantGraphLineEhps")
  controls.pool_line_ems  = make_line_pool("VerdantGraphLineEms")
  controls.pool_skill_top = make_skill_fill_pool("VerdantSkillTop", "ehps_canvas")
  controls.pool_skill_bot = make_skill_fill_pool("VerdantSkillBot", "mps_canvas")

  -- Labels / buttons
  controls.title:SetText(GetString(VERDANT_GRAPH_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)

  controls.btn_record:SetText(GetString(VERDANT_GRAPH_RECORD))
  controls.btn_stop:SetText(GetString(VERDANT_GRAPH_STOP))
  controls.btn_flush:SetText(GetString(VERDANT_GRAPH_FLUSH))
  controls.btn_flush:SetColor(0.80, 0.60, 0.20, 1.00)

  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)

  controls.no_data:SetText(GetString(VERDANT_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)

  controls.btn_prev_view:SetText("<")
  controls.btn_prev_view:SetColor(0.65, 0.65, 0.65, 1)
  controls.view_label:SetText(VIEW_LABELS[current_view])
  controls.view_label:SetColor(0.75, 0.75, 0.75, 1)
  controls.btn_next_view:SetText(">")
  controls.btn_next_view:SetColor(0.65, 0.65, 0.65, 1)

  controls.ehps_label:SetText("eHPS")
  controls.ehps_label:SetColor(C_LINE_EHPS.r, C_LINE_EHPS.g, C_LINE_EHPS.b, 0.80)
  controls.mps_label:SetText("MPS")
  controls.mps_label:SetColor(C_LINE_EMS.r, C_LINE_EMS.g, C_LINE_EMS.b, 0.80)

  refresh_button_colors()

  -- Graph toggle button on the main bar
  VerdantBarWindowGraphBtn:SetText("G")
  VerdantBarWindowGraphBtn:SetColor(0.55, 0.75, 0.95, 1)
end
