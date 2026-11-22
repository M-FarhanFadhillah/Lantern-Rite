--!strict
-- Track-bar reel tuning (PRD §4): the simulation's constants and the difficulty curve. Difficulty 1
-- uses `easy`, difficulty 10 uses `hard`, values in between are linear, and the rod then adjusts
-- them (TrackBarSim.tuning). Distances are in track lengths (0 = bottom, 1 = top), times in seconds.

return table.freeze({
	tickRate = 60, -- simulation steps a second, in the client's run and the server's replay
	maxSeconds = 90, -- a reel still going after this long ends in an escape
	startProgress = 0.3,
	settleSeconds = 1, -- misses don't count during the first second
	missGraceSeconds = 0.25, -- the fish may leave the bar this long before it counts as a miss
	rise = 3, -- bar acceleration while held, track lengths per second²
	fall = 3, -- bar acceleration when released
	maxBarSpeed = 1.2,
	barSizeBase = 0.18, -- bar length at Control 0
	barSizePerControl = 0.004,
	easy = table.freeze({ fishSpeed = 0.25, moveInterval = 1.6, gainRate = 0.14, drainRate = 0.10 }),
	hard = table.freeze({ fishSpeed = 0.75, moveInterval = 0.6, gainRate = 0.10, drainRate = 0.14 }),
})
