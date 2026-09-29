--!strict
-- Airborne: snappy gravity, variable jump height, coyote time, double jump, wall contact,
-- automatic ledge grabs, and momentum-preserving steering.

local Workspace = game:GetService("Workspace")

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local AirState = {}

function AirState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local sd = loco.StateData
	sd.Jumped = data.Jumped == true
	sd.Coyote = data.Coyote == true
	sd.CanCut = sd.Jumped and data.AllowCut ~= false
	sd.FallSpeed = 0
	sd.WallNormal = nil
	sd.WallInstance = nil
	sd.WallSeenAt = -math.huge
	loco:SetDriver(nil)
end

function AirState.Exit(_loco: Loco, _nextState: string) end

local function land(loco: Loco, intent: Intent, fallSpeed: number)
	local cfg = loco.Cfg
	loco.LandedAt = loco.Time
	loco:Fire("Land", fallSpeed)

	local rollRequested = loco.Time - loco.SlideBufferedAt <= cfg.RollWindow or intent.SlideHeld
	if rollRequested and fallSpeed >= cfg.RollMinImpact then
		loco.SlideBufferedAt = -math.huge
		loco:ChangeState("Roll", { Impact = fallSpeed })
		return
	end

	local speed = loco.HSpeed
	if fallSpeed >= cfg.HardLandImpact then
		local t = MathUtil.saturate((fallSpeed - cfg.HardLandImpact) / (cfg.HardLandMaxImpact - cfg.HardLandImpact))
		loco.LandPenaltyUntil = loco.Time + MathUtil.lerp(cfg.HardLandStunMin, cfg.HardLandStunMax, t)
		loco.LandPenaltyMult = cfg.HardLandSpeedMult
		speed *= cfg.HardLandSpeedMult
		loco:Fire("HardLand", fallSpeed)
	end
	loco:ChangeState("Ground", { Speed = speed })
end

