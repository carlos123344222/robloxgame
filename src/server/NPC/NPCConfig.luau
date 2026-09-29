--!strict

export type Archetype = {
	DisplayName: string,
	Role: "Chaser" | "Runner",
	Color: Color3,
	SpeedMult: number, -- scales the shared MovementConfig speeds
	CanDash: boolean,
	CanSlide: boolean,
	DetectRange: number, -- chasers notice targets this far away
	FleeRange: number, -- runners start running when a threat gets this close
	FleeDistance: number, -- how far ahead a runner picks its escape point
	DashRange: number,
	DashMinRange: number,
	TagRange: number,
	TagCooldown: number,
	TagKnockback: number,
	TagStun: number,
}

local NPCConfig = {
	-- Workspace folder the NPCs are parented to.
	FolderName = "NPCs",

	-- What to spawn. Chasers hunt the nearest player or runner, runners flee from players.
	Spawn = {
		{ Archetype = "Chaser", Count = 2 },
		{ Archetype = "Runner", Count = 2 },
	},
	SpawnRingMin = 30,
	SpawnRingMax = 70,

	Archetypes = {
		Chaser = {
			DisplayName = "Chaser",
			Role = "Chaser",
			Color = Color3.fromRGB(214, 70, 70),
			SpeedMult = 0.95,
			CanDash = true,
			CanSlide = true,
			DetectRange = 400,
			FleeRange = 0,
			FleeDistance = 0,
			DashRange = 20,
			DashMinRange = 8,
			TagRange = 4.5,
			TagCooldown = 1.6,
			TagKnockback = 60,
			TagStun = 0.55,
		},
		Runner = {
			DisplayName = "Runner",
			Role = "Runner",
			Color = Color3.fromRGB(70, 140, 220),
			SpeedMult = 0.92,
			CanDash = true,
			CanSlide = true,
			DetectRange = 0,
			FleeRange = 55,
			FleeDistance = 30,
			DashRange = 0,
			DashMinRange = 0,
			TagRange = 0,
			TagCooldown = 0,
			TagKnockback = 0,
			TagStun = 0,
		},
	} :: { [string]: Archetype },
}

return NPCConfig
