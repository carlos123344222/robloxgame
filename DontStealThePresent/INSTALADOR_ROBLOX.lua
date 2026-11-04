-- INSTALADOR de Don't Steal the Present.
-- Pégalo entero en la Barra de comandos de Studio (View > Command Bar) y pulsa Enter.
local function svc(path) local o = game for s in string.gmatch(path, '[^%.]+') do o = (o == game) and game:GetService(s) or o:FindFirstChild(s) end return o end
local function make(service, path, class, source)
  local parent = svc(service)
  for i = 1, #path - 1 do
    local c = parent:FindFirstChild(path[i])
    if not c then c = Instance.new('Folder') c.Name = path[i] c.Parent = parent end
    parent = c
  end
  local name = path[#path]
  local old = parent:FindFirstChild(name)
  local s = Instance.new(class)
  if old then for _, ch in old:GetChildren() do ch.Parent = s end old:Destroy() end
  s.Name = name s.Source = source s.Parent = parent
end
-- primero los contenedores principales (Script/LocalScript) para que los módulos queden dentro
make('ServerScriptService', {'Server'}, 'Script', [======[
-- Don't Steal the Present — arranque del servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
Remotes.Setup()

local World = script.World
local Services = script.Services

local Layout = require(World.Layout)
local MapBuilder = require(World.MapBuilder)
local TerrainBuilder = require(World.TerrainBuilder)
local LightingSetup = require(World.LightingSetup)
local WorldLabels = require(World.WorldLabels)

local DataService = require(Services.DataService)
local CharacterService = require(Services.CharacterService)
local BaseService = require(Services.BaseService)
local EventService = require(Services.EventService)
local ConveyorService = require(Services.ConveyorService)
local StealService = require(Services.StealService)
local GearService = require(Services.GearService)
local RebirthService = require(Services.RebirthService)
local DevCommands = require(Services.DevCommands)

-- Mundo ------------------------------------------------------------------------------------------------------
LightingSetup.Apply()

local map = workspace:FindFirstChild("Map")
if not map or map:GetAttribute("MapVersion") ~= Layout.Version then
	if map then
		map:Destroy()
	end
	local started = os.clock()
	map = MapBuilder.Build(workspace)
	print(string.format("[DSTP] Mapa construido en %.2fs (%d piezas)", os.clock() - started, MapBuilder.CountParts(map)))
end
WorldLabels.Apply(map)
task.spawn(TerrainBuilder.Build)

-- Servicios --------------------------------------------------------------------------------------------------
EventService.Init()
BaseService.Init(map)
ConveyorService.Init(map)

DataService.Start()
CharacterService.Start()
BaseService.Start()
StealService.Start()
GearService.Start()
RebirthService.Start()
ConveyorService.Start()
EventService.StartLoop()
DevCommands.Start()

-- Jugadores -------------------------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	BaseService.Assign(player)
	CharacterService.Track(player)
	GearService.Track(player)

	local offline = 0
	local connection = DataService.Loaded:Connect(function(who, _, _, offlineSeconds)
		if who == player then
			offline = offlineSeconds
		end
	end)
	local data = DataService.Load(player)
	connection:Disconnect()
	if not data or not player.Parent then
		return
	end
	BaseService.OnLoaded(player, data, offline)
	GearService.OnLoaded(player)
	DataService.MarkChanged(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Save(player, true)
	BaseService.Release(player)
	DataService.Release(player)
end)

print("[DSTP] Don't Steal the Present listo 🎁")
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client'}, 'LocalScript', [======[
-- Don't Steal the Present — arranque del cliente.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Controllers = script:WaitForChild("Controllers")
local UI = script:WaitForChild("UI")

local ClientState = require(script:WaitForChild("ClientState"))
local SoundController = require(Controllers.SoundController)
local WorldAnimator = require(Controllers.WorldAnimator)
local BaseController = require(Controllers.BaseController)
local GearController = require(Controllers.GearController)
local EffectsController = require(Controllers.EffectsController)

local Theme = require(UI.Theme)
local Notifications = require(UI.Notifications)
local Hud = require(UI.Hud)
local ShopUI = require(UI.ShopUI)
local RebirthUI = require(UI.RebirthUI)
local IndexUI = require(UI.IndexUI)
local IntroUI = require(UI.IntroUI)

local screen = Instance.new("ScreenGui")
screen.Name = "DontStealThePresent"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

SoundController.Start()
Notifications.Start(screen)
Hud.Start(screen)
ShopUI.Start(screen)
RebirthUI.Start(screen)
IndexUI.Start(screen)
IntroUI.Start(screen)

Hud.Callbacks.Shop = ShopUI.Toggle
Hud.Callbacks.Rebirth = RebirthUI.Toggle
Hud.Callbacks.Index = IndexUI.Toggle
Hud.Callbacks.Help = IntroUI.ToggleHelp

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		ShopUI.Open()
	elseif prompt.Name == "RebirthPrompt" then
		RebirthUI.Open()
	end
end)

-- atajos de teclado
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		ShopUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.R then
		RebirthUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.J then
		IndexUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.H then
		IntroUI.ToggleHelp()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		Theme.CloseAll()
	end
end)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

task.spawn(WorldAnimator.Start)
BaseController.Start()
GearController.Start()
EffectsController.Start()
ClientState.Start()
]======])
make('ReplicatedStorage', {'Shared', 'PresentBuilder'}, 'ModuleScript', [======[
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
		local cube = add(ctx, { Size = V3(w, w, w), CF = CF(), Color = colors[i], Role = "Body", Hub = hub, Reflectance = 0.1 })
		-- el Regalo Infinito siempre cambia de color
		cube:AddTag("Rainbow")
		cube:SetAttribute("HueOffset", i * 0.22)
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
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'ClientState'}, 'ModuleScript', [======[
-- Copia local de tus datos (la manda el servidor) y utilidades sobre tu base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Remotes = require(Shared.Net.Remotes)

local player = Players.LocalPlayer

local ClientState = {}

ClientState.Data = {
	Cash = 0,
	Rebirths = 0,
	Gears = {},
	Index = {},
	Stats = {},
	Presents = {},
	TutorialDone = false,
	CanSave = true,
} :: { [string]: any }
ClientState.Loaded = false
ClientState.Changed = Signal.new()

function ClientState.Start()
	Remotes.Event("DataSync").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" then
			return
		end
		ClientState.Data = snapshot
		ClientState.Loaded = true
		ClientState.Changed:Fire(snapshot)
	end)
	Remotes.Event("ClientReady"):FireServer()
end

function ClientState.Now(): number
	return workspace:GetServerTimeNow()
end

function ClientState.Map(): Instance?
	return workspace:FindFirstChild("Map")
end

function ClientState.MyBase(): Model?
	local map = ClientState.Map()
	local bases = map and map:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	local id = player:GetAttribute("BaseId")
	if type(id) == "number" then
		local base = bases:FindFirstChild("Base" .. id)
		if base and base:GetAttribute("OwnerUserId") == player.UserId then
			return base :: Model
		end
	end
	for _, base in bases:GetChildren() do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base :: Model
		end
	end
	return nil
end

function ClientState.IsMyBaseLocked(): (boolean, number)
	local base = ClientState.MyBase()
	if not base then
		return false, 0
	end
	local untilTime = (base:GetAttribute("LockedUntil") :: number?) or 0
	local remaining = untilTime - ClientState.Now()
	return remaining > 0, remaining
end

return ClientState
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Events'}, 'ModuleScript', [======[
-- Eventos globales del servidor. Cada cierto tiempo empieza uno al azar.

export type EventInfo = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Color: Color3,
	Luck: number,
	MutationChances: { [string]: number }, -- sustituyen a la probabilidad base de esas mutaciones
	SpawnRateMult: number,
}

local Events = {}

Events.Order = { "Blizzard", "Aurora", "SantaNight", "GoldRain" }

local list: { [string]: EventInfo } = {
	Blizzard = {
		Id = "Blizzard",
		Name = "❄️ ¡VENTISCA!",
		Description = "Muchos regalos salen con mutación ESCARCHA (x2.5)",
		Duration = 150,
		Color = Color3.fromRGB(170, 220, 255),
		Luck = 1.3,
		MutationChances = { Frost = 0.3 },
		SpawnRateMult = 1,
	},
	Aurora = {
		Id = "Aurora",
		Name = "🌌 AURORA BOREAL",
		Description = "Los regalos ARCOÍRIS (x5) son mucho más comunes",
		Duration = 150,
		Color = Color3.fromRGB(110, 255, 200),
		Luck = 1.5,
		MutationChances = { Rainbow = 0.05, Diamond = 0.06 },
		SpawnRateMult = 1,
	},
	SantaNight = {
		Id = "SantaNight",
		Name = "🎅 NOCHE DE SANTA",
		Description = "¡Suerte x3 en la cinta y salen regalos más rápido!",
		Duration = 150,
		Color = Color3.fromRGB(255, 90, 90),
		Luck = 3,
		MutationChances = {},
		SpawnRateMult = 1.5,
	},
	GoldRain = {
		Id = "GoldRain",
		Name = "✨ LLUVIA DE ORO",
		Description = "Llueven regalos DORADOS (x1.5) y DIAMANTE (x2)",
		Duration = 150,
		Color = Color3.fromRGB(255, 210, 70),
		Luck = 1.2,
		MutationChances = { Gold = 0.4, Diamond = 0.08 },
		SpawnRateMult = 1,
	},
}

Events.List = list

function Events.Get(id: string?): EventInfo?
	if id == nil or id == "" then
		return nil
	end
	return list[id]
end

return Events
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'GameConfig'}, 'ModuleScript', [======[
-- Números generales del juego. Todo lo que define el ritmo de una partida está aquí.

local GameConfig = {
	GameName = "Don't Steal the Present",
	GameNameEs = "¡No robes el regalo!",

	-- Economía ----------------------------------------------------------------------------------------
	StartCash = 100,
	SellRefund = 0.5, -- al vender un regalo recuperas este % de su precio
	OfflineEarningsRate = 0.2, -- % de los ingresos que generan tus regalos mientras no juegas
	OfflineEarningsMaxHours = 6,

	-- Bases -------------------------------------------------------------------------------------------
	MaxBases = 8,
	SlotsPerBase = 16,

	-- Cinta de regalos --------------------------------------------------------------------------------
	Belt = {
		Speed = 7, -- studs por segundo
		SpawnInterval = 2.3, -- segundos entre regalos
		SpawnJitter = 0.6,
		MaxItems = 30,
		StartX = -192,
		EndX = 196,
		Z = 0,
		SurfaceY = 2.6, -- altura de la superficie de la cinta
		BuyDistance = 18, -- tolerancia del servidor (el prompt aparece a 12)
		AnnounceRarity = 5, -- índice de rareza a partir del cual se anuncia al servidor (5 = Legendario)
	},

	-- Robos -------------------------------------------------------------------------------------------
	Steal = {
		HoldDuration = 1.35,
		MaxCarryTime = 75, -- segundos antes de que el regalo vuelva solo a su dueño
		CarrySpeedMult = 0.7,
		CarryJumpHeight = 5,
		StealDistance = 16,
	},

	-- Movimiento --------------------------------------------------------------------------------------
	Movement = {
		WalkSpeed = 18,
		JumpHeight = 7.5,
	},

	-- Guardado ----------------------------------------------------------------------------------------
	DataStoreName = "DontStealThePresent_v1",
	AutosaveInterval = 90,

	-- Eventos -----------------------------------------------------------------------------------------
	Events = {
		FirstDelay = 150,
		IntervalMin = 330,
		IntervalMax = 510,
	},

	-- Comandos de chat para probar (/dinero, /renacer, /evento...). Solo funcionan en Studio o para el
	-- creador del juego.
	DevCommands = true,

	-- Música de fondo: pon aquí el id de una canción navideña de la Creator Store (p. ej. "rbxassetid://123").
	-- Vacío = sin música.
	MusicSoundId = "",
	MusicVolume = 0.35,
}

return GameConfig
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Gears'}, 'ModuleScript', [======[
-- Objetos (gears) que se compran en la tienda del elfo. Se guardan para siempre.

export type GearInfo = {
	Id: string,
	Name: string, -- nombre corto que aparece en la barra de herramientas
	FullName: string,
	Price: number,
	Icon: string,
	Description: string,
	Color: Color3,
	Cooldown: number,
	-- valores específicos (no todos los usa cada gear)
	Range: number?,
	Knockback: number?,
	FreezeTime: number?,
	ProjectileSpeed: number?,
	SpeedMult: number?,
	JumpHeight: number?,
}

local Gears = {}

Gears.Order = { "CandyBat", "Snowball", "ReindeerBoots", "JingleBell", "FreezeRay" }

local list: { [string]: GearInfo } = {
	CandyBat = {
		Id = "CandyBat",
		Name = "Bastón",
		FullName = "Bastón Golpeador",
		Price = 0,
		Icon = "🍭",
		Description = "Golpea a los ladrones para que suelten el regalo. ¡Gratis para todos!",
		Color = Color3.fromRGB(230, 40, 60),
		Cooldown = 0.85,
		Range = 9.5,
		Knockback = 62,
	},
	Snowball = {
		Id = "Snowball",
		Name = "Bola de Nieve",
		FullName = "Lanzador de Bolas de Nieve",
		Price = 7500,
		Icon = "⛄",
		Description = "Lanza bolas de nieve: congelan un momento y hacen soltar el regalo.",
		Color = Color3.fromRGB(220, 240, 255),
		Cooldown = 2.2,
		FreezeTime = 1.4,
		ProjectileSpeed = 125,
		Knockback = 24,
	},
	ReindeerBoots = {
		Id = "ReindeerBoots",
		Name = "Botas de Reno",
		FullName = "Botas de Reno",
		Price = 60000,
		Icon = "🦌",
		Description = "Corre un 45% más rápido mientras las llevas equipadas.",
		Color = Color3.fromRGB(150, 95, 55),
		Cooldown = 0,
		SpeedMult = 1.45,
	},
	JingleBell = {
		Id = "JingleBell",
		Name = "Campana",
		FullName = "Campana Saltarina",
		Price = 450000,
		Icon = "🔔",
		Description = "Saltos gigantes: ¡pasa por encima de los muros!",
		Color = Color3.fromRGB(255, 205, 60),
		Cooldown = 0,
		JumpHeight = 24,
	},
	FreezeRay = {
		Id = "FreezeRay",
		Name = "Rayo de Hielo",
		FullName = "Rayo Congelador",
		Price = 8000000,
		Icon = "🧊",
		Description = "Congela por completo a quien apuntes durante 3 segundos.",
		Color = Color3.fromRGB(110, 210, 255),
		Cooldown = 9,
		Range = 150,
		FreezeTime = 3,
	},
}

Gears.List = list

function Gears.Get(id: string): GearInfo?
	return list[id]
end

return Gears
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Mutations'}, 'ModuleScript', [======[
-- Mutaciones: variantes especiales de un regalo que multiplican su precio y lo que genera.

export type MutationInfo = {
	Id: string,
	Name: string,
	Mult: number,
	Chance: number, -- probabilidad base al aparecer en la cinta (0..1)
	TextColor: Color3,
	Body: Color3?, -- color del cuerpo del regalo (nil = mantener)
	Ribbon: Color3?,
	Material: Enum.Material?,
	Reflectance: number?,
	Transparency: number?,
	Sparkle: Color3,
	Rainbow: boolean,
	Candy: boolean,
}

local Mutations = {}

Mutations.Order = { "Gold", "Diamond", "Frost", "Candy", "Rainbow" }

local list: { [string]: MutationInfo } = {
	Gold = {
		Id = "Gold",
		Name = "Dorado",
		Mult = 1.5,
		Chance = 0.06,
		TextColor = Color3.fromRGB(255, 210, 70),
		Body = Color3.fromRGB(255, 196, 54),
		Ribbon = Color3.fromRGB(190, 120, 20),
		Material = Enum.Material.Foil,
		Reflectance = 0.15,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 220, 120),
		Rainbow = false,
		Candy = false,
	},
	Diamond = {
		Id = "Diamond",
		Name = "Diamante",
		Mult = 2,
		Chance = 0.02,
		TextColor = Color3.fromRGB(120, 236, 255),
		Body = Color3.fromRGB(150, 236, 255),
		Ribbon = Color3.fromRGB(235, 252, 255),
		Material = Enum.Material.Glass,
		Reflectance = 0.35,
		Transparency = 0.12,
		Sparkle = Color3.fromRGB(200, 250, 255),
		Rainbow = false,
		Candy = false,
	},
	Frost = {
		Id = "Frost",
		Name = "Escarcha",
		Mult = 2.5,
		Chance = 0.004,
		TextColor = Color3.fromRGB(180, 226, 255),
		Body = Color3.fromRGB(176, 220, 255),
		Ribbon = Color3.fromRGB(245, 250, 255),
		Material = Enum.Material.Ice,
		Reflectance = 0.1,
		Transparency = 0.05,
		Sparkle = Color3.fromRGB(230, 245, 255),
		Rainbow = false,
		Candy = false,
	},
	Candy = {
		Id = "Candy",
		Name = "Caramelo",
		Mult = 3,
		Chance = 0.006,
		TextColor = Color3.fromRGB(255, 120, 190),
		Body = Color3.fromRGB(255, 132, 196),
		Ribbon = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 170, 220),
		Rainbow = false,
		Candy = true,
	},
	Rainbow = {
		Id = "Rainbow",
		Name = "Arcoíris",
		Mult = 5,
		Chance = 0.0015,
		TextColor = Color3.fromRGB(255, 255, 255),
		Body = nil,
		Ribbon = nil,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 255, 255),
		Rainbow = true,
		Candy = false,
	},
}

Mutations.List = list

function Mutations.Get(id: string?): MutationInfo?
	if id == nil or id == "" then
		return nil
	end
	return list[id]
end

function Mutations.Multiplier(id: string?): number
	local info = Mutations.Get(id)
	return if info then info.Mult else 1
end

function Mutations.DisplayName(id: string?): string
	local info = Mutations.Get(id)
	return if info then info.Name else "Normal"
end

return Mutations
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Presents'}, 'ModuleScript', [======[
-- Catálogo de regalos. Cada regalo tiene un modelo procedural (ver Shared/PresentBuilder) definido por
-- "Shape" y sus colores. Price = lo que cuesta en la cinta; Income = dinero por segundo que genera.

export type PresentInfo = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Weight: number, -- probabilidad relativa dentro de su rareza
	Shape: string,
	Body: Color3,
	Ribbon: Color3,
	Accent: Color3,
	Size: number,
	Flavor: string,
}

local rgb = Color3.fromRGB

local Presents = {}

