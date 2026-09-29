--!strict
-- Procedural body language for EVERY character (players and NPCs), computed locally each frame from
-- replicated velocity plus the replicated MoveState attributes. Nothing here is networked, and it needs
-- no animation assets: lean into speed and turns, lay back in slides, flip on rolls / double jumps.
--
-- It works by offsetting the character's Root Motor6D.C0, which the Animator never writes to.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterUtil = require(Shared.Util.CharacterUtil)
local MathUtil = require(Shared.Util.MathUtil)
local MovementConfig = require(Shared.Config.MovementConfig)
local SpringModule = require(Shared.Util.Spring)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Spring = SpringModule.Spring

export type Pose = {
	Character: Model,
	Root: BasePart,
	Joint: Motor6D,
	BaseC0: CFrame,
	Pitch: Spring,
	Roll: Spring,
	Drop: Spring,
	LastYaw: number,
	YawRate: number,
	Trail: Trail,
	Loco: Loco?,
	AirJumpAt: number,
}

local TAG = "MovementCharacter"
local TAU = math.pi * 2
local AIR_JUMP_FLIP_TIME = 0.42
local GRAVITY_REFERENCE = 196.2

local PoseController = {}

local poses: { [Model]: Pose } = {}
local localLoco: Loco? = nil

local function createTrail(root: BasePart): Trail
	local top = Instance.new("Attachment")
	top.Name = "WCT_TrailTop"
	top.Position = Vector3.new(0, 1.3, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "WCT_TrailBottom"
	bottom.Position = Vector3.new(0, -1.5, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "WCT_Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.28
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.7
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
	trail.Enabled = false
	trail.Parent = root
	return trail
end

local function untrack(character: Model)
	local pose = poses[character]
	if not pose then
		return
	end
	poses[character] = nil
	if pose.Joint.Parent then
		pose.Joint.C0 = pose.BaseC0
	end
	pose.Trail:Destroy()
end

local function track(character: Model)
	if poses[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Humanoid", 10)
	character:WaitForChild("LowerTorso", 3) -- R15 only; R6 falls through to RootJoint
	if root == nil or not root:IsA("BasePart") or poses[character] then
		return
	end
	local joint = CharacterUtil.getRootJoint(character)
	if joint == nil then
		return
	end

	local look = MathUtil.flatUnit(root.CFrame.LookVector)
	poses[character] = {
		Character = character,
		Root = root,
		Joint = joint,
		BaseC0 = joint.C0,
		Pitch = SpringModule.new(0, 16),
		Roll = SpringModule.new(0, 14),
		Drop = SpringModule.new(0, 14),
		LastYaw = if look.Magnitude > 0.1 then MathUtil.yawFromDirection(look) else 0,
		YawRate = 0,
		Trail = createTrail(root),
		Loco = if localLoco and localLoco.Character == character then localLoco else nil,
		AirJumpAt = -math.huge,
	}
end

-- Resolves the pose driver: exact state from our own Locomotion, replicated attributes for everyone else.
local function readState(pose: Pose, now: number): (string, number, number, number)
	local loco = pose.Loco
	if loco and not loco.Destroyed then
		local side = loco.StateData.Side
		return loco.StateName, loco.StateTime, if typeof(side) == "number" then side else 0, now - pose.AirJumpAt
	end

	local character = pose.Character
	local name = character:GetAttribute("MoveState")
	local stamp = character:GetAttribute("MoveStateT")
	local arg = character:GetAttribute("MoveArg")
	local event = character:GetAttribute("MoveEvent")
	local eventStamp = character:GetAttribute("MoveEventT")

	local airJumpAge = math.huge
	if event == "AirJump" and typeof(eventStamp) == "number" then
		airJumpAge = now - eventStamp
	end
	return if typeof(name) == "string" then name else "Ground",
		if typeof(stamp) == "number" then math.max(0, now - stamp) else 0,
		if typeof(arg) == "number" then arg else 0,
		airJumpAge
end

local function step(pose: Pose, dt: number, now: number)
	local cfg = MovementConfig
	local root = pose.Root
	local velocity = root.AssemblyLinearVelocity
	local hSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	local look = MathUtil.flatUnit(root.CFrame.LookVector)
	if look.Magnitude > 0.1 and dt > 0 then
		local yaw = MathUtil.yawFromDirection(look)
		local rate = MathUtil.wrapAngle(yaw - pose.LastYaw) / dt
		pose.LastYaw = yaw
		pose.YawRate = MathUtil.damp(pose.YawRate, math.clamp(rate, -14, 14), 14, dt)
	end

	local state, age, arg, airJumpAge = readState(pose, now)
	local speedFraction = MathUtil.saturate(hSpeed / cfg.SprintSpeed)

	-- Default: lean into speed, bank into turns (centripetal acceleration = yaw rate x speed).
	local pitch = -math.rad(13) * speedFraction
	local roll = math.clamp(math.atan(pose.YawRate * hSpeed / GRAVITY_REFERENCE) * 0.7, -math.rad(16), math.rad(16))
	local drop = 0
	local flip = 0
	local trailOn = hSpeed > cfg.SprintSpeed + 2
	local trailColor = Color3.fromRGB(190, 225, 255)

	if state == "Slide" then
		pitch, roll, drop = math.rad(52), 0, -0.9
		trailOn = true
	elseif state == "Dash" then
		pitch, roll = -math.rad(36), 0
		trailOn = true
		trailColor = Color3.fromRGB(120, 200, 255)
	elseif state == "WallRun" then
		-- Tilt away from the wall (side +1 = wall on the right).
		pitch, roll = -math.rad(8), arg * math.rad(15)
		trailOn = true
		trailColor = Color3.fromRGB(255, 220, 140)
	elseif state == "Mantle" then
		pitch, roll = -math.rad(22), 0
	elseif state == "Roll" then
		flip = -TAU * MathUtil.easeInOutSine(MathUtil.saturate(age / cfg.RollDuration))
		pitch, roll, drop = 0, 0, -0.7
	elseif state == "Stun" then
		pitch, roll = math.rad(20), 0
	elseif state == "Air" then
		pitch = -math.rad(10) * speedFraction - math.clamp(velocity.Y / 80, -0.6, 0.6) * math.rad(10)
	end

	if airJumpAge >= 0 and airJumpAge < AIR_JUMP_FLIP_TIME then
		flip += -TAU * MathUtil.easeInOutSine(airJumpAge / AIR_JUMP_FLIP_TIME)
	end

	pose.Pitch.Target = pitch
	pose.Roll.Target = roll
	pose.Drop.Target = drop
	local p = pose.Pitch:Update(dt) + flip
	local r = pose.Roll:Update(dt)
	local d = pose.Drop:Update(dt)

	-- Rotate in root-part space, then re-apply the joint's own orientation (identity on R15).
	local base = pose.BaseC0
	local baseRotation = base - base.Position
	pose.Joint.C0 = CFrame.new(base.Position + Vector3.new(0, d, 0)) * CFrame.Angles(p, 0, r) * baseRotation

	pose.Trail.Color = ColorSequence.new(trailColor)
	pose.Trail.Enabled = trailOn
end

function PoseController.Start(movement: Types.LocoProvider)
	local function onLocoChanged(loco: Loco?)
		localLoco = loco
		for _, pose in poses do
			pose.Loco = nil
		end
		if loco == nil then
			return
		end
		local pose = poses[loco.Character]
		if pose then
			pose.Loco = loco
		end
		loco.Events:Connect(function(name: string)
			local target = poses[loco.Character]
			if target and name == "AirJump" then
				target.AirJumpAt = Workspace:GetServerTimeNow()
			end
		end)
	end
	movement.LocoChanged:Connect(onLocoChanged)
	onLocoChanged(movement.GetLocomotion())

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			task.spawn(track, instance)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			untrack(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") then
			task.spawn(track, instance)
		end
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local now = Workspace:GetServerTimeNow()
		for character, pose in poses do
			if not character.Parent or not pose.Root.Parent or not pose.Joint.Parent then
				untrack(character)
			else
				step(pose, dt, now)
			end
		end
	end)
end

return PoseController
