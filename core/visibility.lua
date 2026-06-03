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

-- Master switch for the individual-bars window (Settings → "Individual Bars").
-- Independent from user_visible.bar (the open/closed intent): when this is off
-- the bar window can never show and its re-open affordances are suppressed.
local bar_enabled = true

-- ── apply / persist ───────────────────────────────────────────────────────
local function apply()
  if VerdantBarWindow then
    VerdantBarWindow:SetHidden(not (in_hud and user_visible.bar and bar_enabled))
  end
  if VerdantGraphWindow then
    VerdantGraphWindow:SetHidden(not (in_hud and user_visible.graph))
  end
  -- The graph's "+" button re-opens the bar; it's meaningless when bars are
  -- disabled, so hide it to avoid a dead click.
  if VerdantGraphWindowBarBtn then
    VerdantGraphWindowBarBtn:SetHidden(not bar_enabled)
  end
  -- Settings panel is transient: just hide it whenever leaving HUD; the
  -- user can re-open it via the gear icon on the bar when back in HUD.
  if VerdantSettingsPanel and not in_hud then
    VerdantSettingsPanel:SetHidden(true)
  end
  -- Floating logo: a launcher for the graph window. Show it only while in the
  -- HUD with the graph closed; Logo.sync also respects the user's on/off toggle.
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

-- ── public API ────────────────────────────────────────────────────────────
function M.set(key, visible)
  -- Individual bars can be disabled in Settings; ignore show requests for the
  -- bar while disabled so the keybind / graph "+" / slash can't override it.
  if key == "bar" and visible and not bar_enabled then return end
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
    -- Nothing open: show the usual entry point. The bar is it — unless the
    -- user disabled individual bars, in which case fall back to the graph.
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

-- Master on/off for the individual-bars window (Settings toggle). Turning it on
-- also opens the bar so the change is immediately visible.
function M.set_bar_enabled(enabled)
  if bar_enabled == enabled then return end
  log:info("bar_enabled ->", enabled and "on" or "off")
  bar_enabled = enabled
  if enabled then user_visible.bar = true end
  apply()
  persist()
end

function M.is_bar_enabled() return bar_enabled end

function M.init()
  local sv = Verdant.SavedVars
  if sv then
    user_visible.bar   = (sv.bar      and sv.bar.visible)      or false
    user_visible.graph = (sv.temporal and sv.temporal.visible) or false
    -- Default ON (preserves prior behavior); only an explicit saved false disables.
    if sv.bar and sv.bar.enabled ~= nil then bar_enabled = sv.bar.enabled end
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
