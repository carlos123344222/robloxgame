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
