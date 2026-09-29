--!strict
-- Spawns and runs the NPCs. One shared PreSimulation loop steps every brain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterUtil = require(Shared.Util.CharacterUtil)
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)

local NPCBrain = require(script.Parent.NPCBrain)
local NPCConfig = require(script.Parent.NPCConfig)
local NPCFactory = require(script.Parent.NPCFactory)

export type MovementServiceApi = {
	Knockback: (player: Player, velocity: Vector3, stunSeconds: number) -> (),
}

local TAU = math.pi * 2

local NPCService = {}

-- Fires (npc: Model, target: Model) whenever a chaser lands a tag. Hook combat / game rules here.
NPCService.Tagged = Signal.new()

local brains: { NPCBrain.Brain } = {}

local function playerCharacters(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character and CharacterUtil.isAlive(player.Character) then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function findSpawnCenter(): Vector3
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position
	end
	return Vector3.new(0, 0, 0)
end

function NPCService.Start(movement: MovementServiceApi)
	local folder = Workspace:FindFirstChild(NPCConfig.FolderName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = NPCConfig.FolderName
		folder.Parent = Workspace
	end

	local context: NPCBrain.Context = {
		GetChaseTargets = function(): { Model }
			local list = playerCharacters()
			for _, brain in brains do
				if brain.Archetype.Role == "Runner" then
					table.insert(list, brain.Character)
				end
			end
			return list
		end,
		GetThreats = function(): { Model }
			local list = playerCharacters()
			for _, brain in brains do
				if brain.Archetype.Role == "Chaser" then
					table.insert(list, brain.Character)
				end
			end
			return list
		end,
		OnTag = function(brain: NPCBrain.Brain, target: Model)
			if target:GetAttribute("Invulnerable") == true then
				return -- dash i-frames dodge the tag
			end
			local targetRoot = CharacterUtil.getRoot(target)
			local ownRoot = brain.Loco.Root
			if targetRoot == nil then
				return
			end
			local away = MathUtil.flatUnit(targetRoot.Position - ownRoot.Position)
			if away.Magnitude < 0.1 then
				away = MathUtil.flatUnit(ownRoot.CFrame.LookVector)
			end
			local archetype = brain.Archetype
			local velocity = away * archetype.TagKnockback + Vector3.new(0, 32, 0)

			local player = Players:GetPlayerFromCharacter(target)
			if player then
				movement.Knockback(player, velocity, archetype.TagStun)
			else
				for _, other in brains do
					if other.Character == target then
						other.Loco:Stun(archetype.TagStun, velocity)
					end
				end
			end
			NPCService.Tagged:Fire(brain.Character, target)
		end,
	}

	task.spawn(function()
		local center = findSpawnCenter()
		local rng = Random.new()
		local count = 0
		for _, entry in NPCConfig.Spawn do
			local archetype = NPCConfig.Archetypes[entry.Archetype]
			if archetype == nil then
				warn(`[NPCService] unknown archetype '{entry.Archetype}'`)
				continue
			end
			for _ = 1, entry.Count do
				count += 1
				local angle = rng:NextNumber(0, TAU)
				local radius = rng:NextNumber(NPCConfig.SpawnRingMin, NPCConfig.SpawnRingMax)
				local x = center.X + math.cos(angle) * radius
				local z = center.Z + math.sin(angle) * radius
				local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0))
				local y = if hit then hit.Position.Y + 4 else center.Y + 6

				local model = NPCFactory.Create(archetype, `{archetype.DisplayName}{count}`, CFrame.new(x, y, z), folder)
				if model then
					table.insert(brains, NPCBrain.new(model, archetype, context))
				end
			end
		end
	end)

	RunService.PreSimulation:Connect(function(dt: number)
		for i = #brains, 1, -1 do
			local brain = brains[i]
			if brain.Dead or brain.Character.Parent == nil then
				brain:Destroy()
				table.remove(brains, i)
				brain.Character:Destroy()
			else
				brain:Update(dt)
			end
		end
	end)
end

return NPCService
