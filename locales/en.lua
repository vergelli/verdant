Verdant = Verdant or {}
local Verdant = Verdant

Verdant.L = {
  PROBE_ON       = "Probe ON. Logging events to chat (rate-limited).",
  PROBE_OFF      = "Probe OFF. Buffers keep filling silently.",
  BUFFER_CLEARED = "Probe buffers cleared.",
  FILTER_SET     = "Chat filter set to: %s",
  FILTER_UNKNOWN = "Unknown filter '%s'. Use: heal | shield | damage | effect | group | all",
  DUMP_HEADER    = "=== Verdant probe dump ===",
  DUMP_EMPTY     = "Probe buffers are empty.",
  DUMP_SAVED     = "Buffers snapshotted to SavedVars.",
  HELP_HEADER    = "Verdant probe commands:",
  HELP_LINES     = {
    "  /verdant on            - start chat logging",
    "  /verdant off           - stop chat logging (buffers keep filling)",
    "  /verdant filter <name> - heal|shield|shield_raw|heal_abs|damage|effect|effect_self|cast|combat|group|all",
    "  /verdant stats         - print event counters",
    "  /verdant context       - print session context (player/zone/bars)",
    "  /verdant ping          - print 'alive' marker with delta counts",
    "  /verdant tag <name>    - label this session (saved into the snapshot)",
    "  /verdant dump          - print rolling buffers to chat",
    "  /verdant save          - append snapshot to SavedVars dumps[]",
    "  /verdant clear         - clear rolling buffers and counters",
    "  /verdant help          - show this help",
  },
  LOADED         = "Verdant v%s loaded (Phase 0 probe). Type %s help for commands.",
}
