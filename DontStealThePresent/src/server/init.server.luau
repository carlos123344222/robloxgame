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
