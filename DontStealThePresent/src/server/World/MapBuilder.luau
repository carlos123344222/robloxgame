-- Construye todo el mapa: suelo nevado, la cinta de regalos, la Fábrica de Santa, el Horno de Carbón, la
-- plaza con el árbol gigante, la tienda del elfo, el altar de renacimiento, las 8 bases y el bosque.
--
-- Solo crea instancias y propiedades, así que se puede "hornear" en el .rbxl con Lune (ver tools/) y además
-- el servidor lo construye al arrancar si el lugar no lo trae.

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Layout = require(script.Parent.Layout)
local BaseBuilder = require(script.Parent.BaseBuilder)
local Rng = require(game:GetService("ReplicatedStorage").Shared.Util.Rng)

local MapBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local SNOW = rgb(244, 248, 255)
local GOLD = rgb(255, 200, 60)
local RED = rgb(220, 30, 45)
local WHITE = rgb(255, 255, 255)
local BRICK = rgb(160, 52, 46)

local function buildGround(map: Instance)
	local ground = Build.Folder(map, "Ground")
	local b = Layout.Bounds
	local sizeX = b.MaxX - b.MinX + 160
	local sizeZ = b.MaxZ - b.MinZ + 160
	Build.Part(ground, {
		Name = "Snow",
		Size = V3(sizeX, 4, sizeZ),
		CFrame = CF((b.MinX + b.MaxX) / 2, -2, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
	})
	-- calles adoquinadas a ambos lados de la cinta
	for _, side in { -1, 1 } do
		Build.Part(ground, {
			Name = "Street",
			Size = V3(400, 0.2, 26),
			CFrame = CF(0, 0.1, side * 19),
			Color = rgb(196, 204, 222),
			Material = Enum.Material.Cobblestone,
		})
		-- bordillo nevado
		Build.Part(ground, {
			Name = "Curb",
			Size = V3(400, 0.5, 1),
			CFrame = CF(0, 0.25, side * 32.5),
			Color = rgb(230, 236, 248),
			Material = Enum.Material.Snow,
		})
	end
	-- caminos hacia las bases
	for i = 1, 8 do
		local cf = Layout.BaseCFrame(i)
		Build.Part(ground, {
			Name = "BasePath",
			Size = V3(14, 0.22, 6),
			CFrame = cf * CF(0, 0.11, -Layout.Base.Depth / 2 - 3),
			Color = rgb(196, 204, 222),
			Material = Enum.Material.Cobblestone,
		})
	end
	-- plaza circular
	Build.Cylinder(ground, 0.24, 110, CF(Layout.Plaza + V3(-6, 0.12, 0)), {
		Name = "PlazaFloor",
		Color = rgb(200, 208, 226),
		Material = Enum.Material.Cobblestone,
	})
	Build.Cylinder(ground, 0.26, 70, CF(Layout.Plaza + V3(-6, 0.13, 0)), {
		Name = "PlazaInner",
		Color = rgb(170, 60, 60),
		Material = Enum.Material.Cobblestone,
	})
	-- estanque helado (resbala)
	Build.Cylinder(ground, 0.3, 58, CF(-262, 0.15, 84), {
		Name = "FrozenPond",
		Color = rgb(170, 220, 255),
		Material = Enum.Material.Ice,
		Reflectance = 0.15,
	})
end

local function buildConveyor(map: Instance): Model
	local conveyor = Build.Model(map, "Conveyor")
	local belt = Layout.Belt
	local length = belt.BuildMaxX - belt.BuildMinX
	local centerX = (belt.BuildMaxX + belt.BuildMinX) / 2
	local top = belt.SurfaceY
	Build.Part(conveyor, {
		Name = "Frame",
		Size = V3(length, top - 0.4, belt.Width + 1),
		CFrame = CF(centerX, (top - 0.4) / 2, belt.Z),
		Color = rgb(52, 54, 66),
		Material = Enum.Material.DiamondPlate,
	})
	Build.Part(conveyor, {
		Name = "Belt",
		Size = V3(length, 0.4, belt.Width - 1),
		CFrame = CF(centerX, top - 0.2, belt.Z),
		Color = rgb(150, 18, 34),
		Material = Enum.Material.Fabric,
	})
	-- rayas que el cliente desplaza para que parezca que la cinta se mueve
	local stripes = Build.Folder(conveyor, "Stripes")
	stripes:SetAttribute("MinX", belt.BuildMinX)
	stripes:SetAttribute("MaxX", belt.BuildMaxX)
	local spacing = 4
	for x = belt.BuildMinX + 1, belt.BuildMaxX - 1, spacing do
		Build.Deco(stripes, {
			Name = "Stripe",
			Size = V3(1.3, 0.06, belt.Width - 1.2),
			CFrame = CF(x, top + 0.02, belt.Z),
			Color = WHITE,
			CastShadow = false,
		})
	end
	-- laterales de caramelo
	local segment = 6
	local i = 0
	for x = belt.BuildMinX, belt.BuildMaxX - segment, segment do
		for _, side in { -1, 1 } do
			Build.Deco(conveyor, {
				Name = "Skirt",
				Size = V3(segment, top - 0.4, 0.3),
				CFrame = CF(x + segment / 2, (top - 0.4) / 2, belt.Z + side * (belt.Width / 2 + 0.65)),
				Color = if i % 2 == 0 then RED else WHITE,
			})
		end
		i += 1
	end
	-- barandillas doradas
	for _, side in { -1, 1 } do
		local z = belt.Z + side * (belt.Width / 2 + 0.2)
		Build.Part(conveyor, {
			Name = "Rail",
			Size = V3(length, 0.35, 0.35),
			CFrame = CF(centerX, top + 0.75, z),
			Color = GOLD,
			Material = Enum.Material.Metal,
		})
		for x = belt.BuildMinX + 5, belt.BuildMaxX - 5, 10 do
			Build.Deco(conveyor, { Size = V3(0.3, 0.8, 0.3), CFrame = CF(x, top + 0.35, z), Color = GOLD, Material = Enum.Material.Metal })
		end
	end
	-- arcos de bastón sobre la cinta
	for _, x in { -90, 0, 90 } do
		local arch = Build.Model(conveyor, "Arch")
		for _, side in { -1, 1 } do
			Build.CandyPole(arch, CF(x, 0, belt.Z + side * 9), 15, 1.8, 1.4)
			Build.Ball(arch, 1.6, CF(x, 15.6, belt.Z + side * 9), { Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
		end
		Build.Log(arch, 18, 1.4, CF(x, 15, belt.Z) * ANG(0, math.pi / 2, 0), { Color = RED, CanCollide = false })
		Build.StringLights(arch, V3(x, 14.2, belt.Z - 8.5), V3(x, 14.2, belt.Z + 8.5), 1.3, 1.6, 0.45)
		if x == 0 then
			local sign = Build.Part(arch, {
				Name = "TitleSign",
				Size = V3(1, 6, 26),
				CFrame = CF(x, 19, belt.Z),
				Color = rgb(30, 110, 60),
				CanCollide = false,
			})
			Build.Deco(arch, { Size = V3(1.3, 0.6, 26.6), CFrame = CF(x, 22.2, belt.Z), Color = SNOW, Material = Enum.Material.Snow })
			Build.Deco(arch, { Size = V3(1.2, 0.5, 26.4), CFrame = CF(x, 15.9, belt.Z), Color = GOLD, Material = Enum.Material.Metal })
			sign:SetAttribute("Title", true)
		else
			local bowCF = CF(x, 16.4, belt.Z)
			for _, s in { -1, 1 } do
				local lobe = Build.Deco(arch, { Size = V3(1, 2.2, 3.4), CFrame = bowCF * CF(0, 0.5, s * 1.6) * ANG(s * 0.45, 0, 0), Color = rgb(40, 160, 80) })
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = lobe
			end
			Build.Ball(arch, 1.2, bowCF, { Color = rgb(40, 160, 80), CanCollide = false })
		end
	end
	local items = Build.Folder(conveyor, "Items")
	items.Name = "Items"
	return conveyor
end

local function buildFactory(map: Instance)
	local factory = Build.Model(map, "Factory")
	local origin = CF(Layout.Factory) * ANG(0, -math.pi / 2, 0) -- la fachada (-Z local) mira hacia +X (la cinta)
	local W, D, H = 50, 40, 26
	local door = 16
	local side = (W - door) / 2
	local brickWall = { Color = BRICK, Material = Enum.Material.Brick }
	-- fachada con la puerta por la que sale la cinta
	local p1: any = table.clone(brickWall)
	p1.Size = V3(side, H, 2)
	p1.CFrame = origin * CF(-(door / 2 + side / 2), H / 2, -D / 2)
	Build.Part(factory, p1)
	local p2: any = table.clone(brickWall)
	p2.Size = V3(side, H, 2)
	p2.CFrame = origin * CF(door / 2 + side / 2, H / 2, -D / 2)
	Build.Part(factory, p2)
	local p3: any = table.clone(brickWall)
	p3.Size = V3(door, H - 12, 2)
	p3.CFrame = origin * CF(0, 12 + (H - 12) / 2, -D / 2)
	Build.Part(factory, p3)
	-- resto de muros
	local back: any = table.clone(brickWall)
	back.Size = V3(W, H, 2)
	back.CFrame = origin * CF(0, H / 2, D / 2)
	Build.Part(factory, back)
	for _, s in { -1, 1 } do
		local wall: any = table.clone(brickWall)
		wall.Size = V3(2, H, D)
		wall.CFrame = origin * CF(s * W / 2, H / 2, 0)
		Build.Part(factory, wall)
	end
	Build.Part(factory, { Size = V3(W, 1, D), CFrame = origin * CF(0, H, 0), Color = rgb(90, 40, 36) })
	-- marco de la puerta (bastones) y cortina de luz
	for _, s in { -1, 1 } do
		Build.CandyPole(factory, origin * CF(s * (door / 2 + 0.8), 0, -D / 2 - 1.2), 13, 1.8, 1.3)
	end
	Build.Log(factory, door + 3, 1.8, origin * CF(0, 12.6, -D / 2 - 1.2), { Color = RED })
	local glow = Build.Deco(factory, {
		Size = V3(door - 1, 11.5, 0.3),
		CFrame = origin * CF(0, 6, -D / 2 + 0.6),
		Color = rgb(255, 230, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Name = "DoorGlow",
	})
	Build.Light(glow, rgb(255, 214, 140), 30, 2)
	-- tejado a dos aguas nevado
	local roofH = 12
	for _, s in { -1, 1 } do
		Build.Part(factory, {
			Class = "WedgePart",
			Size = V3(W + 4, roofH, D / 2 + 2),
			CFrame = origin * CF(0, H + roofH / 2, s * (D / 4 + 1)) * ANG(0, if s > 0 then math.pi else 0, 0),
			Color = SNOW,
			Material = Enum.Material.Snow,
		})
	end
	-- adornos de la fachada: ventanas y luces
	for _, x in { -18, -10, 10, 18 } do
		local wcf = origin * CF(x, 17, -D / 2 - 1.05)
		Build.Deco(factory, { Size = V3(5, 5, 0.3), CFrame = wcf, Color = WHITE })
		Build.Deco(factory, { Size = V3(4.2, 4.2, 0.35), CFrame = wcf, Color = rgb(255, 210, 120), Material = Enum.Material.Neon })
		Build.Deco(factory, { Size = V3(5.6, 0.6, 1.2), CFrame = wcf * CF(0, -2.8, -0.4), Color = SNOW, Material = Enum.Material.Snow })
	end
	Build.StringLights(factory, (origin * CF(-W / 2, H + 0.5, -D / 2 - 1.3)).Position, (origin * CF(W / 2, H + 0.5, -D / 2 - 1.3)).Position, 2.2, 1.5, 0.7)
	-- cartel
	local sign = Build.Part(factory, {
		Name = "FactorySign",
		Size = V3(26, 5, 0.8),
		CFrame = origin * CF(0, H + 3.6, -D / 2 - 1.6),
		Color = rgb(30, 110, 60),
		CanCollide = false,
	})
	sign:SetAttribute("Label", "FÁBRICA DE REGALOS")
	-- engranajes que giran (el cliente los anima)
	for i, g in { { -14, 6, 7, 0.5 }, { -7.4, 3.6, 4.4, -0.8 }, { 14, 6, 7, -0.5 } } do
		local gcf = origin * CF(g[1], g[2] + 2, -D / 2 - 1.3) * ANG(0, math.pi / 2, 0)
		local gear = Build.Log(factory, 0.6, g[3], gcf, { Color = if i == 2 then GOLD else rgb(150, 156, 170), Material = Enum.Material.Metal, CanCollide = false, Name = "Gear" })
		gear:AddTag("SpinGear")
		gear:SetAttribute("SpinSpeed", g[4])
		for k = 0, 7 do
			local a = k * math.pi / 4
			local r = g[3] / 2 + 0.4
			local tooth = Build.Deco(factory, {
				Size = V3(0.6, 1.2, 1.2),
				CFrame = gcf * CF(0, math.cos(a) * r, math.sin(a) * r) * ANG(a, 0, 0),
				Color = gear.Color,
				Material = Enum.Material.Metal,
				Name = "Tooth",
			})
			tooth:AddTag("SpinGearTooth")
			tooth:SetAttribute("Gear", i)
		end
		gear:SetAttribute("GearIndex", i)
	end
	-- chimenea con humo
	local chimney = Build.Part(factory, { Size = V3(6, 14, 6), CFrame = origin * CF(14, H + 10, 8), Color = BRICK, Material = Enum.Material.Brick })
	Build.Deco(factory, { Size = V3(7, 1, 7), CFrame = origin * CF(14, H + 17.5, 8), Color = SNOW, Material = Enum.Material.Snow })
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(230, 230, 240)
	smoke.Opacity = 0.18
	smoke.RiseVelocity = 7
	smoke.Size = 6
	smoke.Parent = chimney
	-- regalo gigante en el tejado
	Decor.Gift(factory, origin * CF(-10, H + roofH + 3.5, 0) * ANG(0, 0.3, 0), V3(10, 8, 10), rgb(40, 160, 80), RED)
	-- elfos en la puerta
	Decor.Elf(factory, origin * CF(-12, 0, -D / 2 - 5) * ANG(0, math.pi, 0), rgb(40, 160, 80))
	Decor.Elf(factory, origin * CF(12, 0, -D / 2 - 5) * ANG(0, math.pi, 0), rgb(220, 30, 45))
end

local function buildFurnace(map: Instance)
	local furnace = Build.Model(map, "Furnace")
	local origin = CF(Layout.Furnace) * ANG(0, math.pi / 2, 0) -- la boca (-Z local) mira hacia -X
	local W, D, H = 26, 22, 18
	local mouth = 14
	local side = (W - mouth) / 2
	for _, s in { -1, 1 } do
		Build.Part(furnace, { Size = V3(side, H, 2), CFrame = origin * CF(s * (mouth / 2 + side / 2), H / 2, -D / 2), Color = rgb(70, 64, 70), Material = Enum.Material.Brick })
		Build.Part(furnace, { Size = V3(2, H, D), CFrame = origin * CF(s * W / 2, H / 2, 0), Color = rgb(70, 64, 70), Material = Enum.Material.Brick })
	end
	Build.Part(furnace, { Size = V3(mouth, H - 9, 2), CFrame = origin * CF(0, 9 + (H - 9) / 2, -D / 2), Color = rgb(70, 64, 70), Material = Enum.Material.Brick })
	Build.Part(furnace, { Size = V3(W, H, 2), CFrame = origin * CF(0, H / 2, D / 2), Color = rgb(70, 64, 70), Material = Enum.Material.Brick })
	Build.Part(furnace, { Size = V3(W, 1, D), CFrame = origin * CF(0, H, 0), Color = rgb(50, 46, 50) })
	local core = Build.Deco(furnace, {
		Name = "FurnaceGlow",
		Size = V3(mouth - 1, 8, 1),
		CFrame = origin * CF(0, 4.5, -D / 2 + 3),
		Color = rgb(255, 110, 20),
		Material = Enum.Material.Neon,
	})
	Build.Light(core, rgb(255, 120, 40), 36, 3)
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 12
	fire.Color = rgb(255, 110, 20)
	fire.SecondaryColor = rgb(255, 210, 80)
	fire.Parent = core
	-- chimenea alta
	local stack = Build.Part(furnace, { Size = V3(8, 26, 8), CFrame = origin * CF(0, H + 13, 4), Color = rgb(70, 64, 70), Material = Enum.Material.Brick })
	Build.Deco(furnace, { Size = V3(9, 1.2, 9), CFrame = origin * CF(0, H + 26.4, 4), Color = SNOW, Material = Enum.Material.Snow })
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(60, 60, 66)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 9
	smoke.Size = 8
	smoke.Parent = stack
	-- cartel y montón de carbón
	local sign = Build.Part(furnace, {
		Name = "FurnaceSign",
		Size = V3(18, 4, 0.8),
		CFrame = origin * CF(0, H + 3, -D / 2 - 1),
		Color = rgb(40, 40, 46),
		CanCollide = false,
	})
	sign:SetAttribute("Label", "HORNO DE CARBÓN")
	local rng = Rng.new(77)
	for _ = 1, 14 do
		Build.Ball(furnace, rng:Range(1.2, 2.6), origin * CF(rng:Range(-W / 2, -mouth / 2), rng:Range(0.4, 1.2), -D / 2 - rng:Range(2, 7)), {
			Color = rgb(36, 36, 40),
			Material = Enum.Material.Slate,
		})
	end
	Build.StringLights(furnace, (origin * CF(-W / 2, H + 0.6, -D / 2 - 1.2)).Position, (origin * CF(W / 2, H + 0.6, -D / 2 - 1.2)).Position, 2, 1, 0.6)
end

local function buildGiantTree(map: Instance)
	local model = Build.Model(map, "GiantTree")
	local base = CF(Layout.Plaza)
	Build.Cylinder(model, 2, 26, base * CF(0, 1, 0), { Color = rgb(150, 40, 40), Material = Enum.Material.Brick })
	Build.Cylinder(model, 0.6, 27, base * CF(0, 2.2, 0), { Color = GOLD, Material = Enum.Material.Metal })
	Build.Cylinder(model, 8, 5, base * CF(0, 6, 0), { Color = rgb(96, 62, 38), Material = Enum.Material.Wood })
	local y = 8
	local tiers = 12
	local height = 74
	local tierH = height / tiers
	for i = 0, tiers - 1 do
		local t = i / (tiers - 1)
		local d = 46 * (1 - t) + 5
		local green = if i % 2 == 0 then rgb(26, 104, 60) else rgb(20, 86, 50)
		-- cada piso son tres discos cada vez más estrechos: silueta de cono
		for k = 0, 2 do
			Build.Cylinder(model, tierH * 0.36, d * (1 - k * 0.16), base * CF(0, y + tierH * (0.18 + k * 0.3), 0), {
				Color = green,
				Material = Enum.Material.Grass,
			})
		end
		Build.Cylinder(model, 0.6, d * 0.97, base * CF(0, y + tierH * 0.3, 0), { Color = SNOW, Material = Enum.Material.Snow, CanCollide = false })
		-- bolas de adorno
		local count = math.max(4, math.floor(d / 4))
		for k = 0, count - 1 do
			local a = k * 2 * math.pi / count + i * 0.5
			local colors = { RED, GOLD, rgb(70, 150, 255), rgb(200, 90, 255), WHITE }
			Build.Ball(model, 1.7, base * CF(math.cos(a) * d * 0.5, y + tierH * 0.12, math.sin(a) * d * 0.5), {
				Color = colors[(k + i) % #colors + 1],
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.25,
				CanCollide = false,
				CastShadow = false,
			})
		end
		y += tierH
	end
	-- espiral de luces
	local turns = 5
	local bulbs = 120
	for k = 0, bulbs do
		local t = k / bulbs
		local a = t * turns * 2 * math.pi
		local d = 46 * (1 - t) + 6
		local by = 9 + t * (height - 4)
		Build.Ball(model, 0.9, base * CF(math.cos(a) * d * 0.52, by, math.sin(a) * d * 0.52), {
			Color = Build.BulbColors[k % #Build.BulbColors + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Tag = "TwinkleBulb",
		})
	end
	-- estrella gigante
	local starCF = base * CF(0, y + 5, 0)
	local core = Build.Ball(model, 5, starCF, { Color = rgb(255, 220, 80), Material = Enum.Material.Neon, CanCollide = false, Name = "StarCore" })
	core:AddTag("SpinStar")
	for k = 0, 4 do
		local phi = math.pi / 2 + k * 2 * math.pi / 5
		local spike = Build.Deco(model, {
			Size = V3(1.6, 6, 1.6),
			CFrame = starCF * CF(math.cos(phi) * 4, math.sin(phi) * 4, 0) * ANG(0, 0, phi - math.pi / 2) * ANG(0, math.pi / 4, 0),
			Color = rgb(255, 220, 80),
			Material = Enum.Material.Neon,
			Name = "StarSpike",
		})
		spike:AddTag("SpinStar")
	end
	Build.Light(core, rgb(255, 220, 120), 60, 3)
	Build.Emitter(core, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(rgb(255, 230, 140)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 14,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
	})
	-- regalos bajo el árbol
	local rng = Rng.new(2024)
	for k = 0, 7 do
		local a = k * 2 * math.pi / 8 + 0.3
		Decor.GiftPile(model, base * CF(math.cos(a) * 18, 2.5, math.sin(a) * 18), rng, 3)
	end
end

local function buildShop(map: Instance)
	local shop = Build.Model(map, "Shop")
	local origin = CF(Layout.Shop) * ANG(0, math.pi, 0) -- mostrador mirando a +Z (hacia la plaza)
	local wood = rgb(140, 92, 56)
	Build.Part(shop, { Size = V3(20, 1, 14), CFrame = origin * CF(0, 0.5, 0), Color = rgb(110, 72, 44), Material = Enum.Material.WoodPlanks })
	local counter = Build.Part(shop, { Name = "Counter", Size = V3(16, 4, 3), CFrame = origin * CF(0, 3, -4), Color = wood, Material = Enum.Material.Wood })
	Build.Deco(shop, { Size = V3(16.6, 0.5, 3.6), CFrame = origin * CF(0, 5.2, -4), Color = rgb(250, 250, 250) })
	for _, x in { -9.5, 9.5 } do
		for _, z in { -5.5, 6 } do
			Build.CandyPole(shop, origin * CF(x, 1, z), 11, 1, 1.1)
		end
	end
	-- toldo de rayas
	for i = 0, 9 do
		Build.Part(shop, {
			Class = "WedgePart",
			Size = V3(2.1, 2.4, 14),
			CFrame = origin * CF(-9.45 + i * 2.1, 13.2, 0.25) * ANG(0, 0, 0),
			Color = if i % 2 == 0 then RED else WHITE,
			CanCollide = false,
		})
	end
	Build.Deco(shop, { Size = V3(21, 0.8, 1), CFrame = origin * CF(0, 12.4, -6.9), Color = GOLD, Material = Enum.Material.Metal })
	local sign = Build.Part(shop, { Name = "ShopSign", Size = V3(14, 3.4, 0.6), CFrame = origin * CF(0, 16.2, 6.8), Color = rgb(30, 110, 60), CanCollide = false })
	sign:SetAttribute("Label", "🛒 TIENDA DEL ELFO")
	Decor.Elf(shop, origin * CF(0, 1, 0), rgb(40, 160, 80))
	Decor.GiftPile(shop, origin * CF(-6, 5.4, -4), Rng.new(5), 2)
	Build.StringLights(shop, (origin * CF(-10, 12, -7.2)).Position, (origin * CF(10, 12, -7.2)).Position, 1.4, 1, 0.45)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Abrir tienda"
	prompt.ObjectText = "Tienda del Elfo"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function buildAltar(map: Instance)
	local altar = Build.Model(map, "RebirthAltar")
	local origin = CF(Layout.Altar)
	Build.Cylinder(altar, 1.2, 26, origin * CF(0, 0.6, 0), { Color = rgb(210, 220, 240), Material = Enum.Material.Marble })
	Build.Cylinder(altar, 1.2, 18, origin * CF(0, 1.8, 0), { Color = rgb(230, 236, 250), Material = Enum.Material.Marble })
	Build.Cylinder(altar, 0.3, 19, origin * CF(0, 2.5, 0), { Color = rgb(150, 110, 255), Material = Enum.Material.Neon, CanCollide = false, Name = "RuneRing" })
	for k = 0, 5 do
		local a = k * math.pi / 3
		local pcf = origin * CF(math.cos(a) * 11, 1.2, math.sin(a) * 11)
		Build.Cylinder(altar, 8, 1.6, pcf * CF(0, 4, 0), { Color = rgb(230, 236, 250), Material = Enum.Material.Marble })
		local orb = Build.Ball(altar, 1.6, pcf * CF(0, 8.8, 0), { Color = rgb(170, 130, 255), Material = Enum.Material.Neon, CanCollide = false })
		Build.Light(orb, rgb(170, 130, 255), 12, 1.2)
	end
	local crystal = Build.Part(altar, {
		Name = "Crystal",
		Size = V3(3, 6, 3),
		CFrame = origin * CF(0, 9, 0) * ANG(0, 0.6, 0),
		Color = rgb(180, 150, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.3,
		CanCollide = false,
	})
	crystal:AddTag("FloatSpin")
	local core = Build.Deco(altar, { Name = "CrystalCore", Size = V3(1.4, 4, 1.4), CFrame = origin * CF(0, 9, 0) * ANG(0, 0.6, 0), Color = rgb(220, 200, 255), Material = Enum.Material.Neon })
	core:AddTag("FloatSpin")
	Build.Light(core, rgb(190, 160, 255), 30, 2.5)
	local pedestal = Build.Part(altar, { Name = "AltarPedestal", Size = V3(4, 3, 4), CFrame = origin * CF(0, 3.9, 0), Color = rgb(200, 208, 230), Material = Enum.Material.Marble })
	local sign = Build.Part(altar, { Name = "AltarSign", Size = V3(16, 3.4, 0.6), CFrame = origin * CF(0, 15, -9), Color = rgb(60, 40, 120), CanCollide = false })
	sign:SetAttribute("Label", "✨ ALTAR DE RENACER")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Renacer"
	prompt.ObjectText = "Altar de las Estrellas"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal
end

local function buildForest(map: Instance)
	local forest = Build.Folder(map, "Forest")
	local rng = Rng.new(1225)
	local b = Layout.Bounds
	local function far(x: number, z: number): boolean
		-- no tapar bases, cinta ni plaza
		if math.abs(z) < 104 and x > -250 and x < 225 then
			return false
		end
		if (Vector3.new(x, 0, z) - Layout.Plaza).Magnitude < 70 then
			return false
		end
		if (Vector3.new(x, 0, z) - Vector3.new(-262, 0, 84)).Magnitude < 36 then
			return false
		end
		if math.abs(z) < 26 then
			return false
		end
		return true
	end
	local placed = 0
	local attempts = 0
	while placed < 95 and attempts < 2000 do
		attempts += 1
		local x = rng:Range(b.MinX + 6, b.MaxX - 6)
		local z = rng:Range(b.MinZ + 6, b.MaxZ - 6)
		if far(x, z) then
			local scale = rng:Range(0.8, 1.5)
			Decor.PineTree(forest, CF(x, 0, z) * ANG(0, rng:Range(0, 6), 0), scale, rng:Next() < 0.25, placed)
			placed += 1
		end
	end
	-- rocas, muñecos de nieve y montones de regalos repartidos
	for _ = 1, 26 do
		local x = rng:Range(b.MinX + 10, b.MaxX - 10)
		local z = rng:Range(b.MinZ + 10, b.MaxZ - 10)
		if far(x, z) then
			Decor.Rock(forest, CF(x, 0, z), rng:Range(3, 7), rng)
		end
	end
	local snowmen = { V3(-235, 0, -40), V3(-240, 0, 44), V3(300, 0, -78), V3(300, 0, 80), V3(0, 0, 104), V3(-90, 0, -104), V3(90, 0, 104) }
	for i, p in snowmen do
		Decor.Snowman(forest, CF(p) * ANG(0, rng:Range(0, 6), 0), rng:Range(0.9, 1.3), Build.BulbColors[i % #Build.BulbColors + 1])
	end
	for _, p in { V3(-180, 0, 104), V3(180, 0, -104), V3(-275, 0, 0), V3(318, 0, 0) } do
		Decor.GiftPile(forest, CF(p), rng, 6)
	end
	Decor.Sled(forest, CF(-238, 0, 110) * ANG(0, 0.8, 0))
	for k = 0, 3 do
		Decor.Reindeer(forest, CF(-246 + k * 6, 0, 126 - k * 2) * ANG(0, 0.8, 0), k == 0)
	end
	for _, p in { V3(-262, 0, 50), V3(-226, 0, 84), V3(-298, 0, 84) } do
		Decor.Bench(forest, CF(p) * CFrame.lookAt(Vector3.zero, Vector3.new(-262, 0, 84) - p).Rotation)
	end
end

local function buildStreetDecor(map: Instance)
	local decor = Build.Folder(map, "Street")
	-- farolas a lo largo de la cinta
	for x = -165, 165, 30 do
		for _, side in { -1, 1 } do
			Decor.CandyLamp(decor, CF(x, 0, side * 10.5) * ANG(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0), 12)
		end
	end
	-- entre bases: árboles con luces y bancos
	for _, x in { -180, -90, 0, 90, 180 } do
		for _, side in { -1, 1 } do
			Decor.PineTree(decor, CF(x, 0, side * 52), 0.9, true, x)
			Decor.Bench(decor, CF(x, 0, side * 38) * ANG(0, if side < 0 then 0 else math.pi, 0))
		end
	end
	-- muñecos de nieve junto a la plaza
	Decor.Snowman(decor, CF(222, 0, -22) * ANG(0, -1.2, 0), 1.2, rgb(70, 150, 255))
	Decor.Snowman(decor, CF(222, 0, 22) * ANG(0, -1.9, 0), 1.2, rgb(220, 30, 45))
	Decor.Reindeer(decor, CF(300, 0, -24) * ANG(0, -1.57, 0), true)
	Decor.Reindeer(decor, CF(300, 0, 24) * ANG(0, -1.57, 0), false)
end

local function buildBoundaries(map: Instance)
	local walls = Build.Folder(map, "Boundaries")
	local b = Layout.Bounds
	local h = 80
	local props = { Transparency = 1, CastShadow = false, CanQuery = false, Name = "InvisibleWall" }
	local list = {
		{ V3(b.MaxX - b.MinX, h, 2), V3((b.MinX + b.MaxX) / 2, h / 2, b.MinZ) },
		{ V3(b.MaxX - b.MinX, h, 2), V3((b.MinX + b.MaxX) / 2, h / 2, b.MaxZ) },
		{ V3(2, h, b.MaxZ - b.MinZ), V3(b.MinX, h / 2, 0) },
		{ V3(2, h, b.MaxZ - b.MinZ), V3(b.MaxX, h / 2, 0) },
	}
	for _, w in list do
		local p: any = table.clone(props)
		p.Size = w[1]
		p.CFrame = CF(w[2])
		Build.Part(walls, p)
	end
end

function MapBuilder.Build(parent: Instance): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	map:SetAttribute("MapVersion", Layout.Version)

	buildGround(map)
	buildConveyor(map)
	buildFactory(map)
	buildFurnace(map)
	buildGiantTree(map)
	buildShop(map)
	buildAltar(map)
	buildStreetDecor(map)
	buildForest(map)
	buildBoundaries(map)

	local bases = Build.Folder(map, "Bases")
	for i = 1, 8 do
		BaseBuilder.Build(bases, i)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = V3(10, 0.4, 10)
	spawn.CFrame = CF(Layout.PlazaSpawn + V3(0, 0.3, 0)) * ANG(0, math.pi / 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Parent = map

	map.Parent = parent
	return map
end

-- Cuenta las piezas del mapa (para el registro)
function MapBuilder.CountParts(map: Instance): number
	local count = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return MapBuilder
