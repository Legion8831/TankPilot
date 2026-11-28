# Rotation Pilot 0.8.9

- **Health-band curve fix:** Sort health-triggered actions by ascending threshold before building disjoint client color curves so lower-threshold defensives/potions are never skipped or overlapped, and guard `C_CurveUtil` / `Enum.LuaCurveType` safely.
- **Protection Paladin fixes:** Reset manual seal detection cleanly before scanning active seals, and route Holy Wrath (`2812`) through `ValidHolyTarget` while keeping Exorcism (`879`) confirmation strictly spell-specific.
- **All-class gate safety:** Fix the incomplete Warlock Destruction Agony refresh gate (`n=3` in `PriorityUpdates.lua`) and guard numeric comparisons in `Profiles.lua:compare()` against missing bounds.
- **Performance & diagnostics:** Throttle high-frequency `UNIT_AURA` and nameplate event bursts to 0.05s, expand `/rpilot why <spell>` to report mana/rage reserves and bleed immunity, and harden cross-file/secret-value guards across `Diagnostics.lua`, `DispelCue.lua`, `Targets.lua`, `Profiles.lua`, and `Offense.lua`.

# Rotation Pilot 0.8.8

Track successful seal replacements across ranks and report incoming DBM timer starts with their labels, durations and spell IDs when readable.

# Rotation Pilot 0.8.0

Install the included `ProtPilotOffense` directory over the existing addon. Open `/rpilot` for options or use the existing `/ppoff` alias. The saved-variable names are unchanged.

This release revises health priorities, overlapping and paused DBM timers, engaged target counting, target-specific utility Judgements, and channel and stance forecasts. Use `/rpilot why Exorcism` for readiness checks or `/rpilot report` for the queue and recent events. Copy reports before reloading.

# Tank Pilot 0.7.1

Now, Next, and Then display the assigned Blizzard action-button key on the icon. Empty or unbound slots show no key.

# Tank Pilot 0.7.0

Each profile keeps its learned-spell damage or tank priority. The queue recalculates on target, movement, resources, and group changes. An interrupt requires a readable interruptible cast or channel, a learned usable interrupt, and a positive range check. Personal survival and mapped boss warnings retain priority. Healing specializations provide damage suggestions and personal survival assistance. Group healing target selection is outside these profiles.

| Class and profiles | Situational behavior |
|---|---|
| Warrior: Arms, Fury, Protection | Pummel or Shield Bash when available. Arms and Fury conserve burst under group aggro. Protection can recover a loose mob without taunting another assigned tank. |
| Paladin: Holy, Retribution, Protection | Holy saves mana when assigned to heal. Ret retains damage seals. Protection can use talented Holy Shock, and Auto uses Righteousness while another assigned tank holds the target. |
| Druid: Balance, Cat, Bear, Restoration | Avoid high-mana Innervate and frontal Shred. Bear recovers loose party mobs. Restoration reserves healing mana and can suggest a stationary solo heal in caster form. |
| Hunter: Beast Mastery, Marksmanship, Survival | Bestial Wrath requires a live pet. Skip late Sting and Mark on low-health normal enemies. Survival favors the melee list when already in Raptor Strike range. Deterrence can appear under direct pressure. |
| Mage: Arcane, Fire, Frost | Counterspell readable casts. Avoid stationary channels while moving and avoid Frost Nova on a pack held by someone else. Ice Barrier can take priority at low health. |
| Priest: Discipline, Holy, Shadow | Assigned healers use the mana reserve, including in forecast slots. A wand can fill the gap. Shadow avoids long DoTs on dying normal mobs and moving Mind Flay. Learned Desperate Prayer is a personal emergency option. |
| Rogue: Assassination, Combat, Subtlety | Kick and return to the builder/finisher sequence. Stealth openers only forecast while stealth is available. Avoid Backstab when the target faces the player. Evasion can surface under pressure. |
| Shaman: Elemental, Enhancement, Restoration | Earth Shock can interrupt and reserves the shared shock cooldown in the forecast. Restoration preserves healing mana. Solo self-healing requires a readable health trigger and standing still. |
| Warlock: Affliction, Demonology, Destruction | Avoid long DoTs on dying trash, Hellfire under direct aggro, and Life Tap during group aggro. Recognized dungeon bosses can qualify for Doom. A forecast Shadow Bolt consumes Nightfall. |

