# Attribution and modifications

JustAC 6.2.1, Copyright (C) 2024-2026 wealdly, GPL-3.0-or-later.
Source supplied by the user as rotation helper.zip; upstream https://github.com/wealdly/JustAC.

Survival.lua adapts the health zero/readback approach from BlizzardAPI/SecretValues.lua
and threshold curves from BlizzardAPI/StateHelpers.lua. It uses a limited subset of
Forever control-break mappings from Data/CCBreakers.lua and healing potion IDs/order
from Data/Forever/Consumables.lua. Modified for Tank Pilot on November 14, 2026.

Changes: standalone module without LibStub/Ace dependencies, guarded results,
readable-health preference, per-feature settings, narrow deterministic control-break
selection, potion availability checks and integration with Tank Pilot's forecast.
It is not endorsed by JustAC's author. The original observed-behavior claims do not
constitute validation of these modifications. Full GPL version 3 text is in LICENSE.

All addon Lua source is included. Tank Pilot modifications are provided under
GPL-3.0-or-later, without warranty.

0.4.1: DispelCue.lua adapts UISootheCue.lua AuraContainer/texture registration
from JustAC 6.2.1 (same copyright/license), modified for player disease/poison,
optional magic, a separate cue position and reduced setup with failure reporting.

0.6.0: ForeverData.lua adapts the registration wrapper of JustAC's generated
Data/Forever/Rotations.lua. Its complete GPL attribution, embedded MIT license,
MythicSim/wowsims credits and source commit identifiers are retained in that file.
Profiles.lua adapts the data schema, rank lookup and talent-group selection approach.
Targets.lua adapts GetEngagedEnemyCount from BlizzardAPI/StateHelpers.lua, with
protected-call guards, manual overrides, diagnostics and a delayed downgrade.
Offense.lua caches readable base cooldowns outside combat following the approach
in BlizzardAPI/CooldownTracking.lua. PriorityUpdates.lua contains Pilot-specific
adjustments; README lists the guide checks and remaining limitations.
