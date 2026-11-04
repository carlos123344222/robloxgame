-- Modelos de los gears (Tools) hechos con piezas soldadas al Handle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Config.Gears)
local CFrameUtil = require(ReplicatedStorage.Shared.Util.CFrameUtil)

local ToolBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: BasePart
	p.Name = props.Name or "Part"
	if props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.Size = props.Size
	p.Color = props.Color or rgb(255, 255, 255)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function attach(handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
end

local function newTool(gearId: string): (Tool, BasePart)
	local info = Gears.Get(gearId)
	assert(info, "Gear desconocido " .. gearId)
	local tool = Instance.new("Tool")
	tool.Name = info.Name
	tool.ToolTip = info.FullName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("GearId", gearId)
	return tool, part(tool, { Name = "Handle", Size = V3(0.5, 1, 0.5), Transparency = 1 })
end

local RED = rgb(232, 30, 46)
local WHITE = rgb(255, 255, 255)
local GOLD = rgb(255, 200, 60)

local builders: { [string]: () -> Tool } = {}

function builders.CandyBat(): Tool
	local tool, handle = newTool("CandyBat")
	handle.Size = V3(0.6, 4.6, 0.6)
	tool.Grip = CF(0, -1.6, 0)
	local segments = 8
	local h = 4.6 / segments
	for i = 0, segments - 1 do
		local seg = part(tool, { Name = "Stripe", Size = V3(h + 0.02, 0.6, 0.6), Color = if i % 2 == 0 then RED else WHITE, Shape = Enum.PartType.Cylinder })
		attach(handle, seg, CF(0, -2.3 + h * (i + 0.5), 0) * ANG(0, 0, math.pi / 2))
	end
	-- gancho
	local r = 0.75
	local center = V3(r, 2.3, 0)
	local prev = V3(0, 2.3, 0)
	for i = 1, 6 do
		local theta = math.pi - math.pi * 1.15 * (i / 6)
		local p = center + V3(math.cos(theta) * r, math.sin(theta) * r, 0)
		local mid = (prev + p) / 2
		local seg = part(tool, { Name = "Hook", Size = V3((p - prev).Magnitude + 0.25, 0.6, 0.6), Color = if i % 2 == 0 then RED else WHITE, Shape = Enum.PartType.Cylinder })
		attach(handle, seg, CFrameUtil.LookAt(mid, p) * ANG(0, math.pi / 2, 0))
		prev = p
	end
	local bow = part(tool, { Name = "Bow", Size = V3(0.9, 0.5, 0.3), Color = rgb(40, 170, 80) })
	attach(handle, bow, CF(0, 1.6, -0.35))
	return tool
end

function builders.Snowball(): Tool
	local tool, handle = newTool("Snowball")
	handle.Size = V3(1.1, 1.1, 1.1)
	tool.Grip = CF(0, 0, 0.1)
	local ball = part(tool, { Name = "Ball", Size = V3(1.1, 1.1, 1.1), Shape = Enum.PartType.Ball, Material = Enum.Material.Snow, Color = rgb(245, 250, 255) })
	attach(handle, ball, CF())
	local glove = part(tool, { Name = "Glove", Size = V3(0.9, 0.5, 0.9), Color = rgb(60, 120, 230), Material = Enum.Material.Fabric })
	attach(handle, glove, CF(0, -0.55, 0))
	return tool
end

function builders.ReindeerBoots(): Tool
	local tool, handle = newTool("ReindeerBoots")
	handle.Size = V3(0.9, 1.2, 1.4)
	tool.Grip = CF(0, -0.2, 0)
	local leg = part(tool, { Name = "Leg", Size = V3(0.9, 1.2, 0.9), Color = rgb(150, 95, 55), Material = Enum.Material.Fabric })
	attach(handle, leg, CF(0, 0.2, 0.2))
	local foot = part(tool, { Name = "Foot", Size = V3(0.9, 0.5, 1.5), Color = rgb(150, 95, 55), Material = Enum.Material.Fabric })
	attach(handle, foot, CF(0, -0.55, -0.1))
	local cuff = part(tool, { Name = "Cuff", Size = V3(1.1, 0.35, 1.1), Color = WHITE, Material = Enum.Material.Fabric })
	attach(handle, cuff, CF(0, 0.85, 0.2))
	local sole = part(tool, { Name = "Sole", Size = V3(0.95, 0.15, 1.55), Color = rgb(60, 40, 30) })
	attach(handle, sole, CF(0, -0.85, -0.1))
	local bell = part(tool, { Name = "Bell", Size = V3(0.35, 0.35, 0.35), Shape = Enum.PartType.Ball, Color = GOLD, Material = Enum.Material.Metal })
	attach(handle, bell, CF(0, 0.6, -0.35))
	local trail0 = Instance.new("Attachment")
	trail0.Position = V3(0, -0.8, 0.3)
	trail0.Parent = handle
	local trail1 = Instance.new("Attachment")
	trail1.Position = V3(0, -0.8, -0.5)
	trail1.Parent = handle
	local sparkle = Instance.new("Trail")
	sparkle.Attachment0 = trail0
	sparkle.Attachment1 = trail1
	sparkle.Color = ColorSequence.new(rgb(255, 230, 140), rgb(255, 120, 60))
	sparkle.LightEmission = 1
	sparkle.Lifetime = 0.35
	sparkle.Transparency = NumberSequence.new(0.2, 1)
	sparkle.Parent = handle
	return tool
end

function builders.JingleBell(): Tool
	local tool, handle = newTool("JingleBell")
	handle.Size = V3(0.4, 1.2, 0.4)
	tool.Grip = CF(0, -0.3, 0)
	local stick = part(tool, { Name = "Stick", Size = V3(1.2, 0.4, 0.4), Color = rgb(120, 70, 40), Material = Enum.Material.Wood, Shape = Enum.PartType.Cylinder })
	attach(handle, stick, ANG(0, 0, math.pi / 2))
	local diameters = { 1.5, 1.3, 1.1, 0.9 }
	for i, d in diameters do
		local ring = part(tool, { Name = "Bell", Size = V3(0.3, d, d), Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.2, Shape = Enum.PartType.Cylinder })
		attach(handle, ring, CF(0, 0.75 + (i - 1) * 0.28, 0) * ANG(0, 0, math.pi / 2))
	end
	local dome = part(tool, { Name = "Dome", Size = V3(0.8, 0.8, 0.8), Shape = Enum.PartType.Ball, Color = GOLD, Material = Enum.Material.Metal })
	attach(handle, dome, CF(0, 1.75, 0))
	local bow = part(tool, { Name = "Bow", Size = V3(1, 0.4, 0.3), Color = RED })
	attach(handle, bow, CF(0, 0.55, -0.5))
	return tool
end

function builders.FreezeRay(): Tool
	local tool, handle = newTool("FreezeRay")
	handle.Size = V3(0.5, 1.1, 0.6)
	tool.Grip = CF(0, -0.2, 0.3)
	local grip = part(tool, { Name = "Grip", Size = V3(0.5, 1.1, 0.6), Color = rgb(40, 50, 70) })
	attach(handle, grip, CF())
	local body = part(tool, { Name = "Body", Size = V3(0.8, 0.8, 2.4), Color = rgb(230, 240, 255), Material = Enum.Material.Metal })
	attach(handle, body, CF(0, 0.75, -0.6))
	local tank = part(tool, { Name = "Tank", Size = V3(1.4, 0.7, 0.7), Shape = Enum.PartType.Cylinder, Color = rgb(110, 210, 255), Material = Enum.Material.Neon, Transparency = 0.2 })
	attach(handle, tank, CF(0, 1.3, -0.4) * ANG(0, math.pi / 2, 0))
	local barrel = part(tool, { Name = "Barrel", Size = V3(1.6, 0.45, 0.45), Shape = Enum.PartType.Cylinder, Color = rgb(70, 80, 100), Material = Enum.Material.Metal })
	attach(handle, barrel, CF(0, 0.75, -2.4) * ANG(0, math.pi / 2, 0))
	local tip = part(tool, { Name = "Tip", Size = V3(0.3, 0.6, 0.6), Shape = Enum.PartType.Cylinder, Color = rgb(150, 230, 255), Material = Enum.Material.Neon })
	attach(handle, tip, CF(0, 0.75, -3.25) * ANG(0, math.pi / 2, 0))
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = V3(0, 0.75, -3.5)
	muzzle.Parent = handle
	local light = Instance.new("PointLight")
	light.Color = rgb(120, 220, 255)
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = tip
	return tool
end

function ToolBuilder.Build(gearId: string): Tool
	local builder = builders[gearId]
	assert(builder, "Sin modelo para el gear " .. gearId)
	return builder()
end

return ToolBuilder
