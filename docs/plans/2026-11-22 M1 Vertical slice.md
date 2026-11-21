---
tags: [plan, m1]
---
# M1 Vertical Slice: Design

Back to [[Status]] · Milestone: [[PRD#16. Milestones and roadmap]] · Decisions: [[decisions/2026-11-22 M1 includes the Rowboat]] · Previous: [[plans/2026-11-21 M0 Foundations]]

Status: **approved by the user, 2026-11-22**, after a builder check. Each session below gets its own brainstorm and implementation plan before any code (CLAUDE.md: one system per session).

## Why

M1 answers the PRD's most important question: are the first 10 minutes fun with one zone? (§16: "if the first 10 minutes aren't fun with one zone, more zones won't fix it.") **Gate: 5 testers enjoy the first 10 minutes, playing on PC and a phone.**

## The first 10 minutes (target experience)

1. Spawn on the Driftwood Harbor dock, next to your moored Rowboat.
2. Cast from the pier. First bite and catch within 60 seconds (§2).
3. Reel with the track-bar minigame (§4). A Perfect catch (no misses, never drained below 50%) is worth +15%.
4. The fish goes into the Rowboat's 4×3 hold, the cargo grid (§6). Drag, rotate, auto-pack.
5. Row out to harbor spots where rarer fish bite (far casts, near rocks or a wreck; §4 phase 1).
6. Come back and sell to Old Moss, the fishmonger. That's the first sale.
7. Buy bait or a better rod at the tackle shop. That's the first upgrade, within 10 minutes (§2).
8. Coins, gear and the hold are saved, and they're still there next time.

## Goals

- The loop above works end to end on PC (mouse or keyboard) and on mobile with touch only (§2: buttons at least 44×44 px, text at least 14 px).
- The server is authoritative (§14, CLAUDE.md): it rolls bite time, species and weight, checks reel results (token, minimum duration, plausible input log, rate limit), checks cargo placement with the shared CargoGrid module, prices every sale, and owns all coins and items. Clients never send prices, odds or rewards.
- Twelve Driftwood Harbor species (§5 says the zone has 12) with original names, a one-line lore text each, rarity tiers, weight ranges, base values, cargo shapes and reel difficulty. They live in `src/shared/Data/FishData.luau`.
- All tuning lives in `src/shared/Data/*` (FishData, ZoneData, RodData, BaitData, ReelTuning, EconomyConfig). No tuning is hard-coded in systems.
- Progress saves through ProfileStore (DataService): profile v1 with a `version` field and a migration hook (§14).
- Performance: 30 FPS or better on a mid-range phone from 2022 (§2), checked at the gate.

## Non-goals (M2 or later)

Night, dusk and dawn, and the panic meter; the timing-ring, tension and chained reels; mutations; aberrant fish; the bestiary screen; freshness decay; the daily market board; hull damage, boost, hazards, sinking and passengers; other zones; boats beyond the Rowboat, including buying the Skiff; quests, NPC dialogue and story; monetization and the odds panel; trading; leaderboards; events.

## Anti-goals

- Any Robux product, or anything pay-to-win.
- Any client authority over rolls, prices, coins or items.
- Anything copied from Fisch or DREDGE (names, art, layouts).

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Boat | The free Rowboat with simple piloting. The driver's client owns the boat physics, and the server checks speed and position. W/S and A/D on PC, a thumbstick on mobile. 4×3 hold. No damage, boost or hazards. | User, [[decisions/2026-11-22 M1 includes the Rowboat]] |
| Build order | Playable loop first, then deepen | User, 2026-11-22 |
| First upgrade | Bait, plus one rod upgrade, at the tackle shop | Claude's call, from §2 and the §12 tutorial ("buy bait") |
| Reel | Track bar only, including Perfect catches | PRD §16 M1, §4 |
| Reel authority | The server **replays** every reel. The track-bar physics is a shared, fixed-step, deterministic module tested with Jest; the client sends its input log (the steps where the player presses and releases), and the server reruns it with the same seed and tuning to decide catch, escape and Perfect itself. Same module, seed and steps on both sides, so no tolerance rule is needed. | CLAUDE.md ("clients never send … rewards"), §4; builder check (Claude's call) |
| Feel | M1 includes the feel the PRD requires: sound for cast, bite, hook and reel; camera shake and phone haptics on reel hits, misses and Perfect; splash, bite and Perfect effects; basic cast and reel animations; a rod model; and avatars for Old Moss and the tackle shop owner (R15 with accessories, §13). Audio comes from the Creator Store library (§13: library first), so no ElevenLabs credits in M1. | PRD §4 feel requirements, §13; builder check (Claude's call) |
| Full hold | When a new catch doesn't fit the 4×3 hold, the server keeps it pending for 30 seconds while the catch card waits. The player rearranges or throws a fish overboard (discard, §12); if there's still no room, the fish is released. In M1 only fish take hold cells; gear joins the grid with boat equipment later. | User, 2026-11-22 |
| Phone checks | After session 5 (the playable loop) and session 6 (the Rowboat), a private publish so the user can play on their own phone, which becomes the performance target. If that isn't possible, touch is checked in Studio's Device Simulator and a mobile fix-up session goes in before the gate. Each publish needs the user's go-ahead at the time. | Claude's call (user had no preference) |
| Gate pass rule | Each tester rates "Would you play again tomorrow?" from 1 to 5. The gate passes if at least 4 of the 5 answer 4 or 5. The §2 targets (first catch within 60 s, first sale and first upgrade within 10 min) are recorded per tester but don't fail the gate. Phone FPS is measured, not required (PRD §16 gates 30 FPS in M3). If the gate fails, a fix round follows before re-testing. | Claude's call (user had no preference) |
| Placeholder UI | Plain debug screens during Phase 1; every final screen is designed in Figma first, then built in React Lua | CLAUDE.md |
| Networking | Zap (`net.zap`, generated into `src/shared/Net/`); every remote checks types, range and rate | PRD §14 |
| Tests | Jest Lua for pure modules (CatchRoll, PriceCalc, CargoGrid, Shapes, SeededRng), run in Studio Edit mode | CLAUDE.md, M0 |
| Art | Fish via `art/blender/fish_gen.py` (GLB in studs, head toward −Y); a new `boat_gen.py` for `BOT_Rowboat`; dock and prop generators; uploads through the Studio MCP | M0 decisions |

## Approaches considered

- **Playable loop first (picked):** a rough end-to-end loop on the real architecture in about five sessions, then deepen it. Feel feedback arrives in the first week.
- **One finished system at a time (rejected):** fewer revisits per system, but nothing is playable end to end until around session 8, so feel problems surface late.
- **Art and world first (rejected):** good looks early, but the gate is about fun.

## Sessions (one system each)

### Phase 1: the playable loop (placeholder screens, the M0 test fish where art is needed)

1. **Harbor fish data and CatchRoll.**
   - Builds: FishData (12 species), ZoneData (Driftwood Harbor and its spots), RodData (starter rod), BaitData, a seeded RNG module (it also drives the reel's fish marker, identically on client and server), and CatchRoll, which picks bite time, species by rarity and spot conditions, and weight.
   - Tested with Jest.
   - Done when: the tests pass, and a Studio script prints 1,000 sample rolls whose rarity split matches the weights.
2. **Fishing loop.**
   - Builds: `net.zap` (cast, bite, hook, reel result); FishingService, which holds per-player state, timing, the hook window and rate limits; FishingController plus InputController on the Input Action System (hold and release to cast, press to hook; mouse or Space, or one screen button). Placeholder bobber and line.
   - Done when: in a playtest, cast, bite "!", hook, and the server logs the fish it chose.
3. **Track-bar reel.**
   - Builds: TrackBarSim, a shared fixed-step deterministic module (bar and fish-marker physics from ReelTuning adjusted by the rod, seeded), tested with Jest; MinigameController (runs the sim, placeholder overlay, records the input log); the server replays the log (live token, rate limit) and decides catch, escape and Perfect. An exact Perfect rule for a track bar is set in this session's design. It fires hit, miss and Perfect events for the feel pass.
   - Done when: the Jest tests pass, a reel is won or lost correctly, and a forged log or claimed result that the replay doesn't reproduce is rejected.
4. **Cargo grid.**
   - Builds: Shapes (polyominoes) and CargoGrid (place, rotate, remove, auto-pack), tested with Jest; CargoService, which checks placements on the server with the same module; caught fish auto-placed into the 4×3 hold (fish only); the 30-second pending catch when the hold is full, with discard; a placeholder grid screen (drag, rotate, auto-pack, discard, touch).
   - Done when: the tests pass, the hold fills up, and a catch that doesn't fit waits 30 seconds, then is released unless room is made.
5. **Selling and saving.**
   - Builds: PriceCalc (Jest; §9 formula with only the M1 factors: base value × weight factor × Perfect), EconomyService (sell all or selected at the fishmonger), DataService (ProfileStore, profile v1: coins, rods, bait, hold, catch counts), a placeholder coin display.
   - Done when: sell, coins go up, rejoin, everything is restored.
   - **Then a loop playtest with the user, who gives feel notes, including a first phone check (private publish, with the user's go-ahead).**

### Phase 2: deepen

6. **Rowboat.** `boat_gen.py` → `BOT_Rowboat` (at most 8,000 triangles, §13) and its upload. BoatService and BoatController: spawn at the dock, client-owned physics, steering, server speed and position checks, return to the dock after 5 minutes unattended (§6). Fishing from the boat; the hold belongs to the boat. Ends with the second phone check (the thumbstick and boat feel).
7. **Driftwood Harbor.** Terrain water, the dock, Old Moss's stall, the tackle shop, and 3 to 5 fishing spots (pier, open water, rocks or a wreck). A daylight Lighting preset. Props from dock and rock generators. Works with StreamingEnabled.
8. **Feel pass.** Audio from the Creator Store library (cast, bite, hook, reel hit and miss, Perfect, harbor ambience, a calm day track). Camera shake and phone haptics on reel events. Splash, bite and Perfect sparkle effects. Basic cast and reel animations. A rod model (`ROD_StarterRod`). R15 avatars with accessories for Old Moss and the tackle shop owner.
9. **The 12 fish.** Specs for all 12 species, generated with fish_gen, checked against budgets, uploaded and recorded in AssetIds. Client-side fish visuals (the held fish and the catch card render). I'll suggest running the batch with `ultracode:`.
10. **Final UI, designed in Figma first.** Style guide, HUD, cast and reel overlay, catch card, cargo grid, fishmonger and tackle shop, at 844×390 and 1920×1080, then React Lua components. The Figma read-limit question gets decided here.
11. **Tackle shop.** Buy bait (each bait targets species or raises rarer odds at the Harbor, per §9) and one rod upgrade; purchases checked on the server.
12. **Onboarding and analytics.** Light step prompts (cast, reel, sell, buy bait, row out). AnalyticsService funnel and economy events (§17: tutorial completion and so on), including each player's time to first catch, first sale and first upgrade (§2) for the gate.
13. **Tester gate.** Publish; give testers access (the place is private now); fill in the maturity questionnaire (rated 13+ today, while the PRD targets ages 10 to 17); measure performance on a mid-range phone; run 5 testers on PC and a phone with the one-question survey (Gate pass rule above), recording the §2 timings from session 12's analytics; write the playtest note.

## Constraints

- CLAUDE.md rules: server authority; data in `src/shared/Data`; Jest tests before pure logic is used; `tools/check.ps1` before every commit; a Studio playtest after each feature plus a note in `docs/playtests/`; one system per session; original names only.
- §13 budgets: fish 300 to 1,500 triangles; boat up to 8,000; props up to 2,000; shared palette atlas.
- `SmokeTestService` (M0) gets removed once session 2 shows a real catch.

## Open questions, settled in the session where they arise

- Session 1: the 12 species' names and lore lines. Claude drafts them, and the user approves them for originality and tone.
- Session 10: Figma's Starter plan allows about 20 design-reading calls a month, against "Figma first" for six or more screens. The options are rationing calls, upgrading the plan, or building some screens straight in React Lua.
- Session 13: who the 5 testers are, when they play, and on which devices.

## Left to the builder (each session's own brainstorm and plan)

Module APIs, remote shapes, profile schema details, exact tuning numbers, the species list, spot layout, and screen layouts within the Figma designs.