local function airJump(loco: Loco, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local vel = loco.Velocity
	local hv = Vector3.new(vel.X, 0, vel.Z)

	-- The double jump doubles as a mid-air redirect toward the stick.
	local dir = MathUtil.flatUnit(intent.Move)
	if dir.Magnitude > 0.1 then
		hv = dir * math.max(hv.Magnitude, cfg.RunSpeed * 0.85)
	end

	loco.AirJumps -= 1
	loco.JumpBufferedAt = -math.huge
	loco:AddFlow(0.05)
	loco:Fire("AirJump", nil)
	local newVelocity = Vector3.new(hv.X, cfg.AirJumpVelocity, hv.Z)
	loco.Root.AssemblyLinearVelocity = newVelocity
	loco.Velocity = newVelocity
	sd.CanCut = true
	sd.FallSpeed = 0
end

-- Closest wall the character is touching / about to touch, from side and front probes.
local function probeWalls(loco: Loco, forward: Vector3): (RaycastResult?, RaycastResult?, RaycastResult?)
	local cfg = loco.Cfg
	local position = loco.Root.Position
	local right, left = loco.Sensors:ProbeSides(position, forward, cfg.WallRunCheckDist)
	local front = loco.Sensors:ProbeWall(position, forward, cfg.WallJumpReach)
	return right, left, front
end

local function closest(a: RaycastResult?, b: RaycastResult?, c: RaycastResult?): RaycastResult?
	local best: RaycastResult? = nil
	for _, hit in { a, b, c } do
		if hit and (best == nil or hit.Distance < best.Distance) then
			best = hit
		end
	end
	return best
end

local function tryWallRun(loco: Loco, intent: Intent, right: RaycastResult?, left: RaycastResult?): boolean
	local cfg = loco.Cfg
	if loco.Time < loco.WallRunReadyAt or loco.HSpeed < cfg.WallRunMinSpeed then
		return false
	end
	if loco.FloorDistance < cfg.WallRunMinHeight then
		return false
	end
	local inputDir = MathUtil.flatUnit(intent.Move)
	if inputDir.Magnitude < 0.3 then
		return false
	end

	local hit = right
	local side = 1
	if right == nil or (left ~= nil and left.Distance < right.Distance) then
		hit = left
		side = -1
	end
	if hit == nil then
		return false
	end
	if
		hit.Instance == loco.LastWallInstance
		and loco.Time - loco.LastWallEndAt < cfg.WallRunSameWallDelay
	then
		return false
	end

	local normal = MathUtil.flatUnit(hit.Normal)
	if normal.Magnitude < 0.5 then
		return false
	end
	local tangent = normal:Cross(Vector3.yAxis)
	if tangent:Dot(loco.HDir) < 0 then
		tangent = -tangent
	end
	if tangent:Dot(loco.HDir) < cfg.WallRunMinAlign or tangent:Dot(inputDir) < 0.2 then
		return false
	end

	loco:ChangeState("WallRun", {
		Normal = normal,
		Direction = tangent,
		Instance = hit.Instance,
		Side = side,
	})
	return true
end

function AirState.Update(loco: Loco, dt: number, intent: Intent)
	local cfg = loco.Cfg
	local sd = loco.StateData
	local root = loco.Root
	local vy = loco.Velocity.Y

	if loco:WantsDash() and loco:TryDash(intent) then
		return
	end

	if loco.Grounded and vy <= 3 then
		land(loco, intent, sd.FallSpeed)
		return
	end

	if vy < 0 then
		sd.FallSpeed = math.max(sd.FallSpeed, -vy)
	else
		sd.FallSpeed = 0
	end

	local inputDir = MathUtil.flatUnit(intent.Move)
	local forward = if loco.HSpeed > 3 then loco.HDir elseif inputDir.Magnitude > 0.1 then inputDir else loco:GetFacingDirection()

	-- Grab ledges we are moving into.
	if cfg.MantleEnabled and vy < cfg.MantleMaxRise and (loco.HSpeed > 5 or inputDir.Magnitude > 0.2) then
		if loco:TryMantle(if inputDir.Magnitude > 0.2 then inputDir else forward, cfg.MantleMinHeight) then
			return
		end
	end

	-- Walls: run along them, slide down them, kick off them.
	local wallHit: RaycastResult? = nil
	if cfg.WallRunEnabled then
		local right, left, front = probeWalls(loco, forward)
		if tryWallRun(loco, intent, right, left) then
			return
		end
		wallHit = closest(right, left, front)
		if wallHit then
			sd.WallNormal = MathUtil.flatUnit(wallHit.Normal)
			sd.WallInstance = wallHit.Instance
			sd.WallSeenAt = loco.Time
			-- Holding into a wall while falling scrapes down it slowly.
			if inputDir.Magnitude > 0.2 and inputDir:Dot(-sd.WallNormal) > 0.3 and vy < -cfg.WallSlideSpeed then
				vy = MathUtil.approach(vy, -cfg.WallSlideSpeed, 140 * dt)
			end
		end
	end

	if loco:WantsJump() then
		if sd.Coyote and not sd.Jumped and loco.Time - loco.GroundedAt <= cfg.CoyoteTime then
			loco:Jump("Coyote")
			return
		end

		local wallNormal = sd.WallNormal :: Vector3?
		local wallInstance = sd.WallInstance :: BasePart?
		if
			wallNormal
			and loco.Time - sd.WallSeenAt <= cfg.WallJumpGrace
			and (wallInstance ~= loco.LastWallInstance or loco.Time - loco.LastWallJumpAt > cfg.WallJumpSameWallDelay)
		then
			loco:WallJump(wallNormal, wallInstance, intent)
			return
		end

		-- Just above the floor a buffered press should become a ground jump on touchdown instead.
		local nearGround = vy < 0 and loco.FloorDistance < math.max(2, -vy * cfg.JumpBuffer)
		if loco.AirJumps > 0 and not nearGround then
			airJump(loco, intent)
			vy = loco.Velocity.Y
		end
	end

	-- Releasing jump early trims the ascent.
	if sd.CanCut then
		if vy <= 0 then
			sd.CanCut = false
		elseif not intent.JumpHeld and vy > cfg.JumpCutMinVy then
			vy *= cfg.JumpCutMultiplier
			sd.CanCut = false
		end
	end

	-- Gravity shaping: floaty apex, heavy fall.
	local gravityMult = 1.0
	if math.abs(vy) < cfg.ApexBand then
		gravityMult = cfg.ApexGravityMult
	elseif vy < 0 then
		gravityMult = cfg.FallGravityMult
	end
	vy -= (gravityMult - 1) * Workspace.Gravity * dt
	vy = math.max(vy, -cfg.TerminalVelocity)

	-- Horizontal steering that keeps speed while turning.
	local vel = loco.Velocity
	local hv = Vector3.new(vel.X, 0, vel.Z)
	local speed = hv.Magnitude
	local magnitude = math.min(intent.Move.Magnitude, 1)
	if magnitude > 0.08 then
		local base = (if intent.Sprint then cfg.SprintSpeed else cfg.RunSpeed) * loco:SpeedMultiplier()
		local targetSpeed = math.max(speed, base * magnitude)
		local currentDir = if speed > 0.5 then hv / speed else inputDir
		local newDir = MathUtil.rotateToward(currentDir, inputDir, cfg.AirTurnRate * dt)
		hv = newDir * MathUtil.approach(speed, targetSpeed, cfg.AirAccel * dt)
	elseif speed > 0.01 then
		hv = (hv / speed) * MathUtil.approach(speed, 0, cfg.AirDrag * dt)
	end

	local newVelocity = Vector3.new(hv.X, vy, hv.Z)
	root.AssemblyLinearVelocity = newVelocity
	loco.Velocity = newVelocity

	if hv.Magnitude > 3 then
		loco:FaceDirection(hv)
	end
	loco:ApplyHumanoid(math.max(hv.Magnitude, cfg.RunSpeed), Vector3.zero)
end

return AirState
