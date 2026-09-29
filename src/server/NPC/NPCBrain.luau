--!strict
-- Decision layer for an NPC. It only decides *what it wants* (a goal, a dash, a slide); the Navigator
-- turns that into steering and Locomotion into motion, so NPCs use exactly the same movement toolkit
-- (sprint, slide, dash, mantle, jumps) as players do.
--
--   Chaser: hunts the nearest player/runner with predictive interception, dashes and slides in.
--   Runner: flees from threats toward open ground, dashing when cornered.
--   Both wander when there is nothing to do.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterUtil = require(Shared.Util.CharacterUtil)
local Locomotion = require(Shared.Movement.Locomotion)
local MathUtil = require(Shared.Util.MathUtil)
local MovementConfig = require(Shared.Config.MovementConfig)
local Types = require(Shared.Types)

local NPCAnimator = require(script.Parent.NPCAnimator)
local NPCConfig = require(script.Parent.NPCConfig)
local Navigator = require(script.Parent.Navigator)

type Loco = Types.Loco
type Intent = Types.Intent

export type Context = {
	GetChaseTargets: () -> { Model },
	GetThreats: () -> { Model },
	OnTag: (brain: Brain, target: Model) -> (),
}

export type Brain = {
	Character: Model,
	Archetype: NPCConfig.Archetype,
	Loco: Loco,
	Dead: boolean,
	Update: (self: Brain, dt: number) -> (),
	Destroy: (self: Brain) -> (),
}

type Impl = Brain & {
	Nav: Navigator.Navigator,
	Animator: NPCAnimator.NPCAnimator,
	Intent: Intent,
	Context: Context,
	Cfg: Types.MovementConfig,
	Home: Vector3,
	Rng: Random,
	Now: number,
	Target: Model?,
	NextRetarget: number,
	NextTag: number,
	NextDash: number,
	NextSlide: number,
	NextJumpAt: number,
	JumpHoldUntil: number,
	SlideHoldUntil: number,
	WaitUntil: number,
	WanderGoal: Vector3?,
	FleeGoalAt: number,
	WantSprint: boolean,
	LastArrived: boolean,
	LastFailed: boolean,
	Connections: { RBXScriptConnection },
}

local NPCBrain = {}
NPCBrain.__index = NPCBrain

local TAU = math.pi * 2

function NPCBrain.new(character: Model, archetype: NPCConfig.Archetype, context: Context): Brain
	-- Each NPC gets its own copy of the shared tuning, scaled by its archetype.
	local cfg = table.clone(MovementConfig)
	cfg.WalkSpeed *= archetype.SpeedMult
	cfg.RunSpeed *= archetype.SpeedMult
	cfg.SprintSpeed *= archetype.SpeedMult
	cfg.WallRunEnabled = false -- keeps per-NPC raycast cost down; the toolkit is otherwise identical

	local loco = Locomotion.new(character, cfg, false)
	local root = assert(CharacterUtil.getRoot(character))
	local humanoid = assert(CharacterUtil.getHumanoid(character))

	local self = setmetatable({
		Character = character,
		Archetype = archetype,
		Loco = loco,
		Dead = false,
		Nav = Navigator.new(loco),
		Animator = NPCAnimator.new(character, loco),
		Intent = Locomotion.newIntent(),
		Context = context,
		Cfg = cfg,
		Home = root.Position,
		Rng = Random.new(),
		Now = 0,
		Target = nil,
		NextRetarget = 0,
		NextTag = 0,
		NextDash = 0,
		NextSlide = 0,
		NextJumpAt = 0,
		JumpHoldUntil = 0,
		SlideHoldUntil = 0,
		WaitUntil = 0,
		WanderGoal = nil,
		FleeGoalAt = -math.huge,
		WantSprint = false,
		LastArrived = false,
		LastFailed = false,
		Connections = {},
	}, NPCBrain)

	-- Publish movement state the same way players do, so every client can pose the NPC.
	local connection = loco.StateChanged:Connect(function(newState: string)
		character:SetAttribute("MoveState", newState)
		character:SetAttribute("MoveStateT", Workspace:GetServerTimeNow())
		local side = if newState == "WallRun" then loco.StateData.Side else nil
		character:SetAttribute("MoveArg", if typeof(side) == "number" then side else 0)
	end)
	loco.Events:Connect(function(name: string)
		if name == "AirJump" or name == "WallJump" or name == "Skid" then
			character:SetAttribute("MoveEvent", name)
			character:SetAttribute("MoveEventT", Workspace:GetServerTimeNow())
		end
	end)

	local impl = (self :: any) :: Impl
	table.insert(impl.Connections, connection :: any)
	table.insert(
		impl.Connections,
		humanoid.Died:Connect(function()
			impl.Dead = true
		end)
	)
	return impl
