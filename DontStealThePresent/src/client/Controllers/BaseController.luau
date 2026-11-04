-- Bases desde el punto de vista del jugador:
--   · el escudo de una base bloqueada es sólido para ti salvo que sea la tuya (la colisión es local)
--   · el prompt "Robar" solo sale en bases ajenas abiertas y "Vender" solo en la tuya
--   · marcador "TU TALLER" visible desde lejos y flecha de luz hacia tu taller cuando llevas un regalo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)

local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local BaseController = {}

local prompts: { [ProximityPrompt]: boolean } = {}
local marker: BillboardGui? = nil
local markerDistance: TextLabel? = nil
local beam: Beam? = nil
local beamTarget: Attachment? = nil
local beamSource: Attachment? = nil

local function registerPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and (instance.Name == "StealPrompt" or instance.Name == "SellPrompt") then
		prompts[instance] = true
	end
end

local function updatePrompts()
	local now = ClientState.Now()
	local carrying = player:GetAttribute("Carrying") ~= nil
	for prompt in prompts do
		if not prompt.Parent then
			prompts[prompt] = nil
			continue
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		local ownerId = model and model:GetAttribute("OwnerUserId")
		local mine = ownerId == player.UserId
		local base = model and model:FindFirstAncestor("Base" .. tostring(model:GetAttribute("BaseId")))
		local locked = base ~= nil and ((base:GetAttribute("LockedUntil") :: number?) or 0) > now
		if prompt.Name == "StealPrompt" then
			prompt.Enabled = not mine and not locked and not carrying
		else
			prompt.Enabled = mine
		end
	end
end

local function updateShields()
	local map = ClientState.Map()
	local bases = map and map:FindFirstChild("Bases")
	if not bases then
		return
	end
	local now = ClientState.Now()
	for _, base in bases:GetChildren() do
		local locked = ((base:GetAttribute("LockedUntil") :: number?) or 0) > now
		local mine = base:GetAttribute("OwnerUserId") == player.UserId
		local solid = locked and not mine
		for _, name in { "LockDoor", "LockLid" } do
			local part = base:FindFirstChild(name) :: BasePart?
			if part and part.CanCollide ~= solid then
				part.CanCollide = solid
			end
		end
	end
end

local function ensureMarker(base: Model)
	local sign = base:FindFirstChild("Sign") :: BasePart?
	if not sign then
		return
	end
	if marker and marker.Adornee == sign then
		return
	end
	if marker then
		marker:Destroy()
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Gui.Create("BillboardGui", {
		Name = "MyBaseMarker",
		Adornee = sign,
		Size = UDim2.fromOffset(170, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 16, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local panel = Theme.Panel({ Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Green, Parent = gui, Radius = 12 })
	Gui.Label({
		Text = "🏠 TU TALLER",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -10, 0.6, 0),
		Position = UDim2.fromOffset(5, 3),
		StrokeThickness = 2,
		Parent = panel,
	})
	markerDistance = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -10, 0.36, 0),
		Position = UDim2.new(0, 5, 0.6, 0),
		TextColor3 = Color3.fromRGB(220, 255, 220),
		StrokeThickness = 2,
		Parent = panel,
	})
	marker = gui
end

local function updateMarker()
	local base = ClientState.MyBase()
	if not base then
		if marker then
			marker.Enabled = false
		end
		return
	end
	ensureMarker(base)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local sign = base:FindFirstChild("Sign") :: BasePart?
	if marker and root and sign then
		local distance = (root.Position - sign.Position).Magnitude
		marker.Enabled = distance > 45
		if markerDistance then
			markerDistance.Text = string.format("%d studs", math.floor(distance))
		end
	end

	-- flecha de luz cuando llevas un regalo
	local carrying = player:GetAttribute("Carrying") ~= nil
	if carrying and root then
		local structure = base:FindFirstChild("Structure")
		local floor = if structure then structure:FindFirstChild("Floor") :: BasePart? else nil
		if floor and (not beamTarget or beamTarget.Parent ~= floor) then
			if beamTarget then
				beamTarget:Destroy()
			end
			local target = Instance.new("Attachment")
			target.Name = "CarryTarget"
			target.Position = Vector3.new(0, 3, 0)
			target.Parent = floor
			beamTarget = target
		end
		if not beamSource or beamSource.Parent ~= root then
			if beamSource then
				beamSource:Destroy()
			end
			local source = Instance.new("Attachment")
			source.Name = "CarrySource"
			source.Position = Vector3.new(0, -1.5, 0)
			source.Parent = root
			beamSource = source
		end
		if not beam then
			local b = Instance.new("Beam")
			b.Name = "CarryBeam"
			b.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 255, 140))
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Width0 = 1.4
			b.Width1 = 3
			b.FaceCamera = true
			b.Segments = 20
			b.CurveSize0 = 8
			b.CurveSize1 = -8
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(1, 0.1),
			})
			b.Parent = workspace.CurrentCamera
			beam = b
		end
		local activeBeam = beam :: Beam
		activeBeam.Attachment0 = beamSource
		activeBeam.Attachment1 = beamTarget
		activeBeam.Enabled = true
	elseif beam then
		beam.Enabled = false
	end
end

function BaseController.Start()
	for _, d in workspace:GetDescendants() do
		registerPrompt(d)
	end
	workspace.DescendantAdded:Connect(function(d)
		registerPrompt(d)
		if d:IsA("ProximityPrompt") then
			task.defer(updatePrompts)
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		updatePrompts()
		updateShields()
		updateMarker()
	end)
end

return BaseController