local list: { PresentInfo } = {
	-- COMÚN ------------------------------------------------------------------------------------------
	{
		Id = "Sock",
		Name = "Calcetín Sorpresa",
		Rarity = "Common",
		Price = 25,
		Income = 1,
		Weight = 5,
		Shape = "Sock",
		Body = rgb(214, 38, 52),
		Ribbon = rgb(255, 255, 255),
		Accent = rgb(40, 150, 70),
		Size = 2.4,
		Flavor = "Huele un poco a chimenea.",
	},
	{
		Id = "Cardboard",
		Name = "Caja de Cartón",
		Rarity = "Common",
		Price = 60,
		Income = 2,
		Weight = 4,
		Shape = "Box",
		Body = rgb(186, 140, 92),
		Ribbon = rgb(200, 30, 40),
		Accent = rgb(255, 220, 120),
		Size = 2.4,
		Flavor = "Lo importante es lo de dentro.",
	},
	{
		Id = "Coal",
		Name = "Saco de Carbón",
		Rarity = "Common",
		Price = 110,
		Income = 4,
		Weight = 3,
		Shape = "Bag",
		Body = rgb(156, 112, 70),
		Ribbon = rgb(92, 62, 38),
		Accent = rgb(34, 34, 40),
		Size = 2.5,
		Flavor = "Para los que se portaron regular.",
	},
	{
		Id = "CandyCane",
		Name = "Bastón de Caramelo",
		Rarity = "Common",
		Price = 180,
		Income = 6,
		Weight = 2.5,
		Shape = "Cane",
		Body = rgb(255, 255, 255),
		Ribbon = rgb(225, 30, 45),
		Accent = rgb(60, 170, 90),
		Size = 2.8,
		Flavor = "Sabor menta, versión gigante.",
	},
	{
		Id = "ClassicRed",
		Name = "Regalo Rojo Clásico",
		Rarity = "Common",
		Price = 300,
		Income = 9,
		Weight = 2,
		Shape = "Box",
		Body = rgb(210, 28, 44),
		Ribbon = rgb(255, 200, 60),
		Accent = rgb(255, 230, 140),
		Size = 2.6,
		Flavor = "El de toda la vida.",
	},

	-- POCO COMÚN --------------------------------------------------------------------------------------
	{
		Id = "Mistletoe",
		Name = "Caja Muérdago",
		Rarity = "Uncommon",
		Price = 650,
		Income = 18,
		Weight = 4,
		Shape = "TallBox",
		Body = rgb(30, 140, 70),
		Ribbon = rgb(220, 30, 40),
		Accent = rgb(255, 255, 255),
		Size = 2.4,
		Flavor = "Si te pillan debajo... ¡beso!",
	},
	{
		Id = "HatBox",
		Name = "Sombrerera de Nieve",
		Rarity = "Uncommon",
		Price = 1100,
		Income = 30,
		Weight = 3,
		Shape = "Cylinder",
		Body = rgb(236, 244, 255),
		Ribbon = rgb(60, 120, 230),
		Accent = rgb(170, 210, 255),
		Size = 2.6,
		Flavor = "Dentro hay un gorro de lana muy calentito.",
	},
	{
		Id = "GiftTower",
		Name = "Torre de Regalos",
		Rarity = "Uncommon",
		Price = 1800,
		Income = 46,
		Weight = 2,
		Shape = "Stack",
		Body = rgb(230, 60, 80),
		Ribbon = rgb(255, 255, 255),
		Accent = rgb(60, 180, 110),
		Size = 2.4,
		Flavor = "Tres regalos por el precio de uno.",
	},
	{
		Id = "Ornament",
		Name = "Bola de Árbol Brillante",
		Rarity = "Uncommon",
		Price = 2800,
		Income = 70,
		Weight = 1.5,
		Shape = "Ball",
		Body = rgb(40, 110, 230),
		Ribbon = rgb(255, 215, 90),
		Accent = rgb(255, 255, 255),
		Size = 2.6,
		Flavor = "Tan brillante que te ves reflejado.",
	},

	-- RARO --------------------------------------------------------------------------------------------
	{
		Id = "GingerHouse",
		Name = "Casita de Jengibre",
		Rarity = "Rare",
		Price = 5500,
		Income = 130,
		Weight = 4,
		Shape = "House",
		Body = rgb(170, 100, 50),
		Ribbon = rgb(255, 255, 255),
		Accent = rgb(230, 40, 60),
		Size = 2.8,
		Flavor = "No te comas la puerta.",
	},
	{
		Id = "FrostedGift",
		Name = "Regalo Escarchado",
		Rarity = "Rare",
		Price = 9500,
		Income = 215,
		Weight = 3,
		Shape = "FrostBox",
		Body = rgb(120, 190, 255),
		Ribbon = rgb(240, 250, 255),
		Accent = rgb(200, 235, 255),
		Size = 2.7,
		Flavor = "Recién sacado del Polo Norte.",
	},
	{
		Id = "SnowGlobe",
		Name = "Globo de Nieve",
		Rarity = "Rare",
		Price = 16000,
		Income = 340,
		Weight = 2,
		Shape = "Globe",
		Body = rgb(120, 70, 40),
		Ribbon = rgb(220, 30, 50),
		Accent = rgb(40, 150, 80),
		Size = 2.8,
		Flavor = "Agítalo y nieva dentro.",
	},
	{
		Id = "Drum",
		Name = "Tambor Cascanueces",
		Rarity = "Rare",
		Price = 26000,
		Income = 520,
		Weight = 1.5,
		Shape = "Drum",
		Body = rgb(200, 24, 40),
		Ribbon = rgb(255, 200, 50),
		Accent = rgb(255, 255, 255),
		Size = 2.7,
		Flavor = "¡Pom, pom, pom!",
	},

	-- ÉPICO -------------------------------------------------------------------------------------------
	{
		Id = "SantaSack",
		Name = "Saco de Santa",
		Rarity = "Epic",
		Price = 55000,
		Income = 1050,
		Weight = 4,
		Shape = "Sack",
		Body = rgb(200, 30, 40),
		Ribbon = rgb(255, 210, 70),
		Accent = rgb(60, 170, 90),
		Size = 2.9,
		Flavor = "Pesa más de lo que parece.",
	},
	{
		Id = "MusicBox",
		Name = "Caja Musical Dorada",
		Rarity = "Epic",
		Price = 95000,
		Income = 1750,
		Weight = 3,
		Shape = "MusicBox",
		Body = rgb(110, 20, 60),
		Ribbon = rgb(255, 205, 80),
		Accent = rgb(255, 240, 245),
		Size = 2.7,
		Flavor = "Toca villancicos cuando nadie mira.",
	},
	{
		Id = "MiniTree",
		Name = "Árbol en Miniatura",
		Rarity = "Epic",
		Price = 160000,
		Income = 2700,
		Weight = 2,
		Shape = "Tree",
		Body = rgb(30, 130, 70),
		Ribbon = rgb(255, 215, 60),
		Accent = rgb(230, 40, 60),
		Size = 3,
		Flavor = "Viene con sus propias lucecitas.",
	},
	{
		Id = "AuroraGift",
		Name = "Regalo Aurora",
		Rarity = "Epic",
		Price = 260000,
		Income = 4100,
		Weight = 1.5,
		Shape = "AuroraBox",
		Body = rgb(30, 40, 90),
		Ribbon = rgb(90, 255, 200),
		Accent = rgb(180, 100, 255),
		Size = 2.8,
		Flavor = "Brilla como el cielo del norte.",
	},

	-- LEGENDARIO --------------------------------------------------------------------------------------
	{
		Id = "Star",
		Name = "Estrella de la Punta",
		Rarity = "Legendary",
		Price = 550000,
		Income = 8500,
		Weight = 4,
		Shape = "Star",
		Body = rgb(255, 210, 60),
		Ribbon = rgb(255, 250, 200),
		Accent = rgb(255, 160, 30),
		Size = 3,
		Flavor = "La que corona el árbol más alto.",
	},
	{
		Id = "NorthChest",
		Name = "Cofre del Polo Norte",
		Rarity = "Legendary",
		Price = 950000,
		Income = 14500,
		Weight = 3,
		Shape = "Chest",
		Body = rgb(120, 70, 40),
		Ribbon = rgb(255, 200, 60),
		Accent = rgb(120, 220, 255),
		Size = 2.9,
		Flavor = "Guardado bajo siete capas de hielo.",
	},
	{
		Id = "Wreath",
		Name = "Corona de Navidad",
		Rarity = "Legendary",
		Price = 1700000,
		Income = 25500,
		Weight = 2,
		Shape = "Wreath",
		Body = rgb(26, 120, 60),
		Ribbon = rgb(220, 25, 45),
		Accent = rgb(255, 215, 70),
		Size = 3,
		Flavor = "Huele a pino recién cortado.",
	},
	{
		Id = "ToySleigh",
		Name = "Trineo de Juguete",
		Rarity = "Legendary",
		Price = 3100000,
		Income = 46000,
		Weight = 1.5,
		Shape = "Sleigh",
		Body = rgb(200, 25, 40),
		Ribbon = rgb(255, 205, 60),
		Accent = rgb(255, 255, 255),
		Size = 3,
		Flavor = "Una réplica exacta del de Santa.",
	},

	-- MÍTICO ------------------------------------------------------------------------------------------
	{
		Id = "IceCrystal",
		Name = "Cristal de Hielo Eterno",
		Rarity = "Mythic",
		Price = 6500000,
		Income = 92000,
		Weight = 4,
		Shape = "Crystal",
		Body = rgb(140, 220, 255),
		Ribbon = rgb(230, 250, 255),
		Accent = rgb(60, 160, 255),
		Size = 3.1,
		Flavor = "Nunca se derrite. Nunca.",
	},
	{
		Id = "RoyalBell",
		Name = "Campana de Oro Real",
		Rarity = "Mythic",
		Price = 12500000,
		Income = 172000,
		Weight = 3,
		Shape = "Bell",
		Body = rgb(255, 196, 50),
		Ribbon = rgb(210, 25, 45),
		Accent = rgb(40, 140, 70),
		Size = 3.1,
		Flavor = "Su campanada se oye en todo el Polo.",
	},
	{
		Id = "PolarLantern",
		Name = "Farol Polar",
		Rarity = "Mythic",
		Price = 23000000,
		Income = 305000,
		Weight = 2,
		Shape = "Lantern",
		Body = rgb(40, 50, 70),
		Ribbon = rgb(255, 205, 80),
		Accent = rgb(255, 150, 40),
		Size = 3.1,
		Flavor = "Su llama guía a los renos en la tormenta.",
	},
	{
		Id = "GalaxyGift",
		Name = "Regalo Galáctico",
		Rarity = "Mythic",
		Price = 42000000,
		Income = 520000,
		Weight = 1.5,
		Shape = "Galaxy",
		Body = rgb(26, 14, 60),
		Ribbon = rgb(150, 90, 255),
		Accent = rgb(90, 220, 255),
		Size = 3,
		Flavor = "Lo envían desde otra galaxia.",
	},

	-- SECRETO -----------------------------------------------------------------------------------------
	{
		Id = "SantasGift",
		Name = "El Regalo de Santa",
		Rarity = "Secret",
		Price = 110000000,
		Income = 1250000,
		Weight = 4,
		Shape = "Royal",
		Body = rgb(255, 200, 50),
		Ribbon = rgb(200, 20, 40),
		Accent = rgb(255, 255, 255),
		Size = 3.2,
		Flavor = "El que Santa guardaba para sí mismo.",
	},
	{
		Id = "ChristmasCore",
		Name = "Núcleo de la Navidad",
		Rarity = "Secret",
		Price = 380000000,
		Income = 4200000,
		Weight = 2.5,
		Shape = "Core",
		Body = rgb(255, 80, 90),
		Ribbon = rgb(255, 230, 120),
		Accent = rgb(120, 255, 180),
		Size = 3.2,
		Flavor = "Dicen que es el corazón de toda la Navidad.",
	},
	{
		Id = "InfiniteGift",
		Name = "Regalo Infinito",
		Rarity = "Secret",
		Price = 1100000000,
		Income = 10500000,
		Weight = 1,
		Shape = "Infinite",
		Body = rgb(255, 255, 255),
		Ribbon = rgb(255, 80, 120),
		Accent = rgb(80, 200, 255),
		Size = 3.2,
		Flavor = "Lo abres... y dentro hay otro. Y otro. Y otro...",
	},
}

local byId: { [string]: PresentInfo } = {}
local byRarity: { [string]: { PresentInfo } } = {}
for _, info in list do
	assert(byId[info.Id] == nil, "Regalo duplicado: " .. info.Id)
	byId[info.Id] = info
	byRarity[info.Rarity] = byRarity[info.Rarity] or {}
	table.insert(byRarity[info.Rarity], info)
end

Presents.List = list
Presents.ById = byId
Presents.ByRarity = byRarity

function Presents.Get(id: string): PresentInfo?
	return byId[id]
end

return Presents
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Rarities'}, 'ModuleScript', [======[
-- Rarezas de los regalos. "Weight" es la probabilidad relativa de que salga en la cinta.

export type RarityInfo = {
	Id: string,
	Index: number,
	Name: string,
	Color: Color3,
	Dark: Color3,
	Weight: number,
	Scale: number, -- tamaño del regalo respecto a uno común
	Light: boolean,
	Sparkles: boolean,
	Beam: boolean, -- pilar de luz sobre el regalo en la cinta
	Rainbow: boolean,
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local list: { [string]: RarityInfo } = {
	Common = {
		Id = "Common",
		Index = 1,
		Name = "Común",
		Color = Color3.fromRGB(214, 222, 232),
		Dark = Color3.fromRGB(96, 104, 118),
		Weight = 56,
		Scale = 1,
		Light = false,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Uncommon = {
		Id = "Uncommon",
		Index = 2,
		Name = "Poco común",
		Color = Color3.fromRGB(96, 226, 118),
		Dark = Color3.fromRGB(24, 110, 52),
		Weight = 26,
		Scale = 1.08,
		Light = false,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Rare = {
		Id = "Rare",
		Index = 3,
		Name = "Raro",
		Color = Color3.fromRGB(72, 168, 255),
		Dark = Color3.fromRGB(18, 70, 160),
		Weight = 11.5,
		Scale = 1.18,
		Light = true,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Epic = {
		Id = "Epic",
		Index = 4,
		Name = "Épico",
		Color = Color3.fromRGB(190, 104, 255),
		Dark = Color3.fromRGB(84, 30, 150),
		Weight = 4.6,
		Scale = 1.3,
		Light = true,
		Sparkles = true,
		Beam = false,
		Rainbow = false,
	},
	Legendary = {
		Id = "Legendary",
		Index = 5,
		Name = "Legendario",
		Color = Color3.fromRGB(255, 196, 46),
		Dark = Color3.fromRGB(150, 90, 0),
		Weight = 1.5,
		Scale = 1.42,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = false,
	},
	Mythic = {
		Id = "Mythic",
		Index = 6,
		Name = "Mítico",
		Color = Color3.fromRGB(255, 70, 104),
		Dark = Color3.fromRGB(140, 0, 40),
		Weight = 0.33,
		Scale = 1.56,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = false,
	},
	Secret = {
		Id = "Secret",
		Index = 7,
		Name = "SECRETO",
		Color = Color3.fromRGB(255, 255, 255),
		Dark = Color3.fromRGB(20, 20, 30),
		Weight = 0.07,
		Scale = 1.72,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = true,
	},
}

Rarities.List = list

function Rarities.Get(id: string): RarityInfo
	return list[id] or list.Common
end

-- Pesos ajustados por la suerte: las rarezas altas se multiplican más que las bajas.
function Rarities.WeightWithLuck(id: string, luck: number): number
	local info = Rarities.Get(id)
	if luck <= 1 then
		return info.Weight
	end
	return info.Weight * luck ^ ((info.Index - 1) / 2)
end

return Rarities
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Rebirths'}, 'ModuleScript', [======[
-- Renacimientos: reinician tu dinero y tus regalos a cambio de mejoras permanentes.

local Rarities = require(script.Parent.Rarities)

local Rebirths = {}

Rebirths.Max = 12
Rebirths.IncomeBonus = 0.5 -- +50% de ingresos por cada renacimiento
Rebirths.BaseSlots = 8
Rebirths.SlotsPerRebirth = 2
Rebirths.MaxSlots = 16
Rebirths.LockBase = 60
Rebirths.LockPerRebirth = 6
Rebirths.LockMax = 120

local REQUIRED_RARITY = { "Rare", "Epic", "Legendary", "Legendary", "Mythic", "Mythic", "Secret" }

export type Requirement = {
	Level: number, -- renacimiento que se conseguiría
	Cost: number,
	Rarity: string, -- rareza mínima que tienes que tener en tu base
	RarityName: string,
}

function Rebirths.Requirement(current: number): Requirement?
	if current >= Rebirths.Max then
		return nil
	end
	local rarity = REQUIRED_RARITY[math.min(current + 1, #REQUIRED_RARITY)]
	return {
		Level = current + 1,
		Cost = 1000000 * 6 ^ current,
		Rarity = rarity,
		RarityName = Rarities.Get(rarity).Name,
	}
end

function Rebirths.IncomeMultiplier(rebirths: number): number
	return 1 + Rebirths.IncomeBonus * rebirths
end

function Rebirths.SlotCount(rebirths: number): number
	return math.min(Rebirths.MaxSlots, Rebirths.BaseSlots + Rebirths.SlotsPerRebirth * rebirths)
end

function Rebirths.LockDuration(rebirths: number): number
	return math.min(Rebirths.LockMax, Rebirths.LockBase + Rebirths.LockPerRebirth * rebirths)
end

-- Renacimiento necesario para desbloquear un hueco concreto (1..16).
function Rebirths.SlotRequirement(slotIndex: number): number
	if slotIndex <= Rebirths.BaseSlots then
		return 0
	end
	return math.ceil((slotIndex - Rebirths.BaseSlots) / Rebirths.SlotsPerRebirth)
end

return Rebirths
]======])
make('ReplicatedStorage', {'Shared', 'Config', 'Sounds'}, 'ModuleScript', [======[
-- Sonidos del juego. Por defecto usan sonidos que vienen incluidos con el cliente de Roblox
-- (rbxasset://), así funcionan sin subir nada. Puedes cambiarlos por "rbxassetid://<id>" de la Creator Store.

export type SoundInfo = { Id: string, Volume: number, Pitch: number }

local Sounds: { [string]: SoundInfo } = {
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.15 },
	Collect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.6 },
	NoMoney = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Pitch = 0.6 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Pitch = 1.3 },
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.55, Pitch = 1.1 },
	Hit = { Id = "rbxasset://sounds/collide.wav", Volume = 0.9, Pitch = 0.9 },
	Throw = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 1.5 },
	SnowHit = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.7, Pitch = 1.4 },
	Freeze = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.6, Pitch = 1.4 },
	Zap = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.5, Pitch = 1.6 },
	Lock = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.9, Pitch = 0.8 },
	Unlock = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.7, Pitch = 1.3 },
	Steal = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.8, Pitch = 1.2 },
	Alarm = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Pitch = 0.55 },
	Success = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 },
	Fail = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.5, Pitch = 1 },
	Event = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 0.8 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.8, Pitch = 1.1 },
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.6, Pitch = 1.4 },
	Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.9 },
}

return Sounds
]======])
make('ReplicatedStorage', {'Shared', 'Net', 'Remotes'}, 'ModuleScript', [======[
-- Remotes del juego. El servidor los crea en ReplicatedStorage.Remotes; el cliente los espera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	"DataSync", -- servidor -> cliente: copia de tus datos (dinero, gears, índice...)
	"Notify", -- servidor -> cliente: mensaje (texto, tipo)
	"Fx", -- servidor -> clientes: efectos visuales y sonidos
	"Knockback", -- servidor -> cliente: empujón al recibir un golpe
	"UseGear", -- cliente -> servidor: usar un gear con puntería (bola de nieve, rayo)
	"Alert", -- servidor -> cliente: ¡te están robando!
	"ClientReady", -- cliente -> servidor: la interfaz está lista para recibir datos
}

Remotes.Functions = {
	"BuyGear",
	"Rebirth",
}

local FOLDER_NAME = "Remotes"

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup solo en el servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Remotes.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
]======])
make('ReplicatedStorage', {'Shared', 'Util', 'CFrameUtil'}, 'ModuleScript', [======[
-- CFrame.lookAt seguro: si la dirección es casi vertical usa otro vector "arriba" para no generar NaN.

local CFrameUtil = {}

function CFrameUtil.LookAt(from: Vector3, to: Vector3): CFrame
	local direction = to - from
	if direction.Magnitude < 1e-6 then
		return CFrame.new(from)
	end
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	return CFrame.lookAt(from, to, up)
end

return CFrameUtil
]======])
make('ReplicatedStorage', {'Shared', 'Util', 'Format'}, 'ModuleScript', [======[
-- Formato de números y tiempos para la interfaz: 1250 -> "1.25K", 3600000 -> "3.6M"...

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.Number(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		if n == math.floor(n) or n >= 100 then
			return sign .. tostring(math.floor(n))
		end
		return sign .. trimZeros(string.format("%.1f", math.floor(n * 10 + 1e-6) / 10))
	end
	local tier = 0
	local scaled = n
	while scaled >= 1000 and tier < #SUFFIXES - 1 do
		scaled /= 1000
		tier += 1
	end
	local text
	if scaled >= 100 then
		text = tostring(math.floor(scaled + 1e-9))
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(scaled * 10 + 1e-6) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(scaled * 100 + 1e-6) / 100))
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.Cash(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Income(n: number): string
	return "$" .. Format.Number(n) .. "/s"
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if n < 0 then "-" else "") .. out
end

-- 75 -> "1:15", 9 -> "0:09"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 3700 -> "1h 1m", 75 -> "1m 15s"
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
]======])
make('ReplicatedStorage', {'Shared', 'Util', 'Gui'}, 'ModuleScript', [======[
-- Ayudas para crear interfaces por código (servidor: carteles y billboards; cliente: HUD y menús).

local Gui = {}

Gui.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Bold = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}

function Gui.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Gui.Corner(radius: number?): UICorner
	return Gui.Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Gui.CornerScale(scale: number): UICorner
	return Gui.Create("UICorner", { CornerRadius = UDim.new(scale, 0) })
end

function Gui.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Gui.Create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Gui.BorderStroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Gui.Create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Gui.Gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Gui.Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Gui.RainbowGradient(): UIGradient
	return Gui.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 120)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
		}),
	})
end

-- Texto con borde negro estilo cartoon
function Gui.Label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Gui.Fonts.Bold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	local strokeThickness = base.StrokeThickness
	base.StrokeThickness = nil
	local label = Gui.Create("TextLabel", base)
	if strokeThickness ~= 0 then
		Gui.Stroke(Color3.new(0, 0, 0), strokeThickness or 2).Parent = label
	end
	return label
end

function Gui.Padding(px: number): UIPadding
	return Gui.Create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Gui.List(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return Gui.Create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Billboard básico en studs (se hace más pequeño con la distancia)
function Gui.Billboard(parent: Instance, sizeStuds: Vector2, offset: Vector3, maxDistance: number?): BillboardGui
	return Gui.Create("BillboardGui", {
		Size = UDim2.new(sizeStuds.X, 0, sizeStuds.Y, 0),
		StudsOffsetWorldSpace = offset,
		MaxDistance = maxDistance or 80,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Parent = parent,
	})
end

return Gui
]======])
make('ReplicatedStorage', {'Shared', 'Util', 'Rng'}, 'ModuleScript', [======[
-- Generador pseudoaleatorio determinista (mismo resultado con la misma semilla). Se usa para decorar el
-- mapa siempre igual y para que la lógica pueda probarse fuera de Roblox.

export type Rng = {
	Next: (self: Rng) -> number,
	Range: (self: Rng, min: number, max: number) -> number,
	Int: (self: Rng, min: number, max: number) -> number,
	Pick: <T>(self: Rng, list: { T }) -> T,
	state: number,
}

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number?): Rng
	local self = setmetatable({}, Rng) :: any
	self.state = math.floor(seed or (os.clock() * 1000003)) % 2147483647
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end

-- Park–Miller "minimal standard" (cabe sin problemas en un double).
function Rng:Next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end

function Rng:Range(min: number, max: number): number
	return min + (max - min) * self:Next()
end

function Rng:Int(min: number, max: number): number
	return math.min(max, min + math.floor(self:Next() * (max - min + 1)))
end

function Rng:Pick<T>(list: { T }): T
	return list[self:Int(1, #list)]
end

return Rng
]======])
make('ReplicatedStorage', {'Shared', 'Util', 'Signal'}, 'ModuleScript', [======[
-- Señal mínima (Connect / Fire / Once) para comunicar módulos sin crear dependencias circulares.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	_handlers: { [any]: (...any) -> () },
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if self.Connected then
		self.Connected = false
		self._signal._handlers[self] = nil
	end
end

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal:Connect(fn: (...any) -> ())
	local connection = setmetatable({ Connected = true, _signal = self }, Connection)
	self._handlers[connection] = fn
	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	for connection, fn in self._handlers do
		if connection.Connected then
			task.spawn(fn, ...)
		end
	end
end

return Signal
]======])
make('ServerScriptService', {'Server', 'Services', 'BaseService'}, 'ModuleScript', [======[
-- Bases de los jugadores: asignación, regalos en los pedestales, dinero acumulado, cobro, bloqueo, venta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Rebirths = require(Shared.Config.Rebirths)
local PresentBuilder = require(Shared.PresentBuilder)
local Format = require(Shared.Util.Format)
local Gui = require(Shared.Util.Gui)
local Signal = require(Shared.Util.Signal)
local Remotes = require(Shared.Net.Remotes)

local World = script.Parent.Parent.World
local Layout = require(World.Layout)
local PresentDisplay = require(World.PresentDisplay)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)

export type PresentRecord = {
	Id: string,
	Mutation: string?,
	Stored: number,
	Model: Model?,
	BeingStolen: boolean,
}

export type SlotRecord = {
	Index: number,
	Model: Model,
	Pedestal: BasePart,
	Pad: BasePart,
	PadGlow: BasePart?,
	Glow: BasePart?,
	PadLabel: TextLabel,
	LockGui: BillboardGui,
	LockLabel: TextLabel,
	AlertGui: BillboardGui,
	Present: PresentRecord?,
	Unlocked: boolean,
	LastCollect: number,
}

export type BaseRecord = {
	Id: number,
	Model: Model,
	CFrame: CFrame,
	Owner: Player?,
	Slots: { SlotRecord },
	LockedUntil: number,
	LockDoor: BasePart,
	LockLid: BasePart,
	LockButton: BasePart,
	ButtonLabel: TextLabel,
	SignTitle: TextLabel,
	SignSub: TextLabel,
	HeadName: TextLabel,
	HeadStatus: TextLabel,
	Spawn: SpawnLocation?,
	Theme: Color3,
}

local BaseService = {}

BaseService.Releasing = Signal.new() -- (base, owner): el dueño se va; hay que cancelar robos de esa base
BaseService.Cleared = Signal.new() -- (base): se han quitado todos los regalos (renacer)

local bases: { BaseRecord } = {}
local playerBase: { [Player]: BaseRecord } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "Info")
end

local function fx(player: Player?, kind: string, payload: { [string]: any })
	if player then
		Remotes.Event("Fx"):FireClient(player, kind, payload)
	else
		Remotes.Event("Fx"):FireAllClients(kind, payload)
	end
end

-- Interfaz de cada base -----------------------------------------------------------------------------

local function makeSign(base: BaseRecord, sign: BasePart)
	local surface = Gui.Create("SurfaceGui", {
		Name = "SignGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = sign,
	})
	local frame = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = surface })
	Gui.Padding(8).Parent = frame
	base.SignTitle = Gui.Label({
		Text = "LIBRE",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 0.62),
		TextColor3 = Color3.fromRGB(255, 240, 200),
		StrokeThickness = 3,
		Parent = frame,
	})
	base.SignSub = Gui.Label({
		Text = "Taller " .. base.Model:GetAttribute("ThemeName"),
		Font = Gui.Fonts.Bold,
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.38),
		TextColor3 = base.Theme,
		StrokeThickness = 2,
		Parent = frame,
	})

	local head = Gui.Create("BillboardGui", {
		Name = "OwnerGui",
		Size = UDim2.new(0, 280, 0, 74),
		StudsOffsetWorldSpace = Vector3.new(0, 9, 0),
		MaxDistance = 420,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Parent = sign,
	})
	base.HeadName = Gui.Label({
		Text = "",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 0.58),
		StrokeThickness = 3,
		Parent = head,
	})
	base.HeadStatus = Gui.Label({
		Text = "",
		Font = Gui.Fonts.Bold,
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.42),
		TextColor3 = Color3.fromRGB(160, 255, 170),
		StrokeThickness = 2,
		Parent = head,
	})
end

local function makeButtonLabel(base: BaseRecord)
	local billboard = Gui.Billboard(base.LockButton, Vector2.new(7, 2.6), Vector3.new(0, 2.6, 0), 70)
	billboard.Name = "ButtonGui"
	base.ButtonLabel = Gui.Label({
		Text = "",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 120, 120),
		StrokeThickness = 3,
		Parent = billboard,
	})
end

