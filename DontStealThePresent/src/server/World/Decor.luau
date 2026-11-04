-- Decoración navideña construida con piezas: pinos nevados, muñecos de nieve, farolas de caramelo,
-- montones de regalos, elfos, renos...

local Build = require(script.Parent.Build)
local CFrameUtil = require(game:GetService("ReplicatedStorage").Shared.Util.CFrameUtil)

local Decor = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local SNOW = rgb(244, 248, 255)
local PINE = rgb(28, 98, 62)
local PINE_DARK = rgb(20, 74, 48)
local BARK = rgb(96, 62, 38)
local GOLD = rgb(255, 200, 60)

-- Pino nevado por pisos. scale ~1 = 18 studs de alto.
function Decor.PineTree(parent: Instance, base: CFrame, scale: number, withLights: boolean?, seed: number?): Model
	local model = Build.Model(parent, "PineTree")
	local s = scale
	Build.Cylinder(model, 3 * s, 1.6 * s, base * CF(0, 1.5 * s, 0), { Color = BARK, Material = Enum.Material.Wood })
	local tiers = 4
	local y = 2.4 * s
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local d = (11 - t * 7) * s
		local h = 3.6 * s
		local color = if i % 2 == 0 then PINE else PINE_DARK
		Build.Cylinder(model, h * 0.55, d, base * CF(0, y + h * 0.27, 0), { Color = color, Material = Enum.Material.Grass })
		Build.Cylinder(model, h * 0.5, d * 0.72, base * CF(0, y + h * 0.72, 0), { Color = color, Material = Enum.Material.Grass })
		Build.Cylinder(model, 0.5 * s, d * 0.8, base * CF(0, y + h * 0.56, 0), {
			Color = SNOW,
			Material = Enum.Material.Snow,
			CanCollide = false,
		})
		if withLights then
			local count = 7 - i
			for k = 0, count - 1 do
				local a = k * 2 * math.pi / count + i * 0.7 + (seed or 0)
				local r = d * 0.5
				Build.Ball(model, 0.55 * s, base * CF(math.cos(a) * r, y + h * 0.3, math.sin(a) * r), {
					Color = Build.BulbColors[(k + i) % #Build.BulbColors + 1],
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
					Tag = "TwinkleBulb",
				})
			end
		end
		y += h * 0.85
	end
	Build.Cylinder(model, 0.9 * s, 1.6 * s, base * CF(0, y + 0.3 * s, 0), { Color = SNOW, Material = Enum.Material.Snow, CanCollide = false })
	if withLights then
		Build.Ball(model, 1.1 * s, base * CF(0, y + 1 * s, 0), {
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
	return model
end

-- Muñeco de nieve con bufanda y sombrero
function Decor.Snowman(parent: Instance, base: CFrame, scale: number?, scarf: Color3?): Model
	local s = scale or 1
	local model = Build.Model(parent, "Snowman")
	Build.Ball(model, 5 * s, base * CF(0, 2.3 * s, 0), { Color = SNOW, Material = Enum.Material.Snow })
	Build.Ball(model, 3.8 * s, base * CF(0, 5.4 * s, 0), { Color = SNOW, Material = Enum.Material.Snow })
	Build.Ball(model, 2.8 * s, base * CF(0, 7.9 * s, 0), { Color = SNOW, Material = Enum.Material.Snow })
	-- ojos, botones y nariz
	for side = -1, 1, 2 do
		Build.Ball(model, 0.35 * s, base * CF(side * 0.45 * s, 8.25 * s, -1.25 * s), { Color = rgb(20, 20, 24), CanCollide = false })
	end
	for i = 0, 2 do
		Build.Ball(model, 0.4 * s, base * CF(0, (4.6 + i * 0.75) * s, -1.85 * s + i * 0.1 * s), { Color = rgb(20, 20, 24), CanCollide = false })
	end
	Build.Deco(model, {
		Class = "WedgePart",
		Size = V3(0.4 * s, 0.4 * s, 1.4 * s),
		CFrame = base * CF(0, 7.85 * s, -1.9 * s),
		Color = rgb(255, 130, 30),
	})
	-- bufanda
	local scarfColor = scarf or rgb(220, 30, 45)
	Build.Cylinder(model, 0.7 * s, 3.3 * s, base * CF(0, 6.9 * s, 0), { Color = scarfColor, Material = Enum.Material.Fabric, CanCollide = false })
	Build.Deco(model, {
		Size = V3(0.8 * s, 2 * s, 0.3 * s),
		CFrame = base * CF(0.8 * s, 6 * s, -1.55 * s) * ANG(0.2, 0, 0.15),
		Color = scarfColor,
		Material = Enum.Material.Fabric,
	})
	-- sombrero
	Build.Cylinder(model, 0.3 * s, 3 * s, base * CF(0, 9.2 * s, 0), { Color = rgb(24, 24, 30), CanCollide = false })
	Build.Cylinder(model, 1.8 * s, 2 * s, base * CF(0, 10.2 * s, 0), { Color = rgb(24, 24, 30), CanCollide = false })
	Build.Cylinder(model, 0.35 * s, 2.05 * s, base * CF(0, 9.55 * s, 0), { Color = scarfColor, CanCollide = false })
	-- brazos de rama
	for side = -1, 1, 2 do
		Build.Deco(model, {
			Size = V3(3 * s, 0.25 * s, 0.25 * s),
			CFrame = base * CF(side * 2.9 * s, 5.9 * s, 0) * ANG(0, 0, side * 0.5),
			Color = BARK,
			Material = Enum.Material.Wood,
		})
	end
	return model
end

-- Farola de bastón de caramelo con farol cálido
function Decor.CandyLamp(parent: Instance, base: CFrame, height: number?): Model
	local h = height or 12
	local model = Build.Model(parent, "CandyLamp")
	Build.Cylinder(model, 0.6, 2.2, base * CF(0, 0.3, 0), { Color = rgb(40, 40, 48), Material = Enum.Material.Metal })
	Build.CandyPole(model, base * CF(0, 0.6, 0), h, 0.8, 1.2)
	-- gancho del bastón
	local top = h + 0.6
	local r = 1.4
	local steps = 6
	local prev = V3(0, top, 0)
	for i = 1, steps do
		local theta = math.pi - math.pi * (i / steps)
		local p = V3(r + math.cos(theta) * r, top + math.sin(theta) * r, 0)
		local a = base * prev
		local b = base * p
		Build.Deco(model, {
			Size = V3((b - a).Magnitude + 0.3, 0.8, 0.8),
			CFrame = CFrameUtil.LookAt((a + b) / 2, b) * ANG(0, math.pi / 2, 0),
			Shape = Enum.PartType.Cylinder,
			Color = if i % 2 == 0 then rgb(232, 30, 46) else rgb(255, 255, 255),
		})
		prev = p
	end
	local lampPos = base * CF(2 * r, top - 1.4, 0)
	Build.Deco(model, { Size = V3(1.6, 0.3, 1.6), CFrame = lampPos * CF(0, 0.9, 0), Color = rgb(40, 40, 48), Material = Enum.Material.Metal })
	local lamp = Build.Ball(model, 1.4, lampPos, {
		Color = rgb(255, 214, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Name = "Lamp",
	})
	Build.Light(lamp, rgb(255, 196, 120), 22, 1.6, false)
	return model
end

-- Montón de regalos decorativos (no se pueden comprar)
local GIFT_COLORS = { rgb(220, 30, 45), rgb(40, 160, 80), rgb(60, 120, 230), rgb(255, 200, 60), rgb(180, 80, 220), rgb(255, 255, 255) }

function Decor.Gift(parent: Instance, cf: CFrame, size: Vector3, body: Color3, ribbon: Color3): Model
	local model = Build.Model(parent, "DecoGift")
	Build.Part(model, { Size = size, CFrame = cf, Color = body })
	local rw = math.min(size.X, size.Z) * 0.18
	Build.Deco(model, { Size = V3(size.X + 0.05, size.Y + 0.05, rw), CFrame = cf, Color = ribbon })
	Build.Deco(model, { Size = V3(rw, size.Y + 0.05, size.Z + 0.05), CFrame = cf, Color = ribbon })
	local top = cf * CF(0, size.Y / 2, 0)
	local loop = V3(size.X * 0.32, size.X * 0.22, size.X * 0.12)
	for side = -1, 1, 2 do
		local lobe = Build.Deco(model, { Size = loop, CFrame = top * CF(side * size.X * 0.14, size.X * 0.08, 0) * ANG(0, 0, side * 0.5), Color = ribbon })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = lobe
	end
	return model
end

function Decor.GiftPile(parent: Instance, base: CFrame, rng: any, count: number?): Model
	local model = Build.Model(parent, "GiftPile")
	local n = count or 5
	for i = 1, n do
		local sx = rng:Range(1.8, 3.6)
		local sy = rng:Range(1.6, 3.4)
		local sz = rng:Range(1.8, 3.4)
		local a = rng:Range(0, math.pi * 2)
		local r = rng:Range(0, 3.2)
		local body = GIFT_COLORS[rng:Int(1, #GIFT_COLORS)]
		local ribbon = GIFT_COLORS[rng:Int(1, #GIFT_COLORS)]
		if ribbon == body then
			ribbon = GOLD
		end
		local y = sy / 2
		if i > n - 2 then
			y += rng:Range(1.2, 2)
		end
		Decor.Gift(model, base * CF(math.cos(a) * r, y, math.sin(a) * r) * ANG(0, rng:Range(0, 3), 0), V3(sx, sy, sz), body, ribbon)
	end
	return model
end

-- Roca nevada
function Decor.Rock(parent: Instance, base: CFrame, size: number, rng: any): Model
	local model = Build.Model(parent, "Rock")
	Build.Part(model, {
		Size = V3(size, size * 0.7, size * 0.9),
		CFrame = base * CF(0, size * 0.25, 0) * ANG(rng:Range(-0.2, 0.2), rng:Range(0, 3), rng:Range(-0.2, 0.2)),
		Color = rgb(120, 128, 142),
		Material = Enum.Material.Slate,
	})
	Build.Deco(model, {
		Size = V3(size * 0.95, size * 0.2, size * 0.85),
		CFrame = base * CF(0, size * 0.62, 0) * ANG(0, rng:Range(0, 3), 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
	})
	return model
end

-- Elfo de bloques (decoración / tendero)
function Decor.Elf(parent: Instance, base: CFrame, color: Color3?): Model
	local model = Build.Model(parent, "Elf")
	local suit = color or rgb(40, 160, 80)
	local skin = rgb(255, 214, 180)
	for side = -1, 1, 2 do
		Build.Part(model, { Size = V3(0.8, 2, 0.8), CFrame = base * CF(side * 0.5, 1, 0), Color = rgb(220, 30, 45) })
		Build.Deco(model, { Size = V3(0.9, 0.5, 1.4), CFrame = base * CF(side * 0.5, 0.25, -0.3), Color = rgb(60, 40, 30) })
	end
	Build.Part(model, { Size = V3(2, 2.2, 1.1), CFrame = base * CF(0, 3.1, 0), Color = suit, Material = Enum.Material.Fabric })
	Build.Deco(model, { Size = V3(2.05, 0.35, 1.15), CFrame = base * CF(0, 2.5, 0), Color = rgb(40, 30, 20) })
	Build.Deco(model, { Size = V3(0.5, 0.4, 0.1), CFrame = base * CF(0, 2.5, -0.6), Color = GOLD, Material = Enum.Material.Metal })
	for side = -1, 1, 2 do
		Build.Deco(model, { Size = V3(0.6, 2, 0.6), CFrame = base * CF(side * 1.3, 3.1, 0) * ANG(0, 0, side * 0.15), Color = suit, Material = Enum.Material.Fabric })
		Build.Deco(model, { Size = V3(0.55, 0.55, 0.55), CFrame = base * CF(side * 1.45, 2, 0), Color = skin })
	end
	Build.Part(model, { Size = V3(1.6, 1.6, 1.6), CFrame = base * CF(0, 5, 0), Color = skin })
	for side = -1, 1, 2 do
		Build.Deco(model, { Class = "WedgePart", Size = V3(0.2, 0.9, 0.6), CFrame = base * CF(side * 0.95, 5.2, 0) * ANG(0, side * math.pi / 2, 0), Color = skin })
		Build.Ball(model, 0.25, base * CF(side * 0.35, 5.15, -0.8), { Color = rgb(20, 20, 24), CanCollide = false })
	end
	Build.Ball(model, 0.35, base * CF(0, 4.85, -0.85), { Color = rgb(255, 150, 140), CanCollide = false })
	-- gorro en cono (cilindros decrecientes)
	for i = 0, 4 do
		Build.Cylinder(model, 0.45, 1.8 - i * 0.32, base * CF(0, 6 + i * 0.42, 0), { Color = suit, Material = Enum.Material.Fabric, CanCollide = false })
	end
	Build.Cylinder(model, 0.35, 1.9, base * CF(0, 5.85, 0), { Color = rgb(255, 255, 255), Material = Enum.Material.Fabric, CanCollide = false })
	Build.Ball(model, 0.5, base * CF(0, 8.2, 0), { Color = rgb(255, 255, 255), CanCollide = false })
	return model
end

-- Reno de bloques
function Decor.Reindeer(parent: Instance, base: CFrame, glowingNose: boolean?): Model
	local model = Build.Model(parent, "Reindeer")
	local fur = rgb(140, 92, 56)
	local dark = rgb(70, 44, 26)
	Build.Part(model, { Size = V3(2.4, 2.2, 5), CFrame = base * CF(0, 3.6, 0), Color = fur })
	for _, x in { -0.8, 0.8 } do
		for _, z in { -1.8, 1.8 } do
			Build.Part(model, { Size = V3(0.6, 2.6, 0.6), CFrame = base * CF(x, 1.3, z), Color = fur })
			Build.Deco(model, { Size = V3(0.7, 0.4, 0.7), CFrame = base * CF(x, 0.2, z), Color = dark })
		end
	end
	Build.Part(model, { Size = V3(1.2, 2.4, 1.2), CFrame = base * CF(0, 5.2, -2.3) * ANG(-0.5, 0, 0), Color = fur })
	Build.Part(model, { Size = V3(1.6, 1.5, 2.2), CFrame = base * CF(0, 6.3, -3.1), Color = fur })
	Build.Deco(model, { Size = V3(1.7, 0.6, 1.4), CFrame = base * CF(0, 5.6, -2.9), Color = rgb(255, 230, 200) })
	local nose = Build.Ball(model, 0.6, base * CF(0, 6.1, -4.25), {
		Color = if glowingNose then rgb(255, 40, 40) else dark,
		Material = if glowingNose then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	if glowingNose then
		Build.Light(nose, rgb(255, 60, 60), 10, 2)
	end
	for side = -1, 1, 2 do
		Build.Ball(model, 0.3, base * CF(side * 0.55, 6.7, -4.1), { Color = rgb(20, 20, 24), CanCollide = false })
		-- astas
		local root = base * CF(side * 0.5, 7, -2.9)
		Build.Deco(model, { Size = V3(0.25, 1.8, 0.25), CFrame = root * CF(0, 0.8, 0) * ANG(0, 0, side * -0.4), Color = rgb(230, 210, 170) })
		Build.Deco(model, { Size = V3(0.22, 1.1, 0.22), CFrame = root * CF(side * 0.75, 1.3, -0.2) * ANG(0.3, 0, side * -1.1), Color = rgb(230, 210, 170) })
		Build.Deco(model, { Size = V3(0.22, 1, 0.22), CFrame = root * CF(side * 0.35, 1.9, 0.25) * ANG(-0.4, 0, side * -0.2), Color = rgb(230, 210, 170) })
	end
	Build.Deco(model, { Size = V3(2.5, 0.5, 0.5), CFrame = base * CF(0, 4.9, -2.2), Color = rgb(220, 30, 45) })
	Build.Ball(model, 0.6, base * CF(0, 4.6, -2.6), { Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	return model
end

-- Banco de madera nevado
function Decor.Bench(parent: Instance, base: CFrame): Model
	local model = Build.Model(parent, "Bench")
	local wood = rgb(130, 84, 50)
	for _, x in { -2.4, 2.4 } do
		Build.Part(model, { Size = V3(0.5, 1.6, 2), CFrame = base * CF(x, 0.8, 0), Color = rgb(40, 40, 48), Material = Enum.Material.Metal })
	end
	for i = 0, 2 do
		Build.Part(model, { Size = V3(6, 0.25, 0.6), CFrame = base * CF(0, 1.7, -0.7 + i * 0.7), Color = wood, Material = Enum.Material.Wood })
	end
	Build.Part(model, { Size = V3(6, 1.4, 0.3), CFrame = base * CF(0, 2.6, 1.1) * ANG(-0.15, 0, 0), Color = wood, Material = Enum.Material.Wood })
	Build.Deco(model, { Size = V3(5.6, 0.25, 1.6), CFrame = base * CF(0, 1.92, 0), Color = SNOW, Material = Enum.Material.Snow })
	return model
end

-- Trineo grande decorativo
function Decor.Sled(parent: Instance, base: CFrame): Model
	local model = Build.Model(parent, "Sled")
	for _, x in { -2.2, 2.2 } do
		Build.Part(model, { Size = V3(0.4, 0.4, 9), CFrame = base * CF(x, 0.2, 0), Color = GOLD, Material = Enum.Material.Metal })
		Build.Part(model, { Size = V3(0.4, 0.4, 2), CFrame = base * CF(x, 0.9, -4.8) * ANG(0.9, 0, 0), Color = GOLD, Material = Enum.Material.Metal })
		for _, z in { -2.5, 0, 2.5 } do
			Build.Deco(model, { Size = V3(0.3, 1.2, 0.3), CFrame = base * CF(x, 0.9, z), Color = GOLD, Material = Enum.Material.Metal })
		end
	end
	Build.Part(model, { Size = V3(5, 2.2, 7), CFrame = base * CF(0, 2.5, 0.5), Color = rgb(200, 25, 40) })
	Build.Part(model, { Class = "WedgePart", Size = V3(5, 2.2, 2), CFrame = base * CF(0, 2.5, -4), Color = rgb(200, 25, 40) })
	Build.Part(model, { Size = V3(5, 3, 0.8), CFrame = base * CF(0, 4.6, 3.6), Color = rgb(200, 25, 40) })
	Build.Deco(model, { Size = V3(5.2, 0.4, 7.2), CFrame = base * CF(0, 3.6, 0.5), Color = GOLD, Material = Enum.Material.Metal })
	Build.Deco(model, { Size = V3(4.4, 0.5, 4.5), CFrame = base * CF(0, 3.7, 0.8), Color = rgb(40, 140, 70), Material = Enum.Material.Fabric })
	return model
end

return Decor
