Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Constants = {
  ADDON_NAME    = "Verdant",
  VERSION       = "0.1.0",
  SLASH_COMMAND = "/verdant",
  DEBUG         = true,

  SV_TABLE   = "VerdantSavedVars",
  SV_VERSION = 1,

  PROBE = {
    -- Distinct names per registration: EVENT_MANAGER keys filters by (name, eventCode).
    SRC_COMBAT_OUT = "Verdant_CombatOut",
    SRC_COMBAT_IN  = "Verdant_CombatIn",
    SRC_EFFECT     = "Verdant_Effect",
    SRC_GROUP_J    = "Verdant_GroupJoined",
    SRC_GROUP_L    = "Verdant_GroupLeft",
    SRC_GROUP_U    = "Verdant_GroupUpdate",
    SRC_PLAYER     = "Verdant_PlayerActivated",

    -- Last N events kept per category in the rolling buffer.
    BUFFER_LIMIT = 200,

    -- Min ms between chat lines while logging is ON, to avoid spam in raid.
    CHAT_INTERVAL_MS = 250,
  },
}
