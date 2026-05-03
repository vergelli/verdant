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
