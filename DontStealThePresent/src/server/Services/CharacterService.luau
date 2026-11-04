-- Velocidad y salto de cada personaje según su estado: llevar un regalo, congelado, botas, campana...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gears = require(Shared.Config.Gears)

local CharacterService = {}

type State = {
	Carrying: boolean,
	FrozenUntil: number,
	Boots: boolean,
	Bell: boolean,
	IceBlock: BasePart?,
}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = { Carrying = false, FrozenUntil = 0, Boots = false, Bell = false, IceBlock = nil }
		states[player] = state
	end
	return state
end

function CharacterService.GetHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function CharacterService.GetRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterService.IsFrozen(player: Player): boolean
	return getState(player).FrozenUntil > os.clock()
end

function CharacterService.Refresh(player: Player)
	local humanoid = CharacterService.GetHumanoid(player)
	if not humanoid then
		return
	end
	local state = getState(player)
	local speed = GameConfig.Movement.WalkSpeed
	local jump = GameConfig.Movement.JumpHeight
	if state.Boots then
		speed *= (Gears.List.ReindeerBoots.SpeedMult or 1)
	end
	if state.Bell then
		jump = Gears.List.JingleBell.JumpHeight or jump
	end
	if state.Carrying then
		speed *= GameConfig.Steal.CarrySpeedMult
		jump = math.min(jump, GameConfig.Steal.CarryJumpHeight)
	end
	if state.FrozenUntil > os.clock() then
		speed = 0
		jump = 0
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = jump
end

function CharacterService.SetFlag(player: Player, flag: string, value: boolean)
	local state = getState(player) :: any
	if state[flag] == value then
		return
	end
	state[flag] = value
	CharacterService.Refresh(player)
end

-- Congela al jugador: bloque de hielo y sin poder moverse
function CharacterService.Freeze(player: Player, duration: number)
	local state = getState(player)
	local root = CharacterService.GetRoot(player)
	if not root then
		return
	end
	state.FrozenUntil = math.max(state.FrozenUntil, os.clock() + duration)
	CharacterService.Refresh(player)
	if not state.IceBlock or not state.IceBlock.Parent then
		local ice = Instance.new("Part")
		ice.Name = "IceBlock"
		ice.Size = Vector3.new(4.6, 6.4, 4.6)
		ice.Color = Color3.fromRGB(170, 225, 255)
		ice.Material = Enum.Material.Ice
		ice.Transparency = 0.35
		ice.Reflectance = 0.2
		ice.CanCollide = false
		ice.CanQuery = false
		ice.CanTouch = false
		ice.Massless = true
		ice.CastShadow = false
		ice.CFrame = root.CFrame * CFrame.new(0, -0.4, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ice
		weld.Parent = ice
		ice.Parent = player.Character
		state.IceBlock = ice
	end
	local untilTime = state.FrozenUntil
	task.delay(duration + 0.05, function()
		if state.FrozenUntil <= untilTime + 0.01 and os.clock() >= state.FrozenUntil then
			if state.IceBlock then
				state.IceBlock:Destroy()
				state.IceBlock = nil
			end
			CharacterService.Refresh(player)
		end
	end)
end

function CharacterService.Track(player: Player)
	local function onCharacter(character: Model)
		local state = getState(player)
		state.Carrying = false
		state.Boots = false
		state.Bell = false
		state.FrozenUntil = 0
		state.IceBlock = nil
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			CharacterService.Refresh(player)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function CharacterService.Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CharacterService
