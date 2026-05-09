-- ZOS UI surface used by Verdant: WINDOW_MANAGER, ZO_ObjectPool factory,
-- CreateControlFromVirtual, sound playback. Per SPEC_01 §6/§7.1, exposed
-- by-value where the symbol is a function or singleton; WINDOW_MANAGER is
-- forwarded as the manager handle so callers can use the full :CreateControl
-- / :GetControlByName surface without wrapping every method.

Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.ui = {}
local M = Verdant.zenimax.ui

-- ── managers / factories ──────────────────────────────────────────────────
M.WINDOW_MANAGER          = WINDOW_MANAGER
M.ZO_ObjectPool           = ZO_ObjectPool
M.CreateControlFromVirtual = CreateControlFromVirtual

-- ── sound ─────────────────────────────────────────────────────────────────
M.PlaySound = PlaySound
