--!strict
-- Server side of player movement. Players simulate their own movement (so it feels instant), the
-- server's job is to (1) replicate what state they are in so everyone can see it, (2) hand out dash
-- invulnerability only for dashes it can account for, and (3) catch speed hacks and teleports.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterUtil = require(Shared.Util.CharacterUtil)
local GameConfig = require(Shared.Config.GameConfig)
local MovementConfig = require(Shared.Config.MovementConfig)
local Remotes = require(Shared.Net.Remotes)

local TAG = "MovementCharacter"
local CHECK_INTERVAL = 0.1

local ALLOWED_STATES: { [string]: boolean } = {
	Ground = true,
	Air = true,
	Dash = true,
	Slide = true,
	Roll = true,
	WallRun = true,
	Mantle = true,
	Stun = true,
}
local ALLOWED_EVENTS: { [string]: boolean } = {
	AirJump = true,
	WallJump = true,
	Skid = true,
}

type PlayerState = {
	Tokens: number,
	LastRefill: number,
	DashCharges: number,
	LastDashUpdate: number,
	LastPosition: Vector3?,
	LastGood: CFrame?,
	Violations: number,
	InvulnToken: number,
}

local MovementService = {}

local states: { [Player]: PlayerState } = {}
local knockbackRemote: RemoteEvent

local function newState(now: number): PlayerState
	return {
		Tokens = 40,
		LastRefill = now,
		DashCharges = MovementConfig.DashCharges,
		LastDashUpdate = now,
		LastPosition = nil,
		LastGood = nil,
		Violations = 0,
		InvulnToken = 0,
	}
end

local function consumeToken(state: PlayerState, now: number): boolean
	state.Tokens = math.min(40, state.Tokens + (now - state.LastRefill) * 25)
	state.LastRefill = now
	if state.Tokens < 1 then
		return false
	end
	state.Tokens -= 1
	return true
end

-- Server-side dash accounting. Uses the slowest recharge a legitimate client could have.
local function consumeDash(state: PlayerState, now: number): boolean
	local recharge = MovementConfig.DashRechargeTime / (1 + MovementConfig.FlowRechargeBonus)
	state.DashCharges = math.min(MovementConfig.DashCharges, state.DashCharges + (now - state.LastDashUpdate) / recharge)
	state.LastDashUpdate = now
	if state.DashCharges >= 0.5 then
		state.DashCharges -= 1
		return true
	end
	return false
end

local function onReport(player: Player, name: unknown, arg: unknown)
	local state = states[player]
	local character = player.Character
	if state == nil or character == nil or typeof(name) ~= "string" then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if not consumeToken(state, now) then
		return
	end

	if ALLOWED_STATES[name] then
		character:SetAttribute("MoveState", name)
		character:SetAttribute("MoveStateT", now)
		character:SetAttribute("MoveArg", if typeof(arg) == "number" then math.clamp(arg, -1, 1) else 0)

		if name == "Dash" and consumeDash(state, now) then
			state.InvulnToken += 1
			local token = state.InvulnToken
			character:SetAttribute("Invulnerable", true)
			task.delay(MovementConfig.DashInvulnTime, function()
				if state.InvulnToken == token and character.Parent then
					character:SetAttribute("Invulnerable", false)
				end
			end)
		end
	elseif ALLOWED_EVENTS[name] then
		character:SetAttribute("MoveEvent", name)
		character:SetAttribute("MoveEventT", now)
	end
end

local function setupCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	state.LastPosition = nil
	state.LastGood = nil
	state.Violations = 0
	state.DashCharges = MovementConfig.DashCharges

	character:SetAttribute("MoveState", "Ground")
	character:SetAttribute("MoveStateT", Workspace:GetServerTimeNow())
	character:SetAttribute("MoveArg", 0)
	character:SetAttribute("Invulnerable", false)
	CollectionService:AddTag(character, TAG)
end

local function checkPlayer(player: Player, state: PlayerState, dt: number)
	local ac = GameConfig.AntiCheat
	local character = player.Character
	if not ac.Enabled or character == nil or not CharacterUtil.isAlive(character) then
		state.LastPosition = nil
		return
	end
	local root = CharacterUtil.getRoot(character)
	if root == nil then
		return
	end

	local position = root.Position
	local last = state.LastPosition
	state.LastPosition = position
	if last == nil then
		state.LastGood = root.CFrame
		return
	end

	local horizontal = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
	local allowed = ac.MaxHorizontalSpeed * dt + 4
	local teleported = horizontal > ac.TeleportDistance
	if horizontal > allowed or teleported then
		state.Violations += if teleported then ac.ViolationsBeforeCorrection else 1
	else
		state.Violations = math.max(0, state.Violations - 1)
		state.LastGood = root.CFrame
	end

	if state.Violations >= ac.ViolationsBeforeCorrection then
		state.Violations = 0
		local good = state.LastGood
		if good then
			warn(`[MovementService] {player.Name} moved {math.floor(horizontal)} studs in {dt}s; putting them back`)
			character:PivotTo(good)
			state.LastPosition = good.Position
		end
	end
end

-- Call before teleporting a player from server code (round start, checkpoints, ...).
function MovementService.AuthorizeTeleport(player: Player)
	local state = states[player]
	if state then
		state.LastPosition = nil
		state.Violations = 0
	end
end

-- Launch + stun a player. Movement is owned by their client, so we ask the client to apply it.
function MovementService.Knockback(player: Player, velocity: Vector3, stunSeconds: number)
	knockbackRemote:FireClient(player, velocity, stunSeconds)
end

function MovementService.IsInvulnerable(character: Model): boolean
	return character:GetAttribute("Invulnerable") == true
end

function MovementService.Start()
	local report = Remotes.Get(Remotes.MoveReport)
	knockbackRemote = Remotes.Get(Remotes.Knockback)
	report.OnServerEvent:Connect(onReport)

	local function onPlayerAdded(player: Player)
		states[player] = newState(Workspace:GetServerTimeNow())
		player.CharacterAdded:Connect(function(character: Model)
			setupCharacter(player, character)
		end)
		if player.Character then
			setupCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		local step = elapsed
		elapsed = 0
		for player, state in states do
			checkPlayer(player, state, step)
		end
	end)
end

return MovementService