The low-health trash rule uses 20% on normal/weak enemies as a heuristic. The grouped healer reserve uses the player setting (/ppoff mana, default 20%) when assigned HEALER and costs are readable. Unknown cast flags, range, or health cannot confirm a reactive action.

# Tank Pilot 0.6.7

Auto can recommend Crusader and Judgement on a recognized boss, or Justice and Judgement for a target emitting a readable English flee warning. In a group these sequences require secure threat. The forecast returns to your normal seal afterwards.

# Tank Pilot 0.6.6

Protection Paladin Auto prefers Righteousness solo and Fury in groups when learned. Use /ppoff seal auto to enable it, or select a fixed seal under AddOns > Tank Pilot.

# Tank Pilot 0.6.5

Protection Paladin prioritizes affordable Consecration on single targets and packs. Routine Holy Shield comes first on single targets. On packs, Consecration comes first. Urgent survival and Fury threat recovery retain priority. The mana reserve applies when resource information is readable.

# Tank Pilot 0.6.1

Swift Judgement has its own cooldown. In a group with Fury active, the tank profile holds it for threat recovery when ordinary Judgement is unavailable. Solo or with a damage seal it can follow normal Judgement with offensive cooldowns enabled. See TANK-ABILITIES.md for the per-ability review. Use /ppoff audit for a copyable list from your character’s learned spellbook.

# Tank Pilot 0.6.0

Replace the existing `ProtPilotOffense` folder with the folder from this ZIP, then `/reload`.
No JustAC dependency. Existing settings, display position and health options are retained.

## Options in the game menu

Open **Esc > Options > AddOns > Tank Pilot**, then **Open Tank Pilot options**.
The entry also registers in the legacy Interface > AddOns menu where available.
`/ppoff` still opens the same options window directly.

Rotation now includes automatic target mode, a per-character profile selector and an
on/off switch for offensive cooldown recommendations. Controls save immediately.
Auto profile uses the talent tree with the most points. If talent data is unavailable or
no points are spent, Warrior/Paladin/Druid retain their previous tank defaults; the other
classes use their catalog defaults. Choose a profile explicitly when leveling a DPS alt.
Feral auto selection distinguishes Bear from Cat by current form, refreshed out of combat.
Localized talent names that cannot be matched require explicit profile selection.

## Automatic single-target and AoE

Automatic mode is enabled by default on upgrade. It counts hostile nameplate units with
readable player threat, adapted from the supplied JustAC implementation. Enable enemy
nameplates with **V**. It excludes ordinary unengaged enemies and does not change CVars.
The title displays the selected profile, Single/AoE, and the observed enemy count.
Two enemies enable cleave priorities where present; three or more select area priorities.
Individual spells can require a higher threshold, such as Blizzard at four enemies.
Tank Paladin prioritizes Consecration for packs; Bear prioritizes Swipe; Warrior uses
area priorities. A short delay prevents rapid switching when nameplates disappear.

This count is an estimate of engaged enemies visible to the API, not an exact proximity
or hit-target measurement. Hidden nameplates or restricted threat can undercount. Unknown
counts fall back to single target, and the report labels limited visibility. The same
spell can still be best in both modes, especially on a low-level character.

Overrides: `/ppoff auto`, `/ppoff single`, `/ppoff aoe`. Forced AoE assumes four targets.
`/ppoff status` and `/ppoff report` include the active profile and target-count source.

## Class coverage

