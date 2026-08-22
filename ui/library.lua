Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Library = {}
local M = Verdant.Library

local string_format = string.format
local math_floor    = math.floor
local d             = d

local ROW_H   = 30
local ROW_GAP = 2
local MAX_ROWS = 11

local C_PIP_SAVE  = { r = 0.55, g = 0.92, b = 0.62 }
local C_PIP_OTHER = { r = 0.55, g = 0.66, b = 0.82 }
local C_PIP_LOST  = { r = 0.95, g = 0.42, b = 0.34 }
local C_PIP_NONE  = { r = 0.45, g = 0.48, b = 0.45 }
local C_NAME      = { r = 0.86, g = 0.92, b = 0.88 }
local C_DIM       = { r = 0.55, g = 0.58, b = 0.55 }
local C_SEL       = { r = 0.55, g = 0.92, b = 0.62 }
local C_STAR      = { r = 0.91, g = 0.72, b = 0.29 }

local controls = {}
local rows = {}
local row_session = {}
local selected = nil
local delete_armed = false
local log

local function pip_color(sum)
  if (sum.l or 0) + (sum.m or 0) > 0 then return C_PIP_LOST end
  if (sum.saves or 0) > 0 and sum.saves >= (sum.o or 0) then return C_PIP_SAVE end
  if (sum.o or 0) > 0 then return C_PIP_OTHER end
  return C_PIP_NONE
end

local function fmt_dur(ms)
  local s = math_floor((ms or 0) / 1000)
  return string_format("%d:%02d", math_floor(s / 60), s % 60)
end

local function fmt_ago(ts)
  local now = Verdant.zenimax.api.GetTimeStamp()
  local days = math_floor((now - (ts or now)) / 86400)
  if days <= 0 then return GetString(VERDANT_LIB_TODAY) end
  return days .. "d"
end

local function fmt_k(v)
  if v >= 10000 then return string_format("%.0fk", v / 1000) end
  if v >= 1000 then return string_format("%.1fk", v / 1000) end
  return tostring(v)
end

local WM = WINDOW_MANAGER

local function make_row(i)
  local nm = "VerdantLibraryRow" .. i
  local row = WM:CreateControl(nm, controls.list, CT_CONTROL)
  row:SetAnchor(TOPLEFT,  controls.list, TOPLEFT,  0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetAnchor(TOPRIGHT, controls.list, TOPRIGHT, 0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetHeight(ROW_H)
  row:SetMouseEnabled(true)
  row:SetHandler("OnMouseUp", function() M.on_row_click(i) end)

  local bg = WM:CreateControl(nm .. "Bg", row, CT_TEXTURE)
  bg:SetAnchorFill(row)
  bg:SetColor(1, 1, 1, 0.02)

  local sel = WM:CreateControl(nm .. "Sel", row, CT_TEXTURE)
  sel:SetAnchorFill(row)
  sel:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.10)
  sel:SetHidden(true)

  local pip = WM:CreateControl(nm .. "Pip", row, CT_TEXTURE)
  pip:SetDimensions(3, ROW_H - 12)
  pip:SetAnchor(LEFT, row, LEFT, 4, 0)

  local name = WM:CreateControl(nm .. "Name", row, CT_LABEL)
  name:SetFont("ZoFontGameSmall")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetDimensions(126, ROW_H)
  name:SetAnchor(LEFT, row, LEFT, 14, 0)

  local stats = WM:CreateControl(nm .. "Stats", row, CT_LABEL)
  stats:SetFont("ZoFontGameSmall")
  stats:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  stats:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  stats:SetDimensions(176, ROW_H)
  stats:SetAnchor(LEFT, row, LEFT, 144, 0)

  local when = WM:CreateControl(nm .. "When", row, CT_LABEL)
  when:SetFont("ZoFontGameSmall")
  when:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  when:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  when:SetDimensions(78, ROW_H)
  when:SetAnchor(RIGHT, row, RIGHT, -20, 0)

  local star = WM:CreateControl(nm .. "Star", row, CT_LABEL)
  star:SetFont("ZoFontGameSmall")
  star:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  star:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  star:SetDimensions(14, ROW_H)
  star:SetAnchor(RIGHT, row, RIGHT, -4, 0)
  star:SetColor(C_STAR.r, C_STAR.g, C_STAR.b, 1)

  return { root = row, bg = bg, sel = sel, pip = pip,
           name = name, stats = stats, when = when, star = star }
end

local function set_buttons()
  local has = selected ~= nil
  controls.open_btn:SetEnabled(has)
  controls.lock_btn:SetEnabled(has)
  controls.delete_btn:SetEnabled(has)
  controls.delete_btn:SetText(delete_armed and GetString(VERDANT_LIB_CONFIRM)
                                            or GetString(VERDANT_LIB_DELETE))
  if has then
    local s = Verdant.SessionStore.get(row_session[selected])
    controls.lock_btn:SetText((s and s.head.locked)
      and GetString(VERDANT_LIB_UNLOCK) or GetString(VERDANT_LIB_LOCK))
  else
    controls.lock_btn:SetText(GetString(VERDANT_LIB_LOCK))
  end
end

function M.refresh()
  local SS = Verdant.SessionStore
  local n = SS.count()
  controls.count:SetText(string_format(GetString(VERDANT_LIB_COUNT), n, 24))
  controls.empty:SetHidden(n > 0)
  controls.empty:SetText(GetString(VERDANT_LIB_EMPTY))
  controls.empty:SetColor(0.5, 0.5, 0.5, 1)

  local shown = 0
  for i = n, 1, -1 do
    if shown >= MAX_ROWS then break end
    shown = shown + 1
    local row = rows[shown]
    if not row then row = make_row(shown); rows[shown] = row end
    row_session[shown] = i
    local sess = SS.get(i)
    local h = sess.head
    local pc = pip_color(h.sum or {})
    row.root:SetHidden(false)
    row.bg:SetColor(1, 1, 1, (shown % 2 == 0) and 0.04 or 0.02)
    row.sel:SetHidden(shown ~= selected)
    row.pip:SetColor(pc.r, pc.g, pc.b, 1)
    row.name:SetText(h.zone or "?")
    row.name:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, 1)
    local sum = h.sum or {}
    local denom = (sum.saves or 0) + (sum.o or 0) + (sum.l or 0) + (sum.m or 0)
    row.stats:SetText(string_format(
      "|c94d9eb%s|r  |cf2a0c0%s|r  |c%s%d/%d|r",
      fmt_k(sum.avg or 0), fmt_k(sum.peak or 0),
      (pc == C_PIP_LOST) and "f26b56" or "8cea9e",
      sum.saves or 0, denom))
    row.stats:SetColor(1, 1, 1, 1)
    row.when:SetText(fmt_dur(h.dur_ms) .. "  " .. fmt_ago(h.ts))
    row.when:SetColor(C_DIM.r, C_DIM.g, C_DIM.b, 1)
    row.star:SetText(h.locked and "*" or "")
  end
  for i = shown + 1, #rows do
    rows[i].root:SetHidden(true)
    row_session[i] = nil
  end
  if selected and (selected > shown) then selected = nil end
  set_buttons()
