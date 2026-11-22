---
tags: [plan, m1]
---
# M1 Session 3: Track-Bar Reel Implementation Plan

Back to [[Status]] · Milestone design: [[plans/2026-11-22 M1 Vertical slice]] · Previous: [[plans/2026-11-22 M1 S2 Fishing loop]]

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A hooked fish opens a track-bar reel. The client plays it, and the server replays the client's input to decide caught, escaped and Perfect.

**Architecture:** `TrackBarSim` is a shared, pure, fixed-step simulation (60 ticks a second). It uses only arithmetic and a seeded `Random`, so a replay is exact.
- The server picks a seed and the fish's reel tuning at the cast, and sends both with the bite.
- The client runs the sim on the Fish action and records the ticks at which the hold state flips.
- `FishingState` gains a Reeling phase. Its `reel()` replays those ticks and rejects claims that don't match, or results that arrive too soon.

**Tech Stack:** Luau `--!strict`, Zap 0.6.29, the Input Action System (`InputAction:GetState()`), Jest Lua (Studio Edit mode).

**Spec:** the session 3 design the user approved on 2026-11-22 (session log), the session 3 row of [[plans/2026-11-22 M1 Vertical slice]], PRD §4 (reel, rod stats, Perfect) and §14 (catch flow), and [[decisions/2026-11-22 Track-bar Perfect - keep the fish in the bar]].

## Global Constraints

- The server decides caught, escaped and Perfect from its own replay. The client sends only the token, the toggle ticks and its claimed outcome.
- `src/shared/Data/ReelTuning.luau`:
  - `tickRate = 60`, `maxSeconds = 90`, `startProgress = 0.3`;
  - `settleSeconds = 1`, `missGraceSeconds = 0.25`;
  - bar physics: `rise = 3` and `fall = 3` (track lengths per s²), `maxBarSpeed = 1.2`;
  - bar size: `barSizeBase = 0.18`, `barSizePerControl = 0.004`;
  - `easy` (difficulty 1) = `{ fishSpeed = 0.25, moveInterval = 1.6, gainRate = 0.14, drainRate = 0.10 }`;
  - `hard` (difficulty 10) = `{ fishSpeed = 0.75, moveInterval = 0.6, gainRate = 0.10, drainRate = 0.14 }`;
  - values in between are linear in `(difficulty - 1) / 9`.
- Rod: `barSize = barSizeBase + control × barSizePerControl`; `gainRate × (1 + reelSpeed / 100)`; `drainRate × (1 - resilience / 200)`.
- `FishingTuning.reelGrace = 5`: a reel with no result after `maxSeconds + reelGrace` escapes.
- `TrackBarSim` uses only `+ - * /`, comparisons, `math.min`, `math.max`, `math.clamp` and `Random`. No trig or other library maths.
- Perfect: caught with zero misses. A miss is the fish outside the bar for more than 0.25 s in a row (16 ticks), counted only from tick 60 (after the 1 s settle-in). One stretch outside counts as one miss.
- The overlay is a plain placeholder until session 10, and it uses the same Fish input (Space, mouse, 96 px button).
- `tools/check.ps1` passes and Jest runs in Edit mode before every commit.

## Review Focus

1. **A client that hitches mid-reel.** Its accumulator catches up with the same input, and an honest reel never reaches the server faster than its ticks allow, so the elapsed-time check must not reject it.
2. **A hook the server judges late.** The client has already opened the reel; FishResult Missed closes it, and a ReelResult that follows is Rejected silently.
3. **A player who leaves or respawns mid-reel.** Leaving drops their state. Otherwise the reel escapes after 95 s with no result.
4. **A toggle log that would pass 1000 entries.** Zap caps it, so the client stops at 999 toggles and sends what it has. The replay then disagrees and the fish escapes; the client must never hang.
5. **A miss in the last ticks before the catch.** It still costs the Perfect.

---

### Task 1: ReelTuning and TrackBarSim (pure, test first)

**Files:**
- Create `src/shared/Data/ReelTuning.luau` and `src/shared/Modules/TrackBarSim.luau`.
- Create `tests/ReelBot.luau` (a test helper, not a spec) and `tests/TrackBarSim.spec.luau`.

