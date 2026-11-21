--!strict
-- Fish species (PRD §5). Names and lore approved 2026-11-22: docs/lore/Driftwood Harbor fish.md.
-- Tuning only: CatchRoll reads it, PriceCalc (M1 session 5) applies weight and Perfect to baseValue.

local RarityData = require(script.Parent.RarityData)

export type Species = {
	id: string,
	displayName: string,
	zone: string,
	rarity: RarityData.Rarity,
	spots: { string },
	minCast: number, -- cast power (0 to 1) needed before it bites
	weightKg: { min: number, max: number },
	baseValue: number, -- coins
	shape: { { number } }, -- cargo cells as {x, y}
	difficulty: number, -- track-bar difficulty, 1 to 10
	lore: string,
	assetKey: string, -- AssetIds key: "FSH_" .. id
}

local FAR = 0.7 -- cast power for "far cast" fish

-- Cargo shapes (PRD §6).
local ONE = { { 0, 0 } }
local TWO = { { 0, 0 }, { 1, 0 } }
local SQUARE = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
local ELL = { { 0, 0 }, { 0, 1 }, { 1, 1 } }
local THREE = { { 0, 0 }, { 1, 0 }, { 2, 0 } }
local LARGE = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } }

local list: { Species } = {
	{
		id = "DockMinnow",
		displayName = "Dock Minnow",
		zone = "DriftwoodHarbor",
		rarity = "Common",
		spots = { "pier" },
		minCast = 0,
		weightKg = { min = 0.05, max = 0.2 },
		baseValue = 6,
		shape = ONE,
		difficulty = 1,
		lore = "Schools around the pilings; every new angler's first catch.",
		assetKey = "FSH_DockMinnow",
	},
	{
		id = "RopeSprat",
		displayName = "Rope Sprat",
		zone = "DriftwoodHarbor",
		rarity = "Common",
		spots = { "pier" },
		minCast = 0,
		weightKg = { min = 0.04, max = 0.15 },
		baseValue = 7,
		shape = ONE,
		difficulty = 1,
		lore = "Thin as twine; hides in coiled mooring lines.",
		assetKey = "FSH_RopeSprat",
	},
	{
		id = "PlankPerch",
		displayName = "Plank Perch",
		zone = "DriftwoodHarbor",
		rarity = "Common",
		spots = { "pier", "open", "wreck" },
		minCast = 0,
		weightKg = { min = 0.3, max = 1.2 },
		baseValue = 12,
		shape = TWO,
		difficulty = 2,
		lore = "Flat-sided; rests under floating planks and driftwood.",
		assetKey = "FSH_PlankPerch",
	},
	{
		id = "TidelineHerring",
		displayName = "Tideline Herring",
		zone = "DriftwoodHarbor",
		rarity = "Common",
		spots = { "open", "rocks", "lighthouse" },
		minCast = 0,
		weightKg = { min = 0.2, max = 0.8 },
		baseValue = 15,
		shape = TWO,
		difficulty = 2,
		lore = "Follows the seam where calm harbor water meets the tide.",
		assetKey = "FSH_TidelineHerring",
	},
	{
		id = "KelpSnapper",
		displayName = "Kelp Snapper",
		zone = "DriftwoodHarbor",
		rarity = "Uncommon",
		spots = { "rocks" },
		minCast = 0,
		weightKg = { min = 0.8, max = 3 },
		baseValue = 32,
		shape = TWO,
		difficulty = 3,
		lore = "Teal back, kelp-green bands; snaps at anything that drifts by.",
		assetKey = "FSH_KelpSnapper",
	},
	{
		id = "RustfinBream",
		displayName = "Rustfin Bream",
		zone = "DriftwoodHarbor",
		rarity = "Uncommon",
		spots = { "wreck" },
		minCast = 0,
		weightKg = { min = 0.6, max = 2.5 },
		baseValue = 38,
		shape = TWO,
		difficulty = 3,
		lore = "Its fins went rust-red from nibbling the old anchors.",
		assetKey = "FSH_RustfinBream",
	},
	{
		id = "ShellbackPuffer",
		displayName = "Shellback Puffer",
		zone = "DriftwoodHarbor",
		rarity = "Uncommon",
		spots = { "rocks" },
		minCast = 0,
		weightKg = { min = 0.5, max = 2 },
		baseValue = 48,
		shape = SQUARE,
		difficulty = 4,
		lore = "Puffs up when hooked; its spots look like barnacles.",
		assetKey = "FSH_ShellbackPuffer",
	},
	{
		id = "DriftwireEel",
		displayName = "Driftwire Eel",
		zone = "DriftwoodHarbor",
		rarity = "Rare",
		spots = { "wreck" },
		minCast = 0,
		weightKg = { min = 1, max = 4 },
		baseValue = 95,
		shape = ELL,
		difficulty = 5,
		lore = "Coils inside rotten rope and slips loose if you ease off.",
		assetKey = "FSH_DriftwireEel",
	},
	{
		id = "SiltWhisker",
		displayName = "Silt Whisker",
		zone = "DriftwoodHarbor",
		rarity = "Rare",
		spots = { "open" },
		minCast = FAR,
		weightKg = { min = 2, max = 8 },
		baseValue = 110,
		shape = THREE,
		difficulty = 5,
		lore = "A bottom-feeder whose long whiskers stir the silt.",
		assetKey = "FSH_SiltWhisker",
	},
	{
		id = "Lampjaw",
		displayName = "Lampjaw",
		zone = "DriftwoodHarbor",
		rarity = "Epic",
		spots = { "open" },
		minCast = FAR,
		weightKg = { min = 4, max = 14 },
		baseValue = 320,
		shape = THREE,
		difficulty = 6,
		lore = "A lean hunter with a pale glow at the tip of its jaw.",
		assetKey = "FSH_Lampjaw",
	},
	{
		id = "Wreckwarden",
		displayName = "Wreckwarden",
		zone = "DriftwoodHarbor",
		rarity = "Legendary",
		spots = { "wreck" },
		minCast = FAR,
		weightKg = { min = 25, max = 90 },
		baseValue = 950,
		shape = LARGE,
		difficulty = 8,
		lore = "A vast grouper that has guarded the sunken barge for decades.",
		assetKey = "FSH_Wreckwarden",
	},
	{
		id = "Wickfin",
		displayName = "Wickfin",
		zone = "DriftwoodHarbor",
		rarity = "Mythic",
		spots = { "lighthouse" },
		minCast = 0,
		weightKg = { min = 0.1, max = 0.3 },
		baseValue = 3800,
		shape = ONE,
		difficulty = 7,
		lore = "Old sailors swear it glowed whenever the Lantern burned.",
		assetKey = "FSH_Wickfin",
	},
}

local byId: { [string]: Species } = {}
for _, species in list do
	byId[species.id] = species
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