local function makeSlotGuis(slot: SlotRecord)
	local padGui = Gui.Billboard(slot.Pad, Vector2.new(4.6, 1.5), Vector3.new(0, 1.4, 0), 55)
	padGui.Name = "PadGui"
	slot.PadLabel = Gui.Label({
		Text = "",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(120, 255, 130),
		StrokeThickness = 2,
		Parent = padGui,
	})
	local lockGui = Gui.Billboard(slot.Pedestal, Vector2.new(6, 2.2), Vector3.new(0, 2.6, 0), 60)
	lockGui.Name = "LockGui"
	lockGui.Enabled = false
	slot.LockGui = lockGui
	slot.LockLabel = Gui.Label({
		Text = "🔒",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(200, 210, 230),
		StrokeThickness = 2,
		Parent = lockGui,
	})
	local alert = Gui.Billboard(slot.Pedestal, Vector2.new(8, 2.4), Vector3.new(0, 6.5, 0), 120)
	alert.Name = "AlertGui"
	alert.Enabled = false
	alert.AlwaysOnTop = true
	slot.AlertGui = alert
	Gui.Label({
		Text = "⚠️ ¡ROBANDO!",
		Font = Gui.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 70, 70),
		StrokeThickness = 3,
		Parent = alert,
	})
end

local function setShield(base: BaseRecord, locked: boolean)
	base.LockDoor.Transparency = if locked then 0.15 else 1
	base.LockLid.Transparency = if locked then 0.55 else 1
	base.LockButton.Color = if locked then Color3.fromRGB(90, 255, 130) else Color3.fromRGB(255, 50, 60)
end

-- Información ---------------------------------------------------------------------------------------

function BaseService.GetBase(player: Player): BaseRecord?
	return playerBase[player]
end

function BaseService.GetBaseById(id: number): BaseRecord?
	return bases[id]
end

function BaseService.All(): { BaseRecord }
	return bases
end

function BaseService.IsLocked(base: BaseRecord): boolean
	return base.LockedUntil > now()
end

function BaseService.IsInside(base: BaseRecord, position: Vector3, margin: number?): boolean
	local rel = base.CFrame:PointToObjectSpace(position)
	local m = margin or 0
	return math.abs(rel.X) <= Layout.Base.Width / 2 + m
		and math.abs(rel.Z) <= Layout.Base.Depth / 2 + m
		and rel.Y > -6
		and rel.Y < Layout.Base.ZoneHeight + 6
end

function BaseService.FindFreeSlot(base: BaseRecord): number?
	for _, slot in base.Slots do
		if slot.Unlocked and slot.Present == nil then
			return slot.Index
		end
	end
	return nil
end

function BaseService.IncomeMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	return Rebirths.IncomeMultiplier(data.Rebirths)
end

function BaseService.PresentIncome(player: Player, presentId: string, mutation: string?): number
	return PresentDisplay.BaseIncome(presentId, mutation) * BaseService.IncomeMultiplier(player)
end

function BaseService.TotalIncome(base: BaseRecord): number
	local owner = base.Owner
	if not owner then
		return 0
	end
	local total = 0
	for _, slot in base.Slots do
		local present = slot.Present
		if present and not present.BeingStolen then
			total += BaseService.PresentIncome(owner, present.Id, present.Mutation)
		end
	end
	return total
end

-- ¿Tiene el jugador en su base algún regalo de esta rareza o mejor?
function BaseService.HasRarity(player: Player, rarityId: string): boolean
	local base = playerBase[player]
	if not base then
		return false
	end
	local needed = Rarities.Get(rarityId).Index
	for _, slot in base.Slots do
		local present = slot.Present
		if present and not present.BeingStolen then
			local info = Presents.Get(present.Id)
			if info and Rarities.Get(info.Rarity).Index >= needed then
				return true
			end
		end
	end
	return false
end

local function refreshIncome(base: BaseRecord)
	local owner = base.Owner
	if owner then
		owner:SetAttribute("Income", BaseService.TotalIncome(base))
	end
end

-- Regalos en los pedestales -------------------------------------------------------------------------

local function saveSlot(base: BaseRecord, slot: SlotRecord)
	local owner = base.Owner
	if not owner then
		return
	end
	local data = DataService.Get(owner)
	if not data then
		return
	end
	local present = slot.Present
	if present then
		data.Presents[tostring(slot.Index)] = { Id = present.Id, Mutation = present.Mutation, Stored = present.Stored }
	else
		data.Presents[tostring(slot.Index)] = nil
	end
end

local function spawnModel(base: BaseRecord, slot: SlotRecord, fromPosition: Vector3?)
	local present = slot.Present
	local owner = base.Owner
	if not present or not owner then
		return
	end
	if present.Model then
		present.Model:Destroy()
		present.Model = nil
	end
	local info = Presents.Get(present.Id)
	if not info then
		return
	end
	local model = PresentBuilder.Build(present.Id, present.Mutation)
	PresentBuilder.PlaceAt(model, Layout.SlotPresentCFrame(base.CFrame, slot.Index))
	model.Name = "Present"
	model:SetAttribute("Mode", "Slot")
	model:SetAttribute("BaseId", base.Id)
	model:SetAttribute("SlotIndex", slot.Index)
	model:SetAttribute("OwnerUserId", owner.UserId)
	if fromPosition then
		model:SetAttribute("ArriveFrom", fromPosition)
		model:SetAttribute("ArriveT", now())
	end
	PresentDisplay.Slot(model, present.Id, present.Mutation, BaseService.PresentIncome(owner, present.Id, present.Mutation))
	local root = model.PrimaryPart :: BasePart
	local mid = root:FindFirstChild("Mid") :: Attachment
	PresentDisplay.Prompt(mid, {
		Name = "StealPrompt",
		ActionText = "Robar",
		ObjectText = info.Name,
		HoldDuration = GameConfig.Steal.HoldDuration,
		MaxActivationDistance = 9,
		KeyboardKeyCode = Enum.KeyCode.E,
	})
	local refund = math.floor(PresentDisplay.Price(present.Id, present.Mutation) * GameConfig.SellRefund)
	PresentDisplay.Prompt(mid, {
		Name = "SellPrompt",
		ActionText = "Vender +" .. Format.Cash(refund),
		ObjectText = info.Name,
		HoldDuration = 1.1,
		MaxActivationDistance = 9,
		KeyboardKeyCode = Enum.KeyCode.F,
		UIOffset = Vector2.new(0, 60),
	})
	model.Parent = slot.Model
	present.Model = model
end

function BaseService.PlacePresent(base: BaseRecord, slotIndex: number, presentId: string, mutation: string?, options: { Stored: number?, From: Vector3? }?)
	local slot = base.Slots[slotIndex]
	assert(slot, "Hueco inválido")
	local opts = options or {}
	if slot.Present and slot.Present.Model then
		slot.Present.Model:Destroy()
	end
	slot.Present = {
		Id = presentId,
		Mutation = if mutation == "" then nil else mutation,
		Stored = opts.Stored or 0,
		Model = nil,
		BeingStolen = false,
	}
	spawnModel(base, slot, opts.From)
	saveSlot(base, slot)
	slot.AlertGui.Enabled = false
	refreshIncome(base)
	if base.Owner then
		DataService.MarkChanged(base.Owner)
	end
end

function BaseService.RemovePresent(base: BaseRecord, slotIndex: number): PresentRecord?
	local slot = base.Slots[slotIndex]
	if not slot or not slot.Present then
		return nil
	end
	local present = slot.Present :: PresentRecord
	if present.Model then
		present.Model:Destroy()
		present.Model = nil
	end
	slot.Present = nil
	slot.AlertGui.Enabled = false
	slot.PadLabel.Text = ""
	saveSlot(base, slot)
	refreshIncome(base)
	if base.Owner then
		DataService.MarkChanged(base.Owner)
	end
	return present
end

-- El regalo deja el pedestal porque alguien lo está robando
function BaseService.MarkStealing(base: BaseRecord, slotIndex: number): PresentRecord?
	local slot = base.Slots[slotIndex]
	local present = slot and slot.Present
	if not present or present.BeingStolen then
		return nil
	end
	present.BeingStolen = true
	if present.Model then
		present.Model:Destroy()
		present.Model = nil
	end
	slot.AlertGui.Enabled = true
	refreshIncome(base)
	return present
end

-- El robo falló: el regalo vuelve a su pedestal
function BaseService.RestorePresent(base: BaseRecord, slotIndex: number, fromPosition: Vector3?)
	local slot = base.Slots[slotIndex]
	local present = slot and slot.Present
	if not present then
		return
	end
	present.BeingStolen = false
	slot.AlertGui.Enabled = false
	spawnModel(base, slot, fromPosition)
	refreshIncome(base)
end

function BaseService.ClearPresents(base: BaseRecord)
	BaseService.Cleared:Fire(base)
	for _, slot in base.Slots do
		if slot.Present then
			BaseService.RemovePresent(base, slot.Index)
		end
	end
end

-- Huecos desbloqueados según renacimientos
function BaseService.RefreshSlots(base: BaseRecord)
	local owner = base.Owner
	local data = owner and DataService.Get(owner)
	local rebirths = if data then data.Rebirths else 0
	local count = Rebirths.SlotCount(rebirths)
	for _, slot in base.Slots do
		local unlocked = slot.Index <= count
		slot.Unlocked = unlocked
		slot.Pedestal.Transparency = if unlocked then 0 else 0.55
		slot.Pad.Transparency = if unlocked then 0 else 0.8
		if slot.PadGlow then
			slot.PadGlow.Transparency = if unlocked then 0 else 1
		end
		if slot.Glow then
			slot.Glow.Transparency = if unlocked then 0 else 0.7
		end
		slot.LockGui.Enabled = owner ~= nil and not unlocked
		slot.LockLabel.Text = "🔒 Renacer " .. Rebirths.SlotRequirement(slot.Index)
	end
end

-- Dinero ----------------------------------------------------------------------------------------------

function BaseService.Collect(base: BaseRecord, slot: SlotRecord)
	local owner = base.Owner
	local present = slot.Present
	if not owner or not present then
		return
	end
	local amount = math.floor(present.Stored)
	if amount < 1 then
		return
	end
	present.Stored -= amount
	slot.PadLabel.Text = Format.Cash(present.Stored)
	DataService.AddCash(owner, amount)
	DataService.AddStat(owner, "Collected", amount)
	fx(owner, "Collect", { Position = slot.Pad.Position + Vector3.new(0, 2, 0), Amount = amount })
end

local function incomeTick()
	for _, base in bases do
		local owner = base.Owner
		if owner and DataService.IsLoaded(owner) then
			local mult = BaseService.IncomeMultiplier(owner)
			for _, slot in base.Slots do
				local present = slot.Present
				if present and not present.BeingStolen then
					present.Stored += PresentDisplay.BaseIncome(present.Id, present.Mutation) * mult
					slot.PadLabel.Text = Format.Cash(present.Stored)
				elseif not present then
					slot.PadLabel.Text = ""
				end
			end
		end
	end
end

-- Bloqueo ---------------------------------------------------------------------------------------------

function BaseService.Lock(base: BaseRecord)
	local owner = base.Owner
	if not owner or BaseService.IsLocked(base) then
		return
	end
	local data = DataService.Get(owner)
	if not data then
		return
	end
	local duration = Rebirths.LockDuration(data.Rebirths)
	base.LockedUntil = now() + duration
	base.Model:SetAttribute("LockedUntil", base.LockedUntil)
	setShield(base, true)
	notify(owner, string.format("🔒 ¡Base bloqueada durante %d segundos!", duration), "Success")
	fx(nil, "Sound", { Name = "Lock", Position = base.LockButton.Position })
	-- quien esté dentro sale despedido
	BaseService.Enforce(base)
end

local function pushOut(base: BaseRecord, player: Player)
	local character = player.Character
	if not character then
		return
	end
	local outside = base.CFrame * CFrame.new(math.random(-5, 5), 3.5, -Layout.Base.Depth / 2 - 8)
	character:PivotTo(CFrame.lookAt(outside.Position, outside.Position + base.CFrame.LookVector))
	Remotes.Event("Knockback"):FireClient(player, base.CFrame.LookVector * 40 + Vector3.new(0, 25, 0))
end

function BaseService.Enforce(base: BaseRecord)
	if not BaseService.IsLocked(base) then
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= base.Owner then
			local root = CharacterService.GetRoot(player)
			if root and BaseService.IsInside(base, root.Position, 0.5) then
				pushOut(base, player)
				notify(player, "🔒 Esa base está bloqueada. ¡Espera a que se abra!", "Warning")
			end
		end
	end
end

local function lockTick()
	local t = now()
	for _, base in bases do
		if base.LockedUntil > 0 then
			if t >= base.LockedUntil then
				base.LockedUntil = 0
				base.Model:SetAttribute("LockedUntil", 0)
				setShield(base, false)
				if base.Owner then
					notify(base.Owner, "🔓 Tu base vuelve a estar ABIERTA. ¡Bloquéala otra vez!", "Warning")
					fx(base.Owner, "Sound", { Name = "Unlock" })
				end
			else
				BaseService.Enforce(base)
			end
		end
		local remaining = base.LockedUntil - t
		if base.Owner then
			if remaining > 0 then
				base.ButtonLabel.Text = "🔒 " .. Format.Clock(remaining)
				base.ButtonLabel.TextColor3 = Color3.fromRGB(130, 255, 150)
				base.HeadStatus.Text = "🔒 Bloqueada " .. Format.Clock(remaining)
				base.HeadStatus.TextColor3 = Color3.fromRGB(255, 120, 120)
			else
				base.ButtonLabel.Text = "🔒 BLOQUEAR"
				base.ButtonLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
				base.HeadStatus.Text = "🔓 Abierta"
				base.HeadStatus.TextColor3 = Color3.fromRGB(160, 255, 170)
			end
		else
			base.ButtonLabel.Text = ""
			base.HeadStatus.Text = ""
		end
	end
end

-- Asignación ----------------------------------------------------------------------------------------

local function teleportHome(player: Player, character: Model)
	local base = playerBase[player]
	if not base then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or playerBase[player] ~= base then
		return
	end
	task.wait()
	local target = base.CFrame * CFrame.new(0, 4.5, -14)
	if (root.Position - target.Position).Magnitude > 12 then
		character:PivotTo(target)
	end
end

function BaseService.Assign(player: Player): BaseRecord?
	if playerBase[player] then
		return playerBase[player]
	end
	for _, base in bases do
		if base.Owner == nil then
			base.Owner = player
			playerBase[player] = base
			base.Model:SetAttribute("OwnerUserId", player.UserId)
			base.Model:SetAttribute("OwnerName", player.DisplayName)
			base.SignTitle.Text = player.DisplayName
			base.SignSub.Text = "🎁 Taller " .. base.Model:GetAttribute("ThemeName")
			base.HeadName.Text = "🎁 " .. player.DisplayName
			base.HeadName.TextColor3 = base.Theme
			player:SetAttribute("BaseId", base.Id)
			if base.Spawn then
				player.RespawnLocation = base.Spawn
			end
			BaseService.RefreshSlots(base)
			player.CharacterAdded:Connect(function(character)
				teleportHome(player, character)
			end)
			if player.Character then
				task.spawn(teleportHome, player, player.Character)
			end
			return base
		end
	end
	task.delay(3, function()
		if player.Parent then
			notify(player, "😢 No quedan talleres libres en este servidor. ¡Prueba en otro!", "Warning")
		end
	end)
	return nil
end

function BaseService.OnLoaded(player: Player, data: any, offlineSeconds: number)
	local base = playerBase[player]
	if not base then
		return
	end
	BaseService.RefreshSlots(base)
	for key, entry in data.Presents do
		local index = tonumber(key)
		if index and base.Slots[index] and type(entry) == "table" and Presents.Get(entry.Id) then
			BaseService.PlacePresent(base, index, entry.Id, entry.Mutation, { Stored = tonumber(entry.Stored) or 0 })
		else
			data.Presents[key] = nil
		end
	end
	refreshIncome(base)
	-- ganancias mientras no estabas
	if offlineSeconds > 60 then
		local seconds = math.min(offlineSeconds, GameConfig.OfflineEarningsMaxHours * 3600)
		local earned = math.floor(BaseService.TotalIncome(base) * seconds * GameConfig.OfflineEarningsRate)
		if earned > 0 then
			DataService.AddCash(player, earned)
			task.delay(5, function()
				if player.Parent then
					notify(player, string.format("🌙 Mientras no estabas tus regalos generaron %s", Format.Cash(earned)), "Success")
				end
			end)
		end
	end
end

function BaseService.Release(player: Player)
	local base = playerBase[player]
	if not base then
		return
	end
	BaseService.Releasing:Fire(base, player)
	for _, slot in base.Slots do
		local present = slot.Present
		if present and present.Model then
			present.Model:Destroy()
		end
		slot.Present = nil
		slot.AlertGui.Enabled = false
		slot.PadLabel.Text = ""
	end
	base.Owner = nil
	playerBase[player] = nil
	base.LockedUntil = 0
	setShield(base, false)
	base.Model:SetAttribute("LockedUntil", 0)
	base.Model:SetAttribute("OwnerUserId", 0)
	base.Model:SetAttribute("OwnerName", "")
	base.SignTitle.Text = "LIBRE"
	base.SignSub.Text = "Taller " .. base.Model:GetAttribute("ThemeName")
	base.HeadName.Text = ""
	base.HeadStatus.Text = ""
	BaseService.RefreshSlots(base)
end

-- Vender ----------------------------------------------------------------------------------------------

function BaseService.Sell(player: Player, base: BaseRecord, slotIndex: number)
	if base.Owner ~= player then
		return
	end
	local slot = base.Slots[slotIndex]
	local present = slot and slot.Present
	if not present or present.BeingStolen then
		return
	end
	local info = Presents.Get(present.Id)
	local refund = math.floor(PresentDisplay.Price(present.Id, present.Mutation) * GameConfig.SellRefund)
	local stored = math.floor(present.Stored)
	BaseService.RemovePresent(base, slotIndex)
	DataService.AddCash(player, refund + stored)
	fx(player, "Collect", { Position = slot.Pedestal.Position + Vector3.new(0, 3, 0), Amount = refund + stored, Sound = "Sell" })
	notify(player, string.format("💸 Vendiste %s por %s", if info then info.Name else "el regalo", Format.Cash(refund)), "Info")
end

-- Arranque ----------------------------------------------------------------------------------------------

