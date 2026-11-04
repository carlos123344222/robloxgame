-- Efectos locales: nieve, partículas, "+$" flotante, bolas de nieve, rayos, golpes, empujones,
-- temblor de cámara y los visuales de los eventos (ventisca, aurora, trineo de Santa, lluvia de oro).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)
local CFrameUtil = require(Shared.Util.CFrameUtil)

local SoundController = require(script.Parent.SoundController)
local Notifications = require(script.Parent.Parent.UI.Notifications)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local EffectsController = {}

local fxFolder: Folder
local snowPart: BasePart
local snowEmitter: ParticleEmitter
local goldEmitter: ParticleEmitter
local shake = 0
local projectiles: { [number]: { Part: BasePart, Position: Vector3, Velocity: Vector3, Gravity: Vector3, Age: number } } = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SOFT = "rbxasset://textures/particles/smoke_main.dds"

local function anchoredPart(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(part :: any)[k] = v
	end
	part.Parent = props.Parent or fxFolder
	return part
end

-- Ráfaga de partículas en un punto
local function burst(position: Vector3, color: Color3, count: number, texture: string?, size: number?, speed: number?)
	local holder = anchoredPart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture or SPARKLE
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size or 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(1.6, function()
		holder:Destroy()
	end)
end

-- "+$1.2K" que sube y se desvanece
local function floatingText(position: Vector3, text: string, color: Color3)
	local holder = anchoredPart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1 })
	local billboard = Gui.Create("BillboardGui", {
		Size = UDim2.fromOffset(220, 60),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = holder,
		Parent = holder,
	})
	local label = Gui.Label({
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 3,
		Parent = billboard,
	})
	local scale = Gui.Create("UIScale", { Scale = 0.4, Parent = label })
	Theme.Tween(scale, 0.25, { Scale = 1.15 }, Enum.EasingStyle.Back)
	Theme.Tween(billboard, 1.2, { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) })
	task.delay(0.7, function()
		Theme.Tween(label, 0.5, { TextTransparency = 1 })
		Theme.Tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.5, { Transparency = 1 })
	end)
	task.delay(1.3, function()
		holder:Destroy()
	end)
end

