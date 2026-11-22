--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Shared = ReplicatedStorage.Shared
local RodData = require(Shared.Data.RodData)
local TrackBarSim = require(Shared.Modules.TrackBarSim)
local ReelBot = require(ServerStorage.Tests.ReelBot)

-- A fish that never moves (it stays at 0.5), with the given bar size and rates.
local function still(barSize: number, gainRate: number, drainRate: number): TrackBarSim.Tuning
	return { barSize = barSize, fishSpeed = 0, moveInterval = 1, gainRate = gainRate, drainRate = drainRate }
end

-- Steps `ticks` times with the same input; returns the set of events seen.
local function run(sim: TrackBarSim.Sim, ticks: number, holding: boolean): { [string]: boolean }
	local seen = {}
	for _ = 1, ticks do
		local event = TrackBarSim.step(sim, holding)
		if event then
			seen[event] = true
		end
	end
	return seen
end

describe("TrackBarSim.tuning", function()
	it("makes harder fish faster, jumpier and slower to land, and lets the rod help", function()
		local easy = TrackBarSim.tuning(1, RodData.Driftwood)
		expect(easy.barSize).toBeCloseTo(0.22, 9)
		expect(easy.fishSpeed).toBeCloseTo(0.25, 9)
		expect(easy.moveInterval).toBeCloseTo(1.6, 9)
		expect(easy.gainRate).toBeCloseTo(0.154, 9)
		expect(easy.drainRate).toBeCloseTo(0.10, 9)
		local hard = TrackBarSim.tuning(10, RodData.Brassline)
		expect(hard.barSize).toBeCloseTo(0.26, 9)
		expect(hard.fishSpeed).toBeCloseTo(0.75, 9)
		expect(hard.moveInterval).toBeCloseTo(0.6, 9)
		expect(hard.gainRate).toBeCloseTo(0.115, 9)
		expect(hard.drainRate).toBeCloseTo(0.133, 9)
	end)
end)

describe("TrackBarSim.step", function()
	it("lifts the bar while held, lets it fall when released, and keeps it on the track", function()
		local sim = TrackBarSim.new(still(0.2, 0.1, 0.01), 1)
		run(sim, 300, true)
		expect(sim.barPos).toBeCloseTo(0.8, 9)
		run(sim, 300, false)
		expect(sim.barPos).toBe(0)
	end)

	it("moves the fish by its seed only, and keeps it on the track", function()
		local tuning = TrackBarSim.tuning(5, RodData.Driftwood)
		local a, b, c = TrackBarSim.new(tuning, 7), TrackBarSim.new(tuning, 7), TrackBarSim.new(tuning, 8)
		local same, differs, onTrack = true, false, true
		for i = 1, 600 do
			local holding = i % 50 < 25
			TrackBarSim.step(a, holding)
			TrackBarSim.step(b, holding)
			TrackBarSim.step(c, holding)
			same = same and a.fishPos == b.fishPos
			differs = differs or a.fishPos ~= c.fishPos
			onTrack = onTrack and a.fishPos >= 0 and a.fishPos <= 1
		end
		expect(same).toBe(true)
		expect(differs).toBe(true)
		expect(onTrack).toBe(true)
	end)

	it("fills progress while the fish is in the bar and drains it outside", function()
		local inBar = TrackBarSim.new(still(1, 0.1, 0.05), 1)
		run(inBar, 60, false)
		expect(inBar.progress).toBeCloseTo(0.4, 6)
		local outside = TrackBarSim.new(still(0.2, 0.1, 0.05), 1)
		run(outside, 60, false)
		expect(outside.progress).toBeCloseTo(0.25, 6)
	end)

	it("lands the fish at full progress and loses it at empty", function()
		local caught = TrackBarSim.new(still(1, 0.7, 0.05), 1)
		expect(run(caught, 100, false).Caught).toBe(true)
		local lost = TrackBarSim.new(still(0.2, 0.1, 0.3), 1)
		expect(run(lost, 100, false).Escaped).toBe(true)
		expect(lost.outcome).toBe("Escaped")
	end)

	it("counts a miss only after the settle-in and the grace, once per stretch outside", function()
		local sim = TrackBarSim.new(still(0.2, 0.1, 0.01), 1)
		run(sim, 75, false)
		expect(sim.misses).toBe(0)
		expect(run(sim, 1, false).Miss).toBe(true)
		expect(sim.misses).toBe(1)
		run(sim, 224, false)
		expect(sim.misses).toBe(1)
		-- Hold until the bar reaches the fish: a hit. Keep holding: the bar rises past the fish and
		-- parks at the top, one more stretch outside, so one more miss.
		local hit = false
		while sim.barPos + 0.2 < 0.5 do
			hit = TrackBarSim.step(sim, true) == "Hit" or hit
		end
		expect(hit).toBe(true)
		run(sim, 200, true)
		expect(sim.misses).toBe(2)
	end)

	it("lets the fish escape after 90 seconds", function()
		local sim = TrackBarSim.new(still(0.2, 0, 0), 1)
		run(sim, 5399, false)
		expect(sim.outcome).toBeNil()
		expect(run(sim, 1, false).Escaped).toBe(true)
		expect(sim.tick).toBe(5400)
	end)
end)

describe("TrackBarSim.replay", function()
	it("replays a live run exactly", function()
		local tuning = TrackBarSim.tuning(3, RodData.Driftwood)
		local toggles, live = ReelBot.play(tuning, 11)
		expect(#toggles > 0).toBe(true)
		expect(TrackBarSim.replay(tuning, 11, toggles)).toEqual(live)
	end)

	it("marks a caught reel with no misses Perfect, and one with a miss not", function()
		local clean = TrackBarSim.replay(still(1, 0.7, 0.05), 1, {}) :: TrackBarSim.Result
		expect(clean.outcome).toBe("Caught")
		expect(clean.perfect).toBe(true)
		local toggles, late = ReelBot.play(still(0.3, 0.5, 0.01), 1, 90)
		expect(late.outcome).toBe("Caught")
		expect(late.misses >= 1).toBe(true)
		expect((TrackBarSim.replay(still(0.3, 0.5, 0.01), 1, toggles) :: TrackBarSim.Result).perfect).toBe(false)
	end)

	it("refuses toggles that don't strictly increase, aren't whole ticks, or run past the end", function()
		local tuning = still(1, 0.7, 0.05) -- caught at about tick 60
		expect(TrackBarSim.replay(tuning, 1, { 5, 5 })).toBeNil()
		expect(TrackBarSim.replay(tuning, 1, { 10, 3 })).toBeNil()
		expect(TrackBarSim.replay(tuning, 1, { -1 })).toBeNil()
		expect(TrackBarSim.replay(tuning, 1, { 5.5 })).toBeNil()
		expect(TrackBarSim.replay(tuning, 1, { 500 })).toBeNil()
	end)
end)
