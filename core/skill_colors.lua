Verdant = Verdant or {}
Verdant.SkillColors = {}
local M = Verdant.SkillColors

local GetAbilityName = GetAbilityName
local string_lower   = string.lower
local string_find    = string.find

-- One color per class / skill-line.
local GROUP_COLORS = {
  templar   = { r = 0.95, g = 0.75, b = 0.15, a = 0.95 },  -- amber gold
  arcanist  = { r = 0.20, g = 0.92, b = 0.35, a = 0.95 },  -- vivid green
  warden    = { r = 0.10, g = 0.85, b = 0.60, a = 0.95 },  -- sky cyan
  resto     = { r = 0.72, g = 0.50, b = 0.18, a = 0.95 },  -- warm brown
  dk        = { r = 0.88, g = 0.28, b = 0.08, a = 0.95 },  -- rust orange
  sorc      = { r = 0.28, g = 0.38, b = 0.95, a = 0.95 },  -- electric blue
  nb        = { r = 0.82, g = 0.10, b = 0.18, a = 0.95 },  -- crimson
  necro     = { r = 0.65, g = 0.18, b = 0.82, a = 0.95 },  -- violet
  scribing  = { r = 0.50, g = 0.35, b = 1.00, a = 0.95 },  -- arcane blue
  undaunted = { r = 0.42, g = 0.42, b = 0.18, a = 0.95 },  -- olive
  support   = { r = 0.42, g = 0.31, b = 0.68, a = 0.95 },  -- muted purple
  other     = { r = 0.55, g = 0.55, b = 0.55, a = 0.80 },  -- unknown (grey)
  item      = { r = 0.95, g = 0.20, b = 0.80, a = 0.95 },
}

-- Lowercase English name fragments.  More specific patterns must come first.
-- Use /verdant dump to find IDs for skills that still show grey, then add
-- entries to ABILITY_OVERRIDES below (no name-lookup overhead for those).
local NAME_PATTERNS = {
  -- Templar
  { "breath of life",       "templar" },
  { "honor the dead",       "templar" },
  { "rushed ceremony",      "templar" },
  { "extended ritual",      "templar" },
  { "purifying ritual",     "templar" },
  { "healing ritual",       "templar" },
  { "restoring light",      "templar" },
  { "mending",              "templar" },
  { "luminous shards",      "templar" },
  { "repentance",           "templar" },
  -- Warden
  { "budding seeds",        "warden" },
  { "healing seed",         "warden" },
  { "healing thicket",      "warden" },
  { "enchanted forest",     "warden" },
  { "living thorn",         "warden" },
  { "leeching vines",       "warden" },
  { "polar wind",           "warden" },
  { "arctic wind",          "warden" },
  { "nature's grasp",       "warden" },
  { "nature's embrace",     "warden" },
  -- Arcanist (High-priority unique stems)
  { "runemend",       "arcanist" }, -- Audacious, Evolving, etc.
  { "reconstructive", "arcanist" }, -- Reconstructive Domain
  { "curative",       "arcanist" }, -- Curative Surge, etc.
  { "apocryphal",     "arcanist" }, -- Apocryphal Gate, Barriers, etc.
  { "chakram",        "arcanist" }, -- Chakram of Destiny
  { "glyphic",        "arcanist" }, -- Glyphic Cascade
  { "remedy",         "arcanist" }, -- Remedy Cascade
  { "fatecarver",     "arcanist" }, -- Pragmatic Fatecarver (escudo)
  { "zena",           "arcanist" }, -- Zenas' Empowering Disc
  { "tome-bearer",    "arcanist" }, -- Tome-bearer's Inspiration
  -- Dragonknight
  { "green dragon blood",   "dk" },
  { "coagulating blood",    "dk" },
  { "cauterize",            "dk" },
  { "burning heart",        "dk" },
  { "bursting vines",       "dk" },
  -- Sorcerer
  { "twilight matriarch",   "sorc" },
  { "twilight tormentor",   "sorc" },
  { "regenerative ward",    "sorc" },
  { "annulment",            "sorc" },
  { "dampen magic",         "sorc" },
  -- Nightblade
  { "refreshing path",      "nb" },
  { "twisting path",        "nb" },
  { "sap essence",          "nb" },
  { "drain power",          "nb" },
  { "swallow soul",         "nb" },
  { "funnel health",        "nb" },
  -- Necromancer
  { "render flesh",         "necro" },
  { "resistant flesh",      "necro" },
  { "ghostly embrace",      "necro" },
  { "restoring tether",     "necro" },
  { "braided tether",       "necro" },
  { "mortal coil",          "necro" },
  { "spirit mender",        "necro" },
  { "spirit guardian",      "necro" },
  { "intensive mender",     "necro" },
  -- Restoration Staff  (put "rapid" / "radiating" before plain "regeneration")
  { "healing springs",      "resto" },
  { "grand healing",        "resto" },
  { "illustrious healing",  "resto" },
  { "rapid regeneration",   "resto" },
  { "radiating regeneration","resto" },
  { "regeneration",         "resto" },
  { "combat prayer",        "resto" },
  { "blessed barrier",      "resto" },
  { "blessing of protection","resto" },
  { "healing ward",         "resto" },
  { "panacea",              "resto" },
  { "ward ally",            "resto" },
  { "mutagen",              "resto" },
  { "efficient purge",      "resto" },
  -- UNDAUNTED & WORLD (Sinergias y gremios)
  { "altar",          "undaunted" },
  { "blood",          "undaunted" },
  { "energy orb",     "undaunted" },
  -- Alliance War
  { "barrier",        "support" },
  { "purge",          "support" },
  { "Echoing Vigor",   "support" },
  { "Resolving Vigor",  "support" },
  -- Sets / Items (Cualquier cosa que huela a proc de set)
  { "sentinel",       "items" },
  { "earthgore",      "items" },
  { "chokethorn",     "items" },
  { "nightflame",     "items" },
  { "rkugamz",        "items" },
  -- Scribing Grimoires
  { "wield soul",    "scribing" },
  { "contingency",   "scribing" },
  { "torchbearer",   "scribing" },
  { "trample",       "scribing" },
  { "shatter",       "scribing" },
  { "soul burst",    "scribing" },
  { "mender's bond", "scribing" },
}

