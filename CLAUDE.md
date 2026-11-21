# Lantern Tide — Roblox fishing game

Read docs/PRD.md before planning any feature. Current milestone: **M0 Foundations** (PRD §16).
Solo developer, experienced in Luau. Platforms: PC and mobile.

## Stack
Rojo 7.7+ · Luau `--!strict` · Wally · Rokit · StyLua + Selene · Zap · ProfileStore · React Lua · Jest Lua · Input Action System

## Rules
- Server is authoritative for every roll, coin and item. Clients never send prices, odds or rewards.
- Game data lives in src/shared/Data/*. Never hard-code tuning in systems.
- Pure logic (CatchRoll, PriceCalc, CargoGrid) gets Jest Lua tests before it is used.
- Run stylua and selene before every commit; fix all warnings.
- After each feature: playtest through the Roblox Studio MCP (start play, read the console, screen_capture), then report what you saw.
- Art: generate with art/blender/*.py through the Blender MCP; low-poly palette style; respect PRD §13 budgets. Export GLB modeled in studs (1 Blender unit = 1 stud). Blender 5.3 (Steam) is not on PATH; headless runs use `E:\SteamLibrary\steamapps\common\Blender\blender.exe`. Upload through the Roblox Studio MCP (allowed upload folders: art/blender/exports, art/figma, art/audio). Use tools/upload_assets.py only if the MCP route cannot do the job. Never commit .env or print API keys.
- UI: design in Figma first (file "Lantern Tide UI"), then build with React Lua.
- Paid luck boosts are paid random items: the odds panel (PRD §11) must exist before any luck product ships.
- All names, fish, characters and lore are original. Never copy Fisch or DREDGE content.

## Workflow
- Use superpowers skills: brainstorm and write a plan before each feature, TDD for pure logic, verification before claiming anything is done.
- One system per session. Keep changes small and surgical.
- At the end of a milestone, run a ponytail review or audit.

## Subagents (.claude/agents/)
- notes-keeper (sonnet): decision notes, the PRD updates that go with them, and notes lookups. The main session writes docs/Status.md and the session log itself, because it has the context.
- Explore (inherits the main model): read-only search.
- ui-designer (opus, max effort): Figma UI work.
- blender-artist (opus, max effort): Blender generators and 3D exports.
- All design and code work runs on Opus. Never hand game code to a cheaper model.

## Notes
docs/ is an Obsidian vault and the design source of truth. Use [[wikilinks]].
After each playtest, add a dated note in docs/playtests/. Record design changes in docs/decisions/ and update docs/PRD.md to match.

## Save everything to the vault (do not skip)
Usage or the session can end at any moment without warning, so never batch saving for the end.
- docs/Status.md is the single "where are we" note: current milestone, what is done, what is in progress, the exact next step, open questions and blockers. Update it after EVERY completed task or decision, not only at the end.
- Keep one log note per session in docs/sessions/, named `YYYY-MM-DD HHmm <topic>.md` (template in docs/sessions/README.md). Create it at the start of the session and append to it as you go: what changed (files), commands run, results, problems hit, decisions made.
- Design changes: add a note in docs/decisions/ and update docs/PRD.md in the same step.
- Commit to git after each working change, with a message that matches the session log entry.
- When I say "save", "wrap up", or before /clear or /compact, or when the context is getting long: stop, bring Status.md and the session log fully up to date, commit, then tell me it is saved.
- At the start of every session: read docs/Status.md and the latest note in docs/sessions/ before doing anything else, and continue from "Next step".

## Effort and ultracode
- Sessions run on Opus at Max effort: pick Max in the model menu when a session starts. settings.json can only store up to `xhigh`, so that is the fallback. Ultracode stays OFF by default: most work here is focused, step-by-step systems where one careful line of reasoning is best, and ultracode burns usage limits fast.
- Never turn ultracode on yourself and never start a workflow unless my prompt includes the keyword `ultracode` or asks for a workflow.
- If a task is large and splits into many independent pieces (end-of-milestone audits, batch-generating a zone's fish, comparing several designs for a hard decision), suggest using `ultracode:` and wait for me to say yes.
- When a workflow runs, use the strongest model only for stages that need judgement, and log the run in the session note.
