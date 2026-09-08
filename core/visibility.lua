Verdant = Verdant or {}
Verdant.Visibility = {}
local M = Verdant.Visibility

local Scene = Verdant.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Verdant.Log.for_module("visibility")
local in_hud = true
local user_visible = { bar = false, graph = false }
local bar_enabled = true
local role_ok = true
local restore = {}

local function role_only()
  local sv = Verdant.SavedVars
  return sv and sv.settings and sv.settings.role_only == true or false
end

local function role_matches()
  if not role_only() then return true end
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if type(api.GetSelectedLFGRole) ~= "function" or zc.LFG_ROLE_HEAL == nil then return true end
  return api.GetSelectedLFGRole() == zc.LFG_ROLE_HEAL
end
local AUX_WINDOWS = { "VerdantSettingsPanel", "VerdantLibrary", "VerdantAssignPanel", "VerdantWatchOverlay" }


local function apply()
  if VerdantBarWindow then
    VerdantBarWindow:SetHidden(not (in_hud and user_visible.bar and bar_enabled and role_ok))
  end
  if VerdantGraphWindow then
    VerdantGraphWindow:SetHidden(not (in_hud and user_visible.graph))
  end
  if VerdantGraphWindowBarBtn then
    VerdantGraphWindowBarBtn:SetHidden(not bar_enabled)
  end
  for _, name in ipairs(AUX_WINDOWS) do
    local win = _G[name]
    if win then
      if in_hud then
        if restore[name] then
          win:SetHidden(false)
          restore[name] = nil
        end
      elseif not win:IsHidden() then
        restore[name] = true
        win:SetHidden(true)
      end
    end
  end
  if Verdant.Logo then
    Verdant.Logo.sync(in_hud and not user_visible.graph)
  end
end

local function persist()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.bar      = sv.bar      or {} ; sv.bar.visible      = user_visible.bar
  sv.bar.enabled = bar_enabled
  sv.temporal = sv.temporal or {} ; sv.temporal.visible = user_visible.graph
end

function M.set(key, visible)
  if key == "bar" and visible and not bar_enabled then return end
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
  persist()
end

function M.get(key) return user_visible[key] or false end

function M.master_toggle()
  if user_visible.bar or user_visible.graph then
    log:info("master_toggle: hiding all")
    user_visible.bar    = false
    user_visible.graph  = false
  else
    if bar_enabled then
      log:info("master_toggle: showing bar")
      user_visible.bar = true
    else
      log:info("master_toggle: bars disabled, showing graph")
      user_visible.graph = true
    end
  end
  apply()
  persist()
end

function M.set_bar_enabled(enabled)
  if bar_enabled == enabled then return end
  log:info("bar_enabled ->", enabled and "on" or "off")
  bar_enabled = enabled
  if enabled then user_visible.bar = true end
  apply()
  persist()
end

function M.is_bar_enabled() return bar_enabled end

function M.refresh_role()
  local now = role_matches()
  if now == role_ok then return end
  role_ok = now
  log:info("role gate ->", now and "match" or "mismatch")
  apply()
end

function M.role_allows_bar() return role_ok end

function M.set_role_only(on)
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.settings = sv.settings or {}
  sv.settings.role_only = on and true or false
  M.refresh_role()
end

function M.get_role_only() return role_only() end

function M.init()
  local sv = Verdant.SavedVars
  if sv then
    user_visible.bar   = (sv.bar      and sv.bar.visible)      or false
    user_visible.graph = (sv.temporal and sv.temporal.visible) or false
    if sv.bar and sv.bar.enabled ~= nil then bar_enabled = sv.bar.enabled end
  end

  local zev = Verdant.zenimax.events
  local zc  = Verdant.zenimax.constants
  if zc.EVENT_GROUP_MEMBER_ROLE_CHANGED then
    zev.register("Verdant_Vis_Role", zc.EVENT_GROUP_MEMBER_ROLE_CHANGED, function(unitTag)
      if unitTag == "player" then M.refresh_role() end
    end)
  end
  zev.register("Verdant_Vis_Activated", zc.EVENT_PLAYER_ACTIVATED, function() M.refresh_role() end)
  role_ok = role_matches()

  Scene.register_callback("SceneStateChanged",
    function(scene, oldState, newState)
      if newState ~= SCENE_SHOWN then return end
      local now = Scene.is_hud_scene(scene:GetName())
      if now == in_hud then return end
      in_hud = now
      apply()
    end)

  apply()
end
