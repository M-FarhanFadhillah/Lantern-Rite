---
tags: [plan, m1]
---
# M1 Session 1: Fish Data and CatchRoll Implementation Plan

Back to [[Status]] · Milestone design: [[plans/2026-11-22 M1 Vertical slice]] · Lore: [[lore/Driftwood Harbor fish]]

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Driftwood Harbor's data (12 species, spots, rods, bait, rarity) and a tested CatchRoll that gives true catch odds and deterministic rolls.

**Architecture:** Plain data modules in `src/shared/Data/` and one pure module `src/shared/Modules/CatchRoll.luau`. `CatchRoll.odds(context)` is the single source of catch chances: the roll uses it, and the PRD §11 odds panel will later show it. Randomness comes from Luau's built-in `Random.new(seed)`, which is deterministic per seed, so no wrapper module is needed. The same seed type later drives the reel replay.

**Tech Stack:** Luau `--!strict`, Jest Lua 3.10 (Studio Edit mode), Rojo.

**Spec:** the approved session 1 design (session log 2026-11-22), [[plans/2026-11-22 M1 Vertical slice]], PRD §4, §5, §9.

## Design (approved 2026-11-22)

- **Tier first, then species.** Rarity tiers use PRD §5's base chances (Common 0.55, Uncommon 0.25, Rare 0.12, Epic 0.055, Legendary 0.02, Mythic 0.005). Modifiers multiply Rare and above (bait `rareMult` × (1 + rod luck/100)), and Common absorbs the difference, so Uncommon stays fixed. A tier with no species available at the spot and cast power gives its chance to Common, which keeps each rare tier's absolute chance wherever it lives. Within a tier, available species share the chance equally.
- **Availability:** species `zone` matches, `spots` contains the spot, and `castPower >= minCast`. Every Harbor spot has at least one Common.
- **Bite time:** uniform in the zone's `[min, max]`, × (1 − rod lureSpeed/200) × bait `biteMult`.
- **Weight:** `min + (max − min) × u²`, so heavy fish are rarer, rounded to 0.01 kg.
- **Out (M2+):** mutations, time of day, weather, night species.

## Global Constraints

- Every Luau file starts with `--!strict`; tuning lives only in `src/shared/Data/`.
- Species ids are PascalCase (`DockMinnow`); asset keys are `FSH_<Id>`.
- Base values must sit inside PRD §5's tier value ranges: Common 5–30, Uncommon 25–80, Rare 70–250, Epic 200–900, Legendary 800–4,000, Mythic 3,500–20,000.
- Jest specs run in Studio Edit mode: `return require(game.ServerStorage.Tests.RunTests:Clone())()`.
- `tools/check.ps1` passes before every commit.

## Review Focus

1. A spot without a Common would push missing tiers' chance nowhere, so the odds wouldn't sum to 1. A data test asserts that every spot has a Common.
2. Iterating a dictionary (`pairs`) makes rolls non-deterministic across runs, so species are walked in `FishData.list` order. Tested: the same seed gives the same catch.
3. Strong modifiers could push Common below 0. CatchRoll errors if that happens; tested with an extreme bait.
4. An unknown zone, spot, rod or bait must error clearly rather than roll from an empty table.
5. A float sum drifting from 1 could make the cumulative pick fall off the end. The last available species catches the remainder.

---

### Task 1: Rarity, fish, zone, rod and bait data

**Files:**
- Create: `src/shared/Data/RarityData.luau`, `src/shared/Data/FishData.luau`, `src/shared/Data/ZoneData.luau`, `src/shared/Data/RodData.luau`, `src/shared/Data/BaitData.luau`, `tests/FishData.spec.luau`
- Delete: `src/shared/Data/.gitkeep`

**Interfaces:**
- Produces: `RarityData.order: {Rarity}`, `RarityData.baseChance: {[Rarity]: number}`, `RarityData.valueRange: {[Rarity]: {min: number, max: number}}`, `export type Rarity`.
- Produces: `FishData.list: {Species}`, `FishData.byId: {[string]: Species}`, `export type Species = { id, displayName, zone, rarity, spots: {string}, minCast: number, weightKg: {min, max}, baseValue, shape: {{number}}, difficulty, lore, assetKey }`.
- Produces: `ZoneData.DriftwoodHarbor = { displayName, biteTime: {min, max}, spots: {[string]: {displayName}} }`; `RodData.Driftwood`, `RodData.Brassline`: `{ displayName, control, resilience, lineStrength, reelSpeed, lureSpeed, luck, price }`; `BaitData.HarborShrimp = { displayName, rareMult, biteMult, price }`.

- [ ] **Step 1:** Write `tests/FishData.spec.luau`. It asserts: 12 Harbor species; ids unique; every rarity is known; every spot exists in ZoneData; every spot has at least one Common; `weightKg.min < max`; difficulty 1–10; base value inside its tier's range; shape is non-empty; `assetKey == "FSH_" .. id`.
- [ ] **Step 2:** Run it (Edit mode). Expected: fails, because the modules don't exist.
- [ ] **Step 3:** Write the five data modules with the approved species (names, rarity, spots, shapes, difficulty and lore as in [[lore/Driftwood Harbor fish]]).
- [ ] **Step 4:** Run. Expected: the FishData spec passes.

### Task 2: CatchRoll odds and roll

**Files:**
- Create: `src/shared/Modules/CatchRoll.luau`, `tests/CatchRoll.spec.luau`

**Interfaces:**
- Consumes: the Task 1 data.
- Produces: `export type Context = { zoneId: string, spotId: string, castPower: number, rodId: string, baitId: string? }`, `export type Catch = { speciesId: string, rarity: string, weightKg: number, biteTime: number }`, `CatchRoll.odds(context: Context): {[string]: number}`, `CatchRoll.roll(context: Context, rng: Random): Catch`.

- [ ] **Step 1:** Write `tests/CatchRoll.spec.luau`:
  - The odds sum to 1 (within 1e-9) for every spot at cast power 0.2 and 0.9.
  - The pier gives only Dock Minnow, Rope Sprat and Plank Perch, 1/3 each.
  - Below `minCast`, Silt Whisker and Lampjaw are 0 in open water; at a far cast, Silt Whisker is 0.12 and Lampjaw 0.055.
  - Wreckwarden is 0.02 at the wreck with a far cast, and 0 with a short one.
  - Harbor Shrimp raises Silt Whisker to 0.144, and the Uncommon total stays 0.25.
  - The same seed and context give the same catch.
  - 10,000 rolls in open water with a far cast land within ±0.015 of the odds per species.
  - `weightKg` stays within the species range, and `biteTime` within the zone range × modifiers.
  - An unknown spot errors; a bait with `rareMult` 20 errors (Common < 0).
- [ ] **Step 2:** Run. Expected: fails, because CatchRoll is missing.
- [ ] **Step 3:** Implement `CatchRoll.odds` and `CatchRoll.roll` per the Design section, walking species in `FishData.list` order.
- [ ] **Step 4:** Run. Expected: all specs pass. Then `tools/check.ps1` is clean.

### Task 3: Studio check, notes, commit

- [ ] **Step 1:** In Studio (Edit), `execute_luau` rolls 1,000 times at each spot (far cast) and prints the tier split. It should match the odds.
- [ ] **Step 2:** Write the session log entry and update Status. Commit: "M1 S1: Harbor fish data and CatchRoll (tested)".
