--!strict
-- RemoteEvents live in ReplicatedStorage.WCT_Remotes. The server creates them on demand,
-- the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "WCT_Remotes"

local Remotes = {}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Names, so client and server never disagree on a string.
Remotes.MoveReport = "MoveReport" -- client -> server: state / event notifications
Remotes.Knockback = "Knockback" -- server -> client: launch + stun the local character

return Remotes