-- Rayo congelador
local function beam(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	local part = anchoredPart({
		Size = Vector3.new(0.5, 0.5, length),
		CFrame = CFrameUtil.LookAt((from + to) / 2, to),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	local core = anchoredPart({
		Size = Vector3.new(0.2, 0.2, length),
		CFrame = part.CFrame,
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
	})
	Theme.Tween(part, 0.35, { Transparency = 1, Size = Vector3.new(1.4, 1.4, length) })
	Theme.Tween(core, 0.3, { Transparency = 1 })
	burst(to, color, 25, SPARKLE, 1, 18)
	task.delay(0.4, function()
		part:Destroy()
		core:Destroy()
	end)
end

local function spawnProjectile(id: number, origin: Vector3, velocity: Vector3, gravity: Vector3)
	local part = anchoredPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		CFrame = CFrame.new(origin),
		Color = Color3.fromRGB(245, 250, 255),
		Material = Enum.Material.Snow,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.5
	trail.Parent = part
	projectiles[id] = { Part = part, Position = origin, Velocity = velocity, Gravity = gravity, Age = 0 }
end

local function removeProjectile(id: number)
	local projectile = projectiles[id]
	if projectile then
		projectile.Part:Destroy()
		projectiles[id] = nil
	end
end

-- Empujón / golpe recibido
local function knockback(velocity: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.Sit = false
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(-6, 6))
	shake = math.max(shake, 0.8)
	task.delay(0.75, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Nieve y eventos ------------------------------------------------------------------------------------------

local function setupSnow()
	snowPart = anchoredPart({ Name = "SnowArea", Size = Vector3.new(170, 1, 170), Transparency = 1, Parent = camera })
	snowEmitter = Instance.new("ParticleEmitter")
	snowEmitter.Name = "Snow"
	snowEmitter.Texture = SOFT
	snowEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snowEmitter.LightEmission = 0.4
	snowEmitter.LightInfluence = 0.6
	snowEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	snowEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.05),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	snowEmitter.Lifetime = NumberRange.new(7, 9)
	snowEmitter.Rate = 260
	snowEmitter.Speed = NumberRange.new(5, 8)
	snowEmitter.EmissionDirection = Enum.NormalId.Bottom
	snowEmitter.SpreadAngle = Vector2.new(12, 12)
	snowEmitter.Acceleration = Vector3.new(1.2, -0.5, 0.6)
	snowEmitter.RotSpeed = NumberRange.new(-60, 60)
	snowEmitter.Rotation = NumberRange.new(0, 360)
	snowEmitter.Shape = Enum.ParticleEmitterShape.Box
	snowEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snowEmitter.Parent = snowPart

	goldEmitter = snowEmitter:Clone()
	goldEmitter.Name = "Gold"
	goldEmitter.Texture = SPARKLE
	goldEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 170, 40))
	goldEmitter.LightEmission = 1
	goldEmitter.Size = NumberSequence.new(0.45, 0.2)
	goldEmitter.Rate = 0
	goldEmitter.Parent = snowPart
end

-- Aurora boreal: cintas de luz en el cielo
local auroraFolder: Folder? = nil
local function setAurora(on: boolean)
	if on and not auroraFolder then
		local folder = Instance.new("Folder")
		folder.Name = "Aurora"
		folder.Parent = fxFolder
		auroraFolder = folder
		local colors = {
			{ Color3.fromRGB(80, 255, 170), Color3.fromRGB(120, 140, 255) },
			{ Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 255, 200) },
			{ Color3.fromRGB(80, 220, 255), Color3.fromRGB(200, 110, 255) },
		}
		for i = 1, 3 do
			local anchor = anchoredPart({ Name = "AuroraAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(0, 230 + i * 25, -120 + i * 90), Parent = folder })
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(-520, 0, 0)
			a0.Parent = anchor
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(520, 0, 0)
			a1.Parent = anchor
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Width0 = 110
			b.Width1 = 140
			b.Segments = 40
			b.CurveSize0 = 160
			b.CurveSize1 = -160
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Color = ColorSequence.new(colors[i][1], colors[i][2])
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(0.7, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			b.FaceCamera = false
			b.Parent = anchor
		end
	elseif not on and auroraFolder then
		auroraFolder:Destroy()
		auroraFolder = nil
	end
end

-- Trineo de Santa volando en círculos
local sleigh: Model? = nil
local function buildSleigh(): Model
	local model = Instance.new("Model")
	model.Name = "SantaSleigh"
	local root = anchoredPart({ Name = "Root", Size = Vector3.new(1, 1, 1), Transparency = 1, Parent = model })
	model.PrimaryPart = root
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = offset
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = model
		return p
	end
	local red = Color3.fromRGB(200, 25, 40)
	local gold = Color3.fromRGB(255, 200, 60)
	piece(Vector3.new(7, 3.5, 10), CFrame.new(0, 2.5, 0), red)
	piece(Vector3.new(7, 4, 1.2), CFrame.new(0, 5, 4.5), red)
	piece(Vector3.new(7.4, 0.5, 10.4), CFrame.new(0, 4.3, 0), gold, Enum.Material.Metal)
	for _, x in { -3, 3 } do
		piece(Vector3.new(0.5, 0.5, 13), CFrame.new(x, 0, -1), gold, Enum.Material.Metal)
	end
	-- Santa
	piece(Vector3.new(3, 3, 3), CFrame.new(0, 5.5, 1), red, Enum.Material.Fabric)
	piece(Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 7.8, 1), Color3.fromRGB(255, 214, 180))
	piece(Vector3.new(2.4, 1.6, 2.4), CFrame.new(0, 7.1, 0.4), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric)
	piece(Vector3.new(2.3, 1.4, 2.3), CFrame.new(0, 9.2, 1), red, Enum.Material.Fabric)
	piece(Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 10.2, 1.4), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric, Enum.PartType.Ball)
	-- saco de regalos
	piece(Vector3.new(4, 4, 4), CFrame.new(0, 6, 3.4), Color3.fromRGB(120, 70, 40), Enum.Material.Fabric, Enum.PartType.Ball)
	-- renos
	for i = 1, 4 do
		local z = -10 - (i - 1) * 6
		for _, x in { -2, 2 } do
			if i % 2 == 0 or x < 0 then
				piece(Vector3.new(1.8, 1.8, 4), CFrame.new(x, 2, z), Color3.fromRGB(140, 92, 56))
				piece(Vector3.new(1.3, 1.3, 1.8), CFrame.new(x, 3.4, z - 2.4), Color3.fromRGB(140, 92, 56))
				local nose = piece(Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 3.3, z - 3.4), if i == 4 and x < 0 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(60, 40, 30), if i == 4 and x < 0 then Enum.Material.Neon else nil, Enum.PartType.Ball)
				if i == 4 and x < 0 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 60, 60)
					light.Range = 18
					light.Brightness = 3
					light.Parent = nose
				end
				piece(Vector3.new(0.3, 2, 0.3), CFrame.new(x - 0.4, 4.6, z - 2.2) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(230, 210, 170))
				piece(Vector3.new(0.3, 2, 0.3), CFrame.new(x + 0.4, 4.6, z - 2.2) * CFrame.Angles(0, 0, -0.4), Color3.fromRGB(230, 210, 170))
			end
		end
	end
	local trail0 = Instance.new("Attachment")
	trail0.Position = Vector3.new(0, 1, 6)
	trail0.Parent = root
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = SPARKLE
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 255, 255))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(1.6, 0)
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 60
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Parent = trail0
	model.Parent = fxFolder
	return model