end

function NPCBrain.Destroy(self: Impl)
	self.Dead = true
	for _, connection in self.Connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)
	self.Nav:Destroy()
	self.Animator:Destroy()
	self.Loco:Destroy()
end

local function feetOf(loco: Loco): Vector3
	return loco.Root.Position - Vector3.new(0, loco.RootToFeet, 0)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function pickTarget(self: Impl): Model?
	local position = self.Loco.Root.Position
	local best: Model? = nil
	local bestDistance = self.Archetype.DetectRange
	for _, candidate in self.Context.GetChaseTargets() do
		if candidate ~= self.Character and CharacterUtil.isAlive(candidate) then
			local root = CharacterUtil.getRoot(candidate)
			if root then
				local distance = (root.Position - position).Magnitude
				if candidate == self.Target then
					distance *= 0.7 -- stick with the current target unless another is clearly closer
				end
				if distance < bestDistance then
					best = candidate
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function wander(self: Impl)
	self.WantSprint = false
	local nav = self.Nav

	if self.WanderGoal ~= nil and (self.LastArrived or self.LastFailed) then
		self.WanderGoal = nil
		self.WaitUntil = self.Now + self.Rng:NextNumber(0.6, 2.4)
	end
	if self.Now < self.WaitUntil then
		nav:SetGoal(nil)
		return
	end
	if self.WanderGoal == nil then
		local angle = self.Rng:NextNumber(0, TAU)
		local radius = self.Rng:NextNumber(12, 48)
		local candidate = self.Home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local ground = self.Loco.Sensors:Cast(candidate + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0))
		if ground and math.abs(ground.Position.Y - self.Home.Y) < 15 and ground.Normal.Y > 0.7 then
			self.WanderGoal = ground.Position
			nav:SetGoal(ground.Position, 2.5, true)
		end
	end
end

local function updateChaser(self: Impl)
	local archetype = self.Archetype
	local loco = self.Loco
	local intent = self.Intent

	if self.Now >= self.NextRetarget then
		self.NextRetarget = self.Now + 0.4
		self.Target = pickTarget(self)
	end
	local target = self.Target
	local targetRoot = if target and CharacterUtil.isAlive(target) then CharacterUtil.getRoot(target) else nil
	if target == nil or targetRoot == nil then
		self.Target = nil
		wander(self)
		return
	end
	self.WanderGoal = nil
	self.WantSprint = true

	local position = loco.Root.Position
	local delta = Vector3.new(targetRoot.Position.X - position.X, 0, targetRoot.Position.Z - position.Z)
	local distance = delta.Magnitude
	local toTarget = MathUtil.flatUnit(delta)

	-- Aim where the target will be, not where it is.
	local velocity = targetRoot.AssemblyLinearVelocity
	local lead = if distance > 10 then math.clamp(distance / math.max(loco.HSpeed, 14), 0, 0.8) else 0
	local aim = targetRoot.Position + Vector3.new(velocity.X, 0, velocity.Z) * lead - Vector3.new(0, 3, 0)
	self.Nav:SetGoal(aim, 1.5, false)

	local feet = feetOf(loco)
	local facing = toTarget:Dot(loco.HDir)

	if
		archetype.CanDash
		and loco.DashCharges >= 1
		and self.Now >= self.NextDash
		and distance >= archetype.DashMinRange
		and distance <= archetype.DashRange
		and facing > 0.75
		and self.Nav:CanWalk(feet, targetRoot.Position - Vector3.new(0, 3, 0))
	then
		intent.DashPressed = true
		intent.DashDirection = toTarget
		self.NextDash = self.Now + self.Rng:NextNumber(1.6, 3.2)
	end

	if
		archetype.CanSlide
		and loco.Grounded
		and self.Now >= self.NextSlide
		and loco.HSpeed >= self.Cfg.SlideMinSpeed
		and distance > 6
		and distance < 16
		and facing > 0.85
	then
		intent.SlidePressed = true
		self.SlideHoldUntil = self.Now + 0.55
		self.NextSlide = self.Now + self.Rng:NextNumber(3, 6)
	end

	if distance <= archetype.TagRange and math.abs(targetRoot.Position.Y - position.Y) < 6 and self.Now >= self.NextTag then
		self.NextTag = self.Now + archetype.TagCooldown
		self.Context.OnTag(self, target)
	end
