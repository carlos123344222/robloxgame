--!strict
-- Turns "go there" into smooth steering.
--
-- Roblox pathfinding gives a polyline of waypoints; walking it point to point makes NPCs stop-and-go
-- around every corner. Instead the navigator:
--   * steers straight at the goal whenever the way is clear (no path request at all),
--   * otherwise follows the path with a look-ahead point, cutting corners that are provably walkable,
--   * slows for sharp turns, jumps where the path asks for it, avoids walls with whiskers,
--   * re-routes when the goal moves, the path is blocked, or the NPC stops making progress.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

local PathScheduler = require(script.Parent.PathScheduler)

type Loco = Types.Loco

export type NavResult = {
	Direction: Vector3, -- horizontal unit vector, zero when there is nothing to do
	Speed01: number, -- fraction of the NPC's top speed it should use
	Jump: boolean,
	Arrived: boolean,
	Failed: boolean,
}

export type Navigator = {
	SetGoal: (self: Navigator, position: Vector3?, arriveRadius: number?, slowOnArrive: boolean?) -> (),
	Step: (self: Navigator, dt: number, maxSpeed: number) -> NavResult,
	CanWalk: (self: Navigator, from: Vector3, to: Vector3) -> boolean,
	Destroy: (self: Navigator) -> (),
}

type Impl = Navigator & {
	Loco: Loco,
	Params: { [string]: any },
	Goal: Vector3?,
	ArriveRadius: number,
	SlowOnArrive: boolean,
	Time: number,
	Waypoints: { PathWaypoint },
	Index: number,
	PathGoal: Vector3?,
	Computing: boolean,
	Request: PathScheduler.Request?,
	BlockedConnection: RBXScriptConnection?,
	Blocked: boolean,
	ForceRepath: boolean,
	FailCount: number,
	LastRequestAt: number,
	Direct: boolean,
	LastDirectCheck: number,
	LookTarget: Vector3?,
	LookIndex: number,
	LastLookahead: number,
	LastProgressAt: number,
	LastProgressPos: Vector3,
	StuckTime: number,
	Destroyed: boolean,
	Result: NavResult,
}

local Navigator = {}
Navigator.__index = Navigator

local DIRECT_RANGE = 70
local DIRECT_CHECK_INTERVAL = 0.15
local REPATH_INTERVAL = 0.45
local LOOKAHEAD_INTERVAL = 0.1
local LOOKAHEAD_WAYPOINTS = 6
local REACH_BASE = 2.4
local PROGRESS_INTERVAL = 0.25

local CLEARANCE_RADIUS = 1.8
local KNEE_HEIGHT = 1.4

function Navigator.new(loco: Loco): Navigator
	local self = setmetatable({
		Loco = loco,
		Params = {
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		},
		Goal = nil,
		ArriveRadius = 2,
		SlowOnArrive = false,
		Time = 0,
		Waypoints = {},
		Index = 1,
		PathGoal = nil,
		Computing = false,
		Request = nil,
		BlockedConnection = nil,
		Blocked = false,
		ForceRepath = false,
		FailCount = 0,
		LastRequestAt = -math.huge,
		Direct = false,
		LastDirectCheck = -math.huge,
		LookTarget = nil,
		LookIndex = 0,
		LastLookahead = -math.huge,
		LastProgressAt = 0,
		LastProgressPos = loco.Root.Position,
		StuckTime = 0,
		Destroyed = false,
		Result = { Direction = Vector3.zero, Speed01 = 0, Jump = false, Arrived = false, Failed = false },
	}, Navigator)
	return (self :: any) :: Navigator
end

function Navigator.Destroy(self: Impl)
	self.Destroyed = true
	if self.Request then
		self.Request.Cancelled = true
	end
	if self.BlockedConnection then
		self.BlockedConnection:Disconnect()
		self.BlockedConnection = nil
	end
end

local function clearPath(self: Impl)
	self.Waypoints = {}
	self.Index = 1
	self.PathGoal = nil
	self.LookTarget = nil
	if self.BlockedConnection then
		self.BlockedConnection:Disconnect()
		self.BlockedConnection = nil
	end
end

function Navigator.SetGoal(self: Impl, position: Vector3?, arriveRadius: number?, slowOnArrive: boolean?)
	self.Goal = position
	self.ArriveRadius = arriveRadius or 2
	self.SlowOnArrive = slowOnArrive == true
	if position == nil then
		clearPath(self)
		self.StuckTime = 0
	end