local function characterOwner(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function BaseService.Init(map: Model)
	local folder = map:WaitForChild("Bases")
	for i = 1, GameConfig.MaxBases do
		local model = folder:WaitForChild("Base" .. i) :: Model
		local record: BaseRecord = {
			Id = i,
			Model = model,
			CFrame = Layout.BaseCFrame(i),
			Owner = nil,
			Slots = {},
			LockedUntil = 0,
			LockDoor = model:WaitForChild("LockDoor") :: BasePart,
			LockLid = model:WaitForChild("LockLid") :: BasePart,
			LockButton = model:WaitForChild("LockButton") :: BasePart,
			Spawn = model:FindFirstChild("Spawn") :: SpawnLocation?,
			Theme = (model:GetAttribute("ThemeColor") :: Color3?) or Color3.new(1, 1, 1),
		} :: any
		makeSign(record, model:WaitForChild("Sign") :: BasePart)
		makeButtonLabel(record)
		local slotsFolder = model:WaitForChild("Slots")
		for s = 1, GameConfig.SlotsPerBase do
			local slotModel = slotsFolder:WaitForChild("Slot" .. s) :: Model
			local slot: SlotRecord = {
				Index = s,
				Model = slotModel,
				Pedestal = slotModel:WaitForChild("Pedestal") :: BasePart,
				Pad = slotModel:WaitForChild("Pad") :: BasePart,
				PadGlow = slotModel:FindFirstChild("PadGlow") :: BasePart?,
				Glow = slotModel:FindFirstChild("Glow") :: BasePart?,
				Present = nil,
				Unlocked = s <= Rebirths.BaseSlots,
				LastCollect = 0,
			} :: any
			makeSlotGuis(slot)
			slot.Pad.Touched:Connect(function(hit)
				local player = characterOwner(hit)
				if not player or player ~= record.Owner then
					return
				end
				if os.clock() - slot.LastCollect < 0.3 then
					return
				end
				slot.LastCollect = os.clock()
				BaseService.Collect(record, slot)
			end)
			record.Slots[s] = slot
		end
		record.LockButton.Touched:Connect(function(hit)
			local player = characterOwner(hit)
			if player and player == record.Owner then
				BaseService.Lock(record)
			end
		end)
		setShield(record, false)
		bases[i] = record
		BaseService.RefreshSlots(record)
	end
end

function BaseService.Start()
	DataService.OnBeforeSave(function(player)
		local base = playerBase[player]
		if not base then
			return
		end
		for _, slot in base.Slots do
			if slot.Present then
				saveSlot(base, slot)
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "SellPrompt" then
			return
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		if not model then
			return
		end
		local base = bases[model:GetAttribute("BaseId") :: number]
		local slotIndex = model:GetAttribute("SlotIndex") :: number
		if base and slotIndex then
			BaseService.Sell(player, base, slotIndex)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			incomeTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			lockTick()
		end
	end)
end

return BaseService
]======])
make('ServerScriptService', {'Server', 'Services', 'CharacterService'}, 'ModuleScript', [======[
-- Velocidad y salto de cada personaje según su estado: llevar un regalo, congelado, botas, campana...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gears = require(Shared.Config.Gears)

local CharacterService = {}

type State = {
	Carrying: boolean,
	FrozenUntil: number,
	Boots: boolean,
	Bell: boolean,
	IceBlock: BasePart?,
}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = { Carrying = false, FrozenUntil = 0, Boots = false, Bell = false, IceBlock = nil }
		states[player] = state
	end
	return state
end

function CharacterService.GetHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function CharacterService.GetRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterService.IsFrozen(player: Player): boolean
	return getState(player).FrozenUntil > os.clock()
end

function CharacterService.Refresh(player: Player)
	local humanoid = CharacterService.GetHumanoid(player)
	if not humanoid then
		return
	end
	local state = getState(player)
	local speed = GameConfig.Movement.WalkSpeed
	local jump = GameConfig.Movement.JumpHeight
	if state.Boots then
		speed *= (Gears.List.ReindeerBoots.SpeedMult or 1)
	end
	if state.Bell then
		jump = Gears.List.JingleBell.JumpHeight or jump
	end
	if state.Carrying then
		speed *= GameConfig.Steal.CarrySpeedMult
		jump = math.min(jump, GameConfig.Steal.CarryJumpHeight)
	end
	if state.FrozenUntil > os.clock() then
		speed = 0
		jump = 0
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = jump
end

function CharacterService.SetFlag(player: Player, flag: string, value: boolean)
	local state = getState(player) :: any
	if state[flag] == value then
		return
	end
	state[flag] = value
	CharacterService.Refresh(player)
end

-- Congela al jugador: bloque de hielo y sin poder moverse
function CharacterService.Freeze(player: Player, duration: number)
	local state = getState(player)
	local root = CharacterService.GetRoot(player)
	if not root then
		return
	end
	state.FrozenUntil = math.max(state.FrozenUntil, os.clock() + duration)
	CharacterService.Refresh(player)
	if not state.IceBlock or not state.IceBlock.Parent then
		local ice = Instance.new("Part")
		ice.Name = "IceBlock"
		ice.Size = Vector3.new(4.6, 6.4, 4.6)
		ice.Color = Color3.fromRGB(170, 225, 255)
		ice.Material = Enum.Material.Ice
		ice.Transparency = 0.35
		ice.Reflectance = 0.2
		ice.CanCollide = false
		ice.CanQuery = false
		ice.CanTouch = false
		ice.Massless = true
		ice.CastShadow = false
		ice.CFrame = root.CFrame * CFrame.new(0, -0.4, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ice
		weld.Parent = ice
		ice.Parent = player.Character
		state.IceBlock = ice
	end
	local untilTime = state.FrozenUntil
	task.delay(duration + 0.05, function()
		if state.FrozenUntil <= untilTime + 0.01 and os.clock() >= state.FrozenUntil then
			if state.IceBlock then
				state.IceBlock:Destroy()
				state.IceBlock = nil
			end
			CharacterService.Refresh(player)
		end
	end)
end

function CharacterService.Track(player: Player)
	local function onCharacter(character: Model)
		local state = getState(player)
		state.Carrying = false
		state.Boots = false
		state.Bell = false
		state.FrozenUntil = 0
		state.IceBlock = nil
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			CharacterService.Refresh(player)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function CharacterService.Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CharacterService
]======])
make('ServerScriptService', {'Server', 'Services', 'ConveyorService'}, 'ModuleScript', [======[
-- La cinta de la Fábrica de Santa: van saliendo regalos aleatorios que cualquiera puede comprar.
--
-- El servidor no mueve los modelos: guarda cuándo salió cada regalo (SpawnT) y su velocidad, y cada
-- cliente lo anima localmente (movimiento suave sin coste de red). La posición real se calcula con la
-- misma fórmula para validar las compras.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PresentBuilder = require(Shared.PresentBuilder)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local World = script.Parent.Parent.World
local PresentDisplay = require(World.PresentDisplay)
local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local CharacterService = require(script.Parent.CharacterService)
local EventService = require(script.Parent.EventService)

local ConveyorService = {}

type Item = {
	Uid: number,
	Id: string,
	Mutation: string?,
	SpawnT: number,
	Model: Model,
	Price: number,
}

local items: { [number]: Item } = {}
local itemCount = 0
local nextUid = 0
local itemsFolder: Instance
local random = Random.new()

local BELT = GameConfig.Belt
local TRAVEL_TIME = (BELT.EndX - BELT.StartX) / BELT.Speed

local function now(): number
	return workspace:GetServerTimeNow()
end

local function itemPosition(item: Item, t: number): Vector3
	local x = BELT.StartX + BELT.Speed * (t - item.SpawnT)
	return Vector3.new(x, BELT.SurfaceY, BELT.Z)
end

-- Sorteo -----------------------------------------------------------------------------------------------

function ConveyorService.RollPresent(luck: number): string
	local total = 0
	for _, rarityId in Rarities.Order do
		if Presents.ByRarity[rarityId] then
			total += Rarities.WeightWithLuck(rarityId, luck)
		end
	end
	local roll = random:NextNumber() * total
	local chosen = Rarities.Order[1]
	for _, rarityId in Rarities.Order do
		if Presents.ByRarity[rarityId] then
			roll -= Rarities.WeightWithLuck(rarityId, luck)
			if roll <= 0 then
				chosen = rarityId
				break
			end
		end
	end
	local pool = Presents.ByRarity[chosen]
	local weightTotal = 0
	for _, info in pool do
		weightTotal += info.Weight
	end
	local pick = random:NextNumber() * weightTotal
	for _, info in pool do
		pick -= info.Weight
		if pick <= 0 then
			return info.Id
		end
	end
	return pool[#pool].Id
end

function ConveyorService.RollMutation(): string?
	local overrides = EventService.GetMutationChances()
	-- de la más rara a la más común
	for i = #Mutations.Order, 1, -1 do
		local id = Mutations.Order[i]
		local chance = overrides[id] or Mutations.List[id].Chance
		if random:NextNumber() < chance then
			return id
		end
	end
	return nil
end

-- Cinta ----------------------------------------------------------------------------------------------------

function ConveyorService.Spawn(presentId: string, mutation: string?): Item?
	local info = Presents.Get(presentId)
	if not info then
		return nil
	end
	nextUid += 1
	local uid = nextUid
	local model = PresentBuilder.Build(presentId, mutation)
	model.Name = "BeltPresent"
	local spawnT = now()
	PresentBuilder.PlaceAt(model, CFrame.new(BELT.StartX, BELT.SurfaceY, BELT.Z) * CFrame.Angles(0, -math.pi / 2, 0))
	model:SetAttribute("Mode", "Belt")
	model:SetAttribute("Uid", uid)
	model:SetAttribute("SpawnT", spawnT)
	model:SetAttribute("Speed", BELT.Speed)
	model:SetAttribute("StartX", BELT.StartX)
	model:SetAttribute("EndX", BELT.EndX)
	model:SetAttribute("BeltZ", BELT.Z)
	model:SetAttribute("BeltY", BELT.SurfaceY)
	local price = PresentDisplay.Price(presentId, mutation)
	PresentDisplay.Belt(model, presentId, mutation)
	local root = model.PrimaryPart :: BasePart
	PresentDisplay.Prompt(root:FindFirstChild("Mid") :: Attachment, {
		Name = "BuyPrompt",
		ActionText = "Comprar " .. Format.Cash(price),
		ObjectText = info.Name,
		HoldDuration = 0,
		MaxActivationDistance = 12,
		KeyboardKeyCode = Enum.KeyCode.E,
	})
	local rarity = Rarities.Get(info.Rarity)
	if rarity.Beam then
		PresentDisplay.LightPillar(model, rarity.Color)
	end
	model.Parent = itemsFolder

	local item: Item = { Uid = uid, Id = presentId, Mutation = mutation, SpawnT = spawnT, Model = model, Price = price }
	items[uid] = item
	itemCount += 1

	if rarity.Index >= BELT.AnnounceRarity then
		local mutationName = if mutation then (Mutations.DisplayName(mutation) .. " ") else ""
		Remotes.Event("Notify"):FireAllClients(
			string.format("✨ ¡%s%s (%s) ha salido de la fábrica!", mutationName, info.Name, rarity.Name),
			"Rare",
			{ Color = rarity.Color, Rainbow = rarity.Rainbow }
		)
		Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Event" })
	end
	return item
end

local function removeItem(item: Item)
	if items[item.Uid] then
		items[item.Uid] = nil
		itemCount -= 1
	end
	if item.Model.Parent then
		item.Model:Destroy()
	end
end

-- Compra -----------------------------------------------------------------------------------------------

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "Info")
end

function ConveyorService.TryBuy(player: Player, uid: number)
	local item = items[uid]
	if not item then
		notify(player, "¡Demasiado tarde! Alguien se te adelantó.", "Warning")
		return
	end
	local data = DataService.Get(player)
	local base = BaseService.GetBase(player)
	if not data or not base then
		notify(player, "Necesitas un taller para comprar regalos.", "Warning")
		return
	end
	local root = CharacterService.GetRoot(player)
	if not root then
		return
	end
	local t = now()
	if t - item.SpawnT > TRAVEL_TIME then
		return
	end
	local position = itemPosition(item, t)
	local flat = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
	if flat.Magnitude > BELT.BuyDistance then
		return
	end
	local slotIndex = BaseService.FindFreeSlot(base)
	if not slotIndex then
		notify(player, "🎁 ¡Tu taller está lleno! Vende un regalo o renace para tener más huecos.", "Warning")
		Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "NoMoney" })
		return
	end
	if data.Cash < item.Price then
		notify(player, "💸 Te faltan " .. Format.Cash(item.Price - data.Cash), "Error")
		Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "NoMoney" })
		return
	end
	if not DataService.SpendCash(player, item.Price) then
		return
	end
	removeItem(item)
	BaseService.PlacePresent(base, slotIndex, item.Id, item.Mutation, { From = position + Vector3.new(0, 1, 0) })
	local isNew = DataService.Discover(player, item.Id, item.Mutation)
	DataService.AddStat(player, "Bought", 1)
	DataService.MarkChanged(player)

	local info = Presents.Get(item.Id)
	if not info then
		return
	end
	local rarity = Rarities.Get(info.Rarity)
	Remotes.Event("Fx"):FireAllClients("Burst", { Position = position + Vector3.new(0, 2, 0), Color = rarity.Color, Count = 20 + rarity.Index * 6 })
	Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "Buy" })
	local mutationName = if item.Mutation then (Mutations.DisplayName(item.Mutation) .. " ") else ""
	notify(player, string.format("🎁 ¡Has comprado %s%s!%s", mutationName, info.Name, if isNew then "  📖 ¡Nuevo en tu índice!" else ""), "Success")
	if rarity.Index >= BELT.AnnounceRarity then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				notify(other, string.format("🛒 %s ha comprado %s%s", player.DisplayName, mutationName, info.Name), "Rare")
			end
		end
	end
end

-- Arranque ----------------------------------------------------------------------------------------------

function ConveyorService.Init(map: Model)
	local conveyor = map:WaitForChild("Conveyor")
	itemsFolder = conveyor:FindFirstChild("Items") or Instance.new("Folder")
	itemsFolder.Name = "Items"
	itemsFolder.Parent = conveyor
end

function ConveyorService.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "BuyPrompt" then
			return
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		local uid = model and model:GetAttribute("Uid")
		if type(uid) == "number" then
			ConveyorService.TryBuy(player, uid)
		end
	end)

	-- aparición de regalos
	task.spawn(function()
		-- llena un poco la cinta al arrancar para que no empiece vacía
		local prefill = math.floor(TRAVEL_TIME / BELT.SpawnInterval * 0.5)
		for i = 1, prefill do
			local item = ConveyorService.Spawn(ConveyorService.RollPresent(1), ConveyorService.RollMutation())
			if item then
				item.SpawnT -= (prefill - i + 1) * BELT.SpawnInterval
				item.Model:SetAttribute("SpawnT", item.SpawnT)
			end
		end
		while true do
			local rate = EventService.GetSpawnRateMult()
			task.wait(math.max(0.4, (BELT.SpawnInterval + random:NextNumber(-BELT.SpawnJitter, BELT.SpawnJitter)) / rate))
			if itemCount < BELT.MaxItems then
				ConveyorService.Spawn(ConveyorService.RollPresent(EventService.GetLuck()), ConveyorService.RollMutation())
			end
		end
	end)

	-- los que llegan al horno se convierten en carbón
	RunService.Heartbeat:Connect(function()
		local t = now()
		for _, item in items do
			if t - item.SpawnT >= TRAVEL_TIME then
				removeItem(item)
			end
		end
	end)
end

