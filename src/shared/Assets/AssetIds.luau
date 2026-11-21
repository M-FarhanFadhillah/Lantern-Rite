--!strict
-- Roblox asset IDs for uploaded art, keyed by export name (FSH_*, BOT_*, ROD_*, PRP_*).
-- Claude adds an entry after each upload through the Studio MCP (Open Cloud); there is no
-- upload script. Note each entry's source spec and upload date beside it.

export type AssetIds = {
	Fish: { [string]: number },
}

local AssetIds: AssetIds = {
	Fish = table.freeze({
		-- art/blender/specs/fish/kelp_snapper.json, uploaded 2026-11-22 (M0 test fish). Replaces
		-- 85973780481219, which faced backwards (head +Z); that asset is unused.
		FSH_KelpSnapper = 87926189441992,
	}),
}

return table.freeze(AssetIds)
