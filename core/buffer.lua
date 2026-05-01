Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Buffer = {}

local M = Verdant.Buffer
M.__index = M

local table_remove = table.remove

function M.new(window_ms, capacity)
  local self = setmetatable({}, M)
  self.window_ms = window_ms or 5000
  self.capacity  = capacity or 1024
  self.entries   = {}
  self.head      = 1
  self.tail      = 0
  return self
end

function M:push(entry)
  self.tail = self.tail + 1
  self.entries[self.tail] = entry
  if (self.tail - self.head + 1) > self.capacity then
    self.entries[self.head] = nil
    self.head = self.head + 1
  end
end

function M:trim(now_ms)
  local cutoff = now_ms - self.window_ms
  while self.head <= self.tail and (self.entries[self.head].t or 0) <= cutoff do
    self.entries[self.head] = nil
    self.head = self.head + 1
  end
end

function M:sum(now_ms, field, predicate)
  self:trim(now_ms)
  local s = 0
  for i = self.head, self.tail do
    local e = self.entries[i]
    if not predicate or predicate(e) then
      s = s + (e[field] or 0)
    end
  end
  return s
end

function M:count(now_ms, predicate)
  self:trim(now_ms)
  local n = 0
  for i = self.head, self.tail do
    if not predicate or predicate(self.entries[i]) then
      n = n + 1
    end
  end
  return n
end

function M:size()
  return self.tail - self.head + 1
end

function M:reset()
  self.entries = {}
  self.head = 1
  self.tail = 0
end
