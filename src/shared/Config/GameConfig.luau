--!strict

local GameConfig = {
	-- Builds a parkour test course in Workspace so movement can be tuned in an empty place.
	BuildDevArena = true,

	-- Spawns AI chasers/runners in the arena.
	SpawnNPCs = true,

	-- On-screen speed / state readout (toggle in game with F3).
	ShowDebugHud = true,

	AntiCheat = {
		Enabled = true,
		-- Highest horizontal speed any legit move reaches, plus generous slack.
		MaxHorizontalSpeed = 150,
		-- A single 0.1s check moving farther than this counts as a teleport.
		TeleportDistance = 60,
		-- Violations in a row before the character is put back where it was.
		ViolationsBeforeCorrection = 3,
	},
}

return GameConfig