end

-- True if walking straight from `from` to `to` (both at foot level) is clear and stays on solid,
-- gently sloped ground: no walls in a 3-wide corridor, no gaps, no big steps.
function Navigator.CanWalk(self: Impl, from: Vector3, to: Vector3): boolean
	local sensors = self.Loco.Sensors
	local delta = to - from
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = flat.Magnitude
	if distance < 0.5 then
		return true
	end
	if math.abs(delta.Y) > 0.6 * distance + 2 then
		return false
	end

	local direction = flat / distance
	local side = direction:Cross(Vector3.yAxis) * CLEARANCE_RADIUS
	local base = from + Vector3.new(0, KNEE_HEIGHT, 0)
	if sensors:Cast(base, flat) or sensors:Cast(base + side, flat) or sensors:Cast(base - side, flat) then
		return false
	end

	local steps = math.ceil(distance / 3)
	local lastY = from.Y
	for i = 1, steps do
		local point = from + flat * (i / steps)
		local floor = sensors:Cast(point + Vector3.new(0, 2.5, 0), Vector3.new(0, -6.5, 0))
		if floor == nil or floor.Normal.Y < 0.55 or math.abs(floor.Position.Y - lastY) > 2.2 then
			return false
		end
		lastY = floor.Position.Y
	end
	return true
end

local function ensurePath(self: Impl, feet: Vector3, goal: Vector3, distance: number)
	if self.Computing then
		return
	end
	local needs = #self.Waypoints == 0 or self.Blocked or self.ForceRepath
	if not needs and self.PathGoal then
		needs = (goal - self.PathGoal).Magnitude > math.max(6, distance * 0.15)
	end
	if not needs or self.Time - self.LastRequestAt < REPATH_INTERVAL then
		return
	end

	self.Computing = true
	self.LastRequestAt = self.Time
	self.Request = PathScheduler.Request(self.Params, feet, goal, function(path: Path?)
		self.Computing = false
		self.Request = nil
		if self.Destroyed then
			return
		end
		if path == nil then
			self.FailCount += 1
			return
		end
		clearPath(self)
		self.Waypoints = path:GetWaypoints()
		self.Index = 2 -- waypoint 1 is where we started
		self.PathGoal = goal
		self.Blocked = false
		self.ForceRepath = false
		self.FailCount = 0
		self.BlockedConnection = path.Blocked:Connect(function(blockedIndex: number)
			if blockedIndex >= self.Index then
				self.Blocked = true
			end
		end)
	end)
end

-- Point to steer at along the current path. Sets result.Jump when a jump waypoint is close.
local function pathTarget(self: Impl, feet: Vector3, speed: number, result: NavResult): Vector3?
	local waypoints = self.Waypoints
	local count = #waypoints
	if count == 0 then
		return nil
	end

	local reach = REACH_BASE + speed * 0.05
	while self.Index <= count do
		local position = waypoints[self.Index].Position
		local flat = Vector3.new(position.X - feet.X, 0, position.Z - feet.Z).Magnitude
		if flat < reach and math.abs(position.Y - feet.Y) < 4 then
			self.Index += 1
		else
			break
		end
	end
	if self.Index > count then
		return self.Goal
	end

	local index = self.Index
	local current = waypoints[index]
	if current.Action == Enum.PathWaypointAction.Jump then
		local flat = Vector3.new(current.Position.X - feet.X, 0, current.Position.Z - feet.Z).Magnitude
		if flat < math.clamp(speed * 0.2, 3.5, 8) then
			result.Jump = true
		end
		return current.Position
	end

	-- Cut corners: aim at the furthest upcoming waypoint we can walk to in a straight line.
	if self.LookIndex ~= index or self.Time - self.LastLookahead >= LOOKAHEAD_INTERVAL then
		self.LookIndex = index
		self.LastLookahead = self.Time
		local lookDistance = math.clamp(speed * 0.35 + 3, 4, 14)
		local best = index
		for j = index + 1, math.min(count, index + LOOKAHEAD_WAYPOINTS) do
			local candidate = waypoints[j]
			if candidate.Action == Enum.PathWaypointAction.Jump or waypoints[j - 1].Action == Enum.PathWaypointAction.Jump then
				break
			end
			if (candidate.Position - feet).Magnitude > lookDistance or not self:CanWalk(feet, candidate.Position) then
				break
			end
			best = j
		end
		self.LookTarget = waypoints[best].Position
	end
	return self.LookTarget or current.Position