**Interfaces (produces):**
- `export type Tuning = { barSize, fishSpeed, moveInterval, gainRate, drainRate }`; `Outcome = "Caught" | "Escaped"`; `Event = Outcome | "Hit" | "Miss"`.
- `export type Result = { outcome: Outcome, ticks: number, misses: number, perfect: boolean }`.
- `TrackBarSim.tuning(difficulty: number, rod: RodData.Rod): Tuning`.
- `TrackBarSim.new(tuning: Tuning, seed: number): Sim`. Readable fields: `tick`, `barPos` (bottom edge, 0 to `1 - barSize`), `fishPos` (0 to 1), `progress`, `misses`, `outcome`.
- `TrackBarSim.step(sim, holding: boolean): Event?`. Order within a tick:
  1. move the fish;
  2. move the bar;
  3. check overlap (`barPos <= fishPos <= barPos + barSize`);
  4. update progress;
  5. count hits and misses;
  6. `tick += 1`;
  7. decide the outcome: full progress is Caught, empty progress or `tick >= maxSeconds × tickRate` is Escaped.
  It returns the outcome, else "Miss", else "Hit" (the fish entering the bar).
- `TrackBarSim.replay(tuning, seed, toggles: { number }): Result?`. Toggles are tick indices at which the hold flips, starting released. It returns nil unless the toggles strictly increase, start at 0 or later, and all come before the final tick.
- Fish: starts at 0.5. Every `moveInterval × (0.5 + rng:NextNumber())` seconds it picks `target = rng:NextNumber()`, and it moves toward the target at `fishSpeed`.
- Bar: starts at 0 with no speed. Each tick it accelerates up (`rise`) while held and down (`fall`) otherwise, with speed clamped to ±`maxBarSpeed`. At either end of the track it stops and its speed drops to 0.
- `tests/ReelBot.luau`: `play(tuning, seed): ({ number }, Result)`. It holds while the bar's middle is below the fish and records toggles, as a live client would.

- [ ] **Write `tests/TrackBarSim.spec.luau`.** The specs use a still fish (`fishSpeed = 0`, so it stays at 0.5) where they need control:
  - "makes harder fish faster, jumpier and slower to land":
    - `tuning(1, Driftwood)` equals `{ barSize = 0.22, fishSpeed = 0.25, moveInterval = 1.6, gainRate = 0.154, drainRate = 0.10 }` (each value checked with `toBeCloseTo`);
    - `tuning(10, Brassline)` equals `{ 0.26, 0.75, 0.6, 0.115, 0.133 }` in the same field order.
  - "lifts the bar while held, lets it fall when released, and keeps it on the track": after 300 held ticks `barPos == 1 - barSize`; after 300 released ticks `barPos == 0`.
  - "moves the fish by its seed only": two sims with seed 7 and the same inputs give equal `fishPos` for 600 ticks, and every `fishPos` lies in [0, 1]. A sim with seed 8 differs.
  - "fills progress while the fish is in the bar and drains it outside":
    - with `barSize = 1`, after 60 ticks progress is about `0.3 + gainRate`;
    - with `barSize = 0.2` and no input, after 60 ticks progress is about `0.3 - drainRate`.
  - "lands the fish at full progress and loses it at empty": `barSize = 1` returns "Caught"; the bar left at the bottom under a still fish returns "Escaped".
  - "counts a miss only after the settle-in and the grace, once per stretch": with a still fish, a bar at the bottom and `drainRate = 0.01`:
    - 0 misses after 75 ticks, 1 after 76, still 1 after 300;
    - holding until the bar reaches the fish gives "Hit";
    - releasing until the fish is outside again for 16 ticks gives misses == 2.
  - "escapes after 90 seconds": with `gainRate = 0` and `drainRate = 0`, the outcome is "Escaped" at tick 5400.
  - "replays a live run exactly": `ReelBot.play` with seed 11 on `tuning(3, Driftwood)`; `replay` gives the same outcome, ticks and misses.
  - "marks a caught reel with no misses Perfect": `barSize = 1` gives `perfect == true`; a run with a miss gives `perfect == false`.
  - "refuses toggles that don't strictly increase or run past the end": `{5, 5}`, `{10, 3}`, `{-1}` and a toggle after the final tick all give nil.
- [ ] Run Jest. Expected: FAIL (`TrackBarSim is not a valid member`).
- [ ] Implement `ReelTuning` and `TrackBarSim`. Run Jest. Expected: all pass. Commit "M1 S3 task 1: TrackBarSim and ReelTuning (tested)".

### Task 2: Reel phase, remotes and the server replay

**Files:**
- Modify `src/shared/Modules/FishingState.luau`, `tests/FishingState.spec.luau`, `src/shared/Data/FishingTuning.luau` (`reelGrace = 5`) and `net.zap` (regenerate).
- Modify `src/server/Services/FishingService.luau`.

