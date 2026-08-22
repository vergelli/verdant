unpack = unpack or table.unpack

HARNESS = { chat = {}, state = { grouped = false, group_size = 1, mouse_x = 400, mouse_y = 300, world = "NA Megaserver", in_combat = false, bosses = {} } }
local H = HARNESS

local T = 0

function d(msg) H.chat[#H.chat + 1] = tostring(msg) end

EVENT_ADD_ON_LOADED            = 1
EVENT_COMBAT_EVENT             = 2
EVENT_EFFECT_CHANGED           = 3
EVENT_GROUP_MEMBER_JOINED      = 4
EVENT_GROUP_MEMBER_LEFT        = 5
EVENT_GROUP_UPDATE             = 6
EVENT_PLAYER_ACTIVATED         = 7
EVENT_PLAYER_DEACTIVATED       = 8
EVENT_PLAYER_COMBAT_STATE      = 9
EVENT_ACTION_SLOT_ABILITY_USED = 10
EVENT_BOSSES_CHANGED           = 11
EVENT_UNIT_DEATH_STATE_CHANGED = 12
EVENT_ACTIVE_WEAPON_PAIR_CHANGED = 13
NUMBER_ABBREVIATION_PRECISION_TENTHS = 1

REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = 101
REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE = 102
REGISTER_FILTER_COMBAT_RESULT           = 103
REGISTER_FILTER_IS_ERROR                = 104
REGISTER_FILTER_UNIT_TAG                = 105

COMBAT_UNIT_TYPE_PLAYER     = 1
COMBAT_UNIT_TYPE_PLAYER_PET = 2
COMBAT_UNIT_TYPE_GROUP      = 3
COMBAT_UNIT_TYPE_OTHER      = 5

ACTION_RESULT_HEAL              = 16
ACTION_RESULT_HOT_TICK          = 17
ACTION_RESULT_CRITICAL_HEAL     = 18
ACTION_RESULT_HOT_TICK_CRITICAL = 19
ACTION_RESULT_HEAL_ABSORBED     = 20
ACTION_RESULT_DAMAGE            = 21
ACTION_RESULT_DOT_TICK          = 22
ACTION_RESULT_CRITICAL_DAMAGE   = 23
ACTION_RESULT_DOT_TICK_CRITICAL = 24
ACTION_RESULT_BLOCKED_DAMAGE    = 25
ACTION_RESULT_FALL_DAMAGE       = 26
ACTION_RESULT_DAMAGE_SHIELDED   = 27

EFFECT_RESULT_GAINED       = 31
EFFECT_RESULT_FADED        = 32
EFFECT_RESULT_UPDATED      = 33
EFFECT_RESULT_FULL_REFRESH = 34
EFFECT_RESULT_TRANSFER     = 35

BOSS_RANK_ITERATION_BEGIN = 1
BOSS_RANK_ITERATION_END   = 7

HOTBAR_CATEGORY_PRIMARY = 0
HOTBAR_CATEGORY_BACKUP  = 1

BUFF_EFFECT_TYPE_BUFF   = 1
BUFF_EFFECT_TYPE_DEBUFF = 2
ABILITY_TYPE_HEAL       = 28

TOPLEFT = 41 TOP = 42 TOPRIGHT = 43 LEFT = 44 CENTER = 45 RIGHT = 46
BOTTOMLEFT = 47 BOTTOM = 48 BOTTOMRIGHT = 49
CT_CONTROL = 51 CT_LABEL = 52 CT_TEXTURE = 53 CT_BACKDROP = 54
TEXT_ALIGN_LEFT = 61 TEXT_ALIGN_CENTER = 62 TEXT_ALIGN_RIGHT = 63
TEXT_ALIGN_TOP = 64 TEXT_ALIGN_BOTTOM = 65
SCENE_SHOWN = "shown" SCENE_HIDDEN = "hidden"
SOUNDS = setmetatable({}, { __index = function() return "sound" end })
ZO_COMBOBOX_SUPPRESS_UPDATE = true
SLASH_COMMANDS = {}

H.controls = {}

local mock_control
local MOCKC = {
  __index = function(self, k)
    if type(k) ~= "string" or k:find("^[A-Z]") ~= 1 then return nil end
    local fn
    if k == "SetAnchor" then
      fn = function(s, point, relTo, relPoint, ox, oy)
        s._anchors = (s._anchors or 0) + 1
        if s._anchors > 2 then error("too many anchors on a control (ESO max is 2)") end
        s._anchor_list = s._anchor_list or {}
        s._anchor_list[#s._anchor_list + 1] = {
          point = point, relTo = relTo, relPoint = relPoint or point,
          ox = ox or 0, oy = oy or 0,
        }
      end
    elseif k == "SetAnchorFill" then
      fn = function(s, target)
        s._anchors = 2
        s._fill = target or s._parent or true
      end
    elseif k == "ClearAnchors" then
      fn = function(s)
        s._anchors = 0
        s._anchor_list = nil
        s._fill = nil
      end
    elseif k == "SetDimensions" then fn = function(s, w, h) s._w, s._h = w, h end
    elseif k == "SetWidth" then fn = function(s, w) s._w = w end
    elseif k == "SetHeight" then fn = function(s, h) s._h = h end
    elseif k == "GetWidth" then fn = function(s) return s._w or 600 end
    elseif k == "GetHeight" then fn = function(s) return s._h or 400 end
    elseif k == "GetDimensions" then fn = function(s) return s._w or 600, s._h or 400 end
    elseif k == "GetTop" then fn = function(s) return s._top or 100 end
    elseif k == "GetBottom" then fn = function(s) return (s._top or 100) + (s._h or 400) end
    elseif k == "GetLeft" then fn = function(s) return s._left or 100 end
    elseif k == "GetRight" then fn = function(s) return (s._left or 100) + (s._w or 600) end
    elseif k == "GetCenter" then fn = function(s) return 400, 300 end
    elseif k == "SetText" then fn = function(s, t) s._text = t end
    elseif k == "GetText" then fn = function(s) return s._text or "" end
    elseif k == "GetTextWidth" then fn = function(s) return #tostring(s._text or "") * 7 end
    elseif k == "GetTextHeight" then fn = function() return 14 end
    elseif k == "SetHidden" then fn = function(s, h) s._hidden = h and true or false end
    elseif k == "IsHidden" then fn = function(s) return s._hidden == true end
    elseif k == "SetColor" then fn = function(s, r, g, b, a) s._r, s._g, s._b, s._a = r, g, b, a end
    elseif k == "SetAlpha" then fn = function(s, a) s._alpha = a end
    elseif k == "SetTexture" then fn = function(s, path) s._tex = path end
    elseif k == "GetTextureFileName" then fn = function(s) return s._tex or "" end
    elseif k == "SetDrawLevel" then fn = function(s, lv) s._draw_level = lv end
    elseif k == "SetDrawLayer" then fn = function(s, ly) s._draw_layer = ly end
    elseif k == "SetDrawTier" then fn = function(s, tr) s._draw_tier = tr end
    elseif k == "SetFont" then fn = function(s, f) s._font = f end
    elseif k == "SetCenterColor" then fn = function(s, r, g, b, a) s._cr, s._cg, s._cb, s._ca = r, g, b, a end
    elseif k == "SetEdgeColor" then fn = function(s, r, g, b, a) s._er, s._eg, s._eb, s._ea = r, g, b, a end
    elseif k == "SetHorizontalAlignment" then fn = function(s, a) s._halign = a end
    elseif k == "SetVerticalAlignment" then fn = function(s, a) s._valign = a end
    elseif k == "GetAlpha" then fn = function(s) return s._alpha or 1 end
    elseif k == "SetHandler" then fn = function(s, ev, h) s["_on" .. tostring(ev)] = h end
    elseif k == "GetHandler" then fn = function(s, ev) return s["_on" .. tostring(ev)] end
    elseif k == "GetNamedChild" then
      fn = function(s, suffix)
        s._children = s._children or {}
        if not s._children[suffix] then
          local child = mock_control((s._name or "MockControl") .. suffix)
          child._parent = s
          s._children[suffix] = child
        end
        return s._children[suffix]
      end
    elseif k == "GetName" then fn = function(s) return s._name or "MockControl" end
    elseif k == "SetEnabled" then fn = function(s, e) s._enabled = e and true or false end
    elseif k == "IsTextureLoaded" then fn = function() return true end
    elseif k == "GetScreenRect" then fn = function() return 0, 0, 1920, 1080 end
    elseif k:find("^Is") == 1 or k:find("^Does") == 1 then fn = function() return false end
    elseif k:find("^Get") == 1 then fn = function() return 0 end
    else fn = function() end end
    rawset(self, k, fn)
    return fn
  end,
}
mock_control = function(name)
  local c = setmetatable({}, MOCKC)
  c._name = name
  H.controls[#H.controls + 1] = c
  return c
end
H.mock_control = mock_control

GuiRoot = mock_control("GuiRoot")
GuiRoot.GetDimensions = function() return 1920, 1080 end

setmetatable(_G, {
  __index = function(_, k)
    if type(k) == "string" and k:find("^Verdant%u") then
      local c = mock_control(k)
      rawset(_G, k, c)
      return c
    end
    return nil
  end,
})

WINDOW_MANAGER = {
  CreateControl = function(_, name, parent, ctype)
    local c = mock_control(name)
    c._parent = parent
    c._ctype = ctype
    if name then rawset(_G, name, c) end
    return c
  end,
  CreateControlFromVirtual = function(_, name, parent, tpl)
    local c = mock_control(name)
    c._parent = parent
    c._tpl = tpl
    if name then rawset(_G, name, c) end
    return c
  end,
  CreateTopLevelWindow = function(_, name)
    local c = mock_control(name)
    c._parent = GuiRoot
    c._toplevel = true
    if name then rawset(_G, name, c) end
    return c
  end,
  GetControlByName = function(_, name) return rawget(_G, name) end,
}
function CreateControlFromVirtual(name, parent, tpl)
  return WINDOW_MANAGER:CreateControlFromVirtual(name, parent, tpl)
end

ZO_ObjectPool = {
  New = function(_, factory, reset)
    local p = { free = {}, active = {}, factory = factory, reset = reset }
    function p:AcquireObject()
      local obj = table.remove(self.free)
      if not obj then obj = self.factory(self) end
      self.active[#self.active + 1] = obj
      return obj, #self.active
    end
    function p:ReleaseAllObjects()
      for i = #self.active, 1, -1 do
        if self.reset then self.reset(self.active[i]) end
        self.free[#self.free + 1] = self.active[i]
        self.active[i] = nil
      end
    end
    function p:GetActiveObjectCount() return #self.active end
    return p
  end,
}

TEX_BLEND_MODE_ADD = 71
ANIMATION_ALPHA = 72
ANIMATION_PLAYBACK_PING_PONG = 73
LOOP_INDEFINITELY = -1

ANIMATION_MANAGER = {
  CreateTimeline = function()
    local anim = {
      SetAlphaValues = function() end,
      SetDuration = function() end,
      SetEasingFunction = function() end,
    }
    return {
      InsertAnimation = function() return anim end,
      SetPlaybackType = function() end,
      PlayFromStart = function() end,
      PlayFromEnd = function() end,
      Stop = function() end,
      IsPlaying = function() return false end,
    }
  end,
}

ZO_AlphaAnimation = {
  New = function(_, control)
    return {
      FadeIn = function()
        control:SetHidden(false)
        control:SetAlpha(1)
      end,
      FadeOut = function(_, _, _, _, cb)
        control:SetAlpha(0)
        if cb then cb() end
      end,
    }
  end,
}

function ZO_ComboBox_ObjectFromContainer()
  local combo = { items = {} }
  function combo:SetSortsItems() end
  function combo:ClearItems() self.items = {} end
  function combo:CreateItemEntry(label, cb) return { label = label, cb = cb } end
  function combo:AddItem(entry) self.items[#self.items + 1] = entry end
  function combo:UpdateItems() end
  function combo:SetSelectedItemText(t) self.selected = t end
  function combo:SelectByLabel(label)
    for _, e in ipairs(self.items) do
      if e.label == label then e.cb() return true end
    end
    return false
  end
  return combo
end

ZO_SavedVars = {
  NewAccountWide = function(_, tbl, version, profile, defaults)
    local function copy(src)
      local dst = {}
      for k, v in pairs(src) do
        dst[k] = (type(v) == "table") and copy(v) or v
      end
      return dst
    end
    H.saved_vars = copy(defaults or {})
    return H.saved_vars
  end,
}

SCENE_MANAGER = {
  callbacks = {},
  RegisterCallback = function(self, name, cb)
    self.callbacks[name] = self.callbacks[name] or {}
    local list = self.callbacks[name]
    list[#list + 1] = cb
  end,
  UnregisterCallback = function() end,
}

function ZO_CreateStringId(id, str) rawset(_G, id, str) end
function GetString(s) return s or "" end
function ZO_AbbreviateAndLocalizeNumber(n) return tostring(math.floor(n or 0)) end
function ZO_CommaDelimitNumber(n) return tostring(n) end
function PlaySound() end
function zo_callLater(fn) fn() end

function GetGameTimeMilliseconds() return T end
function GetAPIVersion() return 101050 end
function GetWorldName() return H.state.world end
function GetUIMousePosition() return H.state.mouse_x, H.state.mouse_y end
function IsUnitGrouped() return H.state.grouped end
function GetGroupSize() return H.state.group_size end
function GetUnitName(tag)
  if H.state.bosses[tag] then return H.state.bosses[tag].name end
  return "Velladocuments"
end
function GetUnitDisplayName() return "@vergelli" end
function GetUnitClass() return "Templar" end
function GetUnitRace() return "Breton" end
function GetUnitLevel() return 50 end
function GetUnitChampionPoints() return 1200 end
function GetUnitAlliance() return 1 end
function GetCurrentMapZoneIndex() return 1 end
function GetZoneNameByIndex() return "Mock Zone" end
function GetSlotName() return "" end
function GetSlotBoundId(slot, cat)
  local bars = H.slotted
  local bar = bars and bars[cat]
  return (bar and bar[slot]) or 0
end
function GetAbilityName(id) return (H.ability_names and H.ability_names[id]) or ("Ability" .. tostring(id)) end
function GetAbilityIcon(id)
  return (H.ability_icons and H.ability_icons[id]) or "EsoUI/Art/Icons/ability_mock.dds"
end
function IsAbilityPassive(id)
  return (H.passive_ids and H.passive_ids[id]) == true
end
function GetAbilityDescription(id, rank, caster)
  if caster == "player" then
    local dc = H.ability_descs_caster and H.ability_descs_caster[id]
    if dc then return dc end
  end
  return (H.ability_descs and H.ability_descs[id]) or ""
end
function GetNumBuffs(tag)
  local l = H.unit_buffs and H.unit_buffs[tag]
  return l and #l or 0
end
function GetUnitBuffInfo(tag, i)
  local b = H.unit_buffs[tag][i]
  return "MockBuff", 0, 0, b.slot, 1, "icon.dds", 0, 0, 0, 0, b.id, false, true
end
function GetAbilityEffectDescription(slot)
  return (H.slot_descs and H.slot_descs[slot]) or ""
end
function GetSpecificSkillAbilityKeysByAbilityId(id)
  local k = H.skill_keys and H.skill_keys[id]
  if k then return k[1], k[2], k[3] end
  return 0, 0, 0
end
function GetSkillLineId() return 0 end
function DoesUnitExist(tag) return H.state.bosses[tag] ~= nil end
function IsUnitInCombat(tag)
  if tag == "player" then return H.state.in_combat end
  local b = H.state.bosses[tag]
  return b ~= nil and b.in_combat ~= false
end
function IsUnitDead(tag)
  local b = H.state.bosses[tag]
  return b ~= nil and b.dead == true
end

local handlers = {}
local updates = {}

local FILTER_POS = {
  [EVENT_COMBAT_EVENT] = {
    [REGISTER_FILTER_COMBAT_RESULT]           = 1,
    [REGISTER_FILTER_IS_ERROR]                = 2,
    [REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE] = 7,
    [REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE] = 9,
  },
  [EVENT_EFFECT_CHANGED] = {
    [REGISTER_FILTER_UNIT_TAG]                = 4,
    [REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE] = 16,
  },
  [EVENT_UNIT_DEATH_STATE_CHANGED] = {
    [REGISTER_FILTER_UNIT_TAG] = 1,
  },
}

EVENT_MANAGER = {
  RegisterForEvent = function(_, name, code, fn)
    handlers[code] = handlers[code] or {}
    handlers[code][name] = { fn = fn, filters = {} }
    return true
  end,
  UnregisterForEvent = function(_, name, code)
    if handlers[code] then handlers[code][name] = nil end
    return true
  end,
  AddFilterForEvent = function(_, name, code, ftype, value)
    local reg = handlers[code] and handlers[code][name]
    if reg then reg.filters[#reg.filters + 1] = { ftype, value } end
    return true
  end,
  RegisterForUpdate = function(_, name, ms, fn)
    local interval = (ms and ms > 0) and ms or 16
    updates[name] = { fn = fn, interval = interval, due = T + interval }
    return true
  end,
  UnregisterForUpdate = function(_, name)
    updates[name] = nil
    return true
  end,
}

function H.fire(code, ...)
  local regs = handlers[code]
  if not regs then return 0 end
  local args = { ... }
  local nargs = select("#", ...)
  local pos_map = FILTER_POS[code]
  local fired = 0
  local snapshot = {}
  for name, reg in pairs(regs) do snapshot[name] = reg end
  for _, reg in pairs(snapshot) do
    local pass = true
    if pos_map then
      for _, f in ipairs(reg.filters) do
        local pos = pos_map[f[1]]
        if pos and args[pos] ~= f[2] then pass = false break end
      end
    end
    if pass then
      reg.fn(code, unpack(args, 1, nargs))
      fired = fired + 1
    end
  end
  return fired
end

function H.now() return T end

function H.advance(ms)
  local target = T + ms
  while true do
    local best_name, best_due
    for name, u in pairs(updates) do
      if u.due <= target and (best_due == nil or u.due < best_due) then
        best_name, best_due = name, u.due
      end
    end
    if not best_name then break end
    T = best_due
    local u = updates[best_name]
    u.due = u.due + u.interval
    u.fn()
  end
  T = target
end

function H.update_registered(name) return updates[name] ~= nil end

local next_unit_id = 1000

function H.heal(opts)
  opts = opts or {}
  local result = opts.result or ACTION_RESULT_HEAL
  return H.fire(EVENT_COMBAT_EVENT,
    result, false, "MockHeal", 0, 0,
    "Me", opts.source_type or COMBAT_UNIT_TYPE_PLAYER,
    "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 1000, 0, 0, false,
    opts.source_unit_id or 500, opts.target_unit_id or 600,
    opts.ability_id or 77, opts.overflow or 0)
end

function H.shield(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    ACTION_RESULT_DAMAGE_SHIELDED, false, "MockShield", 0, 0,
    "Enemy", opts.source_type or COMBAT_UNIT_TYPE_OTHER,
    "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 800, 0, 0, false,
    opts.source_unit_id or 900, opts.target_unit_id or 600,
    opts.ability_id or 88, 0)
end

function H.damage(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    opts.result or ACTION_RESULT_DAMAGE, false, "MockDamage", 0, 0,
    "Enemy", opts.source_type or COMBAT_UNIT_TYPE_OTHER,
    "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 2000, 0, 0, false,
    opts.source_unit_id or 900, opts.target_unit_id or 600,
    opts.ability_id or 0, 0)
end

function H.effect(change_type, ability_id, unit_id, end_time_s, source_type, unit_tag, effect_type, ability_type)
  if unit_tag == nil then unit_tag = "group1" end
  if effect_type == nil then effect_type = BUFF_EFFECT_TYPE_BUFF end
  return H.fire(EVENT_EFFECT_CHANGED,
    change_type, 1, "MockEffect", unit_tag, 0, end_time_s or 0,
    1, "icon.dds", 0, effect_type, ability_type or 0, 0,
    "Ally", unit_id, ability_id,
    source_type or COMBAT_UNIT_TYPE_PLAYER)
end

function H.death(is_dead, tag)
  return H.fire(EVENT_UNIT_DEATH_STATE_CHANGED, tag or "player", is_dead and true or false)
end

function H.combat_state(in_combat)
  H.state.in_combat = in_combat
  return H.fire(EVENT_PLAYER_COMBAT_STATE, in_combat)
end

function H.set_bosses(list)
  H.state.bosses = {}
  for i, b in ipairs(list or {}) do
    H.state.bosses["boss" .. i] = b
  end
  return H.fire(EVENT_BOSSES_CHANGED, false)
end

function H.scene(name, state)
  local list = SCENE_MANAGER.callbacks["SceneStateChanged"] or {}
  local scene = { GetName = function() return name end }
  for _, cb in ipairs(list) do cb(scene, nil, state or SCENE_SHOWN) end
end

function H.new_unit_id()
  next_unit_id = next_unit_id + 1
  return next_unit_id
end

function H.chat_contains(pattern)
  for _, line in ipairs(H.chat) do
    if line:find(pattern) then return line end
  end
  return nil
end

function H.clear_chat() H.chat = {} end
