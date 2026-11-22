--!strict
-- The track-bar reel (PRD §4). Hold to lift the bar, release to let it fall, and keep the fish
-- inside it: progress fills while the fish is in the bar and drains while it is out. The client
-- plays it live and the server replays the same input (PRD §14), so it steps at a fixed rate and
-- uses only plain arithmetic, comparisons and a seeded Random. No trig or other library maths,
-- which can round differently from one platform to another.

local Data = script.Parent.Parent.Data
local ReelTuning = require(Data.ReelTuning)
local RodData = require(Data.RodData)

export type Tuning = {
	barSize: number,
	fishSpeed: number,
	moveInterval: number,
	gainRate: number,
	drainRate: number,
}
export type Outcome = "Caught" | "Escaped"
export type Event = Outcome | "Hit" | "Miss"
export type Result = { outcome: Outcome, ticks: number, misses: number, perfect: boolean }
export type Sim = {
	tuning: Tuning,
	rng: Random,
	tick: number,
	barPos: number, -- bottom edge of the bar, 0 to 1 - barSize
	barSpeed: number,
	fishPos: number, -- 0 to 1
	fishTarget: number,
	fishTimer: number,
	progress: number,
	inside: boolean, -- the fish was in the bar last tick
	outside: number, -- ticks in a row with the fish outside the bar, counted after the settle-in
	misses: number,
	outcome: Outcome?,
}

local DT = 1 / ReelTuning.tickRate
local MAX_TICKS = ReelTuning.maxSeconds * ReelTuning.tickRate
local SETTLE_TICKS = ReelTuning.settleSeconds * ReelTuning.tickRate
local GRACE_TICKS = ReelTuning.missGraceSeconds * ReelTuning.tickRate

local TrackBarSim = {}

function TrackBarSim.tuning(difficulty: number, rod: RodData.Rod): Tuning
	local t = (difficulty - 1) / 9
	local easy, hard = ReelTuning.easy, ReelTuning.hard
	local function lerp(a: number, b: number): number
		return a + (b - a) * t
	end
	return {
		barSize = ReelTuning.barSizeBase + rod.control * ReelTuning.barSizePerControl,
		fishSpeed = lerp(easy.fishSpeed, hard.fishSpeed),
		moveInterval = lerp(easy.moveInterval, hard.moveInterval),
		gainRate = lerp(easy.gainRate, hard.gainRate) * (1 + rod.reelSpeed / 100),
		drainRate = lerp(easy.drainRate, hard.drainRate) * (1 - rod.resilience / 200),
	}
end

function TrackBarSim.new(tuning: Tuning, seed: number): Sim
	local rng = Random.new(seed)
	return {
		tuning = tuning,
		rng = rng,
		tick = 0,
		barPos = 0,
		barSpeed = 0,
		fishPos = 0.5,
		fishTarget = rng:NextNumber(),
		fishTimer = tuning.moveInterval * (0.5 + rng:NextNumber()),
		progress = ReelTuning.startProgress,
		inside = false,
		outside = 0,
		misses = 0,
		outcome = nil,
	}
end

-- Advances one tick with the player holding or not. Returns the outcome when the reel ends that
-- tick, otherwise "Miss" or "Hit" (the fish entering the bar), or nil.
function TrackBarSim.step(sim: Sim, holding: boolean): Event?
	if sim.outcome then
		return nil
	end
	local tuning = sim.tuning

	-- The fish swims toward its target and picks a new one when its timer runs out.
	sim.fishTimer -= DT
	if sim.fishTimer <= 0 then
		sim.fishTarget = sim.rng:NextNumber()
		sim.fishTimer = tuning.moveInterval * (0.5 + sim.rng:NextNumber())
	end
	local reach = tuning.fishSpeed * DT
	sim.fishPos += math.clamp(sim.fishTarget - sim.fishPos, -reach, reach)

	-- The bar speeds up while held and slows down or falls otherwise, and stops at either end.
	local accel = if holding then ReelTuning.rise else -ReelTuning.fall
	sim.barSpeed = math.clamp(sim.barSpeed + accel * DT, -ReelTuning.maxBarSpeed, ReelTuning.maxBarSpeed)
	sim.barPos += sim.barSpeed * DT
	local top = 1 - tuning.barSize
	if sim.barPos < 0 then
		sim.barPos = 0
		sim.barSpeed = 0
	elseif sim.barPos > top then
		sim.barPos = top
		sim.barSpeed = 0
	end

	local inside = sim.fishPos >= sim.barPos and sim.fishPos <= sim.barPos + tuning.barSize
	if inside then
		sim.progress += tuning.gainRate * DT
	else
		sim.progress -= tuning.drainRate * DT
	end

	local event: Event? = nil
	if inside then
		if not sim.inside then
			event = "Hit"
		end
		sim.outside = 0
	elseif sim.tick >= SETTLE_TICKS then
		sim.outside += 1
		if sim.outside == GRACE_TICKS + 1 then
			sim.misses += 1
			event = "Miss"
		end
	end
	sim.inside = inside
	sim.tick += 1

	if sim.progress >= 1 then
		sim.outcome = "Caught"
	elseif sim.progress <= 0 or sim.tick >= MAX_TICKS then
		sim.outcome = "Escaped"
	end
	return sim.outcome or event
end

-- Replays a reel from its toggles: the ticks at which the hold flipped, starting released. Nil when
-- the toggles aren't whole, strictly increasing ticks that all come before the reel ended.
function TrackBarSim.replay(tuning: Tuning, seed: number, toggles: { number }): Result?
	local last = -1
	for _, toggle in toggles do
		if toggle <= last or toggle % 1 ~= 0 then
			return nil
		end
		last = toggle
	end
	local sim = TrackBarSim.new(tuning, seed)
	local holding, nextToggle = false, 1
	while not sim.outcome do
		if toggles[nextToggle] == sim.tick then
			holding = not holding
			nextToggle += 1
		end
		TrackBarSim.step(sim, holding)
	end
	if nextToggle <= #toggles then
		return nil
	end
	local outcome: Outcome = sim.outcome :: Outcome
	return {
		outcome = outcome,
		ticks = sim.tick,
		misses = sim.misses,
		perfect = outcome == "Caught" and sim.misses == 0,
	}
end

return table.freeze(TrackBarSim)
