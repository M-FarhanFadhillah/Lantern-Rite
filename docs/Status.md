# Status

Back to [[Home]]. Claude Code updates this note after every completed task.

**Last updated:** 2026-11-21 21:40
**Current milestone:** M0 Foundations ([[PRD#16. Milestones and roadmap]])
**Current plan:** [[plans/2026-11-21 M0 Foundations]]

## Done
- PRD written and saved as [[PRD]]
- Project folder, CLAUDE.md, subagents (Opus for design and code, Sonnet for notes) and this Obsidian vault set up
- Blender MCP add-on installed and connected; Figma MCP added to Claude Code
- Studio upload folders set: art/blender/exports, art/figma, art/audio
- M0 plan approved (2026-11-21): GLB export modeled in studs; M0 gate = the generated fish loads from its asset ID in a Studio playtest; private GitHub repo; config fixes from the review

- Task 1: git repo (branch main) and the approved config fixes, first commit
- Task 2: Rokit 1.2.0 with pinned Rojo 7.7.1, Wally, StyLua, Selene, Lune, Zap 0.6.29, luau-lsp; Wally packages (React, ProfileStore, Jest); `default.project.json` builds; Rojo Studio plugin installed

- Task 3: `rojo serve` + Studio Rojo plugin connected; everything syncs
- Task 4: `Loader` (shared) built test-first; Jest Lua runs in Studio Play through the MCP, 3/3 passing. Needs FFlagEnableLoadModule: re-run `tools/enable-jest-flag.ps1` after every Studio update, then restart Studio

## In progress
- M0 Part A (repo, toolchain, loaders, Jest test) — session [[sessions/2026-11-21 2137 M0 foundations]]

## Next step
- Task 5 of the plan: server/client entry scripts, `AssetIds.luau`, `SmokeTestService`, type check, playtest

## Open questions / blockers
- Waiting for the GitHub repo URL (the user creates an empty private repo)
- The local `figma` MCP server is unauthenticated; remove it (`claude mcp remove figma`) or sign it in with /mcp
- See the open questions in [[PRD#17. Success metrics, risks and open questions]]
