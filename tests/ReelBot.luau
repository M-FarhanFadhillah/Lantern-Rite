--!strict
-- Test helper (not a spec): plays a track-bar reel the way a steady player would, holding while the
-- bar's middle is below the fish, and records the toggle ticks a live client sends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackBarSim = require(ReplicatedStorage.Shared.Modules.TrackBarSim)

local ReelBot = {}

-- `waitTicks`: the bot keeps its hands off until this tick, to force misses at the start.
function ReelBot.play(tuning: TrackBarSim.Tuning, seed: number, waitTicks: number?): ({ number }, TrackBarSim.Result)
	local sim = TrackBarSim.new(tuning, seed)
	local toggles: { number } = {}
	local holding = false
	while not sim.outcome do
		local want = sim.tick >= (waitTicks or 0) and sim.barPos + tuning.barSize / 2 < sim.fishPos
		if want ~= holding then
			holding = want
			table.insert(toggles, sim.tick)
		end
		TrackBarSim.step(sim, holding)
	end
	local outcome: TrackBarSim.Outcome = sim.outcome :: TrackBarSim.Outcome
	return toggles,
		{ outcome = outcome, ticks = sim.tick, misses = sim.misses, perfect = outcome == "Caught" and sim.misses == 0 }
end

return ReelBot
