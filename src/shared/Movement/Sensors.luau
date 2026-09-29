--!strict
-- World queries for the locomotion states: ground, walls and climbable ledges.
-- Rays ignore the character itself, every other character, non-collidable parts and water.

local Workspace = game:GetService("Workspace")

local Shared = script.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Ledge = Types.Ledge
type SensorsApi = Types.SensorsApi

type SensorsImpl = SensorsApi & {
	Character: Model,
	Cfg: Types.MovementConfig,
	RootToFeet: number,
	Params: RaycastParams,
	BaseFilter: { Instance },
}

local Sensors = {}
Sensors.__index = Sensors

local MAX_CHARACTER_SKIPS = 4
local LEDGE_WALL_PROBE_HEIGHT = 2.2 -- above the feet; must be below MantleMinHeight

function Sensors.new(character: Model, cfg: Types.MovementConfig, rootToFeet: number): SensorsApi
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local base: { Instance } = { character }
	params.FilterDescendantsInstances = base

	local self = setmetatable({
		Character = character,
		Cfg = cfg,
		RootToFeet = rootToFeet,
		Params = params,
		BaseFilter = base,
	}, Sensors)
	return (self :: any) :: SensorsApi
end

-- Raycast that steps over other characters (players, NPCs) instead of treating them as walls.
function Sensors.Cast(self: SensorsImpl, origin: Vector3, direction: Vector3): RaycastResult?
	local params = self.Params
	local extended: { Instance }? = nil
	local found: RaycastResult? = nil

	for _ = 1, MAX_CHARACTER_SKIPS do
		local result = Workspace:Raycast(origin, direction, params)
		if not result then
			break
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model ~= self.Character and model:FindFirstChildOfClass("Humanoid") then
			if extended == nil then
				extended = table.clone(self.BaseFilter)
			end
			table.insert(extended :: { Instance }, model)
			params.FilterDescendantsInstances = extended :: { Instance }
		else
			found = result
			break
		end
	end

	if extended then
		params.FilterDescendantsInstances = self.BaseFilter
	end
	return found
end

function Sensors.ProbeGround(self: SensorsImpl, rootPosition: Vector3, extraDistance: number): RaycastResult?
	return self:Cast(rootPosition, Vector3.new(0, -(self.RootToFeet + extraDistance), 0))
end

local function acceptWall(result: RaycastResult?): RaycastResult?
	if not result then
		return nil
	end
	if math.abs(result.Normal.Y) > 0.3 then
		return nil
	end
	if result.Instance:GetAttribute("NoWallRun") == true then
		return nil
	end
	return result
end

function Sensors.ProbeWall(
	self: SensorsImpl,
	rootPosition: Vector3,
	direction: Vector3,
	distance: number
): RaycastResult?
	local dir = MathUtil.flatUnit(direction)
	if dir.Magnitude < 0.5 then
		return nil
	end
	return acceptWall(self:Cast(rootPosition, dir * distance))
end

-- Casts to the character's right and left relative to `forward`. Returns (right, left).
function Sensors.ProbeSides(
	self: SensorsImpl,
	rootPosition: Vector3,
	forward: Vector3,
	distance: number
): (RaycastResult?, RaycastResult?)
	local fwd = MathUtil.flatUnit(forward)
	if fwd.Magnitude < 0.5 then
		return nil, nil
	end
	local right = fwd:Cross(Vector3.yAxis)
	return acceptWall(self:Cast(rootPosition, right * distance)), acceptWall(self:Cast(rootPosition, -right * distance))
end

-- Looks for a ledge in `direction` that the character can climb onto.
-- Requires: a wall in front, the wall top between min/max height, headroom above it, and room to stand.
function Sensors.FindLedge(
	self: SensorsImpl,
	rootPosition: Vector3,
	direction: Vector3,
	minHeightOverride: number?
): Ledge?
	local cfg = self.Cfg
	local dir = MathUtil.flatUnit(direction)
	if dir.Magnitude < 0.5 then
		return nil
	end

	local feetY = rootPosition.Y - self.RootToFeet
	local minHeight = minHeightOverride or cfg.MantleMinHeight
	local maxHeight = cfg.MantleMaxHeight

	local wall = self:Cast(Vector3.new(rootPosition.X, feetY + LEDGE_WALL_PROBE_HEIGHT, rootPosition.Z), dir * cfg.MantleReach)
	if not wall or math.abs(wall.Normal.Y) > 0.35 then
		return nil
	end
	local normal = MathUtil.flatUnit(wall.Normal)
	if normal.Magnitude < 0.5 or dir:Dot(-normal) < 0.5 then
		return nil
	end
	local wallPart = wall.Instance
	if wallPart:GetAttribute("NoMantle") == true then
		return nil
	end

	-- Anything at the maximum height means the obstacle is too tall to climb.
	local clearY = feetY + maxHeight + 0.4
	if self:Cast(Vector3.new(rootPosition.X, clearY, rootPosition.Z), dir * (cfg.MantleReach + 0.3)) then
		return nil
	end

	-- Drop a ray from above onto the top surface, just inside the wall face.
	local inside = wall.Position - normal * 0.3
	local dropLength = clearY - (feetY + minHeight - 0.6)
	local top = self:Cast(Vector3.new(inside.X, clearY, inside.Z), Vector3.new(0, -dropLength, 0))
	if not top or top.Normal.Y < 0.7 then
		return nil
	end
	local height = top.Position.Y - feetY
	if height < minHeight or height > maxHeight then
		return nil
	end

	-- Headroom above the ledge, room at torso height, and solid footing to stand on.
	local topPos = top.Position
	if self:Cast(topPos + Vector3.yAxis * 0.15, Vector3.new(0, cfg.CharacterHeight, 0)) then
		return nil
	end
	if self:Cast(topPos + Vector3.yAxis * (cfg.CharacterHeight * 0.5), -normal * cfg.MantleDepth) then
		return nil
	end
	local footing = topPos - normal * 1.1
	local floorCheck = self:Cast(Vector3.new(footing.X, topPos.Y + 1.5, footing.Z), Vector3.new(0, -2.5, 0))
	if not floorCheck or floorCheck.Normal.Y < 0.6 then
		return nil
	end

	local stand = topPos - normal * 0.9 + Vector3.yAxis * (self.RootToFeet + 0.05)
	return {
		Top = topPos,
		Normal = normal,
		Height = height,
		StandPosition = stand,
		Instance = top.Instance,
	}
end

return Sensors
