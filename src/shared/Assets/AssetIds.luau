--!strict
-- Roblox asset IDs for uploaded art, keyed by export name (FSH_*, BOT_*, ROD_*, PRP_*).
-- Claude adds an entry after each upload through the Studio MCP (Open Cloud); there is no
-- upload script. Note each entry's source spec and upload date beside it.

export type AssetIds = {
	Fish: { [string]: number },
}

local AssetIds: AssetIds = {
	Fish = table.freeze({}),
}

return table.freeze(AssetIds)
