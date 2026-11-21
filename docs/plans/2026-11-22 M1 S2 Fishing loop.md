---
tags: [plan, m1]
---
# M1 Session 2: Fishing Loop Implementation Plan

Back to [[Status]] · Milestone design: [[plans/2026-11-22 M1 Vertical slice]] · Previous: [[plans/2026-11-22 M1 S1 Fish data and CatchRoll]]

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cast, wait, bite and hook in a Studio playtest, with the server choosing every fish. Until session 3 adds the reel, a hooked fish counts as caught.

**Architecture:** One input, "Fish" (PRD §4): hold and release to cast, press to hook, press while waiting to reel in. The client sends only cast power and aim, a token and reel-in. FishingService (server) computes the landing point, checks it's water, finds the spot (tagged zones, defaulting to open water), rolls with CatchRoll, times the bite and judges the hook. The rules live in a pure FishingState module (time passed in, Jest-tested). Remotes come from Zap.

**Tech Stack:** Zap 0.6.29, the Input Action System (InputContext, InputAction, InputBinding), Luau `--!strict`, Jest Lua (Edit mode).

**Spec:** the session 2 design the user approved on 2026-11-22 (session log), [[plans/2026-11-22 M1 Vertical slice]], PRD §4 and §14.

## Global Constraints

- The server decides the landing point, spot, fish, bite time and hook outcome. Clients send only power (0 to 1), aim direction, the cast token and reel-in.
- Tuning lives in `src/shared/Data/FishingTuning.luau`: cast distance 8 to 48 studs, hook window 0.9 s minus 0.04 s per difficulty step above 1 (at least 0.45 s), latency allowance 0.35 s, cast cooldown 0.75 s.
- On mobile, the fish button is at least 44×44 px (PRD §2).
- Generated Zap code in `src/shared/Net/` is committed but kept out of StyLua, Selene and luau-lsp.
- `tools/check.ps1` passes and Jest runs in Edit mode before every commit.

## Review Focus

1. **A hook arriving after the window because of lag.** The server allows window + 0.35 s; a later hook counts as missed, not an error.
2. **A stale token.** A hook carrying an old cast's token after a new cast is rejected, and the new cast is untouched.
3. **A cast that lands on land.** It's refused with a reason, and nothing is rolled.
4. **A player leaving mid-cast.** Their state and timers are cleared, so nothing fires to a missing player.
5. **Casting spam.** The cooldown refuses it.

---

### Task 1: Zap remotes

**Files:** Create `net.zap`, generated `src/shared/Net/Server.luau` and `Client.luau`, and `.styluaignore`. Modify `selene.toml` and `tools/check.ps1` to exclude `src/shared/Net`.

- [ ] Events:
  - `RequestCast` (Client, Reliable, SingleAsync; `power: f32(0..1)`, `direction: Vector3`)
  - `CastResult` (Server; `landing: Vector3?` and a reason, an enum of `Ok`, `NotWater`, `Busy`, `Cooldown`, `NoCharacter`)
  - `Bite` (Server; `token: string.utf8(..40)`)
  - `Hook` (Client; token)
  - `ReelIn` (Client; no data)
  - `FishResult` (Server; an outcome enum of `Caught`, `Missed`, `Escaped`, `ReeledIn`, plus `speciesId: string.utf8(..40)?` and `weightKg: f32?`)
- [ ] `zap net.zap` generates both files; `tools/check.ps1` stays clean.

### Task 2: FishingState (pure, test first)

**Files:** Create `src/shared/Data/FishingTuning.luau`, `src/shared/Modules/FishingState.luau` and `tests/FishingState.spec.luau`.

**Interfaces:** `FishingState.new(): State`; `cast(state, now, token, catch): (boolean, string?)`; `bite(state, now): number?` (returns the hook window); `hook(state, now, token): "Hooked" | "Missed" | "Rejected"`; `expire(state, now): boolean`; `reelIn(state): boolean`; `landing(origin: Vector3, direction: Vector3, power: number): Vector3`; `hookWindow(difficulty: number): number`.

- [ ] Write the spec first:
  - casting works only from Idle and after the cooldown;
  - the bite only comes at or after the bite time;
  - a hook inside the window plus the allowance → Hooked; later → Missed; a wrong token → Rejected;
  - reel-in cancels the wait;
  - expire releases a bite whose window has passed;
  - the window shrinks with difficulty, down to its minimum;
  - the landing point is horizontal and between 8 and 48 studs away.
- [ ] Run it; it fails. Implement. Run it; it passes.

### Task 3: FishingService, controllers, placeholder harbor

**Files:** Create `src/server/Services/FishingService.luau`, `src/client/Controllers/InputController.luau` and `src/client/Controllers/FishingController.luau`. Modify both entry scripts. Delete `src/server/Services/SmokeTestService.luau`.

- [ ] FishingService:
  - Zap callbacks, with a per-player FishingState and `Random`.
  - The water check: a downward raycast that doesn't ignore water.
  - The spot: a part tagged `FishingSpot` with a `SpotId` attribute that contains the landing point; otherwise `open`.
  - `CatchRoll.roll`, with bite and expire timers keyed to the token.
  - Logs `[Fishing] <name> caught <species> <kg> kg at <spot>`.
  - Cleans up when a player leaves.
- [ ] InputController: an InputContext with a Bool "Fish" action bound to Space, MouseLeftButton and an on-screen button (96×96 px).
- [ ] FishingController: power meter while holding; casts toward the camera's flat look direction; bobber and line at the server's landing point; "!" on a bite; hook or reel-in on press; result text.
- [ ] Placeholder harbor in Studio (Edit, through the MCP), in a `PlaceholderHarbor` folder: terrain water, a pier, and tagged spot zones for all 5 spots. Session 7 replaces it.

### Task 4: Playtest, notes, commit

- [ ] Studio playtest through the MCP, using keyboard input: cast, see "!", hook. The console shows the server's catch log; a miss shows Missed. Take a screenshot.
- [ ] Write the playtest note, session log and Status. Commit: "M1 S2: fishing loop (cast, bite, hook) with server-chosen fish".
