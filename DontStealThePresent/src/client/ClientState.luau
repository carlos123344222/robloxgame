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
