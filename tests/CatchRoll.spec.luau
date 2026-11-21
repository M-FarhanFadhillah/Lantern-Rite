--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Shared = ReplicatedStorage.Shared
local CatchRoll = require(Shared.Modules.CatchRoll)
local FishData = require(Shared.Data.FishData)
local ZoneData = require(Shared.Data.ZoneData)

local function ctx(spotId: string, castPower: number, baitId: string?, extraLuck: number?): CatchRoll.Context
	return {
		zoneId = "DriftwoodHarbor",
		spotId = spotId,
		castPower = castPower,
		rodId = "Driftwood",
		baitId = baitId,
		extraLuck = extraLuck,
	}
end

local function total(odds: { [string]: number }): number
	local sum = 0
	for _, p in odds do
		sum += p
	end
	return sum
end

describe("CatchRoll.odds", function()
	it("sums to 1 at every spot, for short and far casts", function()
		for spotId in ZoneData.DriftwoodHarbor.spots do
			for _, power in { 0.2, 0.9 } do
				expect(total(CatchRoll.odds(ctx(spotId, power)))).toBeCloseTo(1, 9)
			end
		end
	end)

	it("gives only the three pier commons at the pier, a third each", function()
		local odds = CatchRoll.odds(ctx("pier", 0.5))
		local ids = {}
		for id in odds do
			table.insert(ids, id)
		end
		table.sort(ids)
		expect(ids).toEqual({ "DockMinnow", "PlankPerch", "RopeSprat" })
		for _, p in odds do
			expect(p).toBeCloseTo(1 / 3, 9)
		end
	end)

	it("needs a far cast for Silt Whisker and Lampjaw", function()
		local short = CatchRoll.odds(ctx("open", 0.5))
		expect(short.SiltWhisker).toBeNil()
		expect(short.Lampjaw).toBeNil()
		local far = CatchRoll.odds(ctx("open", 0.9))
		expect(far.SiltWhisker).toBeCloseTo(0.12, 9)
		expect(far.Lampjaw).toBeCloseTo(0.055, 9)
	end)

	it("keeps the Wreckwarden at its 2% Legendary chance with a far cast at the wreck", function()
		expect(CatchRoll.odds(ctx("wreck", 0.9)).Wreckwarden).toBeCloseTo(0.02, 9)
		expect(CatchRoll.odds(ctx("wreck", 0.5)).Wreckwarden).toBeNil()
	end)

	it("raises Rare and above by 20% with Harbor Shrimp and leaves Uncommon alone", function()
		expect(CatchRoll.odds(ctx("open", 0.9, "HarborShrimp")).SiltWhisker).toBeCloseTo(0.144, 9)
		local rocks = CatchRoll.odds(ctx("rocks", 0.5, "HarborShrimp"))
		expect(rocks.KelpSnapper + rocks.ShellbackPuffer).toBeCloseTo(0.25, 9)
	end)

	it("rejects an unknown spot", function()
		expect(function()
			CatchRoll.odds(ctx("moon", 0.5))
		end).toThrow("unknown spot")
	end)

	it("rejects luck so high that Common would go below zero", function()
		expect(function()
			CatchRoll.odds(ctx("open", 0.9, nil, 2000))
		end).toThrow("below 0")
	end)
end)

describe("CatchRoll.roll", function()
	it("gives the same catch for the same seed", function()
		local a = CatchRoll.roll(ctx("wreck", 0.9), Random.new(42))
		local b = CatchRoll.roll(ctx("wreck", 0.9), Random.new(42))
		expect(a).toEqual(b)
	end)

	it("matches the odds over 10,000 rolls", function()
		local context = ctx("open", 0.9)
		local odds = CatchRoll.odds(context)
		local counts: { [string]: number } = {}
		local rng = Random.new(7)
		for _ = 1, 10000 do
			local id = CatchRoll.roll(context, rng).speciesId
			counts[id] = (counts[id] or 0) + 1
		end
		for id, p in odds do
			local share = (counts[id] or 0) / 10000
			expect({ id = id, close = math.abs(share - p) < 0.015 }).toEqual({ id = id, close = true })
		end
	end)

	it("keeps weight in the species range and bite time in the zone range", function()
		local rng = Random.new(3)
		for _ = 1, 500 do
			local catch = CatchRoll.roll(ctx("wreck", 0.9), rng)
			local range = FishData.byId[catch.speciesId].weightKg
			expect(catch.weightKg >= range.min and catch.weightKg <= range.max).toBe(true)
			expect(catch.biteTime >= 4 and catch.biteTime < 10).toBe(true)
			expect(catch.rarity).toBe(FishData.byId[catch.speciesId].rarity)
		end
	end)

	it("shortens the bite time with Harbor Shrimp", function()
		local rng = Random.new(5)
		for _ = 1, 200 do
			local catch = CatchRoll.roll(ctx("pier", 0.5, "HarborShrimp"), rng)
			expect(catch.biteTime >= 3.6 and catch.biteTime < 9).toBe(true)
		end
	end)
end)
