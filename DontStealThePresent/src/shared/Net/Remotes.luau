-- Remotes del juego. El servidor los crea en ReplicatedStorage.Remotes; el cliente los espera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	"DataSync", -- servidor -> cliente: copia de tus datos (dinero, gears, índice...)
	"Notify", -- servidor -> cliente: mensaje (texto, tipo)
	"Fx", -- servidor -> clientes: efectos visuales y sonidos
	"Knockback", -- servidor -> cliente: empujón al recibir un golpe
	"UseGear", -- cliente -> servidor: usar un gear con puntería (bola de nieve, rayo)
	"Alert", -- servidor -> cliente: ¡te están robando!
	"ClientReady", -- cliente -> servidor: la interfaz está lista para recibir datos
}

Remotes.Functions = {
	"BuyGear",
	"Rebirth",
}

local FOLDER_NAME = "Remotes"

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup solo en el servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Remotes.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
