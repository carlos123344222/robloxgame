--!strict
-- Camera feel layered on top of Roblox's default camera: field of view that opens up with speed,
-- roll on wall runs, a lower camera in slides, and a dip on landings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtil = require(Shared.Util.MathUtil)
local MovementConfig = require(Shared.Config.MovementConfig)
local Spring = require(Shared.Util.Spring)
local Types = require(Shared.Types)

type Loco = Types.Loco

local MAX_SPEED_FOV = 12
local DASH_FOV_KICK = 70
local WALL_ROLL = math.rad(7)

local CameraController = {}

local fov = Spring.new(0, 10)
local roll = Spring.new(0, 12)
local offset = Spring.new(0, 12, 0.7)
local baseFov = 70
local wallSide = 0
local eventConnection: { Disconnect: (any) -> () }? = nil
local currentLoco: Loco? = nil

local function hookLoco(loco: Loco?)
	if eventConnection then
		eventConnection:Disconnect()
		eventConnection = nil
	end
	currentLoco = loco
	wallSide = 0
	if loco == nil then
		return
	end
	eventConnection = loco.Events:Connect(function(name: string, data: any)
		if name == "Land" and typeof(data) == "number" then
			offset:Impulse(-math.clamp(data * 0.05, 0, 9))
		elseif name == "Dash" then
			fov:Impulse(DASH_FOV_KICK)
		elseif name == "Jump" then
			offset:Impulse(-2)
		elseif name == "AirJump" then
			fov:Impulse(25)
		elseif name == "Mantle" then
			fov:Impulse(20)
		elseif name == "WallRunStart" and typeof(data) == "table" then
			wallSide = data.Side or 0
		elseif name == "WallRunEnd" then
			wallSide = 0
		end
	end)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local loco = currentLoco
	if camera == nil then
		return
	end

	if loco == nil or loco.Destroyed then
		fov.Target = 0
		roll.Target = 0
		offset.Target = 0
	else
		local cfg = MovementConfig
		fov.Target = MathUtil.remap(loco.HSpeed, cfg.RunSpeed, cfg.SprintSpeed * 1.3, 0, MAX_SPEED_FOV)
		roll.Target = -wallSide * WALL_ROLL
		local state = loco.StateName
		offset.Target = if state == "Slide" then -1.5 elseif state == "Roll" then -1.2 else 0
		loco.Humanoid.CameraOffset = Vector3.new(0, offset:Update(dt), 0)
	end

	camera.FieldOfView = baseFov + fov:Update(dt)
	local rollAngle = roll:Update(dt)
	if math.abs(rollAngle) > 1e-4 then
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, rollAngle)
	end
end

function CameraController.Start(movement: Types.LocoProvider)
	local camera = Workspace.CurrentCamera
	if camera then
		baseFov = camera.FieldOfView
	end
	hookLoco(movement.GetLocomotion())
	movement.LocoChanged:Connect(hookLoco)
	RunService:BindToRenderStep("WCT_Camera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