**Interfaces:**
- Consumes Task 1's `Tuning`, `replay` and `tuning`.
- Produces:
  - `export type Reel = { seed: number, tuning: TrackBarSim.Tuning }`.
  - `cast(state, now, token, catch, reel)`.
  - `hook()`: "Hooked" now moves to phase "Reeling" and records `reelStart`. It no longer returns the catch.
  - `reel(state, now, token, toggles, claimed): (ReelVerdict, Catch?, boolean)`, where `ReelVerdict = "Caught" | "Escaped" | "Forged" | "Rejected"`:
    - "Rejected" (wrong phase or token) changes nothing.
    - "Forged" (no valid replay, a claim that doesn't match, or `now - reelStart < ticks / tickRate - latencyAllowance`) ends the reel, and the fish escapes.
  - `expire(state, now): ("Missed" | "Escaped")?`.
- `net.zap`:
  - `type Tuning = struct {barSize, fishSpeed, moveInterval, gainRate, drainRate: f64}`;
  - `Bite(token, seed: u32, tuning: Tuning)`;
  - new `ReelResult(token, toggles: u16[..1000], claimed: enum {"Caught", "Escaped"})` (Client, Reliable, SingleAsync);
  - FishResult gains `perfect: boolean?`.

- [ ] **Update `tests/FishingState.spec.luau` first:**
  - Casts pass `{ seed = 1, tuning = TrackBarSim.tuning(1, RodData.Driftwood) }`.
  - "hooks inside the window … and starts the reel": phase "Reeling".
  - Expire tests expect "Missed" or nil.
  - New tests:
    - "lands the fish when the replay agrees" (`ReelBot.play`, with `now = reelStart + ticks / 60`): "Caught", the catch, and the replay's `perfect`.
    - "loses the fish when the replay says it escaped".
    - "rejects a claim the replay doesn't reproduce": the claim is "Caught" on an escaped log; the result is "Forged" and the phase becomes Idle.
    - "rejects a result faster than the reel": `now = reelStart + 0.1` gives "Forged".
    - "ignores a wrong token mid-reel": "Rejected", and the phase stays Reeling.
    - "lets a reel with no result escape after 95 s": "Escaped".
- [ ] Run Jest. Expected: the new tests fail. Implement. Run Jest. Expected: all pass.
- [ ] Update `net.zap` and run `zap net.zap`.
- [ ] Update FishingService:
  - The cast picks `seed = rng:NextInteger(0, 4294967295)` and `tuning = TrackBarSim.tuning(difficulty, RodData[FishingTuning.rodId])`.
  - The bite sends the seed and tuning.
  - A hook logs `[Fishing] <name> hooked <species> at <spot>`.
  - `ReelResult` goes through `allowed()`, and the service answers each verdict:
    - Caught: log `… caught … kg at <spot>` with " (Perfect)" when Perfect, and fire FishResult Caught with `perfect`;
    - Escaped: FishResult Escaped;
    - Forged: `warn` with the player name, and FishResult Escaped.
  - `expire` maps to FishResult Missed or Escaped.
- [ ] Run `tools/check.ps1` and Jest. Commit "M1 S3 task 2: reel phase and server replay of the input log".

### Task 3: MinigameController and placeholder overlay

**Files:**
- Create `src/client/Controllers/MinigameController.luau`.
- Modify `src/client/Controllers/FishingController.luau` and `src/client/init.client.luau`.

**Interfaces:**
- `MinigameController.start(token, seed, tuning)`, `MinigameController.stop()`.
- `MinigameController.events: BindableEvent`, which fires "Hit" and "Miss" for the session 8 feel pass.

- [ ] MinigameController:
  - A hidden `ReelHud` ScreenGui with a 36×300 px vertical track at the right middle of the screen, the bar (height `barSize × 300`), a 10 px fish marker, and a progress column beside it.
  - On RenderStepped, a 1/60 s accumulator steps the sim with `InputController.fish:GetState()`.
  - It records a toggle whenever the hold state changes, and stops recording at 999.
  - It fires events and moves the frames.
  - On the outcome it sends `Net.ReelResult.Fire(token, toggles, outcome)` and stops stepping.
  - `stop()` hides the overlay.
- [ ] FishingController:
  - The Bite stores the seed and tuning.
  - A press while Biting sends Hook and calls `MinigameController.start`, moving the phase to "Reeling"; presses during Reeling do nothing.
  - FishResult calls `MinigameController.stop()`.
  - Result text: Caught adds " Perfect!" when `perfect` is set, and Escaped shows "It escaped."
- [ ] List MinigameController in `init.client.luau` after InputController. Run checks. Commit "M1 S3 task 3: reel overlay on the client".

### Task 4: Playtest, notes, commit

- [ ] Studio playtest through the MCP. Hook with the scripted binding, as in session 2.
  1. A bot that holds while the bar's middle is below the fish gives "Caught …" (and Perfect when there are no misses), with a matching server log.
  2. No input gives "It escaped."
  3. A forged ReelResult, if the test context can fire one, gives a server `warn` and an escape.
  Take a screenshot of the overlay.
- [ ] Write the playtest note, session log and Status. Commit "M1 S3: track-bar reel with server replay".
