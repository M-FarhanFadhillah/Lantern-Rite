# 2026-11-21 Unit tests run in Studio Edit mode
PRD section: §14 (Stack table, "Tests" row)
Was: Jest Lua unit tests for pure modules (rolls, pricing, cargo packing); playtest scripts run through the Studio MCP server.
Now: Jest Lua specs live in `tests/` (synced to `ServerStorage.Tests`; spec modules are named `*.spec`; `tests/jest.config.luau` sets `testMatch`). They run in Studio Edit mode through the Studio MCP: `execute_luau` with datamodel Edit, running `return require(game.ServerStorage.Tests.RunTests:Clone())()`.
- Jest needs Studio's `FFlagEnableLoadModule` (for `debug.loadmodule`). `tools/enable-jest-flag.ps1` writes it into Studio's `ClientSettings\ClientAppSettings.json`. Each Studio update drops the flag, so re-run the script and restart Studio.
- Jest can't run during Play. The game's own scripts load the same modules in the game VM while `execute_luau` runs in the plugin VM, and Jest fails with "Attempt to migrate WeakObjectRef across VM boundary".
- `RunTests` computes success itself, because Jest Lua 3.10.0's `results.success` is inverted (jest-core `TestScheduler.lua` line 434 is missing a `not`).
- Playtests (Play, read the console, `screen_capture`) stay a separate step.
Why: It is the only route that works. Edit-mode runs are also faster than starting a playtest.

Links: [[PRD]] · [[sessions/2026-11-21 2137 M0 foundations]]
