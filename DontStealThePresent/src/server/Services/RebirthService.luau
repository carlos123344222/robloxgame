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
