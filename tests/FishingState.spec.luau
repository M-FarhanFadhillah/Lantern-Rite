--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Shared = ReplicatedStorage.Shared
local CatchRoll = require(Shared.Modules.CatchRoll)
local FishingState = require(Shared.Modules.FishingState)
local FishingTuning = require(Shared.Data.FishingTuning)
local RodData = require(Shared.Data.RodData)
local TrackBarSim = require(Shared.Modules.TrackBarSim)
local ReelBot = require(ServerStorage.Tests.ReelBot)

local ALLOWANCE = FishingTuning.latencyAllowance
local NAN = math.huge - math.huge

-- Every test cast carries a reel. LANDED: a bar as tall as the track, so the still fish is landed
-- with no misses at about tick 60. LOST: the bar sits under the still fish, which escapes at about
-- tick 60.
local LANDED: FishingState.Reel = {
	seed = 1,
	tuning = { barSize = 1, fishSpeed = 0, moveInterval = 1, gainRate = 0.7, drainRate = 0.05 },
}
local LOST: FishingState.Reel = {
	seed = 1,
	tuning = { barSize = 0.2, fishSpeed = 0, moveInterval = 1, gainRate = 0.1, drainRate = 0.3 },
}

-- A Dock Minnow (difficulty 1, so a 0.9 s window) that bites 5 seconds after the cast.
local function minnow(): CatchRoll.Catch
	return { speciesId = "DockMinnow", rarity = "Common", weightKg = 0.1, biteTime = 5 }
end

-- Both results of cast() or canCast(), as one record.
local function castResult(ok: boolean, reason: string?): { ok: boolean, reason: string? }
	return { ok = ok, reason = reason }
end

-- Cast at 0 with token "t1"; the minnow bites at 5.
local function biting(): FishingState.State
	local state = FishingState.new()
	FishingState.cast(state, 0, "t1", minnow(), LANDED)
	FishingState.bite(state, 5)
	return state
end

describe("FishingState.cast", function()
	it("casts from Idle", function()
		local state = FishingState.new()
		expect(castResult(FishingState.cast(state, 0, "t1", minnow(), LANDED))).toEqual({ ok = true })
		expect(state.phase).toBe("Waiting")
	end)

	it("refuses a second cast while the line is out and keeps the first", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		expect(castResult(FishingState.cast(state, 10, "t2", minnow(), LANDED))).toEqual({ ok = false, reason = "Busy" })
		expect(state.token).toBe("t1")
	end)

	it("refuses a cast within the cooldown after the last cast", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		FishingState.reelIn(state)
		local early = FishingTuning.castCooldown - 0.01
		expect(castResult(FishingState.canCast(state, early))).toEqual({ ok = false, reason = "Cooldown" })
		expect(castResult(FishingState.cast(state, early, "t2", minnow(), LANDED))).toEqual({
			ok = false,
			reason = "Cooldown",
		})
		expect(castResult(FishingState.cast(state, FishingTuning.castCooldown, "t2", minnow(), LANDED))).toEqual({
			ok = true,
		})
	end)
end)

describe("FishingState.bite", function()
	it("comes at the bite time, not before", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		expect(FishingState.bite(state, 4.99)).toBeNil()
		expect(state.phase).toBe("Waiting")
		expect(FishingState.bite(state, 5)).toBeCloseTo(0.9, 9)
		expect(state.phase).toBe("Biting")
	end)

	it("comes only once", function()
		expect(FishingState.bite(biting(), 6)).toBeNil()
	end)

	it("gives a harder fish a shorter window", function()
		local state = FishingState.new()
		FishingState.cast(
			state,
			0,
			"t1",
			{ speciesId = "Wreckwarden", rarity = "Legendary", weightKg = 40, biteTime = 5 },
			LANDED
		)
		expect(FishingState.bite(state, 5)).toBeCloseTo(0.62, 9)
	end)
end)

describe("FishingState.hook", function()
	it("hooks inside the window plus the latency allowance and starts the reel", function()
		local state = biting()
		expect((FishingState.hook(state, 5 + 0.9 + ALLOWANCE, "t1"))).toBe("Hooked")
		expect(state.phase).toBe("Reeling")
	end)

	it("misses after the window plus the allowance", function()
		local state = biting()
		expect((FishingState.hook(state, 5 + 0.9 + ALLOWANCE + 0.01, "t1"))).toBe("Missed")
		expect(state.phase).toBe("Idle")
	end)

	it("starts the window when the bite is sent, even a frame late", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		FishingState.bite(state, 5.02)
		expect((FishingState.hook(state, 5.02 + 0.9 + ALLOWANCE, "t1"))).toBe("Hooked")
	end)

	it("rejects a wrong token and leaves the bite alone", function()
		local state = biting()
		expect((FishingState.hook(state, 5.1, "forged"))).toBe("Rejected")
		expect(state.phase).toBe("Biting")
		expect((FishingState.hook(state, 5.2, "t1"))).toBe("Hooked")
	end)

	it("rejects an old cast's token after a new cast", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "old", minnow(), LANDED)
		FishingState.reelIn(state)
		FishingState.cast(state, 1, "new", minnow(), LANDED)
		FishingState.bite(state, 6)
		expect((FishingState.hook(state, 6.1, "old"))).toBe("Rejected")
		expect(state.token).toBe("new")
		expect(state.phase).toBe("Biting")
	end)

	it("rejects a hook before the bite", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		expect((FishingState.hook(state, 1, "t1"))).toBe("Rejected")
		expect(state.phase).toBe("Waiting")
	end)
end)

