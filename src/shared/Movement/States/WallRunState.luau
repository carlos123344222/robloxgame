--!strict
-- Running along a wall: a brief upward kick, then a slow slide down while speed is held.
-- Jump kicks off the wall, holding away from it lets go.

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local WallRunState = {}

function WallRunState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local cfg = loco.Cfg
	local sd = loco.StateData
	sd.Normal = data.Normal
	sd.Direction = data.Direction
	sd.Instance = data.Instance
	sd.Side = data.Side
	sd.Speed = math.max(cfg.WallRunSpeed, math.min(loco.HSpeed, cfg.SprintSpeed * 1.2))
	sd.Vy = math.max(loco.Velocity.Y, cfg.WallRunUpBoost)
	sd.AwayTime = 0

	-- Grabbing a wall refreshes your air options, which is what makes chains possible.
	loco.AirJumps = cfg.AirJumps
	loco.AirDashesUsed = math.max(0, loco.AirDashesUsed - 1)
	loco:AddFlow(0.1)
	loco:Fire("WallRunStart", { Side = sd.Side })
end

function WallRunState.Exit(loco: Loco, _nextState: string)
	local sd = loco.StateData
	loco:SetDriver(nil)
	loco.LastWallInstance = sd.Instance
	loco.LastWallEndAt = loco.Time
	loco.WallRunReadyAt = loco.Time + loco.Cfg.WallRunCooldown
	loco:Fire("WallRunEnd", nil)
end

local function fallOff(loco: Loco, pushAway: number)
	local sd = loco.StateData
	local normal: Vector3 = sd.Normal
	local direction: Vector3 = sd.Direction
	local hv = direction * sd.Speed + normal * pushAway
	loco.Root.AssemblyLinearVelocity = Vector3.new(hv.X, sd.Vy, hv.Z)
	loco:ChangeState("Air", {})
end

function WallRunState.Update(loco: Loco, dt: number, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local root = loco.Root

	if loco:WantsJump() then
		loco:WallJump(sd.Normal, sd.Instance, intent)
		return
	end
	if loco:WantsDash() and loco:TryDash(intent) then
		return
	end

	if loco.Grounded and sd.Vy <= 0 then
		loco:ChangeState("Ground", { Speed = sd.Speed })
		return
	end
	if loco.StateTime > cfg.WallRunDuration then
		fallOff(loco, 4)
		return
	end

	-- Re-probe the wall every step so curved or ending walls behave.
	local normal: Vector3 = sd.Normal
	local hit = loco.Sensors:ProbeWall(root.Position, -normal, cfg.WallRunCheckDist + 0.6)
	if not hit then
		fallOff(loco, 0)
		return
	end
	normal = MathUtil.flatUnit(hit.Normal)
	local tangent = normal:Cross(Vector3.yAxis)
	if tangent:Dot(sd.Direction) < 0 then
		tangent = -tangent
	end
	sd.Normal = normal
	sd.Direction = tangent
	sd.Instance = hit.Instance

	-- Holding away from the wall lets go.
	local input = MathUtil.flatUnit(intent.Move)
	if input.Magnitude > 0.3 and input:Dot(normal) > 0.6 then
		sd.AwayTime += dt
		if sd.AwayTime > 0.15 then
			fallOff(loco, 6)
			return
		end
	else
		sd.AwayTime = 0
	end

	sd.Speed = MathUtil.approach(sd.Speed, cfg.WallRunSpeed, 12 * dt)
	sd.Vy = MathUtil.approach(sd.Vy, -cfg.WallRunSinkSpeed, cfg.WallRunGravity * dt)

	local velocity = tangent * sd.Speed + Vector3.new(0, sd.Vy, 0) - normal * cfg.WallRunStickSpeed
	loco:SetDriver(velocity, false)
	loco:FaceDirection(tangent, 18)
	loco:ApplyHumanoid(cfg.RunSpeed, Vector3.zero)
end

return WallRunState
