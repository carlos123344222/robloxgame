-- Construye un "Taller" (base de un jugador): cabaña de troncos sin techo con 16 pedestales, placas de
-- cobro, botón de bloqueo, chimenea, guirnaldas y el escudo de bloqueo (ForceField) de la puerta y el techo.
--
-- Nombres que usa el código del juego:
--   Base.Slots.Slot<i>.Pedestal / Pad      pedestal del regalo y placa de cobro del hueco i
--   Base.LockButton                         botón para bloquear (lo pisa el dueño)
--   Base.LockDoor / Base.LockLid            escudo de bloqueo (invisible mientras la base está abierta)
--   Base.Sign                               cartel de la entrada (el texto lo pone BaseService)
--   Base.Spawn                              SpawnLocation del dueño

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Layout = require(script.Parent.Layout)

local BaseBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local LOG = rgb(122, 80, 50)
local LOG_DARK = rgb(104, 66, 40)
local SNOW = rgb(244, 248, 255)
local FLOOR = rgb(168, 118, 78)
local GOLD = rgb(255, 200, 60)

local function wallOfLogs(parent: Instance, cf: CFrame, length: number, height: number)
	local count = math.floor(height / 2)
	for i = 0, count - 1 do
		Build.Log(parent, length, 2.05, cf * CF(0, 1 + i * 2, 0), {
			Color = if i % 2 == 0 then LOG else LOG_DARK,
			Material = Enum.Material.Wood,
			Name = "Log",
		})
	end
	-- interior liso para que nada se cuele entre troncos
	Build.Part(parent, {
		Size = V3(length, height, 1.2),
		CFrame = cf * CF(0, height / 2, 0),
		Transparency = 1,
		Name = "WallCollider",
		CastShadow = false,
	})
	Build.Deco(parent, {
		Size = V3(length + 0.6, 0.9, 2.8),
		CFrame = cf * CF(0, height + 0.35, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Name = "SnowCap",
		CanCollide = true,
	})
end

local function icicles(parent: Instance, cf: CFrame, length: number, y: number, outward: number)
	local count = math.floor(length / 2.2)
	for i = 0, count do
		local x = -length / 2 + i * (length / count)
		local h = 0.8 + (i % 3) * 0.45
		Build.Deco(parent, {
			Class = "WedgePart",
			Size = V3(0.35, h, 0.45),
			CFrame = cf * CF(x, y - h / 2, outward) * ANG(math.pi, 0, 0),
			Color = rgb(200, 236, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.15,
			CastShadow = false,
			Name = "Icicle",
		})
	end
end

local function fireplace(parent: Instance, base: CFrame)
	local model = Build.Model(parent, "Fireplace")
	local brick = rgb(156, 64, 52)
	Build.Part(model, { Size = V3(12, 9, 3), CFrame = base * CF(0, 5.5, 0), Color = brick, Material = Enum.Material.Brick })
	Build.Part(model, { Size = V3(13.4, 0.8, 3.8), CFrame = base * CF(0, 10.3, -0.3), Color = rgb(110, 70, 44), Material = Enum.Material.Wood })
	Build.Part(model, { Size = V3(6.4, 4.4, 1.2), CFrame = base * CF(0, 3.2, -1.2), Color = rgb(20, 14, 12) })
	local embers = Build.Deco(model, {
		Size = V3(4.6, 0.6, 1),
		CFrame = base * CF(0, 1.4, -1.6),
		Color = rgb(255, 120, 30),
		Material = Enum.Material.Neon,
		Name = "Embers",
	})
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 6
	fire.Color = rgb(255, 120, 30)
	fire.SecondaryColor = rgb(255, 220, 90)
	fire.Parent = embers
	Build.Light(embers, rgb(255, 150, 70), 24, 2.2, true)
	for i = 0, 3 do
		Build.Deco(model, { Size = V3(0.8, 0.8, 4), CFrame = base * CF(-1.5 + i, 1.5, -1.6) * ANG(0, 0.4 * (i - 1.5), 0), Color = rgb(90, 56, 34), Material = Enum.Material.Wood, Shape = Enum.PartType.Cylinder })
	end
	-- calcetines colgados
	local sockColors = { rgb(220, 30, 45), rgb(40, 160, 80), rgb(60, 120, 230) }
	for i = 1, 3 do
		local x = -4 + (i - 1) * 4
		local s = base * CF(x, 8.6, -2.1)
		Build.Deco(model, { Size = V3(1.2, 1.8, 0.5), CFrame = s, Color = sockColors[i], Material = Enum.Material.Fabric })
		Build.Deco(model, { Size = V3(1.7, 0.7, 0.5), CFrame = s * CF(0.3, -1, 0), Color = sockColors[i], Material = Enum.Material.Fabric })
		Build.Deco(model, { Size = V3(1.4, 0.5, 0.6), CFrame = s * CF(0, 1, 0), Color = rgb(255, 255, 255), Material = Enum.Material.Fabric })
	end
	-- corona encima
	local wreathCenter = base * CF(0, 13.2, -1.9)
	for i = 0, 13 do
		local a = i * 2 * math.pi / 14
		Build.Ball(model, 0.9, wreathCenter * CF(math.cos(a) * 1.5, math.sin(a) * 1.5, 0), {
			Color = rgb(30, 120, 60),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		if i % 3 == 0 then
			Build.Ball(model, 0.35, wreathCenter * CF(math.cos(a) * 1.5, math.sin(a) * 1.5, -0.45), {
				Color = rgb(220, 30, 45),
				CanCollide = false,
			})
		end
	end
	return model
end

-- Construye la base i. Devuelve el Model.
function BaseBuilder.Build(parent: Instance, index: number): Model
	local theme = Layout.BaseThemes[index]
	local cf = Layout.BaseCFrame(index)
	local W, D, H = Layout.Base.Width, Layout.Base.Depth, Layout.Base.WallHeight
	local entrance = Layout.Base.EntranceWidth

	local model = Build.Model(parent, "Base" .. index)
	model:SetAttribute("BaseId", index)
	model:SetAttribute("ThemeName", theme.Name)
	model:SetAttribute("ThemeColor", theme.Color)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("LockedUntil", 0)

	local structure = Build.Folder(model, "Structure")
	local decor = Build.Folder(model, "Decor")

	-- Suelo
	Build.Part(structure, { Size = V3(W, 1, D), CFrame = cf * CF(0, 0.5, 0), Color = FLOOR, Material = Enum.Material.WoodPlanks, Name = "Floor" })
	Build.Deco(structure, {
		Size = V3(22, 0.12, D - 6),
		CFrame = cf * CF(0, 1.06, -1),
		Color = theme.Color,
		Material = Enum.Material.Fabric,
		Name = "Carpet",
	})
	for _, x in { -11.4, 11.4 } do
		Build.Deco(structure, { Size = V3(0.6, 0.14, D - 6), CFrame = cf * CF(x, 1.08, -1), Color = GOLD, Material = Enum.Material.Fabric })
	end
	-- borde del suelo
	Build.Deco(structure, { Size = V3(W + 1, 0.6, 1), CFrame = cf * CF(0, 0.7, -D / 2 - 0.3), Color = theme.Color, Name = "FrontTrim" })

	-- Muros de troncos
	local walls = Build.Folder(structure, "Walls")
	wallOfLogs(walls, cf * CF(0, 1, D / 2 - 1), W, H) -- fondo
	wallOfLogs(walls, cf * CF(-W / 2 + 1, 1, 0) * ANG(0, math.pi / 2, 0), D, H) -- izquierda
	wallOfLogs(walls, cf * CF(W / 2 - 1, 1, 0) * ANG(0, math.pi / 2, 0), D, H) -- derecha
	local segment = (W - entrance) / 2
	wallOfLogs(walls, cf * CF(-(entrance / 2 + segment / 2), 1, -D / 2 + 1), segment, H)
	wallOfLogs(walls, cf * CF(entrance / 2 + segment / 2, 1, -D / 2 + 1), segment, H)

	-- Ventanas iluminadas en los laterales
	for _, side in { -1, 1 } do
		for _, z in { -12, 12 } do
			local wcf = cf * CF(side * (W / 2 - 1), 7.5, z) * ANG(0, math.pi / 2, 0)
			Build.Deco(decor, { Size = V3(6, 4.4, 2.4), CFrame = wcf, Color = rgb(255, 255, 255), Name = "WindowFrame" })
			Build.Deco(decor, { Size = V3(5, 3.6, 2.5), CFrame = wcf, Color = rgb(255, 210, 130), Material = Enum.Material.Neon, Name = "Window" })
			Build.Deco(decor, { Size = V3(0.3, 3.6, 2.6), CFrame = wcf, Color = rgb(255, 255, 255) })
			Build.Deco(decor, { Size = V3(5, 0.3, 2.6), CFrame = wcf, Color = rgb(255, 255, 255) })
			Build.Deco(decor, { Size = V3(6.6, 0.5, 3), CFrame = wcf * CF(0, -2.4, 0), Color = SNOW, Material = Enum.Material.Snow })
		end
	end

	-- Carámbanos en la fachada
	icicles(decor, cf * CF(-(entrance / 2 + segment / 2), 0, -D / 2), segment, H + 0.9, -0.9)
	icicles(decor, cf * CF(entrance / 2 + segment / 2, 0, -D / 2), segment, H + 0.9, -0.9)

	-- Pilares de bastón en las esquinas y la entrada
	local pillars = {
		V3(-W / 2, 0, -D / 2),
		V3(W / 2, 0, -D / 2),
		V3(-W / 2, 0, D / 2),
		V3(W / 2, 0, D / 2),
	}
	for _, p in pillars do
		local pcf = cf * CF(p)
		Build.CandyPole(decor, pcf, H + 3, 2.4, 1.5)
		Build.Ball(decor, 1.8, pcf * CF(0, H + 3.8, 0), { Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	end
	for _, side in { -1, 1 } do
		local pcf = cf * CF(side * (entrance / 2 + 1), 0, -D / 2 + 0.2)
		Build.CandyPole(decor, pcf, H + 5, 2.4, 1.5)
		local star = Build.Ball(decor, 1.6, pcf * CF(0, H + 5.9, 0), {
			Color = theme.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		Build.Light(star, theme.Color, 16, 1.4)
	end

	-- Cartel de la entrada
	local signCF = cf * CF(0, H + 2.6, -D / 2 - 0.2)
	Build.Part(model, {
		Size = V3(entrance + 1, 4.2, 0.8),
		CFrame = signCF,
		Color = rgb(110, 70, 44),
		Material = Enum.Material.Wood,
		Name = "Sign",
		CanCollide = false,
	})
	Build.Deco(decor, { Size = V3(entrance + 1.6, 0.5, 1.2), CFrame = signCF * CF(0, 2.25, 0), Color = SNOW, Material = Enum.Material.Snow })
	Build.Deco(decor, { Size = V3(entrance + 1.6, 0.35, 1), CFrame = signCF * CF(0, -2.2, 0), Color = theme.Color })
	-- lazo gigante encima del cartel
	local bowCF = signCF * CF(0, 3.6, 0)
	for _, side in { -1, 1 } do
		local lobe = Build.Deco(decor, { Size = V3(3.6, 2.3, 1.2), CFrame = bowCF * CF(side * 1.7, 0.4, 0) * ANG(0, 0, side * 0.45), Color = theme.Color })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = lobe
	end
	Build.Ball(decor, 1.3, bowCF, { Color = theme.Color, CanCollide = false })

	-- Guirnaldas de luces sobre los muros
	local top = H + 1.4
	Build.StringLights(decor, (cf * CF(-W / 2, top, -D / 2 - 1.2)).Position, (cf * CF(-entrance / 2 - 2, top, -D / 2 - 1.2)).Position, 2.6, 0.5)
	Build.StringLights(decor, (cf * CF(entrance / 2 + 2, top, -D / 2 - 1.2)).Position, (cf * CF(W / 2, top, -D / 2 - 1.2)).Position, 2.6, 0.5, nil, 2)
	Build.StringLights(decor, (cf * CF(-W / 2 - 1.2, top, -D / 2)).Position, (cf * CF(-W / 2 - 1.2, top, D / 2)).Position, 2.8, 0.6, nil, 1)
	Build.StringLights(decor, (cf * CF(W / 2 + 1.2, top, -D / 2)).Position, (cf * CF(W / 2 + 1.2, top, D / 2)).Position, 2.8, 0.6, nil, 3)
	Build.StringLights(decor, (cf * CF(-entrance / 2 - 1, H + 4.6, -D / 2 - 0.4)).Position, (cf * CF(entrance / 2 + 1, H + 4.6, -D / 2 - 0.4)).Position, 1.6, 1.2, 0.45)

	-- Chimenea al fondo
	fireplace(decor, cf * CF(0, 0, D / 2 - 3.6))

	-- Luz cálida general
	local lightPart = Build.Deco(decor, { Size = V3(1, 1, 1), CFrame = cf * CF(0, H + 4, 0), Transparency = 1, Name = "AmbientLight" })
	Build.Light(lightPart, rgb(255, 214, 160), 44, 0.9)

	-- Huecos (pedestal + placa de cobro)
	local slots = Build.Folder(model, "Slots")
	for i = 1, 16 do
		local pedestal, pad = Layout.SlotLocal(i)
		local slot = Build.Model(slots, "Slot" .. i)
		slot:SetAttribute("Index", i)
		local pcf = cf * CF(pedestal)
		Build.Cylinder(slot, 0.3, 5.6, pcf * CF(0, 1.15, 0), {
			Color = theme.Color,
			Material = Enum.Material.Neon,
			Name = "Glow",
			CanCollide = false,
			CastShadow = false,
		})
		Build.Cylinder(slot, 1.1, 5, pcf * CF(0, 1.6, 0), {
			Color = rgb(245, 242, 236),
			Material = Enum.Material.Marble,
			Name = "Pedestal",
		})
		Build.Cylinder(slot, 0.16, 5.2, pcf * CF(0, 2.22, 0), { Color = GOLD, Material = Enum.Material.Metal, Name = "Rim", CanCollide = false })
		local padCF = cf * CF(pad)
		Build.Part(slot, {
			Size = V3(3.4, 0.3, 3.4),
			CFrame = padCF * CF(0, 1.15, 0),
			Color = rgb(40, 170, 80),
			Material = Enum.Material.SmoothPlastic,
			Name = "Pad",
			CanTouch = true,
		})
		Build.Deco(slot, {
			Size = V3(2.6, 0.32, 2.6),
			CFrame = padCF * CF(0, 1.16, 0),
			Color = rgb(90, 255, 140),
			Material = Enum.Material.Neon,
			Name = "PadGlow",
			CastShadow = false,
		})
	end

	-- Botón de bloqueo
	local buttonCF = cf * CF(0, 0, D / 2 - 10)
	Build.Cylinder(model, 0.8, 6, buttonCF * CF(0, 1.4, 0), { Color = rgb(60, 60, 72), Material = Enum.Material.Metal, Name = "LockButtonBase" })
	Build.Cylinder(model, 0.6, 4.2, buttonCF * CF(0, 2, 0), {
		Color = rgb(255, 50, 60),
		Material = Enum.Material.Neon,
		Name = "LockButton",
		CanTouch = true,
	})

	-- Escudo de bloqueo (lo activa BaseService)
	local shieldProps = {
		Color = theme.Color,
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}
	local door: any = table.clone(shieldProps)
	door.Size = V3(entrance, H + 2, 1)
	door.CFrame = cf * CF(0, 1 + (H + 2) / 2, -D / 2 + 1)
	door.Name = "LockDoor"
	Build.Part(model, door)
	local lid: any = table.clone(shieldProps)
	lid.Size = V3(W, 1, D)
	lid.CFrame = cf * CF(0, H + 2.4, 0)
	lid.Name = "LockLid"
	Build.Part(model, lid)

	-- Spawn del dueño
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = V3(6, 0.4, 6)
	spawn.CFrame = cf * CF(0, 1.2, -14) * ANG(0, math.pi, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Enabled = false
	spawn.Parent = model

	-- Zona de la base (referencia invisible para entregas y bloqueo)
	Build.Part(model, {
		Size = V3(W, Layout.Base.ZoneHeight, D),
		CFrame = cf * CF(0, Layout.Base.ZoneHeight / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Name = "Zone",
	})

	-- Exterior: felpudo, farolas, árbol y muñeco de nieve
	Build.Deco(decor, { Size = V3(entrance - 2, 0.15, 4), CFrame = cf * CF(0, 0.08, -D / 2 - 2.6), Color = theme.Color, Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Decor.CandyLamp(decor, cf * CF(side * (entrance / 2 + 4.5), 0, -D / 2 - 4) * ANG(0, if side < 0 then math.pi else 0, 0), 11)
	end
	Decor.PineTree(decor, cf * CF(-W / 2 - 6, 0, -D / 2 - 6), 0.62, true, index)
	Decor.Snowman(decor, cf * CF(W / 2 + 5, 0, -D / 2 - 6) * ANG(0, math.pi, 0), 0.75, theme.Color)

	model.PrimaryPart = structure:FindFirstChild("Floor") :: BasePart
	return model
end

return BaseBuilder
