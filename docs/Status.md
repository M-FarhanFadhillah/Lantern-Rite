# Status

Back to [[Home]]. Claude Code updates this note after every completed task.

**Last updated:** 2026-11-22 05:55
**Current milestone:** M0 Foundations ([[PRD#16. Milestones and roadmap]]): every task done and the gate passed on PC; the phone check is the user's call (see below)
**Current plan:** [[plans/2026-11-21 M0 Foundations]]

## Done
- PRD written and saved as [[PRD]]
- Project folder, CLAUDE.md, subagents (Opus for design and code, Sonnet for notes) and this Obsidian vault set up
- Blender MCP add-on installed and connected; Figma MCP added to Claude Code
- M0 plan approved (2026-11-21): GLB export modeled in studs; M0 gate = the generated fish loads from its asset ID in a Studio playtest; private GitHub repo; config fixes from the review
- Task 1: git repo (branch main) and the approved config fixes
- Task 2: Rokit 1.2.0 pinning Rojo 7.7.1, Wally, StyLua, Selene, Lune, Zap 0.6.29 and luau-lsp; Wally packages (React, ProfileStore, Jest); `default.project.json`; Rojo Studio plugin
- Task 3: `rojo serve` + the Rojo plugin connected; everything syncs
- Task 4: `Loader` (shared) built test-first; Jest Lua 4/4, run in **Edit mode**: `require(game.ServerStorage.Tests.RunTests:Clone())()`. Needs FFlagEnableLoadModule: re-run `tools/enable-jest-flag.ps1` after every Studio update, then restart Studio
- Task 5: server/client entry scripts load through `Loader`; `AssetIds.luau`; `SmokeTestService` (Studio only) ([[playtests/2026-11-21 M0 loaders]])
- Task 6: decision notes and PRD sync; `tools/check.ps1` (all pre-commit checks); CLAUDE.md Commands; GitHub remote `origin` (M-FarhanFadhillah/Lantern-Rite)
- Task 7: `art/blender/fish_gen.py` + `palette.json` + spec `FSH_KelpSnapper` (484 triangles, 0.84 × 2.40 × 1.12 studs), live and headless
- Task 8: uploaded through the Studio MCP as asset **87926189441992** (`AssetIds.Fish.FSH_KelpSnapper`). Studio's MCP Permissions now approve `art/blender/exports`, `art/figma` and `art/audio` (plus `studio`)
- Task 9: **M0 gate passed on PC**: the fish loads from its asset ID in a Studio playtest. It has the exact size, is textured, upright and anchored, and faces its LookVector ([[playtests/2026-11-22 M0 fish smoke test]], [[decisions/2026-11-22 Export fish as GLB modeled in studs]])
- Task 10: ponytail review of M0; all four findings fixed (facing guard, dead preview light, safer type-definition download, unused export retry)

## In progress
- Nothing.

## Next step
- Decide whether M0 needs a phone check (PRD §16: "a milestone is done only when its gate passes in a real playtest on PC and a phone"). That needs the place published and joined from a phone.
- Then M1, the vertical slice (Harbor, 12 fish, track-bar reel, sell, save, cargo grid): brainstorm and plan first, one system per session.

## Open questions / blockers
- Phone check for the M0 gate (above).
- Studio shows two Rojo buttons on the Plugins toolbar (the one `rojo plugin install` added and another). Keep one so it's always clear which is connected.
- Unused asset 85973780481219 (the first, backwards fish upload) can be archived in the Creator Dashboard.
- The local `figma` MCP server is unauthenticated; remove it (`claude mcp remove figma`) or sign it in with /mcp.
- The universe is rated 13+ (maturity questionnaire not done) while the PRD targets ages 10 to 17. Fill it in before M1 testers.
- See the open questions in [[PRD#17. Success metrics, risks and open questions]]
