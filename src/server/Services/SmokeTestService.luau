--!strict
-- M0 smoke test, Studio only: loads the generated test fish by its asset ID and rests it
-- beside the SpawnLocation, proving Blender -> Open Cloud -> AssetIds -> playtest.
-- Remove once M1's real services show fish.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.Assets.AssetIds)

local FISH_KEY = "FSH_KelpSnapper"
local STUDS_FROM_SPAWN = 10

local SmokeTestService = {}

local function anchorAll(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- Rests the model's bounding box on the ground beside the spawn (or at the origin without one).
local function placeBesideSpawn(model: Model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local target = Vector3.new(0, boxSize.Y / 2, 0)

	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		target = Vector3.new(
			spawn.Position.X + spawn.Size.X / 2 + STUDS_FROM_SPAWN + boxSize.X / 2,
			spawn.Position.Y - spawn.Size.Y / 2 + boxSize.Y / 2,
			spawn.Position.Z
		)
	end

	model:PivotTo(model:GetPivot() + (target - boxCFrame.Position))
end

function SmokeTestService.Start()
	if not RunService:IsStudio() then
		return
	end

	local assetId = AssetIds.Fish[FISH_KEY]
	if assetId == nil then
		print(`[SmokeTest] no {FISH_KEY} asset yet`)
		return
	end

	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn(`[SmokeTest] could not load {FISH_KEY} ({assetId}): {result}`)
		return
	end

	local model = result
	model.Name = FISH_KEY
	anchorAll(model)
	placeBesideSpawn(model)
	model.Parent = workspace

	local _, size = model:GetBoundingBox()
	print(
		string.format(
			"[SmokeTest] %s %d loaded, size %.2f x %.2f x %.2f studs",
			FISH_KEY,
			assetId,
			size.X,
			size.Y,
			size.Z
		)
	)
end

return SmokeTestService
