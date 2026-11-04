-- Ayudas para construir el mapa con Parts. Solo usa propiedades (nada de servicios ni eventos), así el
-- mismo código puede "hornear" el mapa en el .rbxl desde fuera de Roblox (tools/lune/bake.luau).

local Build = {}

export type Props = {
	Name: string?,
	Class: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Anchored: boolean?,
	Tag: string?,
}

local DEFAULT_COLOR = Color3.fromRGB(240, 240, 240)

function Build.Part(parent: Instance, props: Props): BasePart
	local part = Instance.new(props.Class or "Part") :: BasePart
	part.Name = props.Name or "Part"
	if props.Shape and part:IsA("Part") then
		local asPart = part :: Part
		asPart.Shape = props.Shape
	end
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or DEFAULT_COLOR
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	part.Anchored = if props.Anchored == nil then true else props.Anchored
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.CanQuery = if props.CanQuery == nil then true else props.CanQuery
	part.CanTouch = if props.CanTouch == nil then false else props.CanTouch
	part.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Tag then
		part:AddTag(props.Tag)
	end
	part.Parent = parent
	return part
end

-- Pieza decorativa: sin colisión, sin consultas
function Build.Deco(parent: Instance, props: Props): BasePart
	props.CanCollide = if props.CanCollide == nil then false else props.CanCollide
	props.CanQuery = if props.CanQuery == nil then false else props.CanQuery
	return Build.Part(parent, props)
end

-- Cilindro vertical (el eje de los cilindros de Roblox es X; lo giramos para que sea Y)
function Build.Cylinder(parent: Instance, height: number, diameter: number, cf: CFrame, props: { [string]: any }?): BasePart
	local p: any = props or {}
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	p.Shape = Enum.PartType.Cylinder
	return Build.Part(parent, p)
end

-- Cilindro horizontal a lo largo del eje X local de cf
function Build.Log(parent: Instance, length: number, diameter: number, cf: CFrame, props: { [string]: any }?): BasePart
	local p: any = props or {}
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = cf
	p.Shape = Enum.PartType.Cylinder
	return Build.Part(parent, p)
end

function Build.Ball(parent: Instance, diameter: number, cf: CFrame, props: { [string]: any }?): BasePart
	local p: any = props or {}
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = cf
	p.Shape = Enum.PartType.Ball
	return Build.Part(parent, p)
end

function Build.Model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.Folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.Light(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function Build.Emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-- Poste con rayas de bastón de caramelo
function Build.CandyPole(parent: Instance, base: CFrame, height: number, diameter: number, stripe: number?): { BasePart }
	local parts = {}
	local seg = stripe or 1.4
	local count = math.max(2, math.floor(height / seg))
	local segH = height / count
	for i = 0, count - 1 do
		local color = if i % 2 == 0 then Color3.fromRGB(232, 30, 46) else Color3.fromRGB(255, 255, 255)
		local part = Build.Cylinder(parent, segH, diameter, base * CFrame.new(0, segH * (i + 0.5), 0), {
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Name = "CandyStripe",
		})
		table.insert(parts, part)
	end
	return parts
end

-- Guirnalda de bombillas entre dos puntos
local BULB_COLORS = {
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(60, 255, 110),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(255, 120, 230),
}

function Build.StringLights(parent: Instance, a: Vector3, b: Vector3, spacing: number, sag: number?, size: number?, offset: number?)
	local length = (b - a).Magnitude
	local count = math.max(2, math.floor(length / spacing))
	local droop = sag or 0
	for i = 0, count do
		local t = i / count
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * droop, 0)
		Build.Ball(parent, size or 0.5, CFrame.new(p), {
			Color = BULB_COLORS[(i + (offset or 0)) % #BULB_COLORS + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Name = "Bulb",
			Tag = "TwinkleBulb",
		})
	end
end

Build.BulbColors = BULB_COLORS

return Build
