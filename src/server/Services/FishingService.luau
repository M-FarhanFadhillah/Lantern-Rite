--!strict
-- Runs every player's fishing line on the server (PRD §4, §14). Clients send only aim, cast power,
-- the bite token, reel-in and their reel input. This service picks the landing point, spot, fish,
-- bite time and reel, and settles the reel by replaying that input, with FishingState for the
-- rules, CatchRoll for the fish and TrackBarSim for the reel.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CatchRoll = require(Shared.Modules.CatchRoll)
local FishData = require(Shared.Data.FishData)
local FishingState = require(Shared.Modules.FishingState)
local FishingTuning = require(Shared.Data.FishingTuning)
local RateLimit = require(Shared.Modules.RateLimit)
local RodData = require(Shared.Data.RodData)
local TrackBarSim = require(Shared.Modules.TrackBarSim)
local ZoneData = require(Shared.Data.ZoneData)
local Net = require(script.Parent.Parent.Net)

-- Invisible parts with this tag and a SpotId attribute mark the zone's fishing spots.
local SPOT_TAG = "FishingSpot"

type Line = { state: FishingState.State, spotId: string, budget: RateLimit.Bucket }

local lines: { [Player]: Line } = {}
local rng = Random.new()

local function spotAt(point: Vector3): string
	local spots = ZoneData[FishingTuning.zoneId].spots
	for _, zone in CollectionService:GetTagged(SPOT_TAG) do
		local spotId = zone:GetAttribute("SpotId")
		if zone:IsA("BasePart") and typeof(spotId) == "string" and spots[spotId] then
			local offset = zone.CFrame:PointToObjectSpace(point)
			local half = zone.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return spotId
			end
		end
	end
	return FishingTuning.defaultSpot
end

-- The water surface under the landing point, or nil when the line would land on anything else.
local function waterAt(point: Vector3, character: Model): Vector3?
	local params = RaycastParams.new()
	local ignore: { Instance } = CollectionService:GetTagged(SPOT_TAG)
	table.insert(ignore, character)
	params.FilterDescendantsInstances = ignore
	-- IgnoreWater is false by default, so terrain water stops the ray.
	local hit = workspace:Raycast(point + Vector3.yAxis * 2, Vector3.yAxis * -FishingTuning.maxCastDrop, params)
	if hit and hit.Material == Enum.Material.Water then
		return hit.Position
	end
	return nil
end

-- The player's line, if this request fits their rate limit (PRD §14). Requests over the limit are
-- dropped without an answer.
local function allowed(player: Player): Line?
	local line = lines[player]
	if line and RateLimit.take(line.budget, os.clock()) then
		return line
	end
	return nil
end

local function onRequestCast(player: Player, power: number, direction: Vector3)
	local line = allowed(player)
	if not line then
		return
	end
	local now = os.clock()
	local ok, refusal = FishingState.canCast(line.state, now)
	if not ok then -- refused before any raycast or roll, so spamming casts costs almost nothing
		Net.CastResult.Fire(player, refusal :: FishingState.Refusal, nil)
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		Net.CastResult.Fire(player, "NoCharacter", nil)
		return
	end
	local point = FishingState.landing(root.Position, direction, power)
	if not point then
		Net.CastResult.Fire(player, "Invalid", nil)
		return
	end
	local surface = waterAt(point, character)
	if not surface then
		Net.CastResult.Fire(player, "NotWater", nil)
		return
	end
	line.spotId = spotAt(surface)
	local catch = CatchRoll.roll({
		zoneId = FishingTuning.zoneId,
		spotId = line.spotId,
		castPower = power,
		rodId = FishingTuning.rodId,
	}, rng)
	local reel: FishingState.Reel = {
		seed = rng:NextInteger(0, 4294967295),
		tuning = TrackBarSim.tuning(FishData.byId[catch.speciesId].difficulty, RodData[FishingTuning.rodId]),
	}
	FishingState.cast(line.state, now, HttpService:GenerateGUID(false), catch, reel)
	Net.CastResult.Fire(player, "Ok", surface)
end

local function onHook(player: Player, token: string)
	local line = allowed(player)
	if not line then
		return
	end
	local result = FishingState.hook(line.state, os.clock(), token)
	if result == "Hooked" then
		print(`[Fishing] {player.Name} hooked {(line.state.catch :: CatchRoll.Catch).speciesId} at {line.spotId}`)
	elseif result == "Missed" then
		print(`[Fishing] {player.Name} hooked too late at {line.spotId}`)
		Net.FishResult.Fire(player, { outcome = "Missed" })
	end -- "Rejected": a stale or forged token changes nothing and gets no answer.
end

local function onReelResult(player: Player, token: string, toggles: { number }, claimed: TrackBarSim.Outcome)
	local line = allowed(player)
	if not line then
		return
	end
	local verdict, catch, perfect = FishingState.reel(line.state, os.clock(), token, toggles, claimed)
	if verdict == "Caught" and catch then
		local tag = if perfect then " (Perfect)" else ""
		print(`[Fishing] {player.Name} caught {catch.speciesId} {catch.weightKg} kg at {line.spotId}{tag}`)
		Net.FishResult.Fire(player, {
			outcome = "Caught",
			speciesId = catch.speciesId,
			weightKg = catch.weightKg,
			perfect = perfect,
		})
	elseif verdict == "Escaped" then
		print(`[Fishing] {player.Name} lost a fish at {line.spotId}`)
		Net.FishResult.Fire(player, { outcome = "Escaped" })
	elseif verdict == "Forged" then
		warn(`[Fishing] {player.Name} sent a reel result the replay doesn't reproduce; the fish escapes`)
		Net.FishResult.Fire(player, { outcome = "Escaped" })
	end -- "Rejected": a stale token changes nothing and gets no answer.
end

local function onReelIn(player: Player)
	local line = allowed(player)
	if line and FishingState.reelIn(line.state) then
		Net.FishResult.Fire(player, { outcome = "ReeledIn" })
	end
end

-- Bites, unhooked bites and unanswered reels, checked every frame: no per-cast timers to cancel or
-- outlive a player.
local function step()
	local now = os.clock()
	for player, line in lines do
		if FishingState.bite(line.state, now) then
			local reel = line.state.reel :: FishingState.Reel
			Net.Bite.Fire(player, line.state.token :: string, reel.seed, reel.tuning)
		else
			local expiry: FishingState.Expiry? = FishingState.expire(line.state, now)
			if expiry then
				local what = if expiry == "Missed" then "missed a bite" else "never finished a reel"
				print(`[Fishing] {player.Name} {what} at {line.spotId}`)
				Net.FishResult.Fire(player, { outcome = expiry })
			end
		end
	end
end

local function addPlayer(player: Player)
	if not lines[player] then
		lines[player] = {
			state = FishingState.new(),
			spotId = FishingTuning.defaultSpot,
			budget = RateLimit.new(FishingTuning.requestRate, FishingTuning.requestBurst),
		}
	end
end

local FishingService = {}

function FishingService.Start()
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lines[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	Net.RequestCast.SetCallback(onRequestCast)
	Net.Hook.SetCallback(onHook)
	Net.ReelIn.SetCallback(onReelIn)
	Net.ReelResult.SetCallback(onReelResult)
	RunService.Heartbeat:Connect(step)
end

return FishingService
