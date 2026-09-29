--!strict
-- Locomotion: one movement brain for any Humanoid character.
--
-- Players run it on their own client (they own their character's physics); NPCs run it on the server.
-- A controller (keyboard/gamepad/touch or an AI brain) feeds it an Intent every physics step and the
-- state machine (Ground / Air / Dash / Slide / Roll / WallRun / Mantle / Stun) turns that into motion.
--
-- Ground walking is left to the Humanoid (stairs, slopes, moving platforms) with a smoothed speed and
-- heading layered on top. Everything that needs exact control (dash, slide, wall run, mantle, air
-- steering) is driven by a LinearVelocity constraint or direct velocity edits.

local Shared = script.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)
local CharacterUtil = require(Shared.Util.CharacterUtil)
local Types = require(Shared.Types)
local Sensors = require(script.Parent.Sensors)

local States = script.Parent.States
local STATE_MODULES: { [string]: Types.State } = {
	Ground = require(States.GroundState),
	Air = require(States.AirState),
	Dash = require(States.DashState),
	Slide = require(States.SlideState),
	Roll = require(States.RollState),
	WallRun = require(States.WallRunState),
	Mantle = require(States.MantleState),
	Stun = require(States.StunState),
}

type Loco = Types.Loco
type Intent = Types.Intent

local Locomotion = {}
Locomotion.__index = Locomotion

local DRIVER_FORCE = 1e7
local FULL_FORCE = Vector3.new(DRIVER_FORCE, DRIVER_FORCE, DRIVER_FORCE)
local HORIZONTAL_FORCE = Vector3.new(DRIVER_FORCE, 0, DRIVER_FORCE)

function Locomotion.newIntent(): Intent
	return {
		Move = Vector3.zero,
		Sprint = false,
		JumpPressed = false,
		JumpHeld = false,
		DashPressed = false,
		DashDirection = nil,
		SlidePressed = false,
		SlideHeld = false,
	}
end

function Locomotion.new(character: Model, cfg: Types.MovementConfig, isLocal: boolean): Loco
	local humanoid = assert(CharacterUtil.getHumanoid(character), "Locomotion needs a Humanoid")
	local root = assert(CharacterUtil.getRoot(character), "Locomotion needs a root part")
	local rootToFeet = CharacterUtil.rootToFeet(humanoid, root)

	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = cfg.JumpVelocity
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local attachment = Instance.new("Attachment")
	attachment.Name = "LocomotionAttachment"
	attachment.Parent = root

	local driver = Instance.new("LinearVelocity")
	driver.Name = "LocomotionDriver"
	driver.Attachment0 = attachment
	driver.RelativeTo = Enum.ActuatorRelativeTo.World
	driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	driver.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	driver.MaxAxesForce = FULL_FORCE
	driver.VectorVelocity = Vector3.zero
	driver.Enabled = false
	driver.Parent = root

	local look = MathUtil.flatUnit(root.CFrame.LookVector)
	local yaw = if look.Magnitude > 0.1 then MathUtil.yawFromDirection(look) else 0

	local never = -math.huge
	local self = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Cfg = cfg,
		IsLocal = isLocal,
		Sensors = Sensors.new(character, cfg, rootToFeet),
		RootToFeet = rootToFeet,
		Driver = driver,
		DriverAttachment = attachment,

		StateChanged = Signal.new(),
		Events = Signal.new(),

		StateName = "None",
		PreviousStateName = "None",
		StateData = {},
		StateTime = 0,

		Time = 0,
		Velocity = root.AssemblyLinearVelocity,
		HSpeed = 0,
		HDir = if look.Magnitude > 0.1 then look else Vector3.new(0, 0, -1),
		Grounded = false,
		GroundedAt = never,
		GroundNormal = Vector3.yAxis,
		FloorDistance = math.huge,
		Suspended = false,
		Enabled = true,
		Destroyed = false,

		Speed = 0,
		MoveDir = if look.Magnitude > 0.1 then look else Vector3.new(0, 0, -1),
		FacingYaw = yaw,
		DesiredYaw = yaw,
		FaceLambda = cfg.FaceLambda,
		FaceEnabled = true,

		AirJumps = cfg.AirJumps,
		AirDashesUsed = 0,
		DashCharges = cfg.DashCharges,
		DashProgress = 0,
		NextDashAt = 0,
		SlideReadyAt = 0,
		MantleReadyAt = 0,
		WallRunReadyAt = 0,
		LastWallInstance = nil,
		LastWallEndAt = never,
		LastWallJumpAt = never,
		LandedAt = never,
		LandPenaltyUntil = never,
		LandPenaltyMult = 1,
		Flow = 0,
		LastFlowAt = never,

		JumpBufferedAt = never,
		DashBufferedAt = never,
		SlideBufferedAt = never,
	}
	setmetatable(self, Locomotion)

	local loco = (self :: any) :: Loco
	loco:ChangeState(if humanoid.FloorMaterial ~= Enum.Material.Air then "Ground" else "Air")
	return loco
