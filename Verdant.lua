Verdant = Verdant or {}
local Verdant = Verdant

local SLASH_COMMANDS = SLASH_COMMANDS
local ZO_SavedVars   = ZO_SavedVars
local d              = d
local string_format  = string.format
local string_lower   = string.lower
local string_match   = string.match
local table_concat   = table.concat

local KNOWN_FILTERS = { heal=true, shield=true, damage=true, effect=true, group=true, all=true }

local function format_help()
  local L = Verdant.L
  local out = { L.HELP_HEADER }
  for i = 1, #L.HELP_LINES do out[#out + 1] = L.HELP_LINES[i] end
  return table_concat(out, "\n")
end

local function on_slash(input)
  local L = Verdant.L
  input = input or ""
  local cmd = string_match(string_lower(input), "^%s*(%S+)") or "help"

  if cmd == "on" then
    Verdant.Probe.set_enabled(true)
    d("[V] " .. L.PROBE_ON)
  elseif cmd == "off" then
    Verdant.Probe.set_enabled(false)
    d("[V] " .. L.PROBE_OFF)
  elseif cmd == "filter" then
    local val = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
    if KNOWN_FILTERS[val] then
      Verdant.Probe.set_filter(val)
      d("[V] " .. string_format(L.FILTER_SET, val))
    else
      d("[V] " .. string_format(L.FILTER_UNKNOWN, val))
    end
  elseif cmd == "dump" then
    Verdant.Probe.dump()
  elseif cmd == "save" then
    Verdant.Probe.persist_to_savedvars(Verdant.SavedVars)
    d("[V] " .. L.DUMP_SAVED)
  elseif cmd == "clear" then
    Verdant.Probe.clear()
    d("[V] " .. L.BUFFER_CLEARED)
  else
    d("[V] " .. format_help())
  end
end

local function on_addon_loaded()
  local C = Verdant.Constants

  Verdant.SavedVars = ZO_SavedVars:NewAccountWide(C.SV_TABLE, C.SV_VERSION, nil, { probe = {} })
  Verdant.Probe.init()

  SLASH_COMMANDS[C.SLASH_COMMAND] = on_slash

  d("[V] " .. string_format(Verdant.L.LOADED, C.VERSION, C.SLASH_COMMAND))
end

Verdant.Events.register_addon_loaded(Verdant.Constants.ADDON_NAME, on_addon_loaded)
