--!strict
-- Rarity tiers (PRD §5): base catch chances before modifiers, and sell-value ranges in coins.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

local RarityData = {
	order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { Rarity },

	-- Chance of each tier before modifiers; sums to 1.
	baseChance = {
		Common = 0.55,
		Uncommon = 0.25,
		Rare = 0.12,
		Epic = 0.055,
		Legendary = 0.02,
		Mythic = 0.005,
	} :: { [string]: number },

	-- Tiers that bait and rod luck raise ("Rare and above").
	boosted = {
		Rare = true,
		Epic = true,
		Legendary = true,
		Mythic = true,
	} :: { [string]: boolean },

	valueRange = {
		Common = { min = 5, max = 30 },
		Uncommon = { min = 25, max = 80 },
		Rare = { min = 70, max = 250 },
		Epic = { min = 200, max = 900 },
		Legendary = { min = 800, max = 4000 },
		Mythic = { min = 3500, max = 20000 },
	} :: { [string]: { min: number, max: number } },
}

return table.freeze(RarityData)
