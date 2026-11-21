--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Loader = require(ReplicatedStorage.Shared.Modules.Loader)

describe("Loader.load", function()
	it("runs every Init in list order before any Start", function()
		local log: { string } = {}
		local function entry(name: string): Loader.Entry
			return {
				name = name,
				module = {
					Init = function()
						table.insert(log, name .. ".Init")
					end,
					Start = function()
						table.insert(log, name .. ".Start")
					end,
				},
			}
		end

		Loader.load({ entry("A"), entry("B") })

		expect(log).toEqual({ "A.Init", "B.Init", "A.Start", "B.Start" })
	end)

	it("names the module whose Init fails and starts nothing", function()
		local log: { string } = {}
		local entries: { Loader.Entry } = {
			{
				name = "A",
				module = {
					Init = function()
						error("boom")
					end,
					Start = function()
						table.insert(log, "A.Start")
					end,
				},
			},
			{
				name = "B",
				module = {
					Start = function()
						table.insert(log, "B.Start")
					end,
				},
			},
		}

		local ok, err = pcall(Loader.load :: any, entries)

		expect(ok).toBe(false)
		-- Checked by hand: Jest's toThrow(string) strips everything up to the first "file:line: ",
		-- which would also strip the "A.Init failed: " prefix in front of the original error.
		expect((string.find(tostring(err), "A.Init failed: ", 1, true))).toBe(1)
		expect(log).toEqual({})
	end)

	it("accepts modules with no Init or Start", function()
		expect(function()
			Loader.load({ { name = "Empty", module = {} } })
		end).never.toThrow()
	end)
end)
