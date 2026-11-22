--!strict
-- Client entry point: loads controllers in the order listed here (PRD §14).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Modules.Loader)

local Controllers = script.Controllers

local controllers: { Loader.Entry } = {
	{ name = "InputController", module = require(Controllers.InputController) },
	{ name = "MinigameController", module = require(Controllers.MinigameController) },
	{ name = "FishingController", module = require(Controllers.FishingController) },
}

Loader.load(controllers)
print(`[Client] {#controllers} controllers started`)