-- Direct ID → group overrides.  Faster than name lookup; add confirmed IDs here.
-- Format: [abilityId] = "group_key"
local ABILITY_OVERRIDES = {
  -- example: [29483] = "resto",
  [186191] = "arcanist",
  [186243] = "arcanist",
  [186265] = "arcanist",
  [186267] = "arcanist",
  [186203] = "arcanist",
  [61506] = "support",
  [33524] = "templar",
  [217608] = "scribing",
  [22228] = "templar",
  [44013] = "resto",
  [45518] = "undaunted",
  [176922] = "item",
  [217469] = "scribing"
}

-- Runtime cache (abilityId → group string); populated on first encounter.
local ability_cache = {}

-- IDs that fell through all patterns: { [abilityId] = "original name" }
-- Printed by M.print_unknown() so the user can add them to ABILITY_OVERRIDES.
local unknown_log = {}

local function classify_by_name(abilityId)
  local name = GetAbilityName(abilityId)
  if not name or name == "" then return "other" end
  local lc = string_lower(name)
  for _, entry in ipairs(NAME_PATTERNS) do
    if string_find(lc, entry[1], 1, true) then
      return entry[2]
    end
  end
  -- record for user discovery
  unknown_log[abilityId] = name
  return "other"
end

-- Print all unclassified abilities seen so far.
-- Use /verdant skills after a heal session to discover what to add to ABILITY_OVERRIDES.
function M.print_unknown()
  local d      = d
  local lines  = {}
  local count  = 0
  for id, name in pairs(unknown_log) do
    lines[#lines + 1] = string.format("  [%d] = \"?\",  -- %s", id, name)
    count = count + 1
  end
  if count == 0 then
    d("[V] No unclassified heal/shield abilities seen yet.")
    return
  end
  table.sort(lines)
  d("[V] Unclassified abilities (" .. count .. ") — add to ABILITY_OVERRIDES in skill_colors.lua:")
  for _, line in ipairs(lines) do d(line) end
end

local function lookup_group(abilityId)
  if not abilityId or abilityId <= 0 then return "other" end
  local g = ability_cache[abilityId]
  if g then return g end
  g = ABILITY_OVERRIDES[abilityId] or classify_by_name(abilityId)
  ability_cache[abilityId] = g
  return g
end

local FALLBACK = GROUP_COLORS.other

function M.get_color(abilityId)
  return GROUP_COLORS[lookup_group(abilityId)] or FALLBACK
end

-- Returns a sorted array of { r, g, b, a, share } (largest segment first).
-- All shares sum to 1.  Empty if total is 0.
function M.group_shares(buf, now_ms, predicate)
  buf:trim(now_ms)
  local buckets = {}
  local total   = 0
  for i = buf.head, buf.tail do
    local e   = buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and (not predicate or predicate(e)) then
      local key = lookup_group(e.abilityId)
      buckets[key] = (buckets[key] or 0) + amt
      total = total + amt
    end
  end
  if total <= 0 then return {} end
  local out = {}
  for g, amt in pairs(buckets) do
    local c = GROUP_COLORS[g] or FALLBACK
    out[#out + 1] = { r = c.r, g = c.g, b = c.b, a = c.a, share = amt / total }
  end
  table.sort(out, function(a, b) return a.share > b.share end)
  return out
end