end

-- Whisker avoidance: nudge the heading away from walls we are about to scrape.
local function avoid(self: Impl, feet: Vector3, direction: Vector3, speed: number): Vector3
	local sensors = self.Loco.Sensors
	local length = 3.5 + speed * 0.22
	local origin = feet + Vector3.new(0, KNEE_HEIGHT, 0)
	local left = MathUtil.rotateY(direction, 0.6)
	local right = MathUtil.rotateY(direction, -0.6)

	local push = Vector3.zero
	local front = sensors:Cast(origin, direction * length)
	if front then
		push += MathUtil.flatUnit(front.Normal) * (1 - front.Distance / length) * 1.3
	end
	local leftHit = sensors:Cast(origin, left * length * 0.8)
	if leftHit then
		push += MathUtil.flatUnit(leftHit.Normal) * (1 - leftHit.Distance / (length * 0.8))
	end
	local rightHit = sensors:Cast(origin, right * length * 0.8)
	if rightHit then
		push += MathUtil.flatUnit(rightHit.Normal) * (1 - rightHit.Distance / (length * 0.8))
	end

	if push.Magnitude < 0.01 then
		return direction
	end
	local adjusted = MathUtil.flatUnit(direction + push * 0.9)
	return if adjusted.Magnitude > 0.1 then adjusted else direction
end

function Navigator.Step(self: Impl, dt: number, maxSpeed: number): NavResult
	local result = self.Result
	result.Direction = Vector3.zero
	result.Speed01 = 0
	result.Jump = false
	result.Arrived = false
	result.Failed = false
	self.Time += dt

	local goal = self.Goal
	if goal == nil then
		return result
	end

	local loco = self.Loco
	local feet = loco.Root.Position - Vector3.new(0, loco.RootToFeet, 0)
	local toGoal = Vector3.new(goal.X - feet.X, 0, goal.Z - feet.Z)
	local distance = toGoal.Magnitude
	if distance <= self.ArriveRadius and math.abs(goal.Y - feet.Y) < 8 then
		result.Arrived = true
		self.StuckTime = 0
		return result
	end
	if self.FailCount >= 3 then
		result.Failed = true
		return result
	end

	if self.Time - self.LastDirectCheck > DIRECT_CHECK_INTERVAL then
		self.LastDirectCheck = self.Time
		self.Direct = distance < DIRECT_RANGE and self:CanWalk(feet, goal)
	end

	local target = goal
	if not self.Direct then
		ensurePath(self, feet, goal, distance)
		target = pathTarget(self, feet, maxSpeed, result) or goal
	end

	local direction = MathUtil.flatUnit(target - feet)
	if direction.Magnitude < 0.01 then
		direction = MathUtil.flatUnit(toGoal)
	end
	if not result.Jump and distance > 5 then
		direction = avoid(self, feet, direction, loco.HSpeed)
	end

	-- Ease off for sharp turns and when arriving somewhere we want to stop.
	local speed01 = 1.0
	if loco.HSpeed > 8 then
		local turn = math.abs(MathUtil.signedAngleY(loco.HDir, direction))
		speed01 = MathUtil.remap(turn, math.rad(70), math.rad(140), 1, 0.4)
	end
	if self.SlowOnArrive then
		speed01 = math.min(speed01, math.clamp(distance / math.max(maxSpeed * 0.55, 4), 0.25, 1))
	end

	-- No progress for a while: hop, then re-route, then give up.
	if self.Time - self.LastProgressAt >= PROGRESS_INTERVAL then
		local moved = Vector3.new(feet.X - self.LastProgressPos.X, 0, feet.Z - self.LastProgressPos.Z).Magnitude
		self.LastProgressAt = self.Time
		self.LastProgressPos = feet
		if moved < maxSpeed * PROGRESS_INTERVAL * 0.2 then
			self.StuckTime += PROGRESS_INTERVAL
		else
			self.StuckTime = 0
		end
	end
	if self.StuckTime > 0.5 then
		result.Jump = true
	end
	if self.StuckTime > 1.5 then
		self.ForceRepath = true
		self.Direct = false
		self.StuckTime = 0
		self.FailCount += 1
	end

	result.Direction = direction
	result.Speed01 = speed01
	return result
end

return Navigator
