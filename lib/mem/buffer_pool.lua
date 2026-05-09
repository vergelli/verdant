-- Generic O(1) object pool. Pre-allocates `capacity` records via `factory`
-- and maintains a free-list of indices. Per SPEC_03 §5.1.
--
--   pool = BufferPool.new(factory, capacity)
--   ev   = pool:acquire()      -- returns record or nil if exhausted
--   pool:release(ev)
--   pool:in_use()              -- count of records currently outstanding
--   pool:capacity()
--
-- The factory must produce a fresh record each call. The pool stamps
-- `record._pool_idx` at construction; release looks at that index to
-- return the record to the free-list.

Verdant = Verdant or {}
Verdant.lib = Verdant.lib or {}
Verdant.lib.mem = Verdant.lib.mem or {}

local BufferPool = {}
BufferPool.__index = BufferPool
Verdant.lib.mem.BufferPool = BufferPool

function BufferPool.new(factory, capacity)
  local self = setmetatable({}, BufferPool)
  self._capacity = capacity
  self._records  = {}
  self._free     = {}      -- stack of free indices
  self._in_use   = 0
  for i = 1, capacity do
    local rec = factory()
    rec._pool_idx = i
    self._records[i] = rec
    self._free[i] = i      -- pushed in order; pops yield capacity, capacity-1, ...
  end
  self._free_top = capacity
  return self
end

function BufferPool:acquire()
  local top = self._free_top
  if top == 0 then return nil end
  local idx = self._free[top]
  self._free[top] = nil
  self._free_top = top - 1
  self._in_use = self._in_use + 1
  return self._records[idx]
end

function BufferPool:release(rec)
  if not rec or not rec._pool_idx then return end
  local top = self._free_top + 1
  self._free[top] = rec._pool_idx
  self._free_top = top
  self._in_use = self._in_use - 1
end

function BufferPool:in_use()
  return self._in_use
end

function BufferPool:capacity()
  return self._capacity
end
