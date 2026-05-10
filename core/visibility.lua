Verdant = Verdant or {}
Verdant.Visibility = {}
local M = Verdant.Visibility

local Scene = Verdant.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Verdant.Log.for_module("visibility")

-- ── state ─────────────────────────────────────────────────────────────────
-- in_hud: true while either the gameplay HUD scene or the HUD-overlay scene
-- (chat input, etc.) is the active scene.  Anything else (inventory, map,
-- character, journal, etc.) sets in_hud=false and we hide our windows.
local in_hud = true

-- User-intent visibility per window, persisted in SavedVars.  This is the
-- "the user wants this open" flag, INDEPENDENT from the actual SetHidden
-- state — that way auto-hiding during a non-HUD scene does not erase the
-- user's preference.  Actual visibility = in_hud AND user_visible[key].
local user_visible = { bar = false, graph = false }

-- ── apply / persist ───────────────────────────────────────────────────────
local function apply()
  if VerdantBarWindow then
    VerdantBarWindow:SetHidden(not (in_hud and user_visible.bar))
  end
  if VerdantGraphWindow then
    VerdantGraphWindow:SetHidden(not (in_hud and user_visible.graph))
  end
  -- Settings panel is transient: just hide it whenever leaving HUD; the
  -- user can re-open it via the gear icon on the bar when back in HUD.
  if VerdantSettingsPanel and not in_hud then
    VerdantSettingsPanel:SetHidden(true)
  end
end

local function persist()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.bar      = sv.bar      or {} ; sv.bar.visible      = user_visible.bar
  sv.temporal = sv.temporal or {} ; sv.temporal.visible = user_visible.graph
end

-- ── public API ────────────────────────────────────────────────────────────
function M.set(key, visible)
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
  persist()
end

function M.get(key) return user_visible[key] or false end

-- Master toggle wired to the keybind: closes ALL open windows in one shot,
-- or — if every window is closed — opens just the bar.  The graph is not
-- auto-opened so the keybind always has a predictable "show the entry
-- point" action.
function M.master_toggle()
  if user_visible.bar or user_visible.graph then
    log:info("master_toggle: hiding all")
    user_visible.bar    = false
    user_visible.graph  = false
  else
    log:info("master_toggle: showing bar")
    user_visible.bar    = true
  end
  apply()
  persist()
end

function M.init()
  local sv = Verdant.SavedVars
  if sv then
    user_visible.bar   = (sv.bar      and sv.bar.visible)      or false
    user_visible.graph = (sv.temporal and sv.temporal.visible) or false
  end

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