| Class | Tank / damage profiles |
| --- | --- |
| Warrior | Protection, Arms, Fury |
| Paladin | Protection, Retribution, Holy damage |
| Druid | Bear, Feral Cat, Balance, Restoration damage |
| Hunter | Beast Mastery, Marksmanship, Survival |
| Mage | Arcane, Fire, Frost |
| Priest | Shadow, Discipline damage, Holy damage |
| Rogue | Assassination, Combat, Subtlety |
| Shaman | Elemental, Enhancement, Restoration damage |
| Warlock | Affliction, Demonology, Destruction |

The three existing tank engines retain their health/potion/self-heal/DBM/dispel features.
New DPS profiles use the supplied Forever priority catalog, with targeted current-guide
corrections and added burst recommendations. All classes share potion and recognized
racial/control-break checks; this is not comprehensive defensive planning for every DPS
class. Healer-tree entries are damage priorities only, not healing rotations.

Learned ranks, readable resource costs, cooldowns, combo points, forms, buffs/debuffs,
conditions and target count determine recommendations. Offensive cooldowns can be disabled
in Rotation or `/ppoff cooldowns off`; turn them back on with `/ppoff cooldowns on`.
Tank profiles do not inherit DPS Fury-seal or dangerous damage-cooldown behavior.
Base cooldowns are cached outside combat instead of treating secret cooldowns as zero.

## What has and has not been validated

The expanded DPS profiles are a **test build**, not a claim of optimal DPS for every build.
Local Lua tests passed for all 28 profile entries, existing tank regressions, higher spell
ranks, Fury ordering, cooldown toggle/forecast deduplication, DPS Paladin seal separation,
automatic AoE transitions, secret-value handling, and native settings registration.
Those tests do not substitute for running each class/spec in the real client.

NEXT and THEN remain conditional forecasts. Unreadable proc stacks and unsupported swing
conditions are skipped; future procs or resource income are not invented. Advanced
Retribution Echo seal swapping, Hunter hawk/swing synchronization, multi-target DoT
assignment, channel clipping, dynamic time-to-die optimization, consumable burst stacking
and trinket alignment remain manual. A restricted required condition can suppress a spell.
Source data includes endgame build assumptions; leveling fallbacks cover basic learned
attacks. Character talent/gear combinations can need further tuning.

Check this build during normal play: find the menu entry, confirm the intended profile,
then compare the displayed count and NOW action on one enemy versus a small pack. If
something is wrong, copy `/ppoff report` before reloading. No deliberate low-health test
or new Probe capture is required.

## Sources and modifications (November 14, 2026)

- Supplied JustAC 6.2.1: `Data/Forever/Rotations.lua`, `Data/Forever/Defaults.lua`,
  `BlizzardAPI/StateHelpers.lua`, and its out-of-combat cooldown caching approach.
- The catalog attributes MIT-licensed MythicSim Forever presets and preserves its exact
  source commit IDs and license notices in `ForeverData.lua`:
  https://github.com/sage3648/mythicsim-forever-engine
- Current rotation checks and targeted corrections:
  https://www.icy-veins.com/wow-forever/fury-warrior-melee-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/retribution-paladin-melee-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/elemental-shaman-ranged-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/fire-mage-ranged-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/beast-mastery-hunter-ranged-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/combat-rogue-melee-dps-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/affliction-warlock-ranged-dps-pve-rotation-cooldowns-abilities

All casts and item uses remain manual. No input automation or external screen reader.

---

## Historical release notes

# Tank Pilot 0.5.0

Replace the ProtPilotOffense folder, then /reload. Open settings with `/ppoff options`
or just `/ppoff`. No external UI library required. Existing settings and position remain.

## Settings window

- Display: Automatic / Always / Only in combat; saved position lock; 60-160% scale;
  toggle action names, reason text and class/mode title. Reset position and size,
  and open the copyable diagnostic report. Uncheck Lock to drag the helper itself.
  When unlocked it remains visible for positioning; lock again to apply normal visibility.
- Survival: health recommendations, bag potions, solo Paladin heals, control breaks,
  dispel cue, mapped DBM warnings, experimental health decisions, and potion/self-heal
  thresholds. Disabling health recommendations also disables potions and self-heals.
