---
tags: [plan, m0]
---
# M0 Foundations Implementation Plan

Back to [[Status]] · Milestone: [[PRD#16. Milestones and roadmap]] · Session: [[sessions/2026-11-21 2137 M0 foundations]]

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pinned Rojo/Wally/Rokit repo with a tested service loader, plus an art pipeline that takes one generated fish from Blender to a Studio playtest by its asset ID.

**Architecture:** Code syncs with `rojo serve` into the cloud place "Lantern-Tide" (place 97390126948004); world content stays in the place. The server and client entry scripts each pass an explicit, ordered module list to one shared `Loader`. Art comes from parameterized Blender generators, is exported as GLB modeled in studs, uploaded through the Studio MCP (Open Cloud) and referenced by ID from `AssetIds.luau`.

**Tech Stack:** Rokit 1.2.0 · Rojo 7.7.1 · Wally · StyLua · Selene · Lune · Zap 0.6.29 · luau-lsp · Luau `--!strict` · Jest Lua 3.10.0 · React Lua 17 · ProfileStore 1.0.3 · Blender 5.3 · Roblox Studio MCP · MCP for Blender

**Spec:** the approved design below, [[PRD]] §13–§16, CLAUDE.md.

## Design (approved 2026-11-21)

**Why:** M0 proves every tool in the pipeline works before any game system exists, so M1 (the vertical slice) starts on solid ground.

**Goals:** pinned toolchain; the §14 folder layout; server and client loaders with a passing Jest Lua test; MCP servers checked; one generated fish uploaded and loaded by ID in a playtest; the vault and PRD updated to match what changed.

**Non-goals:** any fishing mechanic (M1); DataService or any ProfileStore use (M1); Zap remotes (the first is M1's `RequestCast`); `tools/upload_assets.py`; UI.

| Topic | Decision | Why |
| --- | --- | --- |
| Export format | GLB, modeled in studs (1 Blender unit = 1 stud) | Studio's import guide prefers GLB (one file, textures embedded); GLB usually imports at 1 m = 1 stud, so no scale factor is needed |
| Colour | Faces UV-mapped into a shared 512 px palette atlas | Flat material colours often import as default grey; textures survive |
| Uploads | Studio MCP `open_cloud_invoke`; Claude records IDs in `AssetIds.luau` | No API key or script needed; a batch is one call per file |
| M0 gate | The generated fish loads from its asset ID in a Studio playtest | Catching is M1's job; PRD §16 gets reworded |
| Tests | Jest Lua specs in `ServerStorage.Tests`, run during Play through the Studio MCP | `debug.loadmodule` is already enabled in Studio |
| Dev packages | DevPackages and tests sync into ServerStorage | Server-only, never replicated; revisit in the M5 launch checklist |
| GitHub | Private repo created by the user; Claude adds the remote and pushes | Off-site backup; §16 tracks milestones as Issues |

**Approaches considered and rejected:** FBX export (usually imports about 28× too big and needs a scale factor per export); a throwaway press-E-to-catch stub for the gate (M1 builds real catching); `tools/upload_assets.py` with an API key (the MCP route covers M0).

## Global Constraints

- Every Luau file starts with `--!strict`.
- The server is authoritative. SmokeTestService does nothing unless `RunService:IsStudio()`.
- All names are original. The test fish is a placeholder: `FSH_KelpSnapper`, built from `art/blender/specs/fish/kelp_snapper.json`.
- Fish budget: 300 to 1,500 triangles; shared 512 px palette atlas (PRD §13).
- Export names: `FSH_*`, `BOT_*`, `ROD_*`, `PRP_*`.
- `stylua --check src tests` and `selene src tests` pass with zero warnings before every commit.
- Never commit `.env`; never print API keys.
- Commit after each working change, with a message that matches the session-log entry.
- Update [[Status]] and the session log after every task.

## Review Focus

1. A Studio update drops `debug.loadmodule`: `RunTests` must fail with a message naming FFlagEnableLoadModule, not a Jest stack trace. (Task 4, Step 1)
2. The Rojo plugin and CLI versions differ: Connect fails. Install the plugin with `rojo plugin install` from the pinned CLI. (Task 2, Step 7)
3. A module's `Init` errors: the error names that module and no `Start` runs. (Task 4 spec)
4. A missing or not-yet-approved asset ID: SmokeTestService prints one line and the server keeps running. (Task 5 playtest with an empty `AssetIds`)
5. CRLF line endings from Windows tools: `stylua --check` must not fail on untouched files. `.gitattributes` forces LF. (Task 1, Step 2)

---

## Part A — repo and code

### Task 1: Repo and approved config fixes

**Files:**
- Create: `.gitattributes`
- Modify: `.gitignore`, `CLAUDE.md`, `.claude/settings.json`, `.claude/agents/blender-artist.md`

- [ ] **Step 1:** `git init -b main` prints "Initialized empty Git repository".
- [ ] **Step 2:** `.gitattributes`: `* text=auto eol=lf`, plus `binary` for `*.png *.jpg *.glb *.fbx *.blend *.rbxm *.rbxl *.zip`.
- [ ] **Step 3:** `.gitignore` adds `.env.*`, `!.env.example`, `Claude outputs/`, `__pycache__/`, `*.blend@`.
- [ ] **Step 4:** CLAUDE.md: notes-keeper handles decision notes, PRD updates and lookups, while the main session writes Status.md and the session log itself; the effort line agrees with settings.json; the Art rule adds "export GLB modeled in studs" and the Blender path `E:\SteamLibrary\steamapps\common\Blender\blender.exe`.
- [ ] **Step 5:** `.claude/settings.json`: deny `Read(./.env)` and `Read(./.env.*)`; the effort setting matches CLAUDE.md.
- [ ] **Step 6:** blender-artist: specs live in `art/blender/specs/<kind>/`; export GLB modeled in studs; the Blender path; build in its own scene and never touch the open file; report triangles per mesh, size in studs and one lopsided feature.
- [ ] **Step 7:** `git status` lists no `.env` and nothing from `Claude outputs/`. Commit: "M0: init repo and apply approved config fixes".

### Task 2: Toolchain and Rojo project

**Files:**
- Create: `rokit.toml`, `wally.toml`, `wally.lock`, `default.project.json`, `stylua.toml`, `selene.toml`, and the §14 folders (`.gitkeep` where a folder has no file yet)

**Interfaces:**
- Produces: `ReplicatedStorage.Shared` (src/shared), `ReplicatedStorage.Packages`, `ServerScriptService.Server` (src/server), `ServerStorage.ServerPackages`, `ServerStorage.DevPackages`, `ServerStorage.Tests` (tests/), `StarterPlayer.StarterPlayerScripts.Client` (src/client).

- [ ] **Step 1:** Install Rokit 1.2.0 from its GitHub release with `rokit self-install`. `rokit --version` prints 1.2.0.
- [ ] **Step 2:** `rokit init`, then `rokit add` `rojo-rbx/rojo@7.7.1`, `UpliftGames/wally`, `JohnnyMorganz/StyLua`, `Kampfkarren/selene`, `lune-org/lune`, `red-blox/zap@0.6.29`, `JohnnyMorganz/luau-lsp`. Each tool's `--version` prints its pinned version.
- [ ] **Step 3:** `wally.toml`: package `lantern-tide/game`, realm `shared`, `private = true`. `[dependencies]`: React and ReactRoblox (`jsdotlua/react`, `jsdotlua/react-roblox`, newest 17.x on the registry). `[server-dependencies]`: ProfileStore `lm-loleris/profilestore@1.0.3`; if the registry lacks it, vendor `ProfileStore.luau` from MadStudioRoblox/ProfileStore into `src/server/Vendor/` and record that in the session log. `[dev-dependencies]`: Jest and JestGlobals (`jsdotlua/jest@3.10.0`, `jsdotlua/jest-globals@3.10.0`). `wally install` creates Packages/, ServerPackages/ and DevPackages/.
- [ ] **Step 4:** `default.project.json`, project name `LanternTide`, mapping exactly the instances under Interfaces.
- [ ] **Step 5:** `stylua.toml`: syntax Luau, column width 120, tabs, Unix line endings, AutoPreferDouble quotes, parentheses always. `selene.toml`: `std = "roblox"`.
- [ ] **Step 6:** `rojo build -o build/LanternTide.rbxl` prints "Built project".
- [ ] **Step 7:** `rojo plugin install` puts the matching plugin in `%LOCALAPPDATA%\Roblox\Plugins`.
- [ ] **Step 8:** Commit: "M0: pin toolchain, add Wally packages and Rojo project".

### Task 3: Studio sync

- [ ] **Step 1:** Start `rojo serve` in a Terminal tab; the user clicks Connect in Studio's Rojo panel.
- [ ] **Step 2:** `execute_luau` (Edit) finds every instance listed in Task 2's Interfaces.

### Task 4: Loader, test first

**Files:**
- Create: `tests/jest.config.luau`, `tests/RunTests.luau`, `tests/Loader.spec.luau`, `src/shared/Modules/Loader.luau`

**Interfaces:**
- Produces: `export type Module = { Init: (() -> ())?, Start: (() -> ())? }`, `export type Entry = { name: string, module: Module }`, `Loader.load(entries: { Entry }): ()`. Every `Init` runs synchronously in list order; then each `Start` runs in `task.spawn`, in list order. An `Init` error stops loading and is rethrown as `"<name>.Init failed: <message>"`.
- Produces: `RunTests(): { passed: number, failed: number, success: boolean }`. Run during Play with `return require(game.ServerStorage.Tests.RunTests)()`.

- [ ] **Step 1:** `tests/jest.config.luau` returns `{ testMatch = { "**/*.spec" } }`. `tests/RunTests.luau` errors with "Jest Lua needs debug.loadmodule: enable FFlagEnableLoadModule in Studio's ClientAppSettings.json" when `debug.loadmodule` is nil; otherwise it calls `Jest.runCLI(Tests, { ci = true, verbose = true }, { Tests }):awaitStatus()` and returns the counts.
- [ ] **Step 2:** Write `tests/Loader.spec.luau`:
  - "runs every Init in list order before any Start": entries A and B log to one table; `expect(log).toEqual({ "A.Init", "B.Init", "A.Start", "B.Start" })`.
  - "names the module whose Init fails and starts nothing": A's Init errors with "boom"; `expect(load).toThrow("A.Init failed")`, and the log has no Start entries.
  - "accepts modules with no Init or Start": `{ name = "Empty", module = {} }`; `expect(load).never.toThrow()`.
- [ ] **Step 3:** Play, then run RunTests through `execute_luau` (Server). Expected: it fails because `Shared.Modules.Loader` doesn't exist.
- [ ] **Step 4:** Implement `src/shared/Modules/Loader.luau` to the interface.
- [ ] **Step 5:** Run again. Expected: 3 passed, 0 failed. Stop Play.
- [ ] **Step 6:** StyLua and Selene clean. Commit: "M0: Loader with Jest Lua tests".

### Task 5: Entry scripts, AssetIds, SmokeTestService, playtest

**Files:**
- Create: `src/server/init.server.luau`, `src/client/init.client.luau`, `src/server/Services/SmokeTestService.luau`, `src/shared/Assets/AssetIds.luau`, `docs/playtests/2026-11-21 M0 loaders.md`

**Interfaces:**
- Consumes: `Loader.load`, `Loader.Entry` (Task 4).
- Produces: `AssetIds.Fish: { [string]: number }`, frozen and empty until Part B adds `FSH_KelpSnapper`. `SmokeTestService.Start(): ()`.

- [ ] **Step 1:** `init.server.luau` passes `{ { name = "SmokeTestService", module = require(script.Services.SmokeTestService) } }` to `Loader.load`, then prints `[Server] 1 services started`. `init.client.luau` passes an empty list and prints `[Client] 0 controllers started`.
- [ ] **Step 2:** `AssetIds.luau`: an empty frozen `Fish` table, with a header comment saying Claude adds an entry after each Studio MCP upload.
- [ ] **Step 3:** `SmokeTestService.Start`: return unless `RunService:IsStudio()`. With no ID, print `[SmokeTest] no FSH_KelpSnapper asset yet`. With an ID, call `InsertService:LoadAsset` inside `pcall` (warn on failure), anchor every part, rest the model on the baseplate 10 studs from the SpawnLocation, name it `FSH_KelpSnapper`, and print `[SmokeTest] FSH_KelpSnapper <id> loaded, size <x> x <y> x <z> studs`.
- [ ] **Step 4:** Checks: StyLua and Selene clean; `rojo sourcemap` then `luau-lsp analyze` with the Roblox definitions file (downloaded once, git-ignored) reports no errors; `rojo build` succeeds.
- [ ] **Step 5:** Playtest. The console shows `[Server] 1 services started`, `[SmokeTest] no FSH_KelpSnapper asset yet` and `[Client] 0 controllers started`, with no errors. Take a `screen_capture`, then stop Play.
- [ ] **Step 6:** Write the playtest note, update Status. Commit: "M0: server/client loaders, AssetIds, SmokeTestService".

### Task 6: Notes, commands, GitHub

- [ ] **Step 1:** notes-keeper writes decision notes and updates the PRD to match: uploads through the Studio MCP (§13 step 5, §14 Assets line, §15 API-key row); toolchain and layout (§14 layout and Tests row; §15 Blender 5.3, MCP for Blender, Rokit list with Zap and luau-lsp); the M0 gate (§16). The export-format note waits for Part B, which confirms the scale.
- [ ] **Step 2:** CLAUDE.md gets a Commands section: install, serve, lint, type-check, test, Blender headless.
- [ ] **Step 3:** Once the user supplies the GitHub URL: `git remote add origin <url>`, `git push -u origin main`.
- [ ] **Step 4:** Status's next step becomes Part B. Commit: "M0: decision notes, PRD sync, commands".

## Part B — art smoke test (next sitting)

### Task 7: Fish generator (blender-artist)

**Files:**
- Create: `art/blender/fish_gen.py`, `art/blender/palette.json`, `art/blender/specs/fish/kelp_snapper.json`, `art/blender/previews/FSH_KelpSnapper.png`
- Output, git-ignored: `art/blender/exports/FSH_KelpSnapper.glb`

- [ ] **Step 1:** `fish_gen.py` builds one fish from a JSON spec (body profile, fins, eyes, palette indices) in its own scene, maps every face into the 512 px atlas generated from `palette.json`, and exports GLB modeled in studs.
- [ ] **Step 2:** The same script runs headless: `& "E:\SteamLibrary\steamapps\common\Blender\blender.exe" -b -P art/blender/fish_gen.py -- --spec art/blender/specs/fish/kelp_snapper.json`.
- [ ] **Step 3:** Report triangles (300 to 1,500), size in studs, one lopsided feature and the preview PNG. Commit.

### Task 8: Upload and record

- [ ] **Step 1:** `open_cloud_invoke` POST `/assets/v1/assets` (Model, creator = the user's userId) with the GLB; poll the operation until done; moderation state Approved.
- [ ] **Step 2:** Add `FSH_KelpSnapper = <id>` to `AssetIds.Fish`. Commit.

### Task 9: Playtest and lock the export scale

- [ ] **Step 1:** Play. The console shows `[SmokeTest] FSH_KelpSnapper <id> loaded…`. Check against rbx-import-asset: MeshPart count matches; a texture is present (`TextureID` or `SurfaceAppearance.ColorMap`); size is within 10% of the expected studs; upright, with the lopsided feature on the expected side; anchored. `screen_capture`.
- [ ] **Step 2:** If anything is off, make one fix in fish_gen.py's export, re-export, re-upload, update AssetIds and check again.
- [ ] **Step 3:** Playtest note with both screenshots; notes-keeper writes the "GLB modeled in studs" decision and updates PRD §13. Commit.

### Task 10: Close M0

- [ ] **Step 1:** Ponytail review of the M0 changes; fix what it finds.
- [ ] **Step 2:** Status: M0 done, current milestone M1. Commit and push.
