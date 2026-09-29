--!strict
-- Shared type definitions. States talk to the `Loco` interface instead of requiring the Locomotion
-- module directly, which keeps the module graph free of cycles.

local Shared = script.Parent
local MovementConfigModule = require(Shared.Config.MovementConfig)
local SignalModule = require(Shared.Util.Signal)

export type MovementConfig = MovementConfigModule.MovementConfig
export type Signal = SignalModule.Signal

-- What a controller (keyboard/gamepad/touch or an NPC brain) wants this frame.
export type Intent = {
	Move: Vector3, -- world space, horizontal, magnitude 0..1
	Sprint: boolean,
	JumpPressed: boolean, -- true only on the frame the button went down
	JumpHeld: boolean,
	DashPressed: boolean,
	DashDirection: Vector3?, -- optional override (AI / aim assist); otherwise move input or facing
	SlidePressed: boolean,
	SlideHeld: boolean,
}

export type Ledge = {
	Top: Vector3, -- point on the walkable top surface
	Normal: Vector3, -- wall face normal, pointing away from the wall
	Height: number, -- top height above the character's feet
	StandPosition: Vector3, -- where the root part should end up
	Instance: BasePart,
}

export type SensorsApi = {
	Cast: (self: SensorsApi, origin: Vector3, direction: Vector3) -> RaycastResult?,
	ProbeGround: (self: SensorsApi, rootPosition: Vector3, extraDistance: number) -> RaycastResult?,
	ProbeWall: (self: SensorsApi, rootPosition: Vector3, direction: Vector3, distance: number) -> RaycastResult?,
	ProbeSides: (
		self: SensorsApi,
		rootPosition: Vector3,
		forward: Vector3,
		distance: number
	) -> (RaycastResult?, RaycastResult?),
	FindLedge: (self: SensorsApi, rootPosition: Vector3, direction: Vector3, minHeight: number?) -> Ledge?,
}

export type Loco = {
	-- References
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Cfg: MovementConfig,
	IsLocal: boolean,
	Sensors: SensorsApi,
	RootToFeet: number,
	Driver: LinearVelocity,
	DriverAttachment: Attachment,

	-- Signals
	StateChanged: Signal, -- (newState: string, oldState: string)
	Events: Signal, -- (eventName: string, data: any)

	-- State machine
	StateName: string,
	PreviousStateName: string,
	StateData: { [string]: any },
	StateTime: number,

	-- Sampled every step
	Time: number,
	Velocity: Vector3,
	HSpeed: number,
	HDir: Vector3,
	Grounded: boolean,
	GroundedAt: number,
	GroundNormal: Vector3,
	FloorDistance: number,
	Suspended: boolean,
	Enabled: boolean,
	Destroyed: boolean,

	-- Movement model
	Speed: number,
	MoveDir: Vector3,
	FacingYaw: number,
	DesiredYaw: number,
	FaceLambda: number,
	FaceEnabled: boolean,

	-- Abilities
	AirJumps: number,
	AirDashesUsed: number,
	DashCharges: number,
	DashProgress: number,
	NextDashAt: number,
	SlideReadyAt: number,
	MantleReadyAt: number,
	WallRunReadyAt: number,
	LastWallInstance: BasePart?,
	LastWallEndAt: number,
	LastWallJumpAt: number,
	LandedAt: number,
	LandPenaltyUntil: number,
	LandPenaltyMult: number,
	Flow: number,
	LastFlowAt: number,

	-- Buffered inputs (stamped with Loco.Time)
	JumpBufferedAt: number,
	DashBufferedAt: number,
	SlideBufferedAt: number,

	-- Methods
	Step: (self: Loco, dt: number, intent: Intent) -> (),
	Destroy: (self: Loco) -> (),
	ChangeState: (self: Loco, name: string, data: { [string]: any }?) -> (),
	Fire: (self: Loco, eventName: string, data: any?) -> (),
	SetDriver: (self: Loco, velocity: Vector3?, horizontalOnly: boolean?) -> (),
	ApplyHumanoid: (self: Loco, walkSpeed: number, direction: Vector3?) -> (),
	FaceDirection: (self: Loco, direction: Vector3, lambda: number?) -> (),
	GetFacingDirection: (self: Loco) -> Vector3,
	WantsJump: (self: Loco) -> boolean,
	WantsDash: (self: Loco) -> boolean,
	Jump: (self: Loco, kind: string) -> (),
	Leap: (self: Loco, velocity: Vector3, kind: string, allowCut: boolean?) -> (),
	WallJump: (self: Loco, normal: Vector3, instance: BasePart?, intent: Intent) -> (),
	TryDash: (self: Loco, intent: Intent) -> boolean,
	TryMantle: (self: Loco, direction: Vector3, minHeight: number) -> boolean,
	AddFlow: (self: Loco, amount: number) -> (),
	SpeedMultiplier: (self: Loco) -> number,
	Stun: (self: Loco, duration: number, velocity: Vector3?) -> (),
}

-- Anything that can tell visual controllers which Locomotion the local character currently has.
export type LocoProvider = {
	LocoChanged: Signal, -- fires (loco: Loco?)
	GetLocomotion: () -> Loco?,
}

export type State = {
	Enter: (loco: Loco, previous: string?, data: { [string]: any }) -> (),
	Exit: (loco: Loco, nextState: string) -> (),
	Update: (loco: Loco, dt: number, intent: Intent) -> (),
}

return {}