describe("FishingState.expire", function()
	it("releases a bite once the window and the allowance have passed", function()
		local state = biting()
		expect(FishingState.expire(state, 5 + 0.9 + ALLOWANCE)).toBeNil()
		expect(FishingState.expire(state, 5 + 0.9 + ALLOWANCE + 0.01)).toBe("Missed")
		expect(state.phase).toBe("Idle")
	end)

	it("leaves a waiting line alone", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		expect(FishingState.expire(state, 100)).toBeNil()
		expect(state.phase).toBe("Waiting")
	end)
end)

-- Cast at 0 with this reel, bite at 5, hook at 5.1: the reel starts at 5.1.
local function reeling(reel: FishingState.Reel): FishingState.State
	local state = FishingState.new()
	FishingState.cast(state, 0, "t1", minnow(), reel)
	FishingState.bite(state, 5)
	FishingState.hook(state, 5.1, "t1")
	return state
end

describe("FishingState.reel", function()
	it("lands the fish when the replay agrees, with the replay's Perfect", function()
		local state = reeling(LANDED)
		local verdict, catch, perfect = FishingState.reel(state, 5.1 + 2, "t1", {}, "Caught")
		expect(verdict).toBe("Caught")
		expect(catch and catch.speciesId).toBe("DockMinnow")
		expect(perfect).toBe(true)
		expect(state.phase).toBe("Idle")
	end)

	it("settles a real player's reel the way the replay does", function()
		local real: FishingState.Reel = { seed = 11, tuning = TrackBarSim.tuning(3, RodData.Driftwood) }
		local toggles, live = ReelBot.play(real.tuning, real.seed)
		local verdict, _, perfect = FishingState.reel(reeling(real), 5.1 + live.ticks / 60, "t1", toggles, live.outcome)
		expect(verdict).toBe(live.outcome)
		expect(perfect).toBe(live.perfect)
	end)

	it("loses the fish when the replay says it escaped", function()
		local verdict, catch = FishingState.reel(reeling(LOST), 5.1 + 2, "t1", {}, "Escaped")
		expect(verdict).toBe("Escaped")
		expect(catch).toBeNil()
	end)

	it("rejects a claim the replay doesn't reproduce, and the fish escapes", function()
		local state = reeling(LOST)
		expect((FishingState.reel(state, 5.1 + 2, "t1", {}, "Caught"))).toBe("Forged")
		expect(state.phase).toBe("Idle")
	end)

	it("rejects toggles the replay can't use", function()
		expect((FishingState.reel(reeling(LANDED), 5.1 + 2, "t1", { 3, 3 }, "Caught"))).toBe("Forged")
	end)

	it("rejects a result that comes back faster than the reel could take", function()
		expect((FishingState.reel(reeling(LANDED), 5.1 + 0.1, "t1", {}, "Caught"))).toBe("Forged")
	end)

	it("ignores a wrong token mid-reel", function()
		local state = reeling(LANDED)
		expect((FishingState.reel(state, 5.1 + 2, "nope", {}, "Caught"))).toBe("Rejected")
		expect(state.phase).toBe("Reeling")
	end)

	it("lets a reel with no result escape after 95 seconds", function()
		local state = reeling(LANDED)
		expect(FishingState.expire(state, 5.1 + 94.9)).toBeNil()
		expect(FishingState.expire(state, 5.1 + 95.1)).toBe("Escaped")
		expect(state.phase).toBe("Idle")
	end)
end)

describe("FishingState.reelIn", function()
	it("cancels a waiting line, so no bite comes", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow(), LANDED)
		expect(FishingState.reelIn(state)).toBe(true)
		expect(state.phase).toBe("Idle")
		expect(FishingState.bite(state, 10)).toBeNil()
	end)

	it("does nothing when no line is out", function()
		expect(FishingState.reelIn(FishingState.new())).toBe(false)
	end)
end)

describe("FishingState.hookWindow", function()
	it("shrinks by 0.04 s per difficulty step above 1, down to 0.45 s", function()
		expect(FishingState.hookWindow(1)).toBeCloseTo(0.9, 9)
		expect(FishingState.hookWindow(8)).toBeCloseTo(0.62, 9)
		expect(FishingState.hookWindow(20)).toBeCloseTo(0.45, 9)
	end)
end)

describe("FishingState.landing", function()
	local origin = Vector3.new(10, 5, -3)

	it("lands 8 studs away at zero power and 48 at full power, level with the caster", function()
		local near = FishingState.landing(origin, Vector3.new(0, 0, -1), 0) :: Vector3
		local far = FishingState.landing(origin, Vector3.new(0, 0, -1), 1) :: Vector3
		expect((near - origin).Magnitude).toBeCloseTo(8, 4)
		expect((far - origin).Magnitude).toBeCloseTo(48, 4)
		expect(far.Y).toBe(5)
	end)

	it("drops the vertical part of the aim", function()
		local point = FishingState.landing(origin, Vector3.new(3, -50, 4), 0.5) :: Vector3
		expect((point - Vector3.new(26.8, 5, 19.4)).Magnitude).toBeCloseTo(0, 4)
	end)

	it("refuses an aim with no horizontal part, NaN, or power outside 0 to 1", function()
		expect(FishingState.landing(origin, Vector3.new(0, -1, 0), 0.5)).toBeNil()
		expect(FishingState.landing(origin, Vector3.new(NAN, 0, 1), 0.5)).toBeNil()
		expect(FishingState.landing(origin, Vector3.new(1, 0, 0), NAN)).toBeNil()
		expect(FishingState.landing(origin, Vector3.new(1, 0, 0), 1.5)).toBeNil()
	end)
end)
