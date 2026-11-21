--!strict
-- Rods (PRD §4 rod stats). M1: the starter rod and one upgrade from the tackle shop.

export type Rod = {
	displayName: string,
	control: number, -- larger catch bar
	resilience: number, -- slower progress drain
	lineStrength: number, -- tension reels (later)
	reelSpeed: number, -- faster progress gain
	lureSpeed: number, -- shorter wait for bites: bite time × (1 - lureSpeed / 200)
	luck: number, -- Rare and above × (1 + luck / 100)
	price: number, -- coins
}

local RodData: { [string]: Rod } = {
	Driftwood = {
		displayName = "Driftwood Rod",
		control = 10,
		resilience = 0,
		lineStrength = 10,
		reelSpeed = 10,
		lureSpeed = 0,
		luck = 0,
		price = 0,
	},
	Brassline = {
		displayName = "Brassline Rod",
		control = 20,
		resilience = 10,
		lineStrength = 20,
		reelSpeed = 15,
		lureSpeed = 20,
		luck = 10,
		price = 400,
	},
}

return table.freeze(RodData)
