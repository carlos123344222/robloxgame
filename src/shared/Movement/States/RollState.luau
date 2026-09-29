--!strict
-- Landing roll: pressing slide just before a hard landing turns the impact into forward speed
-- instead of a stumble.

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local RollState = {}

function RollState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local cfg = loco.Cfg
	local sd = loco.StateData
	local impact = data.Impact
	local impactSpeed = if typeof(impact) == "number" then impact else 0

	sd.Direction = if loco.HSpeed > 3 then loco.HDir else loco:GetFacingDirection()
	sd.StartSpeed = math.min(
		math.max(loco.HSpeed, cfg.RollMinSpeed) + impactSpeed * cfg.RollImpactSpeedBonus,
		cfg.SprintSpeed * 1.25
	)
	loco:AddFlow(0.15)
	loco:Fire("Roll", impactSpeed)
end

function RollState.Exit(loco: Loco, _nextState: string)
	loco:SetDriver(nil)
end

function RollState.Update(loco: Loco, dt: number, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local progress = math.min(loco.StateTime / cfg.RollDuration, 1)
	local speed = MathUtil.lerp(sd.StartSpeed, sd.StartSpeed * cfg.RollExitMult, progress)
	local direction: Vector3 = sd.Direction

	if loco:WantsJump() then
		local hv = direction * speed
		loco:Leap(Vector3.new(hv.X, cfg.JumpVelocity * 0.9, hv.Z), "RollJump", true)
		return
	end
	if loco:WantsDash() and loco:TryDash(intent) then
		return
	end

	if not loco.Grounded and loco.Time - loco.GroundedAt > 0.15 then
		local hv = direction * speed
		loco.Root.AssemblyLinearVelocity = Vector3.new(hv.X, loco.Velocity.Y, hv.Z)
		loco:ChangeState("Air", { Coyote = true })
		return
	end
	if progress >= 1 then
		loco.MoveDir = direction
		loco:ChangeState("Ground", { Speed = speed })
		return
	end

	local input = MathUtil.flatUnit(intent.Move)
	if input.Magnitude > 0.1 then
		sd.Direction = MathUtil.rotateToward(direction, input, 2.2 * dt)
		direction = sd.Direction
	end

	loco:SetDriver(direction * speed, true)
	loco:FaceDirection(direction, 16)
	loco:ApplyHumanoid(cfg.WalkSpeed, Vector3.zero)
end

return RollState
