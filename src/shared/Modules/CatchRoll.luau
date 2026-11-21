--!strict
-- Catch odds and rolls (PRD §4, §5). odds() is the one source of catch chances: roll() draws from it,
-- and the odds panel (PRD §11) will show it. Pure: no services; randomness comes in as a Random.
--
-- Tier first, then species: tiers keep PRD §5's chances, bait and luck raise Rare and above (Common
-- absorbs the difference), and a tier with no fish available here gives its chance to Common, so a
-- rare tier's absolute chance holds wherever that tier lives. Available fish share their tier evenly.

local Data = script.Parent.Parent.Data
local BaitData = require(Data.BaitData)
local FishData = require(Data.FishData)
local RarityData = require(Data.RarityData)
local RodData = require(Data.RodData)
local ZoneData = require(Data.ZoneData)

export type Context = {
	zoneId: string,
	spotId: string,
	castPower: number, -- 0 to 1
	rodId: string,
	baitId: string?,
	extraLuck: number?, -- luck from boosts (PRD §10, §11); none in M1
}

export type Catch = {
	speciesId: string,
	rarity: string,
	weightKg: number,
	biteTime: number, -- seconds
}

local CatchRoll = {}

local function lookup<T>(map: { [string]: T }, key: string, what: string): T
	local value = map[key]
	if value == nil then
		error(`CatchRoll: unknown {what} {key}`, 3)
	end
	return value
end

local function tierChances(context: Context): { [string]: number }
	local rod = lookup(RodData, context.rodId, "rod")
	local bait = if context.baitId then lookup(BaitData, context.baitId, "bait") else nil
	local boost = (1 + (rod.luck + (context.extraLuck or 0)) / 100) * (if bait then bait.rareMult else 1)
	local chances: { [string]: number } = {}
	local others = 0
	for _, tier in RarityData.order do
		if tier ~= "Common" then
			local chance = RarityData.baseChance[tier] * (if RarityData.boosted[tier] then boost else 1)
			chances[tier] = chance
			others += chance
		end
	end
	chances.Common = 1 - others
	if chances.Common < 0 then
		error("CatchRoll: modifiers push the Common chance below 0", 3)
	end
	return chances
end

function CatchRoll.odds(context: Context): { [string]: number }
	local zone = lookup(ZoneData, context.zoneId, "zone")
	lookup(zone.spots, context.spotId, "spot")
	local chances = tierChances(context)

	local byTier: { [string]: { FishData.Species } } = {}
	for _, species in FishData.list do
		if
			species.zone == context.zoneId
			and table.find(species.spots, context.spotId)
			and context.castPower >= species.minCast
		then
			byTier[species.rarity] = byTier[species.rarity] or {}
			table.insert(byTier[species.rarity], species)
		end
	end
	if not byTier.Common then
		error(`CatchRoll: no Common fish at {context.zoneId}/{context.spotId}`, 2)
	end

	local commonChance = chances.Common
	for _, tier in RarityData.order do
		if tier ~= "Common" and not byTier[tier] then
			commonChance += chances[tier]
		end
	end

	local odds: { [string]: number } = {}
	for tier, pool in byTier do
		local share = (if tier == "Common" then commonChance else chances[tier]) / #pool
		for _, species in pool do
			odds[species.id] = share
		end
	end
	return odds
end

function CatchRoll.roll(context: Context, rng: Random): Catch
	local odds = CatchRoll.odds(context)
	local zone = ZoneData[context.zoneId]
	local rod = RodData[context.rodId]
	local bait = if context.baitId then BaitData[context.baitId] else nil

	local biteMult = (1 - rod.lureSpeed / 200) * (if bait then bait.biteMult else 1)
	local biteTime = rng:NextNumber(zone.biteTime.min, zone.biteTime.max) * biteMult

	-- Walk FishData.list (not the odds map) so the same seed always picks the same fish.
	local pick = rng:NextNumber()
	local chosen: FishData.Species? = nil
	local last: FishData.Species? = nil
	for _, species in FishData.list do
		local p = odds[species.id]
		if p then
			last = species
			pick -= p
			if pick < 0 then
				chosen = species
				break
			end
		end
	end
	local species = (chosen or last) :: FishData.Species -- float rounding: the remainder goes to the last fish

	local u = rng:NextNumber()
	local range = species.weightKg
	local weightKg = math.round((range.min + (range.max - range.min) * u * u) * 100) / 100

	return {
		speciesId = species.id,
		rarity = species.rarity,
		weightKg = weightKg,
		biteTime = biteTime,
	}
end

return CatchRoll
