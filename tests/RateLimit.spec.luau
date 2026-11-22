--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)

describe("RateLimit", function()
	it("allows a burst at once, then refuses", function()
		local bucket = RateLimit.new(4, 3)
		expect(RateLimit.take(bucket, 100)).toBe(true)
		expect(RateLimit.take(bucket, 100)).toBe(true)
		expect(RateLimit.take(bucket, 100)).toBe(true)
		expect(RateLimit.take(bucket, 100)).toBe(false)
	end)

	it("refills at the rate: one more request every 1/rate seconds", function()
		local bucket = RateLimit.new(4, 1)
		expect(RateLimit.take(bucket, 100)).toBe(true)
		expect(RateLimit.take(bucket, 100.125)).toBe(false) -- half a request saved up
		expect(RateLimit.take(bucket, 100.25)).toBe(true)
		expect(RateLimit.take(bucket, 100.25)).toBe(false)
	end)

	it("never saves up more than the burst, however long the caller waits", function()
		local bucket = RateLimit.new(4, 2)
		RateLimit.take(bucket, 100)
		expect(RateLimit.take(bucket, 5000)).toBe(true)
		expect(RateLimit.take(bucket, 5000)).toBe(true)
		expect(RateLimit.take(bucket, 5000)).toBe(false)
	end)
end)
