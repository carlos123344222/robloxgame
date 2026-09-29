--!strict
-- Momentum slide: starts from a sprint, gains speed downhill, bleeds it uphill / to friction, can be
-- steered a little, and cancels into a boosted slide-jump.

local Workspace = game:GetService("Workspace")

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local SlideState = {}

function SlideState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local cfg = loco.Cfg
	local sd = loco.StateData
	local direction = data.Direction
	local dir = if typeof(direction) == "Vector3" then MathUtil.flatUnit(direction) else Vector3.zero
	if dir.Magnitude < 0.1 then
		dir = loco:GetFacingDirection()
	end
	local speed = data.Speed
	sd.Direction = dir
	sd.Speed = math.clamp(if typeof(speed) == "number" then speed else loco.HSpeed, cfg.SlideEndSpeed, cfg.SlideMaxSpeed)
	sd.AirTime = 0
	loco:AddFlow(0.05)
	loco:Fire("SlideStart", sd.Speed)
end

function SlideState.Exit(loco: Loco, _nextState: string)
	loco:SetDriver(nil)
	loco.SlideReadyAt = loco.Time + loco.Cfg.SlideCooldown
	loco:Fire("SlideEnd", nil)
end

local function endSlide(loco: Loco, speed: number)
	loco.MoveDir = loco.StateData.Direction
	loco:ChangeState("Ground", { Speed = speed })
end

function SlideState.Update(loco: Loco, dt: number, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local direction: Vector3 = sd.Direction
	local speed: number = sd.Speed

	if loco:WantsJump() then
		local hv = direction * math.min(speed * cfg.SlideJumpMult, cfg.SlideMaxSpeed)
		loco:AddFlow(0.2)
		loco:Leap(Vector3.new(hv.X, cfg.SlideJumpVelocity, hv.Z), "SlideJump", true)
		return
	end
	if loco:WantsDash() and loco:TryDash(intent) then
		return
	end

	if loco.Grounded then
		sd.AirTime = 0
	else
		sd.AirTime += dt
		if sd.AirTime > 0.12 then
			local hv = direction * speed
			loco.Root.AssemblyLinearVelocity = Vector3.new(hv.X, loco.Velocity.Y, hv.Z)
			loco:ChangeState("Air", { Coyote = true })
			return
		end
	end

	-- Gravity along the surface: free speed downhill, a tax uphill.
	local normal = loco.GroundNormal
	local downhill = (normal * normal.Y - Vector3.yAxis) * Workspace.Gravity
	speed += downhill:Dot(direction) * cfg.SlideSlopeFactor * dt
	speed -= cfg.SlideFriction * dt
	speed = math.clamp(speed, 0, cfg.SlideMaxSpeed)
	sd.Speed = speed

	local released = not intent.SlideHeld and loco.StateTime > cfg.SlideMinTime
	local slowed = speed < cfg.SlideEndSpeed
	local blocked = loco.StateTime > 0.1 and loco.HSpeed < speed * 0.35
	if released or slowed or blocked or loco.StateTime > cfg.SlideMaxTime then
		endSlide(loco, if blocked then loco.HSpeed else math.max(speed, cfg.WalkSpeed))
		return
	end

	local input = MathUtil.flatUnit(intent.Move)
	if input.Magnitude > 0.1 then
		sd.Direction = MathUtil.rotateToward(direction, input, cfg.SlideSteerRate * dt)
		direction = sd.Direction
	end

	loco:SetDriver(direction * speed, true)
	loco:FaceDirection(direction, 14)
	loco:ApplyHumanoid(cfg.WalkSpeed, Vector3.zero)
end

return SlideState
