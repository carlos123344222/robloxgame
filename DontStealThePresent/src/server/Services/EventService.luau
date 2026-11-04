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
