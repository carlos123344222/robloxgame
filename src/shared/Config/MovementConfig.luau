--!strict
-- Every number that shapes how movement *feels* lives here.
-- Speeds are studs/second, accelerations studs/second², times are seconds, angles radians.

local MovementConfig = {
	-- Ground locomotion ------------------------------------------------------
	WalkSpeed = 11,
	RunSpeed = 20,
	SprintSpeed = 28,
	AutoSprint = false, -- true = always sprint at full input (Shift no longer needed)
	GroundAccel = 120, -- 0 -> run speed in ~0.17s
	SprintAccel = 38, -- run -> sprint in ~0.2s
	GroundDecel = 80, -- releasing sprint while still steering
	StopDecel = 170, -- letting go of the stick (short glide instead of a dead stop)
	BrakeDecel = 260, -- skid when reversing direction at speed
	TurnRateRun = 18, -- heading change per second while running
	TurnRateSprint = 9, -- heavier arcs while sprinting
	SnapTurnSpeed = 6, -- below this speed heading snaps to the input
	PivotAngle = math.rad(120), -- input this far from heading at speed = skid first
	PivotMinSpeed = 16,
	GroundLeaveDelay = 0.06, -- tolerance before "I'm airborne" (stairs, bumps)
	FaceLambda = 20, -- body rotation smoothing (higher = snappier)
	GroundProbeDistance = 10,

	-- Jump & air -------------------------------------------------------------
	JumpVelocity = 54,
	CoyoteTime = 0.15, -- measured from the last frame on the ground (includes GroundLeaveDelay)
	JumpBuffer = 0.14,
	JumpCutMultiplier = 0.42, -- releasing jump early trims the ascent
	JumpCutMinVy = 10,
	FallGravityMult = 1.5, -- snappy descent
	ApexGravityMult = 0.72, -- a touch of hang time at the top
	ApexBand = 8,
	TerminalVelocity = 150,
	AirAccel = 55,
	AirTurnRate = 5.5,
	AirDrag = 2.5,
	AirJumps = 1,
	AirJumpVelocity = 50,
	ChainHopWindow = 0.09, -- jumping this soon after landing keeps (and adds) speed
	ChainHopBoost = 0.05,
	ChainHopMaxMult = 1.22,

	-- Dash -------------------------------------------------------------------
	DashSpeed = 92,
	DashDuration = 0.2,
	DashExitSpeedMult = 0.9, -- x SprintSpeed, carried out of the dash
	DashCharges = 2,
	DashRechargeTime = 2.4,
	DashCooldown = 0.32,
	DashBuffer = 0.16,
	AirDashes = 1,
	DashInvulnTime = 0.16,

	-- Slide ------------------------------------------------------------------
	SlideMinSpeed = 15,
	SlideEntryMult = 1.15,
	SlideMaxSpeed = 40,
	SlideFriction = 15,
	SlideSlopeFactor = 0.9,
	SlideSteerRate = 1.7,
	SlideEndSpeed = 8,
	SlideMinTime = 0.2,
	SlideMaxTime = 2.2,
	SlideCooldown = 0.25,
	SlideBuffer = 0.15,
	SlideJumpMult = 1.1,
	SlideJumpVelocity = 46,

	-- Landing & roll ---------------------------------------------------------
	RollWindow = 0.25, -- press slide this soon before touchdown to roll
	RollMinImpact = 38,
	RollDuration = 0.46,
	RollMinSpeed = 14,
	RollImpactSpeedBonus = 0.15,
	RollExitMult = 0.9,
	HardLandImpact = 78, -- fall speed that hurts your momentum
	HardLandMaxImpact = 140,
	HardLandStunMin = 0.22,
	HardLandStunMax = 0.65,
	HardLandSpeedMult = 0.4,

	-- Wall run / wall jump ---------------------------------------------------
	WallRunEnabled = true,
	WallRunMinSpeed = 15,
	WallRunSpeed = 26,
	WallRunDuration = 1.7,
	WallRunUpBoost = 16,
	WallRunGravity = 34,
	WallRunSinkSpeed = 5,
	WallRunCheckDist = 2.7,
	WallRunMinHeight = 4.5, -- must be this far above the floor
	WallRunStickSpeed = 3,
	WallRunCooldown = 0.2,
	WallRunSameWallDelay = 1.2,
	WallRunMinAlign = 0.45, -- 0 = head-on, 1 = perfectly parallel
	WallJumpUp = 54,
	WallJumpAway = 34,
	WallJumpForward = 0.65,
	WallJumpReach = 2.6,
	WallJumpGrace = 0.14,
	WallJumpSameWallDelay = 0.9,
	WallSlideSpeed = 16,

	-- Mantle / vault ---------------------------------------------------------
	MantleEnabled = true,
	MantleMinHeight = 3.3,
	MantleMaxHeight = 7.4,
	MantleGroundMinHeight = 3.6, -- from the ground, only pop up ledges taller than this
	MantleReach = 3.0,
	MantleSpeed = 36,
	MantleExitSpeed = 16,
	MantleCooldown = 0.25,
	MantleMaxRise = 30,
	MantleDepth = 1.4,
	CharacterHeight = 5.4,

	-- Flow: chaining moves builds a small speed / recharge bonus -------------
	FlowSpeedBonus = 0.1,
	FlowRechargeBonus = 0.5,
	FlowDecayDelay = 2.2,
	FlowDecayRate = 0.14,
}

export type MovementConfig = typeof(MovementConfig)

return MovementConfig
