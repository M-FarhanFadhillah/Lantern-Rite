--!strict
-- The one gameplay input, "Fish" (PRD §4): Space or the left mouse button, or a screen button for
-- touch. Its context outranks and sinks the default PlayerScripts contexts, so Space fishes
-- instead of jumping, except while swimming. The button is a plain placeholder until the final HUD
-- (M1 session 10).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local context = Instance.new("InputContext")
context.Name = "FishingContext"
context.Priority = 2000
context.Sink = true

local fish = Instance.new("InputAction")
fish.Name = "Fish"
fish.Type = Enum.InputActionType.Bool
fish.Parent = context

for _, keyCode in { Enum.KeyCode.Space, Enum.KeyCode.MouseLeftButton } do
	local binding = Instance.new("InputBinding")
	binding.Name = keyCode.Name
	binding.KeyCode = keyCode
	binding.Parent = fish
end

local gui = Instance.new("ScreenGui")
gui.Name = "FishButton"
gui.ResetOnSpawn = false

local button = Instance.new("TextButton")
button.Name = "Fish"
button.AnchorPoint = Vector2.new(1, 0.5)
button.Position = UDim2.new(1, -24, 0.55, 0)
button.Size = UDim2.fromOffset(96, 96) -- PRD §2: touch targets of at least 44 px
button.Text = "Fish"
button.TextSize = 24
button.Parent = gui

local touch = Instance.new("InputBinding")
touch.Name = "ScreenButton"
touch.UIButton = button
touch.Parent = fish

gui.Parent = player:WaitForChild("PlayerGui")
context.Parent = player:WaitForChild("PlayerScripts")

-- In the water Space must swim and jump, or a PC player who falls in can't climb back out.
local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	context.Enabled = true
	humanoid.StateChanged:Connect(function(_, new)
		context.Enabled = new ~= Enum.HumanoidStateType.Swimming
	end)
end
player.CharacterAdded:Connect(watch)
if player.Character then
	task.spawn(watch, player.Character)
end

return table.freeze({ fish = fish })
