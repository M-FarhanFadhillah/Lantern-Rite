--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Data = ReplicatedStorage.Shared.Data
local FishData = require(Data.FishData)
local RarityData = require(Data.RarityData)
local ZoneData = require(Data.ZoneData)

local HARBOR = "DriftwoodHarbor"

describe("FishData", function()
	it("has the 12 Driftwood Harbor species with unique ids", function()
		local seen: { [string]: boolean } = {}
		local harbor = 0
		for _, species in FishData.list do
			expect(seen[species.id]).toBeNil()
			seen[species.id] = true
			if species.zone == HARBOR then
				harbor += 1
			end
		end
		expect(harbor).toBe(12)
	end)

	it("indexes every species by id", function()
		for _, species in FishData.list do
			expect(FishData.byId[species.id]).toBe(species)
		end
	end)

	it("gives every species valid fields", function()
		for _, species in FishData.list do
			local zone = ZoneData[species.zone]
			local range = RarityData.valueRange[species.rarity]
			local spotsKnown = zone ~= nil and #species.spots > 0
			if zone then
				for _, spot in species.spots do
					spotsKnown = spotsKnown and zone.spots[spot] ~= nil
				end
			end
			-- One record per species, so a failure names the fish.
			expect({
				id = species.id,
				spotsKnown = spotsKnown,
				rarityKnown = RarityData.baseChance[species.rarity] ~= nil,
				minCastOk = species.minCast >= 0 and species.minCast <= 1,
				weightOk = species.weightKg.min > 0 and species.weightKg.min < species.weightKg.max,
				difficultyOk = species.difficulty >= 1 and species.difficulty <= 10,
				valueInTier = range ~= nil and species.baseValue >= range.min and species.baseValue <= range.max,
				hasShape = #species.shape > 0,
				hasLore = #species.lore > 0,
				assetKey = species.assetKey,
			}).toEqual({
				id = species.id,
				spotsKnown = true,
				rarityKnown = true,
				minCastOk = true,
				weightOk = true,
				difficultyOk = true,
				valueInTier = true,
				hasShape = true,
				hasLore = true,
				assetKey = "FSH_" .. species.id,
			})
		end
	end)

	it("puts at least one Common at every Harbor spot", function()
		for spotId in ZoneData[HARBOR].spots do
			local hasCommon = false
			for _, species in FishData.list do
				if species.zone == HARBOR and species.rarity == "Common" and table.find(species.spots, spotId) then
					hasCommon = true
				end
			end
			expect({ spot = spotId, hasCommon = hasCommon }).toEqual({ spot = spotId, hasCommon = true })
		end
	end)
end)