end

local function setSleigh(on: boolean)
	if on and not sleigh then
		sleigh = buildSleigh()
	elseif not on and sleigh then
		sleigh:Destroy()
		sleigh = nil
	end
end

local baseFog: { Density: number, Haze: number }? = nil

local function applyEvent(eventId: string)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and not baseFog then
		baseFog = { Density = atmosphere.Density, Haze = atmosphere.Haze }
	end
	local blizzard = eventId == "Blizzard"
	snowEmitter.Rate = if blizzard then 1100 else 260
	snowEmitter.Speed = if blizzard then NumberRange.new(16, 24) else NumberRange.new(5, 8)
	snowEmitter.Acceleration = if blizzard then Vector3.new(22, -4, 9) else Vector3.new(1.2, -0.5, 0.6)
	goldEmitter.Rate = if eventId == "GoldRain" then 160 else 0
	if atmosphere and baseFog then
		Theme.Tween(atmosphere, 2, {
			Density = if blizzard then 0.58 else baseFog.Density,
			Haze = if blizzard then 3 else baseFog.Haze,
		})
	end
	setAurora(eventId == "Aurora")
	setSleigh(eventId == "SantaNight")
end

-- Arranque ------------------------------------------------------------------------------------------------

function EffectsController.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = workspace.CurrentCamera
	setupSnow()

	Remotes.Event("Fx").OnClientEvent:Connect(function(kind, payload)
		if type(payload) ~= "table" then
			payload = {}
		end
		if kind == "Sound" then
			SoundController.Play(payload.Name, payload.Position, 0.06)
		elseif kind == "Burst" then
			burst(payload.Position, payload.Color or Color3.new(1, 1, 1), payload.Count or 20)
		elseif kind == "Collect" then
			floatingText(payload.Position, "+" .. Format.Cash(payload.Amount or 0), Theme.Colors.Money)
			burst(payload.Position, Color3.fromRGB(255, 220, 80), 14, SPARKLE, 0.7, 10)
			SoundController.Play(payload.Sound or "Collect", nil, 0.08)
		elseif kind == "Projectile" then
			spawnProjectile(payload.Id, payload.Origin, payload.Velocity, payload.Gravity)
		elseif kind == "SnowBurst" then
			removeProjectile(payload.Id)
			burst(payload.Position, Color3.fromRGB(240, 248, 255), 26, SOFT, 1.2, 16)
			SoundController.Play("SnowHit", payload.Position, 0.1)
		elseif kind == "Beam" then
			beam(payload.From, payload.To, payload.Color or Color3.fromRGB(120, 220, 255))
		elseif kind == "Hit" then
			burst(payload.Position, Color3.fromRGB(255, 230, 90), 22, SPARKLE, 1.1, 20)
			SoundController.Play("Hit", payload.Position, 0.1)
		elseif kind == "Confetti" then
			Notifications.Confetti(payload.Big == true)
		end
	end)

	Remotes.Event("Knockback").OnClientEvent:Connect(function(velocity)
		if typeof(velocity) == "Vector3" then
			knockback(velocity)
		end
	end)

	-- temblor de cámara (después de que la cámara por defecto se actualice)
	RunService:BindToRenderStep("DSTPCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake > 0 then
			shake = math.max(0, shake - dt * 2.5)
			local s = shake * 0.35
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * s * 0.1, (math.random() - 0.5) * s * 0.1, 0)
		end
	end)

	local lastEvent = ""
	RunService.RenderStepped:Connect(function(dt)
		-- la nieve sigue a la cámara
		local camPos = camera.CFrame.Position
		snowPart.CFrame = CFrame.new(camPos.X, camPos.Y + 45, camPos.Z)
		-- proyectiles
		for id, p in projectiles do
			p.Age += dt
			p.Position += p.Velocity * dt + p.Gravity * (0.5 * dt * dt)
			p.Velocity += p.Gravity * dt
			p.Part.CFrame = CFrame.new(p.Position)
			if p.Age > 2.4 then
				removeProjectile(id)
			end
		end
		-- trineo de Santa
		if sleigh and sleigh.PrimaryPart then
			local t = os.clock() * 0.12
			local radius = 260
			local center = Vector3.new(20, 130 + math.sin(os.clock() * 0.5) * 10, 0)
			local pos = center + Vector3.new(math.cos(t) * radius, 0, math.sin(t) * radius * 0.6)
			local ahead = center + Vector3.new(math.cos(t + 0.05) * radius, 0, math.sin(t + 0.05) * radius * 0.6)
			sleigh.PrimaryPart.CFrame = CFrame.lookAt(pos, ahead)
		end
		-- eventos
		local eventId = workspace:GetAttribute("EventId")
		local id = if type(eventId) == "string" then eventId else ""
		if id ~= lastEvent then
			lastEvent = id
			applyEvent(id)
		end
	end)
end

return EffectsController
