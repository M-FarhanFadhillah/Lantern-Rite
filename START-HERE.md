# Start here

This folder already has the PRD, CLAUDE.md, the model helpers (subagents) and the Obsidian vault.
Do these steps once, in order.

## 1. Install (once)
- [ ] Roblox Studio, Claude Code (`claude update` to get the latest), Git, Blender 4.x, Python 3.10+ and uv, Obsidian, VS Code (optional)

## 2. Obsidian
- [ ] Obsidian > Open folder as vault > pick this folder's `docs` subfolder. Start at `Home.md`.

## 3. Connect tools to Claude Code
- [ ] Roblox Studio: Assistant Settings > MCP Servers > Quick connect > turn on Claude Code
- [ ] Blender: install the blender-mcp add-on, then run `claude mcp add blender uvx blender-mcp`
- [ ] Figma: follow Figma's guide to add its MCP server to Claude Code

## 4. Open the project in the Claude desktop app (Code tab)
- [ ] Start a **Local** session (not cloud) with the folder `E:\Claude\Lantern-Tide`. Cloud sessions can't reach Blender, Studio or your E: drive.
- [ ] Model picker under the prompt box (Ctrl+Shift+I): pick **Opus**, and under **Effort** pick **Max**.
- [ ] Type `/mcp` (or ask "which MCP servers and tools do you have?") and check Roblox Studio, blender and figma are there. Authenticate Figma if asked.
- [ ] Plugins: **+** next to the prompt box > Plugins. Keep superpowers, design, andrej-karpathy-skills, ponytail, frontend-design; turn off vercel.

## 5. Before each session
- [ ] Roblox Studio open (for code and playtests); Blender open with the MCP panel showing "Connected" (only for art sessions).
- [ ] Closing the desktop app stops a local session. Claude saves progress to docs/Status.md and docs/sessions/ as it works, but type "save" before you close.

## Effort and ultracode (quick reference)
- **Default:** Opus, Effort **Max**, Ultracode **off**.
- **Big jobs only:** put `ultracode:` at the start of one prompt instead of turning the setting on. Approve or deny the card that shows the steps and token warning.
  - End of a milestone: `ultracode: audit every server service for exploits and missing validation, and verify each finding before reporting`
  - Mass art: `ultracode: generate all 15 Kelpshade Reef fish from their specs, export each, and check every one against the §13 budgets`
  - Hard decisions: `ultracode: draft the networking and anti-cheat plan for the catch flow from several angles and compare them`

## 6. First prompt
Switch the mode selector under the prompt box to **Plan** (Ctrl+Shift+M), then paste. After you approve the plan, switch to **Accept edits**.

```
Read CLAUDE.md and docs/PRD.md in full. This is my Roblox fishing game; we are
starting Milestone M0 "Foundations" (PRD §16). CLAUDE.md, .claude/agents/,
.claude/settings.json, .gitignore and the docs/ Obsidian vault already exist —
review them and suggest fixes, but don't rewrite them.

Plan first; don't write files until I approve. The plan should cover:

1. Project setup per PRD §14–15: git init, rokit.toml (Rojo 7.7+, Wally,
   StyLua, Selene, Lune, Zap), wally.toml (ProfileStore, React Lua, Jest Lua),
   default.project.json, and the folder layout from §14.
2. A minimal server service loader and client controller loader, with one
   example service and one passing Jest Lua test.
3. Check that the Roblox Studio, Blender and Figma MCP servers are connected,
   and tell me exactly what's missing if any aren't.
4. The M0 smoke test, using the blender-artist subagent: art/blender/fish_gen.py
   (low-poly, budgets in §13), one test fish from a JSON spec, a viewport
   screenshot, FBX export to art/blender/exports; then upload it and record
   the asset ID in src/shared/Assets/AssetIds.luau.
5. Uploads: Studio's MCP can upload to Open Cloud from art/blender/exports,
   art/figma and art/audio. Prefer that over writing tools/upload_assets.py;
   only build the script (and ask me for an API key) if the MCP route can't do
   what we need, such as batch uploads or recording asset IDs.
6. Ask notes-keeper to add a decisions note for anything we change.

Ask me anything you need before you start.
```

## 7. Only if Claude Code asks for a Roblox API key
- [ ] Create an Open Cloud API key (Assets read + write) on the Creator Dashboard and paste it into a `.env` file here yourself. Never paste it into the chat.