end

function Locomotion.Destroy(self: Loco)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Driver.Enabled = false
	self.Driver:Destroy()
	self.DriverAttachment:Destroy()
	self.StateChanged:DisconnectAll()
	self.Events:DisconnectAll()
	if self.Humanoid.Parent then
		self.Humanoid.AutoRotate = true
	end
end

function Locomotion.Fire(self: Loco, eventName: string, data: any?)
	self.Events:Fire(eventName, data)
end

function Locomotion.ChangeState(self: Loco, name: string, data: { [string]: any }?)
	local nextModule = STATE_MODULES[name]
	if nextModule == nil then
		warn(`[Locomotion] unknown state '{name}'`)
		return
	end
	local previous = self.StateName
	local previousModule = STATE_MODULES[previous]
	if previousModule then
		previousModule.Exit(self, name)
	end
	self.PreviousStateName = previous
	self.StateName = name
	self.StateData = {}
	self.StateTime = 0
	nextModule.Enter(self, previous, data or {})
	self.StateChanged:Fire(name, previous)
end

-- Drive the character with the velocity constraint. nil turns it off.
-- horizontalOnly leaves the Y axis to gravity / the Humanoid.
function Locomotion.SetDriver(self: Loco, velocity: Vector3?, horizontalOnly: boolean?)
	local driver = self.Driver
	if velocity == nil then
		if driver.Enabled then
			driver.Enabled = false
		end
		return
	end
	driver.MaxAxesForce = if horizontalOnly then HORIZONTAL_FORCE else FULL_FORCE
	driver.VectorVelocity = velocity
	if not driver.Enabled then
		driver.Enabled = true
	end
end

function Locomotion.ApplyHumanoid(self: Loco, walkSpeed: number, direction: Vector3?)
	local humanoid = self.Humanoid
	humanoid.WalkSpeed = math.max(walkSpeed, 0.01)
	humanoid:Move(direction or Vector3.zero, false)
end

function Locomotion.FaceDirection(self: Loco, direction: Vector3, lambda: number?)
	local flat = MathUtil.flatUnit(direction)
	if flat.Magnitude < 0.01 then
		return
	end
	self.DesiredYaw = MathUtil.yawFromDirection(flat)
	if lambda then
		self.FaceLambda = lambda
	end
end

function Locomotion.GetFacingDirection(self: Loco): Vector3
	return MathUtil.directionFromYaw(self.FacingYaw)
end

function Locomotion.WantsJump(self: Loco): boolean
	return self.Time - self.JumpBufferedAt <= self.Cfg.JumpBuffer
end

function Locomotion.WantsDash(self: Loco): boolean
	return self.Time - self.DashBufferedAt <= self.Cfg.DashBuffer
end

function Locomotion.SpeedMultiplier(self: Loco): number
	return 1 + self.Cfg.FlowSpeedBonus * self.Flow
end

function Locomotion.AddFlow(self: Loco, amount: number)
	self.Flow = math.min(1, self.Flow + amount)
	self.LastFlowAt = self.Time
end

