--!strict
-- Owns the local player's Locomotion: creates it for every spawn, feeds it input each physics step,
-- and tells the server about state changes so other players can see them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locomotion = require(Shared.Movement.Locomotion)
local MovementConfig = require(Shared.Config.MovementConfig)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local InputController = require(script.Parent.InputController)

type Loco = Types.Loco

local player = Players.LocalPlayer

-- Local events other players need to see (as MoveEvent attributes set by the server).
local REPORTED_EVENTS: { [string]: boolean } = { AirJump = true, WallJump = true, Skid = true }

local MovementController = {}

-- Fires (loco: Loco?) whenever the local character gains or loses a Locomotion.
MovementController.LocoChanged = Signal.new()

local current: Loco? = nil
local stepConnection: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil
local report: RemoteEvent? = nil

function MovementController.GetLocomotion(): Loco?
	return current
end

local function send(name: string, arg: number?)
	if report then
		report:FireServer(name, arg)
	end
end

local function detach()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	RunService:UnbindFromRenderStep("WCT_SampleInput")
	if current then
		local old = current
		current = nil
		old:Destroy()
		MovementController.LocoChanged:Fire(nil)
	end
end

local function attach(character: Model)
	detach()

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid == nil or root == nil then
		return
	end

	local loco = Locomotion.new(character, MovementConfig, true)
	current = loco

	loco.StateChanged:Connect(function(newState: string)
		local side = if newState == "WallRun" then loco.StateData.Side else nil
		send(newState, if typeof(side) == "number" then side else nil)
	end)
	loco.Events:Connect(function(name: string)
		if REPORTED_EVENTS[name] then
			send(name, nil)
		end
	end)

	-- Sample input right after the default controls (which run at Input priority) and the camera.
	RunService:BindToRenderStep("WCT_SampleInput", Enum.RenderPriority.Camera.Value + 2, function()
		InputController.Sample(humanoid)
	end)
	stepConnection = RunService.PreSimulation:Connect(function(dt: number)
		loco:Step(dt, InputController.GetIntent())
		InputController.ClearEdges()
	end)
	diedConnection = humanoid.Died:Connect(detach)

	MovementController.LocoChanged:Fire(loco)
end

function MovementController.Start()
	report = Remotes.Get(Remotes.MoveReport)
	InputController.Start()

	Remotes.Get(Remotes.Knockback).OnClientEvent:Connect(function(velocity: any, stun: any)
		local loco = current
		if loco and typeof(velocity) == "Vector3" and typeof(stun) == "number" then
			loco:Stun(math.clamp(stun, 0.05, 3), velocity)
		end
	end)

	player.CharacterAdded:Connect(attach)
	player.CharacterRemoving:Connect(detach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end

return MovementController
