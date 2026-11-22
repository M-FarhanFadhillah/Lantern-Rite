--!strict
-- One player's fishing line (PRD §4): cast, wait, bite, hook, reel. Pure: the caller passes the
-- time (`now`, in seconds), the catch CatchRoll already rolled and the reel's seed and tuning, so
-- FishingService owns the clock, the remotes and the randomness. The reel is settled by replaying
-- the client's input with TrackBarSim (PRD §14).

local Data = script.Parent.Parent.Data
local CatchRoll = require(script.Parent.CatchRoll)
local TrackBarSim = require(script.Parent.TrackBarSim)
local FishData = require(Data.FishData)
local FishingTuning = require(Data.FishingTuning)
local ReelTuning = require(Data.ReelTuning)

export type Phase = "Idle" | "Waiting" | "Biting" | "Reeling"
export type HookResult = "Hooked" | "Missed" | "Rejected"
export type ReelVerdict = "Caught" | "Escaped" | "Forged" | "Rejected"
export type Expiry = "Missed" | "Escaped"
export type Refusal = "Busy" | "Cooldown"
export type Reel = { seed: number, tuning: TrackBarSim.Tuning }

export type State = {
	phase: Phase,
	token: string?, -- this cast's token; the client learns it from the bite
	catch: CatchRoll.Catch?, -- rolled at the cast; the client never sees it before the reel ends
	reel: Reel?, -- the reel's seed and tuning, sent to the client with the bite
	castAt: number,
	deadline: number, -- the last moment a hook counts, once the fish bites
	biteAt: number, -- when the server sent the bite; no honest reel can start before it
	readyAt: number, -- the earliest next cast
}

local FishingState = {}

local function reset(state: State)
	state.phase = "Idle"
	state.token = nil
	state.catch = nil
	state.reel = nil
end

function FishingState.new(): State
	return {
		phase = "Idle",
		token = nil,
		catch = nil,
		reel = nil,
		castAt = 0,
		deadline = 0,
		biteAt = 0,
		readyAt = -math.huge,
	}
end

function FishingState.hookWindow(difficulty: number): number
	return math.max(
		FishingTuning.hookWindowMin,
		FishingTuning.hookWindowBase - FishingTuning.hookWindowStep * (difficulty - 1)
	)
end

function FishingState.canCast(state: State, now: number): (boolean, Refusal?)
	if state.phase ~= "Idle" then
		return false, "Busy"
	elseif now < state.readyAt then
		return false, "Cooldown"
	end
	return true, nil
end

function FishingState.cast(
	state: State,
	now: number,
	token: string,
	catch: CatchRoll.Catch,
	reel: Reel
): (boolean, Refusal?)
	local ok: boolean, reason: Refusal? = FishingState.canCast(state, now)
	if not ok then
		return false, reason
	end
	state.phase = "Waiting"
	state.token = token
	state.catch = catch
	state.reel = reel
	state.castAt = now
	state.readyAt = now + FishingTuning.castCooldown
	return true, nil
end

-- Starts the bite once its time has come and returns the hook window. The window runs from
-- `now`, when the server sends the bite, not from when the bite was due.
function FishingState.bite(state: State, now: number): number?
	local catch = state.catch
	if state.phase ~= "Waiting" or not catch or now < state.castAt + catch.biteTime then
		return nil
	end
	local window = FishingState.hookWindow(FishData.byId[catch.speciesId].difficulty)
	state.phase = "Biting"
	state.biteAt = now
	state.deadline = now + window + FishingTuning.latencyAllowance
	return window
end

-- A hook with this cast's token during the bite: "Hooked" up to the deadline, which starts the
-- reel, and "Missed" after it. Anything else is "Rejected" and changes nothing.
function FishingState.hook(state: State, now: number, token: string): HookResult
	if state.phase ~= "Biting" or token ~= state.token then
		return "Rejected"
	end
	if now <= state.deadline then
		state.phase = "Reeling"
		return "Hooked"
	end
	reset(state)
	return "Missed"
end

-- Settles the reel from the client's toggles; the server's own replay decides. A claim the replay
-- doesn't reproduce, toggles it can't use, or a result back sooner than the reel could take is
-- "Forged", and the fish escapes. A wrong token or phase is "Rejected" and changes nothing.
-- Returns the verdict, the catch when it's landed, and whether the catch is Perfect.
function FishingState.reel(
	state: State,
	now: number,
	token: string,
	toggles: { number },
	claimed: TrackBarSim.Outcome
): (ReelVerdict, CatchRoll.Catch?, boolean)
	local reel = state.reel
	if state.phase ~= "Reeling" or token ~= state.token or not reel then
		return "Rejected", nil, false
	end
	local catch = state.catch
	-- Timed from the bite, not the hook's arrival: a lagged hook must not make an honest reel look fast.
	local elapsed = now - state.biteAt
	local result = TrackBarSim.replay(reel.tuning, reel.seed, toggles)
	reset(state)
	if
		not result
		or result.outcome ~= claimed
		or elapsed < result.ticks / ReelTuning.tickRate - FishingTuning.latencyAllowance
	then
		return "Forged", nil, false
	end
	if result.outcome == "Caught" then
		return "Caught", catch, result.perfect
	end
	return "Escaped", nil, false
end

-- Ends a bite nobody hooked in time ("Missed") or a reel that never reported back ("Escaped").
function FishingState.expire(state: State, now: number): Expiry?
	if state.phase == "Biting" and now > state.deadline then
		reset(state)
		return "Missed"
	elseif state.phase == "Reeling" and now > state.biteAt + ReelTuning.maxSeconds + FishingTuning.reelGrace then
		reset(state)
		return "Escaped"
	end
	return nil
end

-- Pulls the line back in at any point after the cast. True when a line was out.
function FishingState.reelIn(state: State): boolean
	if state.phase == "Idle" then
		return false
	end
	reset(state)
	return true
end

-- Where a cast lands: level with `origin`, along the horizontal part of `direction`, castMin
-- (power 0) to castMax (power 1) studs away. Nil for an aim with no usable horizontal part or a
-- power outside 0 to 1 (including NaN), since both come from the client.
function FishingState.landing(origin: Vector3, direction: Vector3, power: number): Vector3?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local length = flat.Magnitude
	if not (length > 1e-3 and length < math.huge and power >= 0 and power <= 1) then
		return nil
	end
	local distance = FishingTuning.castMin + (FishingTuning.castMax - FishingTuning.castMin) * power
	return origin + flat / length * distance
end

return table.freeze(FishingState)
