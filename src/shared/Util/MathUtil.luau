--!strict
-- Small numeric helpers used everywhere in the movement code.
-- Yaw convention matches Roblox: CFrame.Angles(0, yaw, 0), positive = turning left seen from above.

local MathUtil = {}

local TAU = math.pi * 2
local EPS = 1e-5

function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathUtil.saturate(x: number): number
	return math.clamp(x, 0, 1)
end

function MathUtil.remap(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	if inMax == inMin then
		return outMin
	end
	local t = math.clamp((x - inMin) / (inMax - inMin), 0, 1)
	return outMin + (outMax - outMin) * t
end

-- Move `current` toward `target` by at most `maxDelta`.
function MathUtil.approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function MathUtil.approachVector(current: Vector3, target: Vector3, maxDelta: number): Vector3
	local delta = target - current
	local mag = delta.Magnitude
	if mag <= maxDelta or mag < EPS then
		return target
	end
	return current + delta * (maxDelta / mag)
end

-- Frame-rate independent exponential smoothing. `lambda` is 1/seconds: higher = snappier.
function MathUtil.damp(current: number, target: number, lambda: number, dt: number): number
	return target + (current - target) * math.exp(-lambda * dt)
end

function MathUtil.dampVector(current: Vector3, target: Vector3, lambda: number, dt: number): Vector3
	return target + (current - target) * math.exp(-lambda * dt)
end

function MathUtil.wrapAngle(a: number): number
	return (a + math.pi) % TAU - math.pi
end

function MathUtil.approachAngle(current: number, target: number, maxDelta: number): number
	local d = MathUtil.wrapAngle(target - current)
	if math.abs(d) <= maxDelta then
		return target
	end
	return current + math.sign(d) * maxDelta
end

function MathUtil.dampAngle(current: number, target: number, lambda: number, dt: number): number
	local d = MathUtil.wrapAngle(target - current)
	return current + d * (1 - math.exp(-lambda * dt))
end

function MathUtil.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Horizontal unit vector, or Vector3.zero when there is no horizontal component.
function MathUtil.flatUnit(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	local m = f.Magnitude
	if m < EPS then
		return Vector3.zero
	end
	return f / m
end

function MathUtil.yawFromDirection(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

function MathUtil.directionFromYaw(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- Signed angle from `a` to `b` around +Y. Positive = counter-clockwise from above (a left turn).
function MathUtil.signedAngleY(a: Vector3, b: Vector3): number
	return MathUtil.wrapAngle(math.atan2(-b.X, -b.Z) - math.atan2(-a.X, -a.Z))
end

function MathUtil.rotateY(v: Vector3, angle: number): Vector3
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end

-- Turn horizontal direction `from` toward `to` by at most `maxAngle` radians.
function MathUtil.rotateToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = MathUtil.signedAngleY(from, to)
	if math.abs(angle) <= maxAngle then
		return to
	end
	return MathUtil.rotateY(from, math.sign(angle) * maxAngle)
end

function MathUtil.easeOutQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

function MathUtil.easeOutCubic(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

function MathUtil.easeInOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

return MathUtil
