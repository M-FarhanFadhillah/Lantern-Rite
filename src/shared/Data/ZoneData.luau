--!strict
-- Fishing zones and their spots (PRD §5). M1 has Driftwood Harbor only.

export type Spot = { displayName: string }

export type Zone = {
	displayName: string,
	biteTime: { min: number, max: number }, -- seconds before rod and bait modifiers
	spots: { [string]: Spot },
}

local ZoneData: { [string]: Zone } = {
	DriftwoodHarbor = {
		displayName = "Driftwood Harbor",
		biteTime = { min = 4, max = 10 }, -- short enough for a first catch within 60 s (PRD §2)
		spots = {
			pier = { displayName = "The Pier" },
			open = { displayName = "Open Water" },
			rocks = { displayName = "Kelp Rocks" },
			wreck = { displayName = "The Sunken Barge" },
			lighthouse = { displayName = "Lighthouse Rocks" },
		},
	},
}

return table.freeze(ZoneData)
