Verdant = Verdant or {}
Verdant.Graph = {}
local M = Verdant.Graph

local ZO_ObjectPool           = ZO_ObjectPool
local WINDOW_MANAGER          = WINDOW_MANAGER
local EVENT_MANAGER           = EVENT_MANAGER
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetString               = GetString
local math_max                = math.max
local math_min                = math.min
local math_floor              = math.floor
local string_format           = string.format

-- Colors matching bar.lua
local C_EHPS = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 }  -- pastel green
local C_MPS  = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 }  -- pastel pink
local C_BG   = { r = 0.06, g = 0.06, b = 0.08, a = 1.00 }

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local BG_TEXTURE     = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_bg.dds"
local FILL_T, FILL_B = 0, 0.53125

-- ── state ─────────────────────────────────────────────────────────────────
local controls           = {}
local recording_start_ms = 0

-- ── pool factory ──────────────────────────────────────────────────────────
local function make_graph_pool(name_prefix)
  local counter = 0
  return ZO_ObjectPool:New(
    function(pool, key)
      counter = counter + 1
      local t = WINDOW_MANAGER:CreateControl(name_prefix .. counter, controls.canvas, CT_TEXTURE)
      t:SetTexture(FILL_TEXTURE)
      t:SetTextureCoords(0, 1, FILL_T, FILL_B)
      return t
    end,
    function(t)
      t:SetHidden(true)
    end
  )
end

-- ── rendering ─────────────────────────────────────────────────────────────
local function render_graph()
  local pool_ehps = controls.pool_ehps
  local pool_mps  = controls.pool_mps
  pool_ehps:ReleaseAllObjects()
  pool_mps:ReleaseAllObjects()

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

  -- Y-axis scale: max EMS value in the visible buffer
  local max_ems = 0
  Verdant.TemporalBuffer.iterate(function(i, s)
    local ems = s.eHPS + s.MPS
    if ems > max_ems then max_ems = ems end
  end)
  if max_ems <= 0 then return end

  local bar_w = cw / n

  Verdant.TemporalBuffer.iterate(function(i, s)
    local x  = (i - 1) * bar_w
    local bw = math_max(1, math_floor(bar_w))

    -- Green bar: eHPS, BOTTOM-anchored to canvas floor
    local ehps_h = math_max(1, math_floor(ch * (s.eHPS / max_ems) + 0.5))
    local te = pool_ehps:AcquireObject()
    te:ClearAnchors()
    te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, 0)
    te:SetWidth(bw)
    te:SetHeight(ehps_h)
    te:SetColor(C_EHPS.r, C_EHPS.g, C_EHPS.b, C_EHPS.a)
    te:SetHidden(false)

    -- Pink bar: MPS, stacked on top of the green bar
    if s.MPS > 0 then
      local mps_h = math_max(1, math_floor(ch * (s.MPS / max_ems) + 0.5))
      local tm = pool_mps:AcquireObject()
      tm:ClearAnchors()
      tm:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -ehps_h)
      tm:SetWidth(bw)
      tm:SetHeight(mps_h)
      tm:SetColor(C_MPS.r, C_MPS.g, C_MPS.b, C_MPS.a)
      tm:SetHidden(false)
    end
  end)
end

-- ── button state visuals ──────────────────────────────────────────────────
local function refresh_button_colors()
  local recording = Verdant.TemporalBuffer.is_recording()
  -- REC: bright red when available, dim when already recording
  if recording then
    controls.btn_record:SetColor(0.55, 0.15, 0.15, 0.70)
  else
    controls.btn_record:SetColor(1.00, 0.20, 0.20, 1.00)
  end
  -- STOP: bright when recording is active
  if recording then
    controls.btn_stop:SetColor(0.90, 0.90, 0.90, 1.00)
  else
    controls.btn_stop:SetColor(0.40, 0.40, 0.40, 0.70)
  end
end

