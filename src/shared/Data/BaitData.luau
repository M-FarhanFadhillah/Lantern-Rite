--!strict
-- Bait (PRD §9): consumable, bought with coins. M1 has one.

export type Bait = {
	displayName: string,
	rareMult: number, -- multiplies Rare-and-above chances
	biteMult: number, -- multiplies bite time
	price: number, -- coins per bait
}

local BaitData: { [string]: Bait } = {
	HarborShrimp = {
		displayName = "Harbor Shrimp",
		rareMult = 1.2,
		biteMult = 0.9,
		price = 15,
	},
}

return table.freeze(BaitData)
