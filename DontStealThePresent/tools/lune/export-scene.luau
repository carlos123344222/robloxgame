-- Exporta piezas a JSON para renderizarlas en Blender (tools/blender/render.py).
--   lune run tools/lune/export-scene.luau build/base.rbxl map out.json
--   lune run tools/lune/export-scene.luau build/base.rbxl presents out.json
--   lune run tools/lune/export-scene.luau build/base.rbxl hero out.json <PresentId> [Mutation]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local placePath = process.args[1] or "build/base.rbxl"
local mode = process.args[2] or "map"
local output = process.args[3] or "scene.json"

local env = harness.open(placePath)
local game = env.game
local workspace = game:GetService("Workspace")
local shared = harness.find(game, "ReplicatedStorage.Shared")
local PresentBuilder = env.require(shared.PresentBuilder)
local Presents = env.require(shared.Config.Presents)
local Mutations = env.require(shared.Config.Mutations)

local CF = roblox.CFrame
local V3 = roblox.Vector3

local parts = {}
local lights = {}

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function exportPart(part: any)
	if part.Transparency >= 0.99 then
		return
	end
	local cf = part.CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local shape = "Block"
	if part.ClassName == "WedgePart" then
		shape = "Wedge"
	elseif part.ClassName == "Part" then
		shape = part.Shape.Name
	end
	if part:FindFirstChildOfClass("SpecialMesh") then
		shape = "Ellipsoid"
	end
	local color = part.Color
	table.insert(parts, {
		s = shape,
		z = { round(part.Size.X), round(part.Size.Y), round(part.Size.Z) },
		c = { round(x), round(y), round(z), round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22) },
		k = { round(color.R), round(color.G), round(color.B) },
		m = part.Material.Name,
		t = round(part.Transparency),
		r = round(part.Reflectance),
	})
	for _, child in part:GetDescendants() do
		if child.ClassName == "PointLight" and child.Enabled ~= false then
			local position = cf.Position
			if child.Parent and child.Parent.ClassName == "Attachment" then
				position = (cf * child.Parent.CFrame).Position
			end
			table.insert(lights, {
				p = { round(position.X), round(position.Y), round(position.Z) },
				k = { round(child.Color.R), round(child.Color.G), round(child.Color.B) },
				b = round(child.Brightness),
				r = round(child.Range),
			})
		end
	end
end

local function exportTree(root: any)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			exportPart(d)
		end
	end
end

-- Coloca un regalo (las piezas soldadas se recolocan a mano, aquí no hay física)
local function placePresent(parent: any, id: string, mutation: string?, cf: any, scale: number?)
	local model = PresentBuilder.Build(id, mutation, { Scale = scale })
	PresentBuilder.PlaceAt(model, cf)
	-- las piezas de los hubs giratorios ya están colocadas por Build
	model.Parent = parent
	return model
end

local MapBuilder = env.require(harness.find(game, "ServerScriptService.Server.World.MapBuilder"))
local Layout = env.require(harness.find(game, "ServerScriptService.Server.World.Layout"))

if mode == "map" then
	local map = MapBuilder.Build(workspace)
	-- regalos de ejemplo en la cinta
	local showcase = roblox.Instance.new("Folder")
	showcase.Parent = workspace
	local beltIds = { "ClassicRed", "Sock", "HatBox", "GiftTower", "Ornament", "GingerHouse", "SnowGlobe", "Star", "Cardboard", "Drum", "MiniTree", "CandyCane", "IceCrystal", "ToySleigh", "Coal", "Mistletoe", "AuroraGift", "SantasGift" }
	local mutationsOn = { [3] = "Gold", [7] = "Diamond", [11] = "Candy", [15] = "Frost" }
	for i, id in beltIds do
		local x = -170 + i * 19
		placePresent(showcase, id, mutationsOn[i], CF.new(x, Layout.Belt.SurfaceY, 0) * CF.Angles(0, -math.pi / 2, 0))
	end
	-- dos talleres con regalos
	local baseIds = {
		{ "SantaSack", "MusicBox", "NorthChest", "Wreath", "RoyalBell", "PolarLantern", "GalaxyGift", "ChristmasCore" },
		{ "ClassicRed", "Drum", "FrostedGift", "Mistletoe", "SnowGlobe", "Ornament", "Sock", "Star" },
	}
	for b, list in baseIds do
		local baseCF = Layout.BaseCFrame(if b == 1 then 2 else 6)
		for i, id in list do
			placePresent(showcase, id, if i == 4 then "Rainbow" else nil, Layout.SlotPresentCFrame(baseCF, i) * CF.new(0, 0.4, 0))
		end
	end
	exportTree(map)
	exportTree(showcase)
