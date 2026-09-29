--!strict
-- Grounded locomotion. The Humanoid still does the walking (slopes, stairs, platforms); we shape
-- *how* it accelerates: speed ramps, arcing turns at speed, and a skid when you reverse.

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local GroundState = {}

function GroundState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	loco.AirJumps = loco.Cfg.AirJumps
	loco.AirDashesUsed = 0
	loco.LastWallInstance = nil

	local speed = data.Speed
	loco.Speed = if typeof(speed) == "number" then speed else loco.HSpeed
	if loco.HSpeed > 1 then
		loco.MoveDir = loco.HDir
	end
	loco:SetDriver(nil)
end

function GroundState.Exit(_loco: Loco, _nextState: string) end

function GroundState.Update(loco: Loco, dt: number, intent: Intent)
	local cfg = loco.Cfg

	-- Walked off an edge (with a little tolerance for bumps and stairs).
	if not loco.Grounded and loco.Time - loco.GroundedAt > cfg.GroundLeaveDelay then
		loco:ChangeState("Air", { Coyote = true })
		return
	end

	local recovering = loco.Time < loco.LandPenaltyUntil

	if not recovering then
		if loco:WantsJump() then
			local direction = if loco.HSpeed > 3 then loco.HDir else loco:GetFacingDirection()
			if not loco:TryMantle(direction, cfg.MantleGroundMinHeight) then
				loco:Jump("Ground")
			end
			return
		end

		local slideWanted = intent.SlidePressed or loco.Time - loco.SlideBufferedAt <= cfg.SlideBuffer
		if slideWanted and loco.Time >= loco.SlideReadyAt and loco.HSpeed >= cfg.SlideMinSpeed then
			loco.SlideBufferedAt = -math.huge
			loco:ChangeState("Slide", { Direction = loco.HDir, Speed = loco.HSpeed * cfg.SlideEntryMult })
			return
		end

		if loco:WantsDash() and loco:TryDash(intent) then
			return
		end
	end

	local move = intent.Move
	local magnitude = math.min(move.Magnitude, 1)
	local hasInput = magnitude > 0.08
	local inputDir = if hasInput then MathUtil.flatUnit(move) else Vector3.zero

	local maxSpeed = (if intent.Sprint then cfg.SprintSpeed else cfg.RunSpeed) * loco:SpeedMultiplier()
	local target = 0.0
	if hasInput then
		target = math.max(maxSpeed * magnitude, cfg.WalkSpeed * 0.6)
	end
	if recovering then
		target *= loco.LandPenaltyMult
	end

	-- Heading: snap at low speed, arc at speed, skid when the input reverses. A skid, once started,
	-- runs until we are slow enough to snap around (otherwise it would turn into a wide U-turn).
	local skidding = loco.StateData.Skidding == true
	local pivoting = false
	if hasInput then
		if loco.Speed < cfg.SnapTurnSpeed or loco.MoveDir.Magnitude < 0.1 then
			loco.MoveDir = inputDir
		else
			local angle = math.abs(MathUtil.signedAngleY(loco.MoveDir, inputDir))
			if angle > cfg.PivotAngle and (skidding or loco.Speed > cfg.PivotMinSpeed) then
				pivoting = true
				if not skidding then
					loco:Fire("Skid", loco.Speed)
				end
			else
				local t = MathUtil.saturate((loco.Speed - cfg.RunSpeed) / (cfg.SprintSpeed - cfg.RunSpeed))
				local rate = MathUtil.lerp(cfg.TurnRateRun, cfg.TurnRateSprint, t)
				loco.MoveDir = MathUtil.rotateToward(loco.MoveDir, inputDir, rate * dt)
			end
		end
	end
	loco.StateData.Skidding = if pivoting then true else nil
	if pivoting then
		target = 0
	end

	local rate: number
	if target > loco.Speed then
		rate = if loco.Speed < cfg.RunSpeed then cfg.GroundAccel else cfg.SprintAccel
	elseif pivoting then
		rate = cfg.BrakeDecel
	elseif hasInput then
		rate = cfg.GroundDecel
	else
		rate = cfg.StopDecel
	end
	loco.Speed = MathUtil.approach(loco.Speed, target, rate * dt)

	-- Don't bank speed while pressed against a wall.
	if loco.Speed - loco.HSpeed > 9 then
		loco.Speed = MathUtil.approach(loco.Speed, loco.HSpeed + 6, 90 * dt)
	end

	if loco.Speed > 0.35 then
		loco:ApplyHumanoid(loco.Speed, loco.MoveDir)
		if loco.Speed > 1 then
			loco:FaceDirection(loco.MoveDir)
		end
	else
		loco:ApplyHumanoid(loco.Speed, Vector3.zero)
	end
end

return GroundState