-- Launch upward/outward. `kind` is only used for events (Jump, Coyote, SlideJump, ...).
function Locomotion.Leap(self: Loco, velocity: Vector3, kind: string, allowCut: boolean?)
	self.JumpBufferedAt = -math.huge
	self.Root.AssemblyLinearVelocity = velocity
	self.Velocity = velocity
	if self.Grounded or self.StateName ~= "Air" then
		-- Same value as our launch speed, so the Humanoid's own jump impulse agrees with it.
		self.Humanoid.JumpPower = velocity.Y
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	self:Fire("Jump", kind)
	self:ChangeState("Air", { Jumped = true, AllowCut = allowCut ~= false })
end

-- Standard jump from the ground / coyote time. Jumping right after touchdown keeps and adds speed.
function Locomotion.Jump(self: Loco, kind: string)
	local cfg = self.Cfg
	local vel = self.Root.AssemblyLinearVelocity
	local hv = Vector3.new(vel.X, 0, vel.Z)
	local speed = hv.Magnitude
	if kind == "Ground" and self.Time - self.LandedAt <= cfg.ChainHopWindow and speed > cfg.RunSpeed * 0.8 then
		local cap = cfg.SprintSpeed * cfg.ChainHopMaxMult * self:SpeedMultiplier()
		local boosted = math.max(speed, math.min(speed * (1 + cfg.ChainHopBoost), cap))
		hv = hv.Unit * boosted
		self:AddFlow(0.08)
		self:Fire("ChainHop", boosted)
	end
	self:Leap(Vector3.new(hv.X, cfg.JumpVelocity, hv.Z), kind, true)
end

-- Kick off a wall: away from it, carrying some of the speed along it, refreshing air options.
function Locomotion.WallJump(self: Loco, normal: Vector3, instance: BasePart?, intent: Intent)
	local cfg = self.Cfg
	local vel = self.Root.AssemblyLinearVelocity
	local hv = Vector3.new(vel.X, 0, vel.Z)
	local along = hv - normal * hv:Dot(normal)
	local out = normal * cfg.WallJumpAway + along * cfg.WallJumpForward

	-- Lean the kick toward where the player is steering, unless that means back into the wall.
	local steer = MathUtil.flatUnit(intent.Move)
	if steer.Magnitude > 0.1 and steer:Dot(normal) > -0.3 then
		out += steer * 6
	end

	self.LastWallInstance = instance
	self.LastWallJumpAt = self.Time
	self.AirJumps = cfg.AirJumps
	self.AirDashesUsed = math.max(0, self.AirDashesUsed - 1)
	self:AddFlow(0.2)
	self:Leap(Vector3.new(out.X, cfg.WallJumpUp, out.Z), "WallJump", true)
end

function Locomotion.TryDash(self: Loco, intent: Intent): boolean
	local cfg = self.Cfg
	if self.Time < self.NextDashAt or self.DashCharges < 1 then
		return false
	end
	if self.StateName == "Mantle" or self.StateName == "Stun" then
		return false
	end
	local airborne = not self.Grounded
	if airborne and self.AirDashesUsed >= cfg.AirDashes then
		return false
	end

	local dir = MathUtil.flatUnit(intent.DashDirection or Vector3.zero)
	if dir.Magnitude < 0.1 then
		dir = MathUtil.flatUnit(intent.Move)
	end
	if dir.Magnitude < 0.1 then
		dir = self:GetFacingDirection()
	end

	self.DashBufferedAt = -math.huge
	self.DashCharges -= 1
	if airborne then
		self.AirDashesUsed += 1
	end
	self.NextDashAt = self.Time + cfg.DashCooldown
	self:ChangeState("Dash", { Direction = dir, Airborne = airborne })
	return true
end

function Locomotion.TryMantle(self: Loco, direction: Vector3, minHeight: number): boolean
	local cfg = self.Cfg
	if not cfg.MantleEnabled or self.Time < self.MantleReadyAt then
		return false
	end
	local dir = MathUtil.flatUnit(direction)
	if dir.Magnitude < 0.1 then
		return false
	end
	local ledge = self.Sensors:FindLedge(self.Root.Position, dir, minHeight)
	if not ledge then
		return false
	end
	self:ChangeState("Mantle", { Ledge = ledge })
	return true
