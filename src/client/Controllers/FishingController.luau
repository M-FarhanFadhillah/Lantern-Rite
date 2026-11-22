--!strict
-- The fishing loop on the client (PRD §4): hold and release Fish to cast, press on the "!" to hook
-- and start the reel (MinigameController), press while waiting to reel in. It sends only power,
-- aim, the bite token and reel-in, and shows what the server answers. Plain debug visuals until the
-- final HUD (M1 session 10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local FishData = require(Shared.Data.FishData)
local FishingTuning = require(Shared.Data.FishingTuning)
local TrackBarSim = require(Shared.Modules.TrackBarSim)
local InputController = require(script.Parent.InputController)
local MinigameController = require(script.Parent.MinigameController)
local Net = require(script.Parent.Parent.Net)

-- Answering: a reel-in is on its way to the server. Reeling: the reel overlay is up.
type Phase = "Idle" | "Charging" | "Casting" | "Waiting" | "Biting" | "Reeling" | "Answering"

local REFUSALS: { [string]: string } = {
	NotWater = "Cast into the water.",
	Busy = "Your line is already out.",
	Cooldown = "Too soon. Try again.",
	NoCharacter = "No character to cast with.",
	Invalid = "Couldn't aim that cast.",
}

local player = Players.LocalPlayer
local phase: Phase = "Idle"
local chargeStart = 0
local token: string? = nil
local reel: { seed: number, tuning: TrackBarSim.Tuning }? = nil
local bobber: Part? = nil

local hud = Instance.new("ScreenGui")
hud.Name = "FishingHud"
hud.ResetOnSpawn = false

local meter = Instance.new("Frame")
meter.Name = "PowerMeter"
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Position = UDim2.new(0.5, 0, 1, -120)
meter.Size = UDim2.fromOffset(240, 16)
meter.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
meter.Visible = false
meter.Parent = hud

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = meter

local message = Instance.new("TextLabel")
message.Name = "Message"
message.AnchorPoint = Vector2.new(0.5, 0)
message.Position = UDim2.new(0.5, 0, 0, 60)
message.Size = UDim2.fromOffset(480, 40)
message.BackgroundTransparency = 1
message.Text = ""
message.TextColor3 = Color3.new(1, 1, 1)
message.TextStrokeTransparency = 0
message.TextSize = 24
message.Parent = hud

hud.Parent = player:WaitForChild("PlayerGui")

local said = 0
local function say(text: string)
	said += 1
	local this = said
	message.Text = text
	task.delay(3, function()
		if said == this then
			message.Text = ""
		end
	end)
end

local function power(): number
	return math.min(1, (os.clock() - chargeStart) / FishingTuning.chargeTime)
end

local function clearBobber()
	if bobber then
		bobber:Destroy()
		bobber = nil
	end
end

-- A bobber where the server says the line landed, with a line from the character's hand.
local function showBobber(at: Vector3)
	clearBobber()
	local part = Instance.new("Part")
	part.Name = "Bobber"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.6
	part.Color = Color3.fromRGB(220, 60, 50)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = at + Vector3.yAxis * 0.2
	local tip = Instance.new("Attachment")
	tip.Parent = part
	local grip = player.Character and player.Character:FindFirstChild("RightGripAttachment", true)
	if grip and grip:IsA("Attachment") then
		local line = Instance.new("Beam")
		line.Attachment0 = grip
		line.Attachment1 = tip
		line.Width0 = 0.05
		line.Width1 = 0.05
		line.FaceCamera = true
		line.Color = ColorSequence.new(Color3.new(1, 1, 1))
		line.Parent = part
	end
	part.Parent = workspace
	bobber = part
end

local function showBite()
	if not bobber then
		return
	end
	bobber.Position -= Vector3.yAxis * 0.3
	local sign = Instance.new("BillboardGui")
	sign.Name = "Bite"
	sign.AlwaysOnTop = true
	sign.Size = UDim2.fromOffset(60, 60)
	sign.StudsOffset = Vector3.yAxis * 2.5
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Text = "!"
	mark.TextColor3 = Color3.fromRGB(255, 220, 60)
	mark.TextScaled = true
	mark.TextStrokeTransparency = 0
	mark.Parent = sign
	sign.Parent = bobber
end

local function onPressed()
	if phase == "Idle" then
		phase = "Charging"
		chargeStart = os.clock()
		fill.Size = UDim2.fromScale(0, 1)
		meter.Visible = true
	elseif phase == "Waiting" then
		phase = "Answering"
		Net.ReelIn.Fire()
	elseif phase == "Biting" and token and reel then
		-- Start the reel at once (PRD §4: within 0.2 s); the server confirms or says Missed.
		phase = "Reeling"
		Net.Hook.Fire(token)
		local sign = bobber and bobber:FindFirstChild("Bite")
		if sign then
			sign:Destroy()
		end
		MinigameController.start(token, reel.seed, reel.tuning)
	end
end

local function onReleased()
	if phase ~= "Charging" then
		return
	end
	phase = "Casting"
	meter.Visible = false
	Net.RequestCast.Fire(power(), workspace.CurrentCamera.CFrame.LookVector) -- the server levels the aim
end

local function onCastResult(reason: string, landing: Vector3?)
	if phase ~= "Casting" then
		return
	end
	if reason == "Ok" and landing then
		phase = "Waiting"
		showBobber(landing)
	else
		phase = "Idle"
		say(REFUSALS[reason] or reason)
	end
end

local function onBite(biteToken: string, seed: number, tuning: TrackBarSim.Tuning)
	if phase == "Waiting" then
		phase = "Biting"
		token = biteToken
		reel = { seed = seed, tuning = tuning }
		showBite()
	end
end

local function onFishResult(outcome: string, speciesId: string?, weightKg: number?, perfect: boolean?)
	if phase ~= "Charging" then
		phase = "Idle"
	end
	token = nil
	reel = nil
	clearBobber()
	MinigameController.stop()
	if outcome == "Caught" and speciesId then
		local species = FishData.byId[speciesId]
		local name = if species then species.displayName else speciesId
		local tag = if perfect then " Perfect!" else ""
		say(`Caught a {name}! {string.format("%.2f", weightKg or 0)} kg{tag}`)
	elseif outcome == "Missed" then
		say("It got away.")
	elseif outcome == "Escaped" then
		say("It escaped.")
	end
end

local FishingController = {}

function FishingController.Start()
	InputController.fish.Pressed:Connect(onPressed)
	InputController.fish.Released:Connect(onReleased)
	Net.CastResult.SetCallback(onCastResult)
	Net.Bite.SetCallback(onBite)
	Net.FishResult.SetCallback(function(result)
		onFishResult(result.outcome, result.speciesId, result.weightKg, result.perfect)
	end)
	RunService.RenderStepped:Connect(function()
		if phase == "Charging" then
			fill.Size = UDim2.fromScale(power(), 1)
		end
	end)
end

return FishingController
