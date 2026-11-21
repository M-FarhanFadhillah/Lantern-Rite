--!strict
-- Fishing loop tuning (PRD §4): cast, bite and hook. Times in seconds, distances in studs.

return table.freeze({
	castMin = 8, -- landing distance at zero power
	castMax = 48, -- landing distance at full power
	castCooldown = 0.75, -- the next cast can start this long after the last one started
	hookWindowBase = 0.9, -- time to hook a difficulty-1 fish once it bites
	hookWindowStep = 0.04, -- less time per difficulty step above 1
	hookWindowMin = 0.45,
	latencyAllowance = 0.35, -- added to every hook window for the round trip to the server
})
