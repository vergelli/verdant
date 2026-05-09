Verdant = Verdant or {}

-- Keybinding label shown in ESO Controls settings
ZO_CreateStringId("SI_BINDING_NAME_VERDANT_TOGGLE", "Toggle Verdant Bar")

-- Debug / status strings
ZO_CreateStringId("VERDANT_PROBE_ON",       "Probe ON. Logging events to chat (rate-limited).")
ZO_CreateStringId("VERDANT_PROBE_OFF",      "Probe OFF. Buffers keep filling silently.")
ZO_CreateStringId("VERDANT_BUFFER_CLEARED", "Probe buffers cleared.")
ZO_CreateStringId("VERDANT_FILTER_SET",     "Chat filter set to: %s")
ZO_CreateStringId("VERDANT_FILTER_UNKNOWN", "Unknown filter '%s'. Use: heal | shield | damage | effect | group | all")
ZO_CreateStringId("VERDANT_DUMP_HEADER",    "=== Verdant probe dump ===")
ZO_CreateStringId("VERDANT_DUMP_EMPTY",     "Probe buffers are empty.")
ZO_CreateStringId("VERDANT_DUMP_SAVED",     "Buffers snapshotted to SavedVars.")
ZO_CreateStringId("VERDANT_READOUT_LINE",   "[%s] eHPS=%d MPS=%d EMS=%d | %s=%d | C=%.2f (h=%.2f s=%.2f)")
ZO_CreateStringId("VERDANT_METRIC_SET",     "Active metric: %s")
ZO_CreateStringId("VERDANT_METRIC_UNKNOWN", "Unknown metric '%s'. Use: EMS | eHPS_only | MPS_only | eff_ratio")
ZO_CreateStringId("VERDANT_BAR_SHOWN",      "Bar shown.")
ZO_CreateStringId("VERDANT_BAR_HIDDEN",     "Bar hidden.")
ZO_CreateStringId("VERDANT_LOADED",         "Verdant v%s loaded. Type %s to toggle.")

-- Settings panel
ZO_CreateStringId("VERDANT_SETTINGS_TITLE",          "Verdant Settings")
ZO_CreateStringId("VERDANT_SETTINGS_PROFILE",        "Profile")
ZO_CreateStringId("VERDANT_SETTINGS_RESET",          "Reset to Defaults")
ZO_CreateStringId("VERDANT_SETTING_REFRESH_RATE",    "Refresh Rate")
ZO_CreateStringId("VERDANT_SETTING_HEAL_WINDOW",     "Heal Window")
ZO_CreateStringId("VERDANT_SETTING_SHIELD_WINDOW",   "Shield Window")
ZO_CreateStringId("VERDANT_SETTING_SAMPLE_RATE",     "Sampling Rate")
ZO_CreateStringId("VERDANT_SETTING_TIME_WINDOW",     "Time Window")
ZO_CreateStringId("VERDANT_SETTING_VIEWPORT_ALPHA",  "Viewport Alpha")

-- Profile preset names
ZO_CreateStringId("VERDANT_PROFILE_SOLO",            "Solo PvE")
ZO_CreateStringId("VERDANT_PROFILE_DUNGEONS",        "Group Dungeons")
ZO_CreateStringId("VERDANT_PROFILE_TRIALS",          "Trials")
ZO_CreateStringId("VERDANT_PROFILE_PVP",             "PvP")
ZO_CreateStringId("VERDANT_PROFILE_CUSTOM",          "Custom")

-- Help command output
ZO_CreateStringId("VERDANT_HELP_HEADER",  "Verdant commands:")
ZO_CreateStringId("VERDANT_HELP_TOGGLE",  "  /verdant         toggle the bar window")
ZO_CreateStringId("VERDANT_HELP_GRAPH",   "  /verdant graph   toggle the temporal analytics window")
ZO_CreateStringId("VERDANT_HELP_HELP",    "  /verdant help    show this list")

-- Graph window
ZO_CreateStringId("VERDANT_GRAPH_TITLE",          "Temporal Analytics")
ZO_CreateStringId("VERDANT_GRAPH_RECORD",         "Record")
ZO_CreateStringId("VERDANT_GRAPH_STOP",           "Stop")
ZO_CreateStringId("VERDANT_GRAPH_FLUSH",          "Flush")
ZO_CreateStringId("VERDANT_GRAPH_NO_DATA",        "No data — press Record during combat.")