return ConveyorService
]======])
make('ServerScriptService', {'Server', 'Services', 'DataService'}, 'ModuleScript', [======[
-- Datos de cada jugador: carga y guardado con DataStore, leaderstats y sincronización con el cliente.
--
-- Si el DataStore no está disponible (p. ej. en Studio sin "Enable Studio Access to API Services") se juega
-- con datos nuevos y no se guarda nada, para no machacar datos buenos.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

export type SavedPresent = { Id: string, Mutation: string?, Stored: number? }

export type PlayerData = {
	Version: number,
	Cash: number,
	Rebirths: number,
	Presents: { [string]: SavedPresent }, -- clave = número de hueco como texto
	Gears: { [string]: boolean },
	Index: { [string]: { [string]: boolean } }, -- [regalo][mutación o "Normal"]
	Stats: { [string]: number },
	LastOnline: number,
	TutorialDone: boolean,
}

type Profile = {
	Data: PlayerData,
	CanSave: boolean,
	Saving: boolean,
	SyncQueued: boolean,
}

local DataService = {}

DataService.Loaded = Signal.new() -- (player, data, isNew, offlineSeconds)
DataService.Changed = Signal.new() -- (player, data)

local profiles: { [Player]: Profile } = {}
local beforeSave: { (Player, PlayerData) -> () } = {}
local loadingThreads: { [Player]: boolean } = {}

local store: DataStore? = nil
local storeDisabled = false
local storeReason = ""

do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if not ok then
		storeDisabled = true
		storeReason = tostring(err)
	end
end

local function key(player: Player): string
	return "Player_" .. player.UserId
end

function DataService.Default(): PlayerData
	return {
		Version = 1,
		Cash = GameConfig.StartCash,
		Rebirths = 0,
		Presents = {},
		Gears = { CandyBat = true },
		Index = {},
		Stats = { Steals = 0, Stolen = 0, Bought = 0, Collected = 0, PlayTime = 0, Defended = 0 },
		LastOnline = 0,
		TutorialDone = false,
	}
end

local function reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			if type(v) == "table" then
				target[k] = table.clone(v)
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
end

local function isStudioAccessError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio", 1, true) ~= nil
		or string.find(lower, "403", 1, true) ~= nil
		or string.find(lower, "api services", 1, true) ~= nil
		or string.find(lower, "not allowed", 1, true) ~= nil
end

local function loadRaw(player: Player): (any, boolean)
	if storeDisabled or not store then
		return nil, false
	end
	local activeStore = store :: DataStore
	for attempt = 1, 4 do
		local ok, result = pcall(function()
			return activeStore:GetAsync(key(player))
		end)
		if ok then
			return result, true
		end
		local message = tostring(result)
		warn(string.format("[Datos] Error cargando %s (intento %d): %s", player.Name, attempt, message))
		if isStudioAccessError(message) then
			storeDisabled = true
			storeReason = message
			return nil, false
		end
		task.wait(attempt * 1.5)
	end
	return nil, false
end

-- Carga los datos del jugador (bloquea). Devuelve los datos.
function DataService.Load(player: Player): PlayerData?
	if profiles[player] then
		return profiles[player].Data
	end
	loadingThreads[player] = true
	local raw, ok = loadRaw(player)
	loadingThreads[player] = nil
	if not player.Parent then
		return nil
	end

	local isNew = raw == nil
	local data: PlayerData
	if type(raw) == "table" then
		data = raw
	else
		data = DataService.Default()
	end
	reconcile(data :: any, DataService.Default() :: any)
	data.Gears.CandyBat = true

	local canSave = ok and not storeDisabled
	local profile: Profile = { Data = data, CanSave = canSave, Saving = false, SyncQueued = false }
	profiles[player] = profile

	if not canSave then
		task.delay(4, function()
			if player.Parent then
				local reason = if RunService:IsStudio()
					then "Estás en Studio sin acceso a DataStore: tu progreso no se guardará (actívalo en Game Settings → Security)."
					else "No se pudieron cargar tus datos. Tu progreso de esta sesión no se guardará."
				Remotes.Event("Notify"):FireClient(player, reason, "Warning")
			end
		end)
		if storeReason ~= "" then
			warn("[Datos] DataStore desactivado: " .. storeReason)
			storeReason = ""
		end
	end

	DataService.SetupLeaderstats(player, data)
	local offline = if data.LastOnline > 0 then math.max(0, os.time() - data.LastOnline) else 0
	DataService.Loaded:Fire(player, data, isNew, offline)
	DataService.MarkChanged(player)
	return data
end

function DataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.OnBeforeSave(callback: (Player, PlayerData) -> ())
	table.insert(beforeSave, callback)
end

-- Leaderstats ---------------------------------------------------------------------------------------

function DataService.SetupLeaderstats(player: Player, data: PlayerData)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "💰 Dinero"
		cash.Parent = folder
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "⭐ Renacer"
		rebirths.Parent = folder
		local steals = Instance.new("IntValue")
		steals.Name = "😈 Robos"
		steals.Parent = folder
		folder.Parent = player
	end
	DataService.UpdateLeaderstats(player, data)
end

function DataService.UpdateLeaderstats(player: Player, data: PlayerData)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local cash = folder:FindFirstChild("💰 Dinero") :: StringValue?
	local rebirths = folder:FindFirstChild("⭐ Renacer") :: IntValue?
	local steals = folder:FindFirstChild("😈 Robos") :: IntValue?
	if cash then
		cash.Value = Format.Cash(data.Cash)
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	if steals then
		steals.Value = data.Stats.Steals or 0
	end
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Rebirths", data.Rebirths)
end

-- Cambios -----------------------------------------------------------------------------------------

-- Avisa de que los datos cambiaron: se actualizan leaderstats y se manda una copia al cliente (agrupado).
function DataService.MarkChanged(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.UpdateLeaderstats(player, profile.Data)
	DataService.Changed:Fire(player, profile.Data)
	if profile.SyncQueued then
		return
	end
	profile.SyncQueued = true
	task.delay(0.12, function()
		profile.SyncQueued = false
		if player.Parent and profiles[player] == profile then
			DataService.Sync(player)
		end
	end)
end

function DataService.Snapshot(player: Player): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.Data
	local presents = {}
	for slot, entry in data.Presents do
		presents[slot] = { Id = entry.Id, Mutation = entry.Mutation }
	end
	return {
		Cash = data.Cash,
		Rebirths = data.Rebirths,
		Gears = table.clone(data.Gears),
		Index = data.Index,
		Stats = table.clone(data.Stats),
		Presents = presents,
		TutorialDone = data.TutorialDone,
		CanSave = profile.CanSave,
	}
end

function DataService.Sync(player: Player)
	local snapshot = DataService.Snapshot(player)
	if snapshot then
		Remotes.Event("DataSync"):FireClient(player, snapshot)
	end
end

function DataService.AddCash(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount ~= amount then
		return
	end
	data.Cash = math.max(0, data.Cash + amount)
	DataService.MarkChanged(player)
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount < 0 then
		return false
	end
	if data.Cash < amount then
		return false
	end
	data.Cash -= amount
	DataService.MarkChanged(player)
	return true
end

function DataService.AddStat(player: Player, stat: string, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Stats[stat] = (data.Stats[stat] or 0) + amount
end

-- Registra un regalo en el índice. Devuelve true si es nuevo.
function DataService.Discover(player: Player, presentId: string, mutation: string?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local entry = data.Index[presentId]
	if not entry then
		entry = {}
		data.Index[presentId] = entry
	end
	local mutationKey = if mutation and mutation ~= "" then mutation else "Normal"
	if entry[mutationKey] then
		return false
	end
	entry[mutationKey] = true
	return true
end

-- Guardado ----------------------------------------------------------------------------------------

function DataService.Save(player: Player, final: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	if profile.Saving and not final then
		return false
	end
	profile.Saving = true
	for _, callback in beforeSave do
		local ok, err = pcall(callback, player, profile.Data)
		if not ok then
			warn("[Datos] Error preparando el guardado: " .. tostring(err))
		end
	end
	profile.Data.LastOnline = os.time()
	local activeStore = store :: DataStore
	local success = false
	local attempts = if final then 3 else 1
	for attempt = 1, attempts do
		local ok, err = pcall(function()
			activeStore:UpdateAsync(key(player), function()
				return profile.Data
			end)
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[Datos] Error guardando %s (intento %d): %s", player.Name, attempt, tostring(err)))
		task.wait(1)
	end
	profile.Saving = false
	return success
end

function DataService.Release(player: Player)
	profiles[player] = nil
	loadingThreads[player] = nil
end

function DataService.Start()
	-- Autoguardado escalonado
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				if profiles[player] then
					task.spawn(DataService.Save, player)
					task.wait(1)
				end
			end
		end
	end)

	-- Tiempo jugado
	task.spawn(function()
		while true do
			task.wait(60)
			for player, profile in profiles do
				if player.Parent then
					profile.Data.Stats.PlayTime = (profile.Data.Stats.PlayTime or 0) + 1
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and storeDisabled then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			if profiles[player] then
				pending += 1
				task.spawn(function()
					DataService.Save(player, true)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)

	Remotes.Event("ClientReady").OnServerEvent:Connect(function(player)
		DataService.Sync(player)
	end)
end

return DataService
]======])
make('ServerScriptService', {'Server', 'Services', 'DevCommands'}, 'ModuleScript', [======[
-- Comandos de chat para probar el juego (solo en Studio o para el creador del juego):
--   /dinero 1000000      añade dinero (también /cash)
--   /regalo SantasGift Rainbow   saca ese regalo en la cinta ahora mismo
--   /evento SantaNight   empieza un evento (Blizzard, Aurora, SantaNight, GoldRain)
--   /renacer             renace sin requisitos
--   /bloquear            bloquea tu base
--   /borrar              reinicia tus datos (no se guardan hasta que vuelvas a ganar algo)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Presents = require(Shared.Config.Presents)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local ConveyorService = require(script.Parent.ConveyorService)
local EventService = require(script.Parent.EventService)

local DevCommands = {}

local function allowed(player: Player): boolean
	if not GameConfig.DevCommands then
		return false
	end
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	return false
end

local function reply(player: Player, text: string)
	Remotes.Event("Notify"):FireClient(player, "🛠️ " .. text, "Info")
end

local function parseAmount(text: string?): number
	if not text then
		return 1000000
	end
	local value = tonumber(text)
	if value then
		return value
	end
	local number, suffix = string.match(string.lower(text), "^([%d%.]+)(%a+)$")
	local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[suffix or ""]
	if number and mult then
		return (tonumber(number) or 0) * mult
	end
	return 1000000
end

local commands: { [string]: (Player, { string }) -> () } = {}

commands.dinero = function(player, args)
	local amount = parseAmount(args[1])
	DataService.AddCash(player, amount)
	reply(player, "Añadidos $" .. tostring(amount))
end
commands.cash = commands.dinero

commands.regalo = function(player, args)
	local id = args[1]
	if not id or not Presents.Get(id) then
		local ids = {}
		for _, info in Presents.List do
			table.insert(ids, info.Id)
		end
		reply(player, "Regalos: " .. table.concat(ids, ", "))
		return
	end
	local mutation = args[2]
	if mutation and not Mutations.Get(mutation) then
		mutation = nil
	end
	ConveyorService.Spawn(id, mutation)
	reply(player, "Regalo " .. id .. " en la cinta")
end

commands.evento = function(player, args)
	if not EventService.Start(args[1] or "SantaNight") then
		reply(player, "Eventos: Blizzard, Aurora, SantaNight, GoldRain")
	end
end
commands.event = commands.evento

commands.renacer = function(player)
	local data = DataService.Get(player)
	local base = BaseService.GetBase(player)
	if not data or not base then
		return
	end
	BaseService.ClearPresents(base)
	data.Rebirths += 1
	data.Cash = GameConfig.StartCash
	data.Presents = {}
	BaseService.RefreshSlots(base)
	DataService.MarkChanged(player)
	reply(player, "Renacimiento " .. data.Rebirths)
end

commands.bloquear = function(player)
	local base = BaseService.GetBase(player)
	if base then
		BaseService.Lock(base)
	end
end

commands.borrar = function(player)
	local data = DataService.Get(player)
	local base = BaseService.GetBase(player)
	if not data or not base then
		return
	end
	BaseService.ClearPresents(base)
	local fresh = DataService.Default()
	for key, value in fresh do
		(data :: any)[key] = value
	end
	BaseService.RefreshSlots(base)
	DataService.MarkChanged(player)
	reply(player, "Datos reiniciados")
end

local function run(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "/" or not allowed(player) then
		return
	end
	local parts = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(parts, 1) or "")
	local command = commands[name]
	if command then
		command(player, parts)
	end
end

function DevCommands.Start()
	if not GameConfig.DevCommands then
		return
	end
	local useTextChat = false
	pcall(function()
		useTextChat = TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
	end)
	if useTextChat then
		local folder = Instance.new("Folder")
		folder.Name = "DevCommands"
		folder.Parent = TextChatService
		for name in commands do
			local command = Instance.new("TextChatCommand")
			command.Name = "Dev_" .. name
			command.PrimaryAlias = "/" .. name
			pcall(function()
				command.AutocompleteVisible = false
			end)
			command.Parent = folder
			command.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, text)
				end
			end)
		end
	else
		local function hook(player: Player)
			player.Chatted:Connect(function(message)
				run(player, message)
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
end

return DevCommands
]======])
make('ServerScriptService', {'Server', 'Services', 'EventService'}, 'ModuleScript', [======[
-- Eventos globales: Ventisca, Aurora Boreal, Noche de Santa, Lluvia de Oro.
-- El evento activo se publica en atributos de Workspace (EventId, EventEndsAt) para que el cliente
-- muestre el cartel y los efectos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Events = require(Shared.Config.Events)
local Remotes = require(Shared.Net.Remotes)

local EventService = {}

local current: Events.EventInfo? = nil
local endsAt = 0
local token = 0
local random = Random.new()

local EMPTY = {}

function EventService.Current(): Events.EventInfo?
	if current and workspace:GetServerTimeNow() < endsAt then
		return current
	end
	return nil
end

function EventService.GetLuck(): number
	local event = EventService.Current()
	return if event then event.Luck else 1
end

function EventService.GetMutationChances(): { [string]: number }
	local event = EventService.Current()
	return if event then event.MutationChances else EMPTY
end

function EventService.GetSpawnRateMult(): number
	local event = EventService.Current()
	return if event then event.SpawnRateMult else 1
end

function EventService.Stop()
	current = nil
	endsAt = 0
	workspace:SetAttribute("EventId", "")
	workspace:SetAttribute("EventEndsAt", 0)
end

function EventService.Start(eventId: string, duration: number?)
	local event = Events.Get(eventId)
	if not event then
		return false
	end
	token += 1
	local myToken = token
	current = event
	local length = duration or event.Duration
	endsAt = workspace:GetServerTimeNow() + length
	workspace:SetAttribute("EventId", event.Id)
	workspace:SetAttribute("EventEndsAt", endsAt)
	Remotes.Event("Notify"):FireAllClients(event.Name .. " — " .. event.Description, "Event", { Color = event.Color })
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Event" })
	task.delay(length, function()
		if token == myToken then
			EventService.Stop()
			if #Players:GetPlayers() > 0 then
				Remotes.Event("Notify"):FireAllClients("El evento ha terminado. ¡Hasta el próximo!", "Info")
			end
		end
	end)
	return true
end

function EventService.Init()
	workspace:SetAttribute("EventId", "")
	workspace:SetAttribute("EventEndsAt", 0)
end

function EventService.StartLoop()
	task.spawn(function()
		task.wait(GameConfig.Events.FirstDelay)
		while true do
			if not EventService.Current() and #Players:GetPlayers() > 0 then
				local id = Events.Order[random:NextInteger(1, #Events.Order)]
				EventService.Start(id)
			end
			task.wait(random:NextNumber(GameConfig.Events.IntervalMin, GameConfig.Events.IntervalMax))
		end
	end)
end

return EventService
]======])
make('ServerScriptService', {'Server', 'Services', 'GearService'}, 'ModuleScript', [======[
-- Gears: se compran en la tienda, se guardan y se dan al reaparecer. El servidor resuelve todos los
-- golpes e impactos (el cliente solo dice hacia dónde apunta).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Gears = require(Shared.Config.Gears)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local ToolBuilder = require(script.Parent.Parent.World.ToolBuilder)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)
local StealService = require(script.Parent.StealService)

local GearService = {}

local templates: { [string]: Tool } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local projectileId = 0

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "Info")
end

local function onCooldown(player: Player, gearId: string, duration: number): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local t = os.clock()
	if (list[gearId] or 0) > t then
		return true
	end
	list[gearId] = t + duration * 0.92 -- un pelín de margen por la latencia
	return false
end

local function equippedGear(player: Player, gearId: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("GearId") == gearId then
			return child
		end
	end
	return nil
end

local function characterPlayer(instance: Instance): Player?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return player
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Golpe a otro jugador: suelta el regalo, empujón y efectos
local function hitPlayer(attacker: Player, victim: Player, direction: Vector3, force: number, freeze: number?, kind: string)
	local victimRoot = CharacterService.GetRoot(victim)
	if not victimRoot then
		return
	end
	local dropped = StealService.ForceDrop(victim, if kind == "Bat" then "¡Te han dado un bastonazo!" else "¡Te han congelado!")
	if dropped then
		notify(attacker, "🛡️ ¡Has hecho soltar el regalo a " .. victim.DisplayName .. "!", "Success")
		DataService.AddStat(attacker, "Defended", 1)
	end
	if freeze and freeze > 0 then
		CharacterService.Freeze(victim, freeze)
	end
	if force > 0 then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.new(0, 0, 1)
		end
		Remotes.Event("Knockback"):FireClient(victim, flat.Unit * force + Vector3.new(0, force * 0.45, 0))
	end
	Remotes.Event("Fx"):FireAllClients("Hit", {
		Position = victimRoot.Position,
		Kind = kind,
	})
end

-- Bastón ----------------------------------------------------------------------------------------------------

local function swingBat(player: Player, tool: Tool)
	local info = Gears.List.CandyBat
	if onCooldown(player, "CandyBat", info.Cooldown) then
		return
	end
	local root = CharacterService.GetRoot(player)
	if not root or CharacterService.IsFrozen(player) then
		return
	end
	-- animación de golpe del Animate por defecto
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	task.delay(0.5, function()
		if anim.Parent then
			anim:Destroy()
		end
	end)
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Swing", Position = root.Position })

	local range = info.Range or 9
	local best: Player? = nil
	local bestDistance = math.huge
	local look = root.CFrame.LookVector
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = CharacterService.GetRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= range then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local facing = if flat.Magnitude > 0.01 then look:Dot(flat.Unit) else 1
					if (facing > 0.1 or distance < 4.5) and distance < bestDistance then
						best = other
						bestDistance = distance
					end
				end
			end
		end
	end
	if best then
		local otherRoot = CharacterService.GetRoot(best) :: BasePart
		hitPlayer(player, best, otherRoot.Position - root.Position, info.Knockback or 60, nil, "Bat")
	end
end

-- Bola de nieve ----------------------------------------------------------------------------------------------

local function throwSnowball(player: Player, target: Vector3)
	local info = Gears.List.Snowball
	if onCooldown(player, "Snowball", info.Cooldown) then
		return
	end
	local character = player.Character
	local root = CharacterService.GetRoot(player)
	if not character or not root or CharacterService.IsFrozen(player) then
		return
	end
	local origin = root.Position + Vector3.new(0, 1.6, 0) + root.CFrame.LookVector * 1.5
	local direction = target - origin
	if direction.Magnitude < 1 then
		direction = root.CFrame.LookVector
	end
	local speed = info.ProjectileSpeed or 120
	local velocity = direction.Unit * speed + Vector3.new(0, 6, 0)
	local gravity = Vector3.new(0, -workspace.Gravity * 0.2, 0)
	projectileId += 1
	local id = projectileId
	Remotes.Event("Fx"):FireAllClients("Projectile", { Id = id, Origin = origin, Velocity = velocity, Gravity = gravity, Kind = "Snowball" })
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Throw", Position = origin })

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local carried = workspace:FindFirstChild("CarriedPresents")
	if carried then
		table.insert(exclude, carried)
	end
	params.FilterDescendantsInstances = exclude

	task.spawn(function()
		local position = origin
		local vel = velocity
		local elapsed = 0
		while elapsed < 2.2 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local step = vel * dt + gravity * (0.5 * dt * dt)
			-- un poco de radio: spherecast
			local result = workspace:Spherecast(position, 0.6, step, params)
			if result then
				local victim = characterPlayer(result.Instance)
				Remotes.Event("Fx"):FireAllClients("SnowBurst", { Id = id, Position = result.Position })
				if victim and victim ~= player then
					hitPlayer(player, victim, vel, info.Knockback or 20, info.FreezeTime, "Snowball")
				end
				return
			end
			position += step
			vel += gravity * dt
		end
		Remotes.Event("Fx"):FireAllClients("SnowBurst", { Id = id, Position = position })
	end)
end

-- Rayo congelador -------------------------------------------------------------------------------------------

local function fireFreezeRay(player: Player, tool: Tool, target: Vector3)
	local info = Gears.List.FreezeRay
	if onCooldown(player, "FreezeRay", info.Cooldown) then
		notify(player, "🧊 El rayo se está recargando...", "Info")
		return
	end
	local character = player.Character
	local root = CharacterService.GetRoot(player)
	if not character or not root or CharacterService.IsFrozen(player) then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	local origin = if muzzle then muzzle.WorldPosition else root.Position + Vector3.new(0, 1.5, 0)
	local direction = target - origin
	if direction.Magnitude < 1 then
		direction = root.CFrame.LookVector
	end
	direction = direction.Unit * (info.Range or 150)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local carried = workspace:FindFirstChild("CarriedPresents")
	if carried then
		table.insert(exclude, carried)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Spherecast(origin, 1.2, direction, params)
	local hitPosition = if result then result.Position else origin + direction
	Remotes.Event("Fx"):FireAllClients("Beam", { From = origin, To = hitPosition, Color = info.Color })
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Zap", Position = origin })
	if result then
		local victim = characterPlayer(result.Instance)
		if victim and victim ~= player then
			hitPlayer(player, victim, direction, 10, info.FreezeTime, "Freeze")
			Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Freeze", Position = hitPosition })
		end
	end
end

-- Dar herramientas -----------------------------------------------------------------------------------------

local function hookTool(player: Player, tool: Tool)
	local gearId = tool:GetAttribute("GearId")
	if gearId == "CandyBat" then
		tool.Activated:Connect(function()
			swingBat(player, tool)
		end)
	elseif gearId == "ReindeerBoots" then
		tool.Equipped:Connect(function()
			CharacterService.SetFlag(player, "Boots", true)
		end)
		tool.Unequipped:Connect(function()
			CharacterService.SetFlag(player, "Boots", false)
		end)
	elseif gearId == "JingleBell" then
		tool.Equipped:Connect(function()
			CharacterService.SetFlag(player, "Bell", true)
		end)
		tool.Unequipped:Connect(function()
			CharacterService.SetFlag(player, "Bell", false)
		end)
	end
end

local function hasTool(player: Player, gearId: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("GearId") == gearId then
					return true
				end
			end
		end
	end
	return false
end

function GearService.Give(player: Player, gearId: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local template = templates[gearId]
	if not backpack or not template or hasTool(player, gearId) then
		return
	end
	local tool = template:Clone()
	hookTool(player, tool)
	tool.Parent = backpack
end

function GearService.GiveOwned(player: Player)
	local data = DataService.Get(player)
	for _, gearId in Gears.Order do
		if gearId == "CandyBat" or (data and data.Gears[gearId]) then
			GearService.Give(player, gearId)
		end
	end
end

function GearService.Track(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		task.wait(0.1)
		if player.Parent then
			GearService.GiveOwned(player)
		end
	end)
	if player.Character then
		task.spawn(GearService.GiveOwned, player)
	end
end

function GearService.OnLoaded(player: Player)
	GearService.GiveOwned(player)
end

function GearService.Buy(player: Player, gearId: string): (boolean, string)
	local info = Gears.Get(gearId)
	local data = DataService.Get(player)
	if not info or not data then
		return false, "No disponible"
	end
	if data.Gears[gearId] then
		GearService.Give(player, gearId)
		return false, "Ya lo tienes"
	end
	if not DataService.SpendCash(player, info.Price) then
		return false, "Te faltan " .. Format.Cash(info.Price - data.Cash)
	end
	data.Gears[gearId] = true
	DataService.MarkChanged(player)
	GearService.Give(player, gearId)
	notify(player, info.Icon .. " ¡Has comprado " .. info.FullName .. "! Ya está en tu mochila.", "Success")
	Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "Buy" })
	return true, "OK"
end

function GearService.Start()
	for _, gearId in Gears.Order do
		templates[gearId] = ToolBuilder.Build(gearId)
	end

	Remotes.Function("BuyGear").OnServerInvoke = function(player, gearId)
		if type(gearId) ~= "string" then
			return false, "Petición inválida"
		end
		return GearService.Buy(player, gearId)
	end

	Remotes.Event("UseGear").OnServerEvent:Connect(function(player, gearId, target)
		if type(gearId) ~= "string" or typeof(target) ~= "Vector3" then
			return
		end
		if target.Magnitude ~= target.Magnitude or target.Magnitude > 1e5 then
			return
		end
		local tool = equippedGear(player, gearId)
		if not tool then
			return
		end
		if gearId == "Snowball" then
			throwSnowball(player, target)
		elseif gearId == "FreezeRay" then
			fireFreezeRay(player, tool, target)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return GearService
]======])
make('ServerScriptService', {'Server', 'Services', 'RebirthService'}, 'ModuleScript', [======[
-- Renacer: con suficiente dinero y un regalo de cierta rareza en tu taller, reinicias dinero y regalos a
-- cambio de +50% de ingresos, más huecos y más tiempo de bloqueo para siempre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rebirths = require(Shared.Config.Rebirths)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)

local RebirthService = {}

function RebirthService.Check(player: Player): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Tus datos aún se están cargando"
	end
	local requirement = Rebirths.Requirement(data.Rebirths)
	if not requirement then
		return false, "¡Ya tienes el renacimiento máximo!"
	end
	if data.Cash < requirement.Cost then
		return false, "Te faltan " .. Format.Cash(requirement.Cost - data.Cash)
	end
	if not BaseService.HasRarity(player, requirement.Rarity) then
		return false, "Necesitas un regalo " .. requirement.RarityName .. " (o mejor) en tu taller"
	end
	return true, "OK"
end

function RebirthService.Rebirth(player: Player): (boolean, string)
	local ok, reason = RebirthService.Check(player)
	if not ok then
		return false, reason
	end
	local data = DataService.Get(player)
	local base = BaseService.GetBase(player)
	if not data or not base then
		return false, "No tienes taller"
	end
	BaseService.ClearPresents(base)
	data.Rebirths += 1
	data.Cash = GameConfig.StartCash
	data.Presents = {}
	BaseService.RefreshSlots(base)
	DataService.MarkChanged(player)

	local mult = Rebirths.IncomeMultiplier(data.Rebirths)
	Remotes.Event("Notify"):FireClient(
		player,
		string.format(
			"⭐ ¡RENACIMIENTO %d! Ahora ganas x%s, tienes %d huecos y %ds de bloqueo.",
			data.Rebirths,
			Format.Number(mult),
			Rebirths.SlotCount(data.Rebirths),
			Rebirths.LockDuration(data.Rebirths)
		),
		"Success"
	)
	Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "Rebirth" })
	Remotes.Event("Fx"):FireClient(player, "Confetti", { Big = true })
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Event("Notify"):FireClient(other, string.format("⭐ %s ha renacido (nivel %d)", player.DisplayName, data.Rebirths), "Rare")
		end
	end
	return true, "OK"
end

function RebirthService.Start()
	Remotes.Function("Rebirth").OnServerInvoke = function(player, action)
		if action == "check" then
			return RebirthService.Check(player)
		end
		return RebirthService.Rebirth(player)
	end
end

return RebirthService
]======])
make('ServerScriptService', {'Server', 'Services', 'StealService'}, 'ModuleScript', [======[
-- Robos: un jugador mantiene E sobre un regalo de una base abierta ajena, lo lleva sobre la cabeza (más
-- lento) y si llega a su propia base se lo queda. Si le golpean, le congelan, muere, se acaba el tiempo o
-- se desconecta, el regalo vuelve a su dueño.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PresentBuilder = require(Shared.PresentBuilder)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local CharacterService = require(script.Parent.CharacterService)

local StealService = {}

type Carry = {
	Thief: Player,
	Victim: Player,
	Base: BaseService.BaseRecord,
	SlotIndex: number,
	PresentId: string,
	Mutation: string?,
	Model: Model,
	StartedAt: number,
}

local carries: { [Player]: Carry } = {}
local carryFolder: Folder

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "Info")
end

local function presentLabel(presentId: string, mutation: string?): string
	local info = Presents.Get(presentId)
	local name = if info then info.Name else "regalo"
	if mutation and mutation ~= "" then
		return Mutations.DisplayName(mutation) .. " " .. name
	end
	return name
end

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

local function endCarry(carry: Carry)
	carries[carry.Thief] = nil
	if carry.Model.Parent then
		carry.Model:Destroy()
	end
	if carry.Thief.Parent then
		carry.Thief:SetAttribute("Carrying", nil)
		carry.Thief:SetAttribute("CarryingRarity", nil)
		carry.Thief:SetAttribute("CarryEndsAt", nil)
		CharacterService.SetFlag(carry.Thief, "Carrying", false)
	end
end

-- El regalo vuelve a su dueño
function StealService.Fail(carry: Carry, reason: string)
	if carries[carry.Thief] ~= carry then
		return
	end
	local root = carry.Model.PrimaryPart
	local from = if root then root.Position else nil
	endCarry(carry)
	if carry.Base.Owner == carry.Victim then
		BaseService.RestorePresent(carry.Base, carry.SlotIndex, from)
	end
	local label = presentLabel(carry.PresentId, carry.Mutation)
	if carry.Thief.Parent then
		notify(carry.Thief, "❌ " .. reason .. " ¡Has perdido " .. label .. "!", "Error")
		Remotes.Event("Fx"):FireClient(carry.Thief, "Sound", { Name = "Fail" })
	end
	if carry.Victim.Parent then
		notify(carry.Victim, "🛡️ ¡" .. label .. " ha vuelto a tu taller!", "Success")
		DataService.AddStat(carry.Victim, "Defended", 1)
	end
	if from then
		Remotes.Event("Fx"):FireAllClients("Burst", { Position = from, Color = Color3.fromRGB(255, 255, 255), Count = 18 })
	end
end

function StealService.ForceDrop(player: Player, reason: string): boolean
	local carry = carries[player]
	if not carry then
		return false
	end
	StealService.Fail(carry, reason)
	return true
end

local function deliver(carry: Carry)
	local thief = carry.Thief
	local thiefBase = BaseService.GetBase(thief)
	if not thiefBase then
		StealService.Fail(carry, "No tienes taller.")
		return
	end
	local slotIndex = BaseService.FindFreeSlot(thiefBase)
	if not slotIndex then
		StealService.Fail(carry, "Tu taller está lleno.")
		return
	end
	local root = carry.Model.PrimaryPart
	local from = if root then root.Position else thiefBase.CFrame.Position
	local present = carry.Base.Slots[carry.SlotIndex].Present
	local stored = 0
	endCarry(carry)
	if carry.Base.Owner == carry.Victim and present and present.Id == carry.PresentId then
		BaseService.RemovePresent(carry.Base, carry.SlotIndex)
	end
	BaseService.PlacePresent(thiefBase, slotIndex, carry.PresentId, carry.Mutation, { From = from, Stored = stored })
	local isNew = DataService.Discover(thief, carry.PresentId, carry.Mutation)
	DataService.AddStat(thief, "Steals", 1)
	DataService.MarkChanged(thief)
	if carry.Victim.Parent then
		DataService.AddStat(carry.Victim, "Stolen", 1)
		DataService.MarkChanged(carry.Victim)
	end

	local label = presentLabel(carry.PresentId, carry.Mutation)
	notify(thief, "😈 ¡Robo completado! " .. label .. " ya es tuyo." .. (if isNew then "  📖 ¡Nuevo en tu índice!" else ""), "Success")
	Remotes.Event("Fx"):FireClient(thief, "Sound", { Name = "Success" })
	Remotes.Event("Fx"):FireClient(thief, "Confetti", {})
	if carry.Victim.Parent then
		notify(carry.Victim, "😭 " .. thief.DisplayName .. " te ha robado " .. label .. ".", "Error")
	end
	local info = Presents.Get(carry.PresentId)
	if info and Rarities.Get(info.Rarity).Index >= GameConfig.Belt.AnnounceRarity then
		for _, other in Players:GetPlayers() do
			if other ~= thief and other ~= carry.Victim then
				notify(other, string.format("😈 %s le ha robado %s a %s", thief.DisplayName, label, carry.Victim.DisplayName), "Rare")
			end
		end
	end
	Remotes.Event("Fx"):FireAllClients("Burst", { Position = from, Color = Color3.fromRGB(255, 210, 80), Count = 30 })
end

function StealService.TrySteal(thief: Player, baseId: number, slotIndex: number)
	local base = BaseService.GetBaseById(baseId)
	if not base then
		return
	end
	local victim = base.Owner
	if not victim or victim == thief then
		return
	end
	if not DataService.IsLoaded(thief) then
		return
	end
	if carries[thief] then
		notify(thief, "Ya llevas un regalo. ¡Llévalo a tu taller!", "Warning")
		return
	end
	if BaseService.IsLocked(base) then
		notify(thief, "🔒 Esta base está bloqueada.", "Warning")
		return
	end
	local thiefBase = BaseService.GetBase(thief)
	if not thiefBase then
		notify(thief, "Necesitas un taller para guardar lo que robes.", "Warning")
		return
	end
	if not BaseService.FindFreeSlot(thiefBase) then
		notify(thief, "🎁 Tu taller está lleno: vende algo antes de robar.", "Warning")
		return
	end
	if CharacterService.IsFrozen(thief) then
		return
	end
	local root = CharacterService.GetRoot(thief)
	local slot = base.Slots[slotIndex]
	if not root or not slot then
		return
	end
	if (root.Position - slot.Pedestal.Position).Magnitude > GameConfig.Steal.StealDistance then
		return
	end
	local present = BaseService.MarkStealing(base, slotIndex)
	if not present then
		return
	end

	-- el regalo va sobre la cabeza del ladrón
	local model = PresentBuilder.Build(present.Id, present.Mutation, { Scale = 0.7, NoEffects = false })
	model.Name = "Carried_" .. thief.Name
	model:SetAttribute("Mode", "Carried")
	local presentRoot = model.PrimaryPart :: BasePart
	PresentBuilder.PlaceAt(model, root.CFrame * CFrame.new(0, 3.2, 0))
	presentRoot.Anchored = false
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = presentRoot
	weld.C0 = CFrame.new(0, 3.2, 0)
	weld.Parent = presentRoot
	model.Parent = carryFolder

	local carry: Carry = {
		Thief = thief,
		Victim = victim,
		Base = base,
		SlotIndex = slotIndex,
		PresentId = present.Id,
		Mutation = present.Mutation,
		Model = model,
		StartedAt = os.clock(),
	}
	carries[thief] = carry
	CharacterService.SetFlag(thief, "Carrying", true)
	local info = Presents.Get(present.Id)
	thief:SetAttribute("Carrying", presentLabel(present.Id, present.Mutation))
	thief:SetAttribute("CarryingRarity", if info then info.Rarity else "Common")
	thief:SetAttribute("CarryEndsAt", workspace:GetServerTimeNow() + GameConfig.Steal.MaxCarryTime)

	local label = presentLabel(present.Id, present.Mutation)
	notify(thief, "🏃 ¡Lo tienes! Corre a tu taller con " .. label .. ".", "Success")
	Remotes.Event("Alert"):FireClient(victim, thief.DisplayName, label)
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Steal", Position = slot.Pedestal.Position })
end

-- Arranque ----------------------------------------------------------------------------------------------

function StealService.Start()
	carryFolder = Instance.new("Folder")
	carryFolder.Name = "CarriedPresents"
	carryFolder.Parent = workspace

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "StealPrompt" then
			return
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		if not model then
			return
		end
		local baseId = model:GetAttribute("BaseId")
		local slotIndex = model:GetAttribute("SlotIndex")
		if type(baseId) == "number" and type(slotIndex) == "number" then
			StealService.TrySteal(player, baseId, slotIndex)
		end
	end)

	-- si el dueño se va, el robo se cancela (sus regalos se guardan con él)
	BaseService.Releasing:Connect(function(base)
		for _, carry in carries do
			if carry.Base == base then
				endCarry(carry)
				if carry.Thief.Parent then
					notify(carry.Thief, "El dueño de ese regalo se ha ido del servidor.", "Warning")
				end
			end
		end
	end)
	BaseService.Cleared:Connect(function(base)
		for _, carry in carries do
			if carry.Base == base then
				endCarry(carry)
				if carry.Thief.Parent then
					notify(carry.Thief, "Ese regalo ha desaparecido.", "Warning")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carry = carries[player]
		if carry then
			StealService.Fail(carry, "Te has desconectado.")
		end
	end)

	RunService.Heartbeat:Connect(function()
		for thief, carry in carries do
			local root = CharacterService.GetRoot(thief)
			if not root or not carry.Model.PrimaryPart then
				StealService.Fail(carry, "¡Te han eliminado!")
			elseif os.clock() - carry.StartedAt > GameConfig.Steal.MaxCarryTime then
				StealService.Fail(carry, "¡Se acabó el tiempo!")
			else
				local thiefBase = BaseService.GetBase(thief)
				if thiefBase and BaseService.IsInside(thiefBase, root.Position, -1) then
					deliver(carry)
				end
			end
		end
	end)
end

return StealService
]======])
make('ServerScriptService', {'Server', 'World', 'BaseBuilder'}, 'ModuleScript', [======[
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
		Build.Cylinder(slot, 0.22, 5.12, pcf * CF(0, 1.95, 0), { Color = GOLD, Material = Enum.Material.Metal, Name = "Rim", CanCollide = false })
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
]======])
make('ServerScriptService', {'Server', 'World', 'Build'}, 'ModuleScript', [======[
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
]======])
make('ServerScriptService', {'Server', 'World', 'Decor'}, 'ModuleScript', [======[
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
]======])
make('ServerScriptService', {'Server', 'World', 'Layout'}, 'ModuleScript', [======[
-- Posiciones fijas del mapa. Las bases miran hacia la cinta: en el espacio local de una base, -Z es la
-- entrada (hacia la cinta) y +Z el fondo.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local Layout = {}

Layout.Version = 4

Layout.Base = {
	Width = 56, -- eje X local
	Depth = 60, -- eje Z local
	WallHeight = 12,
	EntranceWidth = 16,
	FloorTop = 1,
	PedestalTop = 2.3,
	ZoneHeight = 22,
}

local BASE_X = { -135, -45, 45, 135 }
local BASE_Z = 64

Layout.BaseThemes = {
	{ Name = "Rojo", Color = Color3.fromRGB(226, 46, 62) },
	{ Name = "Verde", Color = Color3.fromRGB(46, 190, 100) },
	{ Name = "Azul", Color = Color3.fromRGB(60, 132, 245) },
	{ Name = "Morado", Color = Color3.fromRGB(160, 86, 240) },
	{ Name = "Dorado", Color = Color3.fromRGB(245, 186, 40) },
	{ Name = "Rosa", Color = Color3.fromRGB(245, 110, 186) },
	{ Name = "Turquesa", Color = Color3.fromRGB(40, 206, 214) },
	{ Name = "Naranja", Color = Color3.fromRGB(248, 136, 40) },
}

-- CFrame del centro de cada base (a nivel del suelo), mirando hacia la cinta
function Layout.BaseCFrame(index: number): CFrame
	local col = (index - 1) % 4 + 1
	local north = index <= 4
	local center = Vector3.new(BASE_X[col], 0, if north then -BASE_Z else BASE_Z)
	local facing = if north then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	return CFrame.lookAt(center, center + facing)
end

-- Posición local del hueco i (1..16): impares a la izquierda, pares a la derecha, de la entrada al fondo
function Layout.SlotLocal(index: number): (Vector3, Vector3, number)
	local side = if index % 2 == 1 then -1 else 1
	local row = math.ceil(index / 2)
	local z = -21 + (row - 1) * 6.5
	local pedestal = Vector3.new(side * 21, 0, z)
	local pad = Vector3.new(side * 15.4, 0, z)
	return pedestal, pad, side
end

-- CFrame de la base del regalo colocado en el hueco i, mirando hacia el pasillo central
function Layout.SlotPresentCFrame(baseCF: CFrame, index: number): CFrame
	local pedestal, _, side = Layout.SlotLocal(index)
	local yaw = if side < 0 then -math.pi / 2 else math.pi / 2
	return baseCF * CFrame.new(pedestal + Vector3.new(0, Layout.Base.PedestalTop, 0)) * CFrame.Angles(0, yaw, 0)
end

Layout.Belt = {
	StartX = GameConfig.Belt.StartX,
	EndX = GameConfig.Belt.EndX,
	Z = GameConfig.Belt.Z,
	SurfaceY = GameConfig.Belt.SurfaceY,
	BuildMinX = -196,
	BuildMaxX = 196,
	Width = 10,
}

Layout.Factory = Vector3.new(-212, 0, 0)
Layout.Furnace = Vector3.new(206, 0, 0)
Layout.Plaza = Vector3.new(262, 0, 0)
Layout.Shop = Vector3.new(238, 0, -46)
Layout.Altar = Vector3.new(238, 0, 46)
Layout.PlazaSpawn = Vector3.new(232, 0, 0)

Layout.Bounds = {
	MinX = -300,
	MaxX = 330,
	MinZ = -160,
	MaxZ = 160,
}

return Layout
]======])
make('ServerScriptService', {'Server', 'World', 'LightingSetup'}, 'ModuleScript', [======[
-- Noche de Navidad: cielo estrellado, niebla azulada, brillo en las luces de neón.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function LightingSetup.Apply()
	Lighting.ClockTime = 20.6
	Lighting.GeographicLatitude = 41
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(92, 102, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 140, 184)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local sky = ensure("Sky", "NightSky") :: Sky
	sky.StarCount = 6000
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 10
	sky.CelestialBodiesShown = true

	local atmosphere = ensure("Atmosphere", "SnowAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(176, 196, 255)
	atmosphere.Decay = Color3.fromRGB(92, 104, 168)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	color.Brightness = 0.03
	color.Contrast = 0.1
	color.Saturation = 0.12
	color.TintColor = Color3.fromRGB(242, 246, 255)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.03
	rays.Spread = 0.6
end

return LightingSetup
]======])
make('ServerScriptService', {'Server', 'World', 'MapBuilder'}, 'ModuleScript', [======[
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
]======])
make('ServerScriptService', {'Server', 'World', 'PresentDisplay'}, 'ModuleScript', [======[
-- Carteles flotantes y prompts de los regalos (en la cinta y en los pedestales).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)

local PresentDisplay = {}

local GREEN = Color3.fromRGB(110, 255, 120)
local YELLOW = Color3.fromRGB(255, 226, 80)

local function line(parent: Instance, text: string, color: Color3, height: number, order: number, font: Enum.Font?): TextLabel
	return Gui.Label({
		Name = "Line" .. order,
		Text = text,
		TextColor3 = color,
		Font = font or Gui.Fonts.Bold,
		Size = UDim2.new(1, 0, height, 0),
		LayoutOrder = order,
		Parent = parent,
		StrokeThickness = 2,
	})
end

local function rarityLine(parent: Instance, rarityId: string, height: number, order: number)
	local rarity = Rarities.Get(rarityId)
	local label = line(parent, rarity.Name, rarity.Color, height, order, Gui.Fonts.Title)
	if rarity.Rainbow then
		label.TextColor3 = Color3.new(1, 1, 1)
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
	return label
end

local function mutationLine(parent: Instance, mutationId: string?, height: number, order: number)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	local label = line(parent, mutation.Name .. "  x" .. mutation.Mult, mutation.TextColor, height, order, Gui.Fonts.Title)
	if mutation.Rainbow then
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
end

function PresentDisplay.Price(presentId: string, mutationId: string?): number
	local info = Presents.Get(presentId)
	if not info then
		return 0
	end
	return math.floor(info.Price * Mutations.Multiplier(mutationId))
end

function PresentDisplay.BaseIncome(presentId: string, mutationId: string?): number
	local info = Presents.Get(presentId)
	if not info then
		return 0
	end
	return info.Income * Mutations.Multiplier(mutationId)
end

local function holder(model: Model): Attachment
	local root = model.PrimaryPart :: BasePart
	return root:FindFirstChild("Top") :: Attachment
end

-- Cartel completo de un regalo en la cinta
function PresentDisplay.Belt(model: Model, presentId: string, mutationId: string?)
	local info = Presents.Get(presentId)
	if not info then
		return
	end
	local billboard = Gui.Billboard(holder(model), Vector2.new(10, 5.6), Vector3.new(0, 2.9, 0), 90)
	billboard.Name = "Info"
	local frame = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = billboard })
	Gui.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = frame
	mutationLine(frame, mutationId, 0.17, 1)
	line(frame, info.Name, Color3.new(1, 1, 1), 0.21, 2)
	rarityLine(frame, info.Rarity, 0.17, 3)
	line(frame, Format.Income(PresentDisplay.BaseIncome(presentId, mutationId)), YELLOW, 0.17, 4)
	line(frame, Format.Cash(PresentDisplay.Price(presentId, mutationId)), GREEN, 0.25, 5, Gui.Fonts.Title)
end

-- Cartel de un regalo en un pedestal
function PresentDisplay.Slot(model: Model, presentId: string, mutationId: string?, incomePerSecond: number)
	local info = Presents.Get(presentId)
	if not info then
		return
	end
	local billboard = Gui.Billboard(holder(model), Vector2.new(8, 3.6), Vector3.new(0, 1.8, 0), 70)
	billboard.Name = "Info"
	local frame = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = billboard })
	Gui.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = frame
	mutationLine(frame, mutationId, 0.24, 1)
	line(frame, info.Name, Color3.new(1, 1, 1), 0.28, 2)
	rarityLine(frame, info.Rarity, 0.22, 3)
	line(frame, Format.Income(incomePerSecond), YELLOW, 0.26, 4).Name = "Income"
end

function PresentDisplay.Prompt(parent: Instance, props: { [string]: any }): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Style = Enum.ProximityPromptStyle.Default
	for key, value in props do
		(prompt :: any)[key] = value
	end
	prompt.Parent = parent
	return prompt
end

-- Pilar de luz para los regalos legendarios o mejores
function PresentDisplay.LightPillar(model: Model, color: Color3)
	local root = model.PrimaryPart :: BasePart
	local bottom = Instance.new("Attachment")
	bottom.Name = "PillarBottom"
	bottom.Parent = root
	local top = Instance.new("Attachment")
	top.Name = "PillarTop"
	top.Position = Vector3.new(0, 70, 0)
	top.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "Pillar"
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 2.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Segments = 1
	beam.Parent = root
end

return PresentDisplay
]======])
make('ServerScriptService', {'Server', 'World', 'TerrainBuilder'}, 'ModuleScript', [======[
-- Montañas nevadas alrededor del mapa con Terrain (solo en ejecución: Lune no puede hornear terreno).

local Layout = require(script.Parent.Layout)
local Rng = require(game:GetService("ReplicatedStorage").Shared.Util.Rng)

local TerrainBuilder = {}

function TerrainBuilder.Build()
	local terrain = workspace.Terrain
	if terrain:GetAttribute("DSTPBuilt") then
		return
	end
	terrain:SetAttribute("DSTPBuilt", true)
	pcall(function()
		terrain.WaterWaveSize = 0
		terrain.Decoration = false
	end)
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(240, 246, 255))
		terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(170, 215, 255))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(120, 128, 145))
	end)

	local rng = Rng.new(31)
	local b = Layout.Bounds
	local margin = 26
	local function hill(x: number, z: number, radius: number)
		local pos = Vector3.new(x, -radius * 0.35, z)
		terrain:FillBall(pos, radius, Enum.Material.Snow)
		if radius > 50 then
			terrain:FillBall(pos + Vector3.new(rng:Range(-10, 10), radius * 0.45, rng:Range(-10, 10)), radius * 0.45, Enum.Material.Glacier)
			terrain:FillBall(pos + Vector3.new(0, radius * 0.6, 0), radius * 0.32, Enum.Material.Snow)
		end
	end

	-- norte y sur
	for x = b.MinX - 60, b.MaxX + 60, 42 do
		hill(x + rng:Range(-12, 12), b.MinZ - margin - rng:Range(10, 40), rng:Range(40, 72))
		hill(x + rng:Range(-12, 12), b.MaxZ + margin + rng:Range(10, 40), rng:Range(40, 72))
	end
	-- este y oeste
	for z = b.MinZ - 40, b.MaxZ + 40, 42 do
		hill(b.MinX - margin - rng:Range(10, 40), z + rng:Range(-12, 12), rng:Range(44, 76))
		hill(b.MaxX + margin + rng:Range(10, 40), z + rng:Range(-12, 12), rng:Range(44, 76))
	end
	-- picos lejanos
	for _ = 1, 14 do
		local angle = rng:Range(0, math.pi * 2)
		local dist = rng:Range(420, 520)
		local center = Vector3.new(15 + math.cos(angle) * dist, 0, math.sin(angle) * dist * 0.75)
		hill(center.X, center.Z, rng:Range(80, 120))
	end
