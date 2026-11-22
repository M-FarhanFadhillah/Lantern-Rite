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
	chargeTime = 1.2, -- holding Fish this long reaches full power
	maxCastDrop = 60, -- the water may lie this far below the caster
	requestRate = 10, -- fishing requests a second each player may send on average (PRD §14)
	requestBurst = 20, -- at once; a real player sends one or two per cast
	-- M1 stand-ins until DataService gives each player a rod (session 5) and M2 adds zones.
	zoneId = "DriftwoodHarbor",
	rodId = "Driftwood",
	defaultSpot = "open", -- wherever no FishingSpot zone covers the landing point
})
