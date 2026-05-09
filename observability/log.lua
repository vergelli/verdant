-- Verdant.Log — minimal logger that wraps chat (d()) and CopyBox.
--
-- Usage:
--   local log = Verdant.Log.for_module("mem.ring_buffer")
--   log:info("acquired event", ev_id)
--   log:warn("pool pressure", in_use, "/", cap)
--   log:err("invalid state:", err)
--
-- Args after msg are tostring'd and joined with spaces.
--
-- Routing:
--   DEBUG = true  → all levels go to CopyBox
--   DEBUG = false → info/warn no-op; err goes to chat (errors stay visible)
--
-- This module is loaded at all times (~80 lines of Lua). When DEBUG is
-- false the no-ops short-circuit at the first line of each level fn.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Log = {}
local M = Verdant.Log

local d        = d
local tostring = tostring
local concat   = table.concat

-- Tightly-bound aliases for frequent module paths. Keeps the prefix short
-- in the output without losing precision.
local ALIAS = {
  ["observability.diagnostics"] = "diag",
  ["core.engine"]               = "engine",
  ["core.metrics"]              = "metrics",
  ["core.probe"]                = "probe",
}

local function format_line(level, source, args, n)
  local prefix = "[" .. (ALIAS[source] or source) .. "]"
  if level ~= "info" then
    prefix = prefix .. " " .. level .. ":"
  end
  -- Build the body. Up to 8 args inline; rare path uses concat.
  if n == 0 then return prefix end
  local body
  if n == 1 then body = tostring(args[1])
  elseif n == 2 then body = tostring(args[1]) .. " " .. tostring(args[2])
  else
    local parts = {}
    for i = 1, n do parts[i] = tostring(args[i]) end
    body = concat(parts, " ")
  end
  return prefix .. " " .. body
end

local function emit(level, source, ...)
  local n = select("#", ...)
  local args = { ... }
  local line = format_line(level, source, args, n)
  if Verdant.Constants.DEBUG and Verdant.CopyBox then
    Verdant.CopyBox.append(line)
  elseif level == "err" then
    d(line)
  end
end

-- Flat API.
function M.info(source, ...) emit("info", source, ...) end
function M.warn(source, ...) emit("warn", source, ...) end
function M.err(source, ...)  emit("err",  source, ...) end

-- Bound API: one logger per module, source captured once.
local Bound = {}
Bound.__index = Bound

function Bound:info(...) emit("info", self.source, ...) end
function Bound:warn(...) emit("warn", self.source, ...) end
function Bound:err(...)  emit("err",  self.source, ...) end

function M.for_module(source)
  return setmetatable({ source = source }, Bound)
end
