Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Constants = {
  ADDON_NAME    = "Verdant",
  VERSION       = "2.0.0",
  SLASH_COMMAND = "/verdant",

  -- DEBUG gates developer-only slash subcommands (probe/dump/diag/...) and,
  -- starting in Phase 6, observability layers (log/profiler/validation).
  -- Release builds keep this false so the no-op references are wired in
  -- and the cost of dev instrumentation stays out of the hot path.
  DEBUG         = false,

  SV_TABLE   = "VerdantSavedVars",
  SV_VERSION = 1,

  PROBE = {
    -- Distinct names per registration: EVENT_MANAGER keys filters by (name, eventCode).
    SRC_COMBAT_OUT      = "Verdant_CombatOut",       -- heals where source=player
    SRC_COMBAT_IN       = "Verdant_CombatIn",        -- damage where target=group
    SRC_SHIELD_RAW      = "Verdant_ShieldRaw",       -- DAMAGE_SHIELDED, no source filter
    SRC_HEAL_ABSORBED   = "Verdant_HealAbsorbed",    -- HEAL_ABSORBED where source=player
    SRC_EFFECT          = "Verdant_Effect",          -- effects where source=player
    SRC_EFFECT_ON_SELF  = "Verdant_EffectOnSelf",    -- effects where target=player
    SRC_COMBAT_STATE    = "Verdant_CombatState",
    SRC_CAST            = "Verdant_Cast",
    SRC_GROUP_J         = "Verdant_GroupJoined",
    SRC_GROUP_L         = "Verdant_GroupLeft",
    SRC_GROUP_U         = "Verdant_GroupUpdate",
    SRC_PLAYER          = "Verdant_PlayerActivated",
    SRC_AUTOSAVE        = "Verdant_AutoSave",

    -- Last N events kept per category in the rolling buffer.
    BUFFER_LIMIT = 200,

    -- Min ms between chat lines while logging is ON, to avoid spam in raid.
    CHAT_INTERVAL_MS = 250,

    -- How many full snapshots to keep in SavedVars (rotated, newest at index 1).
    DUMP_HISTORY_LIMIT = 5,

    -- Min ms between auto-saves on combat exit, to avoid disk thrash.
    AUTOSAVE_COOLDOWN_MS = 30000,
  },

  TEMPORAL = {
    UPDATE_NAME          = "VerdantTemporalSample",
    SAMPLE_RATE_DEFAULT  = 1000,   -- ms interval → 1 Hz
    TIME_WINDOW_DEFAULT  = 60,     -- seconds
  },

  POOL = {
    -- Worst-case sustained ~300 events/sec in 12-man trial × 13 sec headroom.
    -- Per SPEC_03 §5.2.
    EVENT_CAPACITY = 4096,
  },

  -- VerdantEvent.kind values. Numeric ints for fast switch dispatch in
  -- pipeline/filter and pipeline/processing.
  ABILITY_KIND = {
    HEAL         = 1,
    OVERHEAL     = 2,
    SHIELD       = 3,
    DAMAGE_GROUP = 4,
  },

  -- Per-stage profiler budgets in ms. A sample exceeding the budget
  -- emits log.write("warn", "profiler.budget_exceeded", ...).
  --
  -- Values calibrated against a real DEBUG=true delve session
  -- (Phase 6 validation). Set to ~2x measured max so transient spikes
  -- don't spam; warnings should mean "something is wrong", not
  -- "normal high-end of the distribution".
  PROFILER_BUDGETS_MS = {
    ["pipeline.combat_event"]            = 5.0,   -- measured max=1
    ["pipeline.combat_event.acquisition"] = 2.0,
    ["pipeline.combat_event.filter"]     = 2.0,
    ["pipeline.combat_event.processing"] = 3.0,
    ["pipeline.render_tick"]             = 10.0,
    ["bar.refresh"]                      = 5.0,   -- measured max=1
    ["graph.sample_tick"]                = 15.0,  -- measured max=7 with full pool
  },
}
