--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local MovementService = require(script.MovementService)
local DevArena = require(script.DevArena)
local NPCService = require(script.NPC.NPCService)

-- Shift is our sprint key; Roblox's shift-lock would fight it.
pcall(function()
	StarterPlayer.EnableMouseLockOption = false
end)

MovementService.Start()

if GameConfig.BuildDevArena then
	DevArena.Build()
end
if GameConfig.SpawnNPCs then
	NPCService.Start(MovementService)
end
