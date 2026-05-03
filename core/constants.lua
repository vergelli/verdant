Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Constants = {
  ADDON_NAME    = "Verdant",
  VERSION       = "1.0.1",
  SLASH_COMMAND = "/verdant",
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
}
