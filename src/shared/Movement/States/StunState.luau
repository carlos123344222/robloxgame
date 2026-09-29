--!strict
-- Hit-stun / knockback. Control is locked and the body is left to physics for the duration.

local Shared = script.Parent.Parent.Parent
local MathUtil = require(Shared.Util.MathUtil)
local Types = require(Shared.Types)

type Loco = Types.Loco
type Intent = Types.Intent

local StunState = {}

function StunState.Enter(loco: Loco, _previous: string?, data: { [string]: any })
	local sd = loco.StateData
	local duration = data.Duration
	sd.Duration = if typeof(duration) == "number" then duration else 0.4

	loco:SetDriver(nil)
	loco.FaceEnabled = false
	local velocity = data.Velocity
	if typeof(velocity) == "Vector3" then
		loco.Root.AssemblyLinearVelocity = velocity
		loco.Velocity = velocity
	end
	loco:Fire("Stun", sd.Duration)
end

function StunState.Exit(loco: Loco, _nextState: string)
	loco.FaceEnabled = true
	local look = MathUtil.flatUnit(loco.Root.CFrame.LookVector)
	if look.Magnitude > 0.1 then
		loco.FacingYaw = MathUtil.yawFromDirection(look)
		loco.DesiredYaw = loco.FacingYaw
	end
end

function StunState.Update(loco: Loco, _dt: number, _intent: Intent)
	loco:ApplyHumanoid(0, Vector3.zero)
	if loco.StateTime >= loco.StateData.Duration then
		loco:ChangeState(if loco.Grounded then "Ground" else "Air", {})
	end
end

return StunState
