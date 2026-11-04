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
