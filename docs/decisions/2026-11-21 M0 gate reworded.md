# 2026-11-21 M0 gate reworded
PRD section: §16 (the M0 node in the milestone diagram)
Was: `Gate: generated fish caught in Studio`
Now: `Gate: generated fish loads from its asset ID in a Studio playtest`. The fish's ID comes from `AssetIds.luau`, and a Studio-only SmokeTestService spawns it during the playtest.
Why: Catching (cast, hook, reel) is M1's job, and a throwaway catch stub would be deleted in M1. The smoke test in §15 already describes uploading and inserting.

Links: [[PRD]] · [[sessions/2026-11-21 2137 M0 foundations]]
