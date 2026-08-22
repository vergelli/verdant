return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  if not Verdant.Constants.DEBUG then return end

  local slash = SLASH_COMMANDS["/verdant"]
  H.clear_chat()

  slash("diag")
  slash("report")
  slash("report full")
  slash("prof")
  slash("validate")

  ok(H.chat_contains("handler .* error") == nil, "a slash handler errored")
  ok(H.chat_contains("disabled") == nil, "a DEBUG surface reported disabled while DEBUG=true")
end
