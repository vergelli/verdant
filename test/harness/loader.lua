local ROOT = HARNESS_ROOT or "."

local manifest = io.open(ROOT .. "/Verdant.txt", "r")
if not manifest then error("cannot open Verdant.txt under " .. ROOT) end

local entries = {}
for line in manifest:lines() do
  local path = line:match("^%s*(.-)%s*$")
  entries[#entries + 1] = path
  if path ~= "" and not path:find("^#") and path:find("%.xml$") then
    HARNESS.tag_xml(ROOT .. "/" .. path)
  end
end

for _, path in ipairs(entries) do
  if path ~= "" and not path:find("^#") and path:find("%.lua$") and not path:find("%$%(") then
    dofile(ROOT .. "/" .. path)
    if path == "core/constants.lua" and HARNESS_DEBUG then
      Verdant.Constants.DEBUG = true
    end
  end
end

manifest:close()
