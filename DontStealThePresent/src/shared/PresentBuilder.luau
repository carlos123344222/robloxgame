-- Construye los modelos de los regalos solo con Parts (sin mallas ni assets que haya que subir).
--
-- Estructura del modelo:
--   Model (PrimaryPart = Root)
--     Root            Part invisible en la BASE del regalo (y = 0). Anclado. Todo lo demás va soldado a él.
--     ...             piezas visuales soldadas con Weld (sin colisión, sin masa)
--     Root.Mid        Attachment a media altura (prompts, luz, partículas)
--     Root.Top        Attachment encima del regalo (carteles)
--
-- Las piezas que giran (anillos, planetas, bailarina...) cuelgan de un "hub" soldado con un Weld llamado
-- SpinWeld (atributos SpinSpeed y SpinAxis); el cliente anima su C0.
-- Las piezas con la etiqueta "Rainbow" cambian de color en el cliente.

local Presents = require(script.Parent.Config.Presents)
local Rarities = require(script.Parent.Config.Rarities)
local Mutations = require(script.Parent.Config.Mutations)
local CFrameUtil = require(script.Parent.Util.CFrameUtil)

local PresentBuilder = {}

type Ctx = {
	Model: Model,
	Root: BasePart,
	S: number,
	Body: Color3,
	Ribbon: Color3,
	Accent: Color3,
	Parts: { BasePart },
	Roles: { [BasePart]: string },
	Count: number,
}

type PartProps = {
	Class: string?,
	Size: Vector3,
	CF: CFrame,
	Color: Color3?,
	Role: string?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	Mesh: boolean?, -- true = elipsoide (SpecialMesh esfera escalada al tamaño del Part)
	Hub: BasePart?, -- si se indica, CF es relativo al hub y se suelda a él
	Name: string?,
}

local PI = math.pi
local rad = math.rad
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local DARK = Color3.fromRGB(30, 30, 36)
local LEAF = Color3.fromRGB(34, 130, 64)
local BERRY = Color3.fromRGB(215, 25, 40)

-- Piezas -------------------------------------------------------------------------------------------

local function makeWeld(part0: BasePart, part1: BasePart, c0: CFrame): Weld
	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = c0
	weld.C1 = CF()
	weld.Parent = part1
	return weld
end

local function add(ctx: Ctx, props: PartProps): BasePart
	local part = Instance.new(props.Class or "Part") :: BasePart
	ctx.Count += 1
	part.Name = props.Name or ("P" .. ctx.Count)
	if props.Shape and part:IsA("Part") then
		local asPart = part :: Part
		asPart.Shape = props.Shape
	end
	part.Size = props.Size
	part.Color = props.Color or ctx.Body
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = props.Size.Magnitude > 0.9
	if props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	local hub = props.Hub
	if hub then
		local hubWeld = hub:FindFirstChildOfClass("Weld") :: Weld
		part.CFrame = hubWeld.C0 * props.CF
		makeWeld(hub, part, props.CF)
	else
		part.CFrame = props.CF
		makeWeld(ctx.Root, part, props.CF)
	end
	part.Parent = ctx.Model
	table.insert(ctx.Parts, part)
	ctx.Roles[part] = props.Role or "Body"
	return part
end

-- Bloque
local function box(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, { Size = size, CF = cf, Color = color, Role = role, Material = material })
end

-- Esfera perfecta
local function ball(ctx: Ctx, d: number, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, { Size = V3(d, d, d), CF = cf, Color = color, Role = role, Material = material, Shape = Enum.PartType.Ball })
end

-- Elipsoide de cualquier tamaño
local function ellipsoid(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, { Size = size, CF = cf, Color = color, Role = role, Material = material, Mesh = true })
end

-- Cilindro vertical: cf es el centro, h la altura, d el diámetro
local function cyl(ctx: Ctx, h: number, d: number, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, {
		Size = V3(h, d, d),
		CF = cf * ANG(0, 0, PI / 2),
		Color = color,
		Role = role,
		Material = material,
		Shape = Enum.PartType.Cylinder,
	})
end

-- Disco/cilindro cuyo eje mira hacia Z (de frente)
local function disc(ctx: Ctx, thickness: number, d: number, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, {
		Size = V3(thickness, d, d),
		CF = cf * ANG(0, PI / 2, 0),
		Color = color,
		Role = role,
		Material = material,
		Shape = Enum.PartType.Cylinder,
	})
end

local function wedge(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3?, role: string?, material: Enum.Material?)
	return add(ctx, { Class = "WedgePart", Size = size, CF = cf, Color = color, Role = role, Material = material })
end

local function neon(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, isBall: boolean?)
	return add(ctx, {
		Size = size,
		CF = cf,
		Color = color,
		Role = "Glow",
		Material = Enum.Material.Neon,
		Shape = if isBall then Enum.PartType.Ball else nil,
	})
end

-- Pieza invisible que gira; lo que se suelde a ella gira con ella.
local function spinHub(ctx: Ctx, pivot: CFrame, speed: number, axis: Vector3): BasePart
	local hub = add(ctx, { Size = V3(0.2, 0.2, 0.2), CF = pivot, Transparency = 1, Role = "Hub", Name = "Hub" })
	local weld = hub:FindFirstChildOfClass("Weld") :: Weld
	weld.Name = "SpinWeld"
	weld:SetAttribute("SpinSpeed", speed)
	weld:SetAttribute("SpinAxis", axis)
	return hub
end

-- Segmento cilíndrico entre dos puntos
local function segment(ctx: Ctx, a: Vector3, b: Vector3, d: number, color: Color3, role: string?)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude + d * 0.35
	return add(ctx, {
		Size = V3(length, d, d),
		CF = CFrameUtil.LookAt(mid, b) * ANG(0, PI / 2, 0),
		Color = color,
		Role = role,
		Shape = Enum.PartType.Cylinder,
	})
end

-- Lazo encima de un regalo, con el centro en y
local function bow(ctx: Ctx, y: number, size: number, color: Color3?, cf: CFrame?)
	local base = (cf or CF()) * CF(0, y, 0)
	local c = color or ctx.Ribbon
	local loop = V3(size * 0.62, size * 0.42, size * 0.24)
	ellipsoid(ctx, loop, base * CF(-size * 0.27, size * 0.16, 0) * ANG(0, 0, rad(-28)), c, "Ribbon")
	ellipsoid(ctx, loop, base * CF(size * 0.27, size * 0.16, 0) * ANG(0, 0, rad(28)), c, "Ribbon")
	ellipsoid(ctx, loop * 0.8, base * CF(0, size * 0.12, -size * 0.2) * ANG(rad(30), PI / 2, 0), c, "Ribbon")
	ball(ctx, size * 0.24, base * CF(0, size * 0.12, 0), c, "Ribbon")
	local tail = V3(size * 0.1, size * 0.36, size * 0.14)
	box(ctx, tail, base * CF(-size * 0.12, -size * 0.06, -size * 0.12) * ANG(rad(20), 0, rad(25)), c, "Ribbon")
	box(ctx, tail, base * CF(size * 0.12, -size * 0.06, -size * 0.12) * ANG(rad(20), 0, rad(-25)), c, "Ribbon")
end

-- Dos cintas que rodean una caja de tamaño (w, h, d) centrada en cf
local function ribbonCross(ctx: Ctx, w: number, h: number, d: number, cf: CFrame, color: Color3?, widthFactor: number?)
	local rw = math.min(w, d) * (widthFactor or 0.2)
	local c = color or ctx.Ribbon
	box(ctx, V3(w + 0.04, h + 0.04, rw), cf, c, "Ribbon")
	box(ctx, V3(rw, h + 0.04, d + 0.04), cf, c, "Ribbon")
