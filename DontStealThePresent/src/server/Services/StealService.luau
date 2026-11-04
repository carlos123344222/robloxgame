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