end

function Locomotion.Stun(self: Loco, duration: number, velocity: Vector3?)
	self:ChangeState("Stun", { Duration = duration, Velocity = velocity })
end

local function isSuspendedState(humanoid: Humanoid): boolean
	if humanoid.Health <= 0 or humanoid.Sit then
		return true
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.Dead
		or state == Enum.HumanoidStateType.PlatformStanding
end

function Locomotion.Step(self: Loco, dt: number, intent: Intent)
	if self.Destroyed or not self.Enabled or dt <= 0 then
		return
	end
	local humanoid, root, cfg = self.Humanoid, self.Root, self.Cfg

	-- Let the default behaviours (ladders, water, seats) run untouched.
	if isSuspendedState(humanoid) then
		if not self.Suspended then
			self.Suspended = true
			self:SetDriver(nil)
			humanoid.AutoRotate = true
			if self.StateName ~= "Ground" then
				self:ChangeState("Ground")
			end
		end
		return
	end
	if self.Suspended then
		self.Suspended = false
		local look = MathUtil.flatUnit(root.CFrame.LookVector)
		if look.Magnitude > 0.1 then
			self.FacingYaw = MathUtil.yawFromDirection(look)
			self.DesiredYaw = self.FacingYaw
		end
	end
	humanoid.AutoRotate = false

	self.Time += dt
	self.StateTime += dt

	-- Sample the physical world.
	local vel = root.AssemblyLinearVelocity
	self.Velocity = vel
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	self.HSpeed = flatVel.Magnitude
	if self.HSpeed > 1 then
		self.HDir = flatVel / self.HSpeed
	end
	self.Grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if self.Grounded then
		self.GroundedAt = self.Time
	end
	local ground = self.Sensors:ProbeGround(root.Position, cfg.GroundProbeDistance)
	if ground then
		self.GroundNormal = ground.Normal
		self.FloorDistance = math.max(0, ground.Distance - self.RootToFeet)
	else
		self.GroundNormal = Vector3.yAxis
		self.FloorDistance = math.huge
	end

	-- Input buffers.
	if intent.JumpPressed then
		self.JumpBufferedAt = self.Time
	end
	if intent.DashPressed then
		self.DashBufferedAt = self.Time
	end
	if intent.SlidePressed then
		self.SlideBufferedAt = self.Time
	end

	-- Dash charges recharge over time; flow speeds that up.
	if self.DashCharges < cfg.DashCharges then
		local rechargeTime = cfg.DashRechargeTime / (1 + cfg.FlowRechargeBonus * self.Flow)
		self.DashProgress += dt / rechargeTime
		if self.DashProgress >= 1 then
			self.DashProgress = 0
			self.DashCharges += 1
		end
	else
		self.DashProgress = 0
	end

	-- Flow fades if you stop chaining moves.
	if self.Flow > 0 and self.Time - self.LastFlowAt > cfg.FlowDecayDelay then
		self.Flow = math.max(0, self.Flow - cfg.FlowDecayRate * dt)
	end

	-- Run the active state.
	self.FaceLambda = cfg.FaceLambda
	local state = STATE_MODULES[self.StateName]
	if state then
		state.Update(self, dt, intent)
	end

	-- Smoothed body rotation shared by every state. It starts from the part's real orientation (so
	-- platforms or collisions that turned us are respected) and only writes the CFrame while there is
	-- actually turning to do, which keeps physics undisturbed the rest of the time.
	if self.FaceEnabled and not self.Destroyed then
		local look = MathUtil.flatUnit(root.CFrame.LookVector)
		local currentYaw = if look.Magnitude > 0.05 then MathUtil.yawFromDirection(look) else self.FacingYaw
		local nextYaw = MathUtil.dampAngle(currentYaw, self.DesiredYaw, self.FaceLambda, dt)
		self.FacingYaw = nextYaw
		if math.abs(MathUtil.wrapAngle(self.DesiredYaw - currentYaw)) > 0.0008 then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, nextYaw, 0)
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- We own jumping; make sure the default controls never fire a second jump.
	humanoid.Jump = false
end

return Locomotion