end

return TerrainBuilder
]======])
make('ServerScriptService', {'Server', 'World', 'ToolBuilder'}, 'ModuleScript', [======[
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
]======])
make('ServerScriptService', {'Server', 'World', 'WorldLabels'}, 'ModuleScript', [======[
-- Textos de los carteles del mapa (se crean al arrancar, no se hornean).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gui = require(ReplicatedStorage.Shared.Util.Gui)

local WorldLabels = {}

local function signText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local surface = Gui.Create("SurfaceGui", {
		Name = "Label" .. face.Name,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 36,
		LightInfluence = 0,
		Brightness = 1.6,
		Parent = part,
	})
	local label = Gui.Label({
		Text = text,
		Font = font or Gui.Fonts.Title,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 4,
		Parent = surface,
	})
	Gui.Padding(10).Parent = label
	return label
end

function WorldLabels.Apply(map: Instance)
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") then
			local text = descendant:GetAttribute("Label")
			if type(text) == "string" and not descendant:FindFirstChild("LabelFront") then
				signText(descendant, Enum.NormalId.Front, text, Color3.fromRGB(255, 240, 200))
			end
			if descendant:GetAttribute("Title") and not descendant:FindFirstChild("LabelRight") then
				for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
					local label = signText(descendant, face, "DON'T STEAL THE PRESENT", Color3.fromRGB(255, 255, 255))
					local sub = Gui.Label({
						Text = "🎁 ¡No robes el regalo! 🎁",
						Font = Gui.Fonts.Bold,
						TextColor3 = Color3.fromRGB(255, 220, 90),
						Size = UDim2.fromScale(1, 0.3),
						Position = UDim2.fromScale(0, 0.72),
						StrokeThickness = 3,
						Parent = label.Parent,
					})
					label.Size = UDim2.fromScale(1, 0.72)
					sub.ZIndex = 2
				end
			end
		end
	end
end

return WorldLabels
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'Controllers', 'BaseController'}, 'ModuleScript', [======[
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
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'Controllers', 'EffectsController'}, 'ModuleScript', [======[
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
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'Controllers', 'GearController'}, 'ModuleScript', [======[
-- Gears con puntería (bola de nieve y rayo): al hacer clic/tocar se manda al servidor hacia dónde apuntas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gears = require(Shared.Config.Gears)
local Remotes = require(Shared.Net.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local GearController = {}

local AIMED = { Snowball = true, FreezeRay = true }
local hooked: { [Tool]: boolean } = {}
local lastUse: { [string]: number } = {}

local function aimPoint(): Vector3
	local hit = mouse.Hit
	if hit then
		return hit.Position
	end
	local camera = workspace.CurrentCamera
	return camera.CFrame.Position + camera.CFrame.LookVector * 100
end

local function hook(tool: Tool)
	if hooked[tool] then
		return
	end
	local gearId = tool:GetAttribute("GearId")
	if type(gearId) ~= "string" or not AIMED[gearId] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local info = Gears.Get(gearId)
		if not info then
			return
		end
		local t = os.clock()
		if t - (lastUse[gearId] or 0) < info.Cooldown then
			return
		end
		lastUse[gearId] = t
		-- animación de lanzar (el Animate por defecto la reproduce y se replica)
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.4, function()
			anim:Destroy()
		end)
		Remotes.Event("UseGear"):FireServer(gearId, aimPoint())
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then
			hooked[tool] = nil
		end
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			hook(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(hook, child)
		end
	end)
end

function GearController.Start()
	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	local function onCharacter(character: Model)
		mouse.TargetFilter = character
		watch(character)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return GearController
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'Controllers', 'SoundController'}, 'ModuleScript', [======[
-- Reproduce los sonidos del juego por nombre (ver Shared/Config/Sounds).

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local GameConfig = require(Shared.Config.GameConfig)

local SoundController = {}

local templates: { [string]: Sound } = {}
local folder: Folder
local music: Sound? = nil
SoundController.Muted = false

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local info = Sounds[name]
	if not info then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.Id
	sound.Volume = info.Volume
	sound.PlaybackSpeed = info.Pitch
	sound.Parent = folder
	templates[name] = sound
	return sound
end

function SoundController.Play(name: string, position: Vector3?, pitchJitter: number?)
	if SoundController.Muted then
		return
	end
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	if pitchJitter then
		sound.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchJitter
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = workspace.CurrentCamera
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 220
		sound.Parent = holder
		sound:Play()
		task.delay(6, function()
			holder:Destroy()
		end)
	else
		sound.Parent = folder
		sound:Play()
		task.delay(6, function()
			sound:Destroy()
		end)
	end
end

function SoundController.SetMuted(muted: boolean)
	SoundController.Muted = muted
	if music then
		music.Volume = if muted then 0 else GameConfig.MusicVolume
	end
end

function SoundController.Start()
	folder = Instance.new("Folder")
	folder.Name = "DSTPSounds"
	folder.Parent = SoundService
	for name in Sounds do
		template(name)
	end
	if GameConfig.MusicSoundId ~= "" then
		local track = Instance.new("Sound")
		track.Name = "Music"
		track.SoundId = GameConfig.MusicSoundId
		track.Volume = GameConfig.MusicVolume
		track.Looped = true
		track.Parent = folder
		track:Play()
		music = track
	end
end

return SoundController
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'Controllers', 'WorldAnimator'}, 'ModuleScript', [======[
-- Todo lo que se mueve en el mundo, animado en el cliente (suave y sin coste de red):
--   · regalos de la cinta (posición calculada con la hora del servidor), saltito al llegar a un pedestal,
--     flotar y girar en los pedestales, piezas que giran dentro de los regalos
--   · rayas de la cinta, engranajes de la fábrica, estrella del árbol gigante, cristal del altar
--   · luces que parpadean y piezas/textos arcoíris

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.Parent.ClientState)

local WorldAnimator = {}

type Tracked = {
	Model: Model,
	Root: BasePart,
	Mode: string,
	Home: CFrame,
	Phase: number,
	Spins: { { Weld: Weld, Base: CFrame, Speed: number, Axis: Vector3 } },
}

local tracked: { [Model]: Tracked } = {}
local rainbowParts: { [BasePart]: number } = {}
local rainbowGradients: { [UIGradient]: boolean } = {}

local stripes: { { Part: BasePart, X: number } } = {}
local stripeMin, stripeRange, stripeSpeed = 0, 1, 7

local gears: { { Part: BasePart, Base: CFrame, Speed: number, Children: { { Part: BasePart, Offset: CFrame } } } } = {}
local stars: { { Part: BasePart, Offset: CFrame } } = {}
local starCenter: CFrame? = nil
local floaters: { { Part: BasePart, Base: CFrame } } = {}
local bulbs: { BasePart } = {}

local ARRIVE_TIME = 0.9

local function collectSpins(model: Model)
	local spins = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "SpinWeld" then
			local axis = d:GetAttribute("SpinAxis")
			table.insert(spins, {
				Weld = d,
				Base = d.C0,
				Speed = (d:GetAttribute("SpinSpeed") :: number?) or 1,
				Axis = if typeof(axis) == "Vector3" then axis else Vector3.new(0, 1, 0),
			})
		end
	end
	return spins
end

local function track(model: Model)
	if tracked[model] then
		return
	end
	local mode = model:GetAttribute("Mode")
	if type(mode) ~= "string" or mode == "Carried" then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
	if not root then
		return
	end
	tracked[model] = {
		Model = model,
		Root = root,
		Mode = mode,
		Home = root.CFrame,
		Phase = math.random() * math.pi * 2,
		Spins = collectSpins(model),
	}
end

local function onDescendant(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute("Mode") ~= nil then
		-- esperar a que lleguen las piezas
		task.defer(function()
			if instance.Parent then
				track(instance)
			end
		end)
	end
end

local function addRainbowPart(instance: Instance)
	if instance:IsA("BasePart") then
		rainbowParts[instance] = (instance:GetAttribute("HueOffset") :: number?) or math.random()
	end
end

local function addRainbowText(instance: Instance)
	local gradient = instance:FindFirstChildOfClass("UIGradient")
	if gradient then
		rainbowGradients[gradient] = true
	end
end

local function setupMap(map: Instance)
	local conveyor = map:FindFirstChild("Conveyor")
	local stripeFolder = conveyor and conveyor:FindFirstChild("Stripes")
	if stripeFolder then
		stripeMin = (stripeFolder:GetAttribute("MinX") :: number?) or -196
		local maxX = (stripeFolder:GetAttribute("MaxX") :: number?) or 196
		stripeRange = maxX - stripeMin
		for _, part in stripeFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(stripes, { Part = part, X = part.Position.X })
			end
		end
	end
	local gearByIndex: { [number]: any } = {}
	for _, part in CollectionService:GetTagged("SpinGear") do
		if part:IsA("BasePart") and part:IsDescendantOf(map) then
			local entry = { Part = part, Base = part.CFrame, Speed = (part:GetAttribute("SpinSpeed") :: number?) or 0.5, Children = {} }
			table.insert(gears, entry)
			gearByIndex[(part:GetAttribute("GearIndex") :: number?) or 0] = entry
		end
	end
	for _, tooth in CollectionService:GetTagged("SpinGearTooth") do
		if tooth:IsA("BasePart") then
			local gear = gearByIndex[(tooth:GetAttribute("Gear") :: number?) or -1]
			if gear then
				table.insert(gear.Children, { Part = tooth, Offset = gear.Base:Inverse() * tooth.CFrame })
			end
		end
	end
	local core: BasePart? = nil
	for _, part in CollectionService:GetTagged("SpinStar") do
		if part:IsA("BasePart") and part.Name == "StarCore" then
			core = part
		end
	end
	if core then
		starCenter = core.CFrame
		for _, part in CollectionService:GetTagged("SpinStar") do
			if part:IsA("BasePart") then
				table.insert(stars, { Part = part, Offset = core.CFrame:Inverse() * part.CFrame })
			end
		end
	end
	for _, part in CollectionService:GetTagged("FloatSpin") do
		if part:IsA("BasePart") then
			table.insert(floaters, { Part = part, Base = part.CFrame })
		end
	end
	for _, part in CollectionService:GetTagged("TwinkleBulb") do
		if part:IsA("BasePart") then
			table.insert(bulbs, part)
		end
	end
end

local function updatePresents(t: number, now: number)
	for model, entry in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		local mode = model:GetAttribute("Mode")
		if mode == "Carried" then
			tracked[model] = nil
			continue
		end
		local root = entry.Root
		if mode == "Belt" then
			local spawnT = (model:GetAttribute("SpawnT") :: number?) or now
			local speed = (model:GetAttribute("Speed") :: number?) or 7
			local startX = (model:GetAttribute("StartX") :: number?) or -190
			local endX = (model:GetAttribute("EndX") :: number?) or 190
			local beltZ = (model:GetAttribute("BeltZ") :: number?) or 0
			local beltY = (model:GetAttribute("BeltY") :: number?) or 2.6
			local x = startX + speed * (now - spawnT)
			local sink = 0
			if x > endX - 4 then
				sink = math.min(6, (x - (endX - 4)) * 1.2)
			end
			local wobble = math.sin(t * 3 + entry.Phase) * 0.06
			root.CFrame = CFrame.new(math.min(x, endX + 2), beltY - sink, beltZ) * CFrame.Angles(0, -math.pi / 2 + wobble, 0)
		elseif mode == "Slot" then
			local home = entry.Home
			local arriveT = model:GetAttribute("ArriveT") :: number?
			local from = model:GetAttribute("ArriveFrom") :: Vector3?
			if arriveT and from and now - arriveT < ARRIVE_TIME then
				local alpha = math.clamp((now - arriveT) / ARRIVE_TIME, 0, 1)
				local eased = 1 - (1 - alpha) * (1 - alpha)
				local position = from:Lerp(home.Position, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 12, 0)
				root.CFrame = CFrame.new(position) * home.Rotation * CFrame.Angles(0, alpha * math.pi * 4, 0)
			else
				local bob = 0.35 + math.sin(t * 2 + entry.Phase) * 0.25
				root.CFrame = home * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 0.7 + entry.Phase) * 0.6, 0)
			end
		end
		for _, spin in entry.Spins do
			if spin.Weld.Parent then
				spin.Weld.C0 = spin.Base * CFrame.fromAxisAngle(spin.Axis, t * spin.Speed)
			end
		end
	end
end

local twinkleTimer = 0

local function updateWorld(t: number, dt: number)
	-- rayas de la cinta
	local offset = t * stripeSpeed
	for _, stripe in stripes do
		local x = stripeMin + ((stripe.X - stripeMin + offset) % stripeRange)
		local cf = stripe.Part.CFrame
		stripe.Part.CFrame = CFrame.new(x, cf.Y, cf.Z)
	end
	-- engranajes
	for _, gear in gears do
		local cf = gear.Base * CFrame.Angles(t * gear.Speed, 0, 0)
		gear.Part.CFrame = cf
		for _, child in gear.Children do
			child.Part.CFrame = cf * child.Offset
		end
	end
	-- estrella del árbol
	if starCenter then
		local cf = starCenter * CFrame.Angles(0, t * 0.6, 0)
		for _, star in stars do
			star.Part.CFrame = cf * star.Offset
		end
	end
	for i, floater in floaters do
		floater.Part.CFrame = floater.Base * CFrame.new(0, math.sin(t * 1.4 + i) * 0.8, 0) * CFrame.Angles(0, t * 0.8, 0)
	end
	-- luces que parpadean
	twinkleTimer += dt
	if twinkleTimer > 0.12 and #bulbs > 0 then
		twinkleTimer = 0
		for _ = 1, math.min(40, #bulbs) do
			local bulb = bulbs[math.random(1, #bulbs)]
			bulb.Transparency = if bulb.Transparency > 0.1 then 0 else 0.55
		end
	end
	-- arcoíris
	local hueBase = t * 0.25
	for part, hueOffset in rainbowParts do
		if part.Parent then
			part.Color = Color3.fromHSV((hueBase + hueOffset) % 1, 0.75, 1)
		else
			rainbowParts[part] = nil
		end
	end
	local rotation = (t * 120) % 360
	for gradient in rainbowGradients do
		if gradient.Parent then
			gradient.Rotation = rotation
			gradient.Offset = Vector2.new(math.sin(t * 2) * 0.3, 0)
		else
			rainbowGradients[gradient] = nil
		end
	end
end

function WorldAnimator.Start()
	local map = workspace:WaitForChild("Map", 60)
	if map then
		setupMap(map)
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Mode") ~= nil then
			track(d)
		end
	end
	workspace.DescendantAdded:Connect(onDescendant)
	for _, part in CollectionService:GetTagged("Rainbow") do
		addRainbowPart(part)
	end
	CollectionService:GetInstanceAddedSignal("Rainbow"):Connect(addRainbowPart)
	for _, label in CollectionService:GetTagged("RainbowText") do
		addRainbowText(label)
	end
	CollectionService:GetInstanceAddedSignal("RainbowText"):Connect(function(label)
		task.defer(addRainbowText, label)
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		updatePresents(t, ClientState.Now())
		updateWorld(t, dt)
	end)
end

return WorldAnimator
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'Hud'}, 'ModuleScript', [======[
-- HUD: dinero, ingresos, estado del bloqueo, botones de menú, cartel de evento y aviso de "llévalo a tu base".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Rebirths = require(Shared.Config.Rebirths)
local Events = require(Shared.Config.Events)
local Rarities = require(Shared.Config.Rarities)

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local player = Players.LocalPlayer

local Hud = {}

Hud.Callbacks = {} :: { [string]: () -> () }

local cashLabel: TextLabel
local incomeLabel: TextLabel
local rebirthLabel: TextLabel
local lockLabel: TextLabel
local lockChip: Frame
local carryHolder: Frame
local carryLabel: TextLabel
local eventHolder: Frame
local eventTitle: TextLabel
local eventDesc: TextLabel
local eventStroke: UIStroke?

local shownCash = 0
local targetCash = 0

local function menuButton(parent: Instance, icon: string, text: string, color: Color3, order: number, key: string)
	local button = Theme.Button({
		Name = key,
		Text = "",
		Color = color,
		Size = UDim2.fromOffset(104, 88),
		LayoutOrder = order,
		Parent = parent,
		OnClick = function()
			local callback = Hud.Callbacks[key]
			if callback then
				callback()
			end
		end,
	})
	Gui.Label({
		Text = icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		Font = Theme.Fonts.Title,
		StrokeThickness = 0,
		Parent = button,
	})
	Gui.Label({
		Text = text,
		Size = UDim2.new(1, 0, 0.36, 0),
		Position = UDim2.fromScale(0, 0.64),
		Font = Theme.Fonts.Title,
		StrokeThickness = 2,
		Parent = button,
	})
	return button
end

local function buildLeft(screen: ScreenGui)
	local holder = Gui.Create("Frame", {
		Name = "LeftHud",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(240, 420),
		Position = UDim2.new(0, 14, 0, 66),
		AnchorPoint = Vector2.new(0, 0),
		Parent = screen,
	})
	Theme.AutoScale(holder)
	Gui.List(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left).Parent = holder

	local cashPanel = Theme.Panel({ Name = "Cash", Size = UDim2.fromOffset(232, 104), Parent = holder, LayoutOrder = 1 })
	Gui.Label({
		Text = "💰",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(8, 8),
		StrokeThickness = 0,
		Parent = cashPanel,
	})
	cashLabel = Gui.Label({
		Name = "Amount",
		Text = "$0",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -66, 0, 46),
		Position = UDim2.fromOffset(58, 8),
		StrokeThickness = 3,
		Parent = cashPanel,
	})
	Gui.Gradient(Color3.fromRGB(190, 255, 170), Color3.fromRGB(70, 220, 100), 90).Parent = cashLabel
	incomeLabel = Gui.Label({
		Name = "Income",
		Text = "+$0/s",
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Income,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.62, -10, 0, 28),
		Position = UDim2.fromOffset(12, 62),
		StrokeThickness = 2,
		Parent = cashPanel,
	})
	rebirthLabel = Gui.Label({
		Name = "Rebirth",
		Text = "⭐ x1",
		Font = Theme.Fonts.Bold,
		TextColor3 = Color3.fromRGB(220, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.38, -8, 0, 28),
		Position = UDim2.new(0.62, 0, 0, 62),
		StrokeThickness = 2,
		Parent = cashPanel,
	})

	lockChip = Theme.Panel({ Name = "Lock", Size = UDim2.fromOffset(232, 40), Parent = holder, LayoutOrder = 2, Color = Theme.Colors.DarkRed, Radius = 12 })
	lockLabel = Gui.Label({
		Text = "🔓 Tu taller está ABIERTO",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 2,
		Parent = lockChip,
	})

	local grid = Gui.Create("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(232, 200), Parent = holder, LayoutOrder = 3 })
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(108, 90),
		CellPadding = UDim2.fromOffset(12, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	menuButton(grid, "🛒", "TIENDA", Theme.Colors.Green, 1, "Shop")
	menuButton(grid, "⭐", "RENACER", Theme.Colors.Purple, 2, "Rebirth")
	menuButton(grid, "📖", "ÍNDICE", Theme.Colors.Blue, 3, "Index")
	menuButton(grid, "❓", "AYUDA", Theme.Colors.Orange, 4, "Help")

	local mute = Theme.Button({
		Name = "Mute",
		Text = "🔊",
		Color = Theme.Colors.NavyLight,
		Size = UDim2.fromOffset(52, 42),
		LayoutOrder = 4,
		Parent = holder,
	})
	mute.Activated:Connect(function()
		SoundController.SetMuted(not SoundController.Muted)
		mute.Text = if SoundController.Muted then "🔇" else "🔊"
	end)
end

local function buildCarry(screen: ScreenGui)
	carryHolder = Gui.Create("Frame", {
		Name = "CarryHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 64),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = screen,
	})
	Theme.AutoScale(carryHolder)
	local panel = Theme.Panel({ Size = UDim2.fromScale(1, 1), Color = Theme.Colors.DarkGold, Parent = carryHolder })
	carryLabel = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 3,
		Parent = panel,
	})
end

local function buildEvent(screen: ScreenGui)
	eventHolder = Gui.Create("Frame", {
		Name = "EventHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(520, 78),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = screen,
	})
	Theme.AutoScale(eventHolder)
	local panel = Theme.Panel({ Name = "EventPanel", Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Blue, Parent = eventHolder })
	eventStroke = panel:FindFirstChildOfClass("UIStroke")
	eventTitle = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 0.56, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		StrokeThickness = 3,
		Parent = panel,
	})
	eventDesc = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = Color3.fromRGB(230, 240, 255),
		Size = UDim2.new(1, -20, 0.34, 0),
		Position = UDim2.new(0.5, 0, 0.6, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		StrokeThickness = 2,
		Parent = panel,
	})
end

local function refreshData()
	local data = ClientState.Data
	targetCash = data.Cash or 0
	local rebirths = data.Rebirths or 0
	rebirthLabel.Text = string.format("⭐ x%s", Format.Number(Rebirths.IncomeMultiplier(rebirths)))
end

local lastEventId = ""

local function update(dt: number)
	-- el dinero sube/baja con animación
	if math.abs(targetCash - shownCash) < 1 then
		shownCash = targetCash
	else
		shownCash += (targetCash - shownCash) * math.min(1, dt * 10)
	end
	cashLabel.Text = Format.Cash(shownCash)
	local income = (player:GetAttribute("Income") :: number?) or 0
	incomeLabel.Text = "+" .. Format.Income(income)

	-- bloqueo de tu base
	local base = ClientState.MyBase()
	if base then
		lockChip.Visible = true
		local locked, remaining = ClientState.IsMyBaseLocked()
		if locked then
			lockLabel.Text = "🔒 Bloqueado " .. Format.Clock(remaining)
			lockChip.BackgroundColor3 = Color3.new(1, 1, 1)
			local gradient = lockChip:FindFirstChildOfClass("UIGradient") :: UIGradient
			gradient.Color = ColorSequence.new(Color3.fromRGB(60, 200, 110), Color3.fromRGB(20, 120, 60))
		else
			local blink = (os.clock() % 1) < 0.5
			lockLabel.Text = if blink then "🔓 ¡Tu taller está ABIERTO!" else "🔓 Pisa el botón rojo para cerrar"
			local gradient = lockChip:FindFirstChildOfClass("UIGradient") :: UIGradient
			gradient.Color = ColorSequence.new(Color3.fromRGB(230, 70, 80), Color3.fromRGB(140, 20, 34))
		end
	else
		lockChip.Visible = false
	end

	-- llevando un regalo robado
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" then
		carryHolder.Visible = true
		local endsAt = (player:GetAttribute("CarryEndsAt") :: number?) or 0
		local remaining = endsAt - ClientState.Now()
		carryLabel.Text = string.format("🏃 ¡Lleva %s a tu taller!  ⏱ %d", carrying, math.max(0, math.ceil(remaining)))
		local rarity = Rarities.Get((player:GetAttribute("CarryingRarity") :: string?) or "Common")
		carryLabel.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4)
	else
		carryHolder.Visible = false
	end

	-- evento activo
	local eventId = workspace:GetAttribute("EventId")
	local event = Events.Get(if type(eventId) == "string" then eventId else nil)
	if event then
		local endsAt = (workspace:GetAttribute("EventEndsAt") :: number?) or 0
		local remaining = endsAt - ClientState.Now()
		if remaining > 0 then
			eventHolder.Visible = true
			eventTitle.Text = event.Name .. "   " .. Format.Clock(remaining)
			eventDesc.Text = event.Description
			if lastEventId ~= event.Id then
				lastEventId = event.Id
				local panel = eventHolder:FindFirstChild("EventPanel") :: Frame
				local gradient = panel:FindFirstChildOfClass("UIGradient") :: UIGradient
				gradient.Color = ColorSequence.new(event.Color, event.Color:Lerp(Color3.new(0, 0, 0), 0.45))
				if eventStroke then
					eventStroke.Color = event.Color:Lerp(Color3.new(0, 0, 0), 0.7)
				end
			end
		else
			eventHolder.Visible = false
		end
	else
		eventHolder.Visible = false
		lastEventId = ""
	end
end

function Hud.Start(screen: ScreenGui)
	buildLeft(screen)
	buildCarry(screen)
	buildEvent(screen)
	ClientState.Changed:Connect(refreshData)
	refreshData()
	shownCash = targetCash
	RunService.RenderStepped:Connect(update)
end

-- Posición del botón de dinero (para efectos que vuelan hacia él)
function Hud.CashLabel(): TextLabel
	return cashLabel
end

return Hud
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'IndexUI'}, 'ModuleScript', [======[
-- Índice de regalos: todos los regalos del juego con vista 3D; los que no has conseguido salen en sombra.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PresentBuilder = require(Shared.PresentBuilder)

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local IndexUI = {}

type Card = {
	Frame: Frame,
	Viewport: ViewportFrame,
	Name: TextLabel,
	Info: TextLabel,
	Dots: { [string]: Frame },
	Model: Model?,
	Discovered: boolean?,
	Distance: number,
	Height: number,
}

local modal: Theme.Modal
local cards: { [string]: Card } = {}
local counter: TextLabel
local built = false
local spinConnection: RBXScriptConnection? = nil

local MUTATION_KEYS = { "Normal", "Gold", "Diamond", "Frost", "Candy", "Rainbow" }

local function setSilhouette(model: Model, silhouette: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "Hub" then
			if silhouette then
				d:SetAttribute("OriginalColor", d:GetAttribute("OriginalColor") or d.Color)
				d.Color = Color3.fromRGB(8, 10, 20)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

local function fillViewport(card: Card, presentId: string, discovered: boolean)
	if card.Model and card.Discovered == discovered then
		return
	end
	if card.Model then
		card.Model:Destroy()
	end
	local model = PresentBuilder.Build(presentId, nil, { NoEffects = true })
	local height = PresentBuilder.GetHeight(model)
	setSilhouette(model, not discovered)
	model.Parent = card.Viewport
	card.Model = model
	card.Discovered = discovered
	local camera = card.Viewport.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = card.Viewport
	card.Viewport.CurrentCamera = camera
	local size = math.max(height, (model.PrimaryPart :: BasePart).Size.X * 2.2)
	local distance = size * 1.9 + 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.62, -distance), Vector3.new(0, height * 0.45, 0))
	card.Distance = distance
	card.Height = height
end

local function refresh()
	local index = ClientState.Data.Index or {}
	local found, total = 0, 0
	for _, info in Presents.List do
		total += 1
		local card = cards[info.Id]
		local entry = index[info.Id]
		local discovered = entry ~= nil and next(entry) ~= nil
		if discovered then
			found += 1
		end
		if card then
			fillViewport(card, info.Id, discovered)
			card.Name.Text = if discovered then info.Name else "???"
			local rarity = Rarities.Get(info.Rarity)
			card.Info.Text = if discovered then Format.Income(info.Income) else rarity.Name
			for key, dot in card.Dots do
				local has = entry ~= nil and entry[key] == true
				dot.BackgroundTransparency = if has then 0 else 0.75
			end
		end
	end
	counter.Text = string.format("📖 Descubiertos: %d / %d", found, total)
end

local function build()
	if built then
		return
	end
	built = true
	local scroller = modal.Content:FindFirstChild("Scroller") :: ScrollingFrame
	for order, info in Presents.List do
		local rarity = Rarities.Get(info.Rarity)
		local frame = Theme.Panel({
			Name = info.Id,
			Size = UDim2.fromOffset(150, 196),
			Color = rarity.Dark,
			Parent = scroller,
			LayoutOrder = order,
			StrokeColor = rarity.Color,
			StrokeThickness = 3,
		})
		frame.ZIndex = 23
		if rarity.Rainbow then
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				Gui.RainbowGradient().Parent = stroke
			end
		end
		local viewport = Gui.Create("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, 112),
			Position = UDim2.fromOffset(6, 6),
			Ambient = Color3.fromRGB(190, 190, 210),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-0.5, -1, 0.6),
			ZIndex = 24,
			Parent = frame,
		})
		local name = Gui.Label({
			Text = "???",
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, -10, 0, 22),
			Position = UDim2.fromOffset(5, 120),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		local rarityLabel = Gui.Label({
			Text = rarity.Name,
			Font = Theme.Fonts.Title,
			TextColor3 = rarity.Color,
			Size = UDim2.new(1, -10, 0, 16),
			Position = UDim2.fromOffset(5, 142),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		if rarity.Rainbow then
			Gui.RainbowGradient().Parent = rarityLabel
			rarityLabel:AddTag("RainbowText")
		end
		local infoLabel = Gui.Label({
			Text = "",
			Font = Theme.Fonts.Bold,
			TextColor3 = Theme.Colors.Income,
			Size = UDim2.new(1, -10, 0, 16),
			Position = UDim2.fromOffset(5, 158),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		local dotsFrame = Gui.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 12),
			Position = UDim2.fromOffset(5, 178),
			ZIndex = 24,
			Parent = frame,
		})
		Gui.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center).Parent = dotsFrame
		local dots = {}
		for i, key in MUTATION_KEYS do
			local mutation = Mutations.Get(key)
			local color = if mutation then mutation.TextColor else Color3.fromRGB(230, 230, 240)
			local dot = Gui.Create("Frame", {
				Name = key,
				BackgroundColor3 = color,
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = i,
				ZIndex = 25,
				Parent = dotsFrame,
			}, { Gui.CornerScale(0.5), Gui.BorderStroke(Color3.new(0, 0, 0), 1) })
			if key == "Rainbow" then
				Gui.RainbowGradient().Parent = dot
			end
			dots[key] = dot
		end
		cards[info.Id] = {
			Frame = frame,
			Viewport = viewport,
			Name = name,
			Info = infoLabel,
			Dots = dots,
			Model = nil,
			Discovered = nil,
			Distance = 10,
			Height = 3,
		}
	end
end

function IndexUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "📖 ÍNDICE DE REGALOS", Theme.Colors.Blue, Vector2.new(860, 560))
	counter = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 23,
		StrokeThickness = 2,
		Parent = modal.Content,
	})
	Gui.Label({
		Text = "Puntos: Normal · Dorado · Diamante · Escarcha · Caramelo · Arcoíris",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(200, 210, 240),
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 28),
		ZIndex = 23,
		StrokeThickness = 0,
		Parent = modal.Content,
	})
	local scroller = Gui.Create("ScrollingFrame", {
		Name = "Scroller",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.fromOffset(0, 50),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Snow,
		ZIndex = 22,
		Parent = modal.Content,
	})
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	Gui.Padding(6).Parent = scroller
	modal.OnOpen = function()
		build()
		refresh()
		if not spinConnection then
			spinConnection = RunService.RenderStepped:Connect(function()
				if not modal.IsOpen then
					return
				end
				local angle = os.clock() * 0.8
				local orbit = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				for _, card in cards do
					local camera = card.Viewport.CurrentCamera
					if camera and card.Model then
						local eye = orbit * card.Distance + Vector3.new(0, card.Height * 0.62, 0)
						camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, card.Height * 0.45, 0))
					end
				end
			end)
		end
	end
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function IndexUI.Open()
	modal:Open()
