--!strict
-- Small one-shot visual feedback for the local player: dust on landings, skids, slides and dashes.
-- (Trails and body language for everyone live in PoseController.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

type Loco = Types.Loco

local EffectsController = {}

local connections: { { Disconnect: (any) -> () } } = {}
local emitter: ParticleEmitter? = nil

local function createEmitter(loco: Loco): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "WCT_FeetFx"
	attachment.Position = Vector3.new(0, -loco.RootToFeet + 0.2, 0)
	attachment.Parent = loco.Root

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Dust"
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Rate = 0
	particles.Enabled = false
	particles.Lifetime = NumberRange.new(0.35, 0.7)
	particles.Speed = NumberRange.new(5, 12)
	particles.SpreadAngle = Vector2.new(80, 80)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Acceleration = Vector3.new(0, -4, 0)
	particles.Rotation = NumberRange.new(0, 360)
	particles.Color = ColorSequence.new(Color3.fromRGB(200, 195, 185))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Parent = attachment
	return particles
end

local function burst(count: number)
	if emitter and emitter.Parent then
		emitter:Emit(math.floor(count))
	end
end

local function bind(loco: Loco?)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	emitter = nil
	if loco == nil then
		return
	end

	local particles = createEmitter(loco)
	emitter = particles

	table.insert(
		connections,
		loco.Events:Connect(function(name: string, data: any)
			if name == "Land" and typeof(data) == "number" then
				if data > 30 then
					burst(math.clamp(data / 6, 4, 26))
				end
			elseif name == "HardLand" then
				burst(20)
			elseif name == "Skid" then
				burst(10)
			elseif name == "SlideStart" or name == "Dash" or name == "Roll" then
				burst(12)
			elseif name == "Jump" then
				burst(5)
			elseif name == "WallJump" or name == "AirJump" then
				burst(8)
			end
		end)
	)
	table.insert(
		connections,
		loco.StateChanged:Connect(function(newState: string)
			particles.Rate = if newState == "Slide" then 40 else 0
			particles.Enabled = newState == "Slide"
		end)
	)
end

function EffectsController.Start(movement: Types.LocoProvider)
	movement.LocoChanged:Connect(bind)
	bind(movement.GetLocomotion())
end

return EffectsController