- Rotation: single/AoE mode, Paladin seal/aura/blessing selection, bleed recommendations.
  Click a selection button to cycle its choices. Only learned abilities are recommended.

Changes apply and save immediately. Close with X or Escape. Settings are currently shared
across characters using the existing addon database. Class-specific choices apply only to
that class. Individual defensive thresholds and boss mappings retain their slash commands.

## Display

NOW is the next recommended action. NEXT and THEN are conditional forecasts.
DISPEL marks the separate Blizzard-driven dispel cue and is not a fourth forecast action.
Its heading can remain visible when there is nothing to dispel; only the spell icon signals
a qualifying aura. Scaling applies to the entire helper, including its dispel cue.
The unlock hint appears below the explanation without covering action names.

Additional commands: `/ppoff scale 100`, `/ppoff resetposition`, `/ppoff move`, `/ppoff lock`.
Reset position/size does not reset your rotation or survival preferences.

## Validation

Local mocked Lua tests passed for opening/reusing the options window, checkbox/slider
callbacks, scale bounds, saved settings updates, position reset, and existing tank
rotation/survival/dispel behavior. Actual WoW rendering and dragging need in-game checking.
The tested survival selection logic is unchanged in this build.

Quick check: open settings, unlock and move the helper, adjust size, lock it again,
then /reload to confirm size and position persist. Play normally afterward; no repeated
low-health or disease capture is required. Use /ppoff report if a recommendation misbehaves.

---

# Tank Pilot 0.4.1

Replace ProtPilotOffense, then /reload. No Probe update or JustAC installation required.

## Changes and focused test

- Self-healing movement checks now prefer a readable IsPlayerMoving result, then readable
  speed, then observed PLAYER_STARTED_MOVING/PLAYER_STOPPED_MOVING events. Unknown is
  still not treated as stationary. These alternate signals need live Forever validation.
- Experimental Purify/Cleanse cue beside the three-action queue. An AuraContainer draws
  the spell icon only for player-dispellable harmful auras with disease/poison types
  (also magic for Cleanse). It is armed only in combat while the spell is usable/ready,
  and hidden while an urgent survival action occupies the queue. Up to 40 auras are scanned.
  This is a visual test, not an aura readback or a simulated dispel action. It does not
  identify dangerous debuffs, dispel penalties, or rearrange the following attacks.
- /ppoff report opens a copyable report with the last 200 state/action changes and the
  actual harmful-aura query error. Diagnostics query once per combat-state transition,
  not every update. Captures survive until reload/logout only.
- /ppoff dispelcue off disables the display test; /ppoff dispelcue on enables it.

Next test: fight normally, observe whether the Purify icon appears to the RIGHT of the
three-action queue when poisoned/diseased and clears after Purify. Copy /ppoff report
before reloading. If a healing opportunity happens naturally, check whether the self-heal
prompt appears while stopped and clears while moving. No low-health test is required.

Local tests cover movement unknown/moving/stopped paths, exact dispel filter/curves,
container failure, creation deduplication, and existing rotation/survival regressions.
They cannot verify Blizzard's protected widget rendering. 'registered' in the report
means setup calls succeeded, not that a disease was detected or the cue appeared.

---

# Tank Pilot 0.4.0

Replace the ProtPilotOffense folder, then /reload. JustAC is not required.
All actions remain manual recommendations. Your previous settings are retained.

## New survival recommendations

- Control breaks precede damage, even without a hostile target. This version matches
  Human Will to Survive to stun; Will of the Forsaken to fear/sleep/charm;
  Berserker Rage to fear; Escape Artist or Blessing of Freedom to root.
  Requires a readable matching control effect and a discovered, usable, ready spell.
  No form-cancel recommendation is made for bear tanks.
- Carried, usable healing potions enter the first slot below 30% health.
  Selects the first ready item in a curated strongest-first Forever potion list;
  this is not an exhaustive item catalog. Shared cooldowns use the item's actual cooldown.
- Health-dependent defensives now enter the queue when a health comparison is available.
  Paladin Lay on Hands takes priority over mitigation at its 20% threshold.
  Divine Protection remains solo-only because of its tanking consequences.