end

-- Hojas de acebo con bayas
local function holly(ctx: Ctx, cf: CFrame, size: number)
	ellipsoid(ctx, V3(size * 0.7, size * 0.12, size * 0.32), cf * CF(-size * 0.25, 0, 0) * ANG(0, rad(20), rad(10)), LEAF, "Accent")
	ellipsoid(ctx, V3(size * 0.7, size * 0.12, size * 0.32), cf * CF(size * 0.25, 0, 0) * ANG(0, rad(-20), rad(-10)), LEAF, "Accent")
	for i = 0, 2 do
		local angle = i * 2 * PI / 3
		ball(ctx, size * 0.2, cf * CF(math.cos(angle) * size * 0.1, size * 0.08, math.sin(angle) * size * 0.1), BERRY, "Accent")
	end
end

-- Estrella de 5 puntas en el plano XY (mirando a -Z). r0 = radio interior, r1 = radio de las puntas.
local function star(ctx: Ctx, cf: CFrame, r1: number, thickness: number, color: Color3, material: Enum.Material?, hub: BasePart?)
	local r0 = r1 * 0.36
	local w = r1 * 0.62
	local mat = material or Enum.Material.Neon
	add(ctx, {
		Size = V3(thickness, r0 * 2.3, r0 * 2.3),
		CF = cf * ANG(0, PI / 2, 0),
		Color = color,
		Role = "Body",
		Material = mat,
		Shape = Enum.PartType.Cylinder,
		Hub = hub,
	})
	for k = 0, 4 do
		local phi = PI / 2 + k * 2 * PI / 5
		local dir = V3(math.cos(phi), math.sin(phi), 0)
		local perp = V3(-math.sin(phi), math.cos(phi), 0)
		local length = r1 - r0 * 0.6
		local baseCenter = dir * (r0 * 0.6)
		for side = -1, 1, 2 do
			local y = perp * side
			local z = -dir
			local x = y:Cross(z)
			local half = w / 2
			local center = baseCenter + y * (half / 2) + dir * (length / 2)
			local local_cf = CFrame.fromMatrix(center, x, y, z)
			add(ctx, {
				Class = "WedgePart",
				Size = V3(thickness, half, length),
				CF = cf * local_cf,
				Color = color,
				Role = "Body",
				Material = mat,
				Hub = hub,
			})
		end
	end
end

-- Formas ---------------------------------------------------------------------------------------------
-- Cada forma construye el regalo con la base en y = 0 y devuelve su altura.

local Shapes: { [string]: (Ctx) -> number } = {}

function Shapes.Box(ctx: Ctx): number
	local s = ctx.S
	local h = s * 0.86
	box(ctx, V3(s, h, s), CF(0, h / 2, 0))
	box(ctx, V3(s * 1.05, s * 0.16, s * 1.05), CF(0, h - s * 0.06, 0))
	ribbonCross(ctx, s * 1.05, h + s * 0.02, s * 1.05, CF(0, h / 2 + s * 0.01, 0))
	bow(ctx, h + s * 0.04, s * 0.62)
	return h + s * 0.35
end

function Shapes.TallBox(ctx: Ctx): number
	local s = ctx.S
	local w, h = s * 0.78, s * 1.3
	box(ctx, V3(w, h, w), CF(0, h / 2, 0))
	box(ctx, V3(w * 1.06, s * 0.16, w * 1.06), CF(0, h - s * 0.06, 0))
	ribbonCross(ctx, w * 1.06, h + 0.02, w * 1.06, CF(0, h / 2 + 0.01, 0))
	holly(ctx, CF(w * 0.18, h + s * 0.04, -w * 0.2), s * 0.32)
	for i = 0, 3 do
		ball(ctx, s * 0.07, CF(-w * 0.2 + i * 0.06 * s, h + s * 0.05, w * 0.22), ctx.Accent, "Accent")
	end
	bow(ctx, h + s * 0.04, s * 0.55)
	return h + s * 0.32
end

function Shapes.Cylinder(ctx: Ctx): number
	local s = ctx.S
	local h, d = s * 0.78, s * 1.02
	cyl(ctx, h, d, CF(0, h / 2, 0))
	cyl(ctx, s * 0.18, d * 1.06, CF(0, h - s * 0.05, 0))
	cyl(ctx, s * 0.14, d * 1.015, CF(0, h * 0.42, 0), ctx.Ribbon, "Ribbon")
	box(ctx, V3(d * 1.07, s * 0.05, s * 0.18), CF(0, h + s * 0.045, 0), ctx.Ribbon, "Ribbon")
	box(ctx, V3(s * 0.18, s * 0.05, d * 1.07), CF(0, h + s * 0.045, 0), ctx.Ribbon, "Ribbon")
	-- copos
	for i = 0, 5 do
		local a = i * PI / 3
		neon(ctx, V3(s * 0.06, s * 0.06, s * 0.06), CF(math.cos(a) * d * 0.51, h * 0.7, math.sin(a) * d * 0.51), ctx.Accent, true)
	end
	bow(ctx, h + s * 0.06, s * 0.55)
	return h + s * 0.35
end

function Shapes.Stack(ctx: Ctx): number
	local s = ctx.S
	local y = 0
	local layers = {
		{ w = s * 1.0, h = s * 0.55, c = ctx.Body, r = ctx.Ribbon, rot = 0 },
		{ w = s * 0.76, h = s * 0.48, c = ctx.Accent, r = ctx.Ribbon, rot = rad(22) },
		{ w = s * 0.54, h = s * 0.42, c = ctx.Ribbon, r = ctx.Body, rot = rad(-14) },
	}
	for _, layer in layers do
		local cf = CF(0, y + layer.h / 2, 0) * ANG(0, layer.rot, 0)
		box(ctx, V3(layer.w, layer.h, layer.w), cf, layer.c, "Body")
		ribbonCross(ctx, layer.w, layer.h, layer.w, cf, layer.r, 0.18)
		y += layer.h
	end
	bow(ctx, y + s * 0.02, s * 0.42, ctx.Body)
	return y + s * 0.25
end

function Shapes.Ball(ctx: Ctx): number
	local s = ctx.S
	local baseH = s * 0.12
	cyl(ctx, baseH, s * 0.5, CF(0, baseH / 2, 0), GOLD, "Accent", Enum.Material.Metal)
	local cy = baseH + s * 0.48
	add(ctx, {
		Size = V3(s * 0.96, s * 0.96, s * 0.96),
		CF = CF(0, cy, 0),
		Shape = Enum.PartType.Ball,
		Reflectance = 0.25,
		Role = "Body",
	})
	ellipsoid(ctx, V3(s * 0.985, s * 0.09, s * 0.985), CF(0, cy + s * 0.17, 0), ctx.Ribbon, "Ribbon")
	ellipsoid(ctx, V3(s * 0.985, s * 0.09, s * 0.985), CF(0, cy - s * 0.17, 0), ctx.Ribbon, "Ribbon")
	for i = 0, 7 do
		local a = i * PI / 4
		neon(ctx, V3(s * 0.08, s * 0.08, s * 0.08), CF(math.cos(a) * s * 0.475, cy, math.sin(a) * s * 0.475), ctx.Accent, true)
	end
	cyl(ctx, s * 0.14, s * 0.26, CF(0, cy + s * 0.5, 0), GOLD, "Accent", Enum.Material.Metal)
	disc(ctx, s * 0.04, s * 0.2, CF(0, cy + s * 0.65, 0), GOLD, "Accent", Enum.Material.Metal)
	return cy + s * 0.72
