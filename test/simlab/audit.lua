local ROOT = arg and arg[1] or "."
local OUT  = ROOT .. "/test/simlab/out"

local function list_svgs()
  local files = {}
  local windows = package.config:sub(1, 1) == "\\"
  local cmd = windows
    and ('dir /b "' .. OUT:gsub("/", "\\") .. '\\*.svg" 2>nul')
    or  ('ls "' .. OUT .. '" 2>/dev/null')
  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      if line:find("%.svg$") then files[#files + 1] = line end
    end
    p:close()
  end
  table.sort(files)
  return files
end

local function parse(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local svg = f:read("*a")
  f:close()

  local vb = { svg:match('viewBox="(-?[%d.]+) (-?[%d.]+) ([%d.]+) ([%d.]+)"') }
  local box = { x = tonumber(vb[1]) + 20, y = tonumber(vb[2]) + 20,
                w = tonumber(vb[3]) - 40, h = tonumber(vb[4]) - 40 }

  local els = {}
  for line in svg:gmatch("[^\n]+") do
    local title = line:match("<title>([^<]*)") or ""
    if line:find("^<rect") and title ~= "" then
      local x = tonumber(line:match('x="(-?[%d.]+)"'))
      local y = tonumber(line:match('y="(-?[%d.]+)"'))
      local w = tonumber(line:match('width="([%d.]+)"'))
      local h = tonumber(line:match('height="([%d.]+)"'))
      local op = tonumber(line:match('fill%-opacity="([%d.]+)"')) or 1
      if x and w then
        els[#els + 1] = { kind = "rect", x = x, y = y, w = w, h = h, op = op,
                          button = title:find("Btn") ~= nil, name = title:match("^%S+") }
      end
    elseif line:find("^<text") then
      local txt = line:match("</title>([^<]*)") or ""
      local x = tonumber(line:match('x="(-?[%d.]+)"'))
      local y = tonumber(line:match('y="(-?[%d.]+)"'))
      local px = tonumber(line:match('font%-size="(%d+)"')) or 12
      local dataw = tonumber(line:match('data%-w="([%d.]+)"')) or 0
      local anchor = line:match('text%-anchor="(%w+)"') or "start"
      local plain = txt:gsub("|t.-|t", ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
      local tw = #plain * px * 0.55
      local h = px
      if dataw > 0 and tw > dataw then
        h = px * math.ceil(tw / dataw)
        tw = dataw
      end
      local x0 = x
      if anchor == "middle" then x0 = x - tw / 2
      elseif anchor == "end" then x0 = x - tw end
      if x and plain ~= "" then
        els[#els + 1] = { kind = "text", x = x0, y = y - h / 2, w = tw, h = h,
                          text = plain, op = 1, name = title:match("^%S+") }
      end
    end
  end
  return box, els
end

local FLOATING = { "VerdantHoverCard", "VerdantGraphCrosshair" }

local function floating(name)
  if not name then return false end
  for _, p in ipairs(FLOATING) do
    if name:find("^" .. p) then return true end
  end
  return false
end

local function overlaps(a, b)
  local m = 2
  return a.x + m < b.x + b.w and b.x < a.x + a.w - m
     and a.y + m < b.y + b.h and b.y < a.y + a.h - m
end

local total = 0
for _, name in ipairs(list_svgs()) do
  local box, els = parse(OUT .. "/" .. name)
  if box and box.x then
    local finds = {}
    for _, e in ipairs(els) do
      if e.op > 0.05 and not floating(e.name) then
        if e.x < box.x - 0.5 or e.y < box.y - 0.5
           or e.x + e.w > box.x + box.w + 0.5
           or e.y + e.h > box.y + box.h + 0.5 then
          finds[#finds + 1] = string.format(
            "  OUT-OF-BOUNDS %s (%.0f,%.0f %sx%s) %s",
            e.kind, e.x, e.y, e.w, e.h, e.text or "")
        end
      end
    end
    for i = 1, #els do
      local a = els[i]
      if a.kind == "text" and not floating(a.name) then
        for j = 1, #els do
          local b = els[j]
          if floating(b.name) then
          elseif j > i and b.kind == "text" and overlaps(a, b) then
            finds[#finds + 1] = string.format(
              '  TEXT-OVERLAP "%s" vs "%s" at (%.0f,%.0f)', a.text, b.text, a.x, a.y)
          end
          if b.kind == "rect" and b.button and overlaps(a, b) then
            finds[#finds + 1] = string.format(
              '  TEXT-UNDER-BUTTON "%s" vs %s at (%.0f,%.0f)', a.text, b.name or "?", a.x, a.y)
          end
        end
      end
    end
    if #finds > 0 then
      print(name .. ":")
      for _, l in ipairs(finds) do print(l) end
      total = total + #finds
    end
  end
end
print(string.format("== audit: %d finding(s) ==", total))
os.exit(total == 0 and 0 or 1)