- Paladin Flash of Light, otherwise Holy Light, is offered below 45% health while
  solo, stationary, and not already casting, when learned and usable. Cast-time healing
  can still suffer pushback while being attacked: this is not a safe-cast prediction.
- Later slots assume the first action succeeds. We do not simulate healing amounts,
  future health, or the removal of every concurrent control effect.

## Health decisions

Readable health can change all three recommendations. When health is restricted, the client renders the appropriate survival icon over Now. Next, Then, and the report continue to describe the underlying queue. A visual cue can therefore differ from the report. At the default thresholds a ready Lay on Hands wins below 20%, followed by a carried usable potion below 30%. Settings, cooldowns, group state and available spells determine the remaining bands.

## Controls

```
/ppoff potions on
/ppoff breaks on
/ppoff selfheal on
/ppoff threshold potion 30
/ppoff threshold selfheal 45
/ppoff visibility always
/ppoff visibility combat
/ppoff visibility auto
/ppoff move
/ppoff lock
/ppoff status
```

The four feature switches also accept `off`. `health off` disables all health-triggered
recommendations; control breaks have their own switch. Visibility auto retains prior behavior.

## Validation and limits

Mock tests cover existing offense forecasts/DBM/buff caching and the new control-break,
no-target, potion cooldown, low-health defensive, solo healing, movement/group restrictions,
visibility and experimental-readback failure paths. Actual Forever runtime validation is
still required. Use normal fights; do not intentionally put your character in danger.

Purify/Cleanse recommendations, elixir preparation, aura-container displays and a graphical
options panel are NOT included in 0.4.0. Keep Probe 0.1.3 for debuff evidence.

## Attribution

Tank Pilot 0.4.0 is distributed under GPL-3.0-or-later; see LICENSE and THIRD_PARTY.md.

---

Previous feature documentation follows (version-specific descriptions may describe earlier behavior).

# Tank Pilot 0.3.4 — WoW Forever

Install the ProtPilotOffense folder in Forever's Interface/AddOns, replacing the
previous folder. Restart the client or /reload. No probe addon is required.

The large icon is the current recommendation. The smaller two are conditional
forecasts after assumed successful casts. You cast every ability yourself.
Health defenses are enabled automatically. Settings and position survive reloads.
The default tank seal mode is auto: learned Fury, otherwise Righteousness.

## Buff handling fix in 0.3.1

Readable player buffs are snapshotted outside combat. Known active buffs with a
readable expiration (or zero for permanent effects) remain recognized when combat
restricts their aura data. The snapshot is refreshed whenever readings are
available. Unknown combat data cannot prove a buff was dispelled.
Successful casts invalidate old cached data for that spell.

Auto aura/blessing choices respect an already-active learned option.
Helpful aura name lookup handles a different rank on the player.
An empty combat rotation no longer falls through into out-of-combat buff setup.

## What changed

- Removed the level-10 seal/Judgement cutoff.
- Updated Warrior, Paladin, and Bear priorities from current Forever guides.
- Forecasts advance readable resource costs, cooldowns, upkeep, and Sunder stacks.
  Repeatable fillers can occupy successive slots. Reactive Revenge is not assumed
  to proc again. No resource regeneration is assumed.
- Shield Block is inline when the target is attacking you. Sunder is independent
  of queued Heroic Strike/Cleave. Thunder Clap works in either mode.
- Rage dumps reserve resources. Consecration preserves a configurable mana reserve
  when costs and resource totals are readable.
- Learned tank stance/form prompts and out-of-combat self-buff upkeep.
- Righteous Fury upkeep, configurable seal, aura, and blessing choices. Casting a seal does not change the configured seal policy.
- Automatic class health prompts, cooldown gating, and active-cooldown suppression.
- DBM demo countdown and explicit real-spell mappings with stop/update/pause/resume.
- Saved manual bleed-immunity exclusions remain supported.

## Priorities

