local ROOT = HARNESS_ROOT or "."

local manifest = io.open(ROOT .. "/Verdant.txt", "r")
if not manifest then error("cannot open Verdant.txt under " .. ROOT) end

for line in manifest:lines() do
  local path = line:match("^%s*(.-)%s*$")
  if path ~= "" and not path:find("^#") and path:find("%.lua$") and not path:find("%$%(") then
    dofile(ROOT .. "/" .. path)
    if path == "core/constants.lua" and HARNESS_DEBUG then
      Verdant.Constants.DEBUG = true
    end
  end
end

manifest:close()
