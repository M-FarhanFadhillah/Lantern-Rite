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

local ALLOWANCE = FishingTuning.latencyAllowance
local NAN = math.huge - math.huge

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
	FishingState.cast(state, 0, "t1", minnow())
	FishingState.bite(state, 5)
	return state
end

describe("FishingState.cast", function()
	it("casts from Idle", function()
		local state = FishingState.new()
		expect(castResult(FishingState.cast(state, 0, "t1", minnow()))).toEqual({ ok = true })
		expect(state.phase).toBe("Waiting")
	end)

	it("refuses a second cast while the line is out and keeps the first", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
		expect(castResult(FishingState.cast(state, 10, "t2", minnow()))).toEqual({ ok = false, reason = "Busy" })
		expect(state.token).toBe("t1")
	end)

	it("refuses a cast within the cooldown after the last cast", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
		FishingState.reelIn(state)
		local early = FishingTuning.castCooldown - 0.01
		expect(castResult(FishingState.canCast(state, early))).toEqual({ ok = false, reason = "Cooldown" })
		expect(castResult(FishingState.cast(state, early, "t2", minnow()))).toEqual({ ok = false, reason = "Cooldown" })
		expect(castResult(FishingState.cast(state, FishingTuning.castCooldown, "t2", minnow()))).toEqual({ ok = true })
	end)
end)

describe("FishingState.bite", function()
	it("comes at the bite time, not before", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
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
			{ speciesId = "Wreckwarden", rarity = "Legendary", weightKg = 40, biteTime = 5 }
		)
		expect(FishingState.bite(state, 5)).toBeCloseTo(0.62, 9)
	end)
end)

describe("FishingState.hook", function()
	it("hooks inside the window plus the latency allowance and hands back the catch", function()
		local state = biting()
		local result, catch = FishingState.hook(state, 5 + 0.9 + ALLOWANCE, "t1")
		expect(result).toBe("Hooked")
		expect(catch and catch.speciesId).toBe("DockMinnow")
		expect(state.phase).toBe("Idle")
	end)

	it("misses after the window plus the allowance", function()
		local state = biting()
		local result, catch = FishingState.hook(state, 5 + 0.9 + ALLOWANCE + 0.01, "t1")
		expect(result).toBe("Missed")
		expect(catch).toBeNil()
		expect(state.phase).toBe("Idle")
	end)

	it("starts the window when the bite is sent, even a frame late", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
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
		FishingState.cast(state, 0, "old", minnow())
		FishingState.reelIn(state)
		FishingState.cast(state, 1, "new", minnow())
		FishingState.bite(state, 6)
		expect((FishingState.hook(state, 6.1, "old"))).toBe("Rejected")
		expect(state.token).toBe("new")
		expect(state.phase).toBe("Biting")
	end)

	it("rejects a hook before the bite", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
		expect((FishingState.hook(state, 1, "t1"))).toBe("Rejected")
		expect(state.phase).toBe("Waiting")
	end)
end)

describe("FishingState.expire", function()
	it("releases a bite once the window and the allowance have passed", function()
		local state = biting()
		expect(FishingState.expire(state, 5 + 0.9 + ALLOWANCE)).toBe(false)
		expect(FishingState.expire(state, 5 + 0.9 + ALLOWANCE + 0.01)).toBe(true)
		expect(state.phase).toBe("Idle")
	end)

	it("leaves a waiting line alone", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
		expect(FishingState.expire(state, 100)).toBe(false)
		expect(state.phase).toBe("Waiting")
	end)
end)

describe("FishingState.reelIn", function()
	it("cancels a waiting line, so no bite comes", function()
		local state = FishingState.new()
		FishingState.cast(state, 0, "t1", minnow())
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
