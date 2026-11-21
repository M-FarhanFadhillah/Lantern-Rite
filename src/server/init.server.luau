--!strict
-- Server entry point: loads services in the order listed here (PRD §14).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Modules.Loader)

local Services = script.Services

local services: { Loader.Entry } = {
	{ name = "SmokeTestService", module = require(Services.SmokeTestService) },
}

Loader.load(services)
print(`[Server] {#services} services started`)
