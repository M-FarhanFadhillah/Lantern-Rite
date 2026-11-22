--!strict
-- The track-bar reel on the client (PRD §4). It opens the moment the player hooks, plays TrackBarSim
-- on the Fish input at the same fixed rate the server replays it, and sends back the ticks at which
-- the hold flipped. The server decides the result. Plain debug overlay until the final HUD (M1
-- session 10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ReelTuning = require(Shared.Data.ReelTuning)
local TrackBarSim = require(Shared.Modules.TrackBarSim)
local InputController = require(script.Parent.InputController)
local Net = require(script.Parent.Parent.Net)

local DT = 1 / ReelTuning.tickRate
local TRACK_HEIGHT = 300
local MAX_TOGGLES = 999 -- net.zap carries up to 1000; past this the hold stays as it is

local player = Players.LocalPlayer

local hud = Instance.new("ScreenGui")
hud.Name = "ReelHud"
hud.ResetOnSpawn = false
hud.Enabled = false

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(1, 0.5)
track.Position = UDim2.new(1, -150, 0.5, 0)
track.Size = UDim2.fromOffset(36, TRACK_HEIGHT)
track.BackgroundColor3 = Color3.fromRGB(25, 45, 60)
track.Parent = hud

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
bar.BackgroundTransparency = 0.3
bar.BorderSizePixel = 0
bar.Parent = track

local fish = Instance.new("Frame")
fish.Name = "Fish"
fish.AnchorPoint = Vector2.new(0.5, 0.5)
fish.Size = UDim2.new(1, 8, 0, 10)
fish.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
fish.BorderSizePixel = 0
fish.ZIndex = 2
fish.Parent = track

local progress = Instance.new("Frame")
progress.Name = "Progress"
progress.Position = UDim2.new(1, 8, 0, 0)
progress.Size = UDim2.fromOffset(10, TRACK_HEIGHT)
progress.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
progress.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.AnchorPoint = Vector2.new(0, 1)
fill.Position = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
fill.BorderSizePixel = 0
fill.Parent = progress

hud.Parent = player:WaitForChild("PlayerGui")

local MinigameController = {}

-- Fires "Hit" when the fish enters the bar and "Miss" when a miss counts: hooks for the feel pass
-- (sound, shake and haptics in M1 session 8).
MinigameController.events = Instance.new("BindableEvent")

local sim: TrackBarSim.Sim? = nil
local reelToken = ""
local toggles: { number } = {}
local holding = false
local carry = 0 -- seconds of real time not yet stepped

local function draw(s: TrackBarSim.Sim)
	bar.Size = UDim2.fromScale(1, s.tuning.barSize)
	bar.Position = UDim2.fromScale(0, 1 - s.barPos)
	fish.Position = UDim2.fromScale(0.5, 1 - s.fishPos)
	fill.Size = UDim2.fromScale(1, math.clamp(s.progress, 0, 1))
end

function MinigameController.start(token: string, seed: number, tuning: TrackBarSim.Tuning)
	local s = TrackBarSim.new(tuning, seed)
	sim = s
	reelToken = token
	toggles = {}
	holding = false
	carry = 0
	draw(s)
	hud.Enabled = true
end

function MinigameController.stop()
	sim = nil
	hud.Enabled = false
end

function MinigameController.Start()
	RunService.RenderStepped:Connect(function(dt)
		local s = sim
		if not s or s.outcome then
			return
		end
		carry += dt
		while carry >= DT and not s.outcome do
			carry -= DT
			local want = InputController.fish:GetState() == true
			if want ~= holding and #toggles < MAX_TOGGLES then
				holding = want
				table.insert(toggles, s.tick)
			end
			local event = TrackBarSim.step(s, holding)
			if event == "Hit" or event == "Miss" then
				MinigameController.events:Fire(event)
			elseif event == "Caught" or event == "Escaped" then
				Net.ReelResult.Fire(reelToken, toggles, event)
			end
		end
		draw(s)
	end)
end

return MinigameController
