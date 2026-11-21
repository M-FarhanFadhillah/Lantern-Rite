--!strict
-- Starts an ordered list of modules: every Init runs first, synchronously and in list order,
-- then every Start runs in list order, each in its own thread so one that yields doesn't
-- hold up the rest. Used by the server and client entry scripts.

export type Entry = {
	name: string,
	-- The service or controller table. Init and Start are optional functions. Typed `any`
	-- because strict Luau rejects a module table that leaves out an optional field.
	module: any,
}

local HOOKS = { "Init", "Start" }

local Loader = {}

-- Fails before anything runs if a module sets Init or Start to something other than a function.
local function checkHooks(entries: { Entry })
	for _, entry in entries do
		for _, hook in HOOKS do
			local value = entry.module[hook]
			if value ~= nil and type(value) ~= "function" then
				error(`{entry.name}.{hook} must be a function, got {typeof(value)}`, 0)
			end
		end
	end
end

function Loader.load(entries: { Entry }): ()
	checkHooks(entries)

	for _, entry in entries do
		local init = entry.module.Init
		if init then
			local ok, err = pcall(init)
			if not ok then
				error(`{entry.name}.Init failed: {err}`, 0)
			end
		end
	end

	for _, entry in entries do
		local start = entry.module.Start
		if start then
			task.spawn(start)
		end
	end
end

return Loader
