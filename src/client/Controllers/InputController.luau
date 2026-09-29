--!strict
-- Turns keyboard / gamepad / touch into the Intent the movement code understands.
--
-- Movement and jump come from Roblox's default PlayerModule controls (so every device keeps working,
-- including the touch thumbstick). Dash, slide and sprint are bound here.
--
--   Move ........ WASD / left stick / thumbstick
--   Jump ........ Space / A / touch jump button   (press again in the air for a double jump)
--   Sprint ...... hold Left Shift / L3
--   Dash ........ Q / X
--   Slide/Roll .. C or Left Ctrl / B  (slide while sprinting; press just before landing to roll)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locomotion = require(Shared.Movement.Locomotion)
local Types = require(Shared.Types)
local MovementConfig = require(Shared.Config.MovementConfig)

type Intent = Types.Intent

local ACTION_DASH = "WCT_Dash"
local ACTION_SLIDE = "WCT_Slide"
local ACTION_SPRINT = "WCT_Sprint"

local InputController = {}

local intent: Intent = Locomotion.newIntent()
local dashQueued = false
local slideQueued = false
local sprintHeld = false
local slideHeld = false
local lastJumpHeld = false
local controls: any = nil

local function onDash(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		dashQueued = true
	end
	return Enum.ContextActionResult.Sink
end

local function onSlide(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		slideQueued = true
		slideHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		slideHeld = false
	end
	return Enum.ContextActionResult.Sink
end

local function onSprint(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		sprintHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Pass
end

function InputController.Start()
	local touch = UserInputService.TouchEnabled
	local priority = Enum.ContextActionPriority.High.Value

	ContextActionService:BindActionAtPriority(ACTION_DASH, onDash, touch, priority, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:BindActionAtPriority(
		ACTION_SLIDE,
		onSlide,
		touch,
		priority,
		Enum.KeyCode.C,
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindActionAtPriority(ACTION_SPRINT, onSprint, false, priority, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	if touch then
		ContextActionService:SetTitle(ACTION_DASH, "DASH")
		ContextActionService:SetPosition(ACTION_DASH, UDim2.new(1, -170, 1, -170))
		ContextActionService:SetTitle(ACTION_SLIDE, "SLIDE")
		ContextActionService:SetPosition(ACTION_SLIDE, UDim2.new(1, -250, 1, -100))
	end

	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, result = pcall(function()
			local playerScripts = player:WaitForChild("PlayerScripts")
			local playerModule = require(playerScripts:WaitForChild("PlayerModule") :: ModuleScript) :: any
			return playerModule:GetControls()
		end)
		if ok then
			controls = result
		else
			warn("[InputController] PlayerModule controls unavailable, falling back to WASD: " .. tostring(result))
		end
	end)
end

-- Camera-relative stick input -> world-space horizontal vector (length preserved, max 1).
local function toWorld(moveVector: Vector3, camera: Camera?): Vector3
	if moveVector.Magnitude < 0.01 then
		return Vector3.zero
	end
	local forward = Vector3.new(0, 0, -1)
	if camera then
		local look = camera.CFrame.LookVector
		forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude < 0.05 then
			-- Looking straight up or down: use the camera's up vector as "forward".
			local up = camera.CFrame.UpVector
			forward = Vector3.new(up.X, 0, up.Z)
		end
		if forward.Magnitude < 0.01 then
			forward = Vector3.new(0, 0, -1)
		end
		forward = forward.Unit
	end
	local right = forward:Cross(Vector3.yAxis)
	local world = right * moveVector.X + forward * -moveVector.Z
	if world.Magnitude > 1 then
		world = world.Unit
	end
	return world
end

local function readMoveVector(): Vector3
	if controls ~= nil then
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(vector) == "Vector3" then
			return vector
		end
	end
	local x = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
	local z = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
	return Vector3.new(x, 0, z)
end

-- Call once per rendered frame, after the default controls have run this frame.
function InputController.Sample(humanoid: Humanoid)
	-- The default controls already wrote Humanoid.Jump for whichever device is in use.
	local jumpHeld = humanoid.Jump
	if jumpHeld and not lastJumpHeld then
		intent.JumpPressed = true
	end
	intent.JumpHeld = jumpHeld
	lastJumpHeld = jumpHeld

	local move = toWorld(readMoveVector(), Workspace.CurrentCamera)
	intent.Move = move
	intent.Sprint = sprintHeld or (MovementConfig.AutoSprint and move.Magnitude > 0.9) or (UserInputService.TouchEnabled and move.Magnitude > 0.92)

	if dashQueued then
		intent.DashPressed = true
		dashQueued = false
	end
	if slideQueued then
		intent.SlidePressed = true
		slideQueued = false
	end
	intent.SlideHeld = slideHeld
end

function InputController.GetIntent(): Intent
	return intent
end

-- Edge-triggered flags are consumed by exactly one physics step.
function InputController.ClearEdges()
	intent.JumpPressed = false
	intent.DashPressed = false
	intent.SlidePressed = false
end

return InputController