end

-- Picks a point ahead of the runner that is far from the threat and reachable in a straight line.
local function chooseFleePoint(self: Impl, threatPosition: Vector3): Vector3?
	local loco = self.Loco
	local feet = feetOf(loco)
	local away = MathUtil.flatUnit(feet - threatPosition)
	if away.Magnitude < 0.1 then
		away = MathUtil.directionFromYaw(self.Rng:NextNumber(0, TAU))
	end

	local best: Vector3? = nil
	local bestScore = -math.huge
	local distance = self.Archetype.FleeDistance
	for i = 0, 11 do
		local direction = MathUtil.rotateY(away, (i / 12) * TAU)
		local candidate = feet + direction * distance
		local ground = loco.Sensors:Cast(candidate + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0))
		if ground and math.abs(ground.Position.Y - feet.Y) < 10 and ground.Normal.Y > 0.7 then
			local point = ground.Position
			local score = flatDistance(point, threatPosition) + direction:Dot(away) * 8
			if self.Nav:CanWalk(feet, point) then
				score += 20
			end
			score -= math.max(0, flatDistance(point, self.Home) - 130) * 0.5
			if score > bestScore then
				bestScore = score
				best = point
			end
		end
	end
	return best
end

local function updateRunner(self: Impl)
	local archetype = self.Archetype
	local loco = self.Loco
	local intent = self.Intent
	local position = loco.Root.Position

	local threatRoot: BasePart? = nil
	local threatDistance = archetype.FleeRange
	for _, candidate in self.Context.GetThreats() do
		if candidate ~= self.Character and CharacterUtil.isAlive(candidate) then
			local root = CharacterUtil.getRoot(candidate)
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < threatDistance then
					threatDistance = distance
					threatRoot = root
				end
			end
		end
	end

	if threatRoot == nil then
		wander(self)
		return
	end

	self.WanderGoal = nil
	self.WantSprint = true
	if self.Now - self.FleeGoalAt > 0.6 or self.LastArrived or self.LastFailed then
		self.FleeGoalAt = self.Now
		local point = chooseFleePoint(self, threatRoot.Position)
		if point then
			self.Nav:SetGoal(point, 3, false)
		end
	end

	if archetype.CanDash and loco.DashCharges >= 1 and self.Now >= self.NextDash and threatDistance < 10 then
		local away = MathUtil.flatUnit(position - threatRoot.Position)
		local heading = if loco.HSpeed > 4 then loco.HDir else away
		intent.DashPressed = true
		intent.DashDirection = MathUtil.flatUnit(away + heading)
		self.NextDash = self.Now + self.Rng:NextNumber(1.2, 2.4)
	end
end

function NPCBrain.Update(self: Impl, dt: number)
	local loco = self.Loco
	if self.Dead or loco.Destroyed then
		return
	end
	self.Now += dt

	local intent = self.Intent
	intent.JumpPressed = false
	intent.DashPressed = false
	intent.DashDirection = nil
	intent.SlidePressed = false

	if self.Archetype.Role == "Chaser" then
		updateChaser(self)
	else
		updateRunner(self)
	end

	local maxSpeed = (if self.WantSprint then self.Cfg.SprintSpeed else self.Cfg.RunSpeed) * loco:SpeedMultiplier()
	local nav = self.Nav:Step(dt, maxSpeed)
	self.LastArrived = nav.Arrived
	self.LastFailed = nav.Failed

	intent.Move = nav.Direction * nav.Speed01
	intent.Sprint = self.WantSprint and nav.Speed01 > 0.7
	if nav.Jump and self.Now >= self.NextJumpAt then
		intent.JumpPressed = true
		self.JumpHoldUntil = self.Now + 0.4
		self.NextJumpAt = self.Now + 0.6
	end
	intent.JumpHeld = self.Now < self.JumpHoldUntil
	intent.SlideHeld = self.Now < self.SlideHoldUntil

	loco:Step(dt, intent)
	self.Animator:Update(dt)
end

return NPCBrain
