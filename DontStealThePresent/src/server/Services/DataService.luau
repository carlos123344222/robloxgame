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
