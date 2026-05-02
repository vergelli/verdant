Verdant = Verdant or {}
local Verdant = Verdant

-- Keybinding label shown in ESO Controls settings
ZO_CreateStringId("SI_BINDING_NAME_VERDANT_TOGGLE", "Toggle Verdant Bar")

Verdant.L = {
  PROBE_ON       = "Probe ON. Logging events to chat (rate-limited).",
  PROBE_OFF      = "Probe OFF. Buffers keep filling silently.",
  BUFFER_CLEARED = "Probe buffers cleared.",
  FILTER_SET     = "Chat filter set to: %s",
  FILTER_UNKNOWN = "Unknown filter '%s'. Use: heal | shield | damage | effect | group | all",
  DUMP_HEADER    = "=== Verdant probe dump ===",
  DUMP_EMPTY     = "Probe buffers are empty.",
  DUMP_SAVED     = "Buffers snapshotted to SavedVars.",
  READOUT_LINE   = "[%s] eHPS=%d MPS=%d EMS=%d | %s=%d | C=%.2f (h=%.2f s=%.2f)",
  METRIC_SET     = "Active metric: %s",
  METRIC_UNKNOWN = "Unknown metric '%s'. Use: EMS | eHPS_only | MPS_only | eff_ratio",
  BAR_SHOWN      = "Bar shown.",
  BAR_HIDDEN     = "Bar hidden.",
  LOADED         = "Verdant v%s loaded. Type %s help for commands.",
}
