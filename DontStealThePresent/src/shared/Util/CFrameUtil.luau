-- CFrame.lookAt seguro: si la dirección es casi vertical usa otro vector "arriba" para no generar NaN.

local CFrameUtil = {}

function CFrameUtil.LookAt(from: Vector3, to: Vector3): CFrame
	local direction = to - from
	if direction.Magnitude < 1e-6 then
		return CFrame.new(from)
	end
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	return CFrame.lookAt(from, to, up)
end

return CFrameUtil
