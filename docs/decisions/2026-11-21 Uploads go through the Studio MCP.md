# 2026-11-21 Uploads go through the Studio MCP
PRD section: §13 (Pipeline step 5), §14 (Project layout), §15 (Required table)
Was: An upload script (`tools/upload_assets.py`) used an Open Cloud API key stored in `.env` to upload assets and write their IDs into `AssetIds.luau`.
Now: Claude uploads through the Roblox Studio MCP's `open_cloud_invoke` tool (Open Cloud Assets API, `POST /assets/v1/assets`). The scopes `asset:read` and `asset:write` are granted in Studio's Assistant Settings, under MCP Permissions. Files must sit in an approved upload folder: `art/blender/exports`, `art/figma` or `art/audio`. Claude polls the operation until it is done, checks the moderation state, and records the ID in `src/shared/Assets/AssetIds.luau` by hand. No API key is needed. `tools/upload_assets.py` is built only if the MCP route can't do a job (for example unattended batch uploads). Uploads create permanent assets on the user's account; only the Creator Dashboard can archive them.
Why: There is no secret to manage. The scope probe already returned 200. One call per file covers batches. Studio's own import guide gives a verify-and-repair checklist to follow after insert.

Links: [[PRD]] · [[sessions/2026-11-21 2137 M0 foundations]]
