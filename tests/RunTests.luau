--!strict
-- Runs every *.spec module under ServerStorage.Tests with Jest Lua.
-- During a Studio playtest, from execute_luau (Server):
--   return require(game.ServerStorage.Tests.RunTests)()

local ServerStorage = game:GetService("ServerStorage")

local Jest = require(ServerStorage.DevPackages.Jest)

export type Summary = {
	passed: number,
	failed: number,
	failedSuites: number,
	success: boolean,
}

-- Same probe jest-runtime uses: the function can exist and still be disabled.
local function loadModuleEnabled(): boolean
	local loadmodule = (debug :: any).loadmodule
	return loadmodule ~= nil and (pcall(loadmodule, Instance.new("ModuleScript")))
end

local function runTests(): Summary
	if not loadModuleEnabled() then
		error(
			"Jest Lua needs debug.loadmodule: run tools/enable-jest-flag.ps1 (FFlagEnableLoadModule), then restart Studio",
			0
		)
	end

	local root = ServerStorage.Tests
	local status, result = Jest.runCLI(root, { ci = true, verbose = true }, { root }):awaitStatus()
	if status ~= "Resolved" then
		error(`Jest run did not finish: {result}`, 0)
	end

	-- Jest Lua leaves results.success true when a suite fails to load, so decide here.
	-- A run that finds no tests is a misconfiguration, not a pass.
	local results = result.results
	return {
		passed = results.numPassedTests,
		failed = results.numFailedTests,
		failedSuites = results.numFailedTestSuites,
		success = results.numTotalTests > 0 and results.numFailedTests == 0 and results.numFailedTestSuites == 0,
	}
end

return runTests
