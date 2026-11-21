--!strict
-- Starts an ordered list of modules: every Init runs first, synchronously and in list order,
-- then every Start runs in list order, each in its own thread so one that yields doesn't
-- hold up the rest. Used by the server and client entry scripts.

export type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

export type Entry = {
	name: string,
	module: Module,
}

local Loader = {}

function Loader.load(entries: { Entry }): ()
	for _, entry in entries do
		local init = entry.module.Init
		if init then
			-- Cast so pcall's type includes the error value (it's typed from init's empty returns).
			local ok, err = pcall(init :: any)
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