end

function M.on_row_click(i)
  if not row_session[i] then return end
  selected = i
  delete_armed = false
  for k = 1, #rows do
    rows[k].sel:SetHidden(k ~= i)
  end
  set_buttons()
end

function M.on_open_click()
  if not selected then return end
  local sess = Verdant.SessionStore.get(row_session[selected])
  if sess and Verdant.Graph.load_session(sess) then
    M.hide()
  end
end

function M.on_lock_click()
  if not selected then return end
  local idx = row_session[selected]
  local s = Verdant.SessionStore.get(idx)
  if s then
    Verdant.SessionStore.set_locked(idx, not s.head.locked)
    M.refresh()
  end
end

function M.on_delete_click()
  if not selected then return end
  if not delete_armed then
    delete_armed = true
    set_buttons()
    return
  end
  delete_armed = false
  Verdant.SessionStore.delete(row_session[selected])
  selected = nil
  M.refresh()
end

function M.show()
  selected = nil
  delete_armed = false
  M.refresh()
  controls.window:SetHidden(false)
end

function M.hide()
  controls.window:SetHidden(true)
end

function M.toggle()
  if controls.window:IsHidden() then M.show() else M.hide() end
end

function M.init()
  log = Verdant.Log.for_module("library")
  controls.window     = VerdantLibrary
  controls.title      = VerdantLibraryWindowTitle
  controls.count      = VerdantLibraryCountLabel
  controls.list       = VerdantLibraryList
  controls.empty      = VerdantLibraryListEmpty
  controls.open_btn   = VerdantLibraryOpenBtn
  controls.lock_btn   = VerdantLibraryLockBtn
  controls.delete_btn = VerdantLibraryDeleteBtn

  controls.title:SetText(GetString(VERDANT_LIB_TITLE))
  controls.open_btn:SetText(GetString(VERDANT_LIB_OPEN))
  controls.lock_btn:SetText(GetString(VERDANT_LIB_LOCK))
  controls.delete_btn:SetText(GetString(VERDANT_LIB_DELETE))
  VerdantLibraryBg:SetCenterColor(0.62, 1.00, 0.74, 1.0)
  VerdantLibraryBg:SetEdgeColor(0.42, 1.00, 0.60, 1.0)
  set_buttons()
end