end

function Shapes.Sock(ctx: Ctx): number
	local s = ctx.S
	local legW, legD, legH = s * 0.5, s * 0.42, s * 0.82
	box(ctx, V3(legW, legH, legD), CF(-s * 0.12, s * 0.2 + legH / 2, 0))
	box(ctx, V3(s * 0.78, s * 0.36, legD), CF(s * 0.02, s * 0.18, 0))
	ellipsoid(ctx, V3(s * 0.3, s * 0.36, legD), CF(s * 0.4, s * 0.18, 0), ctx.Accent, "Accent")
	box(ctx, V3(s * 0.26, s * 0.3, legD + 0.02), CF(-s * 0.26, s * 0.18, 0), ctx.Accent, "Accent")
	-- rayas
	for i = 0, 2 do
		box(ctx, V3(legW + 0.03, s * 0.07, legD + 0.03), CF(-s * 0.12, s * 0.45 + i * s * 0.18, 0), ctx.Ribbon, "Ribbon")
	end
	-- puño de pelo
	box(ctx, V3(legW * 1.25, s * 0.24, legD * 1.3), CF(-s * 0.12, s * 0.2 + legH + s * 0.08, 0), WHITE, "Ribbon", Enum.Material.Fabric)
	-- algo asomando
	box(ctx, V3(s * 0.22, s * 0.22, s * 0.22), CF(-s * 0.2, s * 1.22, 0) * ANG(0, rad(30), rad(15)), GOLD, "Accent")
	segment(ctx, V3(-s * 0.02, s * 1.05, 0), V3(-s * 0.02, s * 1.42, 0), s * 0.07, BERRY, "Accent")
	return s * 1.5
end

function Shapes.Cane(ctx: Ctx): number
	local s = ctx.S
	local d = s * 0.22
	ellipsoid(ctx, V3(s * 0.7, s * 0.2, s * 0.55), CF(s * 0.1, s * 0.07, 0), WHITE, "Accent", Enum.Material.Snow)
	local shaftTop = s * 0.95
	local segments = 6
	local segH = (shaftTop - s * 0.05) / segments
	for i = 0, segments - 1 do
		local color = if i % 2 == 0 then ctx.Body else ctx.Ribbon
		cyl(ctx, segH + 0.01, d, CF(0, s * 0.05 + segH * (i + 0.5), 0), color, if i % 2 == 0 then "Body" else "Ribbon")
	end
	local r = s * 0.27
	local center = V3(r, shaftTop, 0)
	local steps = 8
	local from, to = PI, -PI * 0.28
	local prev = center + V3(math.cos(from) * r, math.sin(from) * r, 0)
	for i = 1, steps do
		local theta = from + (to - from) * (i / steps)
		local p = center + V3(math.cos(theta) * r, math.sin(theta) * r, 0)
		local color = if i % 2 == 0 then ctx.Body else ctx.Ribbon
		segment(ctx, prev, p, d, color, if i % 2 == 0 then "Body" else "Ribbon")
		prev = p
	end
	bow(ctx, 0, s * 0.4, ctx.Accent, CF(0, shaftTop - s * 0.12, -d * 0.45) * ANG(rad(-90), 0, 0))
	return shaftTop + r + d
end

local function sackShape(ctx: Ctx, presentsOnTop: boolean): number
	local s = ctx.S
	ellipsoid(ctx, V3(s, s * 0.9, s * 0.92), CF(0, s * 0.45, 0), nil, "Body", Enum.Material.Fabric)
	ellipsoid(ctx, V3(s * 0.5, s * 0.34, s * 0.5), CF(0, s * 0.92, 0), nil, "Body", Enum.Material.Fabric)
	cyl(ctx, s * 0.09, s * 0.44, CF(0, s * 0.9, 0), ctx.Ribbon, "Ribbon")
	segment(ctx, V3(s * 0.2, s * 0.9, -s * 0.12), V3(s * 0.32, s * 0.6, -s * 0.3), s * 0.06, ctx.Ribbon, "Ribbon")
	if presentsOnTop then
		box(ctx, V3(s * 0.3, s * 0.3, s * 0.3), CF(-s * 0.08, s * 1.12, 0) * ANG(0, rad(20), rad(12)), GOLD, "Accent")
		ribbonCross(ctx, s * 0.3, s * 0.3, s * 0.3, CF(-s * 0.08, s * 1.12, 0) * ANG(0, rad(20), rad(12)), ctx.Body, 0.25)
		box(ctx, V3(s * 0.24, s * 0.34, s * 0.24), CF(s * 0.13, s * 1.1, s * 0.05) * ANG(0, rad(-25), rad(-14)), ctx.Accent, "Accent")
		ellipsoid(ctx, V3(s * 0.34, s * 0.3, s * 0.06), CF(s * 0.1, s * 0.42, -s * 0.45) * ANG(0, 0, rad(10)), ctx.Accent, "Accent")
		star(ctx, CF(-s * 0.14, s * 0.52, -s * 0.47), s * 0.12, s * 0.03, GOLD, Enum.Material.Neon)
		return s * 1.32
	end
	for i = 0, 4 do
		local a = i * 2 * PI / 5
		ball(ctx, s * (0.16 + (i % 2) * 0.05), CF(math.cos(a) * s * 0.14, s * 1.05 + (i % 3) * s * 0.04, math.sin(a) * s * 0.14), ctx.Accent, "Accent", Enum.Material.Slate)
	end
	ball(ctx, s * 0.2, CF(s * 0.42, s * 0.1, -s * 0.3), ctx.Accent, "Accent", Enum.Material.Slate)
	return s * 1.22
end

function Shapes.Bag(ctx: Ctx): number
	return sackShape(ctx, false)
end

function Shapes.Sack(ctx: Ctx): number
	return sackShape(ctx, true)
end

