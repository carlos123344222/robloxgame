-- Gears con puntería (bola de nieve y rayo): al hacer clic/tocar se manda al servidor hacia dónde apuntas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gears = require(Shared.Config.Gears)
local Remotes = require(Shared.Net.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local GearController = {}

local AIMED = { Snowball = true, FreezeRay = true }
local hooked: { [Tool]: boolean } = {}
local lastUse: { [string]: number } = {}

local function aimPoint(): Vector3
	local hit = mouse.Hit
	if hit then
		return hit.Position
	end
	local camera = workspace.CurrentCamera
	return camera.CFrame.Position + camera.CFrame.LookVector * 100
end

local function hook(tool: Tool)
	if hooked[tool] then
		return
	end
	local gearId = tool:GetAttribute("GearId")
	if type(gearId) ~= "string" or not AIMED[gearId] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local info = Gears.Get(gearId)
		if not info then
			return
		end
		local t = os.clock()
		if t - (lastUse[gearId] or 0) < info.Cooldown then
			return
		end
		lastUse[gearId] = t
		-- animación de lanzar (el Animate por defecto la reproduce y se replica)
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.4, function()
			anim:Destroy()
		end)
		Remotes.Event("UseGear"):FireServer(gearId, aimPoint())
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then
			hooked[tool] = nil
		end
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			hook(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(hook, child)
		end
	end)
end

function GearController.Start()
	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	local function onCharacter(character: Model)
		mouse.TargetFilter = character
		watch(character)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return GearController