elseif mode == "presents" then
	local folder = roblox.Instance.new("Folder")
	folder.Parent = workspace
	local columns = 7
	for i, info in Presents.List do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		placePresent(folder, info.Id, nil, CF.new(col * 9, 0, row * 11) * CF.Angles(0, math.pi + 0.5, 0), 1 / 1.3)
	end
	exportTree(folder)
elseif mode == "shelf" then
	-- 7 columnas x 4 filas en un plano vertical, para la vitrina con nombres
	local folder = roblox.Instance.new("Folder")
	folder.Parent = workspace
	for i, info in Presents.List do
		local col = (i - 1) % 7
		local row = math.floor((i - 1) / 7)
		local model = PresentBuilder.Build(info.Id, nil, { Scale = 1 })
		local height = model:GetAttribute("Height")
		local scale = math.min(1, 6.5 / height)
		model:Destroy()
		placePresent(folder, info.Id, nil, CF.new(col * 9, -row * 11 - 4, 0) * CF.Angles(0, math.pi + 0.55, 0), scale)
		-- peana
		local base = roblox.Instance.new("Part")
		base.Shape = roblox.Enum.PartType.Cylinder
		base.Size = V3.new(0.4, 6.5, 6.5)
		base.CFrame = CF.new(col * 9, -row * 11 - 4.2, 0) * CF.Angles(0, 0, math.pi / 2)
		base.Color = roblox.Color3.fromRGB(236, 242, 255)
		base.Material = roblox.Enum.Material.Snow
		base.Parent = folder
	end
	exportTree(folder)
	-- posiciones de los nombres para compose.py (cámara ortográfica de 66 studs de ancho a 25 px/stud)
	local Rarities = env.require(shared.Config.Rarities)
	local labels = {}
	for i, info in Presents.List do
		local col = (i - 1) % 7
		local row = math.floor((i - 1) / 7)
		local rarity = Rarities.Get(info.Rarity)
		table.insert(labels, {
			x = col * 9,
			y = -row * 11 - 4.7,
			name = info.Name,
			rarity = rarity.Name,
			color = { rarity.Color.R, rarity.Color.G, rarity.Color.B },
		})
	end
	fs.writeFile(output .. ".catalog.json", serde.encode("json", { pixelsPerStud = 25, originX = -6, originY = 6, items = labels }))
elseif mode == "icon" then
	local folder = roblox.Instance.new("Folder")
	folder.Parent = workspace
	placePresent(folder, "ClassicRed", nil, CF.new(0, 0, 0) * CF.Angles(0, math.pi + 0.6, 0), 1.9)
	placePresent(folder, "SantasGift", nil, CF.new(-5.2, 0, 3.5) * CF.Angles(0, math.pi + 0.9, 0), 0.75)
	placePresent(folder, "Star", nil, CF.new(5.4, 0, 3) * CF.Angles(0, math.pi + 0.2, 0), 0.9)
	placePresent(folder, "Mistletoe", "Candy", CF.new(3.6, 0, -2.6) * CF.Angles(0, math.pi + 0.3, 0), 0.8)
	placePresent(folder, "Ornament", "Diamond", CF.new(-3.8, 0, -2.8) * CF.Angles(0, math.pi, 0), 0.8)
	local snow = roblox.Instance.new("Part")
	snow.Shape = roblox.Enum.PartType.Cylinder
	snow.Size = V3.new(0.6, 22, 22)
	snow.CFrame = CF.new(0, -0.3, 1) * CF.Angles(0, 0, math.pi / 2)
	snow.Color = roblox.Color3.fromRGB(240, 246, 255)
	snow.Material = roblox.Enum.Material.Snow
	snow.Parent = folder
	exportTree(folder)
elseif mode == "mutations" then
	local folder = roblox.Instance.new("Folder")
	folder.Parent = workspace
	local list = { "" }
	for _, id in Mutations.Order do
		table.insert(list, id)
	end
	for i, mutation in list do
		placePresent(folder, "ClassicRed", if mutation == "" then nil else mutation, CF.new((i - 1) * 7, 0, 0) * CF.Angles(0, math.pi + 0.5, 0))
	end
	exportTree(folder)
elseif mode == "hero" then
	local folder = roblox.Instance.new("Folder")
	folder.Parent = workspace
	placePresent(folder, process.args[4] or "SantasGift", process.args[5], CF.new(0, 0, 0) * CF.Angles(0, math.pi + 0.45, 0))
	exportTree(folder)
end

fs.writeFile(output, serde.encode("json", { parts = parts, lights = lights }))
print(string.format("%s: %d piezas, %d luces -> %s", mode, #parts, #lights, output))
local _ = V3
