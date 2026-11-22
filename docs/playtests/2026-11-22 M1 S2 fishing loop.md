# 2026-11-22 M1 S2 fishing loop
Milestone: M1 (session 2 of 13)
Build / commit: "M1 S2 task 3: FishingService, Fish input, placeholder fishing UI" (baa079c)
Platforms tested: PC only (Studio playtest driven through the Studio MCP). No phone yet: the 96×96 touch button exists but wasn't pressed on a device.
Testers: Claude (automated)
Session: [[sessions/2026-11-21 2137 M0 foundations]] · Plan: [[plans/2026-11-22 M1 S2 Fishing loop]]

![[img/2026-11-22 M1 S2 line.jpg]]

## What was tested
- Startup: `[Server] 1 services started` and `[Client] 2 controllers started`. The player spawns on the pier end of the placeholder harbor.
- Casting with real keyboard input (Space held 1.3 s) and real mouse input (left button held).
- Bite, "!", hook and miss. The hook press used a Scriptable test binding on the Fish action, added only inside the playtest. It drives the same action, controller and remotes as a key press. This was needed because the hook window (at most 1.25 s) is shorter than one MCP round trip, so the cast, the wait and the press had to happen in one call.
- All five spots, with a scripted camera aiming each cast.
- Refusals: a cast onto the pier deck, and a recast during the cooldown.

## What felt good
- **Space no longer jumps.** Holding it for 1.3 s raised no Jumping state and the root height didn't change. The Fish context (Priority 2000, Sink on) beats the default PlayerScripts controls, as the Input Action System docs say.
- Full power lands exactly 48 studs ahead, on the water surface; power 0.25 lands 18 studs ahead. The meter hides on release.
- A bite came 7.4 s after a cast (the zone's range is 4 to 10 s). The "!" appeared and the bobber dipped. A press 0.25 s later caught the fish ("Caught a Plank Perch! 0.79 kg") and the line cleared.
- No press on the "!" gave "It got away."
- Pressing while waiting reels in quietly, and an immediate recast then gave "Too soon. Try again."
- A cast toward the pier gave "Cast into the water."
- The server logged one line per result, naming the spot each zone gave:
  ```
  [Fishing] <player> missed a bite at open
  [Fishing] <player> caught PlankPerch 0.79 kg at open
  [Fishing] <player> missed a bite at open
  [Fishing] <player> caught PlankPerch 0.93 kg at wreck
  [Fishing] <player> caught TidelineHerring 0.77 kg at rocks
  [Fishing] <player> caught TidelineHerring 0.38 kg at lighthouse
  [Fishing] <player> caught PlankPerch 0.44 kg at pier
  ```
  Every species lives at the spot it came from ([[lore/Driftwood Harbor fish]]).
- No errors from our code. The only warnings are the `ContentId 203785492` asset-type warnings, which were there before this session.
- Jest 39/39 (Edit mode), and `tools/check.ps1` passes.

The placeholder harbor in Edit mode, seen from the shore: rocks on the left, then the lighthouse, the wreck on the right, and the template Baseplate far off on the left.
![[img/2026-11-22 M1 S2 harbor.jpg]]

## What felt bad
- The character doesn't turn toward the cast, and there's no rod: the line runs from the empty right hand. Both belong to the feel pass (session 8).
- The run's first bite came and expired between tool calls. MCP round trips take several seconds, so a test has to cast and hook within one call.
- A mouse hold sent through the MCP cast farther than its nominal 0.4 s (32 studs instead of about 21): the input tool's own delay stretched the hold. This is not a game bug, but it means the meter can't be judged from the timing of MCP input.
- The spawn pad is a 1-stud step on the pier deck. Placeholder only.
- The Fish button also shows on PC. It is a placeholder; per-device HUD comes in session 10.

## Bugs
- None found.

## Not tested
- A forged or stale token sent over the network. FishingState's tests cover it; requiring the client's Zap module a second time from a test would clash with the live one.
- A player leaving mid-cast (single player). The service drops their state on PlayerRemoving.
- Touch on a phone, and several players at once.

## Follow-up: review fixes (same day, second playtest)
- **Bug found by the review and reproduced:** a PC player who falls into the water can't get out. While swimming, 1.5 s of Space changed no state and didn't raise the character, because the Fish context sank Space; it cast a line from the water instead.
- **Fixed:** the Fish context switches off while the character swims. The same test now cycles Jumping, Freefall and Swimming, the character reaches y 9.8 (above the pier deck), and no line is cast. Back on the pier, Space casts again (a line 28 studs out) with no jump.
- Rate limits: every fishing remote now drops requests over 10 a second (bursts of 20). Normal fishing still works: a cast and hook gave "Caught a Plank Perch! 0.40 kg".

## Decisions to make (link to [[decisions/README|Decisions]])
- **Space now fishes instead of jumping on PC**, because the approved M1 design binds Fish to Space. Keep that, or move Fish to another key so that Space jumps again? Touch players keep their jump button either way.
