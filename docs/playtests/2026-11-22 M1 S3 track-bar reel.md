# 2026-11-22 M1 S3 track-bar reel
Milestone: M1 (session 3 of 13)
Build / commit: "M1 S3 task 3: reel overlay on the client" (0760cd1)
Platforms tested: PC only (Studio playtest driven through the Studio MCP). No phone yet.
Testers: Claude (automated)
Session: [[sessions/2026-11-21 2137 M0 foundations]] · Plan: [[plans/2026-11-22 M1 S3 Track-bar reel]] · Perfect rule: [[decisions/2026-11-22 Track-bar Perfect - keep the fish in the bar]]

![[img/2026-11-22 M1 S3 reel overlay.jpg]]

## What was tested
- Startup: `[Server] 1 services started` and `[Client] 3 controllers started`.
- Cast, bite, hook, then the reel. The hold during the reel came from a test bot through a Scriptable binding on the Fish action. That is the same path a key press takes (the action, then MinigameController, then `ReelResult`). The bot read the overlay each frame and held while the bar's middle was below the fish.
- Three reels:
  1. a simple bot;
  2. no input after the hook;
  3. a steadier bot that also brakes on the bar's speed.

## What felt good
- **The reel opens the moment you hook**, as an overlay with no screen change. In the screenshot you can see the dark track, the green catch bar, the yellow fish just above it, and progress filling on the right.
- The simple bot landed a fish: "Caught a Plank Perch! 0.30 kg", a 12.1 s reel.
- No input gave "It escaped." after 2.9 s, which matches 30% progress draining at about 0.10 a second.
- The steadier bot landed "Caught a Tideline Herring! 0.37 kg" in 11.5 s.
- **The server's replay agreed with the client every time:**
  ```
  [Fishing] <player> hooked PlankPerch at open
  [Fishing] <player> caught PlankPerch 0.3 kg at open
  [Fishing] <player> hooked TidelineHerring at open
  [Fishing] <player> lost a fish at open
  ```
  There were no Forged warnings and no errors. The only warnings are the old `ContentId 203785492` ones.
- The overlay closes on the server's answer, and the bobber's "!" disappears when you hook.
- Jest 60/60 (Edit mode), and `tools/check.ps1` passes.

## What felt bad
- **Neither bot got a Perfect.** Both let the fish slip outside the bar for more than 0.25 s at some point. A bot reading the screen a frame late is clumsier than a person, but Perfect on a 22% bar may still feel too hard. Check it by hand in the loop playtest after session 5. The knobs are in `ReelTuning` (bar size, grace, fish speed).
- The overlay sits at the screen's right edge, next to the Fish button, rather than near the bobber (PRD §4). It's a placeholder; session 10 places the final one.
- There's no sound, shake or animation yet: the Hit and Miss events fire, but nothing listens until session 8.

## Bugs
- None found in the game. The test script's first try timed out on its own wait (`CharacterAdded:Wait()` after the character already existed).

## Not tested
- A forged `ReelResult` sent over the network. FishingState's tests cover forged claims, bad toggles and too-fast results. The live client can't send one, because it records its own input.
- A phone; holding with the screen button; a player who leaves or respawns mid-reel.

## Follow-up: review fixes (same day, 12:16)
- The reel is now timed from the server's bite instead of the hook's arrival, so lag on the hook can't make an honest reel look forged. The client also steps only the ticks due since the hook press.
- A bot reel afterwards: "Caught a Tideline Herring! 0.20 kg". The server logged "hooked" then "caught", with no Forged warning.

## Decisions to make (link to [[decisions/README|Decisions]])
- Is Perfect too hard on a 22% bar? Decide after playing a few reels by hand. The knobs are `barSizeBase` and `missGraceSeconds` in `ReelTuning`. Keep the grace a multiple of 1/60 s until the deferred whole-tick fix lands (see [[Status]]).
