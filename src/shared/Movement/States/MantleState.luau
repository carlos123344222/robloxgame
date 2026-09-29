--!strict
-- Climb / vault onto a ledge. The character rises along the wall, and as its feet clear the edge the
-- upward motion blends into forward motion, so it reads as one arc instead of "up, stop, forward".

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent
type Ledge = Types.Ledge

local MantleState = {}

local MAX_DURATION = 1.3

function MantleState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local cfg = loco.Cfg
	local sd = loco.StateData
	sd.Ledge = data.Ledge
	sd.EntrySpeed = loco.HSpeed
	sd.Speed = math.max(cfg.MantleSpeed, loco.HSpeed * 0.9) * loco:SpeedMultiplier()

	local ledge = data.Ledge :: Ledge
	loco:AddFlow(0.15)
	loco:Fire("Mantle", ledge.Height)
end

function MantleState.Exit(loco: Loco, _nextState: string)
	loco:SetDriver(nil)
	loco.MantleReadyAt = loco.Time + loco.Cfg.MantleCooldown
end

local function finish(loco: Loco, ledge: Ledge)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local exitSpeed = math.max(cfg.MantleExitSpeed, sd.EntrySpeed * 0.7)
	local direction = -ledge.Normal
	loco.Root.AssemblyLinearVelocity = Vector3.new(direction.X * exitSpeed, 0, direction.Z * exitSpeed)
	if loco.Grounded then
		loco.MoveDir = direction
		loco:ChangeState("Ground", { Speed = exitSpeed })
	else
		loco:ChangeState("Air", {})
	end
end

function MantleState.Update(loco: Loco, dt: number, _intent: Intent)
	local sd = loco.StateData
	local ledge: Ledge = sd.Ledge
	local root = loco.Root
	local position = root.Position

	if loco.StateTime > MAX_DURATION then
		loco:ChangeState("Air", {})
		return
	end

	local feetY = position.Y - loco.RootToFeet
	local needUp = ledge.StandPosition.Y - position.Y
	local toStand = Vector3.new(ledge.StandPosition.X - position.X, 0, ledge.StandPosition.Z - position.Z)
	local distance = toStand.Magnitude

	if distance < 0.55 and needUp < 0.45 then
		finish(loco, ledge)
		return
	end

	-- 0 while the feet are still below the edge, 1 once they are clear of it.
	local clearance = feetY - (ledge.Top.Y - 0.2)
	local blend = MathUtil.saturate((clearance + 0.9) / 0.9)

	local speed: number = sd.Speed
	local forward = Vector3.zero
	if distance > 0.05 then
		local forwardSpeed = math.min(speed * blend, distance / math.max(dt, 0.008) * 0.9)
		forward = (toStand / distance) * forwardSpeed
	end
	local up = 0.0
	if needUp > 0.05 then
		up = math.clamp(needUp * 14, 3, speed * 1.15)
	end
	local hug = -ledge.Normal * (1 - blend) * 1.5

	loco:SetDriver(forward + Vector3.new(0, up, 0) + hug, false)
	loco:FaceDirection(-ledge.Normal, 25)
	loco:ApplyHumanoid(loco.Cfg.RunSpeed, Vector3.zero)
end

return MantleState