function Shapes.House(ctx: Ctx): number
	local s = ctx.S
	local w, d, h = s * 1.0, s * 0.8, s * 0.6
	box(ctx, V3(w, h, d), CF(0, h / 2, 0))
	local roofH = s * 0.42
	local roofW = w * 1.12
	local halfD = d * 0.56
	wedge(ctx, V3(roofW, roofH, halfD), CF(0, h + roofH / 2, -halfD / 2), ctx.Body, "Body")
	wedge(ctx, V3(roofW, roofH, halfD), CF(0, h + roofH / 2, halfD / 2) * ANG(0, PI, 0), ctx.Body, "Body")
	local alpha = math.atan2(roofH, halfD)
	local slope = math.sqrt(roofH * roofH + halfD * halfD)
	local icing = ctx.Ribbon
	local mid = h + roofH / 2
	local nF = V3(0, math.cos(alpha), -math.sin(alpha))
	local nB = V3(0, math.cos(alpha), math.sin(alpha))
	box(ctx, V3(roofW + 0.04, s * 0.05, slope), CF(V3(0, mid, -halfD / 2) + nF * s * 0.03) * ANG(-alpha, 0, 0), icing, "Ribbon")
	box(ctx, V3(roofW + 0.04, s * 0.05, slope), CF(V3(0, mid, halfD / 2) + nB * s * 0.03) * ANG(alpha, 0, 0), icing, "Ribbon")
	-- puerta y ventanas
	box(ctx, V3(s * 0.22, s * 0.34, s * 0.04), CF(0, s * 0.17, -d / 2 - 0.01), Color3.fromRGB(90, 50, 25), "Fixed")
	neon(ctx, V3(s * 0.16, s * 0.14, s * 0.03), CF(-s * 0.3, h * 0.6, -d / 2 - 0.01), Color3.fromRGB(255, 210, 110))
	neon(ctx, V3(s * 0.16, s * 0.14, s * 0.03), CF(s * 0.3, h * 0.6, -d / 2 - 0.01), Color3.fromRGB(255, 210, 110))
	-- glaseado de las esquinas
	box(ctx, V3(w + 0.04, s * 0.06, d + 0.04), CF(0, h, 0), icing, "Ribbon")
	-- caramelos
	local candy = { ctx.Accent, Color3.fromRGB(60, 200, 90), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 160, 255) }
	for i = 0, 4 do
		ball(ctx, s * 0.1, CF(-w * 0.4 + i * w * 0.2, h + roofH + s * 0.02, 0), candy[i % #candy + 1], "Accent")
	end
	for side = -1, 1, 2 do
		ball(ctx, s * 0.14, CF(side * w * 0.42, s * 0.07, -d * 0.55), candy[(side + 2) % #candy + 1], "Accent")
	end
	box(ctx, V3(s * 0.14, s * 0.26, s * 0.14), CF(w * 0.28, h + roofH * 0.75, halfD * 0.35), Color3.fromRGB(180, 60, 50), "Fixed")
	return h + roofH + s * 0.12
end

function Shapes.FrostBox(ctx: Ctx): number
	local s = ctx.S
	local h = s * 0.86
	add(ctx, { Size = V3(s, h, s), CF = CF(0, h / 2, 0), Material = Enum.Material.Ice, Transparency = 0.08, Reflectance = 0.1, Role = "Body" })
	box(ctx, V3(s * 1.06, s * 0.16, s * 1.06), CF(0, h - s * 0.05, 0), nil, "Body", Enum.Material.Ice)
	ribbonCross(ctx, s * 1.06, h + 0.02, s * 1.06, CF(0, h / 2 + 0.01, 0))
	ellipsoid(ctx, V3(s * 1.1, s * 0.16, s * 1.1), CF(0, h + s * 0.04, 0), WHITE, "Accent", Enum.Material.Snow)
	-- carámbanos
	for i = 0, 5 do
		local x = -s * 0.45 + i * s * 0.18
		wedge(ctx, V3(s * 0.06, s * 0.2, s * 0.08), CF(x, h - s * 0.24, -s * 0.54) * ANG(PI, 0, 0), ctx.Accent, "Accent", Enum.Material.Glass)
		wedge(ctx, V3(s * 0.06, s * 0.16, s * 0.08), CF(-s * 0.54, h - s * 0.22, x) * ANG(PI, PI / 2, 0), ctx.Accent, "Accent", Enum.Material.Glass)
	end
	for i = 0, 3 do
		neon(ctx, V3(s * 0.05, s * 0.05, s * 0.05), CF(math.cos(i * PI / 2) * s * 0.3, h * 0.5, -s * 0.51), WHITE, true)
	end
	bow(ctx, h + s * 0.1, s * 0.55)
	return h + s * 0.42
end

function Shapes.Globe(ctx: Ctx): number
	local s = ctx.S
	local baseH = s * 0.3
	cyl(ctx, baseH, s * 0.86, CF(0, baseH / 2, 0), ctx.Body, "Body", Enum.Material.Wood)
	cyl(ctx, s * 0.08, s * 0.9, CF(0, baseH * 0.55, 0), ctx.Ribbon, "Ribbon")
	cyl(ctx, s * 0.05, s * 0.78, CF(0, baseH + s * 0.02, 0), GOLD, "Accent", Enum.Material.Metal)
	local gy = baseH + s * 0.4
	ellipsoid(ctx, V3(s * 0.7, s * 0.14, s * 0.7), CF(0, baseH + s * 0.06, 0), WHITE, "Fixed", Enum.Material.Snow)
	-- árbol dentro
	for i = 0, 2 do
		cyl(ctx, s * 0.12, s * (0.36 - i * 0.1), CF(0, baseH + s * 0.16 + i * s * 0.11, 0), ctx.Accent, "Accent")
	end
	neon(ctx, V3(s * 0.06, s * 0.06, s * 0.06), CF(0, baseH + s * 0.5, 0), GOLD, true)
	add(ctx, {
		Size = V3(s * 0.84, s * 0.84, s * 0.84),
		CF = CF(0, gy, 0),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(200, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.62,
		Reflectance = 0.2,
		Role = "Fixed",
		Name = "Glass",
	})
	return gy + s * 0.44
end

function Shapes.Drum(ctx: Ctx): number
	local s = ctx.S
	local h, d = s * 0.74, s * 0.96
	cyl(ctx, h, d, CF(0, h / 2, 0))
	cyl(ctx, s * 0.1, d * 1.05, CF(0, s * 0.05, 0), ctx.Accent, "Accent")
	cyl(ctx, s * 0.1, d * 1.05, CF(0, h - s * 0.05, 0), ctx.Accent, "Accent")
	cyl(ctx, s * 0.02, d * 0.96, CF(0, h + s * 0.005, 0), Color3.fromRGB(250, 240, 220), "Fixed")
	local n = 12
	local r = d / 2 + 0.01
	for i = 0, n - 1 do
		local phi = i * 2 * PI / n
		local tilt = if i % 2 == 0 then rad(32) else rad(-32)
		box(ctx, V3(s * 0.05, h * 0.68, s * 0.03), ANG(0, phi, 0) * CF(0, h / 2, -r) * ANG(0, 0, tilt), ctx.Ribbon, "Ribbon")
	end
	for side = -1, 1, 2 do
		local a = V3(side * s * 0.35, h + s * 0.05, -s * 0.15)
		local b = V3(-side * s * 0.05, h + s * 0.32, s * 0.25)
		segment(ctx, a, b, s * 0.06, Color3.fromRGB(230, 200, 150), "Fixed")
		ball(ctx, s * 0.11, CF(b), ctx.Accent, "Accent")
	end
	return h + s * 0.4
end

function Shapes.MusicBox(ctx: Ctx): number
	local s = ctx.S
	local w, h, d = s * 1.0, s * 0.5, s * 0.72
	box(ctx, V3(w, h, d), CF(0, h / 2, 0))
	for _, y in { s * 0.03, h - s * 0.03 } do
		box(ctx, V3(w + 0.04, s * 0.06, d + 0.04), CF(0, y, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	end
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			box(ctx, V3(s * 0.07, h, s * 0.07), CF(sx * w / 2, h / 2, sz * d / 2), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
		end
	end
	-- tapa abierta
	local hinge = CF(0, h, d / 2)
	local lid = hinge * ANG(rad(100), 0, 0) * CF(0, s * 0.03, -d / 2)
	box(ctx, V3(w, s * 0.06, d), lid, nil, "Body")
	add(ctx, {
		Size = V3(w * 0.8, s * 0.02, d * 0.75),
		CF = lid * CF(0, -s * 0.04, 0),
		Color = Color3.fromRGB(220, 240, 255),
		Material = Enum.Material.Glass,
		Reflectance = 0.5,
		Role = "Fixed",
	})
	-- bailarina que gira
	local hub = spinHub(ctx, CF(0, h, 0), 1.6, V3(0, 1, 0))
	add(ctx, { Size = V3(s * 0.3, s * 0.04, s * 0.3), CF = CF(0, s * 0.14, 0) * ANG(0, 0, PI / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 160, 200), Role = "Accent", Hub = hub })
	add(ctx, { Size = V3(s * 0.12, s * 0.24, s * 0.12), CF = CF(0, s * 0.2, 0), Mesh = true, Color = ctx.Accent, Role = "Accent", Hub = hub })
	add(ctx, { Size = V3(s * 0.1, s * 0.1, s * 0.1), CF = CF(0, s * 0.37, 0), Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 220, 190), Role = "Fixed", Hub = hub })
	add(ctx, { Size = V3(s * 0.34, s * 0.03, s * 0.03), CF = CF(0, s * 0.27, 0), Color = Color3.fromRGB(255, 220, 190), Role = "Fixed", Hub = hub })
	cyl(ctx, s * 0.04, s * 0.08, CF(0, h + s * 0.02, 0), GOLD, "Accent", Enum.Material.Metal)
	-- manivela
	segment(ctx, V3(w / 2, h * 0.5, 0), V3(w / 2 + s * 0.14, h * 0.5, 0), s * 0.05, GOLD, "Accent")
	segment(ctx, V3(w / 2 + s * 0.14, h * 0.5, 0), V3(w / 2 + s * 0.14, h * 0.5 + s * 0.16, 0), s * 0.05, GOLD, "Accent")
	ball(ctx, s * 0.08, CF(w / 2 + s * 0.14, h * 0.5 + s * 0.18, 0), ctx.Accent, "Accent")
	return h + d * 0.95
end

function Shapes.Tree(ctx: Ctx): number
	local s = ctx.S
	cyl(ctx, s * 0.24, s * 0.4, CF(0, s * 0.12, 0), BERRY, "Accent")
	cyl(ctx, s * 0.06, s * 0.42, CF(0, s * 0.2, 0), GOLD, "Ribbon")
	cyl(ctx, s * 0.14, s * 0.14, CF(0, s * 0.3, 0), Color3.fromRGB(110, 70, 40), "Fixed", Enum.Material.Wood)
	local y = s * 0.34
	local tiers = { 0.92, 0.74, 0.56, 0.38 }
	local lights = { GOLD, ctx.Accent, Color3.fromRGB(80, 170, 255), WHITE }
	for i, f in tiers do
		local th = s * 0.26
		cyl(ctx, th * 0.5, s * f, CF(0, y + th * 0.25, 0))
		cyl(ctx, th * 0.5, s * f * 0.78, CF(0, y + th * 0.72, 0))
		local count = 6 - (i - 1)
		for k = 0, count - 1 do
			local a = k * 2 * PI / count + i * 0.6
			neon(ctx, V3(s * 0.07, s * 0.07, s * 0.07), CF(math.cos(a) * s * f * 0.49, y + th * 0.3, math.sin(a) * s * f * 0.49), lights[(k + i) % #lights + 1], true)
		end
		y += th * 0.8
	end
	star(ctx, CF(0, y + s * 0.16, 0), s * 0.17, s * 0.05, GOLD)
	return y + s * 0.36
end

function Shapes.AuroraBox(ctx: Ctx): number
	local s = ctx.S
	local h = s * 0.84
	box(ctx, V3(s, h, s), CF(0, h / 2, 0))
	box(ctx, V3(s * 1.05, s * 0.15, s * 1.05), CF(0, h - s * 0.05, 0))
	local rw = s * 0.18
	add(ctx, { Size = V3(s * 1.07, h + 0.05, rw), CF = CF(0, h / 2, 0), Color = ctx.Ribbon, Material = Enum.Material.Neon, Role = "Ribbon" })
	add(ctx, { Size = V3(rw, h + 0.05, s * 1.07), CF = CF(0, h / 2, 0), Color = ctx.Ribbon, Material = Enum.Material.Neon, Role = "Ribbon" })
	bow(ctx, h + s * 0.04, s * 0.6)
	-- espiral de aurora
	local hub = spinHub(ctx, CF(0, h * 0.55, 0), 0.9, V3(0, 1, 0))
	local n = 14
	for i = 0, n - 1 do
		local a = i * 2 * PI / n
		local t = i / (n - 1)
		local color = ctx.Ribbon:Lerp(ctx.Accent, t)
		add(ctx, {
			Size = V3(s * 0.1, s * 0.22, s * 0.04),
			CF = CF(math.cos(a) * s * 0.85, math.sin(a * 2) * s * 0.22, math.sin(a) * s * 0.85) * ANG(0, -a, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			Role = "Glow",
			Hub = hub,
		})
	end
	return h + s * 0.4
end

function Shapes.Star(ctx: Ctx): number
	local s = ctx.S
	cyl(ctx, s * 0.12, s * 0.6, CF(0, s * 0.06, 0), Color3.fromRGB(70, 40, 30), "Fixed", Enum.Material.Wood)
	cyl(ctx, s * 0.04, s * 0.64, CF(0, s * 0.12, 0), GOLD, "Ribbon", Enum.Material.Metal)
	segment(ctx, V3(0, s * 0.1, 0), V3(0, s * 0.42, 0), s * 0.07, GOLD, "Ribbon")
	local hub = spinHub(ctx, CF(0, s * 0.82, 0), 0.8, V3(0, 1, 0))
	star(ctx, CF(), s * 0.5, s * 0.16, ctx.Body, Enum.Material.Neon, hub)
	star(ctx, CF(0, 0, -s * 0.09), s * 0.3, s * 0.03, ctx.Ribbon, Enum.Material.Neon, hub)
	return s * 1.36
end

function Shapes.Chest(ctx: Ctx): number
	local s = ctx.S
	local w, h, d = s * 1.0, s * 0.52, s * 0.66
	box(ctx, V3(w, h, d), CF(0, h / 2, 0), nil, "Body", Enum.Material.Wood)
	add(ctx, { Size = V3(w, d, d), CF = CF(0, h, 0), Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood, Role = "Body" })
	for _, x in { -w * 0.32, w * 0.32 } do
		box(ctx, V3(s * 0.08, h + 0.02, d + 0.04), CF(x, h / 2, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
		add(ctx, { Size = V3(s * 0.08, d + 0.04, d + 0.04), CF = CF(x, h, 0), Shape = Enum.PartType.Cylinder, Color = ctx.Ribbon, Material = Enum.Material.Metal, Role = "Ribbon" })
	end
	neon(ctx, V3(w * 0.98, s * 0.03, s * 0.02), CF(0, h, -d / 2 - 0.005), ctx.Accent)
	box(ctx, V3(s * 0.2, s * 0.22, s * 0.06), CF(0, h - s * 0.04, -d / 2 - 0.02), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	box(ctx, V3(s * 0.04, s * 0.08, s * 0.02), CF(0, h - s * 0.06, -d / 2 - 0.06), DARK, "Fixed")
	-- cristales de hielo encima
	for i, offset in { V3(-0.3, 0, 0.05), V3(0.05, 0, -0.08), V3(0.32, 0, 0.1) } do
		local tall = s * (0.32 + (i % 2) * 0.12)
		add(ctx, {
			Size = V3(s * 0.12, tall, s * 0.12),
			CF = CF(offset.X * s, h + d * 0.42 + tall / 2 - s * 0.05, offset.Z * s) * ANG(rad(8 * i), rad(45), rad(-10 + i * 7)),
			Color = ctx.Accent,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			Reflectance = 0.3,
			Role = "Accent",
		})
	end
	return h + d * 0.5 + s * 0.42
end

function Shapes.Wreath(ctx: Ctx): number
	local s = ctx.S
	-- caballete
	segment(ctx, V3(-s * 0.32, 0, s * 0.12), V3(0, s * 0.9, s * 0.18), s * 0.06, Color3.fromRGB(110, 70, 40), "Fixed")
	segment(ctx, V3(s * 0.32, 0, s * 0.12), V3(0, s * 0.9, s * 0.18), s * 0.06, Color3.fromRGB(110, 70, 40), "Fixed")
	segment(ctx, V3(0, 0, s * 0.45), V3(0, s * 0.85, s * 0.2), s * 0.06, Color3.fromRGB(110, 70, 40), "Fixed")
	local center = V3(0, s * 0.62, 0)
	local r = s * 0.38
	local n = 16
	for i = 0, n - 1 do
		local a = i * 2 * PI / n
		local p = center + V3(math.cos(a) * r, math.sin(a) * r, 0)
		ball(ctx, s * 0.26, CF(p), if i % 2 == 0 then ctx.Body else ctx.Body:Lerp(Color3.new(0, 0, 0), 0.25), "Body", Enum.Material.Grass)
		if i % 3 == 0 then
			ball(ctx, s * 0.09, CF(p + V3(0, 0, -s * 0.13)), ctx.Ribbon, "Ribbon")
		elseif i % 3 == 1 then
			neon(ctx, V3(s * 0.06, s * 0.06, s * 0.06), CF(p + V3(0, 0, -s * 0.14)), ctx.Accent, true)
		end
	end
	bow(ctx, 0, s * 0.42, ctx.Ribbon, CF(center + V3(0, -r, -s * 0.12)) * ANG(rad(-90), 0, 0))
	return s * 1.06
end

function Shapes.Sleigh(ctx: Ctx): number
	local s = ctx.S
	local runner = GOLD
	for _, x in { -s * 0.32, s * 0.32 } do
		segment(ctx, V3(x, s * 0.04, s * 0.5), V3(x, s * 0.04, -s * 0.45), s * 0.06, runner, "Ribbon")
		segment(ctx, V3(x, s * 0.04, -s * 0.45), V3(x, s * 0.16, -s * 0.62), s * 0.06, runner, "Ribbon")
		segment(ctx, V3(x, s * 0.16, -s * 0.62), V3(x, s * 0.32, -s * 0.6), s * 0.06, runner, "Ribbon")
		for _, z in { -s * 0.3, 0, s * 0.3 } do
			segment(ctx, V3(x, s * 0.04, z), V3(x, s * 0.2, z), s * 0.05, runner, "Ribbon")
		end
	end
	box(ctx, V3(s * 0.74, s * 0.34, s * 0.86), CF(0, s * 0.37, 0))
	wedge(ctx, V3(s * 0.74, s * 0.34, s * 0.3), CF(0, s * 0.37, -s * 0.58), nil, "Body")
	box(ctx, V3(s * 0.74, s * 0.42, s * 0.12), CF(0, s * 0.74, s * 0.38), nil, "Body")
	for _, x in { -s * 0.38, s * 0.38 } do
		box(ctx, V3(s * 0.04, s * 0.06, s * 0.9), CF(x, s * 0.55, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	end
	box(ctx, V3(s * 0.78, s * 0.06, s * 0.14), CF(0, s * 0.96, s * 0.38), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	box(ctx, V3(s * 0.66, s * 0.08, s * 0.4), CF(0, s * 0.56, s * 0.12), ctx.Accent, "Accent", Enum.Material.Fabric)
	-- regalos en el trineo
	box(ctx, V3(s * 0.26, s * 0.26, s * 0.26), CF(-s * 0.14, s * 0.72, -s * 0.15) * ANG(0, rad(15), 0), Color3.fromRGB(60, 170, 90), "Accent")
	ribbonCross(ctx, s * 0.26, s * 0.26, s * 0.26, CF(-s * 0.14, s * 0.72, -s * 0.15) * ANG(0, rad(15), 0), GOLD, 0.25)
	box(ctx, V3(s * 0.2, s * 0.32, s * 0.2), CF(s * 0.16, s * 0.75, -s * 0.1) * ANG(0, rad(-20), 0), Color3.fromRGB(60, 120, 230), "Accent")
	ribbonCross(ctx, s * 0.2, s * 0.32, s * 0.2, CF(s * 0.16, s * 0.75, -s * 0.1) * ANG(0, rad(-20), 0), WHITE, 0.25)
	return s * 1.05
end

function Shapes.Crystal(ctx: Ctx): number
	local s = ctx.S
	ellipsoid(ctx, V3(s * 1.0, s * 0.3, s * 0.9), CF(0, s * 0.1, 0), Color3.fromRGB(230, 245, 255), "Fixed", Enum.Material.Snow)
	local crystals = {
		{ V3(0, 0, 0), 1.05, 0, 0 },
		{ V3(-0.26, 0, 0.08), 0.7, -22, 10 },
		{ V3(0.25, 0, -0.06), 0.78, 20, -8 },
		{ V3(0.05, 0, 0.26), 0.55, 8, 24 },
		{ V3(-0.08, 0, -0.26), 0.5, -10, -22 },
	}
	local top = 0
	for i, c in crystals do
		local pos: Vector3 = c[1]
		local hgt: number = c[2] * s
		local w = s * (if i == 1 then 0.26 else 0.18)
		local base = CF(pos.X * s, s * 0.12, pos.Z * s) * ANG(rad(c[4]), rad(i * 37), rad(c[3]))
		add(ctx, { Size = V3(w, hgt, w), CF = base * CF(0, hgt / 2, 0), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.35, Role = "Body" })
		add(ctx, { Size = V3(w * 0.72, w * 0.72, w * 0.72), CF = base * CF(0, hgt, 0) * ANG(rad(45), 0, rad(45)), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.35, Role = "Body" })
		top = math.max(top, s * 0.12 + hgt)
	end
	neon(ctx, V3(s * 0.22, s * 0.5, s * 0.22), CF(0, s * 0.45, 0), ctx.Accent)
	return top + s * 0.25
end

function Shapes.Bell(ctx: Ctx): number
	local s = ctx.S
	box(ctx, V3(s * 0.7, s * 0.1, s * 0.5), CF(0, s * 0.05, 0), Color3.fromRGB(90, 55, 30), "Fixed", Enum.Material.Wood)
	ball(ctx, s * 0.2, CF(0, s * 0.2, 0), Color3.fromRGB(150, 110, 30), "Fixed", Enum.Material.Metal)
	cyl(ctx, s * 0.08, s * 1.04, CF(0, s * 0.3, 0), ctx.Body, "Body", Enum.Material.Metal)
	local diameters = { 0.98, 0.88, 0.78, 0.68, 0.6, 0.54 }
	local y = s * 0.34
	for _, d in diameters do
		cyl(ctx, s * 0.12, s * d, CF(0, y + s * 0.06, 0), ctx.Body, "Body", Enum.Material.Metal)
		y += s * 0.11
	end
	ellipsoid(ctx, V3(s * 0.56, s * 0.4, s * 0.56), CF(0, y, 0), ctx.Body, "Body", Enum.Material.Metal)
	cyl(ctx, s * 0.05, s * 0.94, CF(0, s * 0.5, 0), ctx.Ribbon, "Ribbon")
	disc(ctx, s * 0.06, s * 0.2, CF(0, y + s * 0.26, 0), ctx.Body, "Body", Enum.Material.Metal)
	bow(ctx, y + s * 0.1, s * 0.48, ctx.Ribbon, CF(0, 0, -s * 0.22))
	holly(ctx, CF(s * 0.2, y + s * 0.06, -s * 0.18), s * 0.3)
	return y + s * 0.4
end

function Shapes.Lantern(ctx: Ctx): number
	local s = ctx.S
	local metal = ctx.Body
	cyl(ctx, s * 0.12, s * 0.66, CF(0, s * 0.06, 0), metal, "Body", Enum.Material.Metal)
	cyl(ctx, s * 0.05, s * 0.7, CF(0, s * 0.13, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	local glassH = s * 0.62
	local gy = s * 0.15 + glassH / 2
	add(ctx, {
		Size = V3(s * 0.44, glassH, s * 0.44),
		CF = CF(0, gy, 0),
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Role = "Fixed",
	})
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			box(ctx, V3(s * 0.06, glassH, s * 0.06), CF(sx * s * 0.23, gy, sz * s * 0.23), metal, "Body", Enum.Material.Metal)
		end
	end
	local flame = add(ctx, { Size = V3(s * 0.16, s * 0.28, s * 0.16), CF = CF(0, gy - s * 0.04, 0), Color = ctx.Accent, Material = Enum.Material.Neon, Mesh = true, Role = "Glow", Name = "Flame" })
	local fire = Instance.new("Fire")
	fire.Size = s * 0.9
	fire.Heat = 2
	fire.Color = ctx.Accent
	fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
	fire.Parent = flame
	local top = s * 0.15 + glassH
	cyl(ctx, s * 0.08, s * 0.62, CF(0, top + s * 0.04, 0), metal, "Body", Enum.Material.Metal)
	ellipsoid(ctx, V3(s * 0.5, s * 0.32, s * 0.5), CF(0, top + s * 0.12, 0), metal, "Body", Enum.Material.Metal)
	cyl(ctx, s * 0.04, s * 0.54, CF(0, top + s * 0.1, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	disc(ctx, s * 0.05, s * 0.24, CF(0, top + s * 0.38, 0), ctx.Ribbon, "Ribbon", Enum.Material.Metal)
	return top + s * 0.5
end

function Shapes.Galaxy(ctx: Ctx): number
	local s = ctx.S
	local h = s * 0.84
	box(ctx, V3(s, h, s), CF(0, h / 2, 0))
	box(ctx, V3(s * 1.05, s * 0.15, s * 1.05), CF(0, h - s * 0.05, 0))
	local rw = s * 0.16
	add(ctx, { Size = V3(s * 1.07, h + 0.05, rw), CF = CF(0, h / 2, 0), Color = ctx.Ribbon, Material = Enum.Material.Neon, Role = "Ribbon" })
	add(ctx, { Size = V3(rw, h + 0.05, s * 1.07), CF = CF(0, h / 2, 0), Color = ctx.Ribbon, Material = Enum.Material.Neon, Role = "Ribbon" })
	for i = 0, 9 do
		local a = i * 2.4
		neon(ctx, V3(s * 0.04, s * 0.04, s * 0.04), CF(math.cos(a) * s * 0.3, h * (0.2 + (i % 4) * 0.18), -s * 0.505), WHITE, true)
	end
	bow(ctx, h + s * 0.04, s * 0.55, ctx.Accent)
	-- anillo planetario
	local ringHub = spinHub(ctx, CF(0, h * 0.55, 0) * ANG(rad(18), 0, rad(8)), 0.7, V3(0, 1, 0))
	local n = 22
	for i = 0, n - 1 do
		local a = i * 2 * PI / n
		add(ctx, {
			Size = V3(s * 0.09, s * 0.09, s * 0.09),
			CF = CF(math.cos(a) * s * 0.92, 0, math.sin(a) * s * 0.92),
			Color = ctx.Accent:Lerp(ctx.Ribbon, (i % 5) / 5),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			Role = "Glow",
			Hub = ringHub,
		})
	end
	-- planetas
	local planets = { { 0.6, 0.18, 1.3, Color3.fromRGB(255, 140, 60) }, { 0.78, 0.13, -0.9, Color3.fromRGB(90, 200, 255) } }
	for i, p in planets do
		local hub = spinHub(ctx, CF(0, h * (0.35 + i * 0.25), 0), p[3], V3(0, 1, 0))
		add(ctx, { Size = V3(s * p[2], s * p[2], s * p[2]) * 1.0, CF = CF(s * p[1] * 1.1, 0, 0), Shape = Enum.PartType.Ball, Color = p[4], Material = Enum.Material.Neon, Role = "Glow", Hub = hub })
	end
	return h + s * 0.4
end

function Shapes.Royal(ctx: Ctx): number
	local s = ctx.S
	ellipsoid(ctx, V3(s * 1.3, s * 0.24, s * 1.3), CF(0, s * 0.1, 0), WHITE, "Fixed", Enum.Material.Fabric)
	local h = s * 0.9
	local base = s * 0.16
	box(ctx, V3(s, h, s), CF(0, base + h / 2, 0), nil, "Body", Enum.Material.Foil)
	box(ctx, V3(s * 1.06, s * 0.16, s * 1.06), CF(0, base + h - s * 0.05, 0), nil, "Body", Enum.Material.Foil)
	ribbonCross(ctx, s * 1.06, h + 0.04, s * 1.06, CF(0, base + h / 2, 0), nil, 0.22)
	-- corona
	local top = base + h + s * 0.03
	cyl(ctx, s * 0.14, s * 0.62, CF(0, top + s * 0.07, 0), GOLD, "Accent", Enum.Material.Metal)
	local gems = { Color3.fromRGB(255, 60, 90), Color3.fromRGB(80, 200, 255), Color3.fromRGB(90, 255, 140), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 230, 90) }
	for i = 0, 4 do
		local a = i * 2 * PI / 5
		local p = V3(math.cos(a) * s * 0.29, top + s * 0.2, math.sin(a) * s * 0.29)
		wedge(ctx, V3(s * 0.06, s * 0.22, s * 0.16), CF(p) * ANG(0, -a + PI / 2, 0), GOLD, "Accent", Enum.Material.Metal)
		neon(ctx, V3(s * 0.07, s * 0.07, s * 0.07), CF(math.cos(a) * s * 0.315, top + s * 0.08, math.sin(a) * s * 0.315), gems[i + 1], true)
		ball(ctx, s * 0.06, CF(math.cos(a) * s * 0.29, top + s * 0.33, math.sin(a) * s * 0.29), WHITE, "Accent")
	end
	ball(ctx, s * 0.2, CF(0, top + s * 0.16, 0), Color3.fromRGB(200, 20, 40), "Fixed", Enum.Material.Fabric)
	-- pilar de luz
	add(ctx, {
		Size = V3(s * 1.4, s * 0.36, s * 0.36),
		CF = CF(0, top + s * 0.9, 0) * ANG(0, 0, PI / 2),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Neon,
		Transparency = 0.7,
		Role = "Glow",
	})
	return top + s * 0.45
end

function Shapes.Core(ctx: Ctx): number
	local s = ctx.S
	cyl(ctx, s * 0.14, s * 0.7, CF(0, s * 0.07, 0), DARK, "Fixed", Enum.Material.Metal)
	neon(ctx, V3(s * 0.08, s * 0.74, s * 0.74), CF(0, s * 0.15, 0) * ANG(0, 0, PI / 2), ctx.Ribbon)
	local cy = s * 0.75
	add(ctx, { Size = V3(s * 0.5, s * 0.5, s * 0.5), CF = CF(0, cy, 0), Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Role = "Body" })
	add(ctx, {
		Size = V3(s * 0.78, s * 0.78, s * 0.78),
		CF = CF(0, cy, 0),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(255, 240, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		Reflectance = 0.3,
		Role = "Fixed",
	})
	local rings = {
		{ ANG(0, 0, 0), 0.62, 1.4, ctx.Ribbon },
		{ ANG(rad(70), 0, rad(20)), 0.7, -1.1, ctx.Accent },
		{ ANG(rad(-60), rad(40), 0), 0.78, 0.8, WHITE },
	}
	for _, ring in rings do
		local hub = spinHub(ctx, CF(0, cy, 0) * ring[1], ring[3], V3(0, 1, 0))
		local n = 14
		for i = 0, n - 1 do
			local a = i * 2 * PI / n
			add(ctx, {
				Size = V3(s * 0.08, s * 0.08, s * 0.08),
				CF = CF(math.cos(a) * s * ring[2], 0, math.sin(a) * s * ring[2]),
				Shape = Enum.PartType.Ball,
				Color = ring[4],
				Material = Enum.Material.Neon,
				Role = "Glow",
				Hub = hub,
			})
		end
	end
	return cy + s * 0.8
end

function Shapes.Infinite(ctx: Ctx): number
	local s = ctx.S
	cyl(ctx, s * 0.1, s * 1.0, CF(0, s * 0.05, 0), DARK, "Fixed", Enum.Material.Metal)
	local y = s * 0.12
	local sizes = { 0.56, 0.43, 0.32, 0.23 }
	local colors = { ctx.Body, ctx.Ribbon, ctx.Accent, GOLD }
	for i, f in sizes do
		local w = s * f
		local gap = s * 0.06
		local hub = spinHub(ctx, CF(0, y + w / 2, 0), if i % 2 == 0 then -1.2 else 1.2, V3(0, 1, 0))
		add(ctx, { Size = V3(w, w, w), CF = CF(), Color = colors[i], Role = "Body", Hub = hub, Reflectance = 0.1 })
		local rw = w * 0.2
		add(ctx, { Size = V3(w + 0.04, w + 0.04, rw), CF = CF(), Color = WHITE, Material = Enum.Material.Neon, Role = "Ribbon", Hub = hub })
		add(ctx, { Size = V3(rw, w + 0.04, w + 0.04), CF = CF(), Color = WHITE, Material = Enum.Material.Neon, Role = "Ribbon", Hub = hub })
		y += w + gap
	end
	return y + s * 0.1
end

PresentBuilder.Shapes = Shapes

-- Mutaciones y efectos --------------------------------------------------------------------------------

local function applyMutation(ctx: Ctx, mutationId: string?)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	local candyIndex = 0
	for _, part in ctx.Parts do
		local role = ctx.Roles[part]
		if role == "Body" or role == "Ribbon" then
			if mutation.Rainbow then
				part:AddTag("Rainbow")
				part:SetAttribute("HueOffset", (#part.Name * 0.137 + (if role == "Ribbon" then 0.5 else 0)) % 1)
				if part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass then
					part.Material = Enum.Material.SmoothPlastic
				end
			elseif mutation.Candy then
				candyIndex += 1
				local useBody = (candyIndex % 2 == 0) == (role == "Body")
				part.Color = if useBody then (mutation.Body :: Color3) else (mutation.Ribbon :: Color3)
				if part.Material ~= Enum.Material.Neon then
					part.Material = Enum.Material.SmoothPlastic
				end
			else
				local color = if role == "Body" then mutation.Body else mutation.Ribbon
				if color then
					part.Color = color
				end
				if part.Material ~= Enum.Material.Neon and mutation.Material then
					part.Material = mutation.Material
				end
				if mutation.Reflectance then
					part.Reflectance = mutation.Reflectance
				end
				if mutation.Transparency and part.Transparency < mutation.Transparency then
					part.Transparency = mutation.Transparency
				end
			end
		end
	end
end

local function sparkleEmitter(color: Color3, rate: number, size: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.6, 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rotation = NumberRange.new(0, 360)
	return emitter
end

export type BuildOptions = {
	Scale: number?,
	NoEffects: boolean?, -- sin luces ni partículas (vistas previas de la interfaz)
}

-- Construye el regalo. Devuelve el Model (con Root en el origen) y su altura.
function PresentBuilder.Build(presentId: string, mutationId: string?, options: BuildOptions?): Model
	local info = Presents.Get(presentId)
	assert(info, "Regalo desconocido: " .. tostring(presentId))
	local rarity = Rarities.Get(info.Rarity)
	local opts: BuildOptions = options or {}

	local model = Instance.new("Model")
	model.Name = info.Id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V3(1, 1, 1)
	root.CFrame = CF()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Ctx = {
		Model = model,
		Root = root,
		S = info.Size * rarity.Scale * (opts.Scale or 1),
		Body = info.Body,
		Ribbon = info.Ribbon,
		Accent = info.Accent,
		Parts = {},
		Roles = {},
		Count = 0,
	}

	local shape = Shapes[info.Shape] or Shapes.Box
	local height = shape(ctx)
	root.Size = V3(ctx.S * 0.5, 0.2, ctx.S * 0.5)

	applyMutation(ctx, mutationId)

	if rarity.Rainbow then
		local halo = add(ctx, {
			Size = V3(0.08, ctx.S * 1.5, ctx.S * 1.5),
			CF = CF(0, 0.05, 0) * ANG(0, 0, PI / 2),
			Shape = Enum.PartType.Cylinder,
			Color = WHITE,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Role = "Glow",
			Name = "Halo",
		})
		halo:AddTag("Rainbow")
		halo:SetAttribute("HueOffset", 0)
	end

	local mid = Instance.new("Attachment")
	mid.Name = "Mid"
	mid.Position = V3(0, height / 2, 0)
	mid.Parent = root

	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Position = V3(0, height + 0.3, 0)
	top.Parent = root

	model:SetAttribute("PresentId", info.Id)
	model:SetAttribute("Mutation", mutationId or "")
	model:SetAttribute("Height", height)

	if not opts.NoEffects then
		if rarity.Light then
			local light = Instance.new("PointLight")
			light.Color = rarity.Color
			light.Range = 6 + rarity.Index * 1.5
			light.Brightness = 0.6 + rarity.Index * 0.2
			light.Shadows = false
			light.Parent = mid
		end
		if rarity.Sparkles then
			local emitter = sparkleEmitter(rarity.Color, 3 + rarity.Index, 0.22 + rarity.Index * 0.04)
			emitter.Parent = mid
			if rarity.Rainbow then
				emitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 80)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
					ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
				})
			end
		end
		local mutation = Mutations.Get(mutationId)
		if mutation then
			local emitter = sparkleEmitter(mutation.Sparkle, 5, 0.3)
			emitter.Name = "MutationSparkles"
			emitter.Parent = mid
			if mutation.Id == "Frost" then
				emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
				emitter.Size = NumberSequence.new(0.25, 0)
				emitter.Acceleration = V3(0, -2, 0)
			end
		end
	end

	return model
end

-- Altura del regalo construido
function PresentBuilder.GetHeight(model: Model): number
	return (model:GetAttribute("Height") :: number?) or 2
end

-- Mueve el modelo para que su base quede en cf (las piezas siguen al Root por los welds en el mundo,
-- pero fuera de él, p. ej. antes de emparentarlo, hay que mover cada pieza).
function PresentBuilder.PlaceAt(model: Model, cf: CFrame)
	local root = model.PrimaryPart :: BasePart
	local inverse = root.CFrame:Inverse()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.CFrame = cf * (inverse * descendant.CFrame)
		end
	end
	root.CFrame = cf
end

return PresentBuilder