Warrior uses buff/mitigation upkeep, Shield Slam and reactive Revenge, armor
reduction building, Thunder Clap, missing Rend, Sunder filler, and surplus-Rage
swing attacks. AoE leads with Thunder Clap and uses Cleave instead of Heroic
Strike. Taunt can appear when readable threat reports that the target is not
securely attacking you. Shield Block requires the target to be attacking you.

Paladin maintains Righteous Fury and the selected seal. Holy Shield receives
mitigation priority, followed by affordable Consecration, Judgement, and Holy
Strike. Exorcism is limited to readable Undead/Demon targets. Fury's Judgement
explicitly includes its taunt. This is an active-tank profile. Choose another seal
or manual seal mode when off-tanking. Immunities are excluded from group
defensive suggestions because of their impact on tanking and attacking.

Bear maintains armor/attack-power debuffs, uses Primal Bite before fillers,
refreshes an expiring readable Lacerate, and uses Lacerate/Swipe according to
target mode. Maul requires surplus readable Rage. Mark and Thorns reminders
appear outside combat when castable. This profile never asks you to leave Bear
Form to cast a heal during combat.

## Controls

- /ppoff single or /ppoff aoe — explicit target mode.
- /ppoff move or /ppoff lock — drag the frame and save its position.
- /ppoff seal righteousness|fury|auto|manual — auto prefers learned Fury.
- /ppoff aura auto|devotion|retribution|manual — auto prefers Retribution.
- /ppoff blessing auto|kings|might|manual — auto prefers Kings.
- /ppoff reserve 30 — Warrior Rage kept after a swing dump.
- /ppoff mana 20 — Paladin mana reserve percentage after Consecration.
- /ppoff health on|off — automatic emergency display.
- /ppoff threshold protection 35 — example per-defensive health threshold.
- /ppoff status — build, settings, discovered abilities, usability, cooldown access.
- /ppoff bleed immune|clear — mark/clear the targeted creature's bleed immunity.
- /ppoff bleed on|off — enable/disable bleed recommendations, including Lacerate.

Bear Maul requires the cost plus 35 Rage reserved in single target or 50 in AoE.
These conservative implementation defaults can leave Rage unused in low-damage
pulls while protecting Primal Bite.

## Default health thresholds

The first ready eligible defensive is selected. Its icon is revealed by a
health curve. When that ability is unavailable, the next eligible rule applies.

- Warrior — Last Stand below 40%, then Shield Wall below 25%.
- Paladin — Templar's Bulwark below 40%, Lay on Hands below 20%, Divine Protection
  below 35% while solo. Lay on Hands is a SELF-heal recommendation.
- Druid — Barkskin below 50%, then Frenzied Regeneration below 35%.

These percentages are product defaults, not guide claims. Adjust them with
/ppoff threshold FAMILY PERCENT. Families are shown by /ppoff status.
Active readable defensive auras or a recent successful defensive cast suppress
further major cooldown prompts. Cast-duration fallbacks are approximate.
The two small offensive forecasts remain conditional while a secret-health
overlay is displayed. Health cannot be read back to re-simulate the queue.

## DBM test

1. Run /ppoff demo on.
2. Run DBM's built-in test counters/bars.
3. With two seconds left on its English "Tank Buster" demo bar, a learned,
   ready defensive should take slot one even outside combat.
4. Run /ppoff demo off when finished.

The demo uses the exact label observed in James's report, including support for
trailing spaces. It does not need a hostile target or low health.
On a level-10 Paladin, the explicit demo uses Divine Protection.

Real fights require /ppoff bossmap SPELLID physical|magic|any, after verifying
what the DBM timer represents. Remove with /ppoff bossmap SPELLID clear.
Use /ppoff boss on|off for all mapped encounter prompts.
No real boss is pre-mapped in this release. The demo capture did not establish a
real boss spell ID, targeting, damage type, or advance warning.
A countdown is a prediction and can drift. Stop/update/pause/resume callbacks
adjust recommendations. Magic-only mappings do not suggest Shield Block or
Bear Barkskin. DBM must provide an advance timer for preemptive timing.

