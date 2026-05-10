-- EVENT_MANAGER façade. Verdant code never calls EVENT_MANAGER directly —
-- it goes through this module so the ACL boundary is single-source.
-- Every callback registered here is wrapped in pcall so a single bug
-- inside one handler can't silently break the rest of the addon.
--
-- Public surface:
--   register_addon_loaded(name, callback)  one-shot, auto-unregisters
--   register(name, eventCode, handler)     pcall-wrapped handler
--   unregister(name, eventCode)
--   add_filter(name, eventCode, ...)       see SPEC_01 §4.2
--   register_update(name, interval_ms, callback)
--   unregister_update(name)

Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.events = {}

local EVENT_MANAGER = EVENT_MANAGER
local d             = d
local pcall         = pcall
local tostring      = tostring

local M = Verdant.zenimax.events

function M.register_addon_loaded(name, callback)
  EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == name then
      EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
      callback()
    end
  end)
end

-- Wrap every handler in pcall so a single bug never silently breaks the probe.
function M.register(name, eventCode, handler)
  EVENT_MANAGER:RegisterForEvent(name, eventCode, function(_, ...)
    local ok, err = pcall(handler, ...)
    if not ok and Verdant.Constants.DEBUG then
      d("[Verdant] handler '" .. name .. "' error: " .. tostring(err))
    end
  end)
end

function M.unregister(name, eventCode)
  EVENT_MANAGER:UnregisterForEvent(name, eventCode)
end

function M.add_filter(name, eventCode, ...)
  EVENT_MANAGER:AddFilterForEvent(name, eventCode, ...)
end

function M.register_update(name, interval_ms, callback)
  EVENT_MANAGER:RegisterForUpdate(name, interval_ms, callback)
end

function M.unregister_update(name)
  EVENT_MANAGER:UnregisterForUpdate(name)
end
