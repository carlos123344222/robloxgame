--!strict
-- A short, committed burst. On the ground it keeps gravity/slopes; in the air it hovers for the
-- duration. It decelerates into a fast exit speed so a dash flows into a sprint instead of stopping.

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local DashState = {}

function DashState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local cfg = loco.Cfg
	local sd = loco.StateData
	local direction = data.Direction
	sd.Direction = if typeof(direction) == "Vector3" then direction else loco:GetFacingDirection()
	sd.Airborne = data.Airborne == true

	local flowMult = loco:SpeedMultiplier()
	sd.StartSpeed = cfg.DashSpeed * flowMult
	sd.ExitSpeed = math.max(cfg.RunSpeed, cfg.SprintSpeed * cfg.DashExitSpeedMult) * flowMult

	loco:AddFlow(0.1)
	loco:Fire("Dash", { Direction = sd.Direction, Airborne = sd.Airborne })
end

function DashState.Exit(loco: Loco, _nextState: string)
	loco:SetDriver(nil)
end

local function finish(loco: Loco, direction: Vector3, exitSpeed: number)
	if loco.Grounded then
		loco.MoveDir = direction
		loco:ChangeState("Ground", { Speed = exitSpeed })
	else
		local vy = math.min(loco.Velocity.Y, 0)
		loco.Root.AssemblyLinearVelocity = Vector3.new(direction.X * exitSpeed, vy, direction.Z * exitSpeed)
		loco:ChangeState("Air", {})
	end
end

function DashState.Update(loco: Loco, _dt: number, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local direction: Vector3 = sd.Direction
	local progress = loco.StateTime / cfg.DashDuration
	local speed = MathUtil.lerp(sd.StartSpeed, sd.ExitSpeed, MathUtil.easeOutQuad(math.min(progress, 1)))

	-- Dash-cancel into a jump or slide keeps the momentum.
	if loco:WantsJump() and (loco.Grounded or loco.AirJumps > 0) then
		loco:AddFlow(0.15)
		if loco.Grounded then
			local hv = direction * math.max(speed, sd.ExitSpeed)
			loco:Leap(Vector3.new(hv.X, cfg.JumpVelocity, hv.Z), "DashJump", true)
		else
			loco.AirJumps -= 1
			loco.JumpBufferedAt = -math.huge
			local hv = direction * math.max(speed, sd.ExitSpeed)
			loco.Root.AssemblyLinearVelocity = Vector3.new(hv.X, cfg.AirJumpVelocity, hv.Z)
			loco:Fire("AirJump", nil)
			loco:ChangeState("Air", { Jumped = true })
		end
		return
	end
	if loco.Grounded and loco.HSpeed >= cfg.SlideMinSpeed then
		local slideWanted = intent.SlidePressed or loco.Time - loco.SlideBufferedAt <= cfg.SlideBuffer
		if slideWanted and loco.Time >= loco.SlideReadyAt then
			loco.SlideBufferedAt = -math.huge
			loco:ChangeState("Slide", { Direction = direction, Speed = math.max(speed, sd.ExitSpeed) })
			return
		end
	end

	-- Ran into something.
	if loco.StateTime > 0.06 and loco.HSpeed < speed * 0.3 then
		finish(loco, direction, math.min(loco.HSpeed + 6, sd.ExitSpeed))
		return
	end
	if progress >= 1 then
		finish(loco, direction, sd.ExitSpeed)
		return
	end

	if sd.Airborne then
		loco:SetDriver(Vector3.new(direction.X * speed, 0, direction.Z * speed), false)
	else
		loco:SetDriver(direction * speed, true)
	end
	loco:FaceDirection(direction, 30)
	loco:ApplyHumanoid(math.min(speed, cfg.SprintSpeed), direction)
end

return DashState
