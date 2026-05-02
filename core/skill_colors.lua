Verdant = Verdant or {}
Verdant.SkillColors = {}
local M = Verdant.SkillColors

-- One color per class / skill-line.
-- Two shades were considered but a single vivid color per group reads better
-- on a narrow vertical bar at small sizes.
local GROUP_COLORS = {
  templar   = { r = 0.95, g = 0.75, b = 0.15, a = 0.95 },  -- amber gold
  arcanist  = { r = 0.20, g = 0.92, b = 0.35, a = 0.95 },  -- vivid green
  warden    = { r = 0.20, g = 0.85, b = 0.90, a = 0.95 },  -- ice cyan
  resto     = { r = 0.72, g = 0.50, b = 0.18, a = 0.95 },  -- brass / brown
  dk        = { r = 0.88, g = 0.28, b = 0.08, a = 0.95 },  -- rust orange
  sorc      = { r = 0.28, g = 0.38, b = 0.95, a = 0.95 },  -- electric blue
  nb        = { r = 0.82, g = 0.10, b = 0.18, a = 0.95 },  -- crimson
  necro     = { r = 0.65, g = 0.18, b = 0.82, a = 0.95 },  -- violet
  undaunted = { r = 0.62, g = 0.62, b = 0.68, a = 0.95 },  -- silver
  other     = { r = 0.55, g = 0.55, b = 0.55, a = 0.80 },  -- unknown (grey)
}

-- ability ID → group key
-- Covers the most common healer skills.  Unknown IDs fall through to "other".
-- Use /verdant dump to discover IDs for skills not listed here, then add them.
local ABILITY_MAP = {

  -- ── Templar ──────────────────────────────────────────────────────────────
  -- Rushed Ceremony / Breath of Life / Honor the Dead
  [1604]  = "templar",
  [5938]  = "templar",
  [1977]  = "templar",
  -- Healing Ritual / Extended Ritual / Purifying Ritual
  [1122]  = "templar",
  [5899]  = "templar",
  [5900]  = "templar",
  -- Restoring Light / Mending / Rapid Mending
  [1718]  = "templar",
  [5924]  = "templar",
  [5925]  = "templar",
  -- Spear Shards / Luminous Shards / Blazing Spear
  [21353] = "templar",
  [21365] = "templar",
  [21366] = "templar",
  -- Restoring Aura / Radiant Aura / Repentance
  [2259]  = "templar",
  [2260]  = "templar",
  [22250] = "templar",

  -- ── Warden ───────────────────────────────────────────────────────────────
  -- Healing Seed / Budding Seeds / Corrupting Pollen
  [85414] = "warden",
  [85432] = "warden",
  [85433] = "warden",
  -- Healing Thicket / Enchanted Forest / Nature's Embrace
  [85499] = "warden",
  [85502] = "warden",
  [85505] = "warden",
  -- Living Thorn / Leeching Vines
  [100175]= "warden",
  [100178]= "warden",
  -- Arctic Wind / Polar Wind / Icy Aura
  [86127] = "warden",
  [86130] = "warden",
  [86133] = "warden",

  -- ── Arcanist ─────────────────────────────────────────────────────────────
  -- Apocryphal Gate / Wanderer's Mark / Fatecarver heals
  [183508]= "arcanist",
  [183509]= "arcanist",
  [183510]= "arcanist",
  [185820]= "arcanist",
  [185821]= "arcanist",
  [186006]= "arcanist",
  [186007]= "arcanist",

  -- ── Dragonknight ─────────────────────────────────────────────────────────
  -- Green Dragon Blood / Coagulating Blood / Bursting Vines
  [29059] = "dk",
  [29062] = "dk",
  [29065] = "dk",
  -- Cauterize / Burning Heart
  [33414] = "dk",
  [33417] = "dk",

  -- ── Sorcerer ─────────────────────────────────────────────────────────────
  -- Twilight Matriarch / Twilight Tormentor
  [23236] = "sorc",
  [23241] = "sorc",
  -- Regenerative Ward / Annulment / Dampen Magic
  [24830] = "sorc",
  [24833] = "sorc",
  [24836] = "sorc",

  -- ── Nightblade ───────────────────────────────────────────────────────────
  -- Refreshing Path / Twisting Path
  [33195] = "nb",
  [33208] = "nb",
  -- Sap Essence / Drain Power / Swallow Soul
  [37526] = "nb",
  [37528] = "nb",
  [61907] = "nb",
  [61910] = "nb",

  -- ── Necromancer ──────────────────────────────────────────────────────────
  -- Render Flesh / Resistant Flesh / Ghostly Embrace
  [114108]= "necro",
  [114111]= "necro",
  [114114]= "necro",
  -- Restoring Tether / Braided Tether / Mortal Coil
  [115009]= "necro",
  [115012]= "necro",
  [115015]= "necro",
  -- Spirit Mender / Spirit Guardian / Intensive Mender
  [114343]= "necro",
  [114346]= "necro",
  [114349]= "necro",

  -- ── Restoration Staff ────────────────────────────────────────────────────
  -- Grand Healing / Healing Springs / Illustrious Healing
  [29478] = "resto",
  [29483] = "resto",
  [29488] = "resto",
  -- Regeneration / Rapid Regeneration / Radiating Regeneration
  [1376]  = "resto",
  [1377]  = "resto",
  [1378]  = "resto",
  -- Combat Prayer / Blessed Barrier / Blessing of Protection
  [29493] = "resto",
  [29494] = "resto",
  [29495] = "resto",
  -- Healing Ward / Panacea / Ward Ally
  [29490] = "resto",
  [29491] = "resto",
  [29492] = "resto",
  -- Mutagen / Efficient Purge / Cure
  [38928] = "resto",
  [38931] = "resto",
  [38934] = "resto",

  -- ── Undaunted ────────────────────────────────────────────────────────────
  -- Blood Altar / Overflowing Altar / Bloodthirst
  [33010] = "undaunted",
  [33013] = "undaunted",
  [33016] = "undaunted",
}

local FALLBACK = GROUP_COLORS.other

function M.get_color(abilityId)
  local g = ABILITY_MAP[abilityId]
  if g then return GROUP_COLORS[g] end
  return FALLBACK
end

-- Returns a sorted array of { r, g, b, a, share } where share is 0-1 and
-- all shares sum to 1.  Largest segment first (bottom of a vertical bar).
-- buf: a Verdant.Buffer instance whose entries have .amount and .abilityId.
-- predicate: optional function(entry) → bool (same as Buffer:sum's predicate).
function M.group_shares(buf, now_ms, predicate)
  buf:trim(now_ms)
  local buckets = {}
  local total   = 0
  for i = buf.head, buf.tail do
    local e   = buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and (not predicate or predicate(e)) then
      local key = ABILITY_MAP[e.abilityId] or "other"
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
