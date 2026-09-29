--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Controllers = script:WaitForChild("Controllers")
local MovementController = require(Controllers.MovementController)
local CameraController = require(Controllers.CameraController)
local PoseController = require(Controllers.PoseController)
local EffectsController = require(Controllers.EffectsController)
local DebugHud = require(Controllers.DebugHud)

MovementController.Start()
CameraController.Start(MovementController)
PoseController.Start(MovementController)
EffectsController.Start(MovementController)
if GameConfig.ShowDebugHud then
	DebugHud.Start(MovementController)
end