## API and forecast limits

Spellbook discovery chooses learned localized spell families and ranks.
Current usability must be readable; unavailable/secret availability is unknown.
Cooldown flags may be readable even when timings are secret. Slots two and
three use readable cooldowns or documented base-cooldown estimates and update
every 0.1 seconds. They cannot guarantee future rage, mana, procs, misses,
immunity, movement, resets, or the next boss target. No automatic target switch
or automatic enemy counting is performed.

When aura reads are restricted, successful casts supply upkeep timers.
Timers do not prove a debuff landed, survived a dispel, or was refreshed by
another effect. Unknown dump resources suppress swing dumps rather than spend
unverifiable reserves. Unknown mana totals cannot enforce the percentage reserve.
Readable valid buffs supplied by others are respected. No spell-immunity
database is inferred from creature type. Only manual bleed exclusions are used.

This build covers the three Forever tanks. Potions, raid-assigned blessings,
off-tank rotations, automatic interrupt selection, and arbitrary boss mechanics
are not implemented. There is no claim of simulated maximum theoretical DPS.
Local tests cover all profiles and secret-state handling. Live validation of
new Warrior/Bear rules, forms, group cooldowns, and real encounter mappings is
still required.

## Rotation research

Reviewed November 11, 2026. The priority choices above adapt these guides to
the state the client exposes. Warrior main-attack reserves and Bear Maul
thresholds come from these authors; mitigation-first ordering and conservative
resource reserves are implementation choices.

- Icy Veins Protection Warrior rotation (updated November 4)
  https://www.icy-veins.com/wow-forever/protection-warrior-tank-pve-rotation-cooldowns-abilities
- Icy Veins Protection Paladin rotation and leveling (updated November 4)
  https://www.icy-veins.com/wow-forever/protection-paladin-tank-pve-rotation-cooldowns-abilities
  https://www.icy-veins.com/wow-forever/protection-paladin-leveling
- Icy Veins Bear rotation (updated November 4)
  https://www.icy-veins.com/wow-forever/feral-druid-melee-dps-and-tank-pve-rotation-cooldowns-abilities
- Wowhead Feral tank rotation (updated November 9)
  https://www.wowhead.com/forever/guide/classes/druid/feral/rotation-cooldowns-pve-tank
- DBM timer callback documentation and current WeakAuras integration reference
  https://github.com/DeadlyBossMods/DeadlyBossMods/wiki/%5BInfo%5D-DBM-Events
  https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/BossMods.lua

## Cooldown forecast correction in 0.3.3

The forecast advances through known cooldown gaps instead of stopping at Wait.
Future actions carry an approximate seconds label. When cooldown timing is
secret, a successful observed cast and its base/observed cooldown can supply
an estimate. An unreadable cooldown with no observed cast remains unknown.
Among ready actions, tank priority still determines selection.

## Seal policy correction in 0.3.4

The upgrade changes the old default Righteousness selection to tank auto mode
once. Auto prefers learned Fury, with Righteousness as a leveling fallback.
Casting Righteousness no longer silently disables auto mode. Explicit manual
or Fury settings are retained. After upgrading, /ppoff seal righteousness can
still lock that seal if desired.

When Exorcism works on a mob whose creature type is unreadable, the addon can
remember a successful cast if the cast destination matches the current target
and the cast identifier stays readable. You can also target that mob and use
`/ppoff exorcism allow`, or undo the confirmation with `/ppoff exorcism clear`.
A readable NPC ID lets the confirmation apply to later mobs with that same ID.
Otherwise it expires when you change targets. Check the snapshot with
`/ppoff exorcism`.

### Learning Exorcism targets

Use this macro in place of your usual Exorcism button.

```
#showtooltip Exorcism
/ppoff exorcism learn
/cast [@target,harm,nodead] Exorcism
```

The addon waits for a successful Exorcism before confirming the selected target. A target change clears the current confirmation. When the NPC ID and the restricted-target spell rules are readable, the confirmation also applies to future encounters with that NPC ID.
