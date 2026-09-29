--!strict
-- Builds an R15 NPC from a HumanoidDescription (needs Studio / server internet access).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NPCConfig = require(script.Parent.NPCConfig)

local NPCFactory = {}

function NPCFactory.Create(archetype: NPCConfig.Archetype, name: string, cframe: CFrame, parent: Instance): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = archetype.Color
	description.TorsoColor = archetype.Color
	description.LeftArmColor = archetype.Color
	description.RightArmColor = archetype.Color
	description.LeftLegColor = archetype.Color
	description.RightLegColor = archetype.Color

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok then
		warn("[NPCFactory] could not build an NPC rig: " .. tostring(result))
		return nil
	end

	local model = result :: Model
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	humanoid.DisplayName = archetype.DisplayName
	humanoid.NameDisplayDistance = 50
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	model:PivotTo(cframe)
	model.Parent = parent
	CollectionService:AddTag(model, "MovementCharacter")
	model:SetAttribute("NPC", true)
	model:SetAttribute("Role", archetype.Role)
	model:SetAttribute("MoveState", "Ground")
	model:SetAttribute("MoveStateT", Workspace:GetServerTimeNow())
	model:SetAttribute("MoveArg", 0)
	model:SetAttribute("Invulnerable", false)

	-- The server simulates NPCs; without this the nearest player would, and the NPC would jitter.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model
end

return NPCFactory
