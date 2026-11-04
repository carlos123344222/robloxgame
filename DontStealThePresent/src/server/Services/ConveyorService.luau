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
