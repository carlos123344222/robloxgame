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
