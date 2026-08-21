return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  ok(Verdant ~= nil, "Verdant global missing")
  ok(type(Verdant.Pipeline.init) == "function", "pipeline missing")
  ok(SLASH_COMMANDS["/verdant"] ~= nil, "slash command not registered")
  ok(Verdant.Metrics.pool_capacity() == 4096, "event pool capacity mismatch")
  ok(Verdant.TemporalBuffer.capacity() == 60, "temporal buffer capacity mismatch")
  ok(H.chat_contains("error") == nil, "boot emitted an error: " .. tostring(H.chat_contains("error")))
end