end

function IndexUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return IndexUI
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'IntroUI'}, 'ModuleScript', [======[
-- Pantalla de bienvenida con el logo animado y la ventana de ayuda "¿Cómo se juega?".

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local GameConfig = require(Shared.Config.GameConfig)

local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local IntroUI = {}

local helpModal: Theme.Modal

local STEPS = {
	{ "🎁", "COMPRA", "Los regalos salen de la Fábrica de Santa por la cinta. Acércate y pulsa E para comprarlos." },
	{ "💰", "COBRA", "Cada regalo de tu taller genera dinero. Pisa la placa verde de delante para cobrarlo." },
	{ "😈", "ROBA", "Entra en otro taller abierto, mantén E sobre un regalo y llévalo corriendo a tu taller." },
	{ "🔒", "PROTEGE", "Pisa el botón rojo de tu taller para bloquearlo. ¡Golpea a los ladrones con el bastón!" },
	{ "⭐", "RENACE", "Junta mucho dinero y un regalo raro para renacer: ganarás más y tendrás más huecos." },
}

local function stepRow(parent: Instance, index: number, step: { string })
	local row = Theme.Panel({ Name = "Step" .. index, Size = UDim2.new(1, -8, 0, 70), Color = Theme.Colors.NavyLight, Parent = parent, LayoutOrder = index, Radius = 14 })
	row.ZIndex = 23
	local badge = Gui.Create("Frame", {
		BackgroundColor3 = Theme.Colors.Gold,
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 24,
		Parent = row,
	}, { Gui.CornerScale(0.5), Gui.BorderStroke(Theme.Colors.DarkGold, 3) })
	Gui.Label({ Text = step[1], Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), StrokeThickness = 0, ZIndex = 25, Parent = badge })
	Gui.Label({
		Text = index .. ". " .. step[2],
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, -84, 0, 24),
		Position = UDim2.fromOffset(74, 6),
		ZIndex = 24,
		StrokeThickness = 2,
		Parent = row,
	})
	Gui.Label({
		Text = step[3],
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(225, 232, 250),
		Size = UDim2.new(1, -84, 0, 34),
		Position = UDim2.fromOffset(74, 30),
		ZIndex = 24,
		StrokeThickness = 0,
		Parent = row,
	})
end

function IntroUI.OpenHelp()
	helpModal:Open()
end

function IntroUI.ToggleHelp()
	if helpModal.IsOpen then
		helpModal:Close()
	else
		helpModal:Open()
	end
end

local function showSplash(screen: ScreenGui)
	local splash = Gui.Create("Frame", {
		Name = "Splash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = screen,
	}, { Gui.Gradient(Color3.fromRGB(20, 30, 80), Color3.fromRGB(6, 10, 30), 90) })
	-- copos de nieve
	local flakes = {}
	for i = 1, 70 do
		local size = math.random(4, 10)
		local flake = Gui.Create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = math.random() * 0.5,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(math.random(), math.random()),
			ZIndex = 61,
			Parent = splash,
		}, { Gui.CornerScale(0.5) })
		flakes[i] = { Frame = flake, Speed = 0.04 + math.random() * 0.08, Drift = (math.random() - 0.5) * 0.03 }
	end
	local content = Gui.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 520),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 62,
		Parent = splash,
	})
	Theme.AutoScale(content)
	local gift = Gui.Label({ Text = "🎁", Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 0, ZIndex = 63, Parent = content })
	local title = Gui.Label({
		Text = "DON'T STEAL THE PRESENT",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.fromOffset(0, 150),
		ZIndex = 63,
		StrokeThickness = 6,
		Parent = content,
	})
	Gui.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 230, 120)),
		}),
		Parent = title,
	})
	Gui.Label({
		Text = "🎄 " .. GameConfig.GameNameEs .. " 🎄",
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 254),
		ZIndex = 63,
		StrokeThickness = 3,
		Parent = content,
	})
	Gui.Label({
		Text = "Compra regalos · Roba los de los demás · Protege tu taller",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(210, 222, 255),
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 304),
		ZIndex = 63,
		StrokeThickness = 0,
		Parent = content,
	})
	local play: TextButton
	local closing = false
	local connection: RBXScriptConnection
	local function close()
		if closing then
			return
		end
		closing = true
		SoundController.Play("Success")
		for _, d in splash:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				Theme.Tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Theme.Tween(d, 0.4, { Transparency = 1 })
			elseif d:IsA("Frame") then
				Theme.Tween(d, 0.4, { BackgroundTransparency = 1 })
			end
		end
		Theme.Tween(splash, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.55, function()
			connection:Disconnect()
			splash:Destroy()
		end)
	end
	play = Theme.Button({
		Text = "🎅 ¡A JUGAR!",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(320, 76),
		Position = UDim2.new(0.5, 0, 0, 360),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = content,
		OnClick = close,
	})
	play.ZIndex = 65
	local playShadow = (play.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	playShadow.ZIndex = 64
	local help = Theme.Button({
		Text = "❓ ¿Cómo se juega?",
		Color = Theme.Colors.Blue,
		Size = UDim2.fromOffset(260, 50),
		Position = UDim2.new(0.5, 0, 0, 452),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = content,
		OnClick = function()
			close()
			task.delay(0.6, IntroUI.OpenHelp)
		end,
	})
	help.ZIndex = 65
	local helpShadow = (help.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	helpShadow.ZIndex = 64

	local giftScale = Gui.Create("UIScale", { Scale = 0.2, Parent = gift })
	Theme.Tween(giftScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Elastic)
	local titleScale = Gui.Create("UIScale", { Scale = 0.4, Parent = title })
	Theme.Tween(titleScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		gift.Rotation = math.sin(t * 2.2) * 8
		title.Rotation = math.sin(t * 1.3) * 1.5
		for _, f in flakes do
			local pos = f.Frame.Position
			local y = pos.Y.Scale + f.Speed * dt
			local x = pos.X.Scale + f.Drift * dt
			if y > 1.02 then
				y = -0.02
				x = math.random()
			end
			f.Frame.Position = UDim2.fromScale(x, y)
		end
	end)
	task.delay(25, close)
end

function IntroUI.Start(screen: ScreenGui)
	helpModal = Theme.Modal(screen, "❓ ¿CÓMO SE JUEGA?", Theme.Colors.Orange, Vector2.new(640, 520))
	local list = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = helpModal.Content })
	Gui.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = list
	for i, step in STEPS do
		stepRow(list, i, step)
	end
	Gui.Label({
		Text = "Consejo: los regalos con pilar de luz son LEGENDARIOS o mejores. ¡Corre a por ellos!",
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Income,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 10,
		ZIndex = 23,
		StrokeThickness = 0,
		Parent = list,
	})
	showSplash(screen)
