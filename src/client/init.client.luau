--!strict
-- Client entry point: loads controllers in the order listed here (PRD §14). None yet in M0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Modules.Loader)

local controllers: { Loader.Entry } = {}

Loader.load(controllers)
print(`[Client] {#controllers} controllers started`)
