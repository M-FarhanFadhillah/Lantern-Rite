--!strict
-- One player's fishing line (PRD §4): cast, wait, bite, hook. Pure: the caller passes the time
-- (`now`, in seconds) and the catch CatchRoll already rolled, so FishingService owns the clock,
-- the remotes and the randomness. Until the reel (M1 session 3), a hooked fish counts as caught.

local Data = script.Parent.Parent.Data
local CatchRoll = require(script.Parent.CatchRoll)
local FishData = require(Data.FishData)
local FishingTuning = require(Data.FishingTuning)

export type Phase = "Idle" | "Waiting" | "Biting"
export type HookResult = "Hooked" | "Missed" | "Rejected"
export type Refusal = "Busy" | "Cooldown"

export type State = {
	phase: Phase,
	token: string?, -- this cast's token; the client learns it from the bite
	catch: CatchRoll.Catch?, -- rolled at the cast; the client never sees it before the hook
	castAt: number,
	deadline: number, -- the last moment a hook counts, once the fish bites
	readyAt: number, -- the earliest next cast
}

local FishingState = {}

local function reset(state: State)
	state.phase = "Idle"
	state.token = nil
	state.catch = nil
end

function FishingState.new(): State
	return { phase = "Idle", token = nil, catch = nil, castAt = 0, deadline = 0, readyAt = -math.huge }
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

function FishingState.cast(state: State, now: number, token: string, catch: CatchRoll.Catch): (boolean, Refusal?)
	local ok: boolean, reason: Refusal? = FishingState.canCast(state, now)
	if not ok then
		return false, reason
	end
	state.phase = "Waiting"
	state.token = token
	state.catch = catch
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
	state.deadline = now + window + FishingTuning.latencyAllowance
	return window
end

-- A hook with this cast's token during the bite: "Hooked" (with the catch) up to the deadline,
-- "Missed" after it. Anything else is "Rejected" and changes nothing.
function FishingState.hook(state: State, now: number, token: string): (HookResult, CatchRoll.Catch?)
	if state.phase ~= "Biting" or token ~= state.token then
		return "Rejected", nil
	end
	local catch = state.catch
	local inTime = now <= state.deadline
	reset(state)
	if inTime then
		return "Hooked", catch
	end
	return "Missed", nil
end

-- Lets the fish go once the hook deadline has passed. True when it did.
function FishingState.expire(state: State, now: number): boolean
	if state.phase == "Biting" and now > state.deadline then
		reset(state)
		return true
	end
	return false
end

-- Pulls the line back in, before or during a bite. True when a line was out.
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