end

return IntroUI
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'Notifications'}, 'ModuleScript', [======[
-- Avisos en pantalla: toasts apilados arriba, alerta roja cuando te roban, texto grande y confeti.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Notifications = {}

local screen: ScreenGui
local stack: Frame
local alertFrame: Frame
local alertText: TextLabel
local edge: Frame

local KIND_COLORS: { [string]: Color3 } = {
	Info = Theme.Colors.NavyLight,
	Success = Theme.Colors.Green,
	Warning = Theme.Colors.Orange,
	Error = Theme.Colors.Red,
	Rare = Theme.Colors.Purple,
	Event = Theme.Colors.Blue,
}

local active = 0

function Notifications.Toast(text: string, kind: string?, extra: { [string]: any }?)
	local color = KIND_COLORS[kind or "Info"] or Theme.Colors.NavyLight
	if extra and typeof(extra.Color) == "Color3" then
		color = extra.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	end
	active += 1
	while active > 5 do
		local oldest: Instance? = nil
		local oldestOrder = math.huge
		for _, child in stack:GetChildren() do
			if child:IsA("Frame") and child.LayoutOrder < oldestOrder then
				oldest = child
				oldestOrder = child.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
		active -= 1
	end
	local toast = Gui.Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = math.floor(os.clock() * 1000),
		BackgroundTransparency = 1,
		Parent = stack,
	}, {
		Gui.Corner(12),
		Gui.Gradient(Theme.Lighter(color, 0.15), Theme.Darker(color, 0.2), 90),
	})
	local stroke = Gui.BorderStroke(Theme.Darker(color, 0.65), 3, 1)
	stroke.Parent = toast
	local label = Gui.Label({
		Text = text,
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 1,
		StrokeThickness = 2,
		Parent = toast,
	})
	local labelStroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	labelStroke.Transparency = 1
	if extra and extra.Rainbow then
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
	Theme.Tween(toast, 0.25, { BackgroundTransparency = 0 })
	Theme.Tween(stroke, 0.25, { Transparency = 0 })
	Theme.Tween(label, 0.25, { TextTransparency = 0 })
	Theme.Tween(labelStroke, 0.25, { Transparency = 0 })
	local life = if kind == "Event" or kind == "Rare" then 6 else 4
	task.delay(life, function()
		if not toast.Parent then
			return
		end
		Theme.Tween(toast, 0.4, { BackgroundTransparency = 1 })
		Theme.Tween(stroke, 0.4, { Transparency = 1 })
		Theme.Tween(label, 0.4, { TextTransparency = 1 })
		Theme.Tween(labelStroke, 0.4, { Transparency = 1 })
		task.wait(0.45)
		if toast.Parent then
			toast:Destroy()
			active -= 1
		end
	end)
end

-- Texto enorme en el centro (renacer, evento...)
function Notifications.Center(text: string, color: Color3?)
	local label = Gui.Label({
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = color or Theme.Colors.Gold,
		Size = UDim2.new(0.8, 0, 0.12, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 5,
		Parent = screen,
	})
	local scale = Gui.Create("UIScale", { Scale = 0.3, Parent = label })
	Theme.Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		Theme.Tween(label, 0.5, { TextTransparency = 1 })
		Theme.Tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.5, { Transparency = 1 })
		task.wait(0.55)
		label:Destroy()
	end)
end

-- ¡Te están robando!
function Notifications.Alert(thiefName: string, presentLabel: string)
	alertText.Text = string.format("🚨 ¡%s te está robando %s! 🚨", thiefName, presentLabel)
	alertFrame.Visible = true
	local scale = alertFrame:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.5
	Theme.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	SoundController.Play("Alarm")
	task.delay(0.35, function()
		SoundController.Play("Alarm")
	end)
	-- borde rojo parpadeante
	edge.Visible = true
	for i = 1, 6 do
		task.delay((i - 1) * 0.3, function()
			edge.BackgroundTransparency = 1
			Theme.Tween(edge, 0.15, { BackgroundTransparency = 0.75 })
			task.wait(0.15)
			Theme.Tween(edge, 0.15, { BackgroundTransparency = 1 })
		end)
	end
	task.delay(3.5, function()
		alertFrame.Visible = false
		edge.Visible = false
	end)
end

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 80),
	Color3.fromRGB(70, 220, 110),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 110, 255),
}

function Notifications.Confetti(big: boolean?)
	local count = if big then 110 else 55
	for _ = 1, count do
		local piece = Gui.Create("Frame", {
			BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Rotation = math.random(0, 360),
			ZIndex = 50,
			Parent = screen,
		})
		local duration = 1.8 + math.random() * 1.6
		Theme.Tween(piece, duration, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.08, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Notifications.Start(parent: ScreenGui)
	screen = parent
	stack = Gui.Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 300),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = screen,
	})
	Theme.AutoScale(stack)
	Gui.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top).Parent = stack

	edge = Gui.Create("Frame", {
		Name = "AlertEdge",
		BackgroundColor3 = Color3.fromRGB(255, 0, 30),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = screen,
	})
	-- el centro del borde es transparente: usamos un marco interior con agujero simulado por 4 barras
	edge.BackgroundTransparency = 1
	for _, def in {
		{ UDim2.new(1, 0, 0.08, 0), UDim2.new(0, 0, 0, 0) },
		{ UDim2.new(1, 0, 0.08, 0), UDim2.new(0, 0, 0.92, 0) },
		{ UDim2.new(0.05, 0, 1, 0), UDim2.new(0, 0, 0, 0) },
		{ UDim2.new(0.05, 0, 1, 0), UDim2.new(0.95, 0, 0, 0) },
	} do
		Gui.Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 0, 30),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = def[1],
			Position = def[2],
			Parent = edge,
		}, {
			Gui.Create("UIGradient", {
				Transparency = NumberSequence.new(0, 1),
				Rotation = if def[1].X.Scale == 1 then (if def[2].Y.Scale > 0.5 then -90 else 90) else (if def[2].X.Scale > 0.5 then 180 else 0),
			}),
		})
	end

	local alertHolder = Gui.Create("Frame", {
		Name = "AlertHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(640, 70),
		Position = UDim2.new(0.5, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		Parent = screen,
	})
	Theme.AutoScale(alertHolder)
	alertFrame = Theme.Panel({
		Name = "Alert",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Red,
		Parent = alertHolder,
	})
	alertFrame.Visible = false
	alertFrame.ZIndex = 30
	Gui.Create("UIScale", { Scale = 1, Parent = alertFrame })
	alertText = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 3,
		ZIndex = 31,
		Parent = alertFrame,
	})

	Remotes.Event("Notify").OnClientEvent:Connect(function(text, kind, extra)
		if type(text) ~= "string" then
			return
		end
		Notifications.Toast(text, kind, extra)
		if kind == "Event" then
			local color = if type(extra) == "table" and typeof(extra.Color) == "Color3" then extra.Color else nil
			Notifications.Center(string.split(text, " — ")[1], color)
		end
	end)
	Remotes.Event("Alert").OnClientEvent:Connect(function(thief, label)
		Notifications.Alert(tostring(thief), tostring(label))
	end)
end

return Notifications
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'RebirthUI'}, 'ModuleScript', [======[
-- Ventana de renacer: qué ganas, qué necesitas y botón para hacerlo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Rebirths = require(Shared.Config.Rebirths)
local Rarities = require(Shared.Config.Rarities)
local Presents = require(Shared.Config.Presents)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local RebirthUI = {}

local modal: Theme.Modal
local levelLabel: TextLabel
local rows: { TextLabel } = {}
local reqCash: TextLabel
local reqRarity: TextLabel
local button: TextButton

local function hasRarity(rarityId: string): boolean
	local needed = Rarities.Get(rarityId).Index
	for _, entry in ClientState.Data.Presents or {} do
		local info = Presents.Get(entry.Id)
		if info and Rarities.Get(info.Rarity).Index >= needed then
			return true
		end
	end
	return false
end

local function refresh()
	local data = ClientState.Data
	local current = data.Rebirths or 0
	local requirement = Rebirths.Requirement(current)
	levelLabel.Text = string.format("Renacimiento actual: %d", current)
	if not requirement then
		rows[1].Text = "¡Has llegado al renacimiento máximo! 👑"
		rows[2].Text = ""
		rows[3].Text = ""
		reqCash.Text = ""
		reqRarity.Text = ""
		button.Text = "MÁXIMO"
		Theme.Recolor(button, Theme.Colors.Gray)
		return
	end
	local nextLevel = requirement.Level
	rows[1].Text = string.format("💰 Ingresos:  x%s  ➜  x%s", Format.Number(Rebirths.IncomeMultiplier(current)), Format.Number(Rebirths.IncomeMultiplier(nextLevel)))
	rows[2].Text = string.format("🎁 Huecos:  %d  ➜  %d", Rebirths.SlotCount(current), Rebirths.SlotCount(nextLevel))
	rows[3].Text = string.format("🔒 Bloqueo:  %ds  ➜  %ds", Rebirths.LockDuration(current), Rebirths.LockDuration(nextLevel))
	local cashOk = (data.Cash or 0) >= requirement.Cost
	local rarityOk = hasRarity(requirement.Rarity)
	reqCash.Text = string.format("%s  Tener %s  (tienes %s)", if cashOk then "✅" else "❌", Format.Cash(requirement.Cost), Format.Cash(data.Cash or 0))
	reqCash.TextColor3 = if cashOk then Theme.Colors.Money else Color3.fromRGB(255, 140, 140)
	reqRarity.Text = string.format("%s  Un regalo %s o mejor en tu taller", if rarityOk then "✅" else "❌", requirement.RarityName)
	reqRarity.TextColor3 = if rarityOk then Theme.Colors.Money else Color3.fromRGB(255, 140, 140)
	button.Text = "⭐ RENACER"
	Theme.Recolor(button, if cashOk and rarityOk then Theme.Colors.Purple else Theme.Colors.Gray)
end

local busy = false

local function doRebirth()
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Function("Rebirth"):InvokeServer("rebirth")
	end)
	busy = false
	if not ok then
		Notifications.Toast("Error al renacer. Inténtalo otra vez.", "Error")
	elseif not success then
		Notifications.Toast("⭐ " .. tostring(message), "Error")
		SoundController.Play("NoMoney")
	else
		modal:Close()
		Notifications.Center("⭐ ¡RENACIMIENTO! ⭐", Color3.fromRGB(220, 180, 255))
	end
	refresh()
end

function RebirthUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "⭐ RENACER", Theme.Colors.Purple, Vector2.new(600, 470))
	local list = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = modal.Content })
	Gui.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = list
	levelLabel = Gui.Label({ Text = "", Font = Theme.Fonts.Title, Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(220, 190, 255), ZIndex = 23, LayoutOrder = 1, Parent = list })
	Gui.Label({ Text = "Al renacer consigues PARA SIEMPRE:", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, LayoutOrder = 2, StrokeThickness = 2, Parent = list })
	for i = 1, 3 do
		rows[i] = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, TextColor3 = Theme.Colors.Income, Size = UDim2.new(1, 0, 0, 30), ZIndex = 23, LayoutOrder = 2 + i, Parent = list })
	end
	Gui.Label({ Text = "Necesitas:", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, LayoutOrder = 7, StrokeThickness = 2, Parent = list })
	reqCash = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 28), ZIndex = 23, LayoutOrder = 8, Parent = list })
	reqRarity = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 28), ZIndex = 23, LayoutOrder = 9, Parent = list })
	Gui.Label({
		Text = "⚠️ Perderás tu dinero y tus regalos. Los objetos de la tienda se quedan.",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(255, 200, 150),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 23,
		LayoutOrder = 10,
		StrokeThickness = 0,
		Parent = list,
	})
	button = Theme.Button({
		Text = "⭐ RENACER",
		Color = Theme.Colors.Purple,
		Size = UDim2.fromOffset(280, 58),
		LayoutOrder = 11,
		Parent = list,
		OnClick = doRebirth,
		Sound = "Click",
	})
	button.ZIndex = 24
	local shadow = (button.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	shadow.ZIndex = 23
	modal.OnOpen = refresh
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function RebirthUI.Open()
	modal:Open()
end

function RebirthUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return RebirthUI
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'ShopUI'}, 'ModuleScript', [======[
-- Tienda del Elfo: compra gears permanentes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Gears = require(Shared.Config.Gears)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local ShopUI = {}

local modal: Theme.Modal
local cards: { [string]: { Button: TextButton, Price: TextLabel } } = {}

local function refresh()
	local data = ClientState.Data
	for gearId, card in cards do
		local info = Gears.Get(gearId)
		if info then
			local owned = data.Gears and data.Gears[gearId]
			if owned or info.Price == 0 then
				card.Button.Text = "✓ TUYO"
				Theme.Recolor(card.Button, Theme.Colors.Gray)
			elseif (data.Cash or 0) >= info.Price then
				card.Button.Text = "COMPRAR"
				Theme.Recolor(card.Button, Theme.Colors.Green)
			else
				card.Button.Text = "COMPRAR"
				Theme.Recolor(card.Button, Theme.Colors.Red)
			end
			card.Price.Text = if info.Price == 0 then "GRATIS" else Format.Cash(info.Price)
		end
	end
end

local busy = false

local function buy(gearId: string)
	if busy then
		return
	end
	local data = ClientState.Data
	if data.Gears and data.Gears[gearId] then
		Notifications.Toast("Ya tienes este objeto: está en tu mochila.", "Info")
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Function("BuyGear"):InvokeServer(gearId)
	end)
	busy = false
	if not ok then
		Notifications.Toast("Error al comprar. Inténtalo otra vez.", "Error")
	elseif not success then
		Notifications.Toast("💸 " .. tostring(message), "Error")
		SoundController.Play("NoMoney")
	end
	refresh()
end

function ShopUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "🛒 TIENDA DEL ELFO", Theme.Colors.Green, Vector2.new(700, 500))
	local scroller = Gui.Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Snow,
		ZIndex = 22,
		Parent = modal.Content,
	})
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(206, 300),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	Gui.Padding(6).Parent = scroller
	for order, gearId in Gears.Order do
		local info = Gears.Get(gearId)
		if info then
			local card = Theme.Panel({ Name = gearId, Size = UDim2.fromOffset(206, 300), Color = Theme.Colors.NavyLight, Parent = scroller, LayoutOrder = order })
			card.ZIndex = 23
			local iconBg = Gui.Create("Frame", {
				BackgroundColor3 = info.Color,
				Size = UDim2.fromOffset(96, 96),
				Position = UDim2.new(0.5, 0, 0, 12),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 24,
				Parent = card,
			}, { Gui.CornerScale(0.5), Gui.BorderStroke(Theme.Darker(info.Color, 0.6), 3) })
			Gui.Label({ Text = info.Icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), StrokeThickness = 0, ZIndex = 25, Parent = iconBg })
			Gui.Label({
				Text = info.FullName,
				Font = Theme.Fonts.Title,
				Size = UDim2.new(1, -16, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 114),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 2,
				ZIndex = 24,
				Parent = card,
			})
			Gui.Label({
				Text = info.Description,
				Font = Theme.Fonts.Body,
				TextColor3 = Color3.fromRGB(210, 220, 245),
				TextWrapped = true,
				Size = UDim2.new(1, -20, 0, 60),
				Position = UDim2.new(0.5, 0, 0, 146),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 0,
				ZIndex = 24,
				Parent = card,
			})
			local price = Gui.Label({
				Text = Format.Cash(info.Price),
				Font = Theme.Fonts.Title,
				TextColor3 = Theme.Colors.Money,
				Size = UDim2.new(1, -16, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 208),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 2,
				ZIndex = 24,
				Parent = card,
			})
			local button = Theme.Button({
				Text = "COMPRAR",
				Color = Theme.Colors.Green,
				Size = UDim2.new(1, -28, 0, 44),
				Position = UDim2.new(0.5, 0, 1, -12),
				AnchorPoint = Vector2.new(0.5, 1),
				Parent = card,
				OnClick = function()
					buy(gearId)
				end,
			})
			button.ZIndex = 25
			local shadow = (button.Parent :: Frame):FindFirstChild("Shadow") :: Frame
			shadow.ZIndex = 24
			cards[gearId] = { Button = button, Price = price }
		end
	end
	modal.OnOpen = refresh
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
	refresh()
end

function ShopUI.Open()
	modal:Open()
end

function ShopUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return ShopUI
]======])
make('StarterPlayer.StarterPlayerScripts', {'Client', 'UI', 'Theme'}, 'ModuleScript', [======[
-- Estilo de la interfaz: colores navideños, botones con relieve, paneles y ventanas modales animadas.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Theme = {}

Theme.Colors = {
	Red = Color3.fromRGB(230, 44, 62),
	DarkRed = Color3.fromRGB(150, 16, 34),
	Green = Color3.fromRGB(42, 184, 96),
	DarkGreen = Color3.fromRGB(18, 110, 56),
	Gold = Color3.fromRGB(255, 200, 60),
	DarkGold = Color3.fromRGB(190, 120, 10),
	Blue = Color3.fromRGB(60, 140, 255),
	DarkBlue = Color3.fromRGB(24, 70, 170),
	Purple = Color3.fromRGB(160, 92, 255),
	DarkPurple = Color3.fromRGB(80, 36, 160),
	Orange = Color3.fromRGB(255, 140, 40),
	DarkOrange = Color3.fromRGB(170, 70, 0),
	Navy = Color3.fromRGB(26, 34, 66),
	NavyLight = Color3.fromRGB(44, 58, 110),
	White = Color3.fromRGB(255, 255, 255),
	Snow = Color3.fromRGB(236, 244, 255),
	Gray = Color3.fromRGB(120, 128, 150),
	Money = Color3.fromRGB(110, 255, 120),
	Income = Color3.fromRGB(255, 226, 80),
}

Theme.Fonts = Gui.Fonts

function Theme.Tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

Theme.Darker = darker
Theme.Lighter = lighter

-- Escala un bloque de interfaz según el tamaño de pantalla (móvil / PC)
function Theme.AutoScale(target: GuiObject): UIScale
	local uiScale = Gui.Create("UIScale", { Parent = target })
	local camera = workspace.CurrentCamera
	local function update()
		local viewport = camera.ViewportSize
		local s = math.min(viewport.X / 1280, viewport.Y / 760)
		uiScale.Scale = math.clamp(s, 0.55, 1.15)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return uiScale
end


export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	Font: Enum.Font?,
	TextColor: Color3?,
	LayoutOrder: number?,
	Name: string?,
	OnClick: (() -> ())?,
	Sound: string?,
}

-- Botón con relieve (sombra inferior), degradado, borde y animación al pasar y pulsar
function Theme.Button(props: ButtonProps): TextButton
	local color = props.Color or Theme.Colors.Green
	local holder = Gui.Create("Frame", {
		Name = props.Name or "Button",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local shadow = Gui.Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = darker(color, 0.55),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 5),
		Parent = holder,
	}, { Gui.Corner(14) })
	local button = Gui.Create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, 0),
		Text = props.Text,
		Font = props.Font or Theme.Fonts.Title,
		TextScaled = true,
		TextColor3 = props.TextColor or Theme.Colors.White,
		Parent = holder,
	}, {
		Gui.Corner(14),
		Gui.Gradient(lighter(color, 0.25), color, 90),
		Gui.BorderStroke(darker(color, 0.6), 3),
		Gui.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	})
	Gui.Stroke(darker(color, 0.7), 2).Parent = button
	local scale = Gui.Create("UIScale", { Scale = 1, Parent = holder })
	button.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.12, { Scale = 1 })
		Theme.Tween(button, 0.08, { Position = UDim2.new() })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.Tween(button, 0.06, { Position = UDim2.new(0, 0, 0, 4) })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.Tween(button, 0.08, { Position = UDim2.new() })
	end)
	button.Activated:Connect(function()
		SoundController.Play(props.Sound or "Click")
		if props.OnClick then
			props.OnClick()
		end
	end)
	shadow.ZIndex = button.ZIndex - 1
	return button
end

-- Cambia el color de un botón creado con Theme.Button
function Theme.Recolor(button: TextButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighter(color, 0.25), color)
	end
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then
			child.Color = darker(color, 0.65)
		end
	end
	local holder = button.Parent
	local shadow = holder and holder:FindFirstChild("Shadow") :: Frame?
	if shadow then
		shadow.BackgroundColor3 = darker(color, 0.55)
	end
end

function Theme.Panel(props: { [string]: any }): Frame
	local color = props.Color or Theme.Colors.Navy
	local frame = Gui.Create("Frame", {
		Name = props.Name or "Panel",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Gui.Corner(props.Radius or 16),
		Gui.Gradient(lighter(color, 0.12), darker(color, 0.15), 90),
		Gui.BorderStroke(props.StrokeColor or Color3.fromRGB(10, 14, 30), props.StrokeThickness or 3),
	})
	return frame
end

-- Ventanas modales ----------------------------------------------------------------------------------------

export type Modal = {
	Root: Frame,
	Content: Frame,
	Title: TextLabel,
	Open: (self: Modal) -> (),
	Close: (self: Modal) -> (),
	IsOpen: boolean,
	OnOpen: (() -> ())?,
}

local current: Modal? = nil

function Theme.Modal(screen: ScreenGui, title: string, color: Color3, size: Vector2): Modal
	local overlay = Gui.Create("TextButton", {
		Name = title .. "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	local holder = Gui.Create("Frame", {
		Name = "WindowHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = overlay,
	})
	Theme.AutoScale(holder)
	local window = Theme.Panel({
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Navy,
		Parent = holder,
		Radius = 22,
		StrokeThickness = 4,
	})
	window.ZIndex = 21
	local scale = Gui.Create("UIScale", { Scale = 1, Parent = window })
	-- cabecera con "nieve"
	local header = Gui.Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 22,
		Parent = window,
	}, {
		Gui.Corner(22),
		Gui.Gradient(lighter(color, 0.2), color, 90),
		Gui.BorderStroke(darker(color, 0.6), 3),
	})
	Gui.Create("Frame", {
		Name = "SnowCap",
		BackgroundColor3 = Theme.Colors.Snow,
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.new(0, 12, 0, -4),
		ZIndex = 23,
		Parent = header,
	}, { Gui.Corner(6) })
	for i = 0, 6 do
		Gui.Create("Frame", {
			BackgroundColor3 = Theme.Colors.Snow,
			Size = UDim2.fromOffset(14 + (i % 3) * 4, 12 + (i % 2) * 6),
			Position = UDim2.new(0.08 + i * 0.14, 0, 0, 2),
			ZIndex = 23,
			Parent = header,
		}, { Gui.CornerScale(0.5) })
	end
	local titleLabel = Gui.Label({
		Text = title,
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -140, 0, 44),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 24,
		StrokeThickness = 3,
		Parent = header,
	})
	local modal: Modal
	local close = Theme.Button({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -10, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Parent = header,
		OnClick = function()
			modal:Close()
		end,
	})
	close.ZIndex = 25
	local closeShadow = (close.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	closeShadow.ZIndex = 24
	local content = Gui.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -82),
		Position = UDim2.new(0, 14, 0, 72),
		ZIndex = 22,
		Parent = window,
	})

	modal = {
		Root = overlay :: any,
		Content = content,
		Title = titleLabel,
		IsOpen = false,
		OnOpen = nil,
	} :: any

	function modal.Open(self: Modal)
		if current and current ~= self then
			current:Close()
		end
		current = self
		self.IsOpen = true
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		scale.Scale = 0.6
		Theme.Tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
		Theme.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		SoundController.Play("Open")
		if self.OnOpen then
			self.OnOpen()
		end
	end

	function modal.Close(self: Modal)
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		if current == self then
			current = nil
		end
		Theme.Tween(overlay, 0.15, { BackgroundTransparency = 1 })
		local tween = Theme.Tween(scale, 0.15, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			if not self.IsOpen then
				overlay.Visible = false
			end
		end)
	end

	overlay.Activated:Connect(function()
		-- clic fuera de la ventana
	end)
	return modal
end

function Theme.CloseAll()
	if current then
		current:Close()
	end
end

return Theme
]======])
game:GetService('Workspace').StreamingEnabled = false
print('Don\'t Steal the Present instalado: ' .. 49 .. ' scripts. Pulsa Play.')