-- ── sampling loop ─────────────────────────────────────────────────────────
local function on_sample_update()
  local now = GetGameTimeMilliseconds()
  local r   = Verdant.Metrics.contribution(now)
  Verdant.TemporalBuffer.push(now, r.eHPS, r.MPS)

  -- Update elapsed timer on the status label
  local elapsed = math_floor((now - recording_start_ms) / 1000)
  controls.status:SetText(string_format("%d:%02d", math_floor(elapsed / 60), elapsed % 60))

  -- Live redraw only if the window is open
  if not controls.window:IsHidden() then
    render_graph()
  end
end

-- ── public API ────────────────────────────────────────────────────────────
function M.on_record_click()
  if Verdant.TemporalBuffer.is_recording() then return end
  Verdant.TemporalBuffer.clear()
  Verdant.TemporalBuffer.start_recording()
  recording_start_ms = GetGameTimeMilliseconds()
  local sv       = Verdant.SavedVars
  local interval = (sv and sv.temporal and sv.temporal.sample_rate_ms) or Verdant.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  EVENT_MANAGER:RegisterForUpdate(Verdant.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  refresh_button_colors()
  controls.status:SetText("0:00")
end

function M.on_stop_click()
  if not Verdant.TemporalBuffer.is_recording() then return end
  Verdant.TemporalBuffer.stop_recording()
  EVENT_MANAGER:UnregisterForUpdate(Verdant.Constants.TEMPORAL.UPDATE_NAME)
  refresh_button_colors()
  render_graph()
end

function M.on_close_click()
  controls.window:SetHidden(true)
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
end

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.temporal = sv.temporal or {}
  local x, y = controls.window:GetCenter()
  sv.temporal.graph_x = x
  sv.temporal.graph_y = y
end

function M.toggle()
  local win = controls.window
  if win:IsHidden() then
    win:SetHidden(false)
    render_graph()
  else
    win:SetHidden(true)
    controls.pool_ehps:ReleaseAllObjects()
    controls.pool_mps:ReleaseAllObjects()
  end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  local WM = WINDOW_MANAGER

  controls.window     = VerdantGraphWindow
  controls.title      = VerdantGraphWindowTitleLabel
  controls.btn_record = VerdantGraphWindowRecordBtn
  controls.btn_stop   = VerdantGraphWindowStopBtn
  controls.status     = VerdantGraphWindowStatusLabel
  controls.canvas     = VerdantGraphWindowCanvas
  controls.no_data    = VerdantGraphWindowNoDataLabel

  -- Restore saved position, fall back to screen centre
  local sv = Verdant.SavedVars
  sv.temporal = sv.temporal or {}
  if sv.temporal.graph_x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.temporal.graph_x, sv.temporal.graph_y)
  end

  -- Canvas background
  local bg = WM:CreateControl("VerdantGraphCanvasBg", controls.canvas, CT_TEXTURE)
  bg:ClearAnchors()
  bg:SetAnchor(TOPLEFT,     controls.canvas, TOPLEFT,     0, 0)
  bg:SetAnchor(BOTTOMRIGHT, controls.canvas, BOTTOMRIGHT, 0, 0)
  bg:SetTexture(BG_TEXTURE)
  bg:SetColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)

  -- ZO_ObjectPools — created once, reused every render
  controls.pool_ehps = make_graph_pool("VerdantGraphEhps")
  controls.pool_mps  = make_graph_pool("VerdantGraphMps")

  -- Labels
  controls.title:SetText(GetString(VERDANT_GRAPH_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)

  controls.btn_record:SetText(GetString(VERDANT_GRAPH_RECORD))
  controls.btn_stop:SetText(GetString(VERDANT_GRAPH_STOP))
  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)

  controls.no_data:SetText(GetString(VERDANT_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)

  refresh_button_colors()

  -- Wire up the graph button on the bar
  VerdantBarWindowGraphBtn:SetText("G")
  VerdantBarWindowGraphBtn:SetColor(0.55, 0.75, 0.95, 1)
end
